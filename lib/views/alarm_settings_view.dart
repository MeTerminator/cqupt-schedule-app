import 'package:flutter/material.dart';
import '../services/alarm_service.dart';
import '../view_models/schedule_view_model.dart';
import 'live_activity_settings_view.dart';

class AlarmSettingsView extends StatefulWidget {
  final ScheduleViewModel viewModel;

  const AlarmSettingsView({
    super.key,
    required this.viewModel,
  });

  @override
  State<AlarmSettingsView> createState() => _AlarmSettingsViewState();
}

class _AlarmSettingsViewState extends State<AlarmSettingsView> {
  int _leadMinutes8 = 30;
  int _leadMinutes10 = 30;
  int _snoozeMinutes = 9;
  bool _courseLiveActivityEnabled = true;
  int _courseLiveActivityLeadMinutes = 15;
  bool _isSupported = true;
  bool _isLoading = true;
  List<Map<String, dynamic>> _scheduledAlarms = [];

  @override
  void initState() {
    super.initState();
    _loadSettingsAndAlarms();
  }

  Future<void> _loadSettingsAndAlarms() async {
    final lead8 = await AlarmService.getLeadMinutes8();
    final lead10 = await AlarmService.getLeadMinutes10();
    final snooze = await AlarmService.getSnoozeMinutes();
    final liveEnabled = await AlarmService.getCourseLiveActivityEnabled();
    final liveLead = await AlarmService.getCourseLiveActivityLeadMinutes();
    final alarms = await AlarmService.getScheduledAlarms();
    final isSupported = await AlarmService.checkOSVersionSupport();
    if (mounted) {
      setState(() {
        _leadMinutes8 = lead8;
        _leadMinutes10 = lead10;
        _snoozeMinutes = snooze;
        _courseLiveActivityEnabled = liveEnabled;
        _courseLiveActivityLeadMinutes = liveLead;
        _scheduledAlarms = alarms;
        _isSupported = isSupported;
        _isLoading = false;
      });
    }
  }



  Future<void> _saveSnoozeMinutes(int value) async {
    setState(() {
      _snoozeMinutes = value;
    });
    await AlarmService.setSnoozeMinutes(value);
  }

  Future<void> _loadScheduledAlarms() async {
    final alarms = await AlarmService.getScheduledAlarms();
    if (mounted) {
      setState(() {
        _scheduledAlarms = alarms;
      });
    }
  }

  Future<void> _saveLead8(int value) async {
    setState(() {
      _leadMinutes8 = value;
    });
    await AlarmService.setLeadMinutes8(value);
  }

  Future<void> _saveLead10(int value) async {
    setState(() {
      _leadMinutes10 = value;
    });
    await AlarmService.setLeadMinutes10(value);
  }

  Future<void> _deleteAlarm(String id, String title) async {
    await AlarmService.cancelAlarm(id);
    await _loadScheduledAlarms();
    widget.viewModel.triggerToast('已删除闹钟: $title');
  }

  String _formatAlarmTime(int timeInMillis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timeInMillis);
    final month = dt.month;
    final day = dt.day;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    
    // 获取星期几
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final weekday = weekdays[dt.weekday - 1];
    
    // 判断是否是今天/明天
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final alarmDate = DateTime(dt.year, dt.month, dt.day);
    
    String dayLabel = '${month}月${day}日';
    if (alarmDate == today) {
      dayLabel = '今天';
    } else if (alarmDate == tomorrow) {
      dayLabel = '明天';
    }
    
    return '$dayLabel ($weekday) $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? Colors.grey[900] : const Color(0xFFF5F5F7);

    return Scaffold(
      appBar: AppBar(
        title: const Text('闹钟管理', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  if (!_isSupported) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '系统版本不支持',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.redAccent,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'iOS版本低于26，需要iOS26才能启用此功能。',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // 1. 规则说明卡片 (Info Card)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.blue.withOpacity(0.1) : Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.info, color: Colors.blue, size: 20),
                            SizedBox(width: 8),
                            Text(
                              '智能闹钟规则说明',
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
                          '• 早八指早上 1-2 节课 (08:00 开始)\n'
                          '• 早十指早上 3-4 节课 (10:15 开始)\n'
                          '• 当天有早八课：仅设置早八闹钟\n'
                          '• 无早八但有早十课：仅设置早十闹钟\n'
                          '• 上午没课：不设置当天闹钟\n'
                          '• 自动跳过历史时间段，确保不补响历史闹钟',
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

                  // 2. 早八闹钟设置 (Early 8 Settings)
                  Text(
                    '早八早十闹钟设置',
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.wb_twilight, color: Colors.amber, size: 22),
                                SizedBox(width: 12),
                                Text(
                                  '早八提前时间',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            Text(
                              '$_leadMinutes8 分钟',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: _leadMinutes8.toDouble(),
                          min: 5,
                          max: 120,
                          divisions: 23,
                          label: '$_leadMinutes8 分钟',
                          onChanged: (val) => _saveLead8(val.toInt()),
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.wb_sunny, color: Colors.orange, size: 22),
                                SizedBox(width: 12),
                                Text(
                                  '早十提前时间',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            Text(
                              '$_leadMinutes10 分钟',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: _leadMinutes10.toDouble(),
                          min: 5,
                          max: 120,
                          divisions: 23,
                          label: '$_leadMinutes10 分钟',
                          onChanged: (val) => _saveLead10(val.toInt()),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 稍后提醒设置 (Snooze Settings)
                  Text(
                    'AlarmKit 稍后提醒设置',
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.snooze_rounded, color: Colors.purple, size: 22),
                                SizedBox(width: 12),
                                Text(
                                  '稍后提醒时间',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            Text(
                              '$_snoozeMinutes 分钟',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: _snoozeMinutes.toDouble(),
                          min: 1,
                          max: 30,
                          divisions: 29,
                          label: '$_snoozeMinutes 分钟',
                          onChanged: (val) => _saveSnoozeMinutes(val.toInt()),
                          activeColor: Colors.purple,
                          inactiveColor: Colors.purple.withOpacity(0.2),
                        ),
                      ],
                    ),
                  ),


                  // 3. 已设置的闹钟列表 (Scheduled Alarms List)
                  Text(
                    '已登记的闹钟列表 (${_scheduledAlarms.length})',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _scheduledAlarms.isEmpty
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                          decoration: BoxDecoration(
                            color: cardBgColor,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.notifications_off_outlined,
                                size: 40,
                                color: isDark ? Colors.grey[600] : Colors.grey[400],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '暂无已设置的闹钟',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '您可以在首页课表详情中设置单课闹钟，\n或在下方一键智能配置整周课程起床闹钟。',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey[600] : Colors.grey[500],
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: cardBgColor,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _scheduledAlarms.length,
                            separatorBuilder: (context, index) => Divider(
                              height: 1,
                              color: isDark ? Colors.grey[800] : Colors.grey[200],
                              indent: 52,
                            ),
                            itemBuilder: (context, index) {
                              final alarm = _scheduledAlarms[index];
                              final id = alarm['id'] as String;
                              final title = alarm['title'] as String;
                              final timeInMillis = (alarm['timeInMillis'] as num).toInt();
                              final leadMinutes = alarm['leadMinutes'] as int?;

                              final isMorningAlarm = id.startsWith('morning_alarm');
                              final isTestAlarm = id.startsWith('test_alarm');
                              final icon = isTestAlarm
                                  ? Icons.alarm_on_rounded
                                  : (isMorningAlarm ? Icons.wb_sunny : Icons.school);
                              final iconColor = isTestAlarm
                                  ? Colors.purple
                                  : (isMorningAlarm ? Colors.orange : Colors.blue);

                              return ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                leading: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: iconColor.withOpacity(0.1),
                                  child: Icon(icon, color: iconColor, size: 18),
                                ),
                                title: Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${_formatAlarmTime(timeInMillis)}${leadMinutes != null ? ' (提前 $leadMinutes 分钟)' : ''}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                  onPressed: () => _deleteAlarm(id, title),
                                  tooltip: '删除此闹钟',
                                ),
                              );
                            },
                          ),
                        ),
                  const SizedBox(height: 24),

                  // 4. 快捷操作区 (Actions Area)
                  Text(
                    '快捷批量操作',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildActionButton(
                    context,
                    title: '一键设置本周全部闹钟',
                    subtitle: '自动安排本周 (第 ${widget.viewModel.calculateCurrentRealWeek()} 周) 的闹钟',
                    icon: Icons.calendar_today,
                    color: Colors.blue,
                    onTap: () => _setupAlarmsForWeek(widget.viewModel.calculateCurrentRealWeek(), '本周'),
                  ),
                  const SizedBox(height: 12),
                  _buildActionButton(
                    context,
                    title: '一键设置下周全部闹钟',
                    subtitle: '自动安排下周 (第 ${widget.viewModel.calculateCurrentRealWeek() + 1} 周) 的闹钟',
                    icon: Icons.next_plan,
                    color: Colors.teal,
                    onTap: () => _setupAlarmsForWeek(widget.viewModel.calculateCurrentRealWeek() + 1, '下周'),
                  ),
                  const SizedBox(height: 12),
                  _buildActionButton(
                    context,
                    title: '清除全套已设闹钟',
                    subtitle: '取消所有通过本应用安排的原生课程和起床闹钟',
                    icon: Icons.delete_sweep,
                    color: Colors.red,
                    onTap: _clearAllAlarms,
                  ),
                  const SizedBox(height: 12),
                  _buildActionButton(
                    context,
                    title: '添加测试闹钟 (3秒后)',
                    subtitle: '用于快速测试系统原生闹钟与强提醒通知的触发情况',
                    icon: Icons.alarm_add_rounded,
                    color: Colors.orange,
                    onTap: _setupTestAlarm,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Future<void> _setupAlarmsForWeek(int week, String label) async {
    final isSupported = await AlarmService.checkOSVersionSupport();
    if (!isSupported) {
      widget.viewModel.triggerToast('iOS版本低于26，需要iOS26才能启用此功能');
      return;
    }

    if (week <= 0 || week > 20) {
      widget.viewModel.triggerToast('学期周次无效 ($week)，无法设置');
      return;
    }

    final count = await AlarmService.scheduleMorningAlarmsForWeek(
      viewModel: widget.viewModel,
      week: week,
      leadMinutes8: _leadMinutes8,
      leadMinutes10: _leadMinutes10,
    );

    if (count > 0) {
      widget.viewModel.triggerToast('一键设置成功，共排入 $count 个未来的 $label闹钟');
      await _loadScheduledAlarms();
    } else {
      widget.viewModel.triggerToast('未设置闹钟，该周可能已无未来的上午课程');
    }
  }

  Future<void> _clearAllAlarms() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除全部闹钟'),
        content: const Text('确定要清除所有通过本应用设置的课程闹钟和起床闹钟吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await AlarmService.clearAllAlarms();
              widget.viewModel.triggerToast('已清除全部闹钟');
              await _loadScheduledAlarms();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('确定清除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _setupTestAlarm() async {
    final result = await AlarmService.scheduleTestAlarm();
    if (result == 'success') {
      widget.viewModel.triggerToast('测试闹钟已添加，3秒后触发响铃');
      await _loadScheduledAlarms();
    } else if (result == 'low_os_version') {
      widget.viewModel.triggerToast('iOS版本低于26，需要iOS26才能启用此功能');
    } else if (result == 'no_permission') {
      widget.viewModel.triggerToast('添加失败，请授予闹钟与通知权限');
    } else {
      widget.viewModel.triggerToast('添加测试闹钟失败，请重试');
    }
  }

  Widget _buildActionButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? Colors.grey[900] : const Color(0xFFF5F5F7);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}
