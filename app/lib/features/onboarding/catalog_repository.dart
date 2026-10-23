import 'package:app_starter/core/network/api_client.dart';
import 'package:app_starter/features/onboarding/catalog_models.dart';

class CatalogRepository {
  CatalogRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<CatalogList> interests() => _load('/api/catalog/interests');

  Future<CatalogList> scenes() => _load('/api/catalog/scenes');

  Future<CatalogList> jobs() => _load('/api/catalog/jobs');

  Future<CatalogList> _load(String path) async {
    final json = await _api.get(path, authed: true);
    return CatalogList.fromJson(json);
  }
}
