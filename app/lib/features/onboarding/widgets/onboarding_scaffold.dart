import 'package:flutter/material.dart';

class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.ctaLabel,
    required this.onCta,
    required this.onBack,
    this.ctaEnabled = true,
    this.submitting = false,
    this.footer,
  });

  final String title;
  final String subtitle;
  final Widget body;
  final String ctaLabel;
  final VoidCallback? onCta;
  final VoidCallback onBack;
  final bool ctaEnabled;
  final bool submitting;
  final Widget? footer;

  static const bg = Color(0xFFF8FAFC);
  static const text = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const blue = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    final canSubmit = ctaEnabled && !submitting && onCta != null;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: blue, size: 32),
          onPressed: onBack,
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: text,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  color: muted,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: SingleChildScrollView(child: body),
              ),
              if (footer != null) ...[
                const SizedBox(height: 12),
                footer!,
              ],
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: canSubmit ? onCta : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: blue,
                    disabledBackgroundColor: const Color(0xFFBFDBFE),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    submitting ? '保存中…' : ctaLabel,
                    style: const TextStyle(
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
