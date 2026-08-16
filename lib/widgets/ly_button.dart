import 'package:flutter/material.dart';
import '../defines/ly_colors.dart';

/// 注释：通用按钮组件
/// 时间：2026/08/16 12:20
/// 作者：郭翰林
enum LyButtonType { primary, secondary, danger, ghost }

class LyButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final LyButtonType type;
  final double? width;
  final double height;

  const LyButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.type = LyButtonType.primary,
    this.width,
    this.height = 34,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bg;
    Color fg;
    BorderSide borderSide = BorderSide.none;

    switch (type) {
      case LyButtonType.primary:
        bg = LyColors.primary;
        fg = Colors.white;
        break;
      case LyButtonType.secondary:
        bg = isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE5E5EA);
        fg = isDark ? LyColors.textPrimaryDark : LyColors.textPrimaryLight;
        break;
      case LyButtonType.danger:
        bg = LyColors.error;
        fg = Colors.white;
        break;
      case LyButtonType.ghost:
        bg = Colors.transparent;
        fg = LyColors.primary;
        borderSide = const BorderSide(color: LyColors.primary, width: 1);
        break;
    }

    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: borderSide,
          ),
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: fg),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
