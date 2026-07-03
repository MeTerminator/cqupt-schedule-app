import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/update_service.dart';
import '../view_models/schedule_view_model.dart';

class AboutView extends StatefulWidget {
  final ScheduleViewModel viewModel;

  const AboutView({super.key, required this.viewModel});

  @override
  State<AboutView> createState() => _AboutViewState();
}

class _AboutViewState extends State<AboutView> {
  String _versionString = '加载中...';
  bool _isCheckingUpdate = false;

  static const Color schoolGreen = Color.fromRGBO(0, 122, 89, 1);

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _versionString = '${packageInfo.version} (Build ${packageInfo.buildNumber})';
      });
    } catch (_) {
      setState(() {
        _versionString = '1.0.0';
      });
    }
  }

  Future<void> _checkUpdateManual() async {
    if (_isCheckingUpdate) return;
    setState(() {
      _isCheckingUpdate = true;
    });

    widget.viewModel.triggerToast('正在检测最新版本...');

    try {
      final updateInfo = await UpdateService.checkUpdate();
      if (mounted) {
        setState(() {
          _isCheckingUpdate = false;
        });
        if (updateInfo != null) {
          UpdateService.showUpdateDialog(context, updateInfo);
        } else {
          widget.viewModel.triggerToast('当前已经是最新版本');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingUpdate = false;
        });
        widget.viewModel.triggerToast('检测更新失败: $e');
      }
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        widget.viewModel.triggerToast('无法打开链接: $urlString');
      }
    } catch (e) {
      widget.viewModel.triggerToast('无法打开链接: $e');
    }
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    widget.viewModel.triggerToast(message);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('关于重邮课表'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            // App Logo / Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: schoolGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                size: 48,
                color: schoolGreen,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '重邮课表',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '版本：$_versionString',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            
            // List options
            Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.favorite_rounded, color: Colors.redAccent),
                    title: const Text('赞助鸣谢'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _launchUrl('https://cqupt.ishub.top/sponsor/'),
                  ),
                  Divider(height: 1, indent: 56, color: isDark ? Colors.grey[800] : Colors.grey[300]),
                  ListTile(
                    leading: const Icon(Icons.code_rounded, color: Colors.blueAccent),
                    title: const Text('GitHub 开源主页'),
                    subtitle: const Text('MeTerminator/cqupt-schedule-app'),
                    trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                    onTap: () => _launchUrl('https://github.com/MeTerminator/cqupt-schedule-app'),
                  ),
                  Divider(height: 1, indent: 56, color: isDark ? Colors.grey[800] : Colors.grey[300]),
                  ListTile(
                    leading: const Icon(Icons.chat_bubble_rounded, color: Colors.green),
                    title: const Text('反馈 QQ 群'),
                    subtitle: const Text('1051832310'),
                    trailing: const Icon(Icons.copy_rounded, size: 18),
                    onTap: () => _copyToClipboard('1051832310', 'QQ群号已复制到剪贴板'),
                  ),
                  if (!kIsWeb && Platform.isAndroid) ...[
                    Divider(height: 1, indent: 56, color: isDark ? Colors.grey[800] : Colors.grey[300]),
                    ListTile(
                      leading: const Icon(Icons.system_update_rounded, color: schoolGreen),
                      title: const Text('检查更新'),
                      trailing: _isCheckingUpdate
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(schoolGreen),
                              ),
                            )
                          : const Icon(Icons.chevron_right_rounded),
                      onTap: _checkUpdateManual,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 64),
            // Copyright Info
            Text(
              '© 2026 MeTerminator',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
