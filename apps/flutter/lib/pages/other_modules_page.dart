import 'package:flutter/material.dart';
import '../services/api.dart';
import '../theme.dart';
import 'attachment_helpers.dart';
import 'environnement_pages.dart';
import 'haccp_page.dart';

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
        _tile(c, Icons.precision_manufacturing, 'Équipements', 'Inspections, statut, maintenance', const EquipmentPage()),
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
  @override void initState() { super.initState(); load(); }
  Future<void> load() async { try { items = List.from(await api.get('/business/trainings')); } catch (_) {} setState(() => loading = false); }

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
    body: loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
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

// -------------------- Équipements --------------------
class EquipmentPage extends StatefulWidget {
  const EquipmentPage({super.key});
  @override
  State<EquipmentPage> createState() => _EquipmentPageState();
}
class _EquipmentPageState extends State<EquipmentPage> {
  final api = Api();
  List items = []; bool loading = true;
  @override void initState() { super.initState(); load(); }
  Future<void> load() async { try { items = List.from(await api.get('/business/equipment')); } catch (_) {} setState(() => loading = false); }

  Future<void> create() async {
    final name = TextEditingController(), category = TextEditingController(), location = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dc) => AlertDialog(
        title: const Text('Nouvel équipement'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Nom')),
          TextField(controller: category, decoration: const InputDecoration(labelText: 'Catégorie')),
          TextField(controller: location, decoration: const InputDecoration(labelText: 'Emplacement')),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(dc, false), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(dc, true), child: const Text('Créer'))],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    try {
      await api.post('/business/equipment', {'code': genCode('EQP'), 'name': name.text.trim(), 'category': category.text.trim(), 'location': location.text.trim(), 'status': 'ACTIVE'});
      load();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  @override
  Widget build(BuildContext c) {
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('Équipements')),
      floatingActionButton: FloatingActionButton.extended(onPressed: create, icon: const Icon(Icons.add), label: const Text('Ajouter')),
      body: loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
        onRefresh: load,
        child: items.isEmpty
            ? ListView(children: const [Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Aucun équipement enregistré')))])
            : ListView.builder(padding: const EdgeInsets.all(12), itemCount: items.length, itemBuilder: (_, i) {
                final e = items[i];
                final next = e['nextInspectionAt'] != null ? DateTime.tryParse(e['nextInspectionAt']) : null;
                final overdue = next != null && next.isBefore(now);
                return Card(child: ListTile(
                  leading: Icon(Icons.precision_manufacturing, color: overdue ? Colors.red : Colors.blueGrey),
                  title: Text('${e['name']}'),
                  subtitle: Text('${e['category'] ?? ''} • ${e['location'] ?? ''}${next != null ? ' • prochaine inspection ${next.toIso8601String().substring(0, 10)}' : ''}'),
                  trailing: overdue ? const Chip(label: Text('En retard'), backgroundColor: Color(0xFFFFCDD2)) : null,
                ));
              }),
      ),
    );
  }
}
