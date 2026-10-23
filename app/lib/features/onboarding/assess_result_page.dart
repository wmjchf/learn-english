import 'package:flutter/material.dart';
import 'package:app_starter/features/onboarding/assess_models.dart';
import 'package:app_starter/features/onboarding/bank_select_page.dart';
import 'package:app_starter/features/shell/main_shell.dart';

/// 定级结果：对齐 Figma Phone/定级（居中大字 + 双水平卡 + 底部 CTA）。
class AssessResultPage extends StatelessWidget {
  const AssessResultPage({
    super.key,
    required this.result,
    this.reassess = false,
  });

  final AssessResult result;

  /// 从「我的」重测：只回主壳，不进选词库。
  final bool reassess;

  static const _bg = Color(0xFFF8FAFC);
  static const _blue = Color(0xFF2563EB);
  static const _blueSoft = Color(0xFFEFF6FF);
  static const _blueBorder = Color(0xFFDBEAFE);
  static const _text = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _hint = Color(0xFF94A3B8);
  static const _divider = Color(0xFFE2E8F0);

  static String _formatVocab(int n) {
    final digits = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  void _goNext(BuildContext context) {
    if (reassess) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const MainShell(initialIndex: 3),
        ),
        (_) => false,
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const BankSelectPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final level = result.level;
    final vocab = _formatVocab(result.estimatedVocab);

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _blueSoft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '测评完成',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _blue,
                          height: 16 / 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      level,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.w700,
                        color: _blue,
                        height: 80 / 72,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '估计词汇量 $vocab',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: _text,
                        height: 22 / 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '按本次作答给出的起步档',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: _hint,
                        height: 18 / 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _blueBorder),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            '首次同时写入',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _muted,
                              height: 16 / 12,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: _LevelCell(
                                  label: '能力水平',
                                  value: level,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 44,
                                color: _divider,
                              ),
                              Expanded(
                                child: _LevelCell(
                                  label: '文章难度基准',
                                  value: level,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            '之后可在画像里分别调整',
                            style: TextStyle(
                              fontSize: 12,
                              color: _hint,
                              height: 16 / 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: () => _goNext(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: _blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    reassess ? '回到我的' : '继续，选词库',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '结果页不提供改档；觉得难易可之后在画像调节',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: _hint,
                  height: 16 / 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelCell extends StatelessWidget {
  const _LevelCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF94A3B8),
            height: 16 / 12,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
            height: 28 / 22,
          ),
        ),
      ],
    );
  }
}
