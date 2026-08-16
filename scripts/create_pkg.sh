#!/bin/bash
set -e

APP_NAME="macOS NFTS"
VERSION="1.0.0"
BUNDLE_ID="com.guohanlin.macntfspro"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST_PKG="$HOME/Desktop/macOS NFTS_Installer.pkg"
TMP_ROOT="/tmp/macntfs_pkg_root"
TMP_SCRIPTS="/tmp/macntfs_pkg_scripts"
TMP_COMPONENT_PKG="/tmp/macOS_NFTS_Component.pkg"

echo "================================================="
echo "  正在制作 $APP_NAME v$VERSION 一键安装包 (PKG)   "
echo "================================================="

# 1. 检查并定位 Release App 编译产物
RELEASE_DIR="$PROJECT_ROOT/build/macos/Build/Products/Release"
find_src_app() {
    if [ -d "$RELEASE_DIR/$APP_NAME.app" ]; then
        echo "$RELEASE_DIR/$APP_NAME.app"
    elif [ -d "$RELEASE_DIR/mac_ntfs_pro.app" ]; then
        echo "$RELEASE_DIR/mac_ntfs_pro.app"
    else
        find "$RELEASE_DIR" -maxdepth 1 -name "*.app" 2>/dev/null | head -n 1
    fi
}

SRC_APP="$(find_src_app)"

if [ -z "$SRC_APP" ] || [ ! -d "$SRC_APP" ]; then
    echo "⚠️ 未找到 Release 编译产物，正在执行 flutter build macos --release..."
    flutter build macos --release
    SRC_APP="$(find_src_app)"
fi

if [ -z "$SRC_APP" ] || [ ! -d "$SRC_APP" ]; then
    echo "❌ 错误: 未能在 $RELEASE_DIR 下找到有效的 macOS .app 编译产物！"
    exit 1
fi

echo "🔍 识别到 App 产物路径: $SRC_APP"

# 2. 清理临时构建目录
rm -rf "$TMP_ROOT" "$TMP_SCRIPTS" "$TMP_COMPONENT_PKG" "$DEST_PKG"
mkdir -p "$TMP_ROOT/Applications"
mkdir -p "$TMP_SCRIPTS"

# 3. 复制 App 到打包根目录
echo "📦 正在准备 App 核心文件..."
cp -R "$SRC_APP" "$TMP_ROOT/Applications/$APP_NAME.app"

# 4. 嵌入 Universal 离线驱动资源包到 App.bundle/Contents/Resources/driver
echo "🔧 正在将 Universal 驱动 (FUSE-T + NTFS-3G) 嵌入 App Bundle..."
DRIVER_DEST="$TMP_ROOT/Applications/$APP_NAME.app/Contents/Resources/driver"
mkdir -p "$DRIVER_DEST/bin" "$DRIVER_DEST/lib"

cp "$PROJECT_ROOT/assets/driver/fuse-t.pkg" "$DRIVER_DEST/"
cp "$PROJECT_ROOT/assets/driver/bin/ntfs-3g" "$DRIVER_DEST/bin/"
cp "$PROJECT_ROOT/assets/driver/lib/libntfs-3g.dylib" "$DRIVER_DEST/lib/"
cp "$PROJECT_ROOT/assets/driver/lib/libintl.8.dylib" "$DRIVER_DEST/lib/"
chmod +x "$DRIVER_DEST/bin/ntfs-3g"

# 5. 生成 postinstall 自动安装脚本
echo "⚙️ 正在生成 postinstall 驱动静默安装钩子..."
cat << 'EOF' > "$TMP_SCRIPTS/postinstall"
#!/bin/bash
set -e

APP_PATH="/Applications/macOS NFTS.app"
DRIVER_DIR="$APP_PATH/Contents/Resources/driver"

echo "=== 执行 macOS NFTS postinstall 安装钩子 ==="

# 1. 静默安装 FUSE-T 驱动
if [ -f "$DRIVER_DIR/fuse-t.pkg" ]; then
    echo "正在静默安装 FUSE-T 用户态文件系统驱动..."
    /usr/sbin/installer -pkg "$DRIVER_DIR/fuse-t.pkg" -target / || true
fi

# 2. 部署 Universal ntfs-3g 及相关库到 /usr/local
mkdir -p /usr/local/bin /usr/local/lib

if [ -f "$DRIVER_DIR/bin/ntfs-3g" ]; then
    echo "正在部署 Universal ntfs-3g 到 /usr/local/bin..."
    cp -f "$DRIVER_DIR/bin/ntfs-3g" /usr/local/bin/ntfs-3g
    chmod 755 /usr/local/bin/ntfs-3g
    chown root:wheel /usr/local/bin/ntfs-3g 2>/dev/null || true
fi

if [ -f "$DRIVER_DIR/lib/libntfs-3g.dylib" ]; then
    echo "正在部署 Universal libntfs-3g.dylib 到 /usr/local/lib..."
    cp -f "$DRIVER_DIR/lib/libntfs-3g.dylib" /usr/local/lib/libntfs-3g.dylib
    chmod 755 /usr/local/lib/libntfs-3g.dylib
fi

if [ -f "$DRIVER_DIR/lib/libintl.8.dylib" ]; then
    echo "正在部署 Universal libintl.8.dylib 到 /usr/local/lib..."
    cp -f "$DRIVER_DIR/lib/libintl.8.dylib" /usr/local/lib/libintl.8.dylib
    chmod 755 /usr/local/lib/libintl.8.dylib
fi

# 3. 创建 FUSE-T 动态库兼容软链接
if [ -f "/usr/local/lib/libfuse-t.dylib" ]; then
    echo "正在创建 FUSE-T 兼容动态链接库软链接..."
    ln -sf /usr/local/lib/libfuse-t.dylib /usr/local/lib/libfuse.2.dylib
    ln -sf /usr/local/lib/libfuse-t.dylib /usr/local/lib/libfuse.dylib
    ln -sf /usr/local/lib/libfuse-t.dylib /usr/local/lib/libosxfuse.2.dylib
    ln -sf /usr/local/lib/libfuse-t.dylib /usr/local/lib/libosxfuse.dylib
fi

# 4. 部署免密挂载 Helper 脚本与 sudoers 规则
echo "正在配置免密驱动挂载 Helper..."
cat << 'HELPER_EOF' > /usr/local/bin/macntfs-helper
#!/bin/bash
set -e
ACTION="$1"
DEVICE="$2"
MOUNT_PATH="$3"
VOL_NAME="$4"

if [ -f "/usr/local/lib/libfuse-t.dylib" ]; then
    [ ! -f "/usr/local/lib/libfuse.2.dylib" ] && ln -sf /usr/local/lib/libfuse-t.dylib /usr/local/lib/libfuse.2.dylib
    [ ! -f "/usr/local/lib/libfuse.dylib" ] && ln -sf /usr/local/lib/libfuse-t.dylib /usr/local/lib/libfuse.dylib
    [ ! -f "/usr/local/lib/libosxfuse.2.dylib" ] && ln -sf /usr/local/lib/libfuse-t.dylib /usr/local/lib/libosxfuse.2.dylib
    [ ! -f "/usr/local/lib/libosxfuse.dylib" ] && ln -sf /usr/local/lib/libfuse-t.dylib /usr/local/lib/libosxfuse.dylib
fi

case "$ACTION" in
    mount)
        diskutil unmount "$DEVICE" 2>/dev/null || true
        mkdir -p "$MOUNT_PATH"
        /usr/local/bin/ntfs-3g "$DEVICE" "$MOUNT_PATH" -o local,allow_other,auto_xattr,recover,remove_hiberfile,windows_names,hide_hid_files,hide_dot_files,volname="$VOL_NAME"
        ;;
    unmount)
        diskutil unmount force "$MOUNT_PATH" 2>/dev/null || umount -f "$MOUNT_PATH" 2>/dev/null || true
        diskutil unmount force "$DEVICE" 2>/dev/null || true
        DEV_ID="$(basename "$DEVICE")"
        pkill -9 -f "ntfs-3g.*$DEV_ID" 2>/dev/null || true
        rmdir "$MOUNT_PATH" 2>/dev/null || true
        diskutil mount "$DEVICE" 2>/dev/null || true
        ;;
    *)
        echo "Usage: $0 {mount|unmount} ..."
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

echo "=== macOS NFTS 驱动与免密环境部署完成！ ==="
exit 0
EOF

chmod +x "$TMP_SCRIPTS/postinstall"

# 6. 使用 pkgbuild 构建 Component PKG
echo "🔨 正在使用 pkgbuild 组装组件包..."
pkgbuild --root "$TMP_ROOT" \
         --scripts "$TMP_SCRIPTS" \
         --identifier "$BUNDLE_ID" \
         --version "$VERSION" \
         --install-location / \
         "$TMP_COMPONENT_PKG"

# 7. 使用 productbuild 生成最终的分发版 PKG
echo "🎉 正在使用 productbuild 生成最终安装器..."
productbuild --package "$TMP_COMPONENT_PKG" "$DEST_PKG"

# 8. 清理临时文件
rm -rf "$TMP_ROOT" "$TMP_SCRIPTS" "$TMP_COMPONENT_PKG"

echo "================================================="
echo "  ✅ PKG 安装包制作完成: $DEST_PKG"
echo "================================================="
ls -lh "$DEST_PKG"
