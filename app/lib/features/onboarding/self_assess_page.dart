import 'package:flutter/material.dart';
import 'package:app_starter/features/onboarding/assess_quiz_page.dart';
import 'package:app_starter/features/onboarding/cefr_levels.dart';
import 'package:app_starter/features/onboarding/job_page.dart';
import 'package:app_starter/features/onboarding/onboarding_nav.dart';
import 'package:app_starter/features/onboarding/widgets/onboarding_scaffold.dart';

/// ⑥ 自评开场：中文六档；只引导起始难度，不写 ability_level。
class SelfAssessPage extends StatefulWidget {
  const SelfAssessPage({super.key, this.reassess = false});

  final bool reassess;

  @override
  State<SelfAssessPage> createState() => _SelfAssessPageState();
}

class _SelfAssessPageState extends State<SelfAssessPage> {
  String? _selectedId;

  void _goNext() {
    final startLevel = startLevelForTierId(_selectedId);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AssessQuizPage(
          startLevel: startLevel,
          reassess: widget.reassess,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: '你的英语怎么样？',
      subtitle: '我们会根据你当前的水平出发，进行学习。',
      body: Column(
        children: [
          for (var i = 0; i < kSelfAssessTiers.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _TierTile(
              tier: kSelfAssessTiers[i],
              selected: _selectedId == kSelfAssessTiers[i].id,
              onTap: () => setState(() {
                _selectedId = kSelfAssessTiers[i].id;
              }),
            ),
          ],
        ],
      ),
      ctaLabel: '下一步',
      // 未选也可点 → 默认中档 B1
      ctaEnabled: true,
      onCta: _goNext,
      onBack: () => onboardingBack(context, fallback: const JobPage()),
    );
  }
}

class _TierTile extends StatelessWidget {
  const _TierTile({
    required this.tier,
    required this.selected,
    required this.onTap,
  });

  final SelfAssessTier tier;
  final bool selected;
  final VoidCallback onTap;

  static const _blue = Color(0xFF2563EB);
  static const _blueSoft = Color(0xFFEFF6FF);
  static const _border = Color(0xFFE2E8F0);
  static const _text = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _blueSoft : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? _blue : _border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tier.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: selected ? _blue : _text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                tier.subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: _muted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
