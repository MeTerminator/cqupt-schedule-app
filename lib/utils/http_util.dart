import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class HttpUtil {
  HttpUtil._();

  static String? _userAgent;

  static Future<String> getUserAgent() async {
    if (_userAgent != null) return _userAgent!;
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final version = packageInfo.version;
      final buildNumber = packageInfo.buildNumber;
      final platform = kIsWeb
          ? 'Web'
          : (Platform.isAndroid
              ? 'Android'
              : (Platform.isIOS ? 'iOS' : 'Unknown'));
      _userAgent = 'CQUPT-Schedule-App/$version+$buildNumber ($platform)';
    } catch (_) {
      _userAgent = 'CQUPT-Schedule-App/1.0.0 (Unknown)';
    }
    return _userAgent!;
  }

  static Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    final ua = await getUserAgent();
    final Map<String, String> finalHeaders = {
      'User-Agent': ua,
      ...?headers,
    };
    return http.get(url, headers: finalHeaders);
  }
}
