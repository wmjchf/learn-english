import 'package:app_starter/core/network/api_client.dart';
import 'package:app_starter/features/today/today_models.dart';

class TodayRepository {
  TodayRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<TodayPayload> fetch() async {
    final json = await _api.get('/api/today', authed: true);
    final raw = json['today'];
    if (raw is! Map) {
      throw ApiException('今日数据异常');
    }
    return TodayPayload.fromJson(Map<String, dynamic>.from(raw));
  }

  /// AI 重写今日未读日课（替换种子稿）。
  Future<TodayPayload> regenerate() async {
    await _api.post('/api/lessons/today/regenerate', authed: true);
    return fetch();
  }
}
