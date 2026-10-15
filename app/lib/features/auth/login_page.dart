import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_starter/core/config/app_brand.dart';
import 'package:app_starter/core/network/api_client.dart';
import 'package:app_starter/core/ui/app_toast.dart';
import 'package:app_starter/features/auth/auth_repository.dart';
import 'package:app_starter/features/shell/home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.authRepository});

  final AuthRepository? authRepository;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const _bg = Color(0xFFF7F7FA);
  static const _text = Color(0xFF1F242E);
  static const _muted = Color(0xFF737A85);
  static const _blue = Color(0xFF2F6FED);

  late final AuthRepository _auth =
      widget.authRepository ?? AuthRepository();

  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  bool _sending = false;
  bool _loggingIn = false;
  int _countdown = 0;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  bool _isValidPhone(String phone) => RegExp(r'^1\d{10}$').hasMatch(phone);

  void _toast(String message) {
    if (!mounted) return;
    AppToast.show(context, message);
  }

  Future<void> _onSendCode() async {
    final phone = _phoneController.text.trim();
    if (!_isValidPhone(phone)) {
      _toast('请输入正确的手机号');
      return;
    }
    if (_sending || _countdown > 0) return;

    setState(() => _sending = true);
    try {
      await _auth.sendCode(phone);
      _toast('验证码已发送（开发模式默认 123456）');
      _startCountdown();
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('发送失败，请检查网络或后端是否启动');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startCountdown() {
    setState(() => _countdown = 60);
    Future.doWhile(() async {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _countdown -= 1);
      return _countdown > 0;
    });
  }

  Future<void> _onLogin() async {
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();
    if (!_isValidPhone(phone)) {
      _toast('请输入正确的手机号');
      return;
    }
    if (code.isEmpty) {
      _toast('请输入验证码');
      return;
    }
    if (_loggingIn) return;

    setState(() => _loggingIn = true);
    try {
      await _auth.login(phone: phone, code: code);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const HomePage()),
        (_) => false,
      );
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('登录失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _loggingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppBrand.name,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: _text,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '手机号验证码登录',
                style: TextStyle(fontSize: 15, color: _muted),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                ],
                decoration: const InputDecoration(
                  labelText: '手机号',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      decoration: const InputDecoration(
                        labelText: '验证码',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _countdown > 0 || _sending ? null : _onSendCode,
                      child: Text(
                        _countdown > 0 ? '${_countdown}s' : '获取验证码',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: _loggingIn ? null : _onLogin,
                  style: FilledButton.styleFrom(backgroundColor: _blue),
                  child: Text(_loggingIn ? '登录中…' : '登录'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
