import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../view_models/schedule_view_model.dart';

class ICloudSettingsView extends StatefulWidget {
  final ScheduleViewModel viewModel;

  const ICloudSettingsView({super.key, required this.viewModel});

  @override
  State<ICloudSettingsView> createState() => _ICloudSettingsViewState();
}

class _ICloudSettingsViewState extends State<ICloudSettingsView> {
  Color get schoolGreen => const Color.fromRGBO(0, 122, 89, 1);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          'iCloud 云端同步',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      body: Consumer<ScheduleViewModel>(
        builder: (context, viewModel, _) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCloudHeader(context),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _buildSyncStatusCard(context, viewModel),
                      const SizedBox(height: 16),
                      if (viewModel.icloudSyncEnabled) ...[
                        _buildSyncOptionsCard(context, viewModel),
                        const SizedBox(height: 24),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCloudHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.cloud_done_rounded,
                size: 56,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'iCloud 云端同步',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                '在您的苹果设备间自动备份并同步课表日程、颜色、隐藏课表、主题设置及多用户档案。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncStatusCard(BuildContext context, ScheduleViewModel viewModel) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SwitchListTile(
        secondary: const Icon(Icons.cloud_sync, size: 28, color: Colors.blue),
        title: const Text('开启 iCloud 同步', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          viewModel.icloudSyncEnabled ? '已与云端建立实时连接' : '关闭后数据仅保存在本设备',
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
        value: viewModel.icloudSyncEnabled,
        activeThumbColor: schoolGreen,
        onChanged: (bool value) async {
          HapticFeedback.mediumImpact();
          await viewModel.setICloudSyncEnabled(value);
        },
      ),
    );
  }

  Widget _buildSyncOptionsCard(BuildContext context, ScheduleViewModel viewModel) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '选择同步内容',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey[500],
              ),
            ),
          ),
          SwitchListTile(
            dense: true,
            title: const Text('同步自定义行程', style: TextStyle(fontSize: 14)),
            value: viewModel.icloudSyncCustomCourses,
            activeThumbColor: schoolGreen,
            onChanged: (bool value) async {
              HapticFeedback.lightImpact();
              await viewModel.toggleICloudSyncOption('custom_courses', value);
            },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          SwitchListTile(
            dense: true,
            title: const Text('同步课程颜色', style: TextStyle(fontSize: 14)),
            value: viewModel.icloudSyncCourseColors,
            activeThumbColor: schoolGreen,
            onChanged: (bool value) async {
              HapticFeedback.lightImpact();
              await viewModel.toggleICloudSyncOption('course_colors', value);
            },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          SwitchListTile(
            dense: true,
            title: const Text('同步隐藏课程', style: TextStyle(fontSize: 14)),
            value: viewModel.icloudSyncHiddenCourses,
            activeThumbColor: schoolGreen,
            onChanged: (bool value) async {
              HapticFeedback.lightImpact();
              await viewModel.toggleICloudSyncOption('hidden_courses', value);
            },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          SwitchListTile(
            dense: true,
            title: const Text('同步主题设置', style: TextStyle(fontSize: 14)),
            value: viewModel.icloudSyncTheme,
            activeThumbColor: schoolGreen,
            onChanged: (bool value) async {
              HapticFeedback.lightImpact();
              await viewModel.toggleICloudSyncOption('theme', value);
            },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          SwitchListTile(
            dense: true,
            title: const Text('同步多用户档案', style: TextStyle(fontSize: 14)),
            value: viewModel.icloudSyncProfiles,
            activeThumbColor: schoolGreen,
            onChanged: (bool value) async {
              HapticFeedback.lightImpact();
              await viewModel.toggleICloudSyncOption('profiles', value);
            },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            title: const Text(
              '立即手动同步',
              style: TextStyle(fontSize: 14, color: Colors.blue, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('执行双向云端数据对齐', style: TextStyle(fontSize: 11)),
            trailing: viewModel.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Icon(Icons.sync_rounded, color: Colors.blue, size: 20),
            onTap: viewModel.isLoading
                ? null
                : () async {
                    HapticFeedback.mediumImpact();
                    await viewModel.pushAllToICloud();
                    await viewModel.pullFromICloud();
                    viewModel.triggerToast("数据同步完成");
                  },
          ),
        ],
      ),
    );
  }
}
