import 'package:app_starter/core/network/api_client.dart';
import 'package:app_starter/features/profile/user_profile.dart';

class ProfileRepository {
  ProfileRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<UserProfile> fetch() async {
    final json = await _api.get('/api/profile', authed: true);
    return UserProfile.fromJson(json['profile'] as Map<String, dynamic>?);
  }

  Future<UserProfile> fetchMe() async {
    final json = await _api.get('/api/auth/me', authed: true);
    return UserProfile.fromJson(json['profile'] as Map<String, dynamic>?);
  }

  Future<UserProfile> patch(Map<String, dynamic> body) async {
    final json = await _api.patch('/api/profile', body: body, authed: true);
    return UserProfile.fromJson(json['profile'] as Map<String, dynamic>?);
  }
}
