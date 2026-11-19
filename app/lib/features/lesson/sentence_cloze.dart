import 'package:app_starter/features/lesson/lesson_models.dart';

/// 一页例句回填：一句英文，可含 1+ 个挖空（同句多词合填）。
class SentenceClozePageData {
  const SentenceClozePageData({
    required this.sentenceBlanked,
    required this.blanks,
  });

  /// 挖空后的句子，空位为 `________`
  final String sentenceBlanked;
  final List<SentenceClozeBlank> blanks;
}

class SentenceClozeBlank {
  const SentenceClozeBlank({
    required this.answer,
    required this.hintZh,
    required this.surface,
  });

  /// 判定用（lemma / 原形优先）
  final String answer;
  final String hintZh;
  /// 文中实际词形（填入/朗读用）
  final String surface;
}

String _cleanLemma(String raw) =>
    raw.trim().toLowerCase().replaceAll(RegExp(r"[^a-z'-]"), '');

List<String> _splitSentences(String plain) {
  final text = plain.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.isEmpty) return const [];
  final out = <String>[];
  final re = RegExp(r'[^.!?]+[.!?]+|[^.!?]+$');
  for (final m in re.allMatches(text)) {
    final s = m.group(0)!.trim();
    if (s.isNotEmpty) out.add(s);
  }
  return out;
}

/// 在句中找 lemma 的实际词形（含简单屈折）。
RegExp _lemmaPattern(String lemma) {
  final esc = RegExp.escape(lemma);
  // relocate → relocating / relocated / relocates
  if (lemma.endsWith('e')) {
    final stem = RegExp.escape(lemma.substring(0, lemma.length - 1));
    return RegExp(
      '\\b($esc(?:s|d)?|${stem}ing|${stem}ed)\\b',
      caseSensitive: false,
    );
  }
  return RegExp(
    '\\b($esc(?:s|es|ed|ing)?)\\b',
    caseSensitive: false,
  );
}

({String surface, int start, int end})? _findSurface(String sentence, String lemma) {
  final m = _lemmaPattern(lemma).firstMatch(sentence);
  if (m == null) return null;
  return (surface: m.group(1)!, start: m.start, end: m.end);
}

String _hintFor(LessonContent content, String lemma) {
  final gloss = content.defFor(lemma)?.gloss.trim() ?? '';
  if (gloss.isNotEmpty) return gloss;
  // 旧 cloze 题提示兜底
  for (final c in content.cloze) {
    if (_cleanLemma(c.answer) == lemma && c.hintZh.trim().isNotEmpty) {
      return c.hintZh.trim();
    }
  }
  return lemma;
}

String _blankSentence(String sentence, List<({String surface, int start, int end, String lemma})> hits) {
  final ordered = [...hits]..sort((a, b) => b.start.compareTo(a.start));
  var out = sentence;
  for (final h in ordered) {
    out = out.replaceRange(h.start, h.end, '________');
  }
  return out;
}

/// 从短文拆句组题：同句多词合填；一词一句则一页一词。
List<SentenceClozePageData> buildSentenceClozePages(LessonContent content) {
  final targets = <String>[
    for (final raw in content.targetLemmas)
      if (_cleanLemma(raw).isNotEmpty) _cleanLemma(raw),
  ];
  final used = <String>{};
  final pages = <SentenceClozePageData>[];

  for (final sentence in _splitSentences(content.article.enPlain)) {
    final hits = <({String surface, int start, int end, String lemma})>[];
    for (final lemma in targets) {
      if (used.contains(lemma)) continue;
      final found = _findSurface(sentence, lemma);
      if (found == null) continue;
      hits.add((
        surface: found.surface,
        start: found.start,
        end: found.end,
        lemma: lemma,
      ));
    }
    if (hits.isEmpty) continue;
    hits.sort((a, b) => a.start.compareTo(b.start));
    for (final h in hits) {
      used.add(h.lemma);
    }
    pages.add(
      SentenceClozePageData(
        sentenceBlanked: _blankSentence(sentence, hits),
        blanks: [
          for (final h in hits)
            SentenceClozeBlank(
              answer: h.lemma,
              hintZh: _hintFor(content, h.lemma),
              surface: h.surface,
            ),
        ],
      ),
    );
  }

  // 短文未覆盖的词：优先 defs 例句，其次旧 cloze，再兜底句
  for (final lemma in targets) {
    if (used.contains(lemma)) continue;
    used.add(lemma);
    final def = content.defFor(lemma);
    final example = (def?.exampleEn ?? '').trim();
    String sentence;
    String surface = lemma;
    if (example.isNotEmpty) {
      final found = _findSurface(example, lemma);
      if (found != null) {
        surface = found.surface;
        sentence = example.replaceRange(found.start, found.end, '________');
      } else {
        sentence = example.contains(lemma)
            ? example.replaceFirst(RegExp(lemma, caseSensitive: false), '________')
            : '$example (________)';
      }
    } else {
      ClozeItem? cloze;
      for (final c in content.cloze) {
        if (_cleanLemma(c.answer) == lemma) {
          cloze = c;
          break;
        }
      }
      if (cloze != null && cloze.sentence.trim().isNotEmpty) {
        sentence = cloze.sentence.contains('________')
            ? cloze.sentence
            : cloze.sentence.replaceFirst(
                RegExp(RegExp.escape(lemma), caseSensitive: false),
                '________',
              );
        if (!sentence.contains('________')) {
          sentence = '${cloze.sentence} ________';
        }
      } else {
        sentence = 'Remember the word ________ in today\'s context.';
      }
    }
    pages.add(
      SentenceClozePageData(
        sentenceBlanked: sentence,
        blanks: [
          SentenceClozeBlank(
            answer: lemma,
            hintZh: _hintFor(content, lemma),
            surface: surface,
          ),
        ],
      ),
    );
  }

  return pages;
}
