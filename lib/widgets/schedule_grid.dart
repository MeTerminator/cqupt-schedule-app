import 'package:flutter/material.dart';
import '../models/schedule_model.dart';
import '../view_models/schedule_view_model.dart';
import 'course_block.dart';

class DateInfo {
  final String month;
  final String day;
  DateInfo(this.month, this.day);
}

class ScheduleGrid extends StatelessWidget {
  final ScheduleViewModel viewModel;
  final int weekToShow;
  final Function(CourseInstance) onCourseTap;

  const ScheduleGrid({
    super.key,
    required this.viewModel,
    required this.weekToShow,
    required this.onCourseTap,
  });

  double get hourHeight => 80;

  int toMinutes(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length != 2) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return h * 60 + m;
  }

  (double y, double height) calculateGeometry(CourseInstance course) {
    final firstP = course.periods.isNotEmpty ? course.periods.first : 1;
    final lastP = course.periods.isNotEmpty ? course.periods.last : 1;

    final stdBegin = timeTable[firstP]?['begin'] ?? '08:00';
    final stdEnd = timeTable[lastP]?['end'] ?? '08:45';

    final standardY = (firstP - 1) * hourHeight;
    final standardHeight = course.periods.length * hourHeight;

    final pixelsPerMinute = hourHeight / 50.0;

    final startDiff = (toMinutes(course.startTime) - toMinutes(stdBegin))
        .toDouble();
    final endDiff = (toMinutes(course.endTime) - toMinutes(stdEnd)).toDouble();

    final finalY = standardY + (startDiff * pixelsPerMinute);
    final finalHeight =
        standardHeight -
        (startDiff * pixelsPerMinute) +
        (endDiff * pixelsPerMinute);

    return (finalY, finalHeight.clamp(30.0, double.infinity));
  }

  DateInfo getDate(int dayIndex) {
    if (viewModel.scheduleData == null) return DateInfo("", "");

    final startStr = viewModel.scheduleData!.week1Monday.substring(0, 10);
    DateTime startDate;
    try {
      startDate = DateTime.parse(startStr);
    } catch (e) {
      return DateInfo("", "");
    }

    final offset = (weekToShow - 1) * 7 + dayIndex;
    final targetDate = startDate.add(Duration(days: offset));

    return DateInfo(targetDate.month.toString(), targetDate.day.toString());
  }

  bool isToday(int dayIndex) {
    if (!viewModel.isCurrentWeekReal || weekToShow != viewModel.selectedWeek) {
      return false;
    }
    final weekday = DateTime.now().weekday;
    return dayIndex == weekday - 1;
  }

  @override
  Widget build(BuildContext context) {
    final courses = viewModel.allCourses(weekToShow);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        _buildHeader(context, isDark),
        Expanded(
          child: SingleChildScrollView(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTimeColumn(isDark),
                Expanded(child: _buildCourseGrid(context, courses, isDark)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    final dateInfo = getDate(0);
    final timelineColor = viewModel.timelineTextColor;
    return Container(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 35,
            child: Text(
              '${dateInfo.month}\n月',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color:
                    timelineColor ??
                    (isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
            ),
          ),
          ...List.generate(7, (i) {
            final dayInfo = getDate(i);
            final today = isToday(i);
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: today ? Colors.grey.withValues(alpha: 0.1) : null,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  children: [
                    Text(
                      ['一', '二', '三', '四', '五', '六', '日'][i],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color:
                            timelineColor ??
                            (today
                                ? (isDark
                                      ? Colors.white
                                      : Theme.of(context).primaryColor)
                                : null),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dayInfo.day,
                      style: TextStyle(
                        fontSize: 10,
                        color:
                            timelineColor ??
                            (isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTimeColumn(bool isDark) {
    final timelineColor = viewModel.timelineTextColor;
    return Column(
      children: List.generate(12, (i) {
        final period = i + 1;
        final t = timeTable[period];
        Color bgColor;
        if (period <= 4) {
          bgColor = Colors.green.withValues(alpha: 0.12);
        } else if (period <= 8) {
          bgColor = Colors.blue.withValues(alpha: 0.12);
        } else {
          bgColor = Colors.purple.withValues(alpha: 0.12);
        }

        return Container(
          width: 35,
          height: hourHeight,
          color: bgColor,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$period',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color:
                      timelineColor ??
                      (isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
              ),
              if (t != null) ...[
                Text(
                  t['begin']!,
                  style: TextStyle(
                    fontSize: 8,
                    color:
                        timelineColor ??
                        (isDark ? Colors.grey[500] : Colors.grey[500]),
                  ),
                ),
                Text(
                  t['end']!,
                  style: TextStyle(
                    fontSize: 8,
                    color:
                        timelineColor ??
                        (isDark ? Colors.grey[500] : Colors.grey[500]),
                  ),
                ),
              ],
            ],
          ),
        );
      }),
    );
  }

  Widget _buildCourseGrid(
    BuildContext context,
    List<CourseInstance> courses,
    bool isDark,
  ) {
    final commonFreePeriods = viewModel.getCommonFreePeriods(weekToShow);

    return SizedBox(
      height: hourHeight * 12,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final colW = constraints.maxWidth / 7;
          return Stack(
            children: [
              ...List.generate(13, (i) {
                return Positioned(
                  left: 0,
                  right: 0,
                  top: i * hourHeight,
                  child: Container(
                    height: 0.5,
                    color: Colors.grey.withValues(alpha: 0.1),
                  ),
                );
              }),

              // 绘制共同空闲时间背景标记 (显示在课程层级下方)
              if (viewModel.showCommonFreeTime && commonFreePeriods.isNotEmpty)
                ...List.generate(7, (dayIdx) {
                  final day = dayIdx + 1; // 1-7
                  
                  // 找出该天的所有空闲节次并排序
                  final dayFreePeriods = <int>[];
                  for (int period = 1; period <= 12; period++) {
                    if (commonFreePeriods.contains("${day}_$period")) {
                      dayFreePeriods.add(period);
                    }
                  }
                  dayFreePeriods.sort();

                  // 将连续的节次合并为组
                  final groups = <List<int>>[];
                  if (dayFreePeriods.isNotEmpty) {
                    var currentGroup = [dayFreePeriods[0]];
                    for (int i = 1; i < dayFreePeriods.length; i++) {
                      if (dayFreePeriods[i] == dayFreePeriods[i - 1] + 1) {
                        currentGroup.add(dayFreePeriods[i]);
                      } else {
                        groups.add(currentGroup);
                        currentGroup = [dayFreePeriods[i]];
                      }
                    }
                    groups.add(currentGroup);
                  }

                  // 为每个合并后的组绘制一格
                  return groups.map((g) {
                    final startPeriod = g.first;
                    final periodCount = g.length;

                    return Positioned(
                      left: (day - 1) * colW + 2,
                      top: (startPeriod - 1) * hourHeight + 2,
                      width: colW - 4,
                      height: periodCount * hourHeight - 4,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isDark
                                ? [
                                    const Color(0x6000F2FE),
                                    const Color(0x604FACFE),
                                  ]
                                : [
                                    const Color(0x4C00F2FE),
                                    const Color(0x4C4FACFE),
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark
                                ? Colors.teal.withValues(alpha: 0.8)
                                : Colors.teal.withValues(alpha: 0.65),
                            width: 1.2,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.coffee_rounded,
                              size: periodCount > 1 ? 16 : 13,
                              color: isDark
                                  ? Colors.teal[100]
                                  : Colors.teal[800],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '共同空闲',
                              style: TextStyle(
                                fontSize: periodCount > 1 ? 9 : 8,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.teal[50]
                                    : Colors.teal[900],
                              ),
                            ),
                            if (periodCount > 1) ...[
                              const SizedBox(height: 2),
                              Text(
                                '$periodCount节连空',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: isDark
                                      ? Colors.teal[100]
                                      : Colors.teal[800],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList();
                }).expand((widgets) => widgets),

              ...courses.map((course) {
                final geoInfo = calculateGeometry(course);
                return Positioned(
                  left: (course.day - 1) * colW + 1,
                  top: geoInfo.$1 + 1,
                  width: colW - 2,
                  height: geoInfo.$2 - 2,
                  child: GestureDetector(
                    onTap: () => onCourseTap(course),
                    child: CourseBlock(viewModel: viewModel, course: course),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
