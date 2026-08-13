import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kServerUrlKey = 'mibem_server_base_url';

// Valeur injectée au moment du build (ex. --dart-define=API_BASE_URL=...
// dans le workflow GitHub Actions). Sert uniquement de valeur par défaut
// tant que rien n'est encore enregistré localement — l'utilisateur reste
// libre de la changer ensuite depuis l'écran de paramètres.
const _kBuildTimeDefaultUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');

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
    // Rien d'enregistré localement : si le build a été fait avec une adresse
    // par défaut (--dart-define=API_BASE_URL=...), on la pré-remplit et on
    // la persiste directement, pour que l'app soit utilisable dès le premier
    // lancement sans saisie manuelle.
    if ((_baseUrl == null || _baseUrl!.isEmpty) && _kBuildTimeDefaultUrl.isNotEmpty) {
      _baseUrl = _kBuildTimeDefaultUrl;
      await prefs.setString(_kServerUrlKey, _baseUrl!);
    }
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