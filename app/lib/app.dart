import 'package:flutter/material.dart';
import 'package:app_starter/core/config/app_brand.dart';
import 'package:app_starter/core/network/api_client.dart';
import 'package:app_starter/features/auth/auth_repository.dart';
import 'package:app_starter/features/auth/login_page.dart';
import 'package:app_starter/features/shell/app_navigator.dart';
import 'package:app_starter/features/shell/home_page.dart';

class AppStarterApp extends StatelessWidget {
  const AppStarterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppBrand.name,
      navigatorKey: AppNavigator.key,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F6FED)),
        useMaterial3: true,
      ),
      home: const _BootPage(),
    );
  }
}

class _BootPage extends StatefulWidget {
  const _BootPage();

  @override
  State<_BootPage> createState() => _BootPageState();
}

class _BootPageState extends State<_BootPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    await ApiClient.warmup();
    final session = await AuthRepository().readSession();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) =>
            session == null ? const LoginPage() : const HomePage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}
