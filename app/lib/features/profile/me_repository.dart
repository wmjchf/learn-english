import 'package:app_starter/core/network/api_client.dart';
import 'package:app_starter/features/profile/me_models.dart';
import 'package:app_starter/features/profile/user_profile.dart';

class MeRepository {
  MeRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<MeSummary> fetch() async {
    final json = await _api.get('/api/me', authed: true);
    final raw = json['me'];
    if (raw is! Map) {
      throw ApiException('我的页数据异常');
    }
    return MeSummary.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<UserProfile> bumpGenerationLevel(int delta) async {
    final json = await _api.post(
      '/api/profile/generation-level',
      body: {'delta': delta},
      authed: true,
    );
    return UserProfile.fromJson(json['profile'] as Map<String, dynamic>?);
  }
}
