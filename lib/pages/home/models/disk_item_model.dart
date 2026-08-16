/// 注释：磁盘实体模型类
/// 时间：2026/08/16 12:20
/// 作者：郭翰林
class DiskItemModel {
  final String deviceIdentifier;
  final String deviceNode;
  final String parentDisk;
  final String volumeName;
  final String mountPoint;
  final String filesystemType;
  final String filesystemName;
  final bool isNTFS;
  final bool isMounted;
  final bool isWritable;
  final bool isInternal;
  final bool isRemovable;
  final int totalSize;
  final int freeSpace;
  final int usedSpace;
  final String uuid;

  DiskItemModel({
    required this.deviceIdentifier,
    required this.deviceNode,
    required this.parentDisk,
    required this.volumeName,
    required this.mountPoint,
    required this.filesystemType,
    required this.filesystemName,
    required this.isNTFS,
    required this.isMounted,
    required this.isWritable,
    required this.isInternal,
    required this.isRemovable,
    required this.totalSize,
    required this.freeSpace,
    required this.usedSpace,
    required this.uuid,
  });

  /// 使用百分比
  double get usagePercentage {
    if (totalSize <= 0) return 0.0;
    final used = totalSize - freeSpace;
    return (used / totalSize).clamp(0.0, 1.0);
  }

  /// 状态描述文本
  String get statusText {
    if (!isMounted) return '未挂载';
    if (isWritable) return '可读写 (RW)';
    return '只读 (RO)';
  }

  /// 显示名称
  String get displayName {
    if (volumeName.trim().isNotEmpty) return volumeName;
    return deviceIdentifier;
  }

  /// 拷贝并修改
  DiskItemModel copyWith({
    String? deviceIdentifier,
    String? deviceNode,
    String? parentDisk,
    String? volumeName,
    String? mountPoint,
    String? filesystemType,
    String? filesystemName,
    bool? isNTFS,
    bool? isMounted,
    bool? isWritable,
    bool? isInternal,
    bool? isRemovable,
    int? totalSize,
    int? freeSpace,
    int? usedSpace,
    String? uuid,
  }) {
    return DiskItemModel(
      deviceIdentifier: deviceIdentifier ?? this.deviceIdentifier,
      deviceNode: deviceNode ?? this.deviceNode,
      parentDisk: parentDisk ?? this.parentDisk,
      volumeName: volumeName ?? this.volumeName,
      mountPoint: mountPoint ?? this.mountPoint,
      filesystemType: filesystemType ?? this.filesystemType,
      filesystemName: filesystemName ?? this.filesystemName,
      isNTFS: isNTFS ?? this.isNTFS,
      isMounted: isMounted ?? this.isMounted,
      isWritable: isWritable ?? this.isWritable,
      isInternal: isInternal ?? this.isInternal,
      isRemovable: isRemovable ?? this.isRemovable,
      totalSize: totalSize ?? this.totalSize,
      freeSpace: freeSpace ?? this.freeSpace,
      usedSpace: usedSpace ?? this.usedSpace,
      uuid: uuid ?? this.uuid,
    );
  }
}
