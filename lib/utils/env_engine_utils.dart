import 'dart:io';
import '../defines/ly_constants.dart';
import '../pages/home/models/env_status_model.dart';
import 'logger_utils.dart';

/// 注释：环境与驱动检测工具类
/// 时间：2026/08/16 12:20
/// 作者：郭翰林
class EnvEngineUtils {
  /// 注释：全面检测当前系统的 NTFS 驱动环境
  /// 时间：2026/08/16 12:20
  /// 作者：郭翰林
  static Future<EnvStatusModel> checkEnvironment() async {
    loggerInfo('开始检测系统 NTFS 读写驱动与运行环境...');

    // 1. 检测 Homebrew
    String brewPath = '';
    bool hasBrew = false;
    for (final path in ['/usr/local/bin/brew', '/opt/homebrew/bin/brew']) {
      if (File(path).existsSync()) {
        brewPath = path;
        hasBrew = true;
        break;
      }
    }
    if (!hasBrew) {
      try {
        final whichRes = await Process.run('which', ['brew']);
        if (whichRes.exitCode == 0 && whichRes.stdout.toString().trim().isNotEmpty) {
          brewPath = whichRes.stdout.toString().trim();
          hasBrew = true;
        }
      } catch (_) {}
    }

    // 2. 检测 NTFS-3G 可执行文件
    String ntfs3gPath = '';
    bool hasNtfs3g = false;
    for (final path in LyConstants.ntfs3gPaths) {
      if (File(path).existsSync()) {
        ntfs3gPath = path;
        hasNtfs3g = true;
        break;
      }
    }
    if (!hasNtfs3g) {
      try {
        final whichRes = await Process.run('which', ['ntfs-3g']);
        if (whichRes.exitCode == 0 &&
            whichRes.stdout.toString().trim().isNotEmpty) {
          ntfs3gPath = whichRes.stdout.toString().trim();
          hasNtfs3g = true;
        }
      } catch (_) {}
    }

    // 3. 检测 FUSE-T / macFUSE
    bool hasFuse = false;
    String fuseType = 'None';
    if (Directory('/Library/Filesystems/fuse-t.fs').existsSync() ||
        Directory('/usr/local/include/fuse-t').existsSync() ||
        File('/usr/local/lib/libfuse-t.dylib').existsSync()) {
      hasFuse = true;
      fuseType = 'FUSE-T';
    } else if (Directory('/Library/Filesystems/macfuse.fs').existsSync() ||
        Directory('/Library/Filesystems/osxfuse.fs').existsSync()) {
      hasFuse = true;
      fuseType = 'macFUSE';
    }

    String message = 'FUSE-T + NTFS-3G 读写驱动已就绪';
    if (!hasNtfs3g || !hasFuse) {
      if (!hasFuse && !hasNtfs3g) {
        message = '未检测到 FUSE-T 与 NTFS-3G 驱动，点击一键配置以获取完整读写支持';
      } else if (!hasFuse) {
        message = '未检测到 FUSE-T 用户态驱动，点击一键配置进行补全';
      } else {
        message = '未检测到 NTFS-3G 组件，点击一键配置进行补全';
      }
    }

    loggerInfo(
      '驱动环境检测完成: brew=$hasBrew, ntfs-3g=$hasNtfs3g ($ntfs3gPath), FUSE=$fuseType',
    );

    return EnvStatusModel(
      hasBrew: hasBrew,
      brewPath: brewPath,
      hasNtfs3g: hasNtfs3g,
      ntfs3gPath: ntfs3gPath,
      hasFuse: hasFuse,
      fuseType: fuseType,
      checkMessage: message,
    );
  }

  /// 注释：获取一键安装推荐驱动的 Shell 脚本
  /// 时间：2026/08/16 12:20
  /// 作者：郭翰林
  static String getInstallScript() {
    return '''
# 安装 FUSE-T 和 NTFS-3G 读写支持
if command -v brew >/dev/null 2>&1; then
    echo "正在通过 Homebrew 安装 FUSE-T 与 ntfs-3g..."
    brew tap gromgit/fuse 2>/dev/null || true
    brew install --cask fuse-t 2>/dev/null || true
    brew install ntfs-3g-mac 2>/dev/null || brew install gromgit/fuse/ntfs-3g-mac 2>/dev/null || true
    echo "驱动配置完成！"
else
    echo "请先安装 Homebrew 或联系管理员配置驱动。"
fi
''';
  }
}
