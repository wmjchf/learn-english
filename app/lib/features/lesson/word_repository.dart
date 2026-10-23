import 'package:app_starter/core/network/api_client.dart';
import 'package:app_starter/features/lesson/lesson_models.dart';

class WordLookupEntry {
  const WordLookupEntry({
    required this.surface,
    required this.lemma,
    required this.isTarget,
    required this.gloss,
    this.context,
    this.root,
    this.source,
  });

  final String surface;
  final String lemma;
  final bool isTarget;
  final String gloss;
  final String? context;
  final String? root;
  final String? source;

  LessonDef toDef() => LessonDef(
        gloss: gloss,
        context: context,
        root: root,
      );

  factory WordLookupEntry.fromJson(Map<String, dynamic>? json) {
    return WordLookupEntry(
      surface: json?['surface'] as String? ?? '',
      lemma: json?['lemma'] as String? ?? '',
      isTarget: json?['isTarget'] == true,
      gloss: json?['gloss'] as String? ?? '',
      context: json?['context'] as String?,
      root: json?['root'] as String?,
      source: json?['source'] as String?,
    );
  }
}

class WordRepository {
  WordRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<WordLookupEntry> lookup({
    required String surface,
    String? lemma,
    int? lessonId,
  }) async {
    final json = await _api.post(
      '/api/words/lookup',
      body: {
        'surface': surface,
        if (lemma != null && lemma.isNotEmpty) 'lemma': lemma,
        if (lessonId != null) 'lessonId': lessonId,
      },
      authed: true,
    );
    final raw = json['entry'];
    if (raw is! Map) {
      throw ApiException('释义数据异常');
    }
    return WordLookupEntry.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<void> markKnown(String lemma, {int? lessonId}) async {
    await _api.post(
      '/api/words/${Uri.encodeComponent(lemma)}/know',
      body: {
        if (lessonId != null) 'lessonId': lessonId,
      },
      authed: true,
    );
  }

  Future<void> markVocab(
    String lemma, {
    int? lessonId,
    String? gloss,
  }) async {
    await _api.post(
      '/api/words/${Uri.encodeComponent(lemma)}/vocab',
      body: {
        if (lessonId != null) 'lessonId': lessonId,
        if (gloss != null && gloss.isNotEmpty) 'gloss': gloss,
      },
      authed: true,
    );
  }
}
