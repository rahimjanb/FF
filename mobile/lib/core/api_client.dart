import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'token_storage.dart';

/// Error returned by the backend in ProblemDetails format, or a network failure (`code == 'network'`).
class ApiException implements Exception {
  ApiException(this.status, this.code, this.message, [this.fields = const {}]);

  final int status;
  final String code;
  final String message;
  final Map<String, List<String>> fields;

  @override
  String toString() => 'ApiException($status, $code, $message)';
}

/// Thin HTTP wrapper: JSON in/out, bearer token, transparent refresh-token rotation.
class ApiClient {
  ApiClient({required this.baseUrl, required this.tokens, http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final String baseUrl;
  final TokenStorage tokens;
  final http.Client _http;
  Future<bool>? _refreshing;

  /// Called when the session can no longer be refreshed (e.g. revoked or blocked account).
  void Function()? onSessionExpired;

  Future<dynamic> get(String path, {Map<String, String?>? query}) => _send('GET', path, query: query);
  Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body: body);
  Future<dynamic> put(String path, Object? body) => _send('PUT', path, body: body);

  Future<dynamic> _send(String method, String path, {Object? body, Map<String, String?>? query}) async {
    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: query == null
          ? null
          : {
              for (final e in query.entries)
                if (e.value != null) e.key: e.value!,
            },
    );
    var res = await _request(method, uri, body);
    if (res.statusCode == 401 && !path.startsWith('/api/auth/')) {
      if (await refresh()) {
        res = await _request(method, uri, body);
      } else {
        await tokens.clear();
        onSessionExpired?.call();
      }
    }
    if (res.statusCode >= 400) throw _parseError(res);
    if (res.statusCode == 204 || res.body.isEmpty) return null;
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  Future<http.Response> _request(String method, Uri uri, Object? body) async {
    final access = await tokens.accessToken();
    final request = http.Request(method, uri)..headers['Accept'] = 'application/json';
    if (access != null) request.headers['Authorization'] = 'Bearer $access';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    try {
      return await http.Response.fromStream(await _http.send(request).timeout(const Duration(seconds: 20)));
    } on TimeoutException {
      throw ApiException(0, 'network', 'Request timed out');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(0, 'network', 'Server unavailable');
    }
  }

  /// Rotates the refresh token. Concurrent callers share one refresh request.
  Future<bool> refresh() {
    return _refreshing ??= () async {
      try {
        final refreshToken = await tokens.refreshToken();
        if (refreshToken == null) return false;
        final res = await _http.post(
          Uri.parse('$baseUrl/api/auth/refresh'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': refreshToken}),
        );
        if (res.statusCode != 200) return false;
        final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        await tokens.save(json['accessToken'] as String, json['refreshToken'] as String);
        return true;
      } catch (_) {
        return false;
      } finally {
        _refreshing = null;
      }
    }();
  }

  ApiException _parseError(http.Response res) {
    try {
      final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final errors = (json['errors'] as Map<String, dynamic>? ?? {}).map(
        (k, v) => MapEntry(k, (v as List).cast<String>()),
      );
      return ApiException(res.statusCode, json['code'] as String? ?? 'error', json['title'] as String? ?? '', errors);
    } catch (_) {
      return ApiException(res.statusCode, 'error', 'HTTP ${res.statusCode}');
    }
  }
}
