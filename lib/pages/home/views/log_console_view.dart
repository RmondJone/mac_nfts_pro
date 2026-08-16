import 'package:flutter/material.dart';
import '../../../events/disk_events.dart';

/// 注释：操作日志控制台组件
/// 时间：2026/08/16 12:20
/// 作者：郭翰林
class LogConsoleView extends StatelessWidget {
  final List<LogMessageEvent> logs;
  final VoidCallback onClear;
  final VoidCallback onClose;

  const LogConsoleView({
    super.key,
    required this.logs,
    required this.onClear,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        border: Border(top: BorderSide(color: Color(0xFF38383A), width: 1)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: const Color(0xFF252526),
            child: Row(
              children: [
                const Icon(Icons.terminal_rounded, size: 14, color: Colors.white70),
                const SizedBox(width: 8),
                const Text(
                  '挂载与驱动执行日志',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: onClear,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      '清空',
                      style: TextStyle(fontSize: 11, color: Colors.white54),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: onClose,
                  child: const Icon(Icons.close, size: 14, color: Colors.white54),
                ),
              ],
            ),
          ),
          Expanded(
            child: logs.isEmpty
                ? const Center(
                    child: Text(
                      '暂无日志记录',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final item = logs[index];
                      Color tagColor = Colors.greenAccent;
                      if (item.level == 'WARN') tagColor = Colors.orangeAccent;
                      if (item.level == 'ERROR') tagColor = Colors.redAccent;

                      final timeStr =
                          '${item.timestamp.hour.toString().padLeft(2, '0')}:${item.timestamp.minute.toString().padLeft(2, '0')}:${item.timestamp.second.toString().padLeft(2, '0')}';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: SelectableText.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '[$timeStr] ',
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                  fontFamily: 'Menlo',
                                ),
                              ),
                              TextSpan(
                                text: '[${item.level}] ',
                                style: TextStyle(
                                  color: tagColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Menlo',
                                ),
                              ),
                              TextSpan(
                                text: item.message,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontFamily: 'Menlo',
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
