import 'package:flutter/material.dart';
import 'package:app_starter/core/config/app_brand.dart';
import 'package:app_starter/features/auth/auth_repository.dart';
import 'package:app_starter/features/auth/login_page.dart';

/// 登录后的空壳首页。在此扩展业务模块。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _auth = AuthRepository();
  AuthSession? _session;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await _auth.readSession();
    if (mounted) setState(() => _session = s);
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final nickname = _session?.nickname ?? '';
    final phone = _session?.phone ?? '';
    return Scaffold(
      appBar: AppBar(
        title: Text(AppBrand.name),
        actions: [
          TextButton(onPressed: _logout, child: const Text('退出')),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '你好${nickname.isEmpty ? '' : '，$nickname'}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                phone.isEmpty ? '已登录' : phone,
                style: const TextStyle(color: Color(0xFF737A85)),
              ),
              const SizedBox(height: 24),
              const Text(
                '这是空壳首页。在 lib/features/ 下加业务模块即可。',
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
