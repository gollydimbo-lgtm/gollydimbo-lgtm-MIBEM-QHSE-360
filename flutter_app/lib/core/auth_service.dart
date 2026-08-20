import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'server_config_service.dart';

const _kAccessTokenKey = 'mibem_access_token';
const _kRefreshTokenKey = 'mibem_refresh_token';

/// Gère la session : login, refresh, logout, et persistance locale des
/// tokens (shared_preferences). Écouté par toute l'app via [Provider] pour
/// basculer automatiquement entre écran de connexion et shell principal.
///
/// L'adresse du serveur n'est plus figée au moment du build : elle est lue
/// dynamiquement depuis [ServerConfigService] à chaque appel, ce qui permet
/// de la changer depuis l'écran de paramètres sans jamais recompiler l'app.
class AuthService extends ChangeNotifier {
  final ServerConfigService serverConfig;

  String? _accessToken;
  String? _refreshToken;
  AuthUser? _user;
  bool _initializing = true;

  AuthService(this.serverConfig) {
    _restoreSession();
  }

  String get _baseUrl => serverConfig.baseUrl!;

  String? get accessToken => _accessToken;
  AuthUser? get user => _user;
  bool get isAuthenticated => _accessToken != null && _user != null;
  bool get initializing => _initializing;

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_kAccessTokenKey);
    _refreshToken = prefs.getString(_kRefreshTokenKey);
    _initializing = false;
    // Le token d'accès expire vite (15 min) : on ne restaure la session
    // "connectée" que si un refresh token est disponible pour le renouveler.
    if (_refreshToken != null && serverConfig.isConfigured) {
      final refreshed = await tryRefresh();
      if (!refreshed) {
        await logout();
      }
    }
    notifyListeners();
  }

  Future<String?> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode != 200) {
      final body = _tryDecode(response.body);
      return body?['message'] ?? 'Connexion impossible (${response.statusCode})';
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    _accessToken = body['accessToken'];
    _refreshToken = body['refreshToken'];
    _user = AuthUser.fromJson(body['user']);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccessTokenKey, _accessToken!);
    await prefs.setString(_kRefreshTokenKey, _refreshToken!);

    notifyListeners();
    return null; // pas d'erreur
  }

  Future<bool> tryRefresh() async {
    if (_refreshToken == null) return false;
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': _refreshToken}),
      );
      if (response.statusCode != 200) return false;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      _accessToken = body['accessToken'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kAccessTokenKey, _accessToken!);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    if (_refreshToken != null && serverConfig.isConfigured) {
      try {
        await http.post(
          Uri.parse('$_baseUrl/api/auth/logout'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': _refreshToken}),
        );
      } catch (_) {
        // Si l'appel réseau échoue, on nettoie quand même localement.
      }
    }
    _accessToken = null;
    _refreshToken = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccessTokenKey);
    await prefs.remove(_kRefreshTokenKey);
    notifyListeners();
  }

  Map<String, dynamic>? _tryDecode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
