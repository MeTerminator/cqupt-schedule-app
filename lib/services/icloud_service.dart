import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

class ICloudService {
  static const MethodChannel _channel = MethodChannel('top.met6.cquptschedule/icloud');

  /// 判断当前平台是否为 Apple 平台 (iOS 或 macOS)
  static bool get isApplePlatform => !kIsWeb && (Platform.isIOS || Platform.isMacOS);

  /// 检查 iCloud 是否可用（即为 Apple 平台并且原生侧可用）
  static Future<bool> isAvailable() async {
    if (!isApplePlatform) return false;
    try {
      final bool? available = await _channel.invokeMethod<bool>('isAvailable');
      return available ?? false;
    } catch (e) {
      return false;
    }
  }

  /// 向 iCloud 写入键值对
  static Future<bool> setString(String key, String value) async {
    if (!isApplePlatform) return false;
    try {
      final bool? success = await _channel.invokeMethod<bool>('setString', {
        'key': key,
        'value': value,
      });
      return success ?? false;
    } catch (e) {
      return false;
    }
  }

  /// 从 iCloud 读取字符串
  static Future<String?> getString(String key) async {
    if (!isApplePlatform) return null;
    try {
      return await _channel.invokeMethod<String>('getString', key);
    } catch (e) {
      return null;
    }
  }

  /// 从 iCloud 中删除某个键
  static Future<bool> remove(String key) async {
    if (!isApplePlatform) return false;
    try {
      final bool? success = await _channel.invokeMethod<bool>('remove', key);
      return success ?? false;
    } catch (e) {
      return false;
    }
  }

  /// 拉取云端保存的所有数据键值对
  static Future<Map<String, String>> getAllData() async {
    if (!isApplePlatform) return {};
    try {
      final Map<dynamic, dynamic>? data = await _channel.invokeMethod<Map<dynamic, dynamic>>('getAllData');
      if (data == null) return {};
      return data.map((key, value) => MapEntry(key.toString(), value.toString()));
    } catch (e) {
      return {};
    }
  }
}
