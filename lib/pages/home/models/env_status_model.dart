/// 注释：环境与驱动状态模型类
/// 时间：2026/08/16 12:20
/// 作者：郭翰林
class EnvStatusModel {
  final bool hasBrew;
  final String brewPath;
  final bool hasNtfs3g;
  final String ntfs3gPath;
  final bool hasFuse;
  final String fuseType; // 'FUSE-T', 'macFUSE', 'None'
  final String checkMessage;

  EnvStatusModel({
    required this.hasBrew,
    required this.brewPath,
    required this.hasNtfs3g,
    required this.ntfs3gPath,
    required this.hasFuse,
    required this.fuseType,
    required this.checkMessage,
  });

  /// 是否具备完整的 FUSE-T + NTFS-3G 读写能力
  bool get canWriteNtfs => hasNtfs3g && hasFuse;

  /// 当前驱动引擎状态展示名称
  String get activeDriverName {
    if (hasNtfs3g && hasFuse) {
      return '$fuseType + NTFS-3G';
    }
    if (hasNtfs3g) {
      return 'NTFS-3G (缺少 FUSE 环境)';
    }
    return '未配置 (系统原生只读)';
  }
}
