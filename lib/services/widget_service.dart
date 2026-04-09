import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
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

      // 统一保存数据
      await HomeWidget.saveWidgetData(
        'full_schedule_json',
        jsonEncode(exportData),
      );

      // 平台差异化更新
      if (Platform.isIOS) {
        // iOS 更新所有 iPhone widget
        await HomeWidget.updateWidget(iOSName: iOSWidgetKind);
        await HomeWidget.updateWidget(iOSName: upcomingCourseWidgetKind);
        await HomeWidget.updateWidget(iOSName: todayCourseWidgetKind);
        await HomeWidget.updateWidget(iOSName: lockScreenWidgetKind);
        // Apple Watch 同步由原生 WatchSessionManager 自动处理
        // 它会监听 UserDefaults 变化并通过 WatchConnectivity 发送到 Watch
      } else if (Platform.isAndroid) {
        // Android 更新所有相关的 Receiver
        await HomeWidget.updateWidget(androidName: androidUpcomingReceiver);
        await HomeWidget.updateWidget(androidName: androidTodayReceiver);
      }
    } catch (e) {
      debugPrint("Widget Sync Error: $e");
    }
  }

  /// 清空 Widget 和 Watch 的课表数据（退出登录时调用）
  static Future<void> clearWidgetData() async {
    try {
      if (Platform.isIOS) {
        await HomeWidget.setAppGroupId(appGroupId);
      }

      // 清除 App Group UserDefaults 中的课表数据
      await HomeWidget.saveWidgetData('full_schedule_json', null);

      // 刷新所有 Widget 使其显示空状态
      if (Platform.isIOS) {
        await HomeWidget.updateWidget(iOSName: iOSWidgetKind);
        await HomeWidget.updateWidget(iOSName: upcomingCourseWidgetKind);
        await HomeWidget.updateWidget(iOSName: todayCourseWidgetKind);
        await HomeWidget.updateWidget(iOSName: lockScreenWidgetKind);
        // WatchSessionManager 会通过 3 秒轮询检测到数据变化并同步到 Watch
      } else if (Platform.isAndroid) {
        await HomeWidget.updateWidget(androidName: androidUpcomingReceiver);
        await HomeWidget.updateWidget(androidName: androidTodayReceiver);
      }
    } catch (e) {
      debugPrint("Widget Clear Error: $e");
    }
  }
}

