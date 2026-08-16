#!/bin/bash
set -e

APP_NAME="MacNTFS Pro"
VERSION="1.0.0"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC_APP="$PROJECT_ROOT/build/macos/Build/Products/Release/mac_ntfs_pro.app"
DEST_DMG="$HOME/Desktop/MacNTFS_Pro_Installer.dmg"
DMG_TMP_DIR="/tmp/macntfs_dmg_tmp"

echo "================================================="
echo "  正在制作 $APP_NAME v$VERSION 安装镜像 (DMG)     "
echo "================================================="

# 1. 确保已生成 PKG 安装器
if [ ! -f "$HOME/Desktop/MacNTFS_Pro_Installer.pkg" ]; then
    echo "📦 正在先调用 create_pkg.sh 生成安装器..."
    bash "$PROJECT_ROOT/scripts/create_pkg.sh"
fi

# 2. 清理旧数据
rm -rf "$DMG_TMP_DIR"
rm -f "$DEST_DMG"
mkdir -p "$DMG_TMP_DIR"

# 3. 复制 App 并嵌入 Universal 驱动
echo "📁 正在准备 DMG 内置应用与资源..."
cp -R "$SRC_APP" "$DMG_TMP_DIR/MacNTFS Pro.app"
DRIVER_DEST="$DMG_TMP_DIR/MacNTFS Pro.app/Contents/Resources/driver"
mkdir -p "$DRIVER_DEST/bin" "$DRIVER_DEST/lib"
cp "$PROJECT_ROOT/assets/driver/fuse-t.pkg" "$DRIVER_DEST/"
cp "$PROJECT_ROOT/assets/driver/bin/ntfs-3g" "$DRIVER_DEST/bin/"
cp "$PROJECT_ROOT/assets/driver/lib/libntfs-3g.dylib" "$DRIVER_DEST/lib/"
cp "$PROJECT_ROOT/assets/driver/lib/libintl.8.dylib" "$DRIVER_DEST/lib/"
chmod +x "$DRIVER_DEST/bin/ntfs-3g"

# 4. 复制一键自动安装器 (PKG) 到 DMG 根目录
cp "$HOME/Desktop/MacNTFS_Pro_Installer.pkg" "$DMG_TMP_DIR/一键安装 MacNTFS Pro 与驱动.pkg"

# 5. 创建 Applications 软链接
ln -s /Applications "$DMG_TMP_DIR/Applications"

# 6. 使用 hdiutil 打包为 DMG
echo "💿 正在打包为 DMG 镜像文件..."
hdiutil create -volname "MacNTFS Pro Installer" -srcfolder "$DMG_TMP_DIR" -ov -format UDZO "$DEST_DMG"

# 7. 清理临时目录
rm -rf "$DMG_TMP_DIR"

echo "================================================="
echo "  ✅ DMG 安装包制作完成: $DEST_DMG"
echo "================================================="
ls -lh "$DEST_DMG"
