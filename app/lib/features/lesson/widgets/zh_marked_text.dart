import 'package:flutter/material.dart';

/// 中文译文：将 【…】 或额外短语标成与目标词同款黄底。
class ZhMarkedText extends StatelessWidget {
  const ZhMarkedText({
    super.key,
    required this.text,
    this.extraHighlights = const [],
    this.fontSize = 14,
    this.color = const Color(0xFF334155),
  });

  final String text;
  final List<String> extraHighlights;
  final double fontSize;
  final Color color;

  static const _hlBg = Color(0xFFFFF3C4);
  static const _hlFg = Color(0xFF8A5A00);

  @override
  Widget build(BuildContext context) {
    final spans = _buildSpans(text, extraHighlights, fontSize);
    if (spans.isEmpty) return const SizedBox.shrink();
    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          height: 22 / fontSize,
          color: color,
        ),
        children: spans,
      ),
    );
  }

  static List<InlineSpan> _buildSpans(
    String raw,
    List<String> extras,
    double fontSize,
  ) {
    final marked = <_Seg>[];
    final re = RegExp(r'【([^】]+)】');
    var start = 0;
    for (final m in re.allMatches(raw)) {
      if (m.start > start) {
        marked.add(_Seg(raw.substring(start, m.start), false));
      }
      marked.add(_Seg(m.group(1) ?? '', true));
      start = m.end;
    }
    if (start < raw.length) {
      marked.add(_Seg(raw.substring(start), false));
    }
    if (marked.isEmpty && raw.isNotEmpty) {
      marked.add(_Seg(raw, false));
    }

    final phrases = extras
        .map((e) => e.trim())
        .where((e) => e.length >= 2)
        .toSet()
        .toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    final out = <InlineSpan>[];
    for (final seg in marked) {
      if (seg.hl || phrases.isEmpty) {
        out.add(_span(seg.text, seg.hl, fontSize));
        continue;
      }
      out.addAll(_highlightPhrases(seg.text, phrases, fontSize));
    }
    return out;
  }

  static List<InlineSpan> _highlightPhrases(
    String text,
    List<String> phrases,
    double fontSize,
  ) {
    if (text.isEmpty) return const [];
    // 找最早出现的最长短语
    var bestStart = -1;
    var bestLen = 0;
    String? best;
    for (final p in phrases) {
      final i = text.indexOf(p);
      if (i < 0) continue;
      if (bestStart < 0 ||
          i < bestStart ||
          (i == bestStart && p.length > bestLen)) {
        bestStart = i;
        bestLen = p.length;
        best = p;
      }
    }
    if (best == null || bestStart < 0) {
      return [_span(text, false, fontSize)];
    }
    return [
      if (bestStart > 0)
        ..._highlightPhrases(text.substring(0, bestStart), phrases, fontSize),
      _span(best, true, fontSize),
      if (bestStart + bestLen < text.length)
        ..._highlightPhrases(
          text.substring(bestStart + bestLen),
          phrases,
          fontSize,
        ),
    ];
  }

  static InlineSpan _span(String text, bool hl, double fontSize) {
    if (text.isEmpty) return const TextSpan(text: '');
    if (!hl) return TextSpan(text: text);
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.ideographic,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: _hlBg,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            height: 22 / fontSize,
            fontWeight: FontWeight.w700,
            color: _hlFg,
          ),
        ),
      ),
    );
  }
}

class _Seg {
  const _Seg(this.text, this.hl);
  final String text;
  final bool hl;
}

/// 从释义里抽可用于标亮的中文片段。
List<String> glossHighlightPhrases(Iterable<String> glosses) {
  final out = <String>{};
  for (final raw in glosses) {
    final g = raw.trim();
    if (g.isEmpty) continue;
    for (final part in g.split(RegExp(r'[；;，,/、|]'))) {
      final p = part.trim().replaceAll(RegExp(r'^[a-zA-Z.\s]+'), '').trim();
      if (p.length >= 2 && p.length <= 8 && RegExp(r'[\u4e00-\u9fff]').hasMatch(p)) {
        out.add(p);
      }
    }
  }
  return out.toList();
}
