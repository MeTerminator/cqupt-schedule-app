import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../view_models/desktop_widget_view_model.dart';
import '../models/schedule_model.dart';
import '../view_models/schedule_view_model.dart' hide DateFormat;
import 'package:intl/intl.dart';

class DesktopWidgetView extends StatefulWidget {
  final String studentId;

  const DesktopWidgetView({super.key, required this.studentId});

  @override
  State<DesktopWidgetView> createState() => _DesktopWidgetViewState();
}

class _DesktopWidgetViewState extends State<DesktopWidgetView> {
  late DesktopWidgetViewModel _viewModel;
  late Timer _clockTimer;
  late Timer _refreshTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _viewModel = DesktopWidgetViewModel(studentId: widget.studentId);
    _viewModel.refreshAll();

    // 每一秒更新一次时钟
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _now = DateTime.now();
      });
    });

    // 每2分钟刷新一次数据
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      _viewModel.refreshAll();
    });

    // 全屏沉浸模式
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // 强制黑色背景的状态栏
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _refreshTimer.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: ChangeNotifierProvider.value(
        value: _viewModel,
        child: Consumer<DesktopWidgetViewModel>(
          builder: (context, vm, child) {
            if (vm.isLoading) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }

            return SafeArea(
              child: OrientationBuilder(
                builder: (context, orientation) {
                  if (orientation == Orientation.portrait) {
                    return _buildPortrait(vm);
                  } else {
                    return _buildLandscape(vm);
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPortrait(DesktopWidgetViewModel vm) {
    final svm = Provider.of<ScheduleViewModel>(context);
    final top = vm.getTopCourse(svm);
    final list = vm.getListCourses(svm);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalHeight = constraints.maxHeight;
        // 增加保守冗余，防止大圆角手机底部溢出
        // 估算固定占用空间：Clock, Weather, Header, TopCard, 边距
        // 约为 110 + 60 + 40 + 140 + 50 = 400
        final fixedHeight = 400.0;
        final availableHeight = totalHeight - fixedHeight;
        // 每项高度估算约为 82，确保在主流手机上能显示约 5 节课
        final itemsToTake = (availableHeight / 82).floor().clamp(
          0,
          list.length,
        );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildClock(fontSize: 100),
              const SizedBox(height: 2),
              _buildWeather(vm),
              const SizedBox(height: 16),
              _buildCurriculumHeader(svm),
              const SizedBox(height: 8),
              _buildTopCard(vm, svm, top),
              ...list
                  .take(itemsToTake)
                  .map((c) => _buildCourseItem(vm, svm, c)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLandscape(DesktopWidgetViewModel vm) {
    final svm = Provider.of<ScheduleViewModel>(context);
    final top = vm.getTopCourse(svm);
    final list = vm.getListCourses(svm);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalHeight = constraints.maxHeight;
        // 横屏模式估算：Header(40) + TopCard(140) + Padding(50) = 230
        final fixedHeight = 200.0;
        final availableHeight = totalHeight - fixedHeight;
        final itemsToTake = (availableHeight / 82).floor().clamp(
          0,
          list.length,
        );

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧：日期与课表
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCurriculumHeader(svm),
                    const SizedBox(height: 12),
                    _buildTopCard(vm, svm, top),
                    ...list
                        .take(itemsToTake)
                        .map((c) => _buildCourseItem(vm, svm, c)),
                  ],
                ),
              ),
              const SizedBox(width: 32),
              // 右侧：时钟与天气
              Expanded(
                flex: 4,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildClock(fontSize: 90),
                    const SizedBox(height: 24),
                    _buildWeather(vm),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClock({required double fontSize}) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        DateFormat('HH:mm').format(_now),
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          fontFamily: 'monospace',
          letterSpacing: -2,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  String _getWeatherDescription(String code) {
    const Map<String, String> codes = {
      '0': '晴',
      '1': '多云',
      '2': '阴',
      '3': '阵雨',
      '4': '雷阵雨',
      '5': '雷阵雨并伴有冰雹',
      '6': '雨夹雪',
      '7': '小雨',
      '8': '中雨',
      '9': '大雨',
      '10': '暴雨',
      '11': '大暴雨',
      '12': '特大暴雨',
      '13': '阵雪',
      '14': '小雪',
      '15': '中雪',
      '16': '大雪',
      '17': '暴雪',
      '18': '雾',
      '19': '冻雨',
      '20': '沙尘暴',
      '21': '小雨-中雨',
      '22': '中雨-大雨',
      '23': '大雨-暴雨',
      '24': '暴雨-大暴雨',
      '25': '大暴雨-特大暴雨',
      '26': '小雪-中雪',
      '27': '中雪-大雪',
      '28': '大雪-暴雪',
      '29': '浮沉',
      '30': '扬沙',
      '31': '强沙尘暴',
      '32': '飑',
      '33': '龙卷风',
      '34': '若高吹雪',
      '35': '轻雾',
      '53': '霾',
      '99': '未知',
    };
    return codes[code] ?? '未知';
  }

  String _getWindDirText(int deg) {
    const directions = ["北", "东北", "东", "东南", "南", "西南", "西", "西北"];
    return directions[(deg ~/ 45) % 8];
  }

  Widget _buildWeather(DesktopWidgetViewModel vm) {
    if (vm.weatherData == null) return const SizedBox.shrink();

    final data = vm.weatherData!;
    final current = data['current'] ?? {};
    final wind = current['wind'] ?? {};

    final String code = current['weather']?.toString() ?? "0";
    final String weatherDesc = _getWeatherDescription(code);
    final String temp = current['temperature']?['value']?.toString() ?? "-";
    final String humidity = current['humidity']?['value']?.toString() ?? "-";

    final int windDeg =
        int.tryParse(wind['direction']?['value']?.toString() ?? '0') ?? 0;
    final double windSpeedRaw =
        double.tryParse(wind['speed']?['value']?.toString() ?? '0') ?? 0;
    final int windLevel = (windSpeedRaw / 3.6).round();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _weatherText(weatherDesc),
            const SizedBox(width: 12),
            _weatherText("$temp℃"),
            const SizedBox(width: 12),
            _weatherText("$humidity%"),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _weatherText("${_getWindDirText(windDeg)}风"),
            const SizedBox(width: 12),
            _weatherText("$windLevel级"),
          ],
        ),
      ],
    );
  }

  Widget _weatherText(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildCurriculumHeader(ScheduleViewModel svm) {
    final nowWeek = svm.calculateCurrentRealWeek();
    final dateStr = DateFormat('yyyy/MM/dd').format(_now);
    final weekday = ["日", "一", "二", "三", "四", "五", "六"][_now.weekday % 7];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "$dateStr 星期$weekday",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          "第 $nowWeek 周",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTopCard(
    DesktopWidgetViewModel vm,
    ScheduleViewModel svm,
    CourseInstance? top,
  ) {
    if (top == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
        ),
        child: const Text(
          "今日及明日无课",
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    final isNow = svm.isCourseOngoing(top);
    final isTomorrowVal = vm.isTomorrow(top, svm);

    final String timeLabel = isNow ? "进行中" : (isTomorrowVal ? "明日未开始" : "未开始");
    final String timeText = isNow
        ? vm.formatRemainingTime(top)
        : vm.formatTimeDiff(top, svm);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  top.course,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                children: [
                  Text(
                    timeText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isTomorrowVal)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Text(
                        "•",
                        style: TextStyle(color: Colors.white, fontSize: 22),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "${top.startTime} - ${top.endTime} · ${top.location}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            timeLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (isNow) ...[
            const SizedBox(height: 12),
            _buildProgressBar(vm.getProgress(top)),
          ],
        ],
      ),
    );
  }

  Widget _buildCourseItem(
    DesktopWidgetViewModel vm,
    ScheduleViewModel svm,
    CourseInstance course,
  ) {
    final isTomorrowVal = vm.isTomorrow(course, svm);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  course.course,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isTomorrowVal)
                const Text(
                  "•",
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            "${course.startTime} - ${course.endTime} · ${course.location}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(double progress) {
    return Container(
      height: 12,
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress,
        child: Container(color: Colors.white),
      ),
    );
  }
}
