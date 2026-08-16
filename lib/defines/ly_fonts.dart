import 'package:flutter/material.dart';

/// 注释：字体与文本样式常量类
/// 时间：2026/08/16 12:20
/// 作者：郭翰林
class LyFonts {
  static const TextStyle titleLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle mono = TextStyle(
    fontSize: 12,
    fontFamily: 'Menlo',
  );
}
