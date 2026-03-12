import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 课程预设颜色列表
/// 这些颜色通过 HSL 色环均分生成
class CourseColors {
  CourseColors._();

  /// 生成预设颜色列表
  static List<Color> get presetColors {
    return List.generate(20, (index) {
      return dynamicCourseColor(index: index, total: 20);
    });
  }

  /// 根据索引获取动态课程颜色
  static Color dynamicCourseColor({required int index, required int total}) {
    final hue = (index * (360.0 / total)) % 360;
    const saturation = 0.7;
    const lightness = 0.6;

    return _hslToColor(hue, saturation, lightness);
  }

  /// HSL 转 Color
  static Color _hslToColor(double h, double s, double l) {
    final r = _hueToRgb((h / 360) + (1.0 / 3.0), s, l);
    final g = _hueToRgb((h / 360), s, l);
    final b = _hueToRgb((h / 360) - (1.0 / 3.0), s, l);

    return Color.fromRGBO(
      (r * 255).round(),
      (g * 255).round(),
      (b * 255).round(),
      1.0,
    );
  }

  static double _hueToRgb(double t1, double t2, double hue) {
    double h = hue;
    if (h < 0) h += 1;
    if (h > 1) h -= 1;

    if (h < (1.0 / 6.0)) return t2 + (t1 - t2) * 6.0 * h;
    if (h < (1.0 / 2.0)) return t1;
    if (h < (2.0 / 3.0)) return t2 + (t1 - t2) * ((2.0 / 3.0) - h) * 6.0;

    return t2;
  }

  /// 查找最接近的颜色索引
  static int findClosestColorIndex(Color color) {
    int closestIndex = 0;
    double minDistance = double.infinity;

    for (int i = 0; i < presetColors.length; i++) {
      final distance = _colorDistance(color, presetColors[i]);
      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }

    return closestIndex;
  }

  /// 计算两个颜色之间的距离
  static double _colorDistance(Color c1, Color c2) {
    final r1 = c1.red.toDouble();
    final g1 = c1.green.toDouble();
    final b1 = c1.blue.toDouble();
    final r2 = c2.red.toDouble();
    final g2 = c2.green.toDouble();
    final b2 = c2.blue.toDouble();

    return math.sqrt(
      (r1 - r2) * (r1 - r2) +
      (g1 - g2) * (g1 - g2) +
      (b1 - b2) * (b1 - b2),
    );
  }
}
