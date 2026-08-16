import 'dart:io';
import 'package:xml/xml.dart';
import '../pages/home/models/disk_item_model.dart';
import '../pages/home/models/env_status_model.dart';
import 'logger_utils.dart';
import 'ly_utils.dart';

/// 注释：macOS 底层磁盘与挂载引擎工具类
/// 时间：2026/08/16 17:55
/// 作者：郭翰林
class DiskEngineUtils {
  /// 注释：扫描系统所有物理磁盘与分区
  /// 时间：2026/08/16 17:55
  /// 作者：郭翰林
  static Future<List<DiskItemModel>> scanDisks() async {
    final List<DiskItemModel> diskList = [];
    try {
      loggerInfo('正在扫描系统磁盘分区...');
      final listResult = await Process.run('diskutil', ['list', '-plist']);
      if (listResult.exitCode != 0) {
        loggerError('diskutil list 执行失败: ${listResult.stderr}');
        return diskList;
      }

      final document = XmlDocument.parse(listResult.stdout.toString());
      final rootDict = document.findAllElements('dict').firstOrNull;
      if (rootDict == null) return diskList;

      // 1. 提取系统 mount 表
      final systemMountMap = await _getSystemMountMap();
      // 2. 提取正在运行的 ntfs-3g 进程与挂载映射表
      final ntfs3gMap = await _getNtfs3gProcessMap();
      // 3. 提取所有已挂载点的实时 df 容量映射表
      final dfSpaceMap = await _getDfSpaceMap();

      final allDisksAndPartitions = _parsePlistDict(rootDict);
      final allDisks =
          (allDisksAndPartitions['AllDisksAndPartitions'] as List?) ?? [];

      for (final diskObj in allDisks) {
        if (diskObj is Map<String, dynamic>) {
          await _processDiskEntry(
            diskObj,
            diskList,
            systemMountMap,
            ntfs3gMap,
            dfSpaceMap,
          );
        }
      }

      loggerInfo('磁盘扫描完成，共获取 ${diskList.length} 个有效分区');
    } catch (e, stack) {
      loggerError('扫描磁盘出现异常: $e', e, stack);
    }
    return diskList;
  }

  /// 注释：获取系统底层所有挂载点及可写状态映射表
  /// 时间：2026/08/16 17:30
  /// 作者：郭翰林
  static Future<Map<String, _MountInfo>> _getSystemMountMap() async {
    final Map<String, _MountInfo> map = {};
    try {
      final res = await Process.run('mount', []);
      if (res.exitCode == 0) {
        final lines = res.stdout.toString().split('\n');
        final reg = RegExp(r'^(.+?)\s+on\s+(.+?)\s+\((.+?)\)$');
        for (final line in lines) {
          final match = reg.firstMatch(line.trim());
          if (match != null) {
            final source = match.group(1)!.trim();
            final point = match.group(2)!.trim();
            final opts = match.group(3)!.toLowerCase();
            final isWritable = !opts.contains('read-only');
            final info = _MountInfo(
              source: source,
              mountPoint: point,
              isWritable: isWritable,
            );
            map[source] = info;
            map[point] = info;
          }
        }
      }
    } catch (e) {
      loggerWarn('获取系统 mount 表异常: $e');
    }
    return map;
  }

  /// 注释：获取正在运行的 NTFS-3G 进程及挂载映射表
  /// 时间：2026/08/16 17:55
  /// 作者：郭翰林
  static Future<Map<String, _Ntfs3gProcessInfo>> _getNtfs3gProcessMap() async {
    final Map<String, _Ntfs3gProcessInfo> map = {};
    try {
      final res = await Process.run('ps', ['-ax', '-o', 'pid,command']);
      if (res.exitCode == 0) {
        final lines = res.stdout.toString().split('\n');
        for (final line in lines) {
          if (line.contains('ntfs-3g') && !line.contains('grep')) {
            final trimmed = line.trim();
            final parts = trimmed.split(RegExp(r'\s+'));
            final pid = int.tryParse(parts.firstOrNull ?? '') ?? 0;
            // 提取设备节点 (如 /dev/disk2s1 或 disk2s1)
            final devMatch =
                RegExp(r'(/dev/disk\w+|(?<=\s)disk\w+)').firstMatch(trimmed);
            // 提取挂载目标路径 (如 /Volumes/xxx)
            final mountMatch = RegExp(r'(/Volumes/[^\s]+)').firstMatch(trimmed);

            if (devMatch != null && mountMatch != null) {
              var rawDev = devMatch.group(1)!;
              if (!rawDev.startsWith('/dev/')) {
                rawDev = '/dev/$rawDev';
              }
              final mountPath = mountMatch.group(1)!;
              final info = _Ntfs3gProcessInfo(
                pid: pid,
                deviceNode: rawDev,
                mountPoint: mountPath,
              );
              map[rawDev] = info;
              map[mountPath] = info;
            }
          }
        }
      }
    } catch (e) {
      loggerWarn('获取 NTFS-3G 进程映射失败: $e');
    }
    return map;
  }

  /// 注释：通过 df -k 获取所有挂载点的实际可用与总容量映射表
  /// 时间：2026/08/16 17:55
  /// 作者：郭翰林
  static Future<Map<String, _DiskSpaceInfo>> _getDfSpaceMap() async {
    final Map<String, _DiskSpaceInfo> map = {};
    try {
      final res = await Process.run('df', ['-k']);
      if (res.exitCode == 0) {
        final lines = res.stdout.toString().split('\n');
        for (var i = 1; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.isEmpty) continue;
          final parts = line.split(RegExp(r'\s+'));
          if (parts.length >= 6) {
            final totalKb = int.tryParse(parts[1]) ?? 0;
            final usedKb = int.tryParse(parts[2]) ?? 0;
            final availKb = int.tryParse(parts[3]) ?? 0;

            final lastPercentIdx =
                parts.lastIndexWhere((p) => p.endsWith('%'));
            String mountPoint = '';
            if (lastPercentIdx != -1 && lastPercentIdx + 1 < parts.length) {
              mountPoint = parts.sublist(lastPercentIdx + 1).join(' ');
            } else {
              mountPoint = parts.last;
            }

            if (mountPoint.isNotEmpty) {
              final spaceInfo = _DiskSpaceInfo(
                totalBytes: totalKb * 1024,
                usedBytes: usedKb * 1024,
                freeBytes: availKb * 1024,
              );
              map[mountPoint] = spaceInfo;
            }
          }
        }
      }
    } catch (e) {
      loggerWarn('获取 df 容量映射失败: $e');
    }
    return map;
  }

  /// 注释：处理单个磁盘及其分区信息 (支持常规分区、APFS 卷及整盘无分区设备)
  /// 时间：2026/08/16 17:55
  /// 作者：郭翰林
  static Future<void> _processDiskEntry(
    Map<String, dynamic> diskMap,
    List<DiskItemModel> results,
    Map<String, _MountInfo> systemMountMap,
    Map<String, _Ntfs3gProcessInfo> ntfs3gMap,
    Map<String, _DiskSpaceInfo> dfSpaceMap,
  ) async {
    final parentDevice = (diskMap['DeviceIdentifier'] ?? '').toString();
    final partitions = (diskMap['Partitions'] as List?) ?? [];
    final apfsVolumes = (diskMap['APFSVolumes'] as List?) ?? [];

    // 1. 如果该磁盘没有子分区（如无分区表的整盘直接格式化 U 盘/移动设备）
    if (partitions.isEmpty && apfsVolumes.isEmpty && parentDevice.isNotEmpty) {
      final item = await _fetchDiskDetail(
        parentDevice,
        parentDevice,
        systemMountMap,
        ntfs3gMap,
        dfSpaceMap,
      );
      if (item != null &&
          !_isSystemInternalIgnore(item) &&
          !(item.totalSize <= 0 && !item.isMounted)) {
        results.add(item);
      }
      return;
    }

    // 2. 处理常规分区
    for (final part in partitions) {
      if (part is Map<String, dynamic>) {
        final devId = (part['DeviceIdentifier'] ?? '').toString();
        if (devId.isNotEmpty) {
          final item = await _fetchDiskDetail(
            devId,
            parentDevice,
            systemMountMap,
            ntfs3gMap,
            dfSpaceMap,
          );
          if (item != null &&
              !_isSystemInternalIgnore(item) &&
              !(item.totalSize <= 0 && !item.isMounted)) {
            results.add(item);
          }
        }
      }
    }

    // 3. 处理 APFS 卷
    for (final vol in apfsVolumes) {
      if (vol is Map<String, dynamic>) {
        final devId = (vol['DeviceIdentifier'] ?? '').toString();
        if (devId.isNotEmpty) {
          final item = await _fetchDiskDetail(
            devId,
            parentDevice,
            systemMountMap,
            ntfs3gMap,
            dfSpaceMap,
          );
          if (item != null &&
              !_isSystemInternalIgnore(item) &&
              !(item.totalSize <= 0 && !item.isMounted)) {
            results.add(item);
          }
        }
      }
    }
  }

  /// 注释：获取具体分区的详细信息
  /// 时间：2026/08/16 17:55
  /// 作者：郭翰林
  static Future<DiskItemModel?> _fetchDiskDetail(
    String devId,
    String parentDisk,
    Map<String, _MountInfo> systemMountMap,
    Map<String, _Ntfs3gProcessInfo> ntfs3gMap,
    Map<String, _DiskSpaceInfo> dfSpaceMap,
  ) async {
    try {
      final infoResult =
          await Process.run('diskutil', ['info', '-plist', '/dev/$devId']);
      if (infoResult.exitCode != 0) return null;

      final doc = XmlDocument.parse(infoResult.stdout.toString());
      final dictNode = doc.findAllElements('dict').firstOrNull;
      if (dictNode == null) return null;

      final info = _parsePlistDict(dictNode);

      var volumeName = (info['VolumeName'] ?? '').toString().trim();
      var mountPoint = (info['MountPoint'] ?? '').toString().trim();
      final fsType = (info['FilesystemType'] ?? '').toString().toLowerCase();
      final fsName = (info['FilesystemName'] ?? '').toString();
      final userVisibleFs =
          (info['FilesystemUserVisibleName'] ?? '').toString();
      final content = (info['Content'] ?? '').toString();
      final devNode = '/dev/$devId';

      final isInternal = (info['Internal'] == true);
      final isRemovable = (info['RemovableMedia'] == true) ||
          (info['RemovableMediaOrExternalDevice'] == true) ||
          (info['Ejectable'] == true);

      var isWritable = (info['Writable'] == true) &&
          (info['WritableVolume'] == true);
      var isMounted = mountPoint.isNotEmpty;

      // 1. 结合 NTFS-3G 进程与系统 mount 表进行状态判定
      if (ntfs3gMap.containsKey(devNode)) {
        final ntfsInfo = ntfs3gMap[devNode]!;
        isMounted = true;
        mountPoint = ntfsInfo.mountPoint;
        isWritable = true;
      } else if (systemMountMap.containsKey(devNode)) {
        final mountEntry = systemMountMap[devNode]!;
        isMounted = true;
        mountPoint = mountEntry.mountPoint;
        isWritable = mountEntry.isWritable;
      } else if (volumeName.isNotEmpty &&
          systemMountMap.containsKey('/Volumes/$volumeName')) {
        final mountEntry = systemMountMap['/Volumes/$volumeName']!;
        isMounted = true;
        mountPoint = mountEntry.mountPoint;
        isWritable = mountEntry.isWritable;
      } else if (volumeName.isNotEmpty &&
          ntfs3gMap.containsKey('/Volumes/$volumeName')) {
        final ntfsInfo = ntfs3gMap['/Volumes/$volumeName']!;
        isMounted = true;
        mountPoint = ntfsInfo.mountPoint;
        isWritable = true;
      }

      // 卷名智能提取：若 VolumeName 为空，尝试从挂载点或介质名提取
      if (volumeName.isEmpty) {
        if (mountPoint.isNotEmpty && mountPoint.startsWith('/Volumes/')) {
          volumeName = mountPoint.replaceFirst('/Volumes/', '');
        } else if ((info['MediaName'] ?? '').toString().trim().isNotEmpty) {
          volumeName = (info['MediaName'] ?? '').toString().trim();
        } else if ((info['IORegistryEntryName'] ?? '')
            .toString()
            .trim()
            .isNotEmpty) {
          volumeName = (info['IORegistryEntryName'] ?? '').toString().trim();
        }
      }

      // 提取磁盘容量与可用空间
      int parseSize(dynamic val) {
        if (val is num) return val.toInt();
        if (val is String) return int.tryParse(val) ?? 0;
        return 0;
      }

      final rawTotal = parseSize(info['TotalSize']) > 0
          ? parseSize(info['TotalSize'])
          : (parseSize(info['APFSContainerSize']) > 0
              ? parseSize(info['APFSContainerSize'])
              : (parseSize(info['Size']) > 0
                  ? parseSize(info['Size'])
                  : (parseSize(info['VolumeSize']) > 0
                      ? parseSize(info['VolumeSize'])
                      : parseSize(info['IOKitSize']))));

      final containerFree = parseSize(info['APFSContainerFree']);
      final standardFree = parseSize(info['FreeSpace']);
      int freeSpace = containerFree > 0 ? containerFree : standardFree;

      final capInUse = parseSize(info['CapacityInUse']) > 0
          ? parseSize(info['CapacityInUse'])
          : parseSize(info['APFSVolumeCapacityInUse']);
      int usedSpace = capInUse;

      int totalSize = rawTotal;

      // 如果已挂载，优先通过 df -k 表校准容量 (无论是 NTFS-3G 还是原生挂载)
      if (isMounted && mountPoint.isNotEmpty && dfSpaceMap.containsKey(mountPoint)) {
        final dfInfo = dfSpaceMap[mountPoint]!;
        if (dfInfo.totalBytes > 0) {
          totalSize = dfInfo.totalBytes;
        }
        usedSpace = dfInfo.usedBytes;
        freeSpace = dfInfo.freeBytes;
      } else {
        if (usedSpace <= 0 && totalSize > 0 && freeSpace > 0 && totalSize >= freeSpace) {
          usedSpace = totalSize - freeSpace;
        }
        if (freeSpace <= 0 && totalSize > 0 && usedSpace > 0 && totalSize >= usedSpace) {
          freeSpace = totalSize - usedSpace;
        }
      }

      final uuid = (info['DiskUUID'] ?? info['VolumeUUID'] ?? '').toString();

      // 判断是否是 NTFS
      final isNTFS = ntfs3gMap.containsKey(devNode) ||
          fsType.contains('ntfs') ||
          fsName.toLowerCase().contains('ntfs') ||
          userVisibleFs.toLowerCase().contains('ntfs') ||
          (content.contains('Microsoft Basic Data') &&
              !fsType.contains('fat') &&
              !fsType.contains('msdos') &&
              !fsType.contains('exfat') &&
              !fsName.toLowerCase().contains('fat') &&
              !fsName.toLowerCase().contains('exfat'));

      return DiskItemModel(
        deviceIdentifier: devId,
        deviceNode: devNode,
        parentDisk: parentDisk.isNotEmpty ? parentDisk : devId,
        volumeName: volumeName.isNotEmpty ? volumeName : devId,
        mountPoint: mountPoint,
        filesystemType: fsType.isNotEmpty ? fsType : (isNTFS ? 'ntfs' : content),
        filesystemName: userVisibleFs.isNotEmpty
            ? userVisibleFs
            : (fsName.isNotEmpty ? fsName : (isNTFS ? 'Windows NT File System (NTFS)' : '未知文件系统')),
        isNTFS: isNTFS,
        isMounted: isMounted,
        isWritable: isWritable,
        isInternal: isInternal,
        isRemovable: isRemovable,
        totalSize: totalSize,
        freeSpace: freeSpace,
        usedSpace: usedSpace,
        uuid: uuid,
      );
    } catch (e) {
      loggerWarn('解析分区 $devId 详情失败: $e');
      return null;
    }
  }

  /// 注释：过滤系统内部无用卷
  /// 时间：2026/08/16 12:20
  /// 作者：郭翰林
  static bool _isSystemInternalIgnore(DiskItemModel disk) {
    final name = disk.volumeName.toLowerCase();
    final point = disk.mountPoint.toLowerCase();
    if (name == 'preboot' ||
        name == 'recovery' ||
        name == 'vm' ||
        name == 'update' ||
        name == 'xart' ||
        name == 'iscpreboot' ||
        name == 'hardware' ||
        name.contains('securepkitruststore') ||
        name.contains('simulator')) {
      return true;
    }
    if (point.startsWith('/system/volumes/')) {
      if (point.contains('preboot') ||
          point.contains('recovery') ||
          point.contains('vm') ||
          point.contains('update')) {
        return true;
      }
    }
    return false;
  }

  /// 注释：以读写模式安全挂载 NTFS 磁盘 (优先免密挂载，首次授权后后续永久免输密码)
  /// 时间：2026/08/16 18:45
  /// 作者：郭翰林
  static Future<bool> mountReadWrite(
    DiskItemModel disk,
    EnvStatusModel env,
  ) async {
    final wasMounted = disk.isMounted;
    final mountPointName = disk.displayName.replaceAll('/', '_');
    final targetMountPath = '/Volumes/$mountPointName';

    try {
      loggerInfo('准备以【读写模式】安全挂载磁盘: ${disk.displayName} (${disk.deviceNode})');

      // 1. 校验 NTFS-3G 驱动就绪状态
      if (!env.hasNtfs3g || env.ntfs3gPath.isEmpty) {
        loggerWarn('未找到 ntfs-3g 可执行文件，无法以读写模式挂载');
        LyUtils.showToast('请先点击上方【一键配置驱动】配置 FUSE-T 与 NTFS-3G', isError: true);
        return false;
      }

      // 2. 如果已原生只读挂载，先安全卸载原生占用
      if (wasMounted) {
        loggerInfo('正在安全卸载原生只读占用: ${disk.deviceNode}');
        await Process.run('sync', []);
        await Process.run('diskutil', ['unmount', disk.deviceNode]);
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // 3. 优先尝试免密静默读写挂载 (若系统已配置 Helper 与 Sudoers 规则)
      if (File('/usr/local/bin/macntfs-helper').existsSync()) {
        try {
          loggerInfo('检测到免密 Helper，尝试静默免密读写挂载: ${disk.deviceNode}');
          final helperRes = await Process.run('sudo', [
            '-n',
            '/usr/local/bin/macntfs-helper',
            'mount',
            disk.deviceNode,
            targetMountPath,
            mountPointName,
          ]);

          if (helperRes.exitCode == 0) {
            loggerInfo('🎉 磁盘 ${disk.displayName} 免密读写挂载成功！');
            LyUtils.showToast('【${disk.displayName}】已成功以读写模式挂载！');
            await Future.delayed(const Duration(milliseconds: 500));
            await LyUtils.openInFinder(targetMountPath);
            return true;
          } else {
            loggerWarn('免密 Helper 尝试未成功 (${helperRes.stderr.toString().trim()})，转为系统授权模式');
          }
        } catch (e) {
          loggerWarn('免密 Helper 执行异常: $e');
        }
      }

      // 4. 首次提权挂载脚本 (执行挂载并自动部署免密 Helper 与 Sudoers 规则，后续永久免密)
      final mountCommand = '''
# 1. 确保 FUSE-T 动态库软链接就绪
if [ -f "/usr/local/lib/libfuse-t.dylib" ]; then
    [ ! -f "/usr/local/lib/libfuse.2.dylib" ] && ln -sf /usr/local/lib/libfuse-t.dylib /usr/local/lib/libfuse.2.dylib
    [ ! -f "/usr/local/lib/libfuse.dylib" ] && ln -sf /usr/local/lib/libfuse-t.dylib /usr/local/lib/libfuse.dylib
    [ ! -f "/usr/local/lib/libosxfuse.2.dylib" ] && ln -sf /usr/local/lib/libfuse-t.dylib /usr/local/lib/libosxfuse.2.dylib
    [ ! -f "/usr/local/lib/libosxfuse.dylib" ] && ln -sf /usr/local/lib/libfuse-t.dylib /usr/local/lib/libosxfuse.dylib
fi

# 2. 兜底确保卸载原生占用
diskutil unmount "${disk.deviceNode}" 2>/dev/null || true

# 3. 创建挂载目标目录并执行 NTFS-3G 读写挂载
mkdir -p "$targetMountPath"
${env.ntfs3gPath} ${disk.deviceNode} "$targetMountPath" -o local,allow_other,auto_xattr,recover,remove_hiberfile,windows_names,hide_hid_files,hide_dot_files,volname="$mountPointName"

# 4. 自动部署免密 Helper 与 Sudoers 规则，保证后续挂载永久免输密码
cat << 'HELPER_EOF' > /usr/local/bin/macntfs-helper
#!/bin/bash
set -e
ACTION="\$1"
DEVICE="\$2"
MOUNT_PATH="\$3"
VOL_NAME="\$4"

if [ -f "/usr/local/lib/libfuse-t.dylib" ]; then
    [ ! -f "/usr/local/lib/libfuse.2.dylib" ] && ln -sf /usr/local/lib/libfuse-t.dylib /usr/local/lib/libfuse.2.dylib
    [ ! -f "/usr/local/lib/libfuse.dylib" ] && ln -sf /usr/local/lib/libfuse-t.dylib /usr/local/lib/libfuse.dylib
    [ ! -f "/usr/local/lib/libosxfuse.2.dylib" ] && ln -sf /usr/local/lib/libfuse-t.dylib /usr/local/lib/libosxfuse.2.dylib
    [ ! -f "/usr/local/lib/libosxfuse.dylib" ] && ln -sf /usr/local/lib/libfuse-t.dylib /usr/local/lib/libosxfuse.dylib
fi

case "\$ACTION" in
    mount)
        diskutil unmount "\$DEVICE" 2>/dev/null || true
        mkdir -p "\$MOUNT_PATH"
        /usr/local/bin/ntfs-3g "\$DEVICE" "\$MOUNT_PATH" -o local,allow_other,auto_xattr,recover,remove_hiberfile,windows_names,hide_hid_files,hide_dot_files,volname="\$VOL_NAME"
        ;;
    unmount)
        diskutil unmount force "\$MOUNT_PATH" 2>/dev/null || umount -f "\$MOUNT_PATH" 2>/dev/null || true
        diskutil unmount force "\$DEVICE" 2>/dev/null || true
        DEV_ID="\$(basename "\$DEVICE")"
        pkill -9 -f "ntfs-3g.*\$DEV_ID" 2>/dev/null || true
        rmdir "\$MOUNT_PATH" 2>/dev/null || true
        diskutil mount "\$DEVICE" 2>/dev/null || true
        ;;
    *)
        echo "Usage: \$0 {mount|unmount} ..."
        exit 1
        ;;
esac
HELPER_EOF

chmod 755 /usr/local/bin/macntfs-helper
chown root:wheel /usr/local/bin/macntfs-helper

mkdir -p /private/etc/sudoers.d
echo "ALL ALL=(ALL) NOPASSWD: /usr/local/bin/macntfs-helper, /usr/local/bin/ntfs-3g" > /private/etc/sudoers.d/mac_ntfs_pro
chmod 440 /private/etc/sudoers.d/mac_ntfs_pro
chown root:wheel /private/etc/sudoers.d/mac_ntfs_pro
visudo -cf /private/etc/sudoers.d/mac_ntfs_pro 2>/dev/null || rm -f /private/etc/sudoers.d/mac_ntfs_pro
''';

      loggerInfo('执行安全读写挂载与免密环境配置:\n$mountCommand');
      final scriptResult = await LyUtils.runPrivilegedScript(mountCommand);

      if (scriptResult.exitCode == 0) {
        loggerInfo('🎉 磁盘 ${disk.displayName} 读写挂载成功，已完成免密配置！');
        LyUtils.showToast('【${disk.displayName}】已成功以读写模式挂载！');
        await Future.delayed(const Duration(milliseconds: 500));
        await LyUtils.openInFinder(targetMountPath);
        return true;
      } else {
        loggerError('读写挂载失败: ${scriptResult.stderr} ${scriptResult.stdout}');
        await _handleMountRollback(disk, targetMountPath, wasMounted);

        final errMsg = scriptResult.stderr.toString();
        if (errMsg.contains('Windows cache') || errMsg.contains('unclean')) {
          LyUtils.showToast('磁盘存在 Windows 快速启动未释放标记，已安全回滚只读模式', isError: true);
        } else if (errMsg.contains('Library not loaded')) {
          LyUtils.showToast('驱动动态库依赖缺失，请点击【一键配置驱动】修复', isError: true);
        } else {
          LyUtils.showToast('读写挂载未成功，已自动安全回滚至只读模式', isError: true);
        }
        return false;
      }
    } catch (e) {
      loggerError('读写挂载异常: $e');
      await _handleMountRollback(disk, targetMountPath, wasMounted);
      LyUtils.showToast('挂载异常，已恢复原生模式: $e', isError: true);
      return false;
    }
  }

  /// 注释：挂载失败时的安全回滚与清理处理
  /// 时间：2026/08/16 16:45
  /// 作者：郭翰林
  static Future<void> _handleMountRollback(
    DiskItemModel disk,
    String targetMountPath,
    bool shouldRemount,
  ) async {
    try {
      loggerWarn('正在执行安全回滚与挂载点清理: ${disk.deviceNode}');
      await Process.run('rmdir', [targetMountPath]);
      if (shouldRemount) {
        await Process.run('diskutil', ['mount', disk.deviceNode]);
      }
    } catch (e) {
      loggerError('回滚清理异常: $e');
    }
  }

  /// 注释：安全卸载磁盘读写挂载并回退为系统原生只读挂载 (防止内置/外置磁盘卸载后彻底消失)
  /// 时间：2026/08/16 18:35
  /// 作者：郭翰林
  static Future<bool> unmountDisk(DiskItemModel disk) async {
    try {
      loggerInfo('正在安全卸载磁盘: ${disk.displayName} (${disk.deviceNode})');
      await Process.run('sync', []);

      final mountPoint = disk.mountPoint;
      final devNode = disk.deviceNode;
      final devId = disk.deviceIdentifier;

      // 1. 如果有挂载点，优先卸载挂载点 (支持 FUSE-T / NFS / 原生挂载，完全免密)
      if (mountPoint.isNotEmpty) {
        final res = await Process.run('diskutil', ['unmount', mountPoint]);
        if (res.exitCode != 0) {
          await Process.run('diskutil', ['unmount', 'force', mountPoint]);
        }
      }

      // 2. 卸载设备节点并清理残留的 ntfs-3g 进程与空挂载目录
      await Process.run('diskutil', ['unmount', devNode]);
      await Process.run('pkill', ['-9', '-f', 'ntfs-3g.*$devId']);
      if (mountPoint.isNotEmpty && mountPoint.startsWith('/Volumes/')) {
        await Process.run('rmdir', [mountPoint]);
      }

      // 3. 恢复为 macOS 原生只读挂载状态 (与 Mac 开机原生只读状态一致，防止磁盘在系统/访达中消失)
      if (disk.isNTFS) {
        loggerInfo('正在将磁盘恢复为系统原生只读挂载: $devNode');
        final remountRes = await Process.run('diskutil', ['mount', devNode]);
        if (remountRes.exitCode == 0) {
          loggerInfo('🎉 磁盘 ${disk.displayName} 已成功恢复为原生只读挂载状态');
          LyUtils.showToast('已卸载读写模式，恢复为原生只读挂载');
          return true;
        } else {
          loggerWarn('恢复原生挂载未直接生效: ${remountRes.stderr} ${remountRes.stdout}');
        }
      }

      // 4. 若普通卸载仍未干净（存在物理占用等情况），尝试提权清理并恢复原生只读
      loggerWarn('尝试提权清理与恢复原生只读挂载...');
      final cleanupScript = '''
sync
if [ -n "$mountPoint" ]; then
    diskutil unmount force "$mountPoint" 2>/dev/null || umount -f "$mountPoint" 2>/dev/null || true
    rmdir "$mountPoint" 2>/dev/null || true
fi
diskutil unmount force "$devNode" 2>/dev/null || true
pkill -9 -f "ntfs-3g.*$devId" 2>/dev/null || true
diskutil mount "$devNode" 2>/dev/null || true
''';
      final privRes = await LyUtils.runPrivilegedScript(cleanupScript);
      if (privRes.exitCode == 0) {
        loggerInfo('磁盘卸载与原生只读恢复处理完毕: ${disk.displayName}');
        LyUtils.showToast('已安全卸载读写挂载并恢复只读');
        return true;
      } else {
        LyUtils.showToast('卸载失败: 磁盘可能正被其他程序占用', isError: true);
        return false;
      }
    } catch (e) {
      loggerError('卸载异常: $e');
      LyUtils.showToast('卸载失败: $e', isError: true);
      return false;
    }
  }

  /// 注释：安全推出物理磁盘 (原生免密推出)
  /// 时间：2026/08/16 18:35
  /// 作者：郭翰林
  static Future<bool> ejectDisk(DiskItemModel disk) async {
    try {
      loggerInfo('正在安全推出磁盘: ${disk.displayName} (${disk.deviceNode})');
      await Process.run('sync', []);

      final devId = disk.deviceIdentifier;
      final mountPoint = disk.mountPoint;
      final devNode = disk.deviceNode;
      final targetEjectDev =
          disk.parentDisk.isNotEmpty ? disk.parentDisk : disk.deviceNode;

      // 1. 如果还在挂载，先执行免密卸载
      if (mountPoint.isNotEmpty) {
        final res = await Process.run('diskutil', ['unmount', mountPoint]);
        if (res.exitCode != 0) {
          await Process.run('diskutil', ['unmount', 'force', mountPoint]);
        }
      }
      await Process.run('diskutil', ['unmount', devNode]);
      await Process.run('pkill', ['-9', '-f', 'ntfs-3g.*$devId']);
      if (mountPoint.isNotEmpty && mountPoint.startsWith('/Volumes/')) {
        await Process.run('rmdir', [mountPoint]);
      }

      // 2. 直接执行原生免密推出
      final res = await Process.run('diskutil', ['eject', targetEjectDev]);
      if (res.exitCode == 0) {
        loggerInfo('磁盘已安全推出: ${disk.displayName}');
        LyUtils.showToast('【${disk.displayName}】已安全推出');
        return true;
      }

      // 3. 若普通推出失败，尝试 force unmount 后重试推出 (依然保持免密)
      if (mountPoint.isNotEmpty) {
        await Process.run('diskutil', ['unmount', 'force', mountPoint]);
      }
      await Process.run('diskutil', ['unmount', 'force', devNode]);
      final retryRes = await Process.run('diskutil', ['eject', targetEjectDev]);
      if (retryRes.exitCode == 0) {
        loggerInfo('磁盘已安全推出 (重试成功): ${disk.displayName}');
        LyUtils.showToast('【${disk.displayName}】已安全推出');
        return true;
      } else {
        loggerError('推出失败: ${retryRes.stderr}');
        LyUtils.showToast('推出失败: ${retryRes.stderr.toString().trim()}', isError: true);
        return false;
      }
    } catch (e) {
      loggerError('推出磁盘异常: $e');
      LyUtils.showToast('推出磁盘异常: $e', isError: true);
      return false;
    }
  }

  /// 注释：递归解析 plist dict XML 节点
  /// 时间：2026/08/16 12:20
  /// 作者：郭翰林
  static Map<String, dynamic> _parsePlistDict(XmlElement dictElement) {
    final Map<String, dynamic> result = {};
    final children = dictElement.children.whereType<XmlElement>().toList();

    for (var i = 0; i < children.length; i++) {
      final child = children[i];
      if (child.name.local == 'key' && i + 1 < children.length) {
        final keyName = child.innerText.trim();
        final valueElement = children[i + 1];
        result[keyName] = _parsePlistValue(valueElement);
        i++;
      }
    }
    return result;
  }

  /// 注释：解析 plist 节点对应的值
  /// 时间：2026/08/16 12:20
  /// 作者：郭翰林
  static dynamic _parsePlistValue(XmlElement element) {
    final tag = element.name.local;
    switch (tag) {
      case 'string':
        return element.innerText.trim();
      case 'integer':
        return int.tryParse(element.innerText.trim()) ?? 0;
      case 'real':
        return double.tryParse(element.innerText.trim()) ?? 0.0;
      case 'true':
        return true;
      case 'false':
        return false;
      case 'dict':
        return _parsePlistDict(element);
      case 'array':
        return element.children
            .whereType<XmlElement>()
            .map((e) => _parsePlistValue(e))
            .toList();
      default:
        return element.innerText.trim();
    }
  }
}

/// 注释：系统底层 Mount 挂载信息内部结构
/// 时间：2026/08/16 17:30
/// 作者：郭翰林
class _MountInfo {
  final String source;
  final String mountPoint;
  final bool isWritable;

  _MountInfo({
    required this.source,
    required this.mountPoint,
    required this.isWritable,
  });
}

/// 注释：NTFS-3G 进程挂载内部信息
/// 时间：2026/08/16 17:55
/// 作者：郭翰林
class _Ntfs3gProcessInfo {
  final int pid;
  final String deviceNode;
  final String mountPoint;

  _Ntfs3gProcessInfo({
    required this.pid,
    required this.deviceNode,
    required this.mountPoint,
  });
}

/// 注释：挂载点实时容量信息 (来自 df -k)
/// 时间：2026/08/16 17:55
/// 作者：郭翰林
class _DiskSpaceInfo {
  final int totalBytes;
  final int usedBytes;
  final int freeBytes;

  _DiskSpaceInfo({
    required this.totalBytes,
    required this.usedBytes,
    required this.freeBytes,
  });
}

