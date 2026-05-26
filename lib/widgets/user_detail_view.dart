import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../view_models/schedule_view_model.dart';
import 'calendar_export_view.dart';
import '../views/course_color_management_view.dart';
import '../views/custom_courses_view.dart';
import '../views/theme_settings_view.dart';
import '../views/desktop_widget_view.dart';
import '../views/desk_dock_widget_view.dart';
import '../views/hidden_courses_management_view.dart';
import '../views/alarm_settings_view.dart';
import '../views/live_activity_settings_view.dart';
import '../views/user_management_view.dart';
import '../views/icloud_settings_view.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/update_service.dart';

class UserDetailView extends StatefulWidget {
  final ScheduleViewModel viewModel;
  final VoidCallback onLogout;

  const UserDetailView({
    super.key,
    required this.viewModel,
    required this.onLogout,
  });

  @override
  State<UserDetailView> createState() => _UserDetailViewViewState();
}

class _UserDetailViewViewState extends State<UserDetailView> {
  String _versionString = '加载中...';

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
  }

  Future<void> _loadVersionInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _versionString = '${packageInfo.version} (Build ${packageInfo.buildNumber})';
      });
    } catch (e) {
      setState(() {
        _versionString = '1.0.0';
      });
    }
  }

  bool _isCheckingUpdate = false;

  Future<void> _checkUpdateManual() async {
    if (_isCheckingUpdate) return;
    setState(() {
      _isCheckingUpdate = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('正在检测最新版本...'),
        duration: Duration(milliseconds: 1500),
      ),
    );

    try {
      final updateInfo = await UpdateService.checkUpdate();
      if (mounted) {
        setState(() {
          _isCheckingUpdate = false;
        });
        if (updateInfo != null) {
          UpdateService.showUpdateDialog(context, updateInfo);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('当前已经是最新版本'),
              backgroundColor: Color.fromRGBO(0, 122, 89, 1),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingUpdate = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('检测更新失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
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
              // 顶部指示条（作为拖动把手）
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // 标题栏
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '用户详情',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),

              // 内容区域：必须使用传入的 scrollController
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. 个人信息
                      _buildSection(context, '个人信息', [
                        _buildRow(
                          context,
                          '姓名',
                          widget.viewModel.scheduleData?.studentName ?? '',
                        ),
                        _buildRow(
                          context,
                          '学号',
                          widget.viewModel.scheduleData?.studentId ?? '',
                        ),
                      ]),
                      const SizedBox(height: 16),

                      // 2. 学期信息
                      _buildSection(context, '学期信息', [
                        _buildRow(
                          context,
                          '学年',
                          widget.viewModel.scheduleData?.academicYear ?? '',
                        ),
                        _buildRow(
                          context,
                          '学期',
                          '第 ${widget.viewModel.scheduleData?.semester ?? ""} 学期',
                        ),
                        _buildRow(
                          context,
                          '开学日期',
                          widget.viewModel.scheduleData?.week1Monday.substring(
                                0,
                                10,
                              ) ??
                              '',
                        ),
                      ]),
                      const SizedBox(height: 16),

                      // 3. 课表设置
                      _buildSection(context, '课表设置', [
                        ListTile(
                          leading: const Icon(Icons.list_alt),
                          title: const Text('自定义行程'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CustomCoursesView(
                                  viewModel: widget.viewModel,
                                ),
                              ),
                            ).then((_) => setState(() {}));
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.palette),
                          title: const Text('课程颜色管理'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CourseColorManagementView(
                                  viewModel: widget.viewModel,
                                ),
                              ),
                            ).then((_) => setState(() {}));
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.visibility_off),
                          title: const Text('隐藏课程管理'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => HiddenCoursesManagementView(
                                  viewModel: widget.viewModel,
                                ),
                              ),
                            ).then((_) => setState(() {}));
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.dashboard),
                          title: const Text('主题设置'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ThemeSettingsView(),
                              ),
                            ).then((_) => setState(() {}));
                          },
                        ),
                      ]),
                      const SizedBox(height: 16),

                      // 4. 系统同步
                      _buildSection(context, '系统同步', [
                        _buildSyncCalendarRow(context),
                        if (!kIsWeb && (Platform.isIOS || Platform.isMacOS))
                          _buildICloudSyncRow(context),
                      ]),
                      const SizedBox(height: 16),

                      // 闹钟与实时活动
                      if (!kIsWeb && Platform.isIOS) ...[
                        _buildSection(context, '闹钟与实时活动', [
                          ListTile(
                            leading: const Icon(Icons.alarm),
                            title: const Text('闹钟管理'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AlarmSettingsView(
                                    viewModel: widget.viewModel,
                                  ),
                                ),
                              ).then((_) => setState(() {}));
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.layers_rounded),
                            title: const Text('实时活动设置'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LiveActivitySettingsView(
                                    viewModel: widget.viewModel,
                                  ),
                                ),
                              ).then((_) => setState(() {}));
                            },
                          ),
                        ]),
                        const SizedBox(height: 16),
                      ],

                      // 5. 更多功能
                      _buildSection(context, '更多功能', [
                        ListTile(
                          leading: const Icon(Icons.monitor),
                          title: const Text('桌面摆件 (1)'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DesktopWidgetView(
                                  studentId: widget.viewModel.currentId,
                                ),
                              ),
                            ).then((_) => setState(() {}));
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.dock),
                          title: const Text('桌面摆件 (2)'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DeskDockWidgetView(
                                  studentId: widget.viewModel.currentId,
                                ),
                              ),
                            ).then((_) => setState(() {}));
                          },
                        ),
                      ]),
                      const SizedBox(height: 16),

                      // 切换用户
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => UserManagementView(
                                  viewModel: widget.viewModel,
                                ),
                              ),
                            ).then((_) => setState(() {}));
                          },
                          icon: const Icon(Icons.switch_account_rounded),
                          label: const Text('切换用户档案'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromRGBO(0, 122, 89, 1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 5. 退出登录
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onLogout();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('退出登录'),
                        ),
                      ),

                      const SizedBox(height: 32),
                      // --- 版权与项目信息 ---
                      _buildFooterInfo(context),
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

  void _showCalendarSyncSheet(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CalendarExportView(viewModel: widget.viewModel),
      ),
    ).then((_) => setState(() {}));
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[850]
                : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(label),
          const Spacer(),
          Text(value, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildSyncCalendarRow(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.calendar_month),
      title: const Text('导出到系统日历'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showCalendarSyncSheet(context),
    );
  }

  Widget _buildICloudSyncRow(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.cloud_sync),
      title: const Text('iCloud 云端同步'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ICloudSettingsView(
              viewModel: widget.viewModel,
            ),
          ),
        ).then((_) => setState(() {}));
      },
    );
  }

  Widget _buildFooterInfo(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Text(
            'GitHub: MeTerminator/cqupt-schedule-app',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 6),
          Text(
            '反馈QQ群：1051832310',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 12),
          if (!kIsWeb && Platform.isAndroid) ...[
            TextButton.icon(
              onPressed: _checkUpdateManual,
              icon: _isCheckingUpdate
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color.fromRGBO(0, 122, 89, 1),
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.system_update_rounded,
                      size: 14,
                      color: Color.fromRGBO(0, 122, 89, 1),
                    ),
              label: const Text(
                '检查更新',
                style: TextStyle(
                  fontSize: 12,
                  color: Color.fromRGBO(0, 122, 89, 1),
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            '版本：$_versionString',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[400],
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '© 2026 MeTerminator',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[400],
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }
}
