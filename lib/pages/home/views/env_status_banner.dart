import 'package:flutter/material.dart';
import '../../../defines/ly_colors.dart';
import '../../../defines/ly_fonts.dart';
import '../../../widgets/ly_badge.dart';
import '../../../widgets/ly_button.dart';
import '../models/env_status_model.dart';

/// 注释：驱动环境状态横幅组件
/// 时间：2026/08/16 12:20
/// 作者：郭翰林
class EnvStatusBanner extends StatelessWidget {
  final EnvStatusModel? env;
  final bool isInstalling;
  final VoidCallback onInstallDrivers;
  final VoidCallback onRefresh;

  const EnvStatusBanner({
    super.key,
    required this.env,
    required this.isInstalling,
    required this.onInstallDrivers,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isReady = env?.canWriteNtfs ?? false;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isReady
            ? (isDark ? const Color(0xFF1B2F20) : const Color(0xFFEBF8EE))
            : (isDark ? const Color(0xFF332617) : const Color(0xFFFFF7EB)),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isReady
              ? LyColors.success.withValues(alpha: 0.3)
              : LyColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isReady ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
            color: isReady ? LyColors.success : LyColors.warning,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'NTFS 驱动引擎: ${env?.activeDriverName ?? "检测中..."}',
                      style: LyFonts.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? LyColors.textPrimaryDark
                            : LyColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(width: 8),
                    LyBadge(
                      label: isReady ? '驱动正常' : '需要配置',
                      textColor: isReady ? LyColors.success : LyColors.warning,
                      backgroundColor: isReady
                          ? LyColors.successLight
                          : LyColors.warningLight,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  env?.checkMessage ?? '正在检测系统驱动环境...',
                  style: LyFonts.bodySmall.copyWith(
                    color: isDark
                        ? LyColors.textSecondaryDark
                        : LyColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          if (!isReady) ...[
            const SizedBox(width: 12),
            LyButton(
              text: '一键配置驱动',
              icon: Icons.download_rounded,
              isLoading: isInstalling,
              type: LyButtonType.primary,
              height: 30,
              onPressed: onInstallDrivers,
            ),
          ],
          const SizedBox(width: 8),
          IconButton(
            tooltip: '重新检测环境',
            icon: Icon(
              Icons.refresh_rounded,
              size: 18,
              color: isDark
                  ? LyColors.textSecondaryDark
                  : LyColors.textSecondaryLight,
            ),
            onPressed: onRefresh,
          ),
        ],
      ),
    );
  }
}
