import 'package:flutter/material.dart';
import '../models/schedule_model.dart';
import '../view_models/schedule_view_model.dart';
import '../models/hidden_rule_model.dart';

import '../services/alarm_service.dart';

class CourseDetailView extends StatelessWidget {
  final CourseInstance course;
  final ScheduleViewModel viewModel;

  const CourseDetailView({
    super.key,
    required this.course,
    required this.viewModel,
  });

  String get courseDate => viewModel.calculateDate(course.week, course.day);
  String get durationWeeks => viewModel.durationWeeks(course);

  DateTime? get courseDateTime {
    if (viewModel.scheduleData == null) return null;
    final startStr = viewModel.scheduleData!.week1Monday.substring(0, 10);
    try {
      final firstMonday = DateTime.parse(startStr);
      final offset = (course.week - 1) * 7 + (course.day - 1);
      final dateOfDay = firstMonday.add(Duration(days: offset));
      
      final timeParts = course.startTime.split(':');
      if (timeParts.length == 2) {
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        return DateTime(dateOfDay.year, dateOfDay.month, dateOfDay.day, hour, minute);
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  String getChineseDay(int day) {
    const days = ['一', '二', '三', '四', '五', '六', '日'];
    return (day >= 1 && day <= 7) ? days[day - 1] : '';
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // 1. 顶部手柄（Handle）- 保持固定
              _buildHandle(context),

              // 2. 标题栏 - 保持固定
              _buildHeader(context),

              // 3. 可滚动内容区
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController, // 绑定 controller 以实现平滑拖拽
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      _buildSection(context, '基本信息', [
                        _buildRow(context, '课程名称', course.course),
                        if (course.teacher != null &&
                            course.teacher!.isNotEmpty &&
                            course.teacher != '无')
                          _buildRow(context, '上课教师', course.teacher!),
                        _buildRow(context, '上课地点', course.location),
                        _buildRow(context, '持续周数', durationWeeks),
                        if (course.credit != null && course.credit!.isNotEmpty)
                          _buildRow(context, '学分', course.credit!),
                        if (course.courseType != null &&
                            course.courseType!.isNotEmpty)
                          _buildRow(context, '课程性质', course.courseType!),
                      ]),
                      const SizedBox(height: 16),
                      _buildSection(context, '时间安排', [
                        _buildRow(context, '上课日期', courseDate),
                        _buildRow(
                          context,
                          '当前周/星期',
                          '第${course.week}周 星期${getChineseDay(course.day)}',
                        ),
                        _buildRow(
                          context,
                          '具体时间',
                          '${course.startTime} - ${course.endTime}',
                        ),
                        _buildRow(
                          context,
                          '上课节数',
                          course.periods.map((e) => e.toString()).join(', '),
                        ),
                        _buildRow(context, '形式', course.type),
                      ]),
                      if (course.description != null &&
                          course.description!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildDescriptionSection(context, course.description!),
                      ],
                      const SizedBox(height: 16),
                      _buildManagementSection(context),
                      // 底部留白，防止被系统手柄或底栏遮挡
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 顶部手柄
  Widget _buildHandle(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 5),
        width: 36,
        height: 5,
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.3),
          borderRadius: BorderRadius.circular(2.5),
        ),
      ),
    );
  }

  // 标题栏
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '课程详情',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: CircleAvatar(
              radius: 14,
              backgroundColor: Colors.grey.withOpacity(0.1),
              child: const Icon(Icons.close, size: 18, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
        ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[900]
                : const Color(0xFFF5F5F7), // 仿 iOS 设置页背景色
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildDescriptionSection(BuildContext context, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            '备注',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
        ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[900]
                : const Color(0xFFF5F5F7),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              description.replaceAll(r'\n', '\n'),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          const SizedBox(width: 24),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManagementSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            '快捷管理',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
        ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[900]
                : const Color(0xFFF5F5F7),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.alarm, color: Colors.blue),
                title: const Text('设置此节闹钟', style: TextStyle(fontWeight: FontWeight.w500)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showAlarmSettings(context),
              ),
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white10
                    : Colors.black12,
              ),
              ListTile(
                leading: const Icon(Icons.visibility_off, color: Colors.orange),
                title: const Text('隐藏此课程', style: TextStyle(fontWeight: FontWeight.w500)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showHideOptions(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showHideOptions(BuildContext context) {
    final timeSlotText = '周${getChineseDay(course.day)} 第${course.periods.join(', ')}节';
    final singleText = '第${course.week}周 周${getChineseDay(course.day)} 第${course.periods.join(', ')}节';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bgColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
        final dividerColor = isDark ? Colors.white10 : Colors.black12;

        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              Text(
                '选择隐藏范围',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '隐藏后的课程不会在课表显示，日历和桌面小组件也会自动忽略',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 20),
              _buildOptionButton(
                ctx,
                title: '隐藏全部该课程',
                subtitle: '隐藏所有周次的《${course.course}》',
                icon: Icons.layers_clear,
                onTap: () {
                  final rule = HiddenRule(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    type: 'all',
                    courseName: course.course,
                    displayText: '${course.course} (全部)',
                  );
                  viewModel.addHiddenRule(rule);
                  viewModel.triggerToast('已隐藏全部该课程');
                  Navigator.pop(ctx); // Close option sheet
                  Navigator.pop(context); // Close detail sheet
                },
              ),
              Container(height: 1, color: dividerColor, margin: const EdgeInsets.symmetric(vertical: 4)),
              _buildOptionButton(
                ctx,
                title: '隐藏此时间段的全部该课程',
                subtitle: '仅隐藏《${course.course}》的【$timeSlotText】时段',
                icon: Icons.alarm_off,
                onTap: () {
                  final rule = HiddenRule(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    type: 'time_slot',
                    courseName: course.course,
                    day: course.day,
                    periods: course.periods,
                    displayText: '${course.course} ($timeSlotText)',
                  );
                  viewModel.addHiddenRule(rule);
                  viewModel.triggerToast('已隐藏该时段课程');
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
              ),
              Container(height: 1, color: dividerColor, margin: const EdgeInsets.symmetric(vertical: 4)),
              _buildOptionButton(
                ctx,
                title: '隐藏此节课程',
                subtitle: '仅隐藏【$singleText】的单节课程',
                icon: Icons.event_busy,
                onTap: () {
                  final rule = HiddenRule(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    type: 'single',
                    courseName: course.course,
                    instanceId: course.id,
                    week: course.week,
                    displayText: '${course.course} ($singleText)',
                  );
                  viewModel.addHiddenRule(rule);
                  viewModel.triggerToast('已隐藏此节课程');
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.orange.withOpacity(0.1),
              child: Icon(icon, color: Colors.orange, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
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

  void _showAlarmSettings(BuildContext context) {
    final DateTime? cDateTime = courseDateTime;
    if (cDateTime == null) {
      viewModel.triggerToast("无法获取课程时间信息");
      return;
    }
    if (cDateTime.isBefore(DateTime.now())) {
      viewModel.triggerToast("该课程时间已过，无法设置闹钟");
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bgColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
        final dividerColor = isDark ? Colors.white10 : Colors.black12;

        final presets = [5, 10, 15, 30, 45, 60];

        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              Text(
                '设置课程闹钟',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '设置提前 N 分钟的原生闹钟提醒',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: presets.length,
                  separatorBuilder: (context, index) => Container(height: 1, color: dividerColor),
                  itemBuilder: (context, index) {
                    final mins = presets[index];
                    return ListTile(
                      leading: const Icon(Icons.alarm, color: Colors.blue),
                      title: Text('提前 $mins 分钟'),
                      subtitle: Text('将于 ${viewModel.calculateDate(course.week, course.day)} ${_formatTime(cDateTime.subtract(Duration(minutes: mins)))} 响铃'),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () async {
                        final result = await AlarmService.scheduleSingleCourseAlarm(
                          course: course,
                          courseDateTime: cDateTime,
                          leadMinutes: mins,
                        );
                        if (result == 'success') {
                          viewModel.triggerToast('闹钟设置成功');
                        } else if (result == 'duplicate') {
                          viewModel.triggerToast('该时间已设置过闹钟，请勿重复设置');
                        } else if (result == 'past') {
                          viewModel.triggerToast('设置的时间已过期，请重新选择');
                        } else if (result == 'no_permission') {
                          viewModel.triggerToast('闹钟设置失败，请授予闹钟与通知权限');
                        } else {
                          viewModel.triggerToast('闹钟设置失败，请检查权限');
                        }
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                      },
                    );
                  },
                ),
              ),
              Container(height: 1, color: dividerColor),
              ListTile(
                leading: const Icon(Icons.alarm_off, color: Colors.red),
                title: const Text('取消闹钟', style: TextStyle(color: Colors.red)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () async {
                  await AlarmService.cancelAlarm(course.id);
                  viewModel.triggerToast('已取消该课程闹钟');
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
