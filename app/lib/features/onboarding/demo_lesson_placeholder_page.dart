import 'package:flutter/material.dart';
import 'package:app_starter/features/onboarding/onboarding_nav.dart';
import 'package:app_starter/features/onboarding/bank_select_page.dart';

/// 先看 Demo：不选定词库即可预览；正式 Demo 日课下一切片接入。
class DemoLessonPlaceholderPage extends StatelessWidget {
  const DemoLessonPlaceholderPage({super.key});

  static const _bg = Color(0xFFF8FAFC);
  static const _blue = Color(0xFF2563EB);
  static const _text = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);

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
          onPressed: () => onboardingBack(
            context,
            fallback: const BankSelectPage(),
          ),
        ),
      ),
      body: const SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Demo 日课',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _text,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '先感受一篇按水平与场景写就的文章。正式 Demo 内容即将接入，返回后仍可自选词库。',
                style: TextStyle(fontSize: 14, color: _muted, height: 1.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
