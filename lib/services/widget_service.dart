import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import '../view_models/schedule_view_model.dart';

class WidgetService {
  static const String appGroupId = 'group.top.met6.cquptscheduleios';

  // iOS 配置（使用 widget 的 kind 值）
  static const String iOSWidgetKind = 'CourseWidget';
  static const String upcomingCourseWidgetKind = 'UpcomingCourseWidget';
  static const String todayCourseWidgetKind = 'TodayCourseWidget';
  static const String lockScreenWidgetKind = 'LockScreenWidget';

  // Android 配置（对应 AndroidManifest.xml 中 Receiver 的类名）
  static const String androidUpcomingReceiver = 'UpcomingWidgetReceiver';
  static const String androidTodayReceiver = 'TodayWidgetReceiver';

  // Android 直接调用 Glance updateAll() 的 Platform Channel
  static const _androidChannel = MethodChannel('top.met6.cquptschedule/widget');

  // 防抖定时器，避免短时间内多次刷新导致 Glance session 互相取消
  static Timer? _debounceTimer;
  static Completer<void>? _pendingCompleter;

  static Future<void> syncToWidget(ScheduleViewModel vm) async {
    if (vm.scheduleData == null) return;

    try {
      // iOS 必须设置 AppGroupId
      if (Platform.isIOS) {
        await HomeWidget.setAppGroupId(appGroupId);
      }

      final Map<String, dynamic> exportData = {
        'week_1_monday': vm.scheduleData!.week1Monday,
        'instances': [
          ...vm.scheduleData!.instances.map((e) => e.toJson()),
          ...vm.customCourses
              .expand((e) => e.toInstances())
              .map((e) => e.toJson()),
        ],
      };

      // 先保存数据（这一步总是立即执行）
      await HomeWidget.saveWidgetData(
        'full_schedule_json',
        jsonEncode(exportData),
      );

      // 平台差异化：触发小组件刷新（Android 带防抖）
      if (Platform.isIOS) {
        await HomeWidget.updateWidget(iOSName: iOSWidgetKind);
        await HomeWidget.updateWidget(iOSName: upcomingCourseWidgetKind);
        await HomeWidget.updateWidget(iOSName: todayCourseWidgetKind);
        await HomeWidget.updateWidget(iOSName: lockScreenWidgetKind);
      } else if (Platform.isAndroid) {
        await _debouncedAndroidUpdate();
      }
    } catch (e) {
      debugPrint("Widget Sync Error: $e");
    }
  }

  /// Android 小组件刷新防抖：500ms 内的多次调用只执行最后一次
  static Future<void> _debouncedAndroidUpdate() async {
    // 取消上一次的定时器
    _debounceTimer?.cancel();

    // 创建新的 Completer 用于让调用者等待
    final completer = Completer<void>();
    _pendingCompleter = completer;

    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        // 优先使用 Platform Channel 直接调用 Glance updateAll()
        try {
          await _androidChannel.invokeMethod('updateWidgets');
        } catch (e) {
          // 回退到广播方式
          await HomeWidget.updateWidget(androidName: androidUpcomingReceiver);
          await HomeWidget.updateWidget(androidName: androidTodayReceiver);
        }
      } catch (e) {
        debugPrint("Widget Android Update Error: $e");
      } finally {
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    });

    return completer.future;
  }

  /// 清空 Widget 和 Watch 的课表数据（退出登录时调用）
  static Future<void> clearWidgetData() async {
    try {
      if (Platform.isIOS) {
        await HomeWidget.setAppGroupId(appGroupId);
      }

      await HomeWidget.saveWidgetData('full_schedule_json', null);

      if (Platform.isIOS) {
        await HomeWidget.updateWidget(iOSName: iOSWidgetKind);
        await HomeWidget.updateWidget(iOSName: upcomingCourseWidgetKind);
        await HomeWidget.updateWidget(iOSName: todayCourseWidgetKind);
        await HomeWidget.updateWidget(iOSName: lockScreenWidgetKind);
      } else if (Platform.isAndroid) {
        try {
          await _androidChannel.invokeMethod('updateWidgets');
        } catch (e) {
          await HomeWidget.updateWidget(androidName: androidUpcomingReceiver);
          await HomeWidget.updateWidget(androidName: androidTodayReceiver);
        }
      }
    } catch (e) {
      debugPrint("Widget Clear Error: $e");
    }
  }
}
