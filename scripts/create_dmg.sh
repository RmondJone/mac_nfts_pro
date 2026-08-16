#!/bin/bash
set -e

APP_NAME="MacNTFS Pro"
SRC_APP="/Users/guohanlin/mac_ntfs_pro/build/macos/Build/Products/Release/mac_ntfs_pro.app"
DEST_DMG="/Users/guohanlin/Desktop/MacNTFS_Pro_Installer.dmg"
DMG_TMP_DIR="/tmp/macntfs_dmg_tmp"

echo "=== 正在制作 $APP_NAME 安装镜像 (DMG) ==="

# 清理旧数据
rm -rf "$DMG_TMP_DIR"
rm -f "$DEST_DMG"
mkdir -p "$DMG_TMP_DIR"

# 复制 App 并创建 Applications 软链接
cp -R "$SRC_APP" "$DMG_TMP_DIR/MacNTFS Pro.app"
ln -s /Applications "$DMG_TMP_DIR/Applications"

# 使用 hdiutil 打包为 DMG
hdiutil create -volname "MacNTFS Pro Installer" -srcfolder "$DMG_TMP_DIR" -ov -format UDZO "$DEST_DMG"

# 清理临时目录
rm -rf "$DMG_TMP_DIR"

echo "=== DMG 安装包制作完成: $DEST_DMG ==="
ls -lh "$DEST_DMG"
