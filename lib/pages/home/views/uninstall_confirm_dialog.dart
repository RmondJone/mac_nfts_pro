import 'package:flutter/material.dart';
import '../../../defines/ly_colors.dart';
import '../../../defines/ly_fonts.dart';
import '../../../widgets/ly_button.dart';

/// 注释：一键彻底卸载确认对话框
/// 时间：2026/08/16 17:35
/// 作者：郭翰林
class UninstallConfirmDialog extends StatefulWidget {
  final Future<void> Function() onConfirmUninstall;

  const UninstallConfirmDialog({
    super.key,
    required this.onConfirmUninstall,
  });

  @override
  State<UninstallConfirmDialog> createState() => _UninstallConfirmDialogState();
}

class _UninstallConfirmDialogState extends State<UninstallConfirmDialog> {
  bool isUninstalling = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? LyColors.cardDark : LyColors.cardLight,
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: LyColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.delete_forever_rounded,
                    color: LyColors.error,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '彻底卸载 MacNTFS Pro',
                        style: LyFonts.titleMedium.copyWith(
                          color: isDark
                              ? LyColors.textPrimaryDark
                              : LyColors.textPrimaryLight,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '一键清理应用本体、内核层/用户态驱动及全部系统依赖',
                        style: LyFonts.bodySmall.copyWith(
                          color: isDark
                              ? LyColors.textSecondaryDark
                              : LyColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isUninstalling)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
              ],
            ),
            const Divider(height: 24),
            Text(
              '执行彻底卸载将自动完成以下清理操作：',
              style: LyFonts.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark
                    ? LyColors.textPrimaryDark
                    : LyColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 10),
            _renderCleanItem(
              Icons.layers_clear_rounded,
              '移除 FUSE-T 驱动框架及底层组件 (/Library/Application Support)',
              isDark,
            ),
            _renderCleanItem(
              Icons.terminal_rounded,
              '清理 NTFS-3G 驱动程序与动态链接库 (/usr/local/bin, /usr/local/lib)',
              isDark,
            ),
            _renderCleanItem(
              Icons.tune_rounded,
              '清除 MacNTFS Pro 用户偏好配置与日志缓存',
              isDark,
            ),
            _renderCleanItem(
              Icons.delete_outline_rounded,
              '删除 /Applications/MacNTFS Pro.app 应用程序本体',
              isDark,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2C2C2E)
                    : const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: LyColors.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '卸载系统级驱动需进行一次 macOS 管理员授权，卸载完成后将自动退出。',
                      style: LyFonts.bodySmall.copyWith(
                        color: isDark
                            ? LyColors.textSecondaryDark
                            : LyColors.textSecondaryLight,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!isUninstalling) ...[
                  LyButton(
                    text: '取消',
                    type: LyButtonType.secondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                ],
                LyButton(
                  text: isUninstalling ? '正在清理中...' : '确认一键彻底卸载',
                  type: LyButtonType.danger,
                  isLoading: isUninstalling,
                  icon: Icons.delete_forever_rounded,
                  onPressed: () async {
                    setState(() => isUninstalling = true);
                    await widget.onConfirmUninstall();
                    if (mounted) {
                      setState(() => isUninstalling = false);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 注释：绘制清理项目条目
  /// 时间：2026/08/16 17:35
  /// 作者：郭翰林
  Widget _renderCleanItem(IconData icon, String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: LyColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: LyFonts.bodySmall.copyWith(
                color: isDark
                    ? LyColors.textSecondaryDark
                    : LyColors.textSecondaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
