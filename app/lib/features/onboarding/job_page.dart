import 'package:flutter/material.dart';
import 'package:app_starter/core/network/api_client.dart';
import 'package:app_starter/core/ui/app_toast.dart';
import 'package:app_starter/features/onboarding/catalog_models.dart';
import 'package:app_starter/features/onboarding/catalog_repository.dart';
import 'package:app_starter/features/onboarding/onboarding_nav.dart';
import 'package:app_starter/features/onboarding/self_assess_page.dart';
import 'package:app_starter/features/onboarding/widgets/onboarding_scaffold.dart';
import 'package:app_starter/features/onboarding/widgets/option_tile_grid.dart';
import 'package:app_starter/features/profile/profile_repository.dart';

class JobPage extends StatefulWidget {
  const JobPage({super.key});

  @override
  State<JobPage> createState() => _JobPageState();
}

class _JobPageState extends State<JobPage> {
  final _catalog = CatalogRepository();
  final _profile = ProfileRepository();
  final _customCtrl = TextEditingController();

  CatalogList? _list;
  String? _selected;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  CatalogItem? get _selectedItem {
    final code = _selected;
    if (code == null || _list == null) return null;
    for (final item in _list!.items) {
      if (item.code == code) return item;
    }
    return null;
  }

  bool get _needsCustom => _selectedItem?.allowCustom == true;

  bool get _canSubmit {
    if (_selected == null || _loading || _error != null) return false;
    if (_needsCustom && _customCtrl.text.trim().isEmpty) return false;
    return true;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _catalog.jobs();
      final profile = await _profile.fetch();
      if (!mounted) return;
      final code = profile.jobCode;
      setState(() {
        _list = list;
        if (code != null && list.items.any((i) => i.code == code)) {
          _selected = code;
        }
        if (profile.jobRaw != null) {
          _customCtrl.text = profile.jobRaw!;
        }
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
        _error = '加载失败，请检查网络';
        _loading = false;
      });
    }
  }

  void _toggle(CatalogItem item) {
    setState(() {
      _selected = item.code;
      if (!item.allowCustom) {
        _customCtrl.clear();
      }
    });
  }

  Future<void> _submit() async {
    if (!_canSubmit || _submitting) return;
    setState(() => _submitting = true);
    try {
      final body = <String, dynamic>{
        'jobCode': _selected,
        'onboardingStep': 'assess',
      };
      if (_needsCustom) {
        body['jobRaw'] = _customCtrl.text.trim();
      } else {
        body['jobRaw'] = null;
      }
      await _profile.patch(body);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const SelfAssessPage()),
      );
    } on ApiException catch (e) {
      if (mounted) AppToast.show(context, e.message);
    } catch (_) {
      if (mounted) AppToast.show(context, '保存失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const Padding(
        padding: EdgeInsets.only(top: 48),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    } else if (_error != null) {
      body = Column(
        children: [
          Text(_error!, style: const TextStyle(color: Color(0xFF64748B))),
          const SizedBox(height: 12),
          TextButton(onPressed: _load, child: const Text('重试')),
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OptionTileGrid(
            items: _list!.items,
            selected: {
              ?_selected,
            },
            onToggle: _toggle,
          ),
          if (_needsCustom) ...[
            const SizedBox(height: 20),
            TextField(
              controller: _customCtrl,
              onChanged: (_) => setState(() {}),
              maxLength: 64,
              decoration: InputDecoration(
                labelText: '你的岗位 / 身份',
                hintText: '例如：跨境电商运营',
                filled: true,
                fillColor: Colors.white,
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF2563EB),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ],
      );
    }

    return OnboardingScaffold(
      title: '你做什么工作？',
      subtitle: '只影响文章岗位语境，不决定词库。',
      body: body,
      ctaLabel: '继续，开始测评',
      ctaEnabled: _canSubmit,
      submitting: _submitting,
      onCta: _submit,
      onBack: () => onboardingBack(context, fallback: jobFallback()),
    );
  }
}
