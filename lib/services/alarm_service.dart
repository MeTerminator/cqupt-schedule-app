import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/schedule_model.dart';
import '../view_models/schedule_view_model.dart';

class AlarmService {
  static const _channel = MethodChannel('top.met6.cquptschedule/alarm');

  static const String _kLead8Key = "alarm_lead_minutes_8";
  static const String _kLead10Key = "alarm_lead_minutes_10";
  static const String _kAlarmsListKey = "scheduled_alarms_list";

  /// 请求闹钟与通知权限
  static Future<bool> requestPermission() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('requestPermission');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// 获取所有未来处于激活状态的闹钟
  static Future<List<Map<String, dynamic>>> getScheduledAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_kAlarmsListKey);
    if (jsonStr == null || jsonStr.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // 过滤掉已经过期的闹钟
      final List<Map<String, dynamic>> activeAlarms = decoded
          .map((e) => Map<String, dynamic>.from(e))
          .where((item) => (item['timeInMillis'] as num).toInt() > now)
          .toList();

      // 如果有被过滤掉的过期闹钟，同步更新一次 SharedPreferences
      if (activeAlarms.length < decoded.length) {
        await prefs.setString(_kAlarmsListKey, jsonEncode(activeAlarms));
      }

      // 按触发时间升序排序
      activeAlarms.sort((a, b) => (a['timeInMillis'] as num).compareTo(b['timeInMillis'] as num));
      return activeAlarms;
    } catch (e) {
      return [];
    }
  }

  /// 保存单个闹钟到 SharedPreferences
  static Future<void> _saveAlarmToPrefs(Map<String, dynamic> alarm) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getScheduledAlarms();
    
    // 移除相同 ID 的旧闹钟（防止重复）
    current.removeWhere((item) => item['id'] == alarm['id']);
    current.add(alarm);
    
    await prefs.setString(_kAlarmsListKey, jsonEncode(current));
  }

  /// 批量保存多个闹钟到 SharedPreferences
  static Future<void> _saveAlarmsToPrefs(List<Map<String, dynamic>> alarms) async {
    if (alarms.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final current = await getScheduledAlarms();

    final alarmIds = alarms.map((e) => e['id']).toSet();
    current.removeWhere((item) => alarmIds.contains(item['id']));
    current.addAll(alarms);

    await prefs.setString(_kAlarmsListKey, jsonEncode(current));
  }

  /// 从 SharedPreferences 移除指定 ID 的闹钟记录
  static Future<void> _removeAlarmFromPrefs(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getScheduledAlarms();
    
    final initialLength = current.length;
    current.removeWhere((item) => item['id'] == id);
    
    if (current.length < initialLength) {
      await prefs.setString(_kAlarmsListKey, jsonEncode(current));
    }
  }

  /// 清空 SharedPreferences 中的所有闹钟记录
  static Future<void> _clearAlarmsFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAlarmsListKey);
  }

  /// 获取早八的提前时间（分钟，默认 30 分钟）
  static Future<int> getLeadMinutes8() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kLead8Key) ?? 30;
  }

  /// 设置早八的提前时间
  static Future<void> setLeadMinutes8(int mins) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLead8Key, mins);
  }

  /// 获取早十的提前时间（分钟，默认 30 分钟）
  static Future<int> getLeadMinutes10() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kLead10Key) ?? 30;
  }

  /// 设置早十的提前时间
  static Future<void> setLeadMinutes10(int mins) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLead10Key, mins);
  }

  /// 设置单个课程闹钟
  static Future<String> scheduleSingleCourseAlarm({
    required CourseInstance course,
    required DateTime courseDateTime,
    required int leadMinutes,
  }) async {
    // 检查并请求权限
    final hasPerm = await requestPermission();
    if (!hasPerm) return 'no_permission';

    // 计算闹钟时间 = 课程开始时间 - 提前量
    final alarmTime = courseDateTime.subtract(Duration(minutes: leadMinutes));
    if (alarmTime.isBefore(DateTime.now())) {
      return 'past'; // 闹钟时间已过
    }

    // 检查是否有重复时间的闹钟，防止设置重复时间的闹钟
    final activeAlarms = await getScheduledAlarms();
    final hasDuplicateTime = activeAlarms.any((alarm) =>
      (alarm['timeInMillis'] as num).toInt() == alarmTime.millisecondsSinceEpoch
    );
    if (hasDuplicateTime) {
      return 'duplicate'; // 重复时间
    }

    final alarmMap = {
      'id': '${course.id}_$leadMinutes', // 使用 leadMinutes 区分，允许单节课程设置多个闹钟
      'title': course.course,
      'timeInMillis': alarmTime.millisecondsSinceEpoch,
      'leadMinutes': leadMinutes,
    };

    try {
      await _channel.invokeMethod('scheduleAlarms', [alarmMap]);
      await _saveAlarmToPrefs(alarmMap);
      return 'success';
    } catch (e) {
      return 'error';
    }
  }

  /// 取消指定 ID 的闹钟（支持以 ID 匹配或以 ID 为前缀的批量匹配）
  static Future<void> cancelAlarm(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = await getScheduledAlarms();
      
      // 寻找所有匹配该 ID 或者以该 ID 为前缀的已登记闹钟（例如：course.id 或 course.id_15）
      final alarmsToCancel = current
          .where((item) =>
              (item['id'] as String) == id ||
              (item['id'] as String).startsWith('${id}_'))
          .toList();
      
      if (alarmsToCancel.isEmpty) return;

      final cancelIds = alarmsToCancel.map((e) => e['id'] as String).toSet();

      // 在原生端逐一取消
      for (final alarmId in cancelIds) {
        await _channel.invokeMethod('cancelAlarm', alarmId);
      }

      // 批量从 SharedPreferences 中移除，提高性能与数据一致性
      final updated = current.where((item) => !cancelIds.contains(item['id'] as String)).toList();
      await prefs.setString(_kAlarmsListKey, jsonEncode(updated));
    } catch (e) {
      // 忽略错误
    }
  }

  /// 清除所有闹钟
  static Future<void> clearAllAlarms() async {
    try {
      await _channel.invokeMethod('clearAllAlarms');
      await _clearAlarmsFromPrefs();
    } catch (e) {
      // 忽略错误
    }
  }

  /// 一键批量设置指定周的所有早八/早十闹钟
  static Future<int> scheduleMorningAlarmsForWeek({
    required ScheduleViewModel viewModel,
    required int week,
    required int leadMinutes8,
    required int leadMinutes10,
  }) async {
    // 请求权限
    final hasPerm = await requestPermission();
    if (!hasPerm) return 0;
    if (viewModel.scheduleData == null) return 0;

    // 获取本学期第一周的周一日期
    final startStr = viewModel.scheduleData!.week1Monday.substring(0, 10);
    DateTime firstMonday;
    try {
      firstMonday = DateTime.parse(startStr);
    } catch (e) {
      return 0;
    }

    final List<Map<String, dynamic>> alarmsToSchedule = [];

    // 遍历该周的星期一到星期日 (day 1-7)
    for (int day = 1; day <= 7; day++) {
      // 计算该天的绝对日期
      final dateOfDay = firstMonday.add(Duration(days: (week - 1) * 7 + (day - 1)));
      
      // 获取该天所有活跃（非隐藏）课程
      final dayCourses = viewModel.allCourses(week).where((c) => c.day == day).toList();

      CourseInstance? morning8Course;
      CourseInstance? morning10Course;

      for (var course in dayCourses) {
        // 判断是否为早八课程（periods 包含 1 或 2，或 startTime 为 08:00）
        if (course.periods.contains(1) || course.periods.contains(2) || course.startTime == "08:00") {
          morning8Course = course;
        }
        // 判断是否为早十课程（periods 包含 3 或 4，或 startTime 为 10:15）
        if (course.periods.contains(3) || course.periods.contains(4) || course.startTime == "10:15") {
          morning10Course = course;
        }
      }

      DateTime? alarmTime;
      String label = "";
      int leadMinutes = 0;

      // 规则：
      // 1. 若当天有早八课程，只设置早八闹钟
      // 2. 若当天没有早八，但有早十课程，只设置早十闹钟
      // 3. 若当前上午没有课程，不设置闹钟
      if (morning8Course != null) {
        final baseTime = DateTime(dateOfDay.year, dateOfDay.month, dateOfDay.day, 8, 0);
        leadMinutes = leadMinutes8;
        alarmTime = baseTime.subtract(Duration(minutes: leadMinutes8));
        label = morning8Course.course;
      } else if (morning10Course != null) {
        final baseTime = DateTime(dateOfDay.year, dateOfDay.month, dateOfDay.day, 10, 15);
        leadMinutes = leadMinutes10;
        alarmTime = baseTime.subtract(Duration(minutes: leadMinutes10));
        label = morning10Course.course;
      }

      // 仅在闹钟时间处于未来时进行调度
      if (alarmTime != null && alarmTime.isAfter(DateTime.now())) {
        alarmsToSchedule.add({
          'id': 'morning_alarm_${week}_$day',
          'title': label,
          'timeInMillis': alarmTime.millisecondsSinceEpoch,
          'leadMinutes': leadMinutes,
        });
      }
    }

    if (alarmsToSchedule.isNotEmpty) {
      try {
        await _channel.invokeMethod('scheduleAlarms', alarmsToSchedule);
        await _saveAlarmsToPrefs(alarmsToSchedule);
      } catch (e) {
        return 0;
      }
    }

    return alarmsToSchedule.length;
  }
}
