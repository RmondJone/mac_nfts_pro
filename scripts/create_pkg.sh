#!/bin/bash
set -e

APP_NAME="MacNTFS Pro"
VERSION="1.0.0"
BUNDLE_ID="com.guohanlin.macntfspro"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC_APP="$PROJECT_ROOT/build/macos/Build/Products/Release/mac_ntfs_pro.app"
DEST_PKG="$HOME/Desktop/MacNTFS_Pro_Installer.pkg"
TMP_ROOT="/tmp/macntfs_pkg_root"
TMP_SCRIPTS="/tmp/macntfs_pkg_scripts"
TMP_COMPONENT_PKG="/tmp/MacNTFS_Pro_Component.pkg"

echo "================================================="
echo "  正在制作 $APP_NAME v$VERSION 一键安装包 (PKG)   "
echo "================================================="

# 1. 检查 Release App 是否已编译
if [ ! -d "$SRC_APP" ]; then
    echo "⚠️ 未找到 Release 编译产物，正在执行 flutter build macos --release..."
    flutter build macos --release
fi

# 2. 清理临时构建目录
rm -rf "$TMP_ROOT" "$TMP_SCRIPTS" "$TMP_COMPONENT_PKG" "$DEST_PKG"
mkdir -p "$TMP_ROOT/Applications/$APP_NAME.app"
mkdir -p "$TMP_SCRIPTS"

# 3. 复制 App 到打包根目录
echo "📦 正在准备 App 核心文件..."
cp -R "$SRC_APP/" "$TMP_ROOT/Applications/$APP_NAME.app/"

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

APP_PATH="/Applications/MacNTFS Pro.app"
DRIVER_DIR="$APP_PATH/Contents/Resources/driver"

echo "=== 执行 MacNTFS Pro postinstall 安装钩子 ==="

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

echo "=== MacNTFS Pro 驱动环境部署完成！ ==="
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
