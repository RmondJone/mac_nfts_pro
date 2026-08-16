import 'package:flutter/material.dart';
import '../defines/ly_colors.dart';

/// 注释：通用单行文本输入框组件 (支持文字与图标精准垂直居中)
/// 时间：2026/08/16 19:25
/// 作者：郭翰林
class LyInput extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool readOnly;
  final VoidCallback? onTap;
  final double height;
  final double? width;
  final TextStyle? style;
  final TextStyle? hintStyle;
  final EdgeInsetsGeometry? contentPadding;

  const LyInput({
    super.key,
    this.controller,
    this.hintText,
    this.onChanged,
    this.prefixIcon,
    this.suffixIcon,
    this.readOnly = false,
    this.onTap,
    this.height = 32,
    this.width,
    this.style,
    this.hintStyle,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
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
        textAlignVertical: TextAlignVertical.center,
        style: style ??
            TextStyle(
              fontSize: 13,
              color:
                  isDark ? LyColors.textPrimaryDark : LyColors.textPrimaryLight,
            ),
        decoration: InputDecoration(
          isDense: true,
          hintText: hintText,
          hintStyle: hintStyle ??
              TextStyle(
                fontSize: 13,
                color: isDark
                    ? LyColors.textSecondaryDark
                    : LyColors.textSecondaryLight,
              ),
          prefixIcon: prefixIcon,
          prefixIconConstraints: prefixIcon != null
              ? const BoxConstraints(
                  minWidth: 30,
                  maxWidth: 30,
                  minHeight: 30,
                  maxHeight: 30,
                )
              : null,
          suffixIcon: suffixIcon,
          suffixIconConstraints: suffixIcon != null
              ? const BoxConstraints(
                  minWidth: 30,
                  maxWidth: 30,
                  minHeight: 30,
                  maxHeight: 30,
                )
              : null,
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          contentPadding: contentPadding ??
              EdgeInsets.only(
                left: prefixIcon == null ? 10 : 0,
                right: suffixIcon == null ? 10 : 0,
              ),
        ),
      ),
    );
  }
}
