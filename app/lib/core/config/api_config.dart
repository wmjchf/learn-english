/// 后端 API 基址。
/// - 本地：`http://127.0.0.1:3001`
/// - 可用 `--dart-define=API_BASE_URL=...` 覆盖
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:3002',
  );
}
