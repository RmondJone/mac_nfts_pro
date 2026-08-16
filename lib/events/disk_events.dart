library;

/// 注释：磁盘事件定义类
/// 时间：2026/08/16 12:20
/// 作者：郭翰林

/// 磁盘列表刷新完成事件
class DiskRefreshedEvent {
  final int diskCount;
  DiskRefreshedEvent(this.diskCount);
}

/// 系统原生磁盘硬件/挂载变动事件 (插拔/推出/挂载/卸载)
class SystemDiskChangeEvent {
  final String eventType;
  SystemDiskChangeEvent([this.eventType = 'unknown']);
}

/// 磁盘挂载状态变更事件
class DiskMountStatusChangedEvent {
  final String deviceNode;
  final bool isMounted;
  final bool isWritable;
  DiskMountStatusChangedEvent({
    required this.deviceNode,
    required this.isMounted,
    required this.isWritable,
  });
}

/// 环境诊断变更事件
class EnvStatusChangedEvent {
  final bool isReady;
  EnvStatusChangedEvent(this.isReady);
}

/// 日志消息事件
class LogMessageEvent {
  final String message;
  final String level;
  final DateTime timestamp;
  LogMessageEvent({
    required this.message,
    this.level = 'INFO',
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
