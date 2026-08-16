import 'dart:developer' as dev;
import '../events/disk_events.dart';
import 'event_bus_utils.dart';

/// 注释：日志打印工具类
/// 时间：2026/08/16 12:20
/// 作者：郭翰林

void loggerDebug(String message) {
  dev.log('🔍 [DEBUG] $message');
}

void loggerInfo(String message) {
  dev.log('ℹ️ [INFO] $message');
  eventBus.fire(LogMessageEvent(message: message, level: 'INFO'));
}

void loggerWarn(String message) {
  dev.log('⚠️ [WARN] $message');
  eventBus.fire(LogMessageEvent(message: message, level: 'WARN'));
}

void loggerError(String message, [dynamic error, StackTrace? stackTrace]) {
  dev.log('❌ [ERROR] $message', error: error, stackTrace: stackTrace);
  eventBus.fire(LogMessageEvent(message: message, level: 'ERROR'));
}
