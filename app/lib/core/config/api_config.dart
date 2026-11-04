/// 后端 API 基址。
///
/// - 本地默认：`http://127.0.0.1:3002`
/// - 测试服：`http://47.97.67.47:3003`
/// - 生产：`https://wordx.wobufang.com`
///
/// 用法：
/// ```bash
/// flutter run --dart-define=API_ENV=prod
/// flutter run --dart-define=API_ENV=test
/// # 或直接覆盖：
/// flutter run --dart-define=API_BASE_URL=https://wordx.wobufang.com
/// ```
class ApiConfig {
  static const String localUrl = 'http://127.0.0.1:3002';
  static const String testUrl = 'http://47.97.67.47:3003';
  static const String prodUrl = 'https://wordx.wobufang.com';

  static const String _env = String.fromEnvironment(
    'API_ENV',
    defaultValue: 'local',
  );

  static const String _override = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override.replaceAll(RegExp(r'/+$'), '');
    switch (_env) {
      case 'prod':
      case 'production':
        return prodUrl;
      case 'test':
        return testUrl;
      default:
        return localUrl;
    }
  }

  static bool get isTest => baseUrl == testUrl || _env == 'test';

  static bool get isProd =>
      baseUrl == prodUrl || _env == 'prod' || _env == 'production';
}
