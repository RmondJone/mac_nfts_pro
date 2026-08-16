import 'dart:io';
import 'package:xml/xml.dart';
import '../pages/home/models/disk_item_model.dart';
import '../pages/home/models/env_status_model.dart';
import 'logger_utils.dart';
import 'ly_utils.dart';

/// 注释：macOS 底层磁盘与挂载引擎工具类
/// 时间：2026/08/16 12:20
/// 作者：郭翰林
class DiskEngineUtils {
  /// 注释：扫描系统所有物理磁盘与分区
  /// 时间：2026/08/16 12:20
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

      final allDisksAndPartitions = _parsePlistDict(rootDict);
      final allDisks =
          (allDisksAndPartitions['AllDisksAndPartitions'] as List?) ?? [];

      for (final diskObj in allDisks) {
        if (diskObj is Map<String, dynamic>) {
          await _processDiskEntry(diskObj, diskList);
        }
      }

      loggerInfo('磁盘扫描完成，共获取 ${diskList.length} 个有效分区');
    } catch (e, stack) {
      loggerError('扫描磁盘出现异常: $e', e, stack);
    }
    return diskList;
  }

  /// 注释：处理单个磁盘及其分区信息
  /// 时间：2026/08/16 12:20
  /// 作者：郭翰林
  static Future<void> _processDiskEntry(
    Map<String, dynamic> diskMap,
    List<DiskItemModel> results,
  ) async {
    final parentDevice = (diskMap['DeviceIdentifier'] ?? '').toString();
    final partitions = (diskMap['Partitions'] as List?) ?? [];
    final apfsVolumes = (diskMap['APFSVolumes'] as List?) ?? [];

    // 处理常规分区
    for (final part in partitions) {
      if (part is Map<String, dynamic>) {
        final devId = (part['DeviceIdentifier'] ?? '').toString();
        if (devId.isNotEmpty) {
          final item = await _fetchDiskDetail(devId, parentDevice);
          if (item != null && !_isSystemInternalIgnore(item)) {
            results.add(item);
          }
        }
      }
    }

    // 处理 APFS 卷
    for (final vol in apfsVolumes) {
      if (vol is Map<String, dynamic>) {
        final devId = (vol['DeviceIdentifier'] ?? '').toString();
        if (devId.isNotEmpty) {
          final item = await _fetchDiskDetail(devId, parentDevice);
          if (item != null && !_isSystemInternalIgnore(item)) {
            results.add(item);
          }
        }
      }
    }
  }

  /// 注释：获取具体分区的详细信息
  /// 时间：2026/08/16 12:20
  /// 作者：郭翰林
  static Future<DiskItemModel?> _fetchDiskDetail(
    String devId,
    String parentDisk,
  ) async {
    try {
      final infoResult =
          await Process.run('diskutil', ['info', '-plist', '/dev/$devId']);
      if (infoResult.exitCode != 0) return null;

      final doc = XmlDocument.parse(infoResult.stdout.toString());
      final dictNode = doc.findAllElements('dict').firstOrNull;
      if (dictNode == null) return null;

      final info = _parsePlistDict(dictNode);

      final volumeName = (info['VolumeName'] ?? '').toString();
      final mountPoint = (info['MountPoint'] ?? '').toString();
      final fsType = (info['FilesystemType'] ?? '').toString().toLowerCase();
      final fsName = (info['FilesystemName'] ?? '').toString();
      final userVisibleFs =
          (info['FilesystemUserVisibleName'] ?? '').toString();
      final content = (info['Content'] ?? '').toString();

      final isInternal = (info['Internal'] == true);
      final isRemovable = (info['RemovableMedia'] == true) ||
          (info['RemovableMediaOrExternalDevice'] == true);

      final isWritable = (info['Writable'] == true) &&
          (info['WritableVolume'] == true);
      final isMounted = mountPoint.isNotEmpty;

      final totalSize = (info['TotalSize'] ?? info['Size'] ?? 0) as int;
      final freeSpace = (info['FreeSpace'] ?? 0) as int;
      final usedSpace = totalSize > freeSpace ? totalSize - freeSpace : 0;
      final uuid = (info['DiskUUID'] ?? info['VolumeUUID'] ?? '').toString();

      // 判断是否是 NTFS
      final isNTFS = fsType.contains('ntfs') ||
          fsName.toLowerCase().contains('ntfs') ||
          userVisibleFs.toLowerCase().contains('ntfs') ||
          content.contains('Microsoft Basic Data');

      return DiskItemModel(
        deviceIdentifier: devId,
        deviceNode: '/dev/$devId',
        parentDisk: parentDisk.isNotEmpty ? parentDisk : devId,
        volumeName: volumeName.isNotEmpty ? volumeName : devId,
        mountPoint: mountPoint,
        filesystemType: fsType.isNotEmpty ? fsType : (isNTFS ? 'ntfs' : content),
        filesystemName: userVisibleFs.isNotEmpty
            ? userVisibleFs
            : (fsName.isNotEmpty ? fsName : '未知文件系统'),
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

  /// 注释：以读写模式安全挂载 NTFS 磁盘 (带失败自动回滚与数据安全保护)
  /// 时间：2026/08/16 16:45
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
        await Future.delayed(const Duration(milliseconds: 400));
      }

      // 3. 构造基于 FUSE-T + NTFS-3G 的高级安全挂载脚本 (带自动修复与容灾参数)
      final mountCommand = '''
mkdir -p "$targetMountPath"
${env.ntfs3gPath} ${disk.deviceNode} "$targetMountPath" -o local,allow_other,auto_xattr,recover,remove_hiberfile,windows_names,volname="$mountPointName"
''';

      loggerInfo('执行安全读写挂载脚本:\n$mountCommand');
      final scriptResult = await LyUtils.runPrivilegedScript(mountCommand);

      if (scriptResult.exitCode == 0) {
        loggerInfo('🎉 磁盘 ${disk.displayName} 读写挂载成功！');
        LyUtils.showToast('【${disk.displayName}】已成功以读写模式挂载！');
        await Future.delayed(const Duration(milliseconds: 500));
        await LyUtils.openInFinder(targetMountPath);
        return true;
      } else {
        loggerError('读写挂载失败: ${scriptResult.stderr} ${scriptResult.stdout}');
        // 4. 挂载失败保护机制：清理空目录并安全回滚到系统原生挂载
        await _handleMountRollback(disk, targetMountPath, wasMounted);

        final errMsg = scriptResult.stderr.toString();
        if (errMsg.contains('Windows cache') || errMsg.contains('unclean')) {
          LyUtils.showToast('磁盘存在 Windows 快速启动未释放标记，已安全回滚只读模式', isError: true);
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
      // 清理可能残留的空挂载目录
      await Process.run('rmdir', [targetMountPath]);
      // 若原本处于挂载状态，自动恢复原生只读挂载，防止磁盘丢失
      if (shouldRemount) {
        await Process.run('diskutil', ['mount', disk.deviceNode]);
      }
    } catch (e) {
      loggerError('回滚清理异常: $e');
    }
  }

  /// 注释：安全卸载磁盘 (先同步缓存 sync)
  /// 时间：2026/08/16 16:45
  /// 作者：郭翰林
  static Future<bool> unmountDisk(DiskItemModel disk) async {
    try {
      loggerInfo('正在安全卸载磁盘: ${disk.displayName} (${disk.deviceNode})');
      // 强制刷盘，保证数据写入完整
      await Process.run('sync', []);
      final res = await Process.run('diskutil', ['unmount', disk.deviceNode]);
      if (res.exitCode == 0) {
        loggerInfo('磁盘卸载成功: ${disk.displayName}');
        LyUtils.showToast('已卸载【${disk.displayName}】');
        return true;
      } else {
        // 尝试提权 umount
        if (disk.mountPoint.isNotEmpty) {
          final privRes = await LyUtils.runPrivilegedScript(
            'sync; umount "${disk.mountPoint}" || diskutil unmount force ${disk.deviceNode}',
          );
          if (privRes.exitCode == 0) {
            loggerInfo('强制卸载成功: ${disk.displayName}');
            LyUtils.showToast('已卸载【${disk.displayName}】');
            return true;
          }
        }
        loggerError('卸载失败: ${res.stderr}');
        LyUtils.showToast('卸载失败: ${res.stderr}', isError: true);
        return false;
      }
    } catch (e) {
      loggerError('卸载异常: $e');
      return false;
    }
  }

  /// 注释：安全推出物理磁盘 (强制落盘 sync)
  /// 时间：2026/08/16 16:45
  /// 作者：郭翰林
  static Future<bool> ejectDisk(DiskItemModel disk) async {
    try {
      loggerInfo('正在安全推出磁盘: ${disk.displayName} (${disk.deviceNode})');
      await Process.run('sync', []);
      final res = await Process.run('diskutil', ['eject', disk.deviceNode]);
      if (res.exitCode == 0) {
        loggerInfo('磁盘已安全推出: ${disk.displayName}');
        LyUtils.showToast('【${disk.displayName}】已安全推出');
        return true;
      } else {
        loggerError('推出失败: ${res.stderr}');
        LyUtils.showToast('推出失败: ${res.stderr}', isError: true);
        return false;
      }
    } catch (e) {
      loggerError('推出磁盘异常: $e');
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
        i++; // 跳过已消费的 value element
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
