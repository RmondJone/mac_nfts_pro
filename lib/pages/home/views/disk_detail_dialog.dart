import 'package:flutter/material.dart';
import '../../../defines/ly_colors.dart';
import '../../../defines/ly_fonts.dart';
import '../../../utils/ly_utils.dart';
import '../../../widgets/ly_button.dart';
import '../models/disk_item_model.dart';

/// 注释：磁盘参数详细信息对话框
/// 时间：2026/08/16 12:20
/// 作者：郭翰林
class DiskDetailDialog extends StatelessWidget {
  final DiskItemModel disk;

  const DiskDetailDialog({super.key, required this.disk});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? LyColors.cardDark : LyColors.cardLight,
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.album_rounded,
                  color: disk.isNTFS ? LyColors.primary : Colors.grey,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        disk.displayName,
                        style: LyFonts.titleMedium.copyWith(
                          color: isDark
                              ? LyColors.textPrimaryDark
                              : LyColors.textPrimaryLight,
                        ),
                      ),
                      Text(
                        '设备节点: ${disk.deviceNode}',
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
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 24),
            renderInfoRow('卷名 (Volume Name)', disk.volumeName, isDark),
            renderInfoRow('设备节点 (Device Node)', disk.deviceNode, isDark),
            renderInfoRow('所属物理磁盘 (Parent Disk)', disk.parentDisk, isDark),
            renderInfoRow('文件系统格式 (Filesystem)', disk.filesystemName, isDark),
            renderInfoRow('NTFS 兼容性', disk.isNTFS ? '是 (NTFS)' : '否', isDark),
            renderInfoRow(
              '当前挂载点 (Mount Point)',
              disk.mountPoint.isNotEmpty ? disk.mountPoint : '未挂载',
              isDark,
            ),
            renderInfoRow('读写权限 (RW Status)', disk.statusText, isDark),
            renderInfoRow(
              '总容量 (Total Size)',
              LyUtils.formatBytes(disk.totalSize),
              isDark,
            ),
            renderInfoRow(
              '剩余可用 (Free Space)',
              LyUtils.formatBytes(disk.freeSpace),
              isDark,
            ),
            renderInfoRow(
              '外置/移动设备',
              disk.isRemovable ? '是 (USB/External)' : '否 (Internal)',
              isDark,
            ),
            if (disk.uuid.isNotEmpty)
              renderInfoRow('UUID', disk.uuid, isDark),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: LyButton(
                text: '关闭',
                type: LyButtonType.secondary,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 注释：绘制单行详情参数
  /// 时间：2026/08/16 12:20
  /// 作者：郭翰林
  Widget renderInfoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(
              label,
              style: LyFonts.bodySmall.copyWith(
                color: isDark
                    ? LyColors.textSecondaryDark
                    : LyColors.textSecondaryLight,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: LyFonts.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark
                    ? LyColors.textPrimaryDark
                    : LyColors.textPrimaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
