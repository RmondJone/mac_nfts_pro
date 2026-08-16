# 🎉 MacNFTSPro v1.0.0 - 首次正式版发布！

**MacNFTSPro** 是一款专为 macOS 打造的高性能、轻量级、**免关 SIP / 免降系统安全策略** 的 NTFS 磁盘读写管理专家。

基于现代化 **FUSE-T + NTFS-3G** 纯用户态文件系统驱动架构，告别传统商业软件的高昂订阅费以及旧版方案需要进入恢复模式降级内核安全性的繁琐操作，让您在 Mac 上如同使用原生硬盘般自由读写、拷贝、修改与管理 NTFS 外置存储设备！

---

## ✨ 核心特性与亮点 (Highlights)

- 🛡️ **免关 SIP，免降安全等级**：采用现代 FUSE-T 本地 NFS 协议栈桥接，无需进 Recovery 模式关闭系统完整性保护，对 macOS 系统核心完全无侵入。
- ⚡ **原生级高速读写**：内置深度调优的 Universal NTFS-3G 驱动引擎，优化缓存管理与扩展属性（xattr），大文件传输稳定迅速。
- 📦 **开箱即用（无需联网配环境）**：安装包内置 Apple Silicon (M1/M2/M3/M4) 与 Intel (x86_64) 双架构离线驱动，PKG 安装器自动完成静默配置。
- 🔌 **即插即用硬件自感知**：底层监听磁盘硬件与卷通知，U 盘/移动硬盘插拔及挂载状态秒级动态刷新。
- 📁 **访达（Finder）深度联动**：一键读写挂载成功后，自动在访达中唤起并打开目标磁盘根目录，无缝拖拽文件。
- 🖥️ **实时诊断控制台**：内置可折叠的底层执行日志终端，实时呈现 `diskutil`、`mount` 与提权执行细节，故障排查一目了然。
- 🧹 **0 残留彻底卸载**：支持界面/命令行一键彻底移除应用本体、偏好设置及 `/usr/local` 下全部驱动与动态库，绝不产生系统垃圾。

---

## 📥 资源下载 (Assets)

| 安装包文件 | 适用架构 | 包含内容 |
| :--- | :--- | :--- |
| **`MacNFTSPro_Installer.pkg`** *(推荐)* | **Universal 通用版**<br>(Apple Silicon & Intel) | MacNFTSPro.app 本体 + FUSE-T + NTFS-3G 离线驱动环境 |

---

## 🚀 快速安装指引

1. 下载 **`MacNFTSPro_Installer.pkg`**；
2. 双击安装包，跟随安装器指引点击“继续”即可完成安装（自动部署应用与底层驱动环境）；
3. 打开“访达” -> “应用程序”，启动 **MacNFTSPro**；
4. 插入您的 NTFS 移动硬盘或 U 盘，在卡片上点击 **【以读写模式挂载】** 即可畅享读写！

---

## ⚠️ macOS 安全拦截放行说明（必读）

> **提示**：由于个人开源项目未购买 Apple 每年 $99 的商业开发者公证证书，首次安装运行可能触发 Gatekeeper 拦截。软件 100% 开源安全无害，请放心放行：

### 1. 双击 PKG 提示“来自未知开发者 / 无法检查恶意软件”
- **便捷放行（推荐）**：在 `MacNFTSPro_Installer.pkg` 上 **右键（或 Control + 单击）** -> 选择 **【打开】** -> 在弹窗中点击 **【打开】/【仍要打开】** 即可。
- **系统设置放行**：前往 Mac **【系统设置】** -> **【隐私与安全性】** -> 滚动到底部安全性区域 -> 点击 **【仍要打开】**。

### 2. 打开 App 提示“已损坏，无法打开。你应该将它移到废纸篓”
macOS 对网络下载文件添加了隔离属性，打开终端执行以下命令即可恢复：
```bash
sudo xattr -rd com.apple.quarantine /Applications/MacNFTSPro.app
```
*(输入锁屏密码回车后即可秒速正常启动)*

---

## 💻 运行环境要求

- **操作系统**：macOS 11.0 (Big Sur) 及以上（完美支持 macOS 13 Ventura / 14 Sonoma / 15 Sequoia）
- **芯片架构**：Apple Silicon (M1/M2/M3/M4 全系列) & Intel 64-bit 处理器

---

## 📄 开源致谢与协议

- 本项目基于 [MIT License](https://github.com/RmondJone/mac_ntfs_pro/blob/main/LICENSE) 开源发布。
- 感谢底层开源组件支持：[FUSE-T](https://github.com/macos-fuse-t/fuse-t) | [NTFS-3G](https://github.com/tuxera/ntfs-3g)
