import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

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

/// A file part of a multipart upload.
class UploadFile {
  const UploadFile(this.field, this.bytes, {required this.filename, required this.contentType});
  final String field;
  final Uint8List bytes;
  final String filename;
  final String contentType;
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

  /// How long a request may take unless the call says otherwise.
  static const defaultTimeout = Duration(seconds: 20);

  Future<dynamic> get(String path, {Map<String, String?>? query, Duration? timeout}) =>
      _send('GET', path, query: query, timeout: timeout);
  Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body: body);
  Future<dynamic> put(String path, Object? body) => _send('PUT', path, body: body);
  Future<dynamic> delete(String path) => _send('DELETE', path);

  /// A JSON request with a longer [timeout], for answers that take a while (an AI service).
  Future<dynamic> send(String method, String path, {Object? body, Map<String, String?>? query, Duration? timeout}) =>
      _send(method, path, body: body, query: query, timeout: timeout);

  /// Raw response body, e.g. an image that needs the bearer token.
  Future<Uint8List> getBytes(String path) async =>
      (await _exchange(path, null, (uri) => http.Request('GET', uri)..headers['Accept'] = '*/*')).bodyBytes;

  /// Sends a multipart/form-data PUT (file upload) and returns the decoded JSON answer.
  Future<dynamic> putMultipart(
    String path, {
    Map<String, String> fields = const {},
    List<UploadFile> files = const [],
    Duration? timeout,
  }) => _multipart('PUT', path, fields, files, timeout);

  /// Sends a multipart/form-data POST (file upload) and returns the decoded JSON answer.
  Future<dynamic> postMultipart(
    String path, {
    Map<String, String> fields = const {},
    List<UploadFile> files = const [],
    Duration? timeout,
  }) => _multipart('POST', path, fields, files, timeout);

  Future<dynamic> _multipart(
    String method,
    String path,
    Map<String, String> fields,
    List<UploadFile> files,
    Duration? timeout,
  ) async => _decode(
    await _exchange(
      path,
      null,
      // Built anew for each attempt: a request body can be sent only once (the retry after a token refresh).
      (uri) => http.MultipartRequest(method, uri)
        ..fields.addAll(fields)
        ..files.addAll([
          for (final f in files)
            http.MultipartFile.fromBytes(
              f.field,
              f.bytes,
              filename: f.filename,
              contentType: MediaType.parse(f.contentType),
            ),
        ]),
      timeout: timeout,
    ),
  );

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String?>? query,
    Duration? timeout,
  }) async => _decode(
    await _exchange(path, query, (uri) {
      final request = http.Request(method, uri);
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      return request;
    }, timeout: timeout),
  );

  dynamic _decode(http.Response res) =>
      res.statusCode == 204 || res.bodyBytes.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));

  /// Sends the request built by [build], refreshing the access token once on 401; throws [ApiException] on errors.
  Future<http.Response> _exchange(
    String path,
    Map<String, String?>? query,
    http.BaseRequest Function(Uri uri) build, {
    Duration? timeout,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: query == null
          ? null
          : {
              for (final e in query.entries)
                if (e.value != null) e.key: e.value!,
            },
    );
    var res = await _request(build(uri), timeout ?? defaultTimeout);
    if (res.statusCode == 401 && !path.startsWith('/api/auth/')) {
      if (await refresh()) {
        res = await _request(build(uri), timeout ?? defaultTimeout);
      } else {
        await tokens.clear();
        onSessionExpired?.call();
      }
    }
    if (res.statusCode >= 400) throw _parseError(res);
    return res;
  }

  Future<http.Response> _request(http.BaseRequest request, Duration timeout) async {
    final access = await tokens.accessToken();
    request.headers.putIfAbsent('Accept', () => 'application/json');
    if (access != null) request.headers['Authorization'] = 'Bearer $access';
    try {
      return await http.Response.fromStream(await _http.send(request).timeout(timeout));
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
