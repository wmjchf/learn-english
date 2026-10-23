import 'package:app_starter/core/network/api_client.dart';
import 'package:app_starter/features/onboarding/plan_models.dart';

class PlanRepository {
  PlanRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<PlanContext> context() async {
    final json = await _api.get('/api/plans/context', authed: true);
    return PlanContext.fromJson(json);
  }

  Future<PlanEstimate> estimate({int? minutes, int? days}) async {
    final q = <String, String>{
      if (minutes != null) 'minutes': '$minutes',
      if (days != null) 'days': '$days',
    };
    final qs = q.entries.map((e) => '${e.key}=${e.value}').join('&');
    final path =
        qs.isEmpty ? '/api/plans/estimate' : '/api/plans/estimate?$qs';
    final json = await _api.get(path, authed: true);
    return PlanEstimate.fromJson(json['estimate'] as Map<String, dynamic>?);
  }

  Future<PlanReady> confirm({required int minutes, required int days}) async {
    final json = await _api.post(
      '/api/plans/confirm',
      body: {'minutes': minutes, 'days': days},
      authed: true,
    );
    return PlanReady.fromJson(json['ready'] as Map<String, dynamic>?);
  }
}
