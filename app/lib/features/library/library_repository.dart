import 'package:app_starter/core/network/api_client.dart';
import 'package:app_starter/features/library/library_models.dart';
import 'package:app_starter/features/lesson/lesson_models.dart';

class LibraryRepository {
  LibraryRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<LibraryPayload> list({String status = 'all'}) async {
    final json = await _api.get(
      '/api/lessons?status=$status',
      authed: true,
    );
    return LibraryPayload.fromJson(json);
  }

  Future<({Lesson lesson, GenerateQuota quota})> generate() async {
    final json = await _api.post('/api/lessons/generate', authed: true);
    final lessonRaw = json['lesson'];
    if (lessonRaw is! Map) {
      throw ApiException('生成结果异常');
    }
    return (
      lesson: Lesson.fromJson(Map<String, dynamic>.from(lessonRaw)),
      quota: GenerateQuota.fromJson(
        json['quota'] is Map
            ? Map<String, dynamic>.from(json['quota'] as Map)
            : null,
      ),
    );
  }
}
