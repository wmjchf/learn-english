import 'package:flutter/material.dart';
import 'package:app_starter/features/lesson/lesson_models.dart';

typedef TokenTap = void Function(LessonToken token);

/// 英文 token 流：目标词黄底高亮，可点。
class TokenText extends StatelessWidget {
  const TokenText({
    super.key,
    required this.tokens,
    required this.onTap,
    this.knownLemmas = const {},
    this.tempHighlightLemmas = const {},
    this.leading,
    this.fontSize = 13,
  });

  final List<LessonToken> tokens;
  final TokenTap onTap;
  final Set<String> knownLemmas;
  final Set<String> tempHighlightLemmas;
  final Widget? leading;
  final double fontSize;

  static const _text = Color(0xFF17202E);
  static const _hlBg = Color(0xFFFFF3C4);
  static const _hlFg = Color(0xFF8A5A00);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 3,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ?leading,
        ...tokens.map((t) {
          final isPunct = RegExp(r"^[.,!?;:—\-']+$").hasMatch(t.surface);
          final showTarget = t.isTarget &&
              !knownLemmas.contains(t.lemma) &&
              t.lemma.isNotEmpty;
          final showTemp = tempHighlightLemmas.contains(t.lemma);
          final highlight = showTarget || showTemp;

          final child = Text(
            t.surface,
            style: TextStyle(
              fontSize: fontSize,
              height: 18 / fontSize,
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w400,
              color: highlight ? _hlFg : _text,
              decoration: t.isReview && !highlight
                  ? TextDecoration.underline
                  : TextDecoration.none,
            ),
          );

          if (isPunct && t.lemma.length <= 1) {
            return child;
          }

          return GestureDetector(
            onTap: () => onTap(t),
            behavior: HitTestBehavior.opaque,
            child: highlight
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: _hlBg,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: child,
                  )
                : child,
          );
        }),
      ],
    );
  }
}
