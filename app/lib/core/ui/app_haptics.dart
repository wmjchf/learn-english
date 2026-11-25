import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// App 内触感（对齐 collection-app / 多邻国手感）。
///
/// iOS 走 AudioToolbox Taptic（1519/1520/1521），**不依赖**「设置 → 声音与触感 →
/// 系统触感反馈」；与 Flutter `HapticFeedback` / UIKit FeedbackGenerator 手感不同。
class AppHaptics {
  AppHaptics._();

  static const _channel = MethodChannel('wordx/haptics');

  /// 轻点 / 普通按钮
  static Future<void> tap() => _play('light');

  /// 选中 Tab / 选项卡等
  static Future<void> select() => _play('medium');

  static Future<void> _play(String style) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>('taptic', {'style': style});
    } catch (_) {
      if (style == 'medium') {
        await HapticFeedback.mediumImpact();
      } else {
        await HapticFeedback.selectionClick();
      }
    }
  }
}

/// 给 [onPressed] / [onTap] 包一层触感；[callback] 为 null 时保持禁用。
VoidCallback? withHaptic(
  FutureOr<void> Function()? callback, {
  bool select = false,
}) {
  if (callback == null) return null;
  return () {
    if (select) {
      unawaited(AppHaptics.select());
    } else {
      unawaited(AppHaptics.tap());
    }
    callback();
  };
}
