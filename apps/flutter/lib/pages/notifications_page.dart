import 'package:flutter/material.dart';
import '../services/api.dart';
import '../theme.dart';

// Cloche de notifications — chantier "calendrier centralisé / notifications
// actives" de l'audit. Liste unifiée de toutes les échéances/alertes déjà
// détectées côté serveur (actions, audits, habilitations, maintenance,
// veille réglementaire, visites médicales, réévaluations de risque,
// fournisseurs...), branchée sur les endpoints /notifications déjà
// construits côté API (idempotents, jamais de doublon).
//
// Limite assumée : contrairement au web, cet écran ne navigue pas encore
// directement vers le module concerné au tap — il se contente de marquer
// la notification comme lue. Ajouter la navigation profonde par module
// demanderait de faire correspondre chaque valeur de "module" à un écran
// Flutter précis, chantier distinct non entrepris ici.
Color notifNiveauColor(String? n) => {
      'CRITICAL': QhseColors.red, 'WARNING': QhseColors.amber,
      'INFO': QhseColors.blue, 'SUCCESS': QhseColors.green,
    }[n] ?? QhseColors.textSecondary;

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final api = Api();
  List items = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final data = await api.get('/notifications');
      setState(() { items = data as List; loading = false; });
    } catch (e) {
      setState(() { error = '$e'; loading = false; });
    }
  }

  Future<void> _marquerLue(Map n) async {
    if (n['lu'] == true) return;
    setState(() => n['lu'] = true);
    try { await api.patch('/notifications/${n['id']}/lue', {}); } catch (_) {}
  }

  Future<void> _marquerToutesLues() async {
    setState(() { for (final n in items) { n['lu'] = true; } });
    try { await api.patch('/notifications/marquer-toutes-lues', {}); } catch (_) {}
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(icon: const Icon(Icons.done_all), tooltip: 'Tout marquer lu', onPressed: _marquerToutesLues),
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Actualiser', onPressed: _load),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text('Erreur : $error', style: TextStyle(color: QhseColors.red)))
              : items.isEmpty
                  ? Center(child: Text('Aucune notification.', style: TextStyle(color: QhseColors.textSecondary)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: QhseColors.border),
                        itemBuilder: (context, i) {
                          final n = items[i] as Map;
                          final lu = n['lu'] == true;
                          return ListTile(
                            onTap: () => _marquerLue(n),
                            tileColor: lu ? null : QhseColors.blue.withOpacity(0.06),
                            leading: Container(
                              width: 10, height: 10, margin: const EdgeInsets.only(top: 4),
                              decoration: BoxDecoration(color: notifNiveauColor(n['niveau'] as String?), shape: BoxShape.circle),
                            ),
                            title: Text('${n['titre'] ?? ''}', style: TextStyle(fontWeight: lu ? FontWeight.normal : FontWeight.w600)),
                            subtitle: (n['detail'] != null && '${n['detail']}'.isNotEmpty) ? Text('${n['detail']}') : null,
                          );
                        },
                      ),
                    ),
    );
  }
}
