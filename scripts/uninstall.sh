#!/bin/bash
# ==============================================================================
# macOS NFTS 彻底卸载与清理脚本
# 作者：郭翰林
# 时间：2026/08/16 17:35
# 说明：清理 App 本体、用户偏好配置、FUSE-T 及 /usr/local 下的 NTFS 驱动与动态库
# ==============================================================================

echo "================================================="
echo "       正在执行 macOS NFTS 彻底清理与卸载        "
echo "================================================="

# 请求管理员权限
if [ "$EUID" -ne 0 ]; then
    echo "⚠️ 卸载系统驱动需要管理员权限，正在请求提权..."
    exec sudo "$0" "$@"
fi

# 1. 退出正在运行的 macOS NFTS
echo "1. 正在退出应用进程..."
pkill -f "macOS NFTS" 2>/dev/null || true
pkill -f "MacNTFS Pro" 2>/dev/null || true
pkill -f "mac_ntfs_pro" 2>/dev/null || true

# 2. 卸载 FUSE-T 用户态文件系统驱动
echo "2. 正在卸载 FUSE-T 驱动框架..."
if [ -f "/Library/Application Support/fuse-t/uninstall.sh" ]; then
    bash "/Library/Application Support/fuse-t/uninstall.sh" 2>/dev/null || true
fi
rm -rf "/Library/Application Support/fuse-t" 2>/dev/null || true
rm -rf "/Library/Frameworks/fuse_t.framework" 2>/dev/null || true
rm -rf "/Library/Filesystems/fuse-t.fs" 2>/dev/null || true

# 3. 清理 /usr/local 下的 NTFS-3G 及动态链接库软链接
echo "3. 正在清理 /usr/local 中的驱动与依赖库..."
rm -f /usr/local/bin/ntfs-3g
rm -f /usr/local/lib/libntfs-3g*
rm -f /usr/local/lib/libfuse-t*
rm -f /usr/local/lib/libfuse.2.dylib
rm -f /usr/local/lib/libfuse.dylib
rm -f /usr/local/lib/libosxfuse*
rm -f /usr/local/lib/libintl.8.dylib

# 4. 删除 App 主程序
echo "4. 正在删除 /Applications/macOS NFTS.app..."
rm -rf "/Applications/macOS NFTS.app"
rm -rf "/Applications/MacNTFS Pro.app"

# 5. 清理当前登录用户的配置与缓存
echo "5. 正在清理用户配置与偏好设置缓存..."
USER_HOME=$(eval echo ~${SUDO_USER:-$USER})
rm -rf "$USER_HOME/Library/Application Support/com.guohanlin.macntfspro"
rm -rf "$USER_HOME/Library/Caches/com.guohanlin.macntfspro"
rm -rf "$USER_HOME/Library/Preferences/com.guohanlin.macntfspro.plist"

echo "================================================="
echo "  🎉 macOS NFTS 及其驱动依赖已全部彻底卸载干净！  "
echo "================================================="
exit 0
