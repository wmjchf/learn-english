import 'package:flutter/material.dart';

/// 根导航，供登录过期时跳转登录页。
abstract final class AppNavigator {
  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();

  static void showSnackBar(String message) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(message)));
  }
}
