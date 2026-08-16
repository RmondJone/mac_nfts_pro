import 'package:flutter/material.dart';
import '../../../defines/ly_colors.dart';
import '../../../defines/ly_fonts.dart';
import '../../../utils/ly_utils.dart';
import '../../../widgets/ly_badge.dart';
import '../../../widgets/ly_button.dart';
import '../../../widgets/ly_card.dart';
import '../models/disk_item_model.dart';
import 'disk_detail_dialog.dart';

/// 注释：单个磁盘分区卡片组件
/// 时间：2026/08/16 12:20
/// 作者：郭翰林
class DiskItemCard extends StatelessWidget {
  final DiskItemModel disk;
  final bool isMounting;
  final bool isUnmounting;
  final bool isEjecting;
  final VoidCallback onMountReadWrite;
  final VoidCallback onUnmount;
  final VoidCallback onEject;
  final VoidCallback onOpenFinder;

  const DiskItemCard({
    super.key,
    required this.disk,
    this.isMounting = false,
    this.isUnmounting = false,
    this.isEjecting = false,
    required this.onMountReadWrite,
    required this.onUnmount,
    required this.onEject,
    required this.onOpenFinder,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LyCard(
      onTap: () => showDialog(
        context: context,
        builder: (_) => DiskDetailDialog(disk: disk),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          renderHeader(context, isDark),
          const SizedBox(height: 12),
          renderCapacityBar(context, isDark),
          const SizedBox(height: 14),
          renderActionButtons(context, isDark),
        ],
      ),
    );
  }

  /// 注释：绘制卡片头部信息
  /// 时间：2026/08/16 12:20
  /// 作者：郭翰林
  Widget renderHeader(BuildContext context, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: disk.isNTFS
                ? LyColors.primary.withValues(alpha: 0.12)
                : (isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            disk.isRemovable ? Icons.usb_rounded : Icons.storage_rounded,
            color: disk.isNTFS ? LyColors.primary : LyColors.textSecondaryLight,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      disk.displayName,
                      style: LyFonts.titleMedium.copyWith(
                        color: isDark
                            ? LyColors.textPrimaryDark
                            : LyColors.textPrimaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (disk.isNTFS)
                    const LyBadge(
                      label: 'NTFS',
                      textColor: Colors.white,
                      backgroundColor: LyColors.primary,
                    ),
                  const SizedBox(width: 6),
                  LyBadge(
                    label: disk.statusText,
                    textColor: disk.isWritable
                        ? LyColors.success
                        : (disk.isMounted ? LyColors.warning : Colors.grey),
                    backgroundColor: disk.isWritable
                        ? LyColors.successLight
                        : (disk.isMounted
                            ? LyColors.warningLight
                            : const Color(0xFFE5E5EA)),
                    icon: disk.isWritable
                        ? Icons.edit
                        : (disk.isMounted ? Icons.lock_outline : Icons.power_off),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                '${disk.deviceNode} • ${disk.filesystemName}',
                style: LyFonts.bodySmall.copyWith(
                  color: isDark
                      ? LyColors.textSecondaryDark
                      : LyColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: '查看磁盘参数',
          icon: Icon(
            Icons.info_outline,
            size: 18,
            color: isDark
                ? LyColors.textSecondaryDark
                : LyColors.textSecondaryLight,
          ),
          onPressed: () => showDialog(
            context: context,
            builder: (_) => DiskDetailDialog(disk: disk),
          ),
        ),
      ],
    );
  }

  /// 注释：绘制磁盘容量使用进度条 (智能区分挂载与未挂载状态)
  /// 时间：2026/08/16 18:15
  /// 作者：郭翰林
  Widget renderCapacityBar(BuildContext context, bool isDark) {
    final totalStr = LyUtils.formatBytes(disk.totalSize);

    // 未挂载状态下，macOS 无法读取内部已用/剩余簇，直接显示总容量与提示
    if (!disk.isMounted) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '总容量: $totalStr',
                style: LyFonts.bodySmall.copyWith(
                  color: isDark
                      ? LyColors.textSecondaryDark
                      : LyColors.textSecondaryLight,
                ),
              ),
              Text(
                '未挂载 (挂载后显示实时已用空间)',
                style: LyFonts.bodySmall.copyWith(
                  color: isDark
                      ? LyColors.textSecondaryDark
                      : LyColors.textSecondaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 0.0,
              minHeight: 6,
              backgroundColor: isDark
                  ? const Color(0xFF38383A)
                  : const Color(0xFFE5E5EA),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.grey),
            ),
          ),
        ],
      );
    }

    final usedStr = LyUtils.formatBytes(disk.usedSpace);
    final freeStr = LyUtils.formatBytes(disk.freeSpace);
    final percentage = (disk.usagePercentage * 100).toStringAsFixed(1);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '已用: $usedStr / $totalStr ($percentage%)',
              style: LyFonts.bodySmall.copyWith(
                color: isDark
                    ? LyColors.textSecondaryDark
                    : LyColors.textSecondaryLight,
              ),
            ),
            Text(
              '可用: $freeStr',
              style: LyFonts.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: disk.freeSpace > 0
                    ? (isDark ? Colors.white70 : Colors.black87)
                    : LyColors.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: disk.usagePercentage,
            minHeight: 6,
            backgroundColor: isDark
                ? const Color(0xFF38383A)
                : const Color(0xFFE5E5EA),
            valueColor: AlwaysStoppedAnimation<Color>(
              disk.usagePercentage > 0.9
                  ? LyColors.error
                  : (disk.usagePercentage > 0.75
                      ? LyColors.warning
                      : LyColors.primary),
            ),
          ),
        ),
      ],
    );
  }

  /// 注释：绘制操作按钮区域
  /// 时间：2026/08/16 19:15
  /// 作者：郭翰林
  Widget renderActionButtons(BuildContext context, bool isDark) {
    final isBusy = isMounting || isUnmounting || isEjecting;

    return Row(
      children: [
        if (disk.isNTFS && !disk.isWritable)
          LyButton(
            text: '以读写模式挂载',
            icon: Icons.flash_on_rounded,
            isLoading: isMounting,
            type: LyButtonType.primary,
            onPressed: isBusy ? null : onMountReadWrite,
          ),
        if (disk.isMounted) ...[
          const SizedBox(width: 8),
          LyButton(
            text: '访达打开',
            icon: Icons.folder_open_rounded,
            type: LyButtonType.secondary,
            onPressed: isBusy ? null : onOpenFinder,
          ),
          const SizedBox(width: 8),
          LyButton(
            text: '卸载',
            icon: Icons.eject_outlined,
            isLoading: isUnmounting,
            type: LyButtonType.secondary,
            onPressed: isBusy ? null : onUnmount,
          ),
        ],
        const Spacer(),
        if (disk.isRemovable || !disk.isInternal)
          LyButton(
            text: '推出',
            icon: Icons.power_settings_new_rounded,
            isLoading: isEjecting,
            type: LyButtonType.secondary,
            onPressed: isBusy ? null : onEject,
          ),
      ],
    );
  }
}
