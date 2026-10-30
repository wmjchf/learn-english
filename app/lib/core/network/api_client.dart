import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:app_starter/core/config/api_config.dart';
import 'package:app_starter/features/auth/auth_repository.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _client;
  final String _baseUrl;

  static Future<void> warmup() async {
    try {
      await ApiClient().get('/api/health').timeout(const Duration(seconds: 4));
    } catch (_) {}
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    String? accessToken,
    bool skipAuthRefresh = false,
    bool handleExpiry = true,
    bool authed = false,
  }) =>
      _request(
        'POST',
        path,
        body: body,
        accessToken: accessToken,
        skipAuthRefresh: skipAuthRefresh,
        handleExpiry: handleExpiry,
        authed: authed,
      );

  Future<Map<String, dynamic>> get(
    String path, {
    String? accessToken,
    bool skipAuthRefresh = false,
    bool handleExpiry = true,
    bool authed = false,
  }) =>
      _request(
        'GET',
        path,
        accessToken: accessToken,
        skipAuthRefresh: skipAuthRefresh,
        handleExpiry: handleExpiry,
        authed: authed,
      );

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    String? accessToken,
    bool skipAuthRefresh = false,
    bool handleExpiry = true,
    bool authed = false,
  }) =>
      _request(
        'PATCH',
        path,
        body: body,
        accessToken: accessToken,
        skipAuthRefresh: skipAuthRefresh,
        handleExpiry: handleExpiry,
        authed: authed,
      );

  Future<Map<String, dynamic>> delete(
    String path, {
    String? accessToken,
    bool skipAuthRefresh = false,
    bool handleExpiry = true,
    bool authed = false,
  }) =>
      _request(
        'DELETE',
        path,
        accessToken: accessToken,
        skipAuthRefresh: skipAuthRefresh,
        handleExpiry: handleExpiry,
        authed: authed,
      );

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? accessToken,
    bool skipAuthRefresh = false,
    bool handleExpiry = true,
    bool authed = false,
    bool isRetry = false,
  }) async {
    var token = accessToken;
    if (token == null && authed) {
      token = (await AuthRepository().readSession())?.accessToken;
    }

    final res = await _send(
      method,
      path,
      body: body,
      accessToken: token,
    );

    if (res.statusCode == 401 &&
        !skipAuthRefresh &&
        !isRetry &&
        token != null) {
      final next = await AuthRepository.tryRefreshAccessToken();
      if (next != null) {
        return _request(
          method,
          path,
          body: body,
          accessToken: next,
          skipAuthRefresh: skipAuthRefresh,
          handleExpiry: handleExpiry,
          authed: authed,
          isRetry: true,
        );
      }
      if (handleExpiry) {
        await AuthRepository.handleSessionExpired(
          message: _peekMessage(res) ?? '登录已过期，请重新登录',
        );
      } else {
        await AuthRepository().clearSession();
      }
      throw ApiException(
        _peekMessage(res) ?? '登录已过期，请重新登录',
        statusCode: 401,
      );
    }

    return _decode(res);
  }

  /// 成文接口常要 20–60s（偶发更久）；其余默认 30s。
  Duration _timeoutFor(String path) {
    final p = path.toLowerCase();
    if (p.contains('/lessons/today') ||
        p.contains('/lessons/generate') ||
        p.contains('/regenerate')) {
      return const Duration(seconds: 240);
    }
    return const Duration(seconds: 30);
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? accessToken,
  }) {
    final uri = Uri.parse('$_baseUrl$path');
    final headers = <String, String>{
      if (body != null) 'Content-Type': 'application/json',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };
    final encoded = body == null ? null : jsonEncode(body);
    final timeout = _timeoutFor(path);

    final Future<http.Response> future;
    switch (method) {
      case 'GET':
        future = _client.get(uri, headers: headers);
        break;
      case 'DELETE':
        future = _client.delete(uri, headers: headers);
        break;
      case 'PATCH':
        future = _client.patch(uri, headers: headers, body: encoded);
        break;
      case 'POST':
      default:
        future = _client.post(uri, headers: headers, body: encoded);
    }
    return future.timeout(
      timeout,
      onTimeout: () => throw ApiException('请求超时，请稍后重试'),
    );
  }

  String? _peekMessage(http.Response res) {
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['message'] is String) {
        return decoded['message'] as String;
      }
    } catch (_) {}
    return null;
  }

  Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(res.body);
      json = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{'data': decoded};
    } catch (_) {
      throw ApiException('服务响应异常', statusCode: res.statusCode);
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return json;
    }
    throw ApiException(
      (json['message'] as String?) ?? '请求失败',
      statusCode: res.statusCode,
      code: json['code'] as String?,
    );
  }
}
