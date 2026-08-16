import 'package:flutter/material.dart';
import '../defines/ly_colors.dart';

/// 注释：通用输入框组件
/// 时间：2026/08/16 12:20
/// 作者：郭翰林
class LyInput extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool readOnly;
  final VoidCallback? onTap;

  const LyInput({
    super.key,
    this.controller,
    this.hintText,
    this.onChanged,
    this.prefixIcon,
    this.suffixIcon,
    this.readOnly = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? LyColors.borderDark : LyColors.borderLight,
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        onChanged: onChanged,
        style: TextStyle(
          fontSize: 13,
          color: isDark ? LyColors.textPrimaryDark : LyColors.textPrimaryLight,
        ),
        decoration: InputDecoration(
          isDense: true,
          hintText: hintText,
          hintStyle: TextStyle(
            fontSize: 13,
            color: isDark
                ? LyColors.textSecondaryDark
                : LyColors.textSecondaryLight,
          ),
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }
}
