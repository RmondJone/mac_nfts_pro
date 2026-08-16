import 'package:flutter/material.dart';
import '../../../defines/ly_colors.dart';
import '../../../defines/ly_fonts.dart';
import '../../../widgets/ly_button.dart';

/// 注释：磁盘空状态占位组件
/// 时间：2026/08/16 12:20
/// 作者：郭翰林
class EmptyDiskView extends StatelessWidget {
  final VoidCallback onRefresh;

  const EmptyDiskView({super.key, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.usb_off_rounded,
            size: 64,
            color: isDark ? Colors.white24 : Colors.black26,
          ),
          const SizedBox(height: 16),
          Text(
            '未检测到符合条件的磁盘',
            style: LyFonts.titleMedium.copyWith(
              color: isDark
                  ? LyColors.textPrimaryDark
                  : LyColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '请插入 NTFS 格式移动硬盘、U盘，或点击下方按钮刷新',
            style: LyFonts.bodySmall.copyWith(
              color: isDark
                  ? LyColors.textSecondaryDark
                  : LyColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 20),
          LyButton(
            text: '重新扫描磁盘',
            icon: Icons.refresh_rounded,
            type: LyButtonType.primary,
            onPressed: onRefresh,
          ),
        ],
      ),
    );
  }
}
