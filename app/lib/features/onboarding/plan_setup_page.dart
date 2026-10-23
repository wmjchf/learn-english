import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_starter/core/network/api_client.dart';
import 'package:app_starter/core/ui/app_toast.dart';
import 'package:app_starter/features/onboarding/bank_select_page.dart';
import 'package:app_starter/features/onboarding/plan_models.dart';
import 'package:app_starter/features/onboarding/plan_ready_page.dart';
import 'package:app_starter/features/onboarding/plan_repository.dart';

/// ⑧ 每天时间与计划天数：chips + 天数双向联动。
class PlanSetupPage extends StatefulWidget {
  const PlanSetupPage({super.key});

  @override
  State<PlanSetupPage> createState() => _PlanSetupPageState();
}

class _PlanSetupPageState extends State<PlanSetupPage> {
  static const _bg = Color(0xFFF8FAFC);
  static const _blue = Color(0xFF2563EB);
  static const _text = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _hint = Color(0xFF94A3B8);
  static const _warn = Color(0xFFB45309);

  final _repo = PlanRepository();
  final _daysCtrl = TextEditingController();

  PlanContext? _ctx;
  int _minutes = 20;
  int _days = 1;
  int _dailyWords = 30;
  String? _warning;
  bool _loading = true;
  bool _estimating = false;
  bool _submitting = false;
  String? _error;
  bool _editingDays = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _daysCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ctx = await _repo.context();
      if (!mounted) return;
      setState(() {
        _ctx = ctx;
        _minutes = ctx.estimate.minutes;
        _days = ctx.estimate.days;
        _dailyWords = ctx.estimate.dailyWords;
        _warning = ctx.estimate.warning;
        _daysCtrl.text = '$_days';
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

  Future<void> _recalcFromMinutes(int minutes) async {
    setState(() {
      _minutes = minutes;
      _estimating = true;
    });
    try {
      final est = await _repo.estimate(minutes: minutes);
      if (!mounted) return;
      setState(() {
        _days = est.days;
        _dailyWords = est.dailyWords;
        _warning = est.warning;
        _daysCtrl.text = '${est.days}';
        _estimating = false;
      });
    } catch (_) {
      if (mounted) setState(() => _estimating = false);
    }
  }

  Future<void> _recalcFromDays(int days) async {
    if (days < 1) return;
    setState(() {
      _days = days;
      _estimating = true;
    });
    try {
      final est = await _repo.estimate(days: days);
      if (!mounted) return;
      setState(() {
        _minutes = est.minutes;
        _dailyWords = est.dailyWords;
        _warning = est.warning;
        _estimating = false;
      });
    } catch (_) {
      if (mounted) setState(() => _estimating = false);
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final ready = await _repo.confirm(minutes: _minutes, days: _days);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => PlanReadyPage(ready: ready)),
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
        AppToast.show(context, '生成计划失败，请稍后重试');
      }
    }
  }

  String? get _warningText {
    switch (_warning) {
      case 'aggressive':
        return '每天超过 45 分钟偏激进，可适当增加计划天数。';
      case 'too_short':
        return '每天不足 5 分钟可能不够一篇，建议增加投入或拉长天数。';
      default:
        return null;
    }
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
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute<void>(
                      builder: (_) => const BankSelectPage(),
                    ),
                    (_) => false,
                  );
                },
        ),
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : _error != null
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(_error!, style: const TextStyle(color: _muted)),
                        TextButton(onPressed: _load, child: const Text('重试')),
                      ],
                    ),
                  )
                : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final ctx = _ctx!;
    final bank = ctx.bank;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '每天能投入多久？',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${bank.title} ${bank.targetSize ?? ''} 词，已知约 ${ctx.knownEstimate}。时间和天数双向联动。',
            style: const TextStyle(fontSize: 13, color: _hint, height: 1.4),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MinuteChips(
                    options: ctx.minuteOptions,
                    selected: _minutes,
                    onSelect: _recalcFromMinutes,
                  ),
                  if (!ctx.minuteOptions.contains(_minutes)) ...[
                    const SizedBox(height: 8),
                    Text(
                      '按当前天数反算约 $_minutes 分钟/天',
                      style: const TextStyle(fontSize: 12, color: _hint),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _SummaryCard(
                    days: _days,
                    dailyWords: _dailyWords,
                    wordsPerLesson: 12,
                  ),
                  if (_warningText != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _warningText!,
                      style: const TextStyle(fontSize: 12, color: _warn),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _DaysCard(
                    controller: _daysCtrl,
                    editing: _editingDays,
                    onEdit: () => setState(() => _editingDays = true),
                    onSubmitted: (v) {
                      setState(() => _editingDays = false);
                      final n = int.tryParse(v.trim());
                      if (n != null) _recalcFromDays(n);
                    },
                  ),
                  if (_estimating)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: _blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _submitting ? '生成中…' : '生成计划并进入',
                style: const TextStyle(
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

class _MinuteChips extends StatelessWidget {
  const _MinuteChips({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final List<int> options;
  final int selected;
  final ValueChanged<int> onSelect;

  static const _blue = Color(0xFF2563EB);
  static const _blueSoft = Color(0xFFEFF6FF);
  static const _border = Color(0xFFE2E8F0);
  static const _text = Color(0xFF0F172A);

  @override
  Widget build(BuildContext context) {
    final rows = <List<int>>[];
    for (var i = 0; i < options.length; i += 3) {
      rows.add(options.sublist(i, (i + 3).clamp(0, options.length)));
    }
    return Column(
      children: [
        for (var r = 0; r < rows.length; r++) ...[
          if (r > 0) const SizedBox(height: 8),
          Row(
            children: [
              for (var c = 0; c < rows[r].length; c++) ...[
                if (c > 0) const SizedBox(width: 8),
                Expanded(
                  child: _Chip(
                    label: '${rows[r][c]} 分钟',
                    active: selected == rows[r][c],
                    onTap: () => onSelect(rows[r][c]),
                  ),
                ),
              ],
              // 补齐不足 3 个的行
              for (var c = rows[r].length; c < 3; c++) ...[
                const SizedBox(width: 8),
                const Expanded(child: SizedBox()),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? _MinuteChips._blueSoft : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? _MinuteChips._blue : _MinuteChips._border,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: active ? _MinuteChips._blue : _MinuteChips._text,
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.days,
    required this.dailyWords,
    required this.wordsPerLesson,
  });

  final int days;
  final int dailyWords;
  final int wordsPerLesson;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '预计学完',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 6),
          Text(
            '$days 天',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '每天约 $dailyWords 个词 · 一篇 $wordsPerLesson 个目标词',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

class _DaysCard extends StatelessWidget {
  const _DaysCard({
    required this.controller,
    required this.editing,
    required this.onEdit,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final bool editing;
  final VoidCallback onEdit;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '想拿下这套 list，计划多少天？',
            style: TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),
          if (editing)
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                suffixText: '天',
              ),
              onSubmitted: onSubmitted,
              onEditingComplete: () => onSubmitted(controller.text),
            )
          else
            GestureDetector(
              onTap: onEdit,
              child: Text(
                '${controller.text} 天',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2563EB),
                ),
              ),
            ),
          const SizedBox(height: 8),
          const Text(
            '改天数会反算每天分钟。',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}
