import 'dart:async';

import 'package:flutter/material.dart';

/// 首篇 / 日课生成中的全屏状态：步骤条 + 轮播提示，避免空白转圈。
class LessonGeneratingView extends StatefulWidget {
  const LessonGeneratingView({
    super.key,
    this.title = '正在写你的 Day 1',
    this.subtitle = '按水平 · 职业 · 场景 · 词库定制',
  });

  final String title;
  final String subtitle;

  @override
  State<LessonGeneratingView> createState() => _LessonGeneratingViewState();
}

class _LessonGeneratingViewState extends State<LessonGeneratingView>
    with SingleTickerProviderStateMixin {
  static const _bg = Color(0xFFF8FAFC);
  static const _text = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _meta = Color(0xFF94A3B8);
  static const _blue = Color(0xFF2563EB);
  static const _blueSoft = Color(0xFFEFF6FF);
  static const _blueDeep = Color(0xFF1E3A8A);
  static const _border = Color(0xFFE2E8F0);

  static const _steps = [
    ('读你的画像', '水平、职业与使用场景'),
    ('抽今日目标词', '从词库里取出这一批'),
    ('写短文与对话', '把词编进自然语境'),
    ('备好闭眼回填', '马上就能开读'),
  ];

  static const _tips = [
    '目标词会在文中高亮，点一下就能看释义。',
    '读出声效果更好，短文和对话都支持朗读。',
    '回填拼错的词会进生词本，之后文章里再见。',
    '生成通常需要几十秒，取决于网络与模型。',
  ];

  late final AnimationController _pulse;
  int _step = 0;
  int _tip = 0;
  Timer? _stepTimer;
  Timer? _tipTimer;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _stepTimer = Timer.periodic(const Duration(milliseconds: 2200), (_) {
      if (!mounted) return;
      setState(() => _step = (_step + 1) % _steps.length);
    });
    _tipTimer = Timer.periodic(const Duration(milliseconds: 3800), (_) {
      if (!mounted) return;
      setState(() => _tip = (_tip + 1) % _tips.length);
    });
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _tipTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _bg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 36, 28, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '词成文',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _blue,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: _text,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  color: _muted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 36),
              ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1.0).animate(
                  CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                ),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
                  decoration: BoxDecoration(
                    color: _blueDeep,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white.withValues(alpha: 0.95),
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      const SizedBox(height: 18),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        child: Text(
                          _steps[_step].$1,
                          key: ValueKey(_step),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        child: Text(
                          _steps[_step].$2,
                          key: ValueKey('sub$_step'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.72),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ...List.generate(_steps.length, (i) {
                final active = i == _step;
                final done = i < _step;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _StepRow(
                    index: i + 1,
                    label: _steps[i].$1,
                    active: active,
                    done: done,
                  ),
                );
              }),
              const Spacer(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: _blueSoft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline, size: 18, color: _blue),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 320),
                        child: Text(
                          _tips[_tip],
                          key: ValueKey(_tip),
                          style: const TextStyle(
                            fontSize: 13,
                            color: _muted,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '请稍候，生成完成后会直接进入阅读',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: _meta),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.index,
    required this.label,
    required this.active,
    required this.done,
  });

  final int index;
  final String label;
  final bool active;
  final bool done;

  static const _text = Color(0xFF0F172A);
  static const _meta = Color(0xFF94A3B8);
  static const _blue = Color(0xFF2563EB);
  static const _border = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    final color = active || done ? _blue : _meta;
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: done || active ? const Color(0xFFEFF6FF) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: done || active ? const Color(0xFFBFDBFE) : _border,
            ),
          ),
          child: done
              ? const Icon(Icons.check_rounded, size: 16, color: _blue)
              : Text(
                  '$index',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? _text : _meta,
            ),
          ),
        ),
        if (active)
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 1.8,
              color: _blue.withValues(alpha: 0.8),
            ),
          ),
      ],
    );
  }
}
