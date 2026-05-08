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
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _viewModel = DesktopWidgetViewModel(studentId: widget.studentId);
    _viewModel.refreshAll();

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _now = DateTime.now();
      });
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

  String _getWeatherDescription(String code) {
    const Map<String, String> codes = {
      '0': '晴',
      '1': '多云',
      '2': '阴',
      '3': '阵雨',
      '4': '雷阵雨',
      '5': '雷阵雨伴有冰雹',
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
      '21': '小到中雨',
      '22': '中到大雨',
      '23': '大到暴雨',
      '24': '暴雨到大暴雨',
      '25': '大暴雨到特大暴雨',
      '26': '小到中雪',
      '27': '中到大雪',
      '28': '大到暴雪',
      '29': '浮尘',
      '30': '扬沙',
      '31': '强沙尘暴',
      '53': '霾',
    };
    return codes[code] ?? '未知';
  }

  String _getWindDirText(int deg) {
    const directions = ["北", "东北", "东", "东南", "南", "西南", "西", "西北"];
    return directions[(deg ~/ 45) % 8];
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
    final svm = Provider.of<ScheduleViewModel>(context);
    final topCourse = vm.getTopCourse(svm);
    final listCourses = vm.getListCourses(svm);

    List<CourseInstance> allCourses = [];
    if (topCourse != null) {
      allCourses.add(topCourse);
    }
    allCourses.addAll(listCourses);

    final data = vm.weatherData ?? {};
    final current = data['current'] ?? {};
    final forecastDaily = data['forecastDaily'] ?? {};
    final indices = data['indices']?.containsKey('indices') == true
        ? data['indices']['indices']
        : [];

    // Weather - Current
    final temp = current['temperature']?['value']?.toString() ?? '--';
    final weatherDesc =
        current['weatherDesc']?.toString() ??
        _getWeatherDescription(current['weather']?.toString() ?? '0');
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
        (_getWindDirText(windDirVal.round()) + '$windLevel级');

    final pressure = current['pressure']?['value']?.toString() ?? '--';

    // Daily
    List temperatures = forecastDaily['temperature']?['value'] ?? [];
    List weathers = forecastDaily['weather']?['value'] ?? [];
    List sunRiseSet = forecastDaily['sunRiseSet']?['value'] ?? [];

    final todayForecastFrom = temperatures.isNotEmpty
        ? temperatures[0]['from']
        : '--';
    final todayForecastTo = temperatures.isNotEmpty
        ? temperatures[0]['to']
        : '--';
    final aqiValue = data['aqi']?['aqi']?.toString() ?? '--';

    String sunset = '--:--';
    if (sunRiseSet.isNotEmpty && sunRiseSet[0]['to'] != null) {
      try {
        final parsed = DateTime.parse(sunRiseSet[0]['to']);
        sunset = DateFormat('HH:mm').format(parsed);
      } catch (_) {}
    }

    // 3 Day Forecast
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

    // Indices
    String uvIndex = '--';
    if (indices is List) {
      for (var idx in indices) {
        if (idx['type'] == 'uvIndex') {
          uvIndex = idx['value']?.toString() ?? '--';
          break;
        }
      }
    }

    // Tags
    List<String> tags = [];
    final minutelyDesc =
        data['minutely']?['probability']?['probabilityDesc']?.toString() ??
        data['minutely']?['precipitation']?['shortDescription']?.toString() ??
        '';

    if (aqiValue != '--') tags.add('AQI $aqiValue');
    if (data['aqi']?['aqiLevelName'] != null)
      tags.add(data['aqi']?['aqiLevelName']);
    if (data['aqi']?['primary'] != null && data['aqi']?['primary'] != '')
      tags.add('首要:${data['aqi']?['primary']}');
    if (minutelyDesc.contains('雨')) tags.add('有雨');
    if (minutelyDesc.contains('雪')) tags.add('有雪');

    // Alerts tags
    final alerts = data['alerts'] as List? ?? [];
    for (var alert in alerts) {
      if (alert['type'] != null) tags.add(alert['type'].toString());
    }

    // Lunar
    final solar = Solar.fromDate(_now);
    final lunar = Lunar.fromSolar(solar);
    final weekdays = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六'];

    return LayoutBuilder(
      builder: (context, constraints) {
        // App container in React has flex rows/cols.
        // We do 4 rows on top (Flex 4), 1 row on bottom (Flex 1) -> Actually Flex is fine.
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
                    child: Container(
                      decoration: const BoxDecoration(
                        border: Border(
                          right: BorderSide(color: Colors.white, width: 0.5),
                        ),
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            DateFormat('HH:mm').format(_now),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 180,
                              fontWeight: FontWeight.w800,
                              fontFeatures: [FontFeature.tabularFigures()],
                              letterSpacing: -5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Sidebar 1 (1 col out of 5)
                  Expanded(
                    flex: 1,
                    child: Container(
                      decoration: const BoxDecoration(
                        border: Border(
                          right: BorderSide(color: Colors.white, width: 0.5),
                        ),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('yyyy/MM/dd').format(_now),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            weekdays[_now.weekday % 7],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '农历 ${lunar.getMonthInChinese()}月${lunar.getDayInChinese()}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${lunar.getYearInGanZhi()}年',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${lunar.getMonthInGanZhi()}月 ${lunar.getDayInGanZhi()}日',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Divider(color: Colors.white),
                          ),
                          Text(
                            '$temp°',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 44,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '$weatherDesc 最高$todayForecastFrom° 最低$todayForecastTo°',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: tags
                                .map(
                                  (t) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[800],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      t,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
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
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                minutelyDesc,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // Sidebar 2 (1 col out of 5)
                  Expanded(
                    flex: 1,
                    child: Container(
                      decoration: const BoxDecoration(),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            children: forecasts
                                .map(
                                  (f) => Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        SizedBox(
                                          width: 32,
                                          child: Text(
                                            f['day'],
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Center(
                                            child: Text(
                                              f['weather'],
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${f['low']}° - ${f['high']}°',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Divider(color: Colors.white),
                          ),
                          Expanded(
                            child: GridView.count(
                              crossAxisCount: 2,
                              childAspectRatio: 1.2,
                              physics: const NeverScrollableScrollPhysics(),
                              children: [
                                _buildIndexItem(
                                  '体感',
                                  '$feelsLike°',
                                  showRight: true,
                                  showBottom: true,
                                ),
                                _buildIndexItem(
                                  '湿度',
                                  '$humidity%',
                                  showRight: false,
                                  showBottom: true,
                                ),
                                _buildIndexItem(
                                  '紫外线',
                                  uvIndex,
                                  showRight: true,
                                  showBottom: true,
                                ),
                                _buildIndexItem(
                                  '风向',
                                  windDesc,
                                  showRight: false,
                                  showBottom: true,
                                ),
                                _buildIndexItem(
                                  '气压',
                                  '$pressure hPa',
                                  showRight: true,
                                  showBottom: false,
                                ),
                                _buildIndexItem(
                                  '日落',
                                  sunset,
                                  showRight: false,
                                  showBottom: false,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Bottom Bar Section
            Expanded(
              flex: 1,
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.white, width: 0.5),
                  ),
                ),
                child: allCourses.isNotEmpty
                    ? Row(
                        children: allCourses.take(5).map((c) {
                          bool isActive = false;
                          if (topCourse != null &&
                              c.id == topCourse.id &&
                              svm.isCourseOngoing(c)) {
                            isActive = true;
                          }
                          bool isTomorrow = vm.isTomorrow(c, svm);

                          return Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                border: const Border(
                                  right: BorderSide(
                                    color: Colors.white,
                                    width: 0.5,
                                  ),
                                ),
                                color: isActive
                                    ? Colors.grey[900]
                                    : Colors.black,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
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
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isTomorrow)
                                        Container(
                                          margin: const EdgeInsets.only(
                                            left: 4,
                                          ),
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${c.startTime}-${c.endTime} | ${c.location}',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (isActive) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      height: 6,
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
                      )
                    : const Center(
                        child: Text(
                          '暂无后续课程',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildIndexItem(
    String label,
    String value, {
    required bool showRight,
    required bool showBottom,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          right: showRight
              ? const BorderSide(color: Colors.white, width: 0.5)
              : BorderSide.none,
          bottom: showBottom
              ? const BorderSide(color: Colors.white, width: 0.5)
              : BorderSide.none,
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: 1),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
