import 'package:flutter/material.dart';
import 'package:app_starter/core/network/api_client.dart';
import 'package:app_starter/core/ui/app_toast.dart';
import 'package:app_starter/features/onboarding/bank_models.dart';
import 'package:app_starter/features/onboarding/bank_repository.dart';
import 'package:app_starter/features/onboarding/catalog_models.dart';
import 'package:app_starter/features/onboarding/catalog_repository.dart';
import 'package:app_starter/features/onboarding/plan_models.dart';
import 'package:app_starter/features/onboarding/plan_repository.dart';
import 'package:app_starter/features/onboarding/self_assess_page.dart';
import 'package:app_starter/features/onboarding/widgets/option_tile_grid.dart';
import 'package:app_starter/features/profile/me_models.dart';
import 'package:app_starter/features/profile/me_repository.dart';
import 'package:app_starter/features/profile/profile_repository.dart';
import 'package:app_starter/features/profile/user_profile.dart';

/// 编辑画像：对齐 Figma Phone/画像。
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, this.hero});

  final MeHero? hero;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _profileRepo = ProfileRepository();
  final _meRepo = MeRepository();
  final _catalog = CatalogRepository();
  final _banks = BankRepository();
  final _plans = PlanRepository();

  UserProfile? _profile;
  CatalogList? _interests;
  CatalogList? _scenes;
  CatalogList? _jobs;
  List<WordBank> _bankList = const [];
  WordBank? _bank;
  bool _loading = true;
  bool _busy = false;
  bool _changed = false;
  String? _error;

  static const _bg = Color(0xFFF8FAFC);
  static const _text = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _meta = Color(0xFF94A3B8);
  static const _blue = Color(0xFF2563EB);
  static const _blueSoft = Color(0xFFEFF6FF);
  static const _blueDeep = Color(0xFF1E3A8A);
  static const _blueMid = Color(0xFF3B82F6);
  static const _border = Color(0xFFE2E8F0);
  static const _divider = Color(0xFFF1F5F9);
  static const _chevron = Color(0xFFCBD5E1);
  static const _levels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
  static const _minuteOptions = [10, 15, 20, 30, 45, 60];

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
      final results = await Future.wait([
        _profileRepo.fetch(),
        _catalog.interests(),
        _catalog.scenes(),
        _catalog.jobs(),
        _banks.list(),
      ]);
      if (!mounted) return;
      final profile = results[0] as UserProfile;
      final banks = results[4] as List<WordBank>;
      WordBank? bank;
      if (profile.primaryBankId != null) {
        for (final b in banks) {
          if (b.id == profile.primaryBankId) {
            bank = b;
            break;
          }
        }
      }
      setState(() {
        _profile = profile;
        _interests = results[1] as CatalogList;
        _scenes = results[2] as CatalogList;
        _jobs = results[3] as CatalogList;
        _bankList = banks;
        _bank = bank;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : '加载失败';
      });
    }
  }

  String get _ability =>
      _profile?.abilityLevel ?? widget.hero?.abilityLevel ?? '—';
  String get _generation =>
      _profile?.generationLevel ??
      widget.hero?.generationLevel ??
      _ability;

  String _labels(
    List<String> codes,
    CatalogList? list, {
    String empty = '未选',
    String? customRaw,
  }) {
    if (codes.isEmpty || list == null) return empty;
    final map = {for (final i in list.items) i.code: i};
    final labels = <String>[];
    for (final c in codes) {
      final item = map[c];
      if (item != null &&
          item.allowCustom &&
          customRaw != null &&
          customRaw.trim().isNotEmpty) {
        labels.add(customRaw.trim());
      } else {
        labels.add(item?.label ?? c);
      }
    }
    return labels.isEmpty ? empty : labels.join(' · ');
  }

  String get _jobLabel {
    final code = _profile?.jobCode;
    if (code == null || _jobs == null) {
      return _profile?.jobRaw?.isNotEmpty == true
          ? _profile!.jobRaw!
          : '未选';
    }
    for (final i in _jobs!.items) {
      if (i.code == code) {
        if (i.allowCustom && (_profile?.jobRaw?.isNotEmpty ?? false)) {
          return _profile!.jobRaw!;
        }
        return i.label;
      }
    }
    return _profile?.jobRaw?.isNotEmpty == true ? _profile!.jobRaw! : code;
  }

  String get _planLine {
    final m = _profile?.dailyMinutes;
    final d = _profile?.targetDays;
    if (m == null) return '未设置';
    if (d == null) return '$m 分钟';
    return '$m 分钟 · 约 $d 天';
  }

  void _markChanged() => _changed = true;

  Future<void> _bump(int delta) async {
    if (_busy) return;
    final nextIdx = _levels.indexOf(_generation) + delta;
    if (nextIdx < 0 || nextIdx >= _levels.length) return;
    final next = _levels[nextIdx];
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierColor: const Color(0x66000000),
      builder: (ctx) => AlertDialog(
        title: Text(delta > 0 ? '升一档到 $next？' : '降一档到 $next？'),
        content: const Text('只影响之后生成的文章难度，历史不回溯。能力水平不变。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final profile = await _meRepo.bumpGenerationLevel(delta);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _busy = false;
      });
      _markChanged();
      AppToast.show(context, '文章难度已改为 ${profile.generationLevel}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppToast.show(context, e is ApiException ? e.message : '调节失败');
    }
  }

  Future<void> _reassess() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const SelfAssessPage(reassess: true),
      ),
    );
    if (!mounted) return;
    _markChanged();
    await _load();
  }

  Future<void> _editInterests() async {
    final list = _interests;
    final profile = _profile;
    if (list == null || profile == null) return;
    final result = await _openMultiPicker(
      title: '兴趣',
      hint: '新文章话题加权 · 最多 ${list.maxSelect} 个',
      list: list,
      initial: profile.interests.toSet(),
    );
    if (result == null || !mounted) return;
    await _patch({'interests': result.codes.toList()});
  }

  Future<void> _editScenes() async {
    final list = _scenes;
    final profile = _profile;
    if (list == null || profile == null) return;
    final result = await _openMultiPicker(
      title: '场景',
      hint: '最多 ${list.maxSelect} 个',
      list: list,
      initial: profile.scenes.toSet(),
      initialRaw: profile.sceneRaw,
      allowCustomInput: true,
    );
    if (result == null || !mounted) return;
    await _patch({
      'scenes': result.codes.toList(),
      'sceneRaw': result.raw,
    });
  }

  Future<void> _editJob() async {
    final list = _jobs;
    final profile = _profile;
    if (list == null || profile == null) return;
    final result = await showModalBottomSheet<_JobPick>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      barrierColor: const Color(0x66000000),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _JobPickerSheet(
        list: list,
        initialCode: profile.jobCode,
        initialRaw: profile.jobRaw,
      ),
    );
    if (result == null || !mounted) return;
    await _patch({
      'jobCode': result.code,
      'jobRaw': result.raw,
    });
  }

  Future<void> _editDaily() async {
    final profile = _profile;
    if (profile == null) return;
    final result = await showModalBottomSheet<_DailyPick>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      barrierColor: const Color(0x66000000),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _DailyPickerSheet(
        minutes: profile.dailyMinutes ?? 20,
        days: profile.targetDays ?? 1,
        options: _minuteOptions,
        estimate: (minutes) => _plans.estimate(minutes: minutes),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await _plans.confirm(minutes: result.minutes, days: result.days);
      if (!mounted) return;
      _markChanged();
      await _load();
      if (!mounted) return;
      AppToast.show(context, '计划已更新');
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e is ApiException ? e.message : '更新失败');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editBank() async {
    if (_bankList.isEmpty) return;
    final picked = await showModalBottomSheet<WordBank>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      barrierColor: const Color(0x66000000),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _BankPickerSheet(
        items: _bankList,
        selectedId: _profile?.primaryBankId,
      ),
    );
    if (picked == null || !mounted) return;
    if (picked.id == _profile?.primaryBankId) return;

    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierColor: const Color(0x66000000),
      builder: (ctx) => AlertDialog(
        title: Text('切换到「${picked.title}」？'),
        content: const Text('切换后会重算预估天数；已学进度按词保留，不按旧计划天数回溯。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认切换'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final res = await _banks.switchBank(picked.id);
      if (!mounted) return;
      setState(() {
        _bank = res.bank;
        if (res.profile != null) _profile = res.profile;
        _busy = false;
      });
      _markChanged();
      await _load();
      if (!mounted) return;
      AppToast.show(context, '已切换到 ${res.bank.title}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppToast.show(context, e is ApiException ? e.message : '切换失败');
    }
  }

  Future<void> _patch(Map<String, dynamic> body) async {
    setState(() => _busy = true);
    try {
      final profile = await _profileRepo.patch(body);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _busy = false;
      });
      _markChanged();
      AppToast.show(context, '已保存');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppToast.show(context, e is ApiException ? e.message : '保存失败');
    }
  }

  Future<_MultiPick?> _openMultiPicker({
    required String title,
    required String hint,
    required CatalogList list,
    required Set<String> initial,
    String? initialRaw,
    bool allowCustomInput = false,
  }) {
    return showModalBottomSheet<_MultiPick>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      barrierColor: const Color(0x66000000),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _MultiPickerSheet(
        title: title,
        hint: hint,
        list: list,
        initial: initial,
        initialRaw: initialRaw,
        allowCustomInput: allowCustomInput,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final idx = _levels.indexOf(_generation);
    final canDown = idx > 0 && !_busy;
    final canUp = idx >= 0 && idx < _levels.length - 1 && !_busy;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(_changed),
                    icon: const Icon(Icons.chevron_left, size: 28),
                    label: const Text('返回'),
                    style: TextButton.styleFrom(
                      foregroundColor: _blue,
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading && _profile == null
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _error != null && _profile == null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_error!, textAlign: TextAlign.center),
                                const SizedBox(height: 12),
                                FilledButton(
                                  onPressed: _load,
                                  child: const Text('重试'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                          children: [
                            _NoticeBanner(),
                            const SizedBox(height: 10),
                            _LevelCard(
                              ability: _ability,
                              generation: _generation,
                              canDown: canDown,
                              canUp: canUp,
                              busy: _busy,
                              onReassess: _reassess,
                              onDown: () => _bump(-1),
                              onUp: () => _bump(1),
                            ),
                            const SizedBox(height: 14),
                            const _SectionLabel('内容偏好'),
                            const SizedBox(height: 8),
                            _SettingsCard(
                              children: [
                                _NavRow(
                                  label: '职业',
                                  value: _jobLabel,
                                  footnote: '只改之后文章的岗位语境，不换词库',
                                  onTap: _busy ? null : _editJob,
                                ),
                                const Divider(height: 1, color: _divider),
                                _NavRow(
                                  label: '场景',
                                  value: _labels(
                                    _profile?.scenes ?? const [],
                                    _scenes,
                                    customRaw: _profile?.sceneRaw,
                                  ),
                                  footnote: '最多 3 个',
                                  onTap: _busy ? null : _editScenes,
                                ),
                                const Divider(height: 1, color: _divider),
                                _NavRow(
                                  label: '兴趣',
                                  value: _labels(
                                    _profile?.interests ?? const [],
                                    _interests,
                                  ),
                                  footnote: '新文章话题加权',
                                  onTap: _busy ? null : _editInterests,
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            const _SectionLabel('计划'),
                            const SizedBox(height: 8),
                            _SettingsCard(
                              children: [
                                _NavRow(
                                  label: '每日时间',
                                  value: _planLine,
                                  footnote: '改完实时重算预估天数',
                                  onTap: _busy ? null : _editDaily,
                                ),
                                const Divider(height: 1, color: _divider),
                                _NavRow(
                                  label: '主词库',
                                  value: _bank?.title ??
                                      widget.hero?.bankTitle ??
                                      '未选词库',
                                  footnote: '切换后重算计划；已学进度按词保留',
                                  onTap: _busy ? null : _editBank,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              '从「我的」进入。难度与词库变更会二次确认。',
                              style: TextStyle(fontSize: 11, color: _meta),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class _NoticeBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: _EditProfilePageState._blueSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 34,
            decoration: BoxDecoration(
              color: _EditProfilePageState._blue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '修改只作用于之后生成的文章',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _EditProfilePageState._blueDeep,
                    height: 18 / 13,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '已读文章、生词、掌握记录和连胜都不改。',
                  style: TextStyle(
                    fontSize: 12,
                    color: _EditProfilePageState._blueMid,
                    height: 16 / 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.ability,
    required this.generation,
    required this.canDown,
    required this.canUp,
    required this.busy,
    required this.onReassess,
    required this.onDown,
    required this.onUp,
  });

  final String ability;
  final String generation;
  final bool canDown;
  final bool canUp;
  final bool busy;
  final VoidCallback onReassess;
  final VoidCallback onDown;
  final VoidCallback onUp;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFF0F172A),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: _LevelCol(
                    label: '能力水平',
                    value: ability,
                    footnote: '测评结果',
                  ),
                ),
                Container(
                  width: 1,
                  height: 56,
                  color: const Color(0xFF1E293B),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: _LevelCol(
                      label: '文章难度基准',
                      value: generation,
                      footnote: '生成用',
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  onTap: busy ? null : onReassess,
                  child: const Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '重新 AI 测评',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: _EditProfilePageState._text,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '只更新能力水平，不改文章难度',
                              style: TextStyle(
                                fontSize: 12,
                                color: _EditProfilePageState._meta,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: _EditProfilePageState._chevron,
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(
                    height: 1,
                    color: _EditProfilePageState._divider,
                  ),
                ),
                const Text(
                  '调节文章难度',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: _EditProfilePageState._text,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '每次升/降一档（A1–C2）。只影响之后文章。',
                  style: TextStyle(
                    fontSize: 12,
                    color: _EditProfilePageState._meta,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: canDown ? onDown : null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _EditProfilePageState._blue,
                          side: const BorderSide(color: Color(0xFFDBEAFE)),
                          backgroundColor: _EditProfilePageState._bg,
                          minimumSize: const Size.fromHeight(40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          '降一档',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: canUp ? onUp : null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _EditProfilePageState._blue,
                          side: const BorderSide(color: Color(0xFFDBEAFE)),
                          backgroundColor: _EditProfilePageState._bg,
                          minimumSize: const Size.fromHeight(40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          '升一档',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelCol extends StatelessWidget {
  const _LevelCol({
    required this.label,
    required this.value,
    required this.footnote,
  });

  final String label;
  final String value;
  final String footnote;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: _EditProfilePageState._meta,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 34 / 28,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          footnote,
          style: const TextStyle(
            fontSize: 11,
            color: _EditProfilePageState._muted,
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: _EditProfilePageState._muted,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.label,
    required this.value,
    required this.footnote,
    this.onTap,
  });

  final String label;
  final String value;
  final String footnote;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _EditProfilePageState._meta,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _EditProfilePageState._text,
                      height: 22 / 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    footnote,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _EditProfilePageState._meta,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: _EditProfilePageState._chevron,
            ),
          ],
        ),
      ),
    );
  }
}

class _MultiPick {
  const _MultiPick({required this.codes, this.raw});
  final Set<String> codes;
  final String? raw;
}

class _MultiPickerSheet extends StatefulWidget {
  const _MultiPickerSheet({
    required this.title,
    required this.hint,
    required this.list,
    required this.initial,
    this.initialRaw,
    this.allowCustomInput = false,
  });

  final String title;
  final String hint;
  final CatalogList list;
  final Set<String> initial;
  final String? initialRaw;
  final bool allowCustomInput;

  @override
  State<_MultiPickerSheet> createState() => _MultiPickerSheetState();
}

class _MultiPickerSheetState extends State<_MultiPickerSheet> {
  late Set<String> _selected;
  late final TextEditingController _raw;
  final _scroll = ScrollController();
  final _rawFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _selected = {...widget.initial};
    _raw = TextEditingController(text: widget.initialRaw ?? '');
    if (_needsCustom) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealCustomField());
    }
  }

  @override
  void dispose() {
    _raw.dispose();
    _scroll.dispose();
    _rawFocus.dispose();
    super.dispose();
  }

  bool get _needsCustom {
    if (!widget.allowCustomInput) return false;
    return _selected.any(
      (c) => widget.list.items.any((i) => i.code == c && i.allowCustom),
    );
  }

  bool get _canSave {
    if (_selected.isEmpty) return false;
    if (_needsCustom && _raw.text.trim().isEmpty) return false;
    return true;
  }

  void _revealCustomField() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_needsCustom) return;
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
      _rawFocus.requestFocus();
    });
  }

  void _toggle(CatalogItem item) {
    final max = widget.list.maxSelect;
    var openedCustom = false;
    setState(() {
      if (_selected.contains(item.code)) {
        _selected.remove(item.code);
        if (item.allowCustom) {
          _raw.clear();
          _rawFocus.unfocus();
        }
      } else if (_selected.length < max) {
        _selected.add(item.code);
        if (item.allowCustom) openedCustom = true;
      } else {
        AppToast.show(context, '最多选 $max 个');
      }
    });
    if (openedCustom) _revealCustomField();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final screenH = MediaQuery.sizeOf(context).height;
    // 标题+说明+保存+内边距约占 160；键盘抬起时列表必须按剩余高度收缩
    const chrome = 160.0;
    final listMaxH = (screenH - inset - bottom - chrome).clamp(
      120.0,
      screenH * 0.5,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom + inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _EditProfilePageState._text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.hint,
            style: const TextStyle(
              fontSize: 13,
              color: _EditProfilePageState._muted,
            ),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: listMaxH),
            child: SingleChildScrollView(
              controller: _scroll,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OptionTileGrid(
                    items: widget.list.items,
                    selected: _selected,
                    onToggle: _toggle,
                  ),
                  if (_needsCustom) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _raw,
                      focusNode: _rawFocus,
                      onChanged: (_) => setState(() {}),
                      maxLength: 64,
                      decoration: InputDecoration(
                        hintText: '填写具体场景',
                        filled: true,
                        fillColor: _EditProfilePageState._bg,
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: _EditProfilePageState._border,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: _EditProfilePageState._border,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: _EditProfilePageState._blue,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: !_canSave
                  ? null
                  : () => Navigator.pop(
                        context,
                        _MultiPick(
                          codes: _selected,
                          raw: _needsCustom ? _raw.text.trim() : null,
                        ),
                      ),
              style: FilledButton.styleFrom(
                backgroundColor: _EditProfilePageState._blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '保存',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JobPick {
  const _JobPick({required this.code, this.raw});
  final String code;
  final String? raw;
}

class _JobPickerSheet extends StatefulWidget {
  const _JobPickerSheet({
    required this.list,
    this.initialCode,
    this.initialRaw,
  });

  final CatalogList list;
  final String? initialCode;
  final String? initialRaw;

  @override
  State<_JobPickerSheet> createState() => _JobPickerSheetState();
}

class _JobPickerSheetState extends State<_JobPickerSheet> {
  String? _selected;
  late final TextEditingController _raw;
  final _scroll = ScrollController();
  final _rawFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _selected = widget.initialCode;
    _raw = TextEditingController(text: widget.initialRaw ?? '');
    if (_needsCustom) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealCustomField());
    }
  }

  @override
  void dispose() {
    _raw.dispose();
    _scroll.dispose();
    _rawFocus.dispose();
    super.dispose();
  }

  CatalogItem? get _item {
    final code = _selected;
    if (code == null) return null;
    for (final i in widget.list.items) {
      if (i.code == code) return i;
    }
    return null;
  }

  bool get _needsCustom => _item?.allowCustom == true;

  bool get _canSave {
    if (_selected == null) return false;
    if (_needsCustom && _raw.text.trim().isEmpty) return false;
    return true;
  }

  void _revealCustomField() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_needsCustom) return;
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
      _rawFocus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final screenH = MediaQuery.sizeOf(context).height;
    const chrome = 160.0;
    final listMaxH = (screenH - inset - bottom - chrome).clamp(
      120.0,
      screenH * 0.45,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom + inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '职业',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _EditProfilePageState._text,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '只改之后文章的岗位语境，不换词库',
            style: TextStyle(
              fontSize: 13,
              color: _EditProfilePageState._muted,
            ),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: listMaxH),
            child: SingleChildScrollView(
              controller: _scroll,
              child: Column(
                children: [
                  OptionTileGrid(
                    items: widget.list.items,
                    selected: {
                      ?_selected,
                    },
                    onToggle: (item) {
                      setState(() {
                        _selected = item.code;
                        if (!item.allowCustom) {
                          _raw.clear();
                          _rawFocus.unfocus();
                        }
                      });
                      if (item.allowCustom) _revealCustomField();
                    },
                  ),
                  if (_needsCustom) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _raw,
                      focusNode: _rawFocus,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: '填写具体岗位',
                        filled: true,
                        fillColor: _EditProfilePageState._bg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: _EditProfilePageState._border,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: _EditProfilePageState._border,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: _EditProfilePageState._blue,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: !_canSave
                  ? null
                  : () => Navigator.pop(
                        context,
                        _JobPick(
                          code: _selected!,
                          raw: _needsCustom ? _raw.text.trim() : null,
                        ),
                      ),
              style: FilledButton.styleFrom(
                backgroundColor: _EditProfilePageState._blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '保存',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyPick {
  const _DailyPick({required this.minutes, required this.days});
  final int minutes;
  final int days;
}

class _DailyPickerSheet extends StatefulWidget {
  const _DailyPickerSheet({
    required this.minutes,
    required this.days,
    required this.options,
    required this.estimate,
  });

  final int minutes;
  final int days;
  final List<int> options;
  final Future<PlanEstimate> Function(int minutes) estimate;

  @override
  State<_DailyPickerSheet> createState() => _DailyPickerSheetState();
}

class _DailyPickerSheetState extends State<_DailyPickerSheet> {
  late int _minutes;
  late int _days;
  bool _estimating = false;

  @override
  void initState() {
    super.initState();
    _minutes = widget.minutes;
    _days = widget.days;
  }

  Future<void> _pick(int minutes) async {
    setState(() {
      _minutes = minutes;
      _estimating = true;
    });
    try {
      final est = await widget.estimate(minutes);
      if (!mounted) return;
      setState(() {
        _days = est.days;
        _estimating = false;
      });
    } catch (_) {
      if (mounted) setState(() => _estimating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '每日时间',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _EditProfilePageState._text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _estimating ? '正在重算…' : '约 $_days 天完成当前词库',
            style: const TextStyle(
              fontSize: 13,
              color: _EditProfilePageState._muted,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: widget.options.map((m) {
              final selected = m == _minutes;
              return GestureDetector(
                onTap: () => _pick(m),
                child: Container(
                  width: 96,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: selected
                        ? _EditProfilePageState._blueSoft
                        : _EditProfilePageState._bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? _EditProfilePageState._blue
                          : _EditProfilePageState._border,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$m 分钟',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? _EditProfilePageState._blue
                          : _EditProfilePageState._text,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _estimating
                  ? null
                  : () => Navigator.pop(
                        context,
                        _DailyPick(minutes: _minutes, days: _days),
                      ),
              style: FilledButton.styleFrom(
                backgroundColor: _EditProfilePageState._blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '保存',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BankPickerSheet extends StatelessWidget {
  const _BankPickerSheet({required this.items, this.selectedId});

  final List<WordBank> items;
  final int? selectedId;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '主词库',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _EditProfilePageState._text,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '切换后重算计划；已学进度按词保留',
            style: TextStyle(
              fontSize: 13,
              color: _EditProfilePageState._muted,
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.5,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final bank = items[i];
                final selected = bank.id == selectedId;
                return Material(
                  color: selected
                      ? _EditProfilePageState._blueSoft
                      : _EditProfilePageState._bg,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => Navigator.pop(context, bank),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? _EditProfilePageState._blue
                              : _EditProfilePageState._border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bank.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: selected
                                        ? _EditProfilePageState._blue
                                        : _EditProfilePageState._text,
                                  ),
                                ),
                                if (bank.subtitle != null &&
                                    bank.subtitle!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    bank.subtitle!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: _EditProfilePageState._muted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (selected)
                            const Icon(
                              Icons.check,
                              color: _EditProfilePageState._blue,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
