import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kServerUrlKey = 'mibem_server_base_url';

/// Adresse du backend saisie par l'utilisateur (ou l'admin) au premier
/// lancement, persistée localement, et modifiable à tout moment depuis
/// l'écran de paramètres — sans jamais avoir à reconstruire l'application.
/// Remplace l'ancienne approche "URL figée au moment du build".
class ServerConfigService extends ChangeNotifier {
  String? _baseUrl;
  bool _loading = true;

  String? get baseUrl => _baseUrl;
  bool get isConfigured => _baseUrl != null && _baseUrl!.trim().isNotEmpty;
  bool get loading => _loading;

  ServerConfigService() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_kServerUrlKey);
    _loading = false;
    notifyListeners();
  }

  /// Nettoie l'URL saisie (retire les espaces et le / final) avant de la
  /// persister, pour éviter des chemins du type "https://x.com//api/...".
  Future<void> setBaseUrl(String url) async {
    var cleaned = url.trim();
    while (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    _baseUrl = cleaned;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kServerUrlKey, cleaned);
    notifyListeners();
  }

  Future<void> clear() async {
    _baseUrl = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kServerUrlKey);
    notifyListeners();
  }
}
