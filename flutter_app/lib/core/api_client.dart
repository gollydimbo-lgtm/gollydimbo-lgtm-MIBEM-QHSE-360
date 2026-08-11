import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

/// Enveloppe http avec injection automatique du Bearer token et un unique
/// retry transparent si l'access token a expiré (401 -> refresh -> replay).
class ApiClient {
  final AuthService authService;

  ApiClient(this.authService);

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$apiBaseUrl$path').replace(queryParameters: query);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (authService.accessToken != null)
          'Authorization': 'Bearer ${authService.accessToken}',
      };

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _withRetry(() => http.get(_uri(path, query), headers: _headers));

  Future<dynamic> post(String path, Map<String, dynamic> body) => _withRetry(
        () => http.post(_uri(path), headers: _headers, body: jsonEncode(body)),
      );

  Future<dynamic> patch(String path, Map<String, dynamic> body) => _withRetry(
        () => http.patch(_uri(path), headers: _headers, body: jsonEncode(body)),
      );

  Future<dynamic> _withRetry(Future<http.Response> Function() call) async {
    var response = await call();
    if (response.statusCode == 401) {
      final refreshed = await authService.tryRefresh();
      if (refreshed) {
        response = await call();
      }
    }
    return _decode(response);
  }

  dynamic _decode(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }
    String message = 'Erreur ${response.statusCode}';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['message'] != null) {
        message = decoded['message'];
      }
    } catch (_) {
      // corps non-JSON, on garde le message générique
    }
    throw ApiException(response.statusCode, message);
  }
}
