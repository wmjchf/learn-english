import 'package:flutter/material.dart';

/// 全屏遮罩（盖住状态栏 + 底栏），用于生成中等阻塞操作。
class BlockingOverlay {
  BlockingOverlay._();

  static const barrierColor = Color(0x66000000);

  /// 弹出遮罩并执行 [task]，结束或失败后自动关闭。
  static Future<T?> run<T>(
    BuildContext context, {
    required Future<T> Function() task,
    Widget? child,
  }) async {
    final nav = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierColor: barrierColor,
      builder: (ctx) {
        return PopScope(
          canPop: false,
          child: Material(
            type: MaterialType.transparency,
            child: Center(child: child ?? const SizedBox.shrink()),
          ),
        );
      },
    );
    try {
      return await task();
    } finally {
      if (nav.canPop()) {
        nav.pop();
      }
    }
  }
}
