import 'package:flutter/material.dart';
import 'package:app_starter/core/ui/app_buttons.dart';
import 'package:app_starter/core/ui/app_haptics.dart';
import 'package:app_starter/features/onboarding/bank_models.dart';
import 'package:app_starter/features/onboarding/plan_models.dart';

const _bg = Color(0xFFF8FAFC);
const _text = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _blue = Color(0xFF7AC70C);
const _blueSoft = Color(0xFFF7FEE7);
const _border = Color(0xFFE2E8F0);

class DailyPick {
  const DailyPick({required this.minutes, required this.days});
  final int minutes;
  final int days;
}

class DailyPickerSheet extends StatefulWidget {
  const DailyPickerSheet({
    super.key,
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
  State<DailyPickerSheet> createState() => _DailyPickerSheetState();
}

class _DailyPickerSheetState extends State<DailyPickerSheet> {
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
              color: _text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _estimating ? '正在重算…' : '约 $_days 天完成当前词库',
            style: const TextStyle(fontSize: 13, color: _muted),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: widget.options.map((m) {
              final selected = m == _minutes;
              return GestureDetector(
                onTap: withHaptic(() => _pick(m), select: true),
                child: Container(
                  width: 96,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: selected ? _blueSoft : _bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: selected ? _blue : _border),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$m 分钟',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected ? _blue : _text,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: AppFilledButton(
              onPressed: _estimating
                  ? null
                  : () => Navigator.pop(
                        context,
                        DailyPick(minutes: _minutes, days: _days),
                      ),
              style: AppFilledButton.styleFrom(
                backgroundColor: _blue,
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

class BankPickerSheet extends StatelessWidget {
  const BankPickerSheet({super.key, required this.items, this.selectedId});

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
              color: _text,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '切换后重算计划；已学进度按词保留',
            style: TextStyle(fontSize: 13, color: _muted),
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
                  color: selected ? _blueSoft : _bg,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: withHaptic(
                      () => Navigator.pop(context, bank),
                      select: true,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? _blue : _border,
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
                                    color: selected ? _blue : _text,
                                  ),
                                ),
                                if (bank.subtitle != null &&
                                    bank.subtitle!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    bank.subtitle!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: _muted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (selected)
                            const Icon(Icons.check, color: _blue),
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
