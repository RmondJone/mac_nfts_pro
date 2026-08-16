import 'dart:async';
import 'dart:io';
import 'package:get/get.dart';
import '../../../events/disk_events.dart';
import '../../../utils/disk_engine_utils.dart';
import '../../../utils/env_engine_utils.dart';
import '../../../utils/event_bus_utils.dart';
import '../../../utils/logger_utils.dart';
import '../../../utils/ly_utils.dart';
import '../models/disk_item_model.dart';
import '../models/env_status_model.dart';

/// 注释：首页磁盘管理控制器
/// 时间：2026/08/16 12:20
/// 作者：郭翰林
class HomeController extends GetxController {
  // 磁盘列表与加载状态
  final RxList<DiskItemModel> diskList = <DiskItemModel>[].obs;
  final RxBool isLoadingDisks = false.obs;
  final RxString mountingDiskNode = ''.obs;

  // 驱动与环境状态
  final Rx<EnvStatusModel?> envStatus = Rx<EnvStatusModel?>(null);
  final RxBool isInstallingDriver = false.obs;

  // 搜索与过滤
  final RxString searchKeyword = ''.obs;

  // 控制台日志列表
  final RxList<LogMessageEvent> logList = <LogMessageEvent>[].obs;
  final RxBool showLogConsole = false.obs;

  // 定时与事件订阅
  Timer? _pollingTimer;
  StreamSubscription<LogMessageEvent>? _logSubscription;

  @override
  void onInit() {
    super.onInit();
    _initSubscriptions();
    refreshAll();
    _startPolling();
  }

  @override
  void onClose() {
    _pollingTimer?.cancel();
    _logSubscription?.cancel();
    super.onClose();
  }

  /// 注释：初始化事件监听
  /// 时间：2026/08/16 12:20
  /// 作者：郭翰林
  void _initSubscriptions() {
    _logSubscription = eventBus.on<LogMessageEvent>().listen((event) {
      logList.insert(0, event);
      if (logList.length > 200) {
        logList.removeLast();
      }
    });
  }

  /// 注释：开启磁盘状态周期轮询
  /// 时间：2026/08/16 12:20
  /// 作者：郭翰林
  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (mountingDiskNode.isEmpty && !isInstallingDriver.value) {
        refreshDisks(silent: true);
      }
    });
  }

  /// 注释：一键全量刷新
  /// 时间：2026/08/16 12:20
  /// 作者：郭翰林
  Future<void> refreshAll() async {
    await refreshEnvironment();
    await refreshDisks();
  }

  /// 注释：刷新环境状态
  /// 时间：2026/08/16 12:20
  /// 作者：郭翰林
  Future<void> refreshEnvironment() async {
    final status = await EnvEngineUtils.checkEnvironment();
    envStatus.value = status;
  }

  /// 注释：刷新磁盘列表
  /// 时间：2026/08/16 12:20
  /// 作者：郭翰林
  Future<void> refreshDisks({bool silent = false}) async {
    if (!silent) {
      isLoadingDisks.value = true;
    }
    try {
      final list = await DiskEngineUtils.scanDisks();
      diskList.assignAll(list);
      eventBus.fire(DiskRefreshedEvent(list.length));
    } catch (e) {
      loggerError('刷新磁盘列表失败: $e');
    } finally {
      if (!silent) {
        isLoadingDisks.value = false;
      }
    }
  }

  /// 注释：获取经过过滤后的磁盘列表 (仅展示当前已挂载的 NTFS 格式磁盘)
  /// 时间：2026/08/16 18:38
  /// 作者：郭翰林
  List<DiskItemModel> get filteredDisks {
    return diskList.where((d) {
      // 1. 过滤非 NTFS 磁盘
      if (!d.isNTFS) {
        return false;
      }
      // 2. 过滤未挂载的磁盘 (仅展示当前已挂载的分区)
      if (!d.isMounted) {
        return false;
      }
      // 3. 搜索关键词过滤
      if (searchKeyword.value.trim().isNotEmpty) {
        final kw = searchKeyword.value.toLowerCase().trim();
        final matchName = d.volumeName.toLowerCase().contains(kw);
        final matchDev = d.deviceIdentifier.toLowerCase().contains(kw);
        final matchFs = d.filesystemName.toLowerCase().contains(kw);
        if (!matchName && !matchDev && !matchFs) return false;
      }
      return true;
    }).toList();
  }

  /// 注释：一键以读写模式挂载指定磁盘
  /// 时间：2026/08/16 12:20
  /// 作者：郭翰林
  Future<void> handleMountReadWrite(DiskItemModel disk) async {
    final env = envStatus.value;
    if (env == null) {
      LyUtils.showToast('环境信息未准备就绪，请稍后', isError: true);
      return;
    }

    mountingDiskNode.value = disk.deviceNode;
    try {
      final success = await DiskEngineUtils.mountReadWrite(disk, env);
      if (success) {
        await refreshDisks(silent: true);
      }
    } finally {
      mountingDiskNode.value = '';
    }
  }

  /// 注释：卸载指定磁盘 (恢复原生只读挂载状态)
  /// 时间：2026/08/16 18:35
  /// 作者：郭翰林
  Future<void> handleUnmount(DiskItemModel disk) async {
    final success = await DiskEngineUtils.unmountDisk(disk);
    if (success) {
      await Future.delayed(const Duration(milliseconds: 300));
      await refreshDisks(silent: true);
    }
  }

  /// 注释：安全推出指定物理磁盘 (硬件级安全断开)
  /// 时间：2026/08/16 18:35
  /// 作者：郭翰林
  Future<void> handleEject(DiskItemModel disk) async {
    final success = await DiskEngineUtils.ejectDisk(disk);
    if (success) {
      diskList.removeWhere(
        (d) =>
            d.deviceIdentifier == disk.deviceIdentifier ||
            (disk.parentDisk.isNotEmpty && d.parentDisk == disk.parentDisk),
      );
      await Future.delayed(const Duration(milliseconds: 300));
      await refreshDisks(silent: true);
    }
  }

  /// 注释：在访达中打开磁盘
  /// 时间：2026/08/16 12:20
  /// 作者：郭翰林
  void handleOpenFinder(DiskItemModel disk) {
    if (disk.mountPoint.isNotEmpty) {
      LyUtils.openInFinder(disk.mountPoint);
    } else {
      LyUtils.showToast('该磁盘尚未挂载，请先挂载', isError: true);
    }
  }

  /// 注释：一键安装/配置推荐驱动
  /// 时间：2026/08/16 16:30
  /// 作者：郭翰林
  Future<void> handleInstallDrivers() async {
    isInstallingDriver.value = true;
    try {
      loggerInfo('准备执行一键离线驱动部署...');
      final script = EnvEngineUtils.getOfflineInstallScript();
      if (script == null) {
        loggerError('未找到 App 内置的离线驱动资源包');
        LyUtils.showToast('未找到内置离线驱动包，请重新安装或检查安装包', isError: true);
        return;
      }

      loggerInfo('开始请求管理员权限执行离线驱动静默安装...');
      final result = await LyUtils.runPrivilegedScript(script);
      if (result.exitCode == 0) {
        loggerInfo('🎉 FUSE-T 与 NTFS-3G 驱动离线部署成功！');
        LyUtils.showToast('驱动环境已就绪，已支持 NTFS 读写！');
        await refreshEnvironment();
      } else {
        loggerError('驱动安装执行失败: ${result.stderr} ${result.stdout}');
        LyUtils.showToast('驱动安装失败: ${result.stderr}', isError: true);
      }
    } catch (e) {
      loggerError('一键驱动安装异常: $e');
      LyUtils.showToast('驱动配置异常: $e', isError: true);
    } finally {
      isInstallingDriver.value = false;
    }
  }

  /// 注释：一键彻底卸载 App 本体与全部系统底层驱动依赖
  /// 时间：2026/08/16 17:35
  /// 作者：郭翰林
  Future<void> handleUninstallApp() async {
    try {
      loggerInfo('准备执行一键彻底卸载与系统底层清理...');
      final script = EnvEngineUtils.getUninstallScript();
      final result = await LyUtils.runPrivilegedScript(script);

      if (result.exitCode == 0) {
        loggerInfo('🎉 系统底层驱动与 MacNTFS Pro 清理完毕，正在退出...');
        LyUtils.showToast('卸载清理成功，应用将在 1 秒后自动退出');
        await Future.delayed(const Duration(milliseconds: 1000));
        exit(0);
      } else {
        loggerError('卸载执行失败: ${result.stderr}');
        LyUtils.showToast('卸载失败: ${result.stderr}', isError: true);
      }
    } catch (e) {
      loggerError('卸载异常: $e');
      LyUtils.showToast('卸载异常: $e', isError: true);
    }
  }

  /// 注释：清空日志
  /// 时间：2026/08/16 12:20
  /// 作者：郭翰林
  void clearLogs() {
    logList.clear();
  }
}
