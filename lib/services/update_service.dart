import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kSavedDownloadIdKey = 'cqupt_schedule_download_id';
const String _kSavedDownloadVersionKey = 'cqupt_schedule_download_version';

class UpdateInfo {
  final int versionCode;
  final String versionName;
  final String downloadUrl;
  final String releaseNotes;
  final bool forceUpdate;

  UpdateInfo({
    required this.versionCode,
    required this.versionName,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.forceUpdate,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      versionCode: json['versionCode'] as int,
      versionName: json['versionName'] as String,
      downloadUrl: json['downloadUrl'] as String,
      releaseNotes: json['releaseNotes'] as String,
      forceUpdate: json['forceUpdate'] as bool? ?? false,
    );
  }
}

class UpdateService {
  static const _channel = MethodChannel('top.met6.cquptschedule/update');
  static const String _updateApiUrl = 'https://cqupt.ishub.top/update.php';

  /// Performs background update check.
  /// Returns [UpdateInfo] if a new update is available, null otherwise.
  static Future<UpdateInfo?> checkUpdate() async {
    try {
      final response = await http.get(Uri.parse(_updateApiUrl)).timeout(
        const Duration(seconds: 10),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final updateInfo = UpdateInfo.fromJson(data);
        
        final packageInfo = await PackageInfo.fromPlatform();
        final localVersionCode = int.tryParse(packageInfo.buildNumber) ?? 0;

        if (updateInfo.versionCode > localVersionCode) {
          return updateInfo;
        }
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
    }
    return null;
  }

  /// Dialog to show update alert
  static void showUpdateDialog(BuildContext context, UpdateInfo updateInfo) {
    showDialog(
      context: context,
      barrierDismissible: !updateInfo.forceUpdate,
      builder: (context) {
        return _UpdateDialogWidget(updateInfo: updateInfo);
      },
    );
  }
}

class _UpdateDialogWidget extends StatefulWidget {
  final UpdateInfo updateInfo;

  const _UpdateDialogWidget({required this.updateInfo});

  @override
  State<_UpdateDialogWidget> createState() => _UpdateDialogWidgetState();
}

class _UpdateDialogWidgetState extends State<_UpdateDialogWidget> {
  bool _isDownloading = false;
  bool _isDownloaded = false;
  double _downloadProgress = 0.0;
  String? _errorMessage;
  int? _downloadId;
  String? _apkPath;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _checkInitialState();
  }

  Future<void> _checkInitialState() async {
    final versionCode = widget.updateInfo.versionCode;

    // 1. Check if the APK file already exists in the Downloads folder
    try {
      final path = await UpdateService._channel.invokeMethod<String>('checkApkExists', versionCode);
      if (path != null && path.isNotEmpty) {
        if (mounted) {
          setState(() {
            _isDownloaded = true;
            _apkPath = path;
            _downloadProgress = 1.0;
          });
        }
        return;
      }
    } catch (e) {
      debugPrint('Error checking local APK file: $e');
    }

    // 2. Check if there is an active or completed download ID in SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getInt(_kSavedDownloadIdKey);
      final savedVersion = prefs.getInt(_kSavedDownloadVersionKey);

      if (savedId != null && savedVersion == versionCode) {
        final progressData = await UpdateService._channel.invokeMapMethod<String, dynamic>(
          'getDownloadProgress',
          savedId,
        );

        if (progressData != null) {
          final int status = progressData['status'] as int? ?? 16;
          final double progress = progressData['progress'] as double? ?? 0.0;

          // DownloadManager status values:
          // STATUS_PENDING = 1
          // STATUS_RUNNING = 2
          // STATUS_PAUSED = 4
          // STATUS_SUCCESSFUL = 8
          // STATUS_FAILED = 16
          if (status == 8) { // STATUS_SUCCESSFUL
            if (mounted) {
              setState(() {
                _isDownloaded = true;
                _downloadId = savedId;
                _downloadProgress = 1.0;
              });
            }
          } else if (status == 1 || status == 2 || status == 4) { // Active download
            if (mounted) {
              setState(() {
                _isDownloading = true;
                _downloadId = savedId;
                _downloadProgress = progress;
              });
            }
            _startProgressTimer(savedId);
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking saved download ID: $e');
    }
  }

  void _startProgressTimer(int downloadId) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      try {
        final progressData = await UpdateService._channel.invokeMapMethod<String, dynamic>(
          'getDownloadProgress',
          downloadId,
        );

        if (progressData != null) {
          final int status = progressData['status'] as int? ?? 16;
          final double progress = progressData['progress'] as double? ?? 0.0;

          if (mounted) {
            setState(() {
              _downloadProgress = progress;
            });
          }

          if (status == 8) { // STATUS_SUCCESSFUL
            timer.cancel();
            if (mounted) {
              setState(() {
                _isDownloading = false;
                _isDownloaded = true;
                _downloadProgress = 1.0;
              });
            }
            // Trigger automatic installation!
            _triggerInstall();
          } else if (status == 16) { // STATUS_FAILED
            timer.cancel();
            if (mounted) {
              setState(() {
                _isDownloading = false;
                _errorMessage = '下载失败，请稍后重试';
              });
            }
          }
        } else {
          timer.cancel();
        }
      } catch (e) {
        timer.cancel();
        debugPrint('Error querying download progress: $e');
      }
    });
  }

  Future<void> _triggerInstall() async {
    try {
      // 1. Check if the user has the install permission
      final hasPermission = await UpdateService._channel.invokeMethod<bool>('checkInstallPermission') ?? false;
      if (!hasPermission) {
        _showPermissionExplanationDialog();
        return;
      }

      // 2. Trigger native APK installation
      if (_apkPath != null) {
        await UpdateService._channel.invokeMethod('installApk', {'apkPath': _apkPath});
      } else if (_downloadId != null) {
        await UpdateService._channel.invokeMethod('installApk', {'downloadId': _downloadId});
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '启动安装失败，请手动打开通知栏安装\n$e';
        });
      }
    }
  }

  void _showPermissionExplanationDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        const primaryColor = Color.fromRGBO(0, 122, 89, 1);

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          title: Row(
            children: [
              const Icon(Icons.security_rounded, color: primaryColor, size: 24),
              const SizedBox(width: 8),
              Text(
                '安装权限授权说明',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          content: const Text(
            '为了安全、无缝地为您安装更新，我们需要您授权「允许安装未知应用」权限。\n\n点击下方「去开启」按钮将带您直接前往系统设置，请为『重邮课表』打开此开关，随后返回应用即可自动进行安装。',
            style: TextStyle(height: 1.5, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消', style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await UpdateService._channel.invokeMethod('requestInstallPermission');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('去开启'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleDownloadOrInstall() async {
    if (_isDownloaded) {
      _triggerInstall();
      return;
    }

    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _downloadProgress = 0.0;
    });

    try {
      final versionCode = widget.updateInfo.versionCode;

      // Start download via DownloadManager MethodChannel
      final downloadId = await UpdateService._channel.invokeMethod<int>('startDownload', {
        'url': widget.updateInfo.downloadUrl,
        'versionCode': versionCode,
      });

      if (downloadId != null) {
        // Persist download info in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_kSavedDownloadIdKey, downloadId);
        await prefs.setInt(_kSavedDownloadVersionKey, versionCode);

        if (mounted) {
          setState(() {
            _downloadId = downloadId;
          });
        }
        _startProgressTimer(downloadId);
      } else {
        throw Exception('无法加入下载队列');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = '启动下载失败，请稍后重试\n$e';
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const primaryColor = Color.fromRGBO(0, 122, 89, 1);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 8,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with Icon & Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    color: primaryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '发现新版本 ${widget.updateInfo.versionName}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '发现升级，建议立即更新',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Release Notes Card
            Text(
              '更新日志：',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxHeight: 150),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: SingleChildScrollView(
                child: Text(
                  widget.updateInfo.releaseNotes,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Download Progress or Actions
            if (_isDownloading)
              Column(
                children: [
                  LinearProgressIndicator(
                    value: _downloadProgress > 0 ? _downloadProgress : null,
                    color: primaryColor,
                    backgroundColor: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '正在下载更新包...',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                      Text(
                        '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '可在系统通知栏实时查看进度，关闭此弹窗下载仍将在后台继续',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[500],
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            else if (_errorMessage != null)
              Column(
                children: [
                  Text(
                    _errorMessage!,
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _handleDownloadOrInstall,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('重试'),
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!widget.updateInfo.forceUpdate)
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        '稍后',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _handleDownloadOrInstall,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      _isDownloaded ? '立即安装' : '下载并安装',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
