import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lunar/lunar.dart';
import '../view_models/desktop_widget_view_model.dart';
import '../models/schedule_model.dart';
import '../view_models/schedule_view_model.dart' hide DateFormat;
import 'package:intl/intl.dart';

class DeskDockWidgetView extends StatefulWidget {
  final String studentId;

  const DeskDockWidgetView({super.key, required this.studentId});

  @override
  State<DeskDockWidgetView> createState() => _DeskDockWidgetViewState();
}

class _DeskDockWidgetViewState extends State<DeskDockWidgetView> {
  late DesktopWidgetViewModel _viewModel;
  late Timer _clockTimer;
  late Timer _refreshTimer;
  final ValueNotifier<DateTime> _timeNotifier = ValueNotifier(DateTime.now());

  @override
  void initState() {
    super.initState();
    _viewModel = DesktopWidgetViewModel(studentId: widget.studentId);
    _viewModel.refreshAll();

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _timeNotifier.value = DateTime.now();
    });

    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      _viewModel.refreshAll();
    });

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
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
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark mode default
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
                  return _buildDeskDockLayout(vm);
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDeskDockLayout(DesktopWidgetViewModel vm) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Base width for scaling is 800 (standard phone landscape)
        final double scale = (constraints.maxWidth / 800).clamp(0.8, 2.0);

        return Column(
          children: [
            // Top Section
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  // Time Area (3 cols out of 5)
                  Expanded(
                    flex: 3,
                    child: _ClockArea(
                      timeNotifier: _timeNotifier,
                      scale: scale,
                    ),
                  ),
                  // Sidebar 1 (1 col out of 5)
                  Expanded(
                    flex: 1,
                    child: _SidebarLeft(
                      vm: vm,
                      timeNotifier: _timeNotifier,
                      scale: scale,
                    ),
                  ),
                  // Sidebar 2 (1 col out of 5)
                  Expanded(
                    flex: 1,
                    child: _SidebarRight(vm: vm, scale: scale),
                  ),
                ],
              ),
            ),
            // Bottom Bar Section
            Expanded(flex: 1, child: _BottomCourseBar(scale: scale)),
          ],
        );
      },
    );
  }
}

/// --- Specialized Sub-widgets for performance ---

class _ClockArea extends StatelessWidget {
  final ValueNotifier<DateTime> timeNotifier;
  final double scale;
  const _ClockArea({required this.timeNotifier, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Colors.white, width: 0.5)),
      ),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(20 * scale),
          child: FittedBox(
            fit: BoxFit.contain, // Fill available space
            child: ValueListenableBuilder<DateTime>(
              valueListenable: timeNotifier,
              builder: (context, now, child) {
                return Text(
                  DateFormat('HH:mm').format(now),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 200, // Large base size for FittedBox
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    letterSpacing: -5 * scale,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarLeft extends StatelessWidget {
  final DesktopWidgetViewModel vm;
  final ValueNotifier<DateTime> timeNotifier;
  final double scale;

  const _SidebarLeft({
    required this.vm,
    required this.timeNotifier,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final data = vm.weatherData ?? {};
    final current = data['current'] ?? {};
    final forecastDaily = data['forecastDaily'] ?? {};

    final temp = current['temperature']?['value']?.toString() ?? '--';
    final weatherDesc =
        current['weatherDesc']?.toString() ??
        _getWeatherDescription(current['weather']?.toString() ?? '0');

    List temperatures = forecastDaily['temperature']?['value'] ?? [];
    final todayForecastFrom = temperatures.isNotEmpty
        ? temperatures[0]['from']
        : '--';
    final todayForecastTo = temperatures.isNotEmpty
        ? temperatures[0]['to']
        : '--';

    final aqiValue = data['aqi']?['aqi']?.toString() ?? '--';
    final minutelyDesc =
        data['minutely']?['probability']?['probabilityDesc']?.toString() ??
        data['minutely']?['precipitation']?['shortDescription']?.toString() ??
        '';

    List<String> tags = [];
    if (aqiValue != '--') tags.add('AQI $aqiValue');
    if (data['aqi']?['aqiLevelName'] != null) {
      tags.add(data['aqi']?['aqiLevelName']);
    }
    if (data['aqi']?['primary'] != null && data['aqi']?['primary'] != '') {
      tags.add('首要:${data['aqi']?['primary']}');
    }

    // Rain and snow tags logic: Check current weather code and minutely precipitation status
    final currentCode = current['weather']?.toString() ?? '0';
    final intCode = int.tryParse(currentCode) ?? -1;
    bool isRainingNow = false;
    bool isSnowingNow = false;
    if (intCode != -1) {
      // Xiaomi/Meteo weather codes: 3-12, 19, 21-25 are rain related; 13-17, 26-28 are snow; 6 is sleet.
      isRainingNow =
          (intCode >= 3 && intCode <= 12) ||
          intCode == 19 ||
          (intCode >= 21 && intCode <= 25) ||
          intCode == 6;
      isSnowingNow =
          (intCode >= 13 && intCode <= 17) ||
          (intCode >= 26 && intCode <= 28) ||
          intCode == 6;
    }

    final isPrecipShow = data['minutely']?['precipitation']?['isShow'] == true;
    if (isRainingNow || (isPrecipShow && minutelyDesc.contains('雨'))) {
      tags.add('有雨');
    }
    if (isSnowingNow || (isPrecipShow && minutelyDesc.contains('雪'))) {
      tags.add('有雪');
    }

    final alerts = data['alerts'] as List? ?? [];
    for (var alert in alerts) {
      if (alert['type'] != null) tags.add(alert['type'].toString());
    }

    return Container(
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Colors.white, width: 0.5)),
      ),
      padding: EdgeInsets.all(8 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ValueListenableBuilder<DateTime>(
            valueListenable: timeNotifier,
            builder: (context, now, child) {
              final weekdays = [
                '星期日',
                '星期一',
                '星期二',
                '星期三',
                '星期四',
                '星期五',
                '星期六',
              ];
              final solar = Solar.fromDate(now);
              final lunar = Lunar.fromSolar(solar);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('yyyy/MM/dd').format(now),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20 * scale,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    weekdays[now.weekday % 7],
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16 * scale,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4 * scale),
                  Text(
                    '农历 ${lunar.getMonthInChinese()}月${lunar.getDayInChinese()}',
                    style: TextStyle(color: Colors.white, fontSize: 14 * scale),
                  ),
                  Text(
                    '${lunar.getYearInGanZhi()}年',
                    style: TextStyle(color: Colors.white, fontSize: 14 * scale),
                  ),
                  Text(
                    '${lunar.getMonthInGanZhi()}月 ${lunar.getDayInGanZhi()}日',
                    style: TextStyle(color: Colors.white, fontSize: 14 * scale),
                  ),
                ],
              );
            },
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 2 * scale),
            child: const Divider(color: Colors.white),
          ),
          Text(
            '$temp°C',
            style: TextStyle(
              color: Colors.white,
              fontSize: 44 * scale,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          Text(
            '$weatherDesc 最高$todayForecastFrom°C 最低$todayForecastTo°C',
            style: TextStyle(color: Colors.white, fontSize: 12 * scale),
          ),
          SizedBox(height: 6 * scale),
          Wrap(
            spacing: 4 * scale,
            runSpacing: 4 * scale,
            children: tags
                .map(
                  (t) => Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 6 * scale,
                      vertical: 2 * scale,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(4 * scale),
                    ),
                    child: Text(
                      t,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11 * scale,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const Spacer(),
          if (minutelyDesc.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 4.0 * scale),
              child: Text(
                minutelyDesc,
                style: TextStyle(color: Colors.white70, fontSize: 11 * scale),
              ),
            ),
        ],
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
}

class _SidebarRight extends StatelessWidget {
  final DesktopWidgetViewModel vm;
  final double scale;

  const _SidebarRight({required this.vm, required this.scale});

  @override
  Widget build(BuildContext context) {
    final data = vm.weatherData ?? {};
    final current = data['current'] ?? {};
    final forecastDaily = data['forecastDaily'] ?? {};
    final indices = data['indices']?.containsKey('indices') == true
        ? data['indices']['indices']
        : [];

    final humidity = current['humidity']?['value']?.toString() ?? '--';
    final feelsLike = current['feelsLike']?['value']?.toString() ?? '--';
    final windDirVal =
        double.tryParse(
          current['wind']?['direction']?['value']?.toString() ?? '0',
        ) ??
        0;
    final windSpeedVal =
        double.tryParse(
          current['wind']?['speed']?['value']?.toString() ?? '0',
        ) ??
        0;
    final windLevel = (windSpeedVal / 3.6).round();
    final windDesc =
        current['wind']?['direction']?['desc']?.toString() ??
        '${_getWindDirText(windDirVal.round())}$windLevel级';
    final pressure = current['pressure']?['value']?.toString() ?? '--';

    List temperatures = forecastDaily['temperature']?['value'] ?? [];
    List weathers = forecastDaily['weather']?['value'] ?? [];
    List sunRiseSet = forecastDaily['sunRiseSet']?['value'] ?? [];

    String sunset = '--:--';
    if (sunRiseSet.isNotEmpty && sunRiseSet[0]['to'] != null) {
      try {
        final parsed = DateTime.parse(sunRiseSet[0]['to']);
        sunset = DateFormat('HH:mm').format(parsed);
      } catch (_) {}
    }

    List<Map<String, dynamic>> forecasts = [];
    final days = ['今天', '明天', '后天'];
    for (int i = 0; i < 3 && i < temperatures.length; i++) {
      String dayWeatherCode = '0';
      if (i < weathers.length && weathers[i]['from'] != null) {
        dayWeatherCode = weathers[i]['from'].toString();
      }
      forecasts.add({
        'day': days[i],
        'weather': _getWeatherDescription(dayWeatherCode),
        'low': temperatures[i]['to'],
        'high': temperatures[i]['from'],
      });
    }

    String uvIndex = '--';
    if (indices is List) {
      for (var idx in indices) {
        if (idx['type'] == 'uvIndex') {
          uvIndex = idx['value']?.toString() ?? '--';
          break;
        }
      }
    }

    return Container(
      padding: EdgeInsets.all(8 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: forecasts
                .map(
                  (f) => Padding(
                    padding: EdgeInsets.only(bottom: 2 * scale),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SizedBox(
                          width: 32 * scale,
                          child: Text(
                            f['day'],
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13 * scale,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              f['weather'],
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13 * scale,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          '${f['low']}° - ${f['high']}°',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 13 * scale,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 4 * scale),
            child: const Divider(color: Colors.white),
          ),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 1.2,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildIndexItem('体感', '$feelsLike°C', true, true, scale),
                _buildIndexItem('湿度', '$humidity%', false, true, scale),
                _buildIndexItem('紫外线', uvIndex, true, true, scale),
                _buildIndexItem('风向', windDesc, false, true, scale),
                _buildIndexItem('气压', pressure, true, false, scale),
                _buildIndexItem('日落', sunset, false, false, scale),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndexItem(
    String label,
    String value,
    bool right,
    bool bottom,
    double scale,
  ) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          right: right
              ? const BorderSide(color: Colors.white, width: 0.5)
              : BorderSide.none,
          bottom: bottom
              ? const BorderSide(color: Colors.white, width: 0.5)
              : BorderSide.none,
        ),
      ),
      padding: EdgeInsets.symmetric(
        vertical: 2.0 * scale,
        horizontal: 4.0 * scale,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey, fontSize: 11 * scale),
          ),
          SizedBox(height: 1 * scale),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 15 * scale,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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
}

class _BottomCourseBar extends StatelessWidget {
  final double scale;
  const _BottomCourseBar({required this.scale});

  @override
  Widget build(BuildContext context) {
    final vm = Provider.of<DesktopWidgetViewModel>(context);
    final svm = Provider.of<ScheduleViewModel>(context);
    final topCourse = vm.getTopCourse(svm);
    final listCourses = vm.getListCourses(svm);

    List<CourseInstance> allCourses = [];
    if (topCourse != null) allCourses.add(topCourse);
    allCourses.addAll(listCourses);

    if (allCourses.isEmpty) {
      return Center(
        child: Text(
          '暂无后续课程',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16 * scale,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white, width: 0.5)),
      ),
      child: Row(
        children: allCourses.take(5).map((c) {
          bool isActive =
              topCourse != null &&
              c.id == topCourse.id &&
              svm.isCourseOngoing(c);
          bool isTomorrow = vm.isTomorrow(c, svm);

          return Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: const Border(
                  right: BorderSide(color: Colors.white, width: 0.5),
                ),
                color: isActive ? Colors.grey[900] : Colors.black,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: 16 * scale,
                vertical: 8 * scale,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.course,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18 * scale,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isTomorrow)
                        Container(
                          margin: EdgeInsets.only(left: 4 * scale),
                          width: 6 * scale,
                          height: 6 * scale,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 4 * scale),
                  Text(
                    '${c.startTime}-${c.endTime} | ${c.location}',
                    style: TextStyle(color: Colors.grey, fontSize: 12 * scale),
                  ),
                  if (isActive) ...[
                    SizedBox(height: 6 * scale),
                    Container(
                      height: 6 * scale,
                      width: double.infinity,
                      color: Colors.grey[800],
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: vm.getProgress(c),
                        child: Container(color: Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
