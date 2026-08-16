import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../defines/ly_colors.dart';
import '../../defines/ly_constants.dart';
import '../../defines/ly_fonts.dart';
import '../../widgets/ly_input.dart';
import 'controllers/home_controller.dart';
import 'views/disk_item_card.dart';
import 'views/empty_disk_view.dart';
import 'views/env_status_banner.dart';
import 'views/log_console_view.dart';

/// 注释：MacNTFS Pro 首页管理界面
/// 时间：2026/08/16 12:20
/// 作者：郭翰林
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final HomeController pageController;
  final TextEditingController searchEditingController = TextEditingController();

  @override
  void initState() {
    super.initState();
    pageController = Get.put(HomeController());
  }

  @override
  void dispose() {
    searchEditingController.dispose();
    Get.delete<HomeController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? LyColors.bgDark : LyColors.bgLight,
      body: SafeArea(
        child: Column(
          children: [
            renderTopToolbar(context, isDark),
            Obx(
              () => EnvStatusBanner(
                env: pageController.envStatus.value,
                isInstalling: pageController.isInstallingDriver.value,
                onInstallDrivers: pageController.handleInstallDrivers,
                onRefresh: pageController.refreshEnvironment,
              ),
            ),
            Expanded(child: renderDiskContent(context, isDark)),
            Obx(() {
              if (!pageController.showLogConsole.value) {
                return const SizedBox.shrink();
              }
              return LogConsoleView(
                logs: pageController.logList,
                onClear: pageController.clearLogs,
                onClose: () => pageController.showLogConsole.value = false,
              );
            }),
            renderBottomStatusBar(context, isDark),
          ],
        ),
      ),
    );
  }

  /// 注释：绘制顶部工具栏与搜索过滤
  /// 时间：2026/08/16 12:20
  /// 作者：郭翰林
  Widget renderTopToolbar(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? LyColors.cardDark : LyColors.cardLight,
        border: Border(
          bottom: BorderSide(
            color: isDark ? LyColors.borderDark : LyColors.borderLight,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: LyColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.disc_full_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    LyConstants.appName,
                    style: LyFonts.titleMedium.copyWith(
                      color: isDark
                          ? LyColors.textPrimaryDark
                          : LyColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: LyColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'v${LyConstants.appVersion}',
                      style: TextStyle(
                        fontSize: 10,
                        color: LyColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                LyConstants.appDesc,
                style: LyFonts.bodySmall.copyWith(
                  color: isDark
                      ? LyColors.textSecondaryDark
                      : LyColors.textSecondaryLight,
                ),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: 180,
            child: LyInput(
              controller: searchEditingController,
              hintText: '搜索磁盘/格式...',
              prefixIcon: const Icon(Icons.search, size: 16),
              onChanged: (val) => pageController.searchKeyword.value = val,
            ),
          ),
          const SizedBox(width: 10),
          Obx(
            () => FilterChip(
              label: const Text('仅显示 NTFS', style: TextStyle(fontSize: 12)),
              selected: pageController.onlyShowNTFS.value,
              onSelected: (val) => pageController.onlyShowNTFS.value = val,
              selectedColor: LyColors.primary.withValues(alpha: 0.2),
              checkmarkColor: LyColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Obx(
            () => IconButton(
              tooltip: '刷新磁盘列表',
              icon: pageController.isLoadingDisks.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 20),
              onPressed: () => pageController.refreshDisks(),
            ),
          ),
          IconButton(
            tooltip: '切换日志面板',
            icon: const Icon(Icons.terminal_rounded, size: 20),
            onPressed: () => pageController.showLogConsole.toggle(),
          ),
        ],
      ),
    );
  }

  /// 注释：绘制磁盘列表内容
  /// 时间：2026/08/16 12:20
  /// 作者：郭翰林
  Widget renderDiskContent(BuildContext context, bool isDark) {
    return Obx(() {
      if (pageController.isLoadingDisks.value &&
          pageController.diskList.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      final disks = pageController.filteredDisks;
      if (disks.isEmpty) {
        return EmptyDiskView(
          onRefresh: () => pageController.refreshDisks(),
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: disks.length,
        itemBuilder: (context, index) {
          final disk = disks[index];
          return DiskItemCard(
            disk: disk,
            isMounting:
                pageController.mountingDiskNode.value == disk.deviceNode,
            onMountReadWrite: () => pageController.handleMountReadWrite(disk),
            onUnmount: () => pageController.handleUnmount(disk),
            onEject: () => pageController.handleEject(disk),
            onOpenFinder: () => pageController.handleOpenFinder(disk),
          );
        },
      );
    });
  }

  /// 注释：绘制底部状态栏
  /// 时间：2026/08/16 12:20
  /// 作者：郭翰林
  Widget renderBottomStatusBar(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? LyColors.cardDark : LyColors.cardLight,
        border: Border(
          top: BorderSide(
            color: isDark ? LyColors.borderDark : LyColors.borderLight,
            width: 1,
          ),
        ),
      ),
      child: Obx(
        () => Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: pageController.envStatus.value?.canWriteNtfs == true
                    ? LyColors.success
                    : LyColors.warning,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '已扫描 ${pageController.diskList.length} 个存储分区 (NTFS: ${pageController.diskList.where((d) => d.isNTFS).length})',
              style: LyFonts.bodySmall.copyWith(
                color: isDark
                    ? LyColors.textSecondaryDark
                    : LyColors.textSecondaryLight,
              ),
            ),
            const Spacer(),
            Text(
              '作者: ${LyConstants.appAuthor}',
              style: LyFonts.bodySmall.copyWith(
                color: isDark
                    ? LyColors.textSecondaryDark
                    : LyColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
