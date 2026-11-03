import 'dart:async';

import 'package:flutter/material.dart';
import 'package:app_starter/core/config/app_brand.dart';
import 'package:app_starter/core/network/api_client.dart';
import 'package:app_starter/core/theme/app_colors.dart';
import 'package:app_starter/features/auth/auth_repository.dart';
import 'package:app_starter/features/onboarding/guide_page.dart';
import 'package:app_starter/features/onboarding/onboarding_nav.dart';
import 'package:app_starter/features/profile/profile_repository.dart';
import 'package:app_starter/features/shell/app_navigator.dart';
import 'package:app_starter/features/shell/main_shell.dart';

class AppStarterApp extends StatelessWidget {
  const AppStarterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppBrand.name,
      navigatorKey: AppNavigator.key,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.accent,
        ),
        scaffoldBackgroundColor: AppColors.bg,
        useMaterial3: true,
      ),
      home: const _AuthGate(),
    );
  }
}

/// 冷启动闸门：对齐 collection-app。
/// 原生启动页盖到 [allowFirstFrame]；首帧直接是真实首页，不另画 Flutter Logo 页。
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  Widget? _home;

  @override
  void initState() {
    super.initState();
    unawaited(_boot());
  }

  Future<void> _boot() async {
    await ApiClient.warmup();
    final home = await _resolveHome();
    if (!mounted) return;
    setState(() => _home = home);
    // 先挂好首页再放行，避免首帧落到空白占位
    WidgetsBinding.instance.allowFirstFrame();
  }

  Future<Widget> _resolveHome() async {
    final session = await AuthRepository().readSession();
    if (session == null) return const GuidePage();
    try {
      final profile = await ProfileRepository().fetchMe();
      if (profile.isOnboardingDone) return const MainShell();
      return pageForOnboardingStep(profile.onboardingStep);
    } catch (_) {
      return pageForOnboardingStep('interest');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 理论上 allowFirstFrame 前不会画到这里；颜色与原生启动底一致兜底
    return _home ?? const ColoredBox(color: AppColors.primarySoft);
  }
}
