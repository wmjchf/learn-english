import 'package:app_starter/core/network/api_client.dart';
import 'package:app_starter/features/onboarding/bank_models.dart';
import 'package:app_starter/features/profile/user_profile.dart';

class SelectBankResult {
  const SelectBankResult({required this.bank, this.profile});

  final WordBank bank;
  final UserProfile? profile;
}

class BankRepository {
  BankRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<List<WordBank>> list() async {
    final json = await _api.get('/api/banks', authed: true);
    final raw = json['items'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => WordBank.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<SelectBankResult> select(int bankId) async {
    final json = await _api.post(
      '/api/plans',
      body: {'bankId': bankId},
      authed: true,
    );
    return _parseSelect(json, bankId);
  }

  /// 画像内换库：不回退 onboarding，并重算预估天数。
  Future<SelectBankResult> switchBank(int bankId) async {
    final json = await _api.post(
      '/api/plans/switch-bank',
      body: {'bankId': bankId},
      authed: true,
    );
    return _parseSelect(json, bankId);
  }

  SelectBankResult _parseSelect(Map<String, dynamic> json, int bankId) {
    final bankJson = json['bank'];
    final profileJson = json['profile'];
    return SelectBankResult(
      bank: WordBank.fromJson(
        bankJson is Map
            ? Map<String, dynamic>.from(bankJson)
            : <String, dynamic>{
                'id': bankId,
                'code': '',
                'type': '',
                'title': '',
              },
      ),
      profile: profileJson is Map
          ? UserProfile.fromJson(Map<String, dynamic>.from(profileJson))
          : null,
    );
  }
}
