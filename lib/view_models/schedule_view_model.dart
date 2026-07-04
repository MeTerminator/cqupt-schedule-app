import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/http_util.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../models/schedule_model.dart';
import '../models/theme_model.dart';
import '../models/hidden_rule_model.dart';
import '../services/widget_service.dart';
import '../services/icloud_service.dart';

class ScheduleViewModel extends ChangeNotifier {
  ScheduleResponse? scheduleData;
  List<CustomCourse> customCourses = [];
  List<HiddenRule> hiddenRules = [];
  bool isLoading = false;
  int selectedWeek = 1;
  String currentId = "";
  Map<String, int> courseColorMap = {}; // 课程颜色索引映射
  Map<String, String> courseCustomColorMap = {}; // 课程自定义颜色 Hex 映射
  ThemeSettings currentTheme = ThemeSettings.defaultTheme(); // 当前主题设置

  // --- 多账号与共同空闲时间管理状态 ---
  List<String> userProfiles = []; // 所有已添加学号列表
  Map<String, ScheduleResponse> loadedSchedules = {}; // 缓存各用户的课表
  Map<String, List<CustomCourse>> loadedCustomCourses = {}; // 缓存各用户的自定义行程
  Map<String, List<HiddenRule>> loadedHiddenRules = {}; // 缓存各用户的隐藏课表规则

  bool showCommonFreeTime = false; // 是否显示共同空闲时间
  List<String> checkedUserIds = []; // 计算共同空闲时间勾选的用户列表

  String toastMessage = "";
  bool showToast = false;

  DateTime? firstMondayDate;
  Timer? _refreshTimer;
  Timer? _toastTimer;

  // 标志位：是否需要动画跳转到指定周
  bool shouldAnimateToWeek = false;

  // --- iCloud 同步配置与状态 ---
  bool _icloudSyncEnabled = false;
  bool _icloudSyncCustomCourses = true;
  bool _icloudSyncCourseColors = true;
  bool _icloudSyncHiddenCourses = true;
  bool _icloudSyncTheme = true;
  bool _icloudSyncProfiles = true;

  bool get icloudSyncEnabled => _icloudSyncEnabled;
  bool get icloudSyncCustomCourses => _icloudSyncCustomCourses;
  bool get icloudSyncCourseColors => _icloudSyncCourseColors;
  bool get icloudSyncHiddenCourses => _icloudSyncHiddenCourses;
  bool get icloudSyncTheme => _icloudSyncTheme;
  bool get icloudSyncProfiles => _icloudSyncProfiles;

  static const String kCustomCoursesKey = "cloud_custom_courses";
  static const String kSavedIdKey = "saved_id";
  static const String kCourseColorMapKey = "course_color_map";
  static const String kCourseCustomColorMapKey = "course_custom_color_map";
  static const String kThemeSettingsKey = "theme_settings";
  static const String kWebBackgroundImageKey = "web_background_image_base64";
  static const String kHiddenRulesKey = "hidden_rules";
  static const String kSyncTimestampSuffix = "__ts";

  Uint8List? _webBackgroundImageBytes; // Web 平台背景图字节缓存

  /// 获取某个 iCloud 键对应的时间戳键名
  static String _tsKey(String key) => '$key$kSyncTimestampSuffix';

  /// 获取当前时间戳字符串（毫秒）
  static String _nowTimestamp() =>
      DateTime.now().millisecondsSinceEpoch.toString();

  ScheduleViewModel() {
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => refreshData(silent: true),
    );
    loadCustomCourses();
    loadThemeSettings();
    loadHiddenRules();
    loadCommonFreeTimeSettings(); // 加载共同空闲时间设置
    _loadICloudSyncSettings(); // 加载 iCloud 同步设置
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  bool get isCurrentWeekReal {
    final real = calculateCurrentRealWeek();
    final expected = real <= 0 ? 0 : (real > 22 ? 22 : real);
    return selectedWeek == expected;
  }

  int get targetWeek {
    final nextCourse = getNextUpcomingCourseGlobal();
    if (nextCourse != null) {
      return nextCourse.week;
    }
    final real = calculateCurrentRealWeek();
    return real <= 0 ? 0 : (real > 22 ? 22 : real);
  }

  int get currentDayOfWeek {
    final weekday = DateTime.now().weekday;
    return weekday;
  }

  bool isToday(int week, int day) {
    return week == calculateCurrentRealWeek() && day == currentDayOfWeek;
  }

  bool isCourseOngoing(CourseInstance course) {
    if (!isToday(course.week, course.day)) return false;

    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    final startMinutes = _timeToMinutes(course.startTime);
    final endMinutes = _timeToMinutes(course.endTime);

    return currentMinutes >= startMinutes && currentMinutes < endMinutes;
  }

  bool isCourseUpcoming(CourseInstance course) {
    if (!isToday(course.week, course.day)) return false;

    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    final startMinutes = _timeToMinutes(course.startTime);

    return currentMinutes < startMinutes;
  }

  bool isTomorrowCourse(CourseInstance course) {
    final tomorrowWeek = calculateCurrentRealWeek();
    final tomorrowDay = currentDayOfWeek + 1;
    if (tomorrowDay > 7) return false;

    return course.week == tomorrowWeek && course.day == tomorrowDay;
  }

  double getCourseProgress(CourseInstance course) {
    if (!isCourseOngoing(course)) return 0.0;

    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    final startMinutes = _timeToMinutes(course.startTime);
    final endMinutes = _timeToMinutes(course.endTime);

    final totalDuration = endMinutes - startMinutes;
    final elapsed = currentMinutes - startMinutes;

    return (elapsed / totalDuration).clamp(0.0, 1.0);
  }

  int _timeToMinutes(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length != 2) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return h * 60 + m;
  }

  bool hasTodayOngoingCourse(int week) {
    final todayCourses = allCourses(week).where((c) => isToday(c.week, c.day));
    return todayCourses.any((c) => isCourseOngoing(c));
  }

  bool hasTodayUpcomingCourse(int week) {
    final todayCourses = allCourses(week).where((c) => isToday(c.week, c.day));
    return todayCourses.any((c) => isCourseUpcoming(c));
  }

  CourseInstance? getNextUpcomingCourse(int week) {
    final currentWeek = calculateCurrentRealWeek();
    final currentDay = currentDayOfWeek;
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    final allUpcomingCourses = allCourses(week).where((c) {
      if (c.week < currentWeek) return false;
      if (c.week > currentWeek) return true;

      if (c.day < currentDay) return false;
      if (c.day > currentDay) return true;

      final startMinutes = _timeToMinutes(c.startTime);
      return startMinutes > currentMinutes;
    }).toList();

    if (allUpcomingCourses.isEmpty) return null;

    allUpcomingCourses.sort((a, b) {
      final weekCompare = a.week.compareTo(b.week);
      if (weekCompare != 0) return weekCompare;

      final dayCompare = a.day.compareTo(b.day);
      if (dayCompare != 0) return dayCompare;

      final aMinutes = _timeToMinutes(a.startTime);
      final bMinutes = _timeToMinutes(b.startTime);
      return aMinutes.compareTo(bMinutes);
    });

    return allUpcomingCourses.first;
  }

  CourseInstance? getNextUpcomingCourseGlobal() {
    final now = DateTime.now();
    final currentRealWeek = calculateCurrentRealWeek();
    final currentDay = now.weekday;
    final currentMinutes = now.hour * 60 + now.minute;

    final int nowAbsoluteMinutes = (currentDay - 1) * 1440 + currentMinutes;

    CourseInstance? bestCourse;
    int minDiff = 999999;

    for (int w = currentRealWeek; w <= currentRealWeek + 1; w++) {
      if (w <= 0 || w > 22) continue;

      final courses = allCourses(w);
      for (var c in courses) {
        final int courseStartMinutes = _timeToMinutes(c.startTime);
        final int weekOffset = (w - currentRealWeek) * 10080;
        final int courseAbsoluteMinutes =
            weekOffset + (c.day - 1) * 1440 + courseStartMinutes;

        final diff = courseAbsoluteMinutes - nowAbsoluteMinutes;

        if (diff > 0 && diff < minDiff) {
          minDiff = diff;
          bestCourse = c;
        }
      }
    }

    return bestCourse;
  }

  bool hasAnyCourseOngoing() {
    final realWeek = calculateCurrentRealWeek();
    if (realWeek <= 0 || realWeek > 22) return false;
    return allCourses(realWeek).any((c) => isCourseOngoing(c));
  }

  Future<void> startup(String studentId) async {
    currentId = studentId;
    await loadColorMap();
    await loadCommonFreeTimeSettings();
    await loadAllProfilesData();
    if (kIsWeb) {
      await loadWebBackgroundImage();
    }
    await loadFromCache(isInitial: true);
    if (!kIsWeb) {
      await WidgetService.syncToWidget(this);
    }
    refreshData(silent: true);
  }

  void generateColorMap() {
    final instances = scheduleData?.instances;
    if (instances == null) return;

    final names =
        instances
            .where((e) => !e.type.contains("考试"))
            .map((e) => e.course)
            .toSet()
            .toList()
          ..sort();

    courseColorMap.clear();

    // 核心：使用黄金比例分配色相，范围 0-360
    for (int i = 0; i < names.length; i++) {
      // 137.5 是黄金分割角，能最大化地分散颜色
      double hue = (i * 137.5) % 360;
      courseColorMap[names[i]] = hue.toInt();
    }

    notifyListeners();
    _saveColorMap();
  }

  void updateCourseColor(String courseName, int colorIndex) {
    courseColorMap[courseName] = colorIndex;
    notifyListeners();
    _saveColorMap();
  }

  void updateCourseCustomColor(String courseName, String? customColorHex) {
    if (customColorHex != null) {
      courseCustomColorMap[courseName] = customColorHex;
    } else {
      courseCustomColorMap.remove(courseName);
    }
    notifyListeners();
    _saveCustomColorMap();
  }

  /// 清空所有课程颜色映射
  void clearAllColorMaps() {
    courseColorMap.clear();
    courseCustomColorMap.clear();
    notifyListeners();
    _saveColorMap();
    _saveCustomColorMap();
  }

  // --- Namespaced Course Color Loading and Saving ---

  Future<void> loadColorMapForUser(String studentId) async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString('${kCourseColorMapKey}_$studentId');
    if (data == null) {
      // 兼容旧版全局键
      data = prefs.getString(kCourseColorMapKey);
      if (data != null) {
        await prefs.setString('${kCourseColorMapKey}_$studentId', data);
      }
    }
    if (data != null) {
      final Map<String, dynamic> jsonMap = jsonDecode(data);
      courseColorMap = jsonMap.map((key, value) => MapEntry(key, value as int));
    } else {
      courseColorMap = {};
    }

    String? customData = prefs.getString('${kCourseCustomColorMapKey}_$studentId');
    if (customData == null) {
      customData = prefs.getString(kCourseCustomColorMapKey);
      if (customData != null) {
        await prefs.setString('${kCourseCustomColorMapKey}_$studentId', customData);
      }
    }
    if (customData != null) {
      final Map<String, dynamic> jsonMap = jsonDecode(customData);
      courseCustomColorMap = jsonMap.map(
        (key, value) => MapEntry(key, value as String),
      );
    } else {
      courseCustomColorMap = {};
    }
    notifyListeners();
  }

  Future<void> saveColorMapForUser(String studentId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${kCourseColorMapKey}_$studentId', jsonEncode(courseColorMap));
    await prefs.setString('${kCourseCustomColorMapKey}_$studentId', jsonEncode(courseCustomColorMap));
    
    // 如果是当前正在使用的账号，同步更新旧版全局键以供其他依赖访问
    if (studentId == currentId) {
      await prefs.setString(kCourseColorMapKey, jsonEncode(courseColorMap));
      await prefs.setString(kCourseCustomColorMapKey, jsonEncode(courseCustomColorMap));
    }
    if (_icloudSyncEnabled && _icloudSyncCourseColors) {
      final ts = _nowTimestamp();
      final prefs2 = await SharedPreferences.getInstance();
      await ICloudService.setString('${kCourseColorMapKey}_$studentId', jsonEncode(courseColorMap));
      await ICloudService.setString(_tsKey('${kCourseColorMapKey}_$studentId'), ts);
      await prefs2.setString(_tsKey('${kCourseColorMapKey}_$studentId'), ts);
      await ICloudService.setString('${kCourseCustomColorMapKey}_$studentId', jsonEncode(courseCustomColorMap));
      await ICloudService.setString(_tsKey('${kCourseCustomColorMapKey}_$studentId'), ts);
      await prefs2.setString(_tsKey('${kCourseCustomColorMapKey}_$studentId'), ts);
    }
  }

  Future<void> _saveColorMap() async {
    await saveColorMapForUser(currentId);
  }

  Future<void> _saveCustomColorMap() async {
    await saveColorMapForUser(currentId);
  }

  Future<void> loadColorMap() async {
    await loadColorMapForUser(currentId);
  }

  List<String> getAllCourseNames() {
    final instances = scheduleData?.instances;
    if (instances == null) return [];

    return instances
        .where((e) => !e.type.contains("考试"))
        .map((e) => e.course)
        .toSet()
        .toList()
      ..sort();
  }

  List<MapEntry<String, int>> getAllCourseColors() {
    final names = getAllCourseNames();
    final customColors = customCourses.map((e) => e.colorIndex).toSet();

    final allColors = <int>{};
    for (var entry in courseColorMap.entries) {
      allColors.add(entry.value);
    }
    allColors.addAll(customColors);

    return names.map((name) {
      final colorIndex = courseColorMap[name] ?? 0;
      return MapEntry(name, colorIndex);
    }).toList();
  }

  Future<void> refreshData({bool silent = false}) async {
    if (currentId.isEmpty) return;

    if (!silent) {
      isLoading = true;
      notifyListeners();
    }

    try {
      final url = Uri.parse(
        "https://cqupt.ishub.top/api/curriculum/$currentId/curriculum.json",
      );
      final response = await HttpUtil.get(url);

      if (response.statusCode == 200) {
        final decoded = ScheduleResponse.fromJson(jsonDecode(response.body));
        scheduleData = decoded;
        await _writeScheduleCache(currentId, response.body);
        generateColorMap();
        parseStartDate(autoJump: false);
        if (!silent) {
          triggerToast("课表已同步");
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error fetching data: $e");
    } finally {
      if (!kIsWeb) {
        await WidgetService.syncToWidget(this);
      }
      // 每次刷新都触发 iCloud 同步（先推再拉）
      if (_icloudSyncEnabled) {
        await pushAllToICloud();
        await pullFromICloud();
      }
      if (!silent) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<String?> _readScheduleCache(String studentId) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('web_schedule_cache_$studentId');
    } else {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/schedule_cache_$studentId.json');
        
        // 兼容/迁移旧版没有学号后缀的缓存文件
        if (!await file.exists() && studentId == currentId && studentId.isNotEmpty) {
          final legacyFile = File('${directory.path}/schedule_cache.json');
          if (await legacyFile.exists()) {
            await legacyFile.copy(file.path);
          }
        }
        
        if (await file.exists()) {
          return await file.readAsString();
        }
      } catch (e) {
        debugPrint("Cache read error for $studentId: $e");
      }
      return null;
    }
  }

  Future<void> _writeScheduleCache(String studentId, String jsonStr) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('web_schedule_cache_$studentId', jsonStr);
    } else {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/schedule_cache_$studentId.json');
        await file.writeAsString(jsonStr);
      } catch (e) {
        debugPrint("Cache write error for $studentId: $e");
      }
    }
    if (_icloudSyncEnabled && _icloudSyncProfiles) {
      final ts = _nowTimestamp();
      final prefs2 = await SharedPreferences.getInstance();
      await ICloudService.setString('schedule_cache_$studentId', jsonStr);
      await ICloudService.setString(_tsKey('schedule_cache_$studentId'), ts);
      await prefs2.setString(_tsKey('schedule_cache_$studentId'), ts);
    }
  }

  /// 仅写入本地缓存，不推送到 iCloud（用于 pullFromICloud 避免循环）
  Future<void> _writeScheduleCacheLocal(String studentId, String jsonStr) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('web_schedule_cache_$studentId', jsonStr);
    } else {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/schedule_cache_$studentId.json');
        await file.writeAsString(jsonStr);
      } catch (e) {
        debugPrint("Cache write error (local) for $studentId: $e");
      }
    }
  }

  Future<void> _deleteScheduleCache(String studentId) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('web_schedule_cache_$studentId');
    } else {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/schedule_cache_$studentId.json');
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint("Error deleting schedule cache for $studentId: $e");
      }
    }
  }

  Future<void> loadFromCache({bool isInitial = false}) async {
    try {
      final jsonStr = await _readScheduleCache(currentId);
      if (jsonStr != null) {
        scheduleData = ScheduleResponse.fromJson(jsonDecode(jsonStr));
        generateColorMap();
        parseStartDate(autoJump: isInitial);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Cache load error: $e");
    }
  }

  void parseStartDate({bool autoJump = false}) {
    if (scheduleData == null) return;
    try {
      String dateStr = scheduleData!.week1Monday;
      DateTime date;

      try {
        date = DateTime.parse(dateStr);
      } catch (e) {
        final altFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ss");
        date = altFormat.parse(dateStr);
      }

      firstMondayDate = DateTime(date.year, date.month, date.day);

      if (autoJump) {
        selectedWeek = targetWeek;
        // 初始加载时不使用动画
        shouldAnimateToWeek = false;
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Date parse error: $e");
    }
  }

  void updateSelectedWeek(int week, {bool animate = false}) {
    selectedWeek = week.clamp(0, 22);
    shouldAnimateToWeek = animate;
    notifyListeners();
  }

  void performLogout() {
    currentId = '';
    scheduleData = null;
    notifyListeners();
  }

  int calculateCurrentRealWeek() {
    if (firstMondayDate == null) return 1;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysDiff = today.difference(firstMondayDate!).inDays;

    if (daysDiff < 0) {
      if (daysDiff >= -7) return 0;
      return -1;
    }
    return (daysDiff ~/ 7) + 1;
  }

  void triggerToast(String msg) {
    _toastTimer?.cancel();
    toastMessage = msg;
    showToast = true;
    notifyListeners();

    _toastTimer = Timer(const Duration(seconds: 2), () {
      showToast = false;
      notifyListeners();
    });
  }

  Future<void> addCustomCourse(CustomCourse course) async {
    customCourses.add(course);
    await saveCustomCourses();
    if (!kIsWeb) await WidgetService.syncToWidget(this);
    triggerToast("行程已添加");
  }

  Future<void> updateCustomCourse(CustomCourse course) async {
    final index = customCourses.indexWhere((e) => e.id == course.id);
    if (index != -1) {
      customCourses[index] = course;
      await saveCustomCourses();
      if (!kIsWeb) await WidgetService.syncToWidget(this);
      triggerToast("行程已更新");
    }
  }

  Future<void> deleteCustomCourseAt(int index) async {
    if (index < 0 || index >= customCourses.length) return;
    customCourses.removeAt(index);
    await saveCustomCourses();
    notifyListeners();
    if (!kIsWeb) await WidgetService.syncToWidget(this);
  }

  Future<void> deleteCustomCourseById(String id) async {
    final index = customCourses.indexWhere((e) => e.id == id);
    if (index != -1) {
      customCourses.removeAt(index);
      await saveCustomCourses();
      notifyListeners();
      if (!kIsWeb) await WidgetService.syncToWidget(this);
    }
  }

  Future<void> clearAllCustomCourses() async {
    customCourses.clear();
    await saveCustomCourses();
    if (!kIsWeb) await WidgetService.syncToWidget(this);
    triggerToast("自定义行程已清空");
  }

  // --- Namespaced Custom Courses and Hidden Rules ---

  Future<void> loadCustomCoursesForUser(String studentId) async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString('${kCustomCoursesKey}_$studentId');
    if (data == null) {
      // 兼容旧版全局键
      data = prefs.getString(kCustomCoursesKey);
      if (data != null) {
        await prefs.setString('${kCustomCoursesKey}_$studentId', data);
      }
    }
    if (data != null) {
      final List<dynamic> jsonList = jsonDecode(data);
      customCourses = jsonList.map((e) => CustomCourse.fromJson(e)).toList();
    } else {
      customCourses = [];
    }
    notifyListeners();
  }

  Future<void> saveCustomCoursesForUser(String studentId) async {
    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(
      customCourses.map((e) => e.toJson()).toList(),
    );
    await prefs.setString('${kCustomCoursesKey}_$studentId', data);

    if (studentId == currentId) {
      await prefs.setString(kCustomCoursesKey, data);
    }
    if (_icloudSyncEnabled && _icloudSyncCustomCourses) {
      final ts = _nowTimestamp();
      await ICloudService.setString('${kCustomCoursesKey}_$studentId', data);
      await ICloudService.setString(_tsKey('${kCustomCoursesKey}_$studentId'), ts);
      await prefs.setString(_tsKey('${kCustomCoursesKey}_$studentId'), ts);
    }
  }

  Future<void> loadHiddenRulesForUser(String studentId) async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString('${kHiddenRulesKey}_$studentId');
    if (data == null) {
      // 兼容旧版全局键
      data = prefs.getString(kHiddenRulesKey);
      if (data != null) {
        await prefs.setString('${kHiddenRulesKey}_$studentId', data);
      }
    }
    if (data != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(data);
        hiddenRules = jsonList.map((e) => HiddenRule.fromJson(e)).toList();
      } catch (e) {
        debugPrint("Failed to parse hidden rules for $studentId: $e");
        hiddenRules = [];
      }
    } else {
      hiddenRules = [];
    }
    notifyListeners();
  }

  Future<void> saveHiddenRulesForUser(String studentId) async {
    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(
      hiddenRules.map((e) => e.toJson()).toList(),
    );
    await prefs.setString('${kHiddenRulesKey}_$studentId', data);

    if (studentId == currentId) {
      await prefs.setString(kHiddenRulesKey, data);
    }
    if (_icloudSyncEnabled && _icloudSyncHiddenCourses) {
      final ts = _nowTimestamp();
      await ICloudService.setString('${kHiddenRulesKey}_$studentId', data);
      await ICloudService.setString(_tsKey('${kHiddenRulesKey}_$studentId'), ts);
      await prefs.setString(_tsKey('${kHiddenRulesKey}_$studentId'), ts);
    }
  }

  /// 仅保存自定义课程到本地，不触发小组件刷新
  Future<void> saveCustomCourses() async {
    await saveCustomCoursesForUser(currentId);
  }

  Future<void> loadCustomCourses() async {
    await loadCustomCoursesForUser(currentId);
  }

  Future<void> saveHiddenRules() async {
    await saveHiddenRulesForUser(currentId);
  }

  Future<void> loadHiddenRules() async {
    await loadHiddenRulesForUser(currentId);
  }

  // --- 多账号管理业务逻辑 ---

  Future<void> loadAllProfilesData() async {
    final prefs = await SharedPreferences.getInstance();
    userProfiles = prefs.getStringList('user_profiles_list') ?? [];

    if (currentId.isNotEmpty && !userProfiles.contains(currentId)) {
      userProfiles.add(currentId);
      await prefs.setStringList('user_profiles_list', userProfiles);
    }

    loadedSchedules.clear();
    loadedCustomCourses.clear();
    loadedHiddenRules.clear();

    for (var id in userProfiles) {
      // 1. 加载课表
      try {
        final jsonStr = await _readScheduleCache(id);
        if (jsonStr != null) {
          loadedSchedules[id] = ScheduleResponse.fromJson(jsonDecode(jsonStr));
        } else if (id == currentId && scheduleData != null) {
          loadedSchedules[id] = scheduleData!;
        }
      } catch (e) {
        debugPrint("Error loading profile schedule for $id: $e");
      }

      // 2. 加载自定义行程
      final customData = prefs.getString('${kCustomCoursesKey}_$id');
      if (customData != null) {
        final List<dynamic> jsonList = jsonDecode(customData);
        loadedCustomCourses[id] = jsonList.map((e) => CustomCourse.fromJson(e)).toList();
      } else if (id == currentId) {
        loadedCustomCourses[id] = customCourses;
      } else {
        loadedCustomCourses[id] = [];
      }

      // 3. 加载隐藏课程
      final hiddenData = prefs.getString('${kHiddenRulesKey}_$id');
      if (hiddenData != null) {
        final List<dynamic> jsonList = jsonDecode(hiddenData);
        loadedHiddenRules[id] = jsonList.map((e) => HiddenRule.fromJson(e)).toList();
      } else if (id == currentId) {
        loadedHiddenRules[id] = hiddenRules;
      } else {
        loadedHiddenRules[id] = [];
      }
    }
    notifyListeners();
  }

  Future<bool> addUserProfile(String studentId) async {
    if (studentId.isEmpty) {
      triggerToast("学号不能为空");
      return false;
    }
    if (userProfiles.contains(studentId)) {
      triggerToast("该学号档案已存在");
      return false;
    }

    isLoading = true;
    notifyListeners();

    try {
      final url = Uri.parse(
        "https://cqupt.ishub.top/api/curriculum/$studentId/curriculum.json",
      );
      final response = await HttpUtil.get(url);

      if (response.statusCode == 200) {
        final body = response.body;
        final decoded = ScheduleResponse.fromJson(jsonDecode(body));
        if (decoded.studentId.isEmpty) {
          triggerToast("无法解析课表数据，添加失败");
          return false;
        }

        // 保存课表缓存
        await _writeScheduleCache(studentId, body);

        // 添加到学号列表
        userProfiles.add(studentId);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('user_profiles_list', userProfiles);
        if (_icloudSyncEnabled && _icloudSyncProfiles) {
          await ICloudService.setString('user_profiles_list', jsonEncode(userProfiles));
        }

        // 初始化对应的空偏好设置
        await loadColorMapForUser(studentId);
        await loadCustomCoursesForUser(studentId);
        await loadHiddenRulesForUser(studentId);

        await saveColorMapForUser(studentId);
        await saveCustomCoursesForUser(studentId);
        await saveHiddenRulesForUser(studentId);

        // 回到当前账号的内存状态
        await loadColorMapForUser(currentId);
        await loadCustomCoursesForUser(currentId);
        await loadHiddenRulesForUser(currentId);

        await loadAllProfilesData();
        triggerToast("添加用户 ${decoded.studentName} 成功");
        return true;
      } else {
        triggerToast("未找到该学号的课表数据");
        return false;
      }
    } catch (e) {
      debugPrint("Error adding user profile: $e");
      triggerToast("添加失败，请检查网络或学号");
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteUserProfile(String studentId) async {
    if (studentId == currentId) {
      triggerToast("无法删除当前正在使用的账号");
      return;
    }

    userProfiles.remove(studentId);
    checkedUserIds.remove(studentId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('user_profiles_list', userProfiles);
    await prefs.setStringList('checked_user_ids', checkedUserIds);

    // 删除缓存文件
    await _deleteScheduleCache(studentId);

    // 删除首选项
    await prefs.remove('${kCustomCoursesKey}_$studentId');
    await prefs.remove('${kCourseColorMapKey}_$studentId');
    await prefs.remove('${kCourseCustomColorMapKey}_$studentId');
    await prefs.remove('${kHiddenRulesKey}_$studentId');

    if (_icloudSyncEnabled && _icloudSyncProfiles) {
      await ICloudService.setString('user_profiles_list', jsonEncode(userProfiles));
      await ICloudService.remove('schedule_cache_$studentId');
      await ICloudService.remove('${kCustomCoursesKey}_$studentId');
      await ICloudService.remove('${kCourseColorMapKey}_$studentId');
      await ICloudService.remove('${kCourseCustomColorMapKey}_$studentId');
      await ICloudService.remove('${kHiddenRulesKey}_$studentId');
    }

    await loadAllProfilesData();
    triggerToast("已删除用户档案");
  }

  Future<void> switchProfile(String studentId) async {
    if (studentId == currentId) return;

    currentId = studentId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kSavedIdKey, studentId);
    await prefs.setBool('is_logged_in', true);

    await loadColorMapForUser(studentId);
    await loadCustomCoursesForUser(studentId);
    await loadHiddenRulesForUser(studentId);

    try {
      final jsonStr = await _readScheduleCache(studentId);
      if (jsonStr != null) {
        scheduleData = ScheduleResponse.fromJson(jsonDecode(jsonStr));
      } else {
        scheduleData = null;
      }
    } catch (e) {
      debugPrint("Error switching profile schedule: $e");
      scheduleData = null;
    }

    parseStartDate(autoJump: true);
    notifyListeners();

    if (!kIsWeb) {
      await WidgetService.syncToWidget(this);
    }

    // 触发静默同步更新最新课表
    await refreshData(silent: false);
  }

  // --- 共同空闲时间业务逻辑 ---

  Future<void> loadCommonFreeTimeSettings() async {
    final prefs = await SharedPreferences.getInstance();
    showCommonFreeTime = prefs.getBool('show_common_free_time') ?? false;
    checkedUserIds = prefs.getStringList('checked_user_ids') ?? [];
    notifyListeners();
  }

  Future<void> toggleCommonFreeTime(bool value) async {
    showCommonFreeTime = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_common_free_time', value);
    notifyListeners();
  }

  Future<void> toggleCheckedUser(String id, bool checked) async {
    if (checked) {
      if (!checkedUserIds.contains(id)) {
        checkedUserIds.add(id);
      }
    } else {
      checkedUserIds.remove(id);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('checked_user_ids', checkedUserIds);
    notifyListeners();
  }

  List<CourseInstance> getCoursesForUser(String id, int week) {
    final schedule = loadedSchedules[id];
    final customs = loadedCustomCourses[id] ?? [];
    final hiddens = loadedHiddenRules[id] ?? [];

    bool isHidden(CourseInstance course) {
      for (var rule in hiddens) {
        if (rule.type == 'all') {
          if (rule.courseName == course.course) return true;
        } else if (rule.type == 'time_slot') {
          if (rule.courseName == course.course &&
              rule.day == course.day &&
              rule.periods != null &&
              rule.periods!.isNotEmpty &&
              course.periods.isNotEmpty &&
              rule.periods!.first == course.periods.first) {
            return true;
          }
        } else if (rule.type == 'single') {
          if (rule.instanceId == course.id) return true;
        }
      }
      return false;
    }

    final apiList = schedule?.instances.where((e) => e.week == week).toList() ?? [];
    final customList = customs
        .expand((e) => e.toInstances())
        .where((e) => e.week == week)
        .toList();

    return [...apiList, ...customList].where((c) => !isHidden(c)).toList();
  }

  Set<String> getCommonFreePeriods(int week) {
    if (!showCommonFreeTime || checkedUserIds.isEmpty) return {};

    final Set<String> freeCells = {};

    // 默认初始化 7 天 * 12 节课全为空闲
    for (int day = 1; day <= 7; day++) {
      for (int period = 1; period <= 12; period++) {
        freeCells.add("${day}_$period");
      }
    }

    // 从空闲集合中扣除每个被勾选用户在这一周的有课节次
    for (var id in checkedUserIds) {
      final courses = getCoursesForUser(id, week);
      for (var c in courses) {
        for (var p in c.periods) {
          freeCells.remove("${c.day}_$p");
        }
      }
    }

    return freeCells;
  }

  bool isCourseHidden(CourseInstance course) {
    for (var rule in hiddenRules) {
      if (rule.type == 'all') {
        if (rule.courseName == course.course) {
          return true;
        }
      } else if (rule.type == 'time_slot') {
        if (rule.courseName == course.course &&
            rule.day == course.day &&
            rule.periods != null &&
            course.periods.isNotEmpty &&
            rule.periods!.first == course.periods.first) {
          return true;
        }
      } else if (rule.type == 'single') {
        if (rule.instanceId == course.id) {
          return true;
        }
      }
    }
    return false;
  }

  Future<void> addHiddenRule(HiddenRule rule) async {
    hiddenRules.add(rule);
    await saveHiddenRules();
    notifyListeners();
    if (!kIsWeb) {
      await WidgetService.syncToWidget(this);
    }
  }

  Future<void> removeHiddenRuleById(String ruleId) async {
    hiddenRules.removeWhere((e) => e.id == ruleId);
    await saveHiddenRules();
    notifyListeners();
    if (!kIsWeb) {
      await WidgetService.syncToWidget(this);
    }
  }

  Future<void> clearAllHiddenRules() async {
    hiddenRules.clear();
    await saveHiddenRules();
    notifyListeners();
    if (!kIsWeb) {
      await WidgetService.syncToWidget(this);
    }
  }

  List<CourseInstance> allCourses(int week) {
    final apiList =
        scheduleData?.instances.where((e) => e.week == week).toList() ?? [];
    final customList = customCourses
        .expand((e) => e.toInstances())
        .where((e) => e.week == week)
        .toList();
    return [...apiList, ...customList].where((c) => !isCourseHidden(c)).toList();
  }

  String calculateDate(int week, int day) {
    if (scheduleData == null) return "未知日期";

    final startStr = scheduleData!.week1Monday.substring(0, 10);
    DateTime startDate;
    try {
      startDate = DateTime.parse(startStr);
    } catch (e) {
      return "未知日期";
    }

    final offset = (week - 1) * 7 + (day - 1);
    final targetDate = startDate.add(Duration(days: offset));

    return DateFormat('yyyy年M月d日').format(targetDate);
  }

  String durationWeeks(CourseInstance course) {
    // 如果存在非空的 weekStr，则直接返回
    if (course.weekStr != null && course.weekStr!.trim().isNotEmpty) {
      return course.weekStr!;
    }

    final allInstances = [
      ...?scheduleData?.instances,
      ...customCourses.map((e) => e.toInstance()),
    ];

    final relatedCourses = allInstances
        .where((e) => e.course == course.course)
        .toList();
    final weeks = relatedCourses.map((e) => e.week).toList();

    if (weeks.isEmpty) return "第${course.week}周";

    final minWeek = weeks.reduce((a, b) => a < b ? a : b);
    final maxWeek = weeks.reduce((a, b) => a > b ? a : b);

    return minWeek == maxWeek ? "第$minWeek周" : "$minWeek-$maxWeek周";
  }

  // 主题设置相关方法
  Future<void> saveThemeSettings(ThemeSettings theme) async {
    currentTheme = theme;
    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(theme.toJson());
    await prefs.setString(kThemeSettingsKey, data);
    notifyListeners();
    if (_icloudSyncEnabled && _icloudSyncTheme) {
      final ts = _nowTimestamp();
      await ICloudService.setString(kThemeSettingsKey, data);
      await ICloudService.setString(_tsKey(kThemeSettingsKey), ts);
      await prefs.setString(_tsKey(kThemeSettingsKey), ts);
    }
  }

  Future<void> loadThemeSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(kThemeSettingsKey);
    if (data != null) {
      try {
        final Map<String, dynamic> jsonMap = jsonDecode(data);
        currentTheme = ThemeSettings.fromJson(jsonMap);
        notifyListeners();
      } catch (e) {
        debugPrint("Failed to load theme settings: $e");
        currentTheme = ThemeSettings.defaultTheme();
      }
    }
  }

  Future<void> applyThemePreset(ThemeSettings preset) async {
    await saveThemeSettings(preset);
  }

  Color? get headerTextColor {
    if (currentTheme.headerTextColorHex != null) {
      return ThemeColorUtils.hexToColor(currentTheme.headerTextColorHex!);
    }
    return null;
  }

  Color? get timelineTextColor {
    if (currentTheme.timelineTextColorHex != null) {
      return ThemeColorUtils.hexToColor(currentTheme.timelineTextColorHex!);
    }
    return null;
  }

  Color? get courseBlockTextColor {
    if (currentTheme.courseBlockTextColorHex != null) {
      return ThemeColorUtils.hexToColor(currentTheme.courseBlockTextColorHex!);
    }
    return null;
  }

  Color? get courseBlockBorderColor {
    if (currentTheme.courseBlockBorderColorHex != null) {
      return ThemeColorUtils.hexToColor(
        currentTheme.courseBlockBorderColorHex!,
      );
    }
    return null;
  }

  double get courseBlockBorderWidth => currentTheme.courseBlockBorderWidth;

  double get courseBlockOpacity => currentTheme.courseBlockOpacity;

  Color? get backgroundColor {
    if (currentTheme.backgroundType == BackgroundType.solid &&
        currentTheme.backgroundColorHex != null) {
      return ThemeColorUtils.hexToColor(currentTheme.backgroundColorHex!);
    }
    return null;
  }

  String? get backgroundImagePath => currentTheme.backgroundImagePath;

  /// Web 平台背景图字节数据
  Uint8List? get backgroundImageBytes => _webBackgroundImageBytes;

  /// 保存 Web 背景图（base64）
  Future<void> saveWebBackgroundImage(Uint8List bytes) async {
    final prefs = await SharedPreferences.getInstance();
    final base64Str = base64Encode(bytes);
    await prefs.setString(kWebBackgroundImageKey, base64Str);
    _webBackgroundImageBytes = bytes;
    notifyListeners();
  }

  /// 加载 Web 背景图（base64）
  Future<void> loadWebBackgroundImage() async {
    final prefs = await SharedPreferences.getInstance();
    final base64Str = prefs.getString(kWebBackgroundImageKey);
    if (base64Str != null && base64Str.isNotEmpty) {
      _webBackgroundImageBytes = base64Decode(base64Str);
      notifyListeners();
    }
  }

  /// 清除 Web 背景图
  Future<void> clearWebBackgroundImage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kWebBackgroundImageKey);
    _webBackgroundImageBytes = null;
    notifyListeners();
  }

  BackgroundType get backgroundType => currentTheme.backgroundType;

  bool get headerBlurEffect => currentTheme.headerBlurEffect;

  Color? get headerBackgroundColor {
    if (currentTheme.headerBackgroundColorHex != null) {
      return ThemeColorUtils.hexToColor(currentTheme.headerBackgroundColorHex!);
    }
    return null;
  }

  double get headerBackgroundOpacity => currentTheme.headerBackgroundOpacity;

  // --- iCloud 同步业务方法 ---
  Future<void> _loadICloudSyncSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _icloudSyncEnabled = prefs.getBool('icloud_sync_enabled') ?? false;
    _icloudSyncCustomCourses = prefs.getBool('icloud_sync_custom_courses') ?? true;
    _icloudSyncCourseColors = prefs.getBool('icloud_sync_course_colors') ?? true;
    _icloudSyncHiddenCourses = prefs.getBool('icloud_sync_hidden_courses') ?? true;
    _icloudSyncTheme = prefs.getBool('icloud_sync_theme') ?? true;
    _icloudSyncProfiles = prefs.getBool('icloud_sync_profiles') ?? true;
    notifyListeners();

    if (_icloudSyncEnabled) {
      await pullFromICloud();
    }
  }

  Future<void> setICloudSyncEnabled(bool enabled) async {
    _icloudSyncEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('icloud_sync_enabled', enabled);
    notifyListeners();

    if (enabled) {
      await pushAllToICloud();
      await pullFromICloud();
      triggerToast("iCloud同步已开启");
    } else {
      triggerToast("iCloud同步已关闭");
    }
  }

  Future<bool> clearAllICloudData() async {
    if (!ICloudService.isApplePlatform) return false;
    isLoading = true;
    notifyListeners();
    try {
      final success = await ICloudService.clear();
      if (success) {
        final prefs = await SharedPreferences.getInstance();
        final keys = prefs.getKeys();
        for (final key in keys) {
          if (key.endsWith(kSyncTimestampSuffix)) {
            await prefs.remove(key);
          }
        }
      }
      return success;
    } catch (e) {
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleICloudSyncOption(String option, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final ts = _nowTimestamp();

    Future<void> pushWithTs(String key, String data) async {
      await ICloudService.setString(key, data);
      await ICloudService.setString(_tsKey(key), ts);
      await prefs.setString(_tsKey(key), ts);
    }

    switch (option) {
      case 'custom_courses':
        _icloudSyncCustomCourses = value;
        await prefs.setBool('icloud_sync_custom_courses', value);
        if (_icloudSyncEnabled && value) {
          for (var id in userProfiles) {
            final data = prefs.getString('${kCustomCoursesKey}_$id');
            if (data != null) {
              await pushWithTs('${kCustomCoursesKey}_$id', data);
            }
          }
        }
        break;
      case 'course_colors':
        _icloudSyncCourseColors = value;
        await prefs.setBool('icloud_sync_course_colors', value);
        if (_icloudSyncEnabled && value) {
          for (var id in userProfiles) {
            final colorData = prefs.getString('${kCourseColorMapKey}_$id');
            if (colorData != null) {
              await pushWithTs('${kCourseColorMapKey}_$id', colorData);
            }
            final customColorData = prefs.getString('${kCourseCustomColorMapKey}_$id');
            if (customColorData != null) {
              await pushWithTs('${kCourseCustomColorMapKey}_$id', customColorData);
            }
          }
        }
        break;
      case 'hidden_courses':
        _icloudSyncHiddenCourses = value;
        await prefs.setBool('icloud_sync_hidden_courses', value);
        if (_icloudSyncEnabled && value) {
          for (var id in userProfiles) {
            final data = prefs.getString('${kHiddenRulesKey}_$id');
            if (data != null) {
              await pushWithTs('${kHiddenRulesKey}_$id', data);
            }
          }
        }
        break;
      case 'theme':
        _icloudSyncTheme = value;
        await prefs.setBool('icloud_sync_theme', value);
        if (_icloudSyncEnabled && value) {
          final themeStr = prefs.getString(kThemeSettingsKey);
          if (themeStr != null) {
            await pushWithTs(kThemeSettingsKey, themeStr);
          }
        }
        break;
      case 'profiles':
        _icloudSyncProfiles = value;
        await prefs.setBool('icloud_sync_profiles', value);
        if (_icloudSyncEnabled && value) {
          await ICloudService.setString('user_profiles_list', jsonEncode(userProfiles));
          if (currentId.isNotEmpty) {
            await ICloudService.setString('saved_id', currentId);
          }
          for (var id in userProfiles) {
            final cache = await _readScheduleCache(id);
            if (cache != null) {
              await pushWithTs('schedule_cache_$id', cache);
            }
          }
        }
        break;
    }
    notifyListeners();
  }

  Future<void> pullFromICloud() async {
    if (!ICloudService.isApplePlatform) return;
    final available = await ICloudService.isAvailable();
    if (!available) return;

    // 强制同步，确保读取到最新的云端数据
    await ICloudService.synchronize();

    final cloudData = await ICloudService.getAllData();
    if (cloudData.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    bool changed = false;

    // 辅助方法：判断云端时间戳是否比本地更新
    bool isCloudNewer(String key) {
      final cloudTsStr = cloudData[_tsKey(key)];
      final localTsStr = prefs.getString(_tsKey(key));

      // 云端无时间戳 → 旧数据，跳过；本地无时间戳 → 首次拉取，采用云端
      if (cloudTsStr == null) return false;
      if (localTsStr == null) return true;

      final cloudTs = int.tryParse(cloudTsStr) ?? 0;
      final localTs = int.tryParse(localTsStr) ?? 0;
      return cloudTs > localTs;
    }

    // 辅助方法：保存云端时间戳到本地
    Future<void> saveCloudTimestamp(String key) async {
      final cloudTsStr = cloudData[_tsKey(key)];
      if (cloudTsStr != null) {
        await prefs.setString(_tsKey(key), cloudTsStr);
      }
    }

    // 1. 同步多用户档案与缓存（档案列表使用合并策略，不走时间戳）
    if (_icloudSyncProfiles) {
      if (cloudData.containsKey('user_profiles_list')) {
        final List<String> cloudProfiles = List<String>.from(jsonDecode(cloudData['user_profiles_list']!));
        if (cloudProfiles.isNotEmpty) {
          final Set<String> merged = {...userProfiles, ...cloudProfiles};
          if (merged.length != userProfiles.length) {
            userProfiles = merged.toList();
            await prefs.setStringList('user_profiles_list', userProfiles);
            changed = true;
          }
        }
      }
      for (var id in userProfiles) {
        final cacheKey = 'schedule_cache_$id';
        if (cloudData.containsKey(cacheKey) && isCloudNewer(cacheKey)) {
          final cloudCache = cloudData[cacheKey]!;
          await _writeScheduleCacheLocal(id, cloudCache);
          await saveCloudTimestamp(cacheKey);
          changed = true;
        }
      }
    }

    // 2. 同步主题
    if (_icloudSyncTheme) {
      if (cloudData.containsKey(kThemeSettingsKey) && isCloudNewer(kThemeSettingsKey)) {
        final cloudThemeStr = cloudData[kThemeSettingsKey]!;
        await prefs.setString(kThemeSettingsKey, cloudThemeStr);
        await saveCloudTimestamp(kThemeSettingsKey);
        try {
          currentTheme = ThemeSettings.fromJson(jsonDecode(cloudThemeStr));
          changed = true;
        } catch (_) {}
      }
    }

    // 3. 用户专属数据（自定义行程、颜色、隐藏课表）
    for (var id in userProfiles) {
      if (_icloudSyncCustomCourses) {
        final key = '${kCustomCoursesKey}_$id';
        if (cloudData.containsKey(key) && isCloudNewer(key)) {
          final cloudDataStr = cloudData[key]!;
          await prefs.setString(key, cloudDataStr);
          await saveCloudTimestamp(key);
          if (id == currentId) {
            await prefs.setString(kCustomCoursesKey, cloudDataStr);
            customCourses = List<dynamic>.from(jsonDecode(cloudDataStr))
                .map((e) => CustomCourse.fromJson(e))
                .toList();
          }
          changed = true;
        }
      }

      if (_icloudSyncCourseColors) {
        final colorKey = '${kCourseColorMapKey}_$id';
        if (cloudData.containsKey(colorKey) && isCloudNewer(colorKey)) {
          final cloudColorStr = cloudData[colorKey]!;
          await prefs.setString(colorKey, cloudColorStr);
          await saveCloudTimestamp(colorKey);
          if (id == currentId) {
            await prefs.setString(kCourseColorMapKey, cloudColorStr);
            final Map<String, dynamic> jsonMap = jsonDecode(cloudColorStr);
            courseColorMap = jsonMap.map((k, v) => MapEntry(k, v as int));
          }
          changed = true;
        }

        final customColorKey = '${kCourseCustomColorMapKey}_$id';
        if (cloudData.containsKey(customColorKey) && isCloudNewer(customColorKey)) {
          final cloudCustomColorStr = cloudData[customColorKey]!;
          await prefs.setString(customColorKey, cloudCustomColorStr);
          await saveCloudTimestamp(customColorKey);
          if (id == currentId) {
            await prefs.setString(kCourseCustomColorMapKey, cloudCustomColorStr);
            final Map<String, dynamic> jsonMap = jsonDecode(cloudCustomColorStr);
            courseCustomColorMap = jsonMap.map((k, v) => MapEntry(k, v as String));
          }
          changed = true;
        }
      }

      if (_icloudSyncHiddenCourses) {
        final key = '${kHiddenRulesKey}_$id';
        if (cloudData.containsKey(key) && isCloudNewer(key)) {
          final cloudDataStr = cloudData[key]!;
          await prefs.setString(key, cloudDataStr);
          await saveCloudTimestamp(key);
          if (id == currentId) {
            await prefs.setString(kHiddenRulesKey, cloudDataStr);
            hiddenRules = List<dynamic>.from(jsonDecode(cloudDataStr))
                .map((e) => HiddenRule.fromJson(e))
                .toList();
          }
          changed = true;
        }
      }
    }

    if (changed) {
      if (currentId.isNotEmpty) {
        await loadFromCache(isInitial: false);
        await loadAllProfilesData();
      }
      notifyListeners();
      if (!kIsWeb) {
        await WidgetService.syncToWidget(this);
      }
    }
  }

  Future<void> pushAllToICloud() async {
    if (!ICloudService.isApplePlatform || !_icloudSyncEnabled) return;
    final available = await ICloudService.isAvailable();
    if (!available) return;

    final prefs = await SharedPreferences.getInstance();
    final ts = _nowTimestamp();

    // 辅助方法：同时写入 iCloud 和本地时间戳
    Future<void> pushWithTimestamp(String key, String value) async {
      await ICloudService.setString(key, value);
      await ICloudService.setString(_tsKey(key), ts);
      await prefs.setString(_tsKey(key), ts);
    }

    // 1. 同步多用户档案与当前账号 ID
    if (_icloudSyncProfiles) {
      await ICloudService.setString('user_profiles_list', jsonEncode(userProfiles));
      if (currentId.isNotEmpty) {
        await ICloudService.setString('saved_id', currentId);
      }
      for (var id in userProfiles) {
        final cache = await _readScheduleCache(id);
        if (cache != null) {
          await pushWithTimestamp('schedule_cache_$id', cache);
        }
      }
    }

    // 2. 同步主题
    if (_icloudSyncTheme) {
      final themeStr = prefs.getString(kThemeSettingsKey);
      if (themeStr != null) {
        await pushWithTimestamp(kThemeSettingsKey, themeStr);
      }
    }

    // 3. 用户专属数据（自定义行程、颜色、隐藏课表）
    for (var id in userProfiles) {
      if (_icloudSyncCustomCourses) {
        final data = prefs.getString('${kCustomCoursesKey}_$id');
        if (data != null) {
          await pushWithTimestamp('${kCustomCoursesKey}_$id', data);
        }
      }
      if (_icloudSyncCourseColors) {
        final colorData = prefs.getString('${kCourseColorMapKey}_$id');
        if (colorData != null) {
          await pushWithTimestamp('${kCourseColorMapKey}_$id', colorData);
        }
        final customColorData = prefs.getString('${kCourseCustomColorMapKey}_$id');
        if (customColorData != null) {
          await pushWithTimestamp('${kCourseCustomColorMapKey}_$id', customColorData);
        }
      }
      if (_icloudSyncHiddenCourses) {
        final data = prefs.getString('${kHiddenRulesKey}_$id');
        if (data != null) {
          await pushWithTimestamp('${kHiddenRulesKey}_$id', data);
        }
      }
    }
  }

  Future<bool> restoreEverythingFromCloud() async {
    if (!ICloudService.isApplePlatform) return false;
    final available = await ICloudService.isAvailable();
    if (!available) {
      triggerToast("iCloud不可用，请检查设置");
      return false;
    }

    isLoading = true;
    notifyListeners();

    try {
      final cloudData = await ICloudService.getAllData();
      if (cloudData.isEmpty) {
        triggerToast("云端暂无备份数据");
        return false;
      }

      final prefs = await SharedPreferences.getInstance();

      // 自动开启同步开关
      _icloudSyncEnabled = true;
      await prefs.setBool('icloud_sync_enabled', true);

      // 1. 恢复多用户档案列表
      if (cloudData.containsKey('user_profiles_list')) {
        final List<dynamic> list = jsonDecode(cloudData['user_profiles_list']!);
        userProfiles = list.map((e) => e.toString()).toList();
        await prefs.setStringList('user_profiles_list', userProfiles);
      }

      // 2. 恢复各个用户的课表缓存
      for (var id in userProfiles) {
        final key = 'schedule_cache_$id';
        if (cloudData.containsKey(key)) {
          await _writeScheduleCache(id, cloudData[key]!);
        }
      }

      // 3. 恢复各个用户的数据：自定义行程、颜色、隐藏课程
      for (var id in userProfiles) {
        final customKey = '${kCustomCoursesKey}_$id';
        if (cloudData.containsKey(customKey)) {
          await prefs.setString(customKey, cloudData[customKey]!);
        }

        final colorKey = '${kCourseColorMapKey}_$id';
        if (cloudData.containsKey(colorKey)) {
          await prefs.setString(colorKey, cloudData[colorKey]!);
        }

        final customColorKey = '${kCourseCustomColorMapKey}_$id';
        if (cloudData.containsKey(customColorKey)) {
          await prefs.setString(customColorKey, cloudData[customColorKey]!);
        }

        final hiddenKey = '${kHiddenRulesKey}_$id';
        if (cloudData.containsKey(hiddenKey)) {
          await prefs.setString(hiddenKey, cloudData[hiddenKey]!);
        }
      }

      // 4. 恢复主题
      if (cloudData.containsKey(kThemeSettingsKey)) {
        final themeStr = cloudData[kThemeSettingsKey]!;
        await prefs.setString(kThemeSettingsKey, themeStr);
        try {
          currentTheme = ThemeSettings.fromJson(jsonDecode(themeStr));
        } catch (_) {}
      }

      // 5. 恢复当前登录的 saved_id
      String? targetId;
      if (cloudData.containsKey('saved_id')) {
        targetId = cloudData['saved_id'];
      }
      if ((targetId == null || targetId.isEmpty) && userProfiles.isNotEmpty) {
        targetId = userProfiles.first;
      }

      if (targetId != null && targetId.isNotEmpty) {
        currentId = targetId;
        await prefs.setString(kSavedIdKey, targetId);
        await prefs.setBool('is_logged_in', true);
        
        await loadColorMapForUser(targetId);
        await loadCustomCoursesForUser(targetId);
        await loadHiddenRulesForUser(targetId);
        await loadFromCache(isInitial: true);
        await loadAllProfilesData();
        
        triggerToast("iCloud数据同步成功");
        return true;
      } else {
        triggerToast("iCloud恢复成功，但未找到关联账户");
        return true;
      }
    } catch (e) {
      debugPrint("Error restoring from iCloud: $e");
      triggerToast("iCloud同步恢复失败");
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}

class DateFormat {
  final String pattern;
  DateFormat(this.pattern);

  String format(DateTime date) {
    String result = pattern;
    result = result.replaceAll('yyyy', date.year.toString());
    result = result.replaceAll('MM', date.month.toString().padLeft(2, '0'));
    result = result.replaceAll('M', date.month.toString());
    result = result.replaceAll('dd', date.day.toString().padLeft(2, '0'));
    result = result.replaceAll('d', date.day.toString());
    return result;
  }

  DateTime parse(String input) {
    if (pattern == "yyyy-MM-dd'T'HH:mm:ss") {
      return DateTime.parse(input);
    }
    return DateTime.parse(input);
  }
}
