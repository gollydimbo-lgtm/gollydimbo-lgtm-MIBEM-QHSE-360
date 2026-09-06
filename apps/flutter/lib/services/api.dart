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
///
/// Gère deux jetons, comme le tableau de bord web : un accès court (15 min)
/// et un rafraîchissement long (30 jours). Un minuteur renouvelle l'accès
/// tout seul un peu avant expiration — en usage normal, l'agent ne devrait
/// plus jamais voir de déconnexion liée à l'expiration du jeton.
class Api {
  // Valeur de compilation par défaut, surchageable via
  // `flutter build apk --dart-define=API_BASE_URL=https://qhse.mibem.com/api/v4`
  static const String _compileTimeDefault =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:3000/api/v4');

  static String _baseUrl = _compileTimeDefault;
  static bool _loaded = false;
  static const _timeout = Duration(seconds: 15);
  static Timer? _refreshTimer;
  static Future<void>? _refreshInFlight;

  /// Appelé automatiquement quand le serveur répond 401 (jeton expiré/invalide)
  /// ET que le rafraîchissement automatique a lui-même échoué. Défini par
  /// [HomeShell] pour rediriger vers l'écran de connexion.
  static void Function()? onUnauthorized;

  static Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final p = await SharedPreferences.getInstance();
    final saved = p.getString('api_base_url');
    if (saved != null && saved.trim().isNotEmpty) _baseUrl = saved.trim();
    _loaded = true;
    final token = p.getString('token');
    if (token != null) _scheduleProactiveRefresh(token);
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
  Future<String?> _storedRefreshToken() async => (await SharedPreferences.getInstance()).getString('refresh_token');

  // Décode la partie centrale d'un JWT pour lire sa date d'expiration —
  // aucune vérification de signature ici, seulement une lecture locale.
  static DateTime? _decodeJwtExpiry(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      switch (payload.length % 4) { case 2: payload += '=='; break; case 3: payload += '='; break; }
      final map = jsonDecode(utf8.decode(base64.decode(payload))) as Map<String, dynamic>;
      final exp = map['exp'];
      return exp == null ? null : DateTime.fromMillisecondsSinceEpoch((exp as int) * 1000);
    } catch (_) { return null; }
  }

  static void _scheduleProactiveRefresh(String accessToken) {
    _refreshTimer?.cancel();
    final exp = _decodeJwtExpiry(accessToken);
    if (exp == null) return;
    final delay = exp.difference(DateTime.now()) - const Duration(minutes: 1);
    _refreshTimer = Timer(delay.isNegative ? const Duration(seconds: 5) : delay, () { Api()._refresh(); });
  }

  Future<bool> _refresh() {
    return (_refreshInFlight ??= _doRefresh()).then((_) => true).catchError((_) => false).whenComplete(() { _refreshInFlight = null; });
  }

  Future<void> _doRefresh() async {
    final refreshToken = await _storedRefreshToken();
    if (refreshToken == null) throw ApiException('Aucun jeton de rafraîchissement');
    final uri = Uri.parse('$_baseUrl/auth/refresh');
    final r = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'refreshToken': refreshToken})).timeout(_timeout);
    if (r.statusCode != 200 && r.statusCode != 201) throw ApiException('Rafraîchissement refusé', statusCode: r.statusCode);
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    await saveSession(data['accessToken'], data['refreshToken'], Map<String, dynamic>.from(data['user']));
  }

  Future<Map<String, String>> _h() async {
    final t = await token();
    return {if (t != null) 'Authorization': 'Bearer $t'};
  }

  Future<dynamic> get(String path) => _send('GET', path);
  Future<dynamic> post(String path, Map body) => _send('POST', path, body: body);
  Future<dynamic> patch(String path, Map body) => _send('PATCH', path, body: body);
  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(String method, String path, {Map? body, bool retried = false}) async {
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
      // Filet de sécurité réactif : si le renouvellement programmé n'a pas eu
      // lieu à temps (app restée en arrière-plan, etc.), on rattrape ici
      // avant d'abandonner et de demander une reconnexion.
      if (r.statusCode == 401 && !retried && path != '/auth/login' && path != '/auth/refresh') {
        final ok = await _refresh();
        if (ok) return _send(method, path, body: body, retried: true);
        onUnauthorized?.call();
        throw ApiException('Session expirée, veuillez vous reconnecter.', statusCode: 401);
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

  // --- Session : jetons + profil utilisateur, persistés localement ---
  Future<void> saveSession(String token, String? refreshToken, Map<String, dynamic> user) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('token', token);
    if (refreshToken != null) await p.setString('refresh_token', refreshToken);
    await p.setString('user', jsonEncode(user));
    _scheduleProactiveRefresh(token);
  }

  Future<Map<String, dynamic>?> currentUser() async {
    final s = (await SharedPreferences.getInstance()).getString('user');
    return s == null ? null : Map<String, dynamic>.from(jsonDecode(s));
  }

  // Révoque le jeton de rafraîchissement côté serveur avant d'effacer la
  // session locale — sans ça, il restait valide 30 jours de plus ailleurs.
  Future<void> logout() async {
    final p = await SharedPreferences.getInstance();
    final rt = p.getString('refresh_token');
    if (rt != null) {
      try { await post('/auth/logout', {'refreshToken': rt}); } catch (_) { /* best-effort */ }
    }
    _refreshTimer?.cancel();
    await p.remove('token');
    await p.remove('refresh_token');
    await p.remove('user');
  }
}
