import 'dart:convert';

import 'package:flutter/services.dart';

class LexiconSynonym {
  const LexiconSynonym({required this.word, this.zh = ''});
  final String word;
  final String zh;
}

class LexiconConfusable {
  const LexiconConfusable({required this.words, required this.note});
  final List<String> words;
  final String note;
}

class LexiconRootFamilyMember {
  const LexiconRootFamilyMember({
    required this.word,
    required this.breakdown,
    required this.gloss,
  });
  final String word;
  final String breakdown;
  final String gloss;
}

class LexiconRoot {
  const LexiconRoot({
    required this.id,
    required this.key,
    required this.meaning,
    required this.etym,
    required this.family,
  });
  final String id;
  final String key;
  final String meaning;
  final String etym;
  final List<LexiconRootFamilyMember> family;
}

class LexiconEntry {
  const LexiconEntry({
    required this.lemma,
    this.breakdown = '',
    this.gloss = '',
    this.rootId = '',
    this.synonyms = const [],
    this.confusables = const [],
    this.senses = const [],
    this.root,
  });

  final String lemma;
  final String breakdown;
  final String gloss;
  final String rootId;
  final List<LexiconSynonym> synonyms;
  final List<LexiconConfusable> confusables;
  final List<String> senses;
  final LexiconRoot? root;

  bool get hasRootDetail =>
      breakdown.isNotEmpty || (root != null && root!.family.isNotEmpty);

  bool get hasRelationRow =>
      synonyms.isNotEmpty || confusables.isNotEmpty || senses.length > 1;

  String get relationSummary {
    final parts = <String>[];
    if (synonyms.isNotEmpty) {
      final words = synonyms.take(2).map((s) => s.word).join(' / ');
      parts.add('近义 · $words');
    }
    if (confusables.isNotEmpty) {
      final c = confusables.first;
      final others = c.words.take(2).join(' / ');
      parts.add(others.isEmpty ? '易混区分' : '易混 · $others');
    }
    if (senses.length > 1) {
      parts.add('多义 · ${senses.first}');
    }
    return parts.join('　');
  }
}

/// 本地词根 / 同义 / 易混索引（assets/lexicon/lemma_index.json）。
class LexiconService {
  LexiconService._();
  static final LexiconService instance = LexiconService._();

  Map<String, dynamic>? _roots;
  Map<String, dynamic>? _lemmas;
  Future<void>? _loading;

  Future<void> ensureLoaded() {
    if (_lemmas != null) return Future.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    final raw = await rootBundle.loadString('assets/lexicon/lemma_index.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    _roots = Map<String, dynamic>.from(json['roots'] as Map? ?? {});
    _lemmas = Map<String, dynamic>.from(json['lemmas'] as Map? ?? {});
  }

  LexiconRoot? _parseRoot(String id) {
    final raw = _roots?[id];
    if (raw is! Map) return null;
    final familyRaw = raw['f'];
    final family = <LexiconRootFamilyMember>[];
    if (familyRaw is List) {
      for (final row in familyRaw) {
        if (row is! List || row.isEmpty) continue;
        family.add(
          LexiconRootFamilyMember(
            word: '${row[0]}',
            breakdown: row.length > 1 ? '${row[1]}' : '',
            gloss: row.length > 2 ? '${row[2]}' : '',
          ),
        );
      }
    }
    return LexiconRoot(
      id: id,
      key: '${raw['k'] ?? ''}',
      meaning: '${raw['m'] ?? ''}',
      etym: '${raw['e'] ?? ''}',
      family: family,
    );
  }

  Future<LexiconEntry?> lookup(String lemma) async {
    await ensureLoaded();
    final key = lemma.trim().toLowerCase().replaceAll(RegExp(r"[^a-z'-]"), '');
    if (key.isEmpty) return null;
    final raw = _lemmas?[key];
    if (raw is! Map) return null;

    final synonyms = <LexiconSynonym>[];
    final synRaw = raw['s'];
    if (synRaw is List) {
      for (final row in synRaw) {
        if (row is List && row.isNotEmpty) {
          synonyms.add(
            LexiconSynonym(
              word: '${row[0]}',
              zh: row.length > 1 ? '${row[1]}' : '',
            ),
          );
        }
      }
    }

    final confusables = <LexiconConfusable>[];
    final confRaw = raw['c'];
    if (confRaw is List) {
      for (final row in confRaw) {
        if (row is! List || row.length < 2) continue;
        final wordsRaw = row[0];
        final words = wordsRaw is List
            ? wordsRaw.map((e) => '$e').toList()
            : <String>[];
        confusables.add(
          LexiconConfusable(words: words, note: '${row[1]}'),
        );
      }
    }

    final senses = <String>[];
    final senseRaw = raw['m'];
    if (senseRaw is List) {
      for (final s in senseRaw) {
        senses.add('$s');
      }
    }

    final rootId = '${raw['r'] ?? ''}';
    return LexiconEntry(
      lemma: key,
      breakdown: '${raw['b'] ?? ''}',
      gloss: '${raw['g'] ?? ''}',
      rootId: rootId,
      synonyms: synonyms,
      confusables: confusables,
      senses: senses,
      root: rootId.isEmpty ? null : _parseRoot(rootId),
    );
  }
}
