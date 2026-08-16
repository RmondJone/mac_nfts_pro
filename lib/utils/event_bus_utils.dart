import 'package:event_bus/event_bus.dart';

/// 注释：全局事件总线单例工具类
/// 时间：2026/08/16 12:20
/// 作者：郭翰林
class EventBusUtils {
  static final EventBus _eventBus = EventBus();

  static EventBus get instance => _eventBus;
}

/// 快捷全局访问
final EventBus eventBus = EventBusUtils.instance;
