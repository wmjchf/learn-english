import 'package:flutter/material.dart';
import 'package:app_starter/features/lesson/lesson_models.dart';

typedef TokenTap = void Function(LessonToken token);

/// 英文 token 流：目标词黄底；focus 词（生词本跳转）蓝底描边。
class TokenText extends StatelessWidget {
  const TokenText({
    super.key,
    required this.tokens,
    required this.onTap,
    this.knownLemmas = const {},
    this.tempHighlightLemmas = const {},
    this.focusLemmas = const {},
    this.leading,
    this.fontSize = 16,
  });

  final List<LessonToken> tokens;
  final TokenTap onTap;
  final Set<String> knownLemmas;
  final Set<String> tempHighlightLemmas;
  /// 从生词本点进原文时强调的词。
  final Set<String> focusLemmas;
  final Widget? leading;
  final double fontSize;

  static const _text = Color(0xFF17202E);
  static const _hlBg = Color(0xFFFFF3C4);
  static const _hlFg = Color(0xFF8A5A00);
  static const _focusBg = Color(0xFFDBEAFE);
  static const _focusFg = Color(0xFF1E40AF);
  static const _focusBorder = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ?leading,
        ...tokens.map((t) {
          final isPunct = RegExp(r"^[.,!?;:—\-']+$").hasMatch(t.surface);
          final showFocus =
              t.lemma.isNotEmpty && focusLemmas.contains(t.lemma);
          final showTarget = t.isTarget &&
              !knownLemmas.contains(t.lemma) &&
              t.lemma.isNotEmpty;
          final showTemp = tempHighlightLemmas.contains(t.lemma);
          final highlight = showTarget || showTemp;

          final child = Text(
            t.surface,
            style: TextStyle(
              fontSize: fontSize,
              height: 24 / fontSize,
              fontWeight:
                  (highlight || showFocus) ? FontWeight.w700 : FontWeight.w400,
              color: showFocus
                  ? _focusFg
                  : (highlight ? _hlFg : _text),
              decoration: t.isReview && !highlight && !showFocus
                  ? TextDecoration.underline
                  : TextDecoration.none,
            ),
          );

          if (isPunct && t.lemma.length <= 1) {
            return child;
          }

          Widget painted = child;
          if (showFocus) {
            painted = Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                color: _focusBg,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _focusBorder, width: 1.2),
              ),
              child: child,
            );
          } else if (highlight) {
            painted = Container(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: _hlBg,
                borderRadius: BorderRadius.circular(3),
              ),
              child: child,
            );
          }

          return GestureDetector(
            onTap: () => onTap(t),
            behavior: HitTestBehavior.opaque,
            child: painted,
          );
        }),
      ],
    );
  }
}
