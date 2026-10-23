import 'package:flutter/material.dart';
import 'package:app_starter/core/network/api_client.dart';
import 'package:app_starter/core/ui/app_toast.dart';
import 'package:app_starter/features/auth/auth_repository.dart';
import 'package:app_starter/features/onboarding/guide_page.dart';
import 'package:app_starter/features/onboarding/self_assess_page.dart';
import 'package:app_starter/features/profile/edit_profile_page.dart';
import 'package:app_starter/features/profile/me_models.dart';
import 'package:app_starter/features/profile/me_repository.dart';

/// 我的 Tab：对齐 Figma Phone/我的。
class MePage extends StatefulWidget {
  const MePage({super.key});

  @override
  State<MePage> createState() => _MePageState();
}

class _MePageState extends State<MePage> {
  final _repo = MeRepository();
  final _auth = AuthRepository();

  MeSummary? _me;
  bool _loading = true;
  String? _error;

  static const _bg = Color(0xFFF8FAFC);
  static const _text = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _meta = Color(0xFF94A3B8);
  static const _blue = Color(0xFF2563EB);
  static const _hero = Color(0xFF1E3A8A);
  static const _heroLabel = Color(0xFF93C5FD);
  static const _heroMeta = Color(0xFFBFDBFE);
  static const _border = Color(0xFFE2E8F0);
  static const _divider = Color(0xFFF1F5F9);

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
      final me = await _repo.fetch();
      if (!mounted) return;
      setState(() {
        _me = me;
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

  Future<void> _editProfile() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EditProfilePage(hero: _me?.hero),
      ),
    );
    if (changed == true && mounted) _load();
  }

  void _reassess() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SelfAssessPage(reassess: true),
      ),
    );
  }

  void _remind() {
    AppToast.show(context, '学习提醒即将接入');
  }

  Future<void> _account() async {
    final phone = _me?.user.phone ?? '';
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '账号',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  phone.isEmpty ? '已登录' : phone,
                  style: const TextStyle(fontSize: 15, color: _muted),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      await _logout();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _blue,
                      side: const BorderSide(color: _border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '退出登录',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    AppToast.show(context, '注销账号即将接入');
                  },
                  child: const Text(
                    '注销账号',
                    style: TextStyle(color: Color(0xFFDC2626)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const GuidePage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: _loading && _me == null
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : _error != null && _me == null
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
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                      children: [
                        const Text(
                          '我的',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: _text,
                            height: 34 / 28,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _HeroCard(
                          hero: _me!.hero,
                          onEdit: _editProfile,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                label: '词汇量',
                                value: _me!.stats.vocabLabel,
                                footnote: _me!.stats.weekDeltaLabel,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _StatCard(
                                label: '连胜',
                                value: _me!.stats.streakLabel,
                                footnote: _me!.stats.streakFootnote,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _border),
                          ),
                          child: Column(
                            children: [
                              _SettingRow(
                                title: '重新 AI 测评',
                                subtitle: '只更新能力水平，不改文章难度基准',
                                onTap: _reassess,
                              ),
                              const Divider(height: 1, color: _divider),
                              _SettingRow(
                                title: '学习提醒',
                                subtitle: '每日推送时间',
                                onTap: _remind,
                              ),
                              const Divider(height: 1, color: _divider),
                              _SettingRow(
                                title: '账号',
                                subtitle: _me!.user.phone.isEmpty
                                    ? '手机号 · 注销'
                                    : '${_me!.user.phone} · 注销',
                                onTap: _account,
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

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.hero, required this.onEdit});

  final MeHero hero;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: BoxDecoration(
        color: _MePageState._hero,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '学习画像',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _MePageState._heroLabel,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            hero.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 32 / 24,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            hero.abilityLine,
            style: const TextStyle(
              fontSize: 13,
              color: _MePageState._heroMeta,
              height: 20 / 13,
            ),
          ),
          Text(
            hero.note,
            style: const TextStyle(
              fontSize: 13,
              color: _MePageState._heroMeta,
              height: 20 / 13,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton(
              onPressed: onEdit,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _MePageState._hero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                '编辑画像',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.footnote,
  });

  final String label;
  final String value;
  final String footnote;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _MePageState._border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: _MePageState._meta,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _MePageState._text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            footnote,
            style: const TextStyle(
              fontSize: 11,
              color: _MePageState._muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: _MePageState._text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _MePageState._meta,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: _MePageState._meta,
            ),
          ],
        ),
      ),
    );
  }
}
