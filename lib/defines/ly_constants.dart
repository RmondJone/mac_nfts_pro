/// 注释：全局常量定义类
/// 时间：2026/08/16 12:20
/// 作者：郭翰林
class LyConstants {
  static const String appName = 'macOS NFTS';
  static const String appVersion = '1.0.0';
  static const String appAuthor = 'RmondJone';
  static const String appCopyright = 'Copyright © 2026 RmondJone. All rights reserved.';
  static const String appDesc = 'macOS NTFS 磁盘读写管理专家';

  // 常见 ntfs-3g 可执行文件路径
  static const List<String> ntfs3gPaths = [
    '/usr/local/bin/ntfs-3g',
    '/opt/homebrew/bin/ntfs-3g',
    '/usr/local/sbin/ntfs-3g',
    '/opt/homebrew/sbin/ntfs-3g',
  ];
}

