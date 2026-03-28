import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/schedule_model.dart';
import 'schedule_view_model.dart';

class DesktopWidgetViewModel extends ChangeNotifier {
  final String studentId;
  Map<String, dynamic>? weatherData;
  bool isLoading = true;

  DesktopWidgetViewModel({required this.studentId});

  Future<void> refreshAll() async {
    isLoading = true;
    notifyListeners();

    await fetchWeather();

    isLoading = false;
    notifyListeners();
  }

  Future<void> fetchWeather() async {
    try {
      final response =
          await http.get(Uri.parse('https://cqupt.ishub.top/api/weather.json'));
      if (response.statusCode == 200) {
        weatherData = json.decode(utf8.decode(response.bodyBytes));
      }
    } catch (e) {
      debugPrint("DesktopWidget fetchWeather error: $e");
    }
  }

  // --- Logic for UI using ScheduleViewModel ---

  bool isToday(CourseInstance c, ScheduleViewModel svm) {
    final now = DateTime.now();
    return c.week == svm.calculateCurrentRealWeek() && c.day == now.weekday;
  }

  bool isTomorrow(CourseInstance c, ScheduleViewModel svm) {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));

    // Calculate what the "week" and "day" of tomorrow should be
    int tomorrowWeek = svm.calculateCurrentRealWeek();
    int tomorrowDay = tomorrow.weekday;

    // If today is Sunday (7), tomorrow is Monday (1) of the next week
    if (now.weekday == 7) {
      tomorrowWeek++;
    }

    return c.week == tomorrowWeek && c.day == tomorrowDay;
  }

  CourseInstance? getTopCourse(ScheduleViewModel svm) {
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;

    // 1. Get all courses for today and tomorrow
    final currentWeek = svm.calculateCurrentRealWeek();
    List<CourseInstance> candidates = [];
    candidates.addAll(svm.allCourses(currentWeek));
    candidates.addAll(svm.allCourses(currentWeek + 1));

    List<CourseInstance> todayAndTomorrow =
        candidates.where((c) => isToday(c, svm) || isTomorrow(c, svm)).toList();

    // 2. Check Ongoing
    final ongoing =
        todayAndTomorrow.where((c) => svm.isCourseOngoing(c)).toList();
    if (ongoing.isNotEmpty) {
      return ongoing.first;
    }

    // 3. Check Upcoming
    todayAndTomorrow.sort((a, b) {
      final int aWeight =
          (a.week * 10 + a.day) * 10000 + _timeToMinutes(a.startTime);
      final int bWeight =
          (b.week * 10 + b.day) * 10000 + _timeToMinutes(b.startTime);
      return aWeight.compareTo(bWeight);
    });

    for (var c in todayAndTomorrow) {
      if (isToday(c, svm)) {
        if (_timeToMinutes(c.startTime) > nowMinutes) return c;
      } else if (isTomorrow(c, svm)) {
        return c;
      }
    }

    return null;
  }

  List<CourseInstance> getListCourses(ScheduleViewModel svm) {
    final top = getTopCourse(svm);
    if (top == null) return [];

    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;

    final currentWeek = svm.calculateCurrentRealWeek();
    List<CourseInstance> candidates = [];
    candidates.addAll(svm.allCourses(currentWeek));
    candidates.addAll(svm.allCourses(currentWeek + 1));

    // Filter for today/tomorrow only, and after "now"
    var futureCourses =
        candidates.where((c) {
          if (c.id == top.id) return false;

          if (isToday(c, svm)) {
            return _timeToMinutes(c.startTime) > nowMinutes;
          }
          return isTomorrow(c, svm);
        }).toList();

    // Sort
    futureCourses.sort((a, b) {
      final int aWeight = (a.week * 10 + a.day) * 10000 + _timeToMinutes(a.startTime);
      final int bWeight = (b.week * 10 + b.day) * 10000 + _timeToMinutes(b.startTime);
      return aWeight.compareTo(bWeight);
    });

    return futureCourses.toList();
  }

  int _timeToMinutes(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length != 2) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return h * 60 + m;
  }

  String formatTimeDiff(CourseInstance course, ScheduleViewModel svm) {
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final beginMinutes = _timeToMinutes(course.startTime);
    
    final realWeek = svm.calculateCurrentRealWeek();
    final isTomorrowMonthDay = svm.isTomorrowCourse(course);
    
    int diff;
    if (course.week == realWeek && course.day == now.weekday) {
       diff = beginMinutes - nowMinutes;
    } else {
       // Offset calculation
       final dayDiff = (course.week - realWeek) * 7 + (course.day - now.weekday);
       diff = dayDiff * 1440 + beginMinutes - nowMinutes;
    }
    
    if (diff < 0) diff = 0;
    
    final h = diff ~/ 60;
    final m = diff % 60;
    return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}";
  }

  String formatRemainingTime(CourseInstance course) {
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final endMinutes = _timeToMinutes(course.endTime);
    
    int diff = endMinutes - nowMinutes;
    if (diff < 0) diff = 0;
    
    final h = diff ~/ 60;
    final m = diff % 60;
    return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}";
  }

  double getProgress(CourseInstance course) {
    final now = DateTime.now();
    final nowMinutes = (now.hour * 60 + now.minute).toDouble();
    final begin = _timeToMinutes(course.startTime).toDouble();
    final end = _timeToMinutes(course.endTime).toDouble();
    
    if (end <= begin) return 0.0;
    final progress = (nowMinutes - begin) / (end - begin);
    return progress.clamp(0.0, 1.0);
  }
}
