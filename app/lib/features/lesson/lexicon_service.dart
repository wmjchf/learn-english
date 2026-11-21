import 'package:app_starter/core/network/api_client.dart';

class LexiconSynonym {
  const LexiconSynonym({required this.word, this.zh = ''});
  final String word;
  final String zh;

  factory LexiconSynonym.fromJson(Map<String, dynamic> json) {
    return LexiconSynonym(
      word: '${json['word'] ?? ''}',
      zh: '${json['zh'] ?? ''}',
    );
  }
}

class LexiconConfusable {
  const LexiconConfusable({required this.words, required this.note});
  final List<String> words;
  final String note;

  factory LexiconConfusable.fromJson(Map<String, dynamic> json) {
    final wordsRaw = json['words'];
    return LexiconConfusable(
      words: wordsRaw is List ? wordsRaw.map((e) => '$e').toList() : const [],
      note: '${json['note'] ?? ''}',
    );
  }
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

  factory LexiconRootFamilyMember.fromJson(Map<String, dynamic> json) {
    return LexiconRootFamilyMember(
      word: '${json['word'] ?? ''}',
      breakdown: '${json['breakdown'] ?? ''}',
      gloss: '${json['gloss'] ?? ''}',
    );
  }
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

  factory LexiconRoot.fromJson(Map<String, dynamic> json) {
    final familyRaw = json['family'];
    return LexiconRoot(
      id: '${json['id'] ?? ''}',
      key: '${json['key'] ?? ''}',
      meaning: '${json['meaning'] ?? ''}',
      etym: '${json['etym'] ?? ''}',
      family: familyRaw is List
          ? familyRaw
              .whereType<Map>()
              .map(
                (e) => LexiconRootFamilyMember.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList()
          : const [],
    );
  }
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

  factory LexiconEntry.fromJson(Map<String, dynamic> json) {
    final synRaw = json['synonyms'];
    final confRaw = json['confusables'];
    final senseRaw = json['senses'];
    final rootRaw = json['root'];
    return LexiconEntry(
      lemma: '${json['lemma'] ?? ''}',
      breakdown: '${json['breakdown'] ?? ''}',
      gloss: '${json['gloss'] ?? ''}',
      rootId: '${json['rootId'] ?? ''}',
      synonyms: synRaw is List
          ? synRaw
              .whereType<Map>()
              .map((e) => LexiconSynonym.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      confusables: confRaw is List
          ? confRaw
              .whereType<Map>()
              .map(
                (e) => LexiconConfusable.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList()
          : const [],
      senses: senseRaw is List ? senseRaw.map((e) => '$e').toList() : const [],
      root: rootRaw is Map
          ? LexiconRoot.fromJson(Map<String, dynamic>.from(rootRaw))
          : null,
    );
  }
}

/// 词根 / 同义 / 易混：走后端 `GET /api/lexicon/:lemma`，进程内缓存。
class LexiconService {
  LexiconService._();
  static final LexiconService instance = LexiconService._();

  final ApiClient _api = ApiClient();
  final Map<String, LexiconEntry?> _cache = {};

  Future<LexiconEntry?> lookup(String lemma) async {
    final key = lemma.trim().toLowerCase().replaceAll(RegExp(r"[^a-z'-]"), '');
    if (key.isEmpty) return null;
    if (_cache.containsKey(key)) return _cache[key];

    try {
      final json = await _api.get(
        '/api/lexicon/${Uri.encodeComponent(key)}',
        authed: true,
      );
      final raw = json['entry'];
      if (raw is! Map) {
        _cache[key] = null;
        return null;
      }
      final entry = LexiconEntry.fromJson(Map<String, dynamic>.from(raw));
      _cache[key] = entry;
      return entry;
    } catch (_) {
      // 离线 / 未灌库时不打断点词主流程
      _cache[key] = null;
      return null;
    }
  }
}
