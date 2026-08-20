import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Exception réseau/API avec un message déjà présentable à l'utilisateur terrain.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final bool networkError; // true = pas de réseau/serveur injoignable (candidat à la mise en file offline)
  ApiException(this.message, {this.statusCode, this.networkError = false});
  @override
  String toString() => message;
}

/// Client API unique pour toute l'application (Android / Windows / Web).
/// L'URL du serveur est configurable au runtime (écran Réglages) car
/// `localhost` ne fonctionne pas depuis un téléphone Android : l'agent
/// terrain doit pouvoir pointer vers l'adresse réelle du serveur QHSE
/// sans recompiler l'application.
class Api {
  // Valeur de compilation par défaut, surchageable via
  // `flutter build apk --dart-define=API_BASE_URL=https://qhse.mibem.com/api/v4`
  static const String _compileTimeDefault =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:3000/api/v4');

  static String _baseUrl = _compileTimeDefault;
  static bool _loaded = false;
  static const _timeout = Duration(seconds: 15);

  /// Appelé automatiquement quand le serveur répond 401 (jeton expiré/invalide).
  /// Défini par [HomeShell] pour rediriger vers l'écran de connexion.
  static void Function()? onUnauthorized;

  static Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final p = await SharedPreferences.getInstance();
    final saved = p.getString('api_base_url');
    if (saved != null && saved.trim().isNotEmpty) _baseUrl = saved.trim();
    _loaded = true;
  }

  static Future<String> currentBaseUrl() async {
    await _ensureLoaded();
    return _baseUrl;
  }

  static Future<void> setBaseUrl(String url) async {
    var u = url.trim();
    if (u.endsWith('/')) u = u.substring(0, u.length - 1);
    _baseUrl = u;
    _loaded = true;
    final p = await SharedPreferences.getInstance();
    await p.setString('api_base_url', u);
  }

  Future<String?> token() async => (await SharedPreferences.getInstance()).getString('token');

  Future<Map<String, String>> _h() async {
    final t = await token();
    return {if (t != null) 'Authorization': 'Bearer $t'};
  }

  Future<dynamic> get(String path) => _send('GET', path);
  Future<dynamic> post(String path, Map body) => _send('POST', path, body: body);
  Future<dynamic> patch(String path, Map body) => _send('PATCH', path, body: body);
  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(String method, String path, {Map? body}) async {
    await _ensureLoaded();
    final uri = Uri.parse('$_baseUrl$path');
    final headers = {...await _h(), if (body != null) 'Content-Type': 'application/json'};
    try {
      late http.Response r;
      switch (method) {
        case 'GET':
          r = await http.get(uri, headers: headers).timeout(_timeout);
          break;
        case 'POST':
          r = await http.post(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(_timeout);
          break;
        case 'PATCH':
          r = await http.patch(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(_timeout);
          break;
        case 'DELETE':
          r = await http.delete(uri, headers: headers).timeout(_timeout);
          break;
      }
      return _decode(r);
    } on TimeoutException {
      throw ApiException('Le serveur ne répond pas (délai dépassé). Vérifiez l\'adresse configurée dans Réglages.', networkError: true);
    } on SocketException {
      throw ApiException('Serveur injoignable. Vérifiez votre connexion et l\'adresse du serveur dans Réglages.', networkError: true);
    } on http.ClientException {
      throw ApiException('Connexion impossible au serveur QHSE.', networkError: true);
    }
  }

  dynamic _decode(http.Response r) {
    if (r.statusCode == 401) {
      onUnauthorized?.call();
      throw ApiException('Session expirée, veuillez vous reconnecter.', statusCode: 401);
    }
    if (r.statusCode >= 400) {
      String msg = 'Erreur serveur (${r.statusCode})';
      try {
        final body = jsonDecode(r.body);
        if (body is Map && body['message'] != null) {
          msg = body['message'] is List ? (body['message'] as List).join(', ') : '${body['message']}';
        }
      } catch (_) {}
      throw ApiException(msg, statusCode: r.statusCode);
    }
    if (r.body.isEmpty) return null;
    return jsonDecode(r.body);
  }

  /// Vérifie que le serveur répond, utilisé par l'écran Réglages pour tester
  /// une adresse avant de la sauvegarder.
  Future<bool> ping(String url) async {
    try {
      var u = url.trim();
      if (u.endsWith('/')) u = u.substring(0, u.length - 1);
      final r = await http.get(Uri.parse('$u/health')).timeout(const Duration(seconds: 8));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // --- Session : jeton + profil utilisateur, persistés localement ---
  Future<void> saveSession(String token, Map<String, dynamic> user) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('token', token);
    await p.setString('user', jsonEncode(user));
  }

  Future<Map<String, dynamic>?> currentUser() async {
    final s = (await SharedPreferences.getInstance()).getString('user');
    return s == null ? null : Map<String, dynamic>.from(jsonDecode(s));
  }

  Future<void> logout() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('token');
    await p.remove('user');
  }
}
