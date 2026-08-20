import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'api.dart';

/// File d'attente locale des mutations créées hors-ligne (accidents, NC,
/// risques...) sur le terrain, sans couverture réseau. Persistée dans
/// SharedPreferences pour survivre à la fermeture de l'app. Rejouée vers
/// `POST /sync/push` dès que la connexion revient (manuellement ou
/// automatiquement via connectivity_plus, voir main.dart).
class SyncQueue {
  static const _key = 'sync_queue_v1';
  static const _uuid = Uuid();

  static Future<List<Map<String, dynamic>>> _load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_key) ?? [];
    return raw.map((s) => Map<String, dynamic>.from(jsonDecode(s))).toList();
  }

  static Future<void> _save(List<Map<String, dynamic>> items) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_key, items.map((e) => jsonEncode(e)).toList());
  }

  /// Met en file une création qui n'a pas pu être envoyée immédiatement
  /// faute de réseau. `entity` doit correspondre à une clé connue du
  /// serveur (nonConformity, action, safetyEvent, risk).
  static Future<String> enqueue(String entity, String operation, Map body, {String? entityId}) async {
    final id = _uuid.v4();
    final items = await _load();
    items.add({
      'clientLocalId': id,
      'entity': entity,
      'operation': operation,
      'entityId': entityId,
      'payload': body,
      'createdAt': DateTime.now().toIso8601String(),
    });
    await _save(items);
    return id;
  }

  static Future<int> pendingCount() async => (await _load()).length;

  static Future<List<Map<String, dynamic>>> pending() => _load();

  /// Envoie toute la file au serveur. Les éléments confirmés SYNCED sont
  /// retirés localement ; ceux en erreur ou toujours hors-ligne restent en
  /// file pour une prochaine tentative.
  static Future<Map<String, int>> flush(Api api) async {
    final items = await _load();
    if (items.isEmpty) return {'synced': 0, 'remaining': 0, 'errors': 0};
    try {
      final r = await api.post('/sync/push', {'items': items});
      final results = List.from(r['items'] ?? []);
      final syncedIds = results.where((x) => x['status'] == 'SYNCED').map((x) => x['clientLocalId']).toSet();
      final errorCount = results.where((x) => x['status'] == 'ERROR').length;
      final remaining = items.where((i) => !syncedIds.contains(i['clientLocalId'])).toList();
      await _save(remaining);
      return {'synced': syncedIds.length, 'remaining': remaining.length, 'errors': errorCount};
    } catch (_) {
      // Toujours hors-ligne : on ne perd rien, la file reste intacte.
      return {'synced': 0, 'remaining': items.length, 'errors': 0};
    }
  }

  static Future<void> clear() async => _save([]);
}
