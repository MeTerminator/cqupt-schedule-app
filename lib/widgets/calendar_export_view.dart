import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../view_models/schedule_view_model.dart';
import '../services/calendar_service.dart'; // 导入 Service
import '../models/schedule_model.dart'; // 导入 Model

class CalendarExportView extends StatefulWidget {
  final ScheduleViewModel viewModel;

  const CalendarExportView({super.key, required this.viewModel});

  @override
  State<CalendarExportView> createState() => _CalendarExportViewState();
}

class _CalendarExportViewState extends State<CalendarExportView> {
  final CalendarService _calendarService = CalendarService(); // 实例化 Service

  bool _isLoading = false; // 本地 loading 状态

  // Settings
  bool _exportNormal = true;
  late TextEditingController _normalNameController;

  bool _exportMakeup = true;
  late TextEditingController _makeupNameController;

  bool _exportExam = true;
  late TextEditingController _examNameController;

  bool _mergeMakeupToNormal = false;
  bool _mergeExamToNormal = false;

  bool _enableAlarm = true;
  int _firstAlert = 30;
  int _secondAlert = 10;

  final List<int> _options = [5, 10, 15, 30, 45, 60];

  @override
  void initState() {
    super.initState();
    _normalNameController = TextEditingController(text: '重邮课表');
    _makeupNameController = TextEditingController(text: '重邮课表-补课');
    _examNameController = TextEditingController(text: '重邮课表-考试');
    _loadSettings();

    _normalNameController.addListener(() => setState(() {}));
    _makeupNameController.addListener(() => setState(() {}));
    _examNameController.addListener(() => setState(() {}));
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _exportNormal = prefs.getBool('cal_export_normal') ?? true;
      _exportMakeup = prefs.getBool('cal_export_makeup') ?? true;
      _exportExam = prefs.getBool('cal_export_exam') ?? true;
      
      _normalNameController.text = prefs.getString('cal_name_normal') ?? '重邮课表';
      _makeupNameController.text = prefs.getString('cal_name_makeup') ?? '重邮课表-补课';
      _examNameController.text = prefs.getString('cal_name_exam') ?? '重邮课表-考试';
      
      _mergeMakeupToNormal = prefs.getBool('cal_merge_makeup') ?? false;
      _mergeExamToNormal = prefs.getBool('cal_merge_exam') ?? false;

      _enableAlarm = prefs.getBool('cal_enable_alarm') ?? true;
      _firstAlert = prefs.getInt('cal_first_alert') ?? 30;
      _secondAlert = prefs.getInt('cal_second_alert') ?? 10;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cal_export_normal', _exportNormal);
    await prefs.setBool('cal_export_makeup', _exportMakeup);
    await prefs.setBool('cal_export_exam', _exportExam);
    
    await prefs.setString('cal_name_normal', _normalNameController.text.trim());
    await prefs.setString('cal_name_makeup', _makeupNameController.text.trim());
    await prefs.setString('cal_name_exam', _examNameController.text.trim());
    
    await prefs.setBool('cal_merge_makeup', _mergeMakeupToNormal);
    await prefs.setBool('cal_merge_exam', _mergeExamToNormal);

    await prefs.setBool('cal_enable_alarm', _enableAlarm);
    await prefs.setInt('cal_first_alert', _firstAlert);
    await prefs.setInt('cal_second_alert', _secondAlert);
  }

  @override
  void dispose() {
    _normalNameController.dispose();
    _makeupNameController.dispose();
    _examNameController.dispose();
    super.dispose();
  }

  /// 核心导出逻辑
  Future<void> _handleExport() async {
    // 保存当前设置
    await _saveSettings();

    bool willExportNormal = _exportNormal || (!_exportMakeup && _mergeMakeupToNormal) || (!_exportExam && _mergeExamToNormal);
    if (!willExportNormal && !_exportMakeup && !_exportExam) {
      widget.viewModel.triggerToast('请至少选择一项要导出的课程类型');
      return;
    }

    // 1. 震动反馈
    HapticFeedback.mediumImpact();

    // 2. 获取数据准备
    final week1Monday = widget.viewModel.scheduleData?.week1Monday ?? '';
    if (week1Monday.isEmpty) {
      widget.viewModel.triggerToast('错误：未找到学期开学日期');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 3. 汇总 0-22 周所有课程实例（包含自定义课程）
      final allInstances = <CourseInstance>[];
      for (int w = 0; w <= 22; w++) {
        allInstances.addAll(widget.viewModel.allCourses(w));
      }

      if (allInstances.isEmpty) {
        throw '当前没有可同步的课程数据';
      }

      bool overallSuccess = true;

      // 分类数据
      final baseNormalInstances = allInstances.where((e) => e.type != '补课' && e.type != '考试').toList();
      final makeupInstances = allInstances.where((e) => e.type == '补课').toList();
      final examInstances = allInstances.where((e) => e.type == '考试').toList();

      final normalInstancesToSync = <CourseInstance>[];
      if (_exportNormal) {
        normalInstancesToSync.addAll(baseNormalInstances);
      }
      if (!_exportMakeup && _mergeMakeupToNormal) {
        normalInstancesToSync.addAll(makeupInstances);
      }
      if (!_exportExam && _mergeExamToNormal) {
        normalInstancesToSync.addAll(examInstances);
      }

      final firstAlert = _enableAlarm ? _firstAlert : null;
      final secondAlert = (_enableAlarm && _secondAlert > 0) ? _secondAlert : null;

      // 4. 调用 Service 执行同步
      if (normalInstancesToSync.isNotEmpty) {
        final name = _normalNameController.text.trim().isEmpty ? '重邮课表' : _normalNameController.text.trim();
        overallSuccess &= await _calendarService.syncCourses(
          instances: normalInstancesToSync,
          startDateStr: week1Monday,
          calendarName: name,
          firstAlertMinutes: firstAlert,
          secondAlertMinutes: secondAlert,
        );
      }

      if (_exportMakeup && makeupInstances.isNotEmpty) {
        final name = _makeupNameController.text.trim().isEmpty ? '重邮课表-补课' : _makeupNameController.text.trim();
        overallSuccess &= await _calendarService.syncCourses(
          instances: makeupInstances,
          startDateStr: week1Monday,
          calendarName: name,
          firstAlertMinutes: firstAlert,
          secondAlertMinutes: secondAlert,
        );
      }

      if (_exportExam && examInstances.isNotEmpty) {
        final name = _examNameController.text.trim().isEmpty ? '重邮课表-考试' : _examNameController.text.trim();
        overallSuccess &= await _calendarService.syncCourses(
          instances: examInstances,
          startDateStr: week1Monday,
          calendarName: name,
          firstAlertMinutes: firstAlert,
          secondAlertMinutes: secondAlert,
        );
      }

      if (mounted) {
        if (overallSuccess) {
          widget.viewModel.triggerToast('导出完成');
          Navigator.pop(context); // 成功后返回
        } else {
          widget.viewModel.triggerToast('同步部分或全部失败：请检查权限');
        }
      }
    } catch (e) {
      if (mounted) widget.viewModel.triggerToast('同步异常: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '导出至系统日历',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('日历分类设置'),
              const SizedBox(height: 8),
              
              _buildCard(
                child: Column(
                  children: [
                    _buildToggleItem(
                      label: '常规课程及自定义行程',
                      value: _exportNormal,
                      controller: _normalNameController,
                      onChanged: (v) {
                        setState(() => _exportNormal = v);
                        _saveSettings();
                      },
                    ),
                    const Divider(height: 1, indent: 16),
                    _buildToggleItem(
                      label: '补课安排',
                      value: _exportMakeup,
                      controller: _makeupNameController,
                      onChanged: (v) {
                        setState(() => _exportMakeup = v);
                        _saveSettings();
                      },
                      mergeValue: _mergeMakeupToNormal,
                      mergeLabel: '将补课安排合并到常规课程中',
                      onMergeChanged: (v) {
                        setState(() => _mergeMakeupToNormal = v);
                        _saveSettings();
                      },
                    ),
                    const Divider(height: 1, indent: 16),
                    _buildToggleItem(
                      label: '考试安排',
                      value: _exportExam,
                      controller: _examNameController,
                      onChanged: (v) {
                        setState(() => _exportExam = v);
                        _saveSettings();
                      },
                      mergeValue: _mergeExamToNormal,
                      mergeLabel: '将考试安排合并到常规课程中',
                      onMergeChanged: (v) {
                        setState(() => _mergeExamToNormal = v);
                        _saveSettings();
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              _buildHintText('开启后，相应的课程将导出到指定名称的日历中。'),
              _buildHintText('重新同步将覆盖该日历名称下的所有旧日程。'),

              const SizedBox(height: 24),
              _buildSectionTitle('提醒设置'),
              const SizedBox(height: 8),

              _buildCard(
                child: Column(
                  children: [
                    _buildListTile(
                      label: '开启上课/考试提醒',
                      trailing: Switch.adaptive(
                        value: _enableAlarm,
                        activeColor: Colors.blueAccent,
                        onChanged: _isLoading
                            ? null
                            : (v) {
                                setState(() => _enableAlarm = v);
                                _saveSettings();
                              },
                      ),
                    ),
                    if (_enableAlarm) ...[
                      const Divider(height: 1, indent: 16),
                      _buildAlertSelector(
                        '第一次提醒',
                        _firstAlert,
                        _options,
                        (v) {
                          setState(() {
                            _firstAlert = v;
                            if (_secondAlert >= v) _secondAlert = 0;
                          });
                          _saveSettings();
                        },
                      ),
                      const Divider(height: 1, indent: 16),
                      _buildAlertSelector(
                        '第二次提醒',
                        _secondAlert,
                        [0, ..._options.where((e) => e < _firstAlert)],
                        (v) {
                          setState(() => _secondAlert = v);
                          _saveSettings();
                        },
                        isSecond: true,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 48),

              Container(
                width: double.infinity,
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: _isLoading
                        ? [Colors.grey, Colors.grey]
                        : [
                            const Color(0xFF2196F3),
                            const Color(0xFF007AFF),
                          ],
                  ),
                  boxShadow: _isLoading
                      ? []
                      : [
                          BoxShadow(
                            color: Colors.blueAccent.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleExport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          '立即同步',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // --- UI 构建 Helper 方法 ---

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }

  Widget _buildToggleItem({
    required String label,
    required bool value,
    required TextEditingController controller,
    required ValueChanged<bool> onChanged,
    bool? mergeValue,
    String? mergeLabel,
    ValueChanged<bool>? onMergeChanged,
  }) {
    return Column(
      children: [
        _buildListTile(
          label: label,
          trailing: Switch.adaptive(
            value: value,
            activeColor: Colors.blueAccent,
            onChanged: _isLoading ? null : onChanged,
          ),
        ),
        if (value)
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
            child: Row(
              children: [
                Text('日历名称', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: controller,
                    textAlign: TextAlign.right,
                    enabled: !_isLoading,
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      hintText: '请输入名称',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                    ),
                    onChanged: (_) => _saveSettings(),
                  ),
                ),
              ],
            ),
          ),
        if (!value && mergeValue != null && mergeLabel != null && onMergeChanged != null)
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
            child: Row(
              children: [
                Expanded(child: Text(mergeLabel, style: TextStyle(fontSize: 14, color: Colors.grey[600]))),
                const SizedBox(width: 16),
                Switch.adaptive(
                  value: mergeValue,
                  activeColor: Colors.blueAccent,
                  onChanged: _isLoading ? null : onMergeChanged,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildListTile({required String label, required Widget trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
          const SizedBox(width: 16),
          trailing,
        ],
      ),
    );
  }

  Widget _buildAlertSelector(
    String label,
    int current,
    List<int> options,
    Function(int) onSelect, {
    bool isSecond = false,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: options.map((m) {
                final isSelected = current == m;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(m == 0 ? '不提醒' : '$m分钟'),
                    selected: isSelected,
                    onSelected: _isLoading ? null : (_) => onSelect(m),
                    selectedColor: Colors.blueAccent.withValues(alpha: 0.2),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Colors.blueAccent
                          : (Theme.of(context).brightness == Brightness.dark
                                ? Colors.white70
                                : Colors.black87),
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    backgroundColor:
                        Theme.of(context).brightness == Brightness.dark
                        ? Colors.white10
                        : Colors.grey[100],
                    side: BorderSide(
                      color: isSelected
                          ? Colors.blueAccent
                          : Colors.transparent,
                    ),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHintText(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 14, color: Colors.orange[400]),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: Colors.orange[600]),
            ),
          ),
        ],
      ),
    );
  }
}
