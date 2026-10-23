import 'package:flutter/material.dart';
import 'package:app_starter/features/lesson/lesson_article_page.dart';
import 'package:app_starter/features/onboarding/plan_models.dart';

/// ⑨ 计划落定：对齐 Figma Phone/进入。
class PlanReadyPage extends StatelessWidget {
  const PlanReadyPage({super.key, required this.ready});

  final PlanReady ready;

  static const _bg = Color(0xFFF8FAFC);
  static const _blue = Color(0xFF2563EB);
  static const _blueSoft = Color(0xFFEFF6FF);
  static const _blueBorder = Color(0xFFBFDBFE);
  static const _blueDeep = Color(0xFF1D4ED8);
  static const _text = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _track = Color(0xFFE2E8F0);

  void _enter(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LessonArticlePage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = ready.days <= 0 ? 0.0 : (1 / ready.days).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '画像完成',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _blue,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                ready.title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: _text,
                  height: 36 / 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                ready.subtitle,
                style: const TextStyle(
                  fontSize: 15,
                  color: _muted,
                  height: 22 / 15,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _blueSoft,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _blueBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '目标词库',
                      style: TextStyle(fontSize: 12, color: _muted),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      ready.bankLine,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _blueDeep,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _StatTile(
                            value: '${ready.days} 天',
                            label: '预计天数',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatTile(
                            value: '${ready.minutes} 分',
                            label: '每日投入',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatTile(
                            value: ready.level,
                            label: '起步水平',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _track),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ready.dayProgress,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _text,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: _track,
                        color: _blue,
                      ),
                    ),
                    if (ready.scenesLine != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        ready.scenesLine!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _muted,
                          height: 18 / 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    const Text(
                      '第一篇已为你备好，点一下就能开读。',
                      style: TextStyle(
                        fontSize: 12,
                        color: _muted,
                        height: 18 / 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 51,
                child: FilledButton(
                  onPressed: () => _enter(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: _blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '开启 Day 1 · 读第一篇',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}
