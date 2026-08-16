import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../defines/ly_colors.dart';
import 'logger_utils.dart';

/// 注释：通用工具类
/// 时间：2026/08/16 12:20
/// 作者：郭翰林
class LyUtils {
  /// 注释：显示全局 Toast / 通知提示
  /// 时间：2026/08/16 12:20
  /// 作者：郭翰林
  static void showToast(String message, {bool isError = false}) {
    if (Get.context == null) return;
    Get.rawSnackbar(
      messageText: Text(
        message,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      snackPosition: SnackPosition.TOP,
      backgroundColor: isError ? LyColors.error : const Color(0xFF323232),
      borderRadius: 8,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      duration: const Duration(seconds: 3),
      animationDuration: const Duration(milliseconds: 250),
      forwardAnimationCurve: Curves.easeOutCubic,
      isDismissible: true,
      icon: Icon(
        isError ? Icons.error_outline : Icons.check_circle_outline,
        color: Colors.white,
        size: 18,
      ),
    );
  }

  /// 注释：格式化字节大小为可读字符串
  /// 时间：2026/08/16 12:20
  /// 作者：郭翰林
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
    var i = 0;
    double num = bytes.toDouble();
    while (num >= 1024 && i < suffixes.length - 1) {
      num /= 1024;
      i++;
    }
    return '${num.toStringAsFixed(num < 10 && i > 0 ? 2 : 1)} ${suffixes[i]}';
  }

  /// 注释：在访达中打开指定目录或磁盘
  /// 时间：2026/08/16 12:20
  /// 作者：郭翰林
  static Future<bool> openInFinder(String path) async {
    try {
      if (path.isEmpty) return false;
      final result = await Process.run('open', [path]);
      if (result.exitCode == 0) {
        loggerInfo('成功在访达中打开: $path');
        return true;
      } else {
        loggerError('访达打开失败: ${result.stderr}');
        return false;
      }
    } catch (e) {
      loggerError('调用 open 命令异常: $e');
      return false;
    }
  }

  /// 注释：以普通权限执行 Shell 命令
  /// 时间：2026/08/16 12:20
  /// 作者：郭翰林
  static Future<ProcessResult> runCommand(
    String executable,
    List<String> arguments,
  ) async {
    try {
      return await Process.run(executable, arguments);
    } catch (e) {
      loggerError('执行命令异常 [$executable ${arguments.join(' ')}]: $e');
      rethrow;
    }
  }

  /// 注释：通过 macOS 提权执行管理员脚本 (弹窗授权)
  /// 时间：2026/08/16 12:20
  /// 作者：郭翰林
  static Future<ProcessResult> runPrivilegedScript(String shellScript) async {
    try {
      loggerInfo('正在请求管理员权限执行脚本...');
      // 严格转义双引号和反斜杠
      final escapedScript =
          shellScript.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
      final appleScript = 'do shell script "$escapedScript" with administrator privileges';
      final result = await Process.run('osascript', ['-e', appleScript]);
      return result;
    } catch (e) {
      loggerError('提权执行脚本异常: $e');
      rethrow;
    }
  }
}
