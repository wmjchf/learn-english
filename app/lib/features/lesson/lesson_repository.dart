import 'package:app_starter/core/network/api_client.dart';
import 'package:app_starter/features/lesson/lesson_models.dart';

class LessonRepository {
  LessonRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<Lesson> today() async {
    final json = await _api.get('/api/lessons/today', authed: true);
    final raw = json['lesson'];
    if (raw is! Map) {
      throw ApiException('日课数据异常');
    }
    return Lesson.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<Lesson> getById(int lessonId) async {
    final json = await _api.get('/api/lessons/$lessonId', authed: true);
    final raw = json['lesson'];
    if (raw is! Map) {
      throw ApiException('日课数据异常');
    }
    return Lesson.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<Lesson> open(int lessonId) async {
    final json = await _api.post(
      '/api/lessons/$lessonId/open',
      authed: true,
    );
    final raw = json['lesson'];
    if (raw is! Map) {
      throw ApiException('日课数据异常');
    }
    return Lesson.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<LessonCompleteResult> complete(
    int lessonId, {
    List<String> wrongLemmas = const [],
  }) async {
    final json = await _api.post(
      '/api/lessons/$lessonId/complete',
      body: {
        if (wrongLemmas.isNotEmpty) 'wrongLemmas': wrongLemmas,
      },
      authed: true,
    );
    final raw = json['lesson'];
    if (raw is! Map) {
      throw ApiException('日课数据异常');
    }
    final checkin = json['checkin'];
    return LessonCompleteResult(
      lesson: Lesson.fromJson(Map<String, dynamic>.from(raw)),
      streakDelta: checkin is Map
          ? (checkin['streakDelta'] as num?)?.toInt() ?? 0
          : 0,
      already: checkin is Map ? checkin['already'] == true : false,
      currentStreak: checkin is Map && checkin['streak'] is Map
          ? (checkin['streak']['currentStreak'] as num?)?.toInt()
          : null,
    );
  }
}

class LessonCompleteResult {
  const LessonCompleteResult({
    required this.lesson,
    required this.streakDelta,
    required this.already,
    this.currentStreak,
  });

  final Lesson lesson;
  final int streakDelta;
  final bool already;
  final int? currentStreak;
}
