import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../view_models/schedule_view_model.dart';
import '../models/hidden_rule_model.dart';

class HiddenCoursesManagementView extends StatefulWidget {
  final ScheduleViewModel viewModel;

  const HiddenCoursesManagementView({super.key, required this.viewModel});

  @override
  State<HiddenCoursesManagementView> createState() => _HiddenCoursesManagementViewState();
}

class _HiddenCoursesManagementViewState extends State<HiddenCoursesManagementView> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final List<HiddenRule> rules = widget.viewModel.hiddenRules;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          '已隐藏课程',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        actions: rules.isEmpty
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                  tooltip: '全部恢复显示',
                  onPressed: () => _confirmClearAll(context),
                ),
              ],
      ),
      body: rules.isEmpty ? _buildEmptyState(context) : _buildRulesList(context, rules),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Colors.blueAccent, Colors.purpleAccent],
                ).createShader(bounds),
                child: const Icon(
                  Icons.visibility,
                  size: 48,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '课表很完整',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '当前没有隐藏任何课程，所有已同步和自定义日程都会完美呈现在你的课表中。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRulesList(BuildContext context, List<HiddenRule> rules) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: rules.length,
      itemBuilder: (context, index) {
        final rule = rules[index];
        return _buildRuleCard(context, rule);
      },
    );
  }

  Widget _buildRuleCard(BuildContext context, HiddenRule rule) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color tagBgColor;
    Color tagTextColor;
    String tagLabel;

    switch (rule.type) {
      case 'all':
        tagBgColor = Colors.purple.withValues(alpha: 0.12);
        tagTextColor = Colors.purpleAccent;
        tagLabel = '全部隐藏';
        break;
      case 'time_slot':
        tagBgColor = Colors.orange.withValues(alpha: 0.12);
        tagTextColor = Colors.orangeAccent;
        tagLabel = '特定时段';
        break;
      case 'single':
      default:
        tagBgColor = Colors.blue.withValues(alpha: 0.12);
        tagTextColor = Colors.blueAccent;
        tagLabel = '单节隐藏';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: tagBgColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tagLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: tagTextColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            rule.courseName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _getRuleDescription(rule),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  widget.viewModel.removeHiddenRuleById(rule.id);
                  widget.viewModel.triggerToast('已恢复《${rule.courseName}》显示');
                  setState(() {});
                },
                icon: const Icon(Icons.visibility, size: 14),
                label: const Text('恢复'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blueAccent,
                  side: const BorderSide(color: Colors.blueAccent, width: 1.2),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getRuleDescription(HiddenRule rule) {
    switch (rule.type) {
      case 'all':
        return '已隐藏全部该课程的所有周次';
      case 'time_slot':
        return '隐藏范围：每周 ${rule.displayText.substring(rule.displayText.indexOf('(') + 1, rule.displayText.length - 1)}';
      case 'single':
      default:
        return '隐藏单节：${rule.displayText.substring(rule.displayText.indexOf('(') + 1, rule.displayText.length - 1)}';
    }
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('全部恢复显示'),
        content: const Text('确定要将所有已隐藏的课程恢复显示吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.viewModel.clearAllHiddenRules();
              widget.viewModel.triggerToast('已恢复所有隐藏的课程');
              setState(() {});
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            child: const Text('确定恢复', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
