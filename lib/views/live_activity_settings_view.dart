import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/alarm_service.dart';
import '../view_models/schedule_view_model.dart';

class LiveActivitySettingsView extends StatefulWidget {
  final ScheduleViewModel viewModel;

  const LiveActivitySettingsView({
    super.key,
    required this.viewModel,
  });

  @override
  State<LiveActivitySettingsView> createState() => _LiveActivitySettingsViewState();
}

class _LiveActivitySettingsViewState extends State<LiveActivitySettingsView> {
  bool _beforeClassEnabled = true;
  bool _duringClassEnabled = true;
  int _leadMinutes = 15;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final beforeEnabled = await AlarmService.getCourseLiveActivityBeforeClassEnabled();
    final duringEnabled = await AlarmService.getCourseLiveActivityDuringClassEnabled();
    final lead = await AlarmService.getCourseLiveActivityLeadMinutes();
    if (mounted) {
      setState(() {
        _beforeClassEnabled = beforeEnabled;
        _duringClassEnabled = duringEnabled;
        _leadMinutes = lead;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveBeforeClassEnabled(bool value) async {
    setState(() {
      _beforeClassEnabled = value;
    });
    await AlarmService.setCourseLiveActivityBeforeClassEnabled(value);
    await AlarmService.syncCourseLiveActivity(widget.viewModel);
    HapticFeedback.lightImpact();
  }

  Future<void> _saveDuringClassEnabled(bool value) async {
    setState(() {
      _duringClassEnabled = value;
    });
    await AlarmService.setCourseLiveActivityDuringClassEnabled(value);
    await AlarmService.syncCourseLiveActivity(widget.viewModel);
    HapticFeedback.lightImpact();
  }

  Future<void> _saveLeadMinutes(int value) async {
    setState(() {
      _leadMinutes = value;
    });
    await AlarmService.setCourseLiveActivityLeadMinutes(value);
    await AlarmService.syncCourseLiveActivity(widget.viewModel);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? Colors.grey[900] : const Color(0xFFF5F5F7);
    final scaffoldBgColor = isDark ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: scaffoldBgColor,
      appBar: AppBar(
        title: const Text('实时活动设置', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : Colors.black87,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. 顶部功能介绍卡片 (Feature Intro Card)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.blue.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.layers_rounded, color: Colors.blue, size: 22),
                            SizedBox(width: 8),
                            Text(
                              '什么是课程实时活动？',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '实时活动可以在锁屏界面和灵动岛上，为您提供最直观的课表倒计时。即使不打开 App，您也能随时掌握下一节课的动态。您可以分别控制“课前”与“课中”的卡片展示，实现更加个性的提醒偏好。',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.6,
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 2. 课前实时活动设置 (Before Class Live Activity Card)
                  Text(
                    '课前实时活动',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      children: [
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Row(
                            children: [
                              Icon(Icons.hourglass_top, color: Colors.teal, size: 22),
                              SizedBox(width: 12),
                              Text(
                                '启用课前实时活动',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          subtitle: const Text('在上课前显示即将上课倒计时卡片'),
                          value: _beforeClassEnabled,
                          onChanged: _saveBeforeClassEnabled,
                          activeColor: Colors.teal,
                        ),
                        if (_beforeClassEnabled) ...[
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.more_time_rounded, color: Colors.teal, size: 20),
                                  SizedBox(width: 12),
                                  Text(
                                    '课前提前显示时间',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                              Text(
                                '$_leadMinutes 分钟',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal,
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: _leadMinutes.toDouble(),
                            min: 5,
                            max: 60,
                            divisions: 11,
                            label: '$_leadMinutes 分钟',
                            activeColor: Colors.teal,
                            inactiveColor: Colors.teal.withValues(alpha: 0.2),
                            onChanged: (val) {
                              _saveLeadMinutes(val.toInt());
                            },
                            onChangeEnd: (val) {
                              HapticFeedback.selectionClick();
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 3. 课中实时活动设置 (During Class Live Activity Card)
                  Text(
                    '课中实时活动',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Row(
                        children: [
                          Icon(Icons.timelapse_rounded, color: Colors.green, size: 22),
                          SizedBox(width: 12),
                          Text(
                            '启用课中实时活动',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      subtitle: const Text('在上课时显示进度环与下课倒计时卡片'),
                      value: _duringClassEnabled,
                      onChanged: _saveDuringClassEnabled,
                      activeColor: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}
