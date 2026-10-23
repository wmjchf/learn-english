import 'package:app_starter/core/network/api_client.dart';
import 'package:app_starter/features/onboarding/assess_models.dart';

class AssessRepository {
  AssessRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<AssessTurn> start({String? startLevel}) async {
    final json = await _api.post(
      '/api/assess/sessions',
      body: {
        'startLevel': ?startLevel,
      },
      authed: true,
    );
    return AssessTurn.fromJson(json);
  }

  Future<AssessTurn> answer({
    required int sessionId,
    required String optionId,
  }) async {
    final json = await _api.post(
      '/api/assess/sessions/$sessionId/answer',
      body: {'optionId': optionId},
      authed: true,
    );
    return AssessTurn.fromJson(json);
  }

  Future<AssessTurn> finish({required int sessionId}) async {
    final json = await _api.post(
      '/api/assess/sessions/$sessionId/finish',
      body: const {},
      authed: true,
    );
    return AssessTurn.fromJson(json);
  }
}
