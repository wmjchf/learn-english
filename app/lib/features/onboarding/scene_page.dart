import 'package:flutter/material.dart';
import 'package:app_starter/core/network/api_client.dart';
import 'package:app_starter/core/ui/app_toast.dart';
import 'package:app_starter/features/onboarding/catalog_models.dart';
import 'package:app_starter/features/onboarding/catalog_repository.dart';
import 'package:app_starter/features/onboarding/job_page.dart';
import 'package:app_starter/features/onboarding/onboarding_nav.dart';
import 'package:app_starter/features/onboarding/widgets/onboarding_scaffold.dart';
import 'package:app_starter/features/onboarding/widgets/option_tile_grid.dart';
import 'package:app_starter/features/profile/profile_repository.dart';

class ScenePage extends StatefulWidget {
  const ScenePage({super.key});

  @override
  State<ScenePage> createState() => _ScenePageState();
}

class _ScenePageState extends State<ScenePage> {
  final _catalog = CatalogRepository();
  final _profile = ProfileRepository();
  final _customCtrl = TextEditingController();

  CatalogList? _list;
  final Set<String> _selected = {};
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

  bool get _needsCustom {
    final list = _list;
    if (list == null) return false;
    return _selected.any(
      (c) => list.items.any((i) => i.code == c && i.allowCustom),
    );
  }

  bool get _canSubmit {
    if (_selected.isEmpty || _loading || _error != null) return false;
    if (_needsCustom && _customCtrl.text.trim().isEmpty) return false;
    return true;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _catalog.scenes();
      final profile = await _profile.fetch();
      if (!mounted) return;
      setState(() {
        _list = list;
        _selected
          ..clear()
          ..addAll(profile.scenes.where(
            (c) => list.items.any((i) => i.code == c),
          ));
        if (profile.sceneRaw != null) {
          _customCtrl.text = profile.sceneRaw!;
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
    final max = _list?.maxSelect ?? 3;
    setState(() {
      if (_selected.contains(item.code)) {
        _selected.remove(item.code);
        if (item.allowCustom) _customCtrl.clear();
      } else if (_selected.length < max) {
        _selected.add(item.code);
      } else {
        AppToast.show(context, '最多选 $max 个');
      }
    });
  }

  Future<void> _submit() async {
    if (!_canSubmit || _submitting) return;
    setState(() => _submitting = true);
    try {
      await _profile.patch({
        'scenes': _selected.toList(),
        'sceneRaw': _needsCustom ? _customCtrl.text.trim() : null,
        'onboardingStep': 'job',
      });
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const JobPage()),
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
    final max = _list?.maxSelect ?? 3;
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
            selected: _selected,
            onToggle: _toggle,
          ),
          if (_selected.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              '已选 ${_selected.length} / $max',
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
          if (_needsCustom) ...[
            const SizedBox(height: 20),
            TextField(
              controller: _customCtrl,
              onChanged: (_) => setState(() {}),
              maxLength: 64,
              decoration: InputDecoration(
                labelText: '你的具体场景',
                hintText: '例如：海关报关、病房交接',
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
      title: '你最常在哪用英语？',
      subtitle: '最多 $max 个。文章场景从这里取。',
      body: body,
      ctaLabel: '继续',
      ctaEnabled: _canSubmit,
      submitting: _submitting,
      onCta: _submit,
      onBack: () => onboardingBack(context, fallback: sceneFallback()),
    );
  }
}
