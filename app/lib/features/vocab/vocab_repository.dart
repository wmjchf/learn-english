import 'package:app_starter/core/network/api_client.dart';
import 'package:app_starter/features/vocab/vocab_models.dart';

class VocabRepository {
  VocabRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<VocabPayload> list({String bucket = 'consolidating'}) async {
    final json = await _api.get(
      '/api/words?bucket=$bucket',
      authed: true,
    );
    return VocabPayload.fromJson(json);
  }

  Future<List<VocabItem>> dueReviews() async {
    final json = await _api.get('/api/words/due', authed: true);
    final raw = json['items'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => VocabItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> answerReview({required String lemma, required bool know}) async {
    await _api.post(
      '/api/words/review',
      body: {'lemma': lemma, 'know': know},
      authed: true,
    );
  }

  /// 复习会话结束打卡（只复习也可保连胜）
  Future<({int streakDelta, bool already, int? currentStreak})>
      completeReview() async {
    final json = await _api.post(
      '/api/words/review/complete',
      authed: true,
    );
    final checkin = json['checkin'];
    if (checkin is! Map) {
      return (streakDelta: 0, already: false, currentStreak: null);
    }
    final streak = checkin['streak'];
    return (
      streakDelta: (checkin['streakDelta'] as num?)?.toInt() ?? 0,
      already: checkin['already'] == true,
      currentStreak: streak is Map
          ? (streak['currentStreak'] as num?)?.toInt()
          : null,
    );
  }

  Future<void> markKnown(String lemma, {int? lessonId}) async {
    final path = '/api/words/${Uri.encodeComponent(lemma)}/know';
    await _api.post(
      path,
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
    final path = '/api/words/${Uri.encodeComponent(lemma)}/vocab';
    await _api.post(
      path,
      body: {
        if (lessonId != null) 'lessonId': lessonId,
        if (gloss != null && gloss.isNotEmpty) 'gloss': gloss,
      },
      authed: true,
    );
  }
}
