import 'package:flutter/material.dart';
import '../services/api.dart';
import '../theme.dart';
import 'attachment_helpers.dart';
import 'environnement_pages.dart';
import 'equipment_page.dart';
import 'haccp_page.dart';
import 'load_error_view.dart';

// -------------------- Hub --------------------
class OtherModulesPage extends StatelessWidget {
  const OtherModulesPage({super.key});
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Modules QHSE')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _tile(c, Icons.restaurant_menu, 'HACCP', 'Points critiques (CCP), surveillance, actions correctives', const HaccpPage()),
        _tile(c, Icons.eco, 'Environnement', 'Relevés (eau, déchets, énergie, rejets...)', const EnvironnementHome()),
        _tile(c, Icons.school, 'Formations', 'Planification, échéances, participants', const TrainingsPage()),
        _tile(c, Icons.precision_manufacturing, 'Équipements', 'Registre, scan QR, contrôles terrain hors-ligne', const EquipmentPage()),
      ],
    ),
  );
  Widget _tile(BuildContext c, IconData icon, String title, String subtitle, Widget page) => Card(
        child: ListTile(
          leading: Icon(icon, size: 32),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => page)),
        ),
      );
}

// (HACCP dispose désormais de son propre module dédié — voir haccp_page.dart.
// L'ancien CRUD plat référençait /business/haccp, route supprimée côté API
// avec la reconstruction complète du module.)

// (Environnement dispose désormais de son propre module dédié — voir environnement_pages.dart)

// -------------------- Formations --------------------
class TrainingsPage extends StatefulWidget {
  const TrainingsPage({super.key});
  @override
  State<TrainingsPage> createState() => _TrainingsPageState();
}
class _TrainingsPageState extends State<TrainingsPage> {
  final api = Api();
  List items = []; bool loading = true;
  Object? error;
  @override void initState() { super.initState(); load(); }
  Future<void> load() async { error = null;
    try { items = List.from(await api.get('/business/trainings')); } catch (e) { error = e; } setState(() => loading = false); }

  Future<void> create() async {
    final title = TextEditingController(), trainer = TextEditingController();
    DateTime date = DateTime.now().add(const Duration(days: 14));
    final ok = await showDialog<bool>(
      context: context,
      builder: (dc) => StatefulBuilder(builder: (dc, setD) => AlertDialog(
        title: const Text('Nouvelle formation'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: title, decoration: const InputDecoration(labelText: 'Intitulé')),
          TextField(controller: trainer, decoration: const InputDecoration(labelText: 'Formateur')),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async { final d = await showDatePicker(context: dc, initialDate: date, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 730))); if (d != null) setD(() => date = d); },
            icon: const Icon(Icons.event),
            label: Text(date.toIso8601String().substring(0, 10)),
          ),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(dc, false), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(dc, true), child: const Text('Créer'))],
      )),
    );
    if (ok != true || title.text.trim().isEmpty) return;
    try {
      await api.post('/business/trainings', {'code': genCode('FORM'), 'title': title.text.trim(), 'trainer': trainer.text.trim(), 'scheduledAt': date.toIso8601String(), 'status': 'PLANNED'});
      load();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Formations')),
    floatingActionButton: FloatingActionButton.extended(onPressed: create, icon: const Icon(Icons.add), label: const Text('Planifier')),
    body: loading ? const Center(child: CircularProgressIndicator()) : error != null ? LoadErrorView(error: error, onRetry: load) : RefreshIndicator(
      onRefresh: load,
      child: items.isEmpty
          ? ListView(children: const [Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Aucune formation planifiée')))])
          : ListView.builder(padding: const EdgeInsets.all(12), itemCount: items.length, itemBuilder: (_, i) {
              final t = items[i];
              return Card(child: ListTile(
                leading: const Icon(Icons.school, color: Colors.indigo),
                title: Text('${t['title']}'),
                subtitle: Text('${t['trainer'] ?? ''} • ${_date(t['scheduledAt'])} • ${t['status']}'),
              ));
            }),
    ),
  );
  String _date(dynamic v) => v == null ? '' : v.toString().substring(0, 10);
}
