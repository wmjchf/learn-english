import 'package:flutter/material.dart';
import 'package:app_starter/core/network/api_client.dart';
import 'package:app_starter/core/ui/app_toast.dart';
import 'package:app_starter/features/onboarding/bank_models.dart';
import 'package:app_starter/features/onboarding/bank_repository.dart';
import 'package:app_starter/features/onboarding/demo_lesson_placeholder_page.dart';
import 'package:app_starter/features/onboarding/plan_setup_page.dart';

/// ⑦ 选词库：扁平列表，与职业无关；可先看 Demo。
class BankSelectPage extends StatefulWidget {
  const BankSelectPage({super.key});

  @override
  State<BankSelectPage> createState() => _BankSelectPageState();
}

class _BankSelectPageState extends State<BankSelectPage> {
  static const _bg = Color(0xFFF8FAFC);
  static const _blue = Color(0xFF2563EB);
  static const _blueSoft = Color(0xFFEFF6FF);
  static const _blueDeep = Color(0xFF1D4ED8);
  static const _blueMid = Color(0xFF3B82F6);
  static const _text = Color(0xFF0F172A);
  static const _title = Color(0xFF17202E);
  static const _muted = Color(0xFF8A94A6);
  static const _border = Color(0xFFE2E8F0);
  static const _demoBorder = Color(0xFFCBD5E1);

  final _repo = BankRepository();

  List<WordBank> _items = const [];
  int? _selectedId;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repo.list();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '加载词库失败，请检查网络';
        _loading = false;
      });
    }
  }

  Future<void> _onSelect(WordBank bank) async {
    if (_submitting) return;
    setState(() {
      _selectedId = bank.id;
      _submitting = true;
    });
    try {
      await _repo.select(bank.id);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const PlanSetupPage()),
        (_) => false,
      );
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        AppToast.show(context, e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        AppToast.show(context, '保存失败，请稍后重试');
      }
    }
  }

  void _onDemo() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const DemoLessonPlaceholderPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: _blue, size: 32),
          onPressed: _submitting
              ? null
              : () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '这次学哪套词？',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _title,
                  height: 31 / 22,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '与职业无关，按学习目标自选。',
                style: TextStyle(
                  fontSize: 13,
                  color: _muted,
                  height: 18 / 13,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(child: _buildList()),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _submitting ? null : _onDemo,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _text,
                  side: const BorderSide(color: _demoBorder),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '先看一篇 Demo',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null) {
      return Column(
        children: [
          Text(_error!, style: const TextStyle(color: _muted)),
          TextButton(onPressed: _load, child: const Text('重试')),
        ],
      );
    }
    if (_items.isEmpty) {
      return const Text('暂无词库', style: TextStyle(color: _muted));
    }

    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final bank = _items[index];
        final active = _selectedId == bank.id;
        return Material(
          color: active ? _blueSoft : Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: _submitting ? null : () => _onSelect(bank),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: active ? _blue : _border,
                  width: active ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bank.title,
                    style: TextStyle(
                      fontSize: active ? 18 : 15,
                      fontWeight: FontWeight.w700,
                      color: active ? _blueDeep : _text,
                      height: active ? 25 / 18 : 21 / 15,
                    ),
                  ),
                  if (bank.subtitle != null && bank.subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      bank.subtitle!,
                      style: TextStyle(
                        fontSize: active ? 13 : 12,
                        color: active ? _blueMid : const Color(0xFF64748B),
                        height: active ? 18 / 13 : 17 / 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
