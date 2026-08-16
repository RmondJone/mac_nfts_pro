import 'dart:io';
import '../defines/ly_constants.dart';
import '../pages/home/models/env_status_model.dart';
import 'logger_utils.dart';

/// 注释：环境与驱动检测及离线安装工具类
/// 时间：2026/08/16 16:30
/// 作者：郭翰林
class EnvEngineUtils {
  /// 注释：获取 App 内置离线驱动资源目录
  /// 时间：2026/08/16 16:30
  /// 作者：郭翰林
  static Directory? getEmbeddedDriverDir() {
    final List<String> candidatePaths = [];

    try {
      // 1. App Bundle 中的 Resources/driver
      final bundleDir = File(Platform.resolvedExecutable).parent.parent;
      candidatePaths.add('${bundleDir.path}/Resources/driver');

      // 2. App.framework 中的 flutter_assets/assets/driver
      candidatePaths.add(
        '${bundleDir.path}/Frameworks/App.framework/Resources/flutter_assets/assets/driver',
      );
    } catch (_) {}

    // 3. 当前工作目录下的 assets/driver (开发调试模式)
    candidatePaths.add('${Directory.current.path}/assets/driver');

    for (final path in candidatePaths) {
      final dir = Directory(path);
      if (dir.existsSync()) {
        final hasPkg = File('${dir.path}/fuse-t.pkg').existsSync();
        final hasBin = File('${dir.path}/bin/ntfs-3g').existsSync();
        if (hasPkg || hasBin) {
          return dir;
        }
      }
    }
    return null;
  }

  /// 注释：全面检测当前系统的 NTFS 驱动环境
  /// 时间：2026/08/16 16:30
  /// 作者：郭翰林
  static Future<EnvStatusModel> checkEnvironment() async {
    loggerInfo('开始检测系统 NTFS 读写驱动与运行环境...');

    // 1. 检测 Homebrew（作为可选辅助）
    String brewPath = '';
    bool hasBrew = false;
    for (final path in ['/usr/local/bin/brew', '/opt/homebrew/bin/brew']) {
      if (File(path).existsSync()) {
        brewPath = path;
        hasBrew = true;
        break;
      }
    }

    // 2. 检测 NTFS-3G 可执行文件
    String ntfs3gPath = '';
    bool hasNtfs3g = false;
    final embeddedDir = getEmbeddedDriverDir();

    final List<String> ntfsSearchPaths = [
      ...LyConstants.ntfs3gPaths,
      if (embeddedDir != null) '${embeddedDir.path}/bin/ntfs-3g',
    ];

    for (final path in ntfsSearchPaths) {
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

    // 校验 ntfs-3g 动态链接库是否能够正常加载运行 (防止缺失 libfuse.2.dylib 等依赖)
    if (hasNtfs3g) {
      try {
        final testRun = await Process.run(ntfs3gPath, ['--version']);
        final isRunOk = testRun.exitCode == 0 ||
            testRun.stdout.toString().contains('ntfs-3g') ||
            testRun.stderr.toString().contains('ntfs-3g');

        // 若因缺少 libfuse.2.dylib 导致加载失败，但存在 libfuse-t.dylib，尝试自愈软链接
        if (!isRunOk && File('/usr/local/lib/libfuse-t.dylib').existsSync()) {
          try {
            await Process.run('ln', [
              '-sf',
              '/usr/local/lib/libfuse-t.dylib',
              '/usr/local/lib/libfuse.2.dylib',
            ]);
            await Process.run('ln', [
              '-sf',
              '/usr/local/lib/libfuse-t.dylib',
              '/usr/local/lib/libfuse.dylib',
            ]);
          } catch (_) {}
        }
      } catch (_) {}
    }

    // 3. 检测 FUSE-T / macFUSE
    bool hasFuse = false;
    String fuseType = 'None';
    if (Directory('/Library/Filesystems/fuse-t.fs').existsSync() ||
        Directory('/usr/local/include/fuse-t').existsSync() ||
        File('/usr/local/lib/libfuse-t.dylib').existsSync() ||
        Directory('/Library/Application Support/fuse-t').existsSync()) {
      hasFuse = true;
      fuseType = 'FUSE-T';
    } else if (Directory('/Library/Filesystems/macfuse.fs').existsSync() ||
        Directory('/Library/Filesystems/osxfuse.fs').existsSync()) {
      hasFuse = true;
      fuseType = 'macFUSE';
    }

    String message = 'FUSE-T + NTFS-3G 读写驱动已就绪';
    if (!hasNtfs3g || !hasFuse) {
      if (embeddedDir != null) {
        message = '检测到内置离线驱动包，点击【一键配置驱动】即可秒级极速就绪';
      } else {
        message = '未检测到完整读写驱动，请点击一键配置驱动';
      }
    }

    loggerInfo(
      '驱动环境检测完成: ntfs-3g=$hasNtfs3g ($ntfs3gPath), FUSE=$fuseType, 内置离线包=${embeddedDir != null}',
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

  /// 注释：获取离线驱动安装 Shell 脚本 (含免密挂载 Helper 与 Sudoers 规则配置)
  /// 时间：2026/08/16 18:45
  /// 作者：郭翰林
  static String? getOfflineInstallScript() {
    final embeddedDir = getEmbeddedDriverDir();
    if (embeddedDir == null) return null;

    final fusePkg = '${embeddedDir.path}/fuse-t.pkg';
    final ntfs3gBin = '${embeddedDir.path}/bin/ntfs-3g';
    final libNtfs3g = '${embeddedDir.path}/lib/libntfs-3g.dylib';
    final libIntl = '${embeddedDir.path}/lib/libintl.8.dylib';

    return '''
if [ -f "$fusePkg" ]; then
    /usr/sbin/installer -pkg "$fusePkg" -target /
fi

mkdir -p /usr/local/bin /usr/local/lib

if [ -f "$ntfs3gBin" ]; then
    cp -f "$ntfs3gBin" /usr/local/bin/ntfs-3g
    chmod 755 /usr/local/bin/ntfs-3g
    chown root:wheel /usr/local/bin/ntfs-3g
fi

if [ -f "$libNtfs3g" ]; then
    cp -f "$libNtfs3g" /usr/local/lib/libntfs-3g.dylib
    chmod 755 /usr/local/lib/libntfs-3g.dylib
fi

if [ -f "$libIntl" ]; then
    cp -f "$libIntl" /usr/local/lib/libintl.8.dylib
    chmod 755 /usr/local/lib/libintl.8.dylib
fi

if [ -f "/usr/local/lib/libfuse-t.dylib" ]; then
    ln -sf /usr/local/lib/libfuse-t.dylib /usr/local/lib/libfuse.2.dylib
    ln -sf /usr/local/lib/libfuse-t.dylib /usr/local/lib/libfuse.dylib
    ln -sf /usr/local/lib/libfuse-t.dylib /usr/local/lib/libosxfuse.2.dylib
    ln -sf /usr/local/lib/libfuse-t.dylib /usr/local/lib/libosxfuse.dylib
fi

# 部署免密挂载 Helper 脚本
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
        exit 1
        ;;
esac
HELPER_EOF

chmod 755 /usr/local/bin/macntfs-helper
chown root:wheel /usr/local/bin/macntfs-helper

# 配置 sudoers 免密规则 (只需首次授权，后续读写挂载完全免密)
mkdir -p /private/etc/sudoers.d
echo "ALL ALL=(ALL) NOPASSWD: /usr/local/bin/macntfs-helper, /usr/local/bin/ntfs-3g" > /private/etc/sudoers.d/mac_ntfs_pro
chmod 440 /private/etc/sudoers.d/mac_ntfs_pro
chown root:wheel /private/etc/sudoers.d/mac_ntfs_pro
visudo -cf /private/etc/sudoers.d/mac_ntfs_pro 2>/dev/null || rm -f /private/etc/sudoers.d/mac_ntfs_pro
''';
  }

  /// 注释：获取一键彻底卸载与系统清理 Shell 脚本
  /// 时间：2026/08/16 18:45
  /// 作者：郭翰林
  static String getUninstallScript() {
    return '''
# 1. 卸载 FUSE-T 驱动框架
if [ -f "/Library/Application Support/fuse-t/uninstall.sh" ]; then
    bash "/Library/Application Support/fuse-t/uninstall.sh" 2>/dev/null || true
fi
rm -rf "/Library/Application Support/fuse-t" 2>/dev/null || true
rm -rf "/Library/Frameworks/fuse_t.framework" 2>/dev/null || true
rm -rf "/Library/Filesystems/fuse-t.fs" 2>/dev/null || true

# 2. 清理 /usr/local 下的驱动与软链接及免密 Helper
rm -f /usr/local/bin/ntfs-3g
rm -f /usr/local/bin/macntfs-helper
rm -f /private/etc/sudoers.d/mac_ntfs_pro
rm -f /usr/local/lib/libntfs-3g*
rm -f /usr/local/lib/libfuse-t*
rm -f /usr/local/lib/libfuse.2.dylib
rm -f /usr/local/lib/libfuse.dylib
rm -f /usr/local/lib/libosxfuse*
rm -f /usr/local/lib/libintl.8.dylib

# 3. 清理用户配置与缓存
USER_NAME=\${SUDO_USER:-\$USER}
USER_HOME=\$(eval echo ~\$USER_NAME)
rm -rf "\$USER_HOME/Library/Application Support/com.guohanlin.macntfspro"
rm -rf "\$USER_HOME/Library/Caches/com.guohanlin.macntfspro"
rm -rf "\$USER_HOME/Library/Preferences/com.guohanlin.macntfspro.plist"

# 4. 删除 App 主程序 (若位于 /Applications)
rm -rf "/Applications/MacNTFS Pro.app"
''';
  }
}

