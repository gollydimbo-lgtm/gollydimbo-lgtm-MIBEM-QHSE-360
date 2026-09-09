import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../services/api.dart';
import '../theme.dart';

// --- Catégories (réutilisé pour EPI et EPC — une seule entrée : le nom) ---
class CategoryListTab extends StatefulWidget {
  final String endpoint;
  final String label;
  const CategoryListTab({super.key, required this.endpoint, required this.label});
  @override
  State<CategoryListTab> createState() => _CategoryListTabState();
}

class _CategoryListTabState extends State<CategoryListTab> {
  final api = Api();
  List items = [];
  bool loading = true;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try { items = List.from(await api.get(widget.endpoint)); } catch (_) {}
    setState(() => loading = false);
  }

  Future<void> _openForm({Map? record}) async {
    final name = TextEditingController(text: record?['name'] ?? '');
    String? formError;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
        title: Text(record == null ? 'Nouvelle catégorie ${widget.label}' : 'Modifier la catégorie'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Nom')),
          if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
        ]),
        actions: [
          if (record != null) TextButton(
            onPressed: () async {
              try { await api.delete('${widget.endpoint}/${record['id']}'); if (context.mounted) Navigator.pop(c); load(); }
              catch (e) { setD(() => formError = '$e'); }
            },
            child: const Text('Supprimer', style: TextStyle(color: QhseColors.red)),
          ),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              try {
                if (record != null) await api.patch('${widget.endpoint}/${record['id']}', {'name': name.text});
                else await api.post(widget.endpoint, {'name': name.text});
                if (context.mounted) Navigator.pop(c);
                load();
              } catch (e) { setD(() => formError = '$e'); }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: () => _openForm(), icon: const Icon(Icons.add, size: 16), label: const Text('Catégorie'))),
          const SizedBox(height: 8),
          if (items.isEmpty) Padding(padding: EdgeInsets.all(16), child: Text('Aucune catégorie', style: TextStyle(color: QhseColors.textSecondary))),
          ...items.map((c) => Card(child: ListTile(title: Text(c['name'] ?? ''), onTap: () => _openForm(record: c)))),
        ],
      ),
    );
  }
}

// --- Personnel ---
class EmployeeTab extends StatefulWidget {
  const EmployeeTab({super.key});
  @override
  State<EmployeeTab> createState() => _EmployeeTabState();
}

class _EmployeeTabState extends State<EmployeeTab> {
  final api = Api();
  List items = [];
  bool loading = true;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try { items = List.from(await api.get('/epi/employees')); } catch (_) {}
    setState(() => loading = false);
  }

  Future<void> _openForm({Map? record}) async {
    final matricule = TextEditingController(text: record?['matricule'] ?? '');
    final firstName = TextEditingController(text: record?['firstName'] ?? '');
    final lastName = TextEditingController(text: record?['lastName'] ?? '');
    final department = TextEditingController(text: record?['department'] ?? '');
    final position = TextEditingController(text: record?['position'] ?? '');
    bool active = record?['active'] ?? true;
    String? formError;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
        title: Text(record == null ? 'Nouvel employé' : "Modifier l'employé"),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: matricule, decoration: const InputDecoration(labelText: 'Matricule')),
            TextField(controller: firstName, decoration: const InputDecoration(labelText: 'Prénom')),
            TextField(controller: lastName, decoration: const InputDecoration(labelText: 'Nom')),
            TextField(controller: department, decoration: const InputDecoration(labelText: 'Département')),
            TextField(controller: position, decoration: const InputDecoration(labelText: 'Poste')),
            if (record != null) CheckboxListTile(value: active, title: const Text('Actif'), onChanged: (v) => setD(() => active = v ?? true), controlAffinity: ListTileControlAffinity.leading),
            if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
          ]),
        ),
        actions: [
          if (record != null) TextButton(
            onPressed: () async {
              try { await api.delete('/epi/employees/${record['id']}'); if (context.mounted) Navigator.pop(c); load(); }
              catch (e) { setD(() => formError = '$e'); }
            },
            child: const Text('Supprimer', style: TextStyle(color: QhseColors.red)),
          ),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              final payload = {'matricule': matricule.text, 'firstName': firstName.text, 'lastName': lastName.text, 'department': department.text, 'position': position.text, if (record != null) 'active': active};
              try {
                if (record != null) await api.patch('/epi/employees/${record['id']}', payload);
                else await api.post('/epi/employees', payload);
                if (context.mounted) Navigator.pop(c);
                load();
              } catch (e) { setD(() => formError = '$e'); }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: () => _openForm(), icon: const Icon(Icons.person_add_alt_1, size: 16), label: const Text('Employé'))),
          const SizedBox(height: 8),
          if (items.isEmpty) Padding(padding: EdgeInsets.all(16), child: Text('Aucun employé enregistré', style: TextStyle(color: QhseColors.textSecondary))),
          ...items.map((e) => Card(child: ListTile(
                title: Text('${e['firstName']} ${e['lastName']}'),
                subtitle: Text('${e['matricule']} • ${e['department'] ?? '—'} • ${e['position'] ?? '—'}'),
                trailing: Icon(Icons.circle, size: 10, color: e['active'] == true ? QhseColors.green : QhseColors.red),
                onTap: () => _openForm(record: e),
              ))),
        ],
      ),
    );
  }
}

// --- Bibliothèque EPC ---
class EpcLibraryTab extends StatefulWidget {
  const EpcLibraryTab({super.key});
  @override
  State<EpcLibraryTab> createState() => _EpcLibraryTabState();
}

class _EpcLibraryTabState extends State<EpcLibraryTab> {
  final api = Api();
  List items = [];
  List categories = [];
  bool loading = true;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      items = List.from(await api.get('/epi/epc'));
      categories = List.from(await api.get('/epi/epc-categories'));
    } catch (_) {}
    setState(() => loading = false);
  }

  Future<void> _openForm({Map? record}) async {
    final code = TextEditingController(text: record?['code'] ?? '');
    final name = TextEditingController(text: record?['name'] ?? '');
    final location = TextEditingController(text: record?['location'] ?? '');
    final zone = TextEditingController(text: record?['zone'] ?? '');
    final manufacturer = TextEditingController(text: record?['manufacturer'] ?? '');
    String? categoryId = record?['categoryId'];
    String status = record?['status'] ?? 'ACTIVE';
    String? formError;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
        title: Text(record == null ? 'Nouvel EPC' : "Modifier l'EPC"),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: code, enabled: record == null, decoration: const InputDecoration(labelText: 'Code')),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Désignation')),
            DropdownButtonFormField<String>(
              value: categoryId, isExpanded: true,
              items: categories.map<DropdownMenuItem<String>>((cat) => DropdownMenuItem(value: cat['id'] as String, child: Text(cat['name']))).toList(),
              onChanged: (v) => setD(() => categoryId = v),
              decoration: const InputDecoration(labelText: 'Catégorie'),
            ),
            TextField(controller: location, decoration: const InputDecoration(labelText: 'Localisation')),
            TextField(controller: zone, decoration: const InputDecoration(labelText: 'Zone')),
            TextField(controller: manufacturer, decoration: const InputDecoration(labelText: 'Fabricant')),
            DropdownButtonFormField<String>(
              value: status,
              items: const [DropdownMenuItem(value: 'ACTIVE', child: Text('Actif')), DropdownMenuItem(value: 'MAINTENANCE', child: Text('En maintenance')), DropdownMenuItem(value: 'NON_CONFORME', child: Text('Non conforme')), DropdownMenuItem(value: 'HORS_SERVICE', child: Text('Hors service'))],
              onChanged: (v) => setD(() => status = v ?? 'ACTIVE'),
              decoration: const InputDecoration(labelText: 'Statut'),
            ),
            if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
          ]),
        ),
        actions: [
          if (record != null) TextButton(
            onPressed: () async {
              try { await api.delete('/epi/epc/${record['id']}'); if (context.mounted) Navigator.pop(c); load(); }
              catch (e) { setD(() => formError = '$e'); }
            },
            child: const Text('Supprimer', style: TextStyle(color: QhseColors.red)),
          ),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              final payload = {'name': name.text, 'categoryId': categoryId, 'location': location.text, 'zone': zone.text, 'manufacturer': manufacturer.text, 'status': status};
              try {
                if (record != null) await api.patch('/epi/epc/${record['id']}', payload);
                else await api.post('/epi/epc', {'code': code.text, ...payload});
                if (context.mounted) Navigator.pop(c);
                load();
              } catch (e) { setD(() => formError = '$e'); }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: () => _openForm(), icon: const Icon(Icons.add, size: 16), label: const Text('EPC'))),
          const SizedBox(height: 8),
          if (items.isEmpty) Padding(padding: EdgeInsets.all(16), child: Text('Aucun EPC enregistré', style: TextStyle(color: QhseColors.textSecondary))),
          ...items.map((e) => Card(child: ListTile(
                title: Text('${e['code']} — ${e['name']}'),
                subtitle: Text('${e['category']?['name'] ?? '—'} • ${e['location'] ?? '—'}'),
                trailing: Icon(Icons.circle, size: 10, color: e['status'] == 'NON_CONFORME' ? QhseColors.red : e['status'] == 'ACTIVE' ? QhseColors.green : QhseColors.amber),
                onTap: () => _openForm(record: e),
              ))),
        ],
      ),
    );
  }
}

// --- Inspections EPI + EPC ---
// --- Stock / bibliothèque EPI — fusion : les champs riches et la
// création/suppression du web, plus le regroupement journalier/annuel
// qui n'existe que côté Flutter. ---
class EpiLibraryTab extends StatefulWidget {
  const EpiLibraryTab({super.key});
  @override
  State<EpiLibraryTab> createState() => _EpiLibraryTabState();
}

class _EpiLibraryTabState extends State<EpiLibraryTab> {
  final api = Api();
  List stock = [];
  List categories = [];
  bool loading = true;
  String? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final d = await api.get('/epi/dashboard');
      stock = List.from(d['stock'] ?? []);
      categories = List.from(await api.get('/epi/epi-categories'));
    } catch (e) {
      error = 'Impossible de charger le catalogue EPI';
    }
    setState(() => loading = false);
  }

  Future<void> _openForm({Map? record}) async {
    final code = TextEditingController(text: record?['code'] ?? '');
    final name = TextEditingController(text: record?['name'] ?? '');
    final manufacturer = TextEditingController(text: record?['manufacturer'] ?? '');
    final model = TextEditingController(text: record?['model'] ?? '');
    final standard = TextEditingController(text: record?['standard'] ?? '');
    final location = TextEditingController(text: record?['location'] ?? '');
    final minStock = TextEditingController(text: '${record?['minStock'] ?? 0}');
    final maxStock = TextEditingController(text: record?['maxStock'] != null ? '${record?['maxStock']}' : '');
    String frequency = record?['frequency'] ?? 'DAILY';
    String? categoryId = record?['categoryId'];
    bool disposable = record?['disposable'] ?? false;
    bool shared = record?['shared'] ?? false;
    String? formError;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
        title: Text(record == null ? 'Nouvel EPI' : "Modifier l'EPI"),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: code, enabled: record == null, decoration: const InputDecoration(labelText: 'Code')),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Désignation')),
            DropdownButtonFormField<String>(
              value: categoryId, isExpanded: true,
              items: categories.map<DropdownMenuItem<String>>((cat) => DropdownMenuItem(value: cat['id'] as String, child: Text(cat['name']))).toList(),
              onChanged: (v) => setD(() => categoryId = v),
              decoration: const InputDecoration(labelText: 'Catégorie'),
            ),
            DropdownButtonFormField<String>(
              value: frequency,
              items: const [DropdownMenuItem(value: 'DAILY', child: Text('Quotidienne')), DropdownMenuItem(value: 'ANNUAL', child: Text('Annuelle'))],
              onChanged: (v) => setD(() => frequency = v ?? 'DAILY'),
              decoration: const InputDecoration(labelText: 'Fréquence de distribution'),
            ),
            Row(children: [
              Expanded(child: TextField(controller: manufacturer, decoration: const InputDecoration(labelText: 'Fabricant'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: model, decoration: const InputDecoration(labelText: 'Modèle'))),
            ]),
            TextField(controller: standard, decoration: const InputDecoration(labelText: 'Norme applicable')),
            TextField(controller: location, decoration: const InputDecoration(labelText: 'Emplacement')),
            Row(children: [
              Expanded(child: TextField(controller: minStock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stock minimum'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: maxStock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stock maximum'))),
            ]),
            CheckboxListTile(value: disposable, title: const Text('Jetable'), onChanged: (v) => setD(() => disposable = v ?? false), controlAffinity: ListTileControlAffinity.leading),
            CheckboxListTile(value: shared, title: const Text('Partagé (non individuel)'), onChanged: (v) => setD(() => shared = v ?? false), controlAffinity: ListTileControlAffinity.leading),
            if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
          ]),
        ),
        actions: [
          if (record != null) TextButton(
            onPressed: () async {
              try { await api.delete('/epi/catalog/${record['id']}'); if (context.mounted) Navigator.pop(c); load(); }
              catch (e) { setD(() => formError = '$e'); }
            },
            child: const Text('Supprimer', style: TextStyle(color: QhseColors.red)),
          ),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              final payload = {
                'name': name.text, 'categoryId': categoryId, 'frequency': frequency,
                'manufacturer': manufacturer.text, 'model': model.text, 'standard': standard.text, 'location': location.text,
                'minStock': int.tryParse(minStock.text) ?? 0, 'maxStock': maxStock.text.isEmpty ? null : int.tryParse(maxStock.text),
                'disposable': disposable, 'shared': shared,
              };
              try {
                if (record != null) await api.patch('/epi/catalog/${record['id']}', payload);
                else await api.post('/epi/catalog', {'code': code.text, ...payload});
                if (context.mounted) Navigator.pop(c);
                load();
              } catch (e) { setD(() => formError = '$e'); }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      )),
    );
  }

  Widget _epiCard(Map e) {
    final s = (e['stock'] ?? 0) as num;
    final minStock = (e['minStock'] ?? 0) as num;
    final low = s <= minStock;
    return Card(
      child: ListTile(
        leading: Icon(Icons.inventory_2, color: low ? QhseColors.red : QhseColors.green),
        title: Text('${e['name']}'),
        subtitle: Text(
          e['frequency'] == 'DAILY'
              ? "Stock restant : $s • distribués aujourd'hui : ${e['dailyDistributed'] ?? 0}"
              : 'Stock restant : $s',
        ),
        trailing: low ? const Chip(label: Text('Stock bas'), backgroundColor: Color(0xFFFFCDD2)) : null,
        onTap: () => _openForm(record: e),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(error!, style: const TextStyle(color: QhseColors.red)),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: load, child: const Text('Réessayer')),
      ]));
    }
    final daily = stock.where((e) => e['frequency'] == 'DAILY').toList();
    final annual = stock.where((e) => e['frequency'] == 'ANNUAL').toList();
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: () => _openForm(), icon: const Icon(Icons.add, size: 16), label: const Text('Nouvel EPI'))),
          const SizedBox(height: 8),
          const Text('EPI journaliers (gants, cache-nez, charlotte…)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          ...daily.map((e) => _epiCard(e)),
          if (daily.isEmpty) Padding(padding: const EdgeInsets.all(8), child: Text('Aucun EPI journalier configuré', style: TextStyle(color: QhseColors.textSecondary))),
          const SizedBox(height: 16),
          const Text('EPI annuels (chaussures, tenue, lunettes, casque…)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          ...annual.map((e) => _epiCard(e)),
          if (annual.isEmpty) Padding(padding: const EdgeInsets.all(8), child: Text('Aucun EPI annuel configuré', style: TextStyle(color: QhseColors.textSecondary))),
        ],
      ),
    );
  }
}

class InspectionsTab extends StatefulWidget {
  const InspectionsTab({super.key});
  @override
  State<InspectionsTab> createState() => _InspectionsTabState();
}

class _InspectionsTabState extends State<InspectionsTab> {
  final api = Api();
  List epiInsp = [], epcInsp = [], epis = [], epcs = [];
  bool loading = true;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      epiInsp = List.from(await api.get('/epi/epi-inspections'));
      epcInsp = List.from(await api.get('/epi/epc-inspections'));
      epis = List.from(await api.get('/epi/catalog'));
      epcs = List.from(await api.get('/epi/epc'));
    } catch (_) {}
    setState(() => loading = false);
  }

  Future<void> _openForm({required bool isEpi}) async {
    String? targetId;
    String result = 'CONFORME';
    final observations = TextEditingController();
    String? formError;
    final options = isEpi ? epis : epcs;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
        title: Text(isEpi ? 'Nouvelle inspection EPI' : 'Nouvelle inspection EPC'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: targetId, isExpanded: true,
              items: options.map<DropdownMenuItem<String>>((o) => DropdownMenuItem(value: o['id'] as String, child: Text(o['name']))).toList(),
              onChanged: (v) => setD(() => targetId = v),
              decoration: InputDecoration(labelText: isEpi ? 'EPI inspecté' : 'EPC inspecté'),
            ),
            DropdownButtonFormField<String>(
              value: result,
              items: const [DropdownMenuItem(value: 'CONFORME', child: Text('Conforme')), DropdownMenuItem(value: 'NON_CONFORME', child: Text('Non conforme')), DropdownMenuItem(value: 'A_SURVEILLER', child: Text('À surveiller')), DropdownMenuItem(value: 'A_REFORMER', child: Text('À réformer'))],
              onChanged: (v) => setD(() => result = v ?? 'CONFORME'),
              decoration: const InputDecoration(labelText: 'Résultat'),
            ),
            TextField(controller: observations, decoration: const InputDecoration(labelText: 'Observations'), maxLines: 2),
            if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              if (targetId == null) { setD(() => formError = 'Sélectionnez un équipement'); return; }
              try {
                final endpoint = isEpi ? '/epi/epi-inspections' : '/epi/epc-inspections';
                final key = isEpi ? 'epiId' : 'epcId';
                await api.post(endpoint, {key: targetId, 'result': result, 'observations': observations.text});
                if (context.mounted) Navigator.pop(c);
                load();
              } catch (e) { setD(() => formError = '$e'); }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      )),
    );
  }

  Color _resultColor(String? r) => r == 'NON_CONFORME' || r == 'A_REFORMER' ? QhseColors.red : r == 'A_SURVEILLER' ? QhseColors.amber : QhseColors.green;
  String _resultLabel(String? r) => {'CONFORME': 'Conforme', 'NON_CONFORME': 'Non conforme', 'A_SURVEILLER': 'À surveiller', 'A_REFORMER': 'À réformer'}[r] ?? '$r';
  bool _isBad(String? r) => r == 'NON_CONFORME' || r == 'A_REFORMER';

  Future<void> _createNcQuick({required String title, String? description, required String source, required int severity, String? epiId, String? epcId}) async {
    final titleCtrl = TextEditingController(text: title);
    final descCtrl = TextEditingController(text: description ?? '');
    String? formError;
    bool saving = false;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
        title: const Text('Nouvelle non-conformité'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Titre')),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
            if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          FilledButton(
            onPressed: saving ? null : () async {
              setD(() => saving = true);
              try {
                await api.post('/business/non-conformities', {
                  'code': 'NC-${DateTime.now().millisecondsSinceEpoch}',
                  'title': titleCtrl.text, 'description': descCtrl.text, 'source': source, 'severity': severity,
                  'occurredAt': DateTime.now().toIso8601String(), 'epiId': epiId, 'epcId': epcId,
                });
                if (context.mounted) Navigator.pop(c);
              } catch (e) { setD(() { saving = false; formError = '$e'; }); }
            },
            child: Text(saving ? 'Enregistrement…' : 'Créer'),
          ),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(children: [
            const Expanded(child: Text('Inspections EPI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
            FilledButton.icon(onPressed: () => _openForm(isEpi: true), icon: const Icon(Icons.add, size: 16), label: const Text('Nouvelle')),
          ]),
          const SizedBox(height: 6),
          if (epiInsp.isEmpty) Padding(padding: const EdgeInsets.all(8), child: Text('Aucune inspection EPI', style: TextStyle(color: QhseColors.textSecondary))),
          ...epiInsp.map((i) => Card(child: ListTile(
                title: Text(i['epi']?['name'] ?? '—'),
                subtitle: Text(i['observations'] ?? ''),
                trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(_resultLabel(i['result']), style: TextStyle(color: _resultColor(i['result']), fontSize: 12, fontWeight: FontWeight.w600)),
                  if (_isBad(i['result']))
                    TextButton(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 24)),
                      onPressed: () => _createNcQuick(
                        title: 'EPI non conforme — ${i['epi']?['name'] ?? ''}',
                        description: i['observations'],
                        source: 'EPI', severity: i['result'] == 'A_REFORMER' ? 3 : 2, epiId: i['epiId'],
                      ),
                      child: const Text('Créer une NC', style: TextStyle(fontSize: 11, color: QhseColors.red)),
                    ),
                ]),
              ))),
          const SizedBox(height: 20),
          Row(children: [
            const Expanded(child: Text('Inspections EPC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
            FilledButton.icon(onPressed: () => _openForm(isEpi: false), icon: const Icon(Icons.add, size: 16), label: const Text('Nouvelle')),
          ]),
          const SizedBox(height: 6),
          if (epcInsp.isEmpty) Padding(padding: const EdgeInsets.all(8), child: Text('Aucune inspection EPC', style: TextStyle(color: QhseColors.textSecondary))),
          ...epcInsp.map((i) => Card(child: ListTile(
                title: Text(i['epc']?['name'] ?? '—'),
                subtitle: Text(i['observations'] ?? ''),
                trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(_resultLabel(i['result']), style: TextStyle(color: _resultColor(i['result']), fontSize: 12, fontWeight: FontWeight.w600)),
                  if (_isBad(i['result']))
                    TextButton(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 24)),
                      onPressed: () => _createNcQuick(
                        title: 'EPC non conforme — ${i['epc']?['name'] ?? ''}',
                        description: i['observations'],
                        source: 'EPC', severity: i['result'] == 'A_REFORMER' ? 3 : 2, epcId: i['epcId'],
                      ),
                      child: const Text('Créer une NC', style: TextStyle(fontSize: 11, color: QhseColors.red)),
                    ),
                ]),
              ))),
        ],
      ),
    );
  }
}

// --- Maintenance EPC ---
class EpcMaintenanceTab extends StatefulWidget {
  const EpcMaintenanceTab({super.key});
  @override
  State<EpcMaintenanceTab> createState() => _EpcMaintenanceTabState();
}

class _EpcMaintenanceTabState extends State<EpcMaintenanceTab> {
  final api = Api();
  List items = [], epcs = [];
  bool loading = true;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      items = List.from(await api.get('/epi/maintenance'));
      epcs = List.from(await api.get('/epi/epc'));
    } catch (_) {}
    setState(() => loading = false);
  }

  Future<void> _openForm() async {
    String? epcId;
    String type = 'PREVENTIVE';
    final description = TextEditingController();
    final cost = TextEditingController();
    DateTime? nextMaintenanceAt;
    String? formError;
    bool saving = false;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
        title: const Text('Nouvelle intervention de maintenance'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: epcId, isExpanded: true,
              items: epcs.map<DropdownMenuItem<String>>((e) => DropdownMenuItem(value: e['id'] as String, child: Text('${e['code']} — ${e['name']}'))).toList(),
              onChanged: (v) => setD(() => epcId = v),
              decoration: const InputDecoration(labelText: 'Équipement'),
            ),
            DropdownButtonFormField<String>(
              value: type,
              items: const [DropdownMenuItem(value: 'PREVENTIVE', child: Text('Préventive')), DropdownMenuItem(value: 'CORRECTIVE', child: Text('Corrective'))],
              onChanged: (v) => setD(() => type = v ?? 'PREVENTIVE'),
              decoration: const InputDecoration(labelText: "Type d'intervention"),
            ),
            TextField(controller: description, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
            TextField(controller: cost, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Coût (optionnel)')),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(nextMaintenanceAt == null ? 'Prochaine échéance (optionnel)' : 'Échéance : ${nextMaintenanceAt!.day}/${nextMaintenanceAt!.month}/${nextMaintenanceAt!.year}'),
              trailing: const Icon(Icons.edit_calendar),
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2035));
                if (d != null) setD(() => nextMaintenanceAt = d);
              },
            ),
            if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          FilledButton(
            onPressed: saving ? null : () async {
              if (epcId == null) { setD(() => formError = 'Sélectionnez un équipement'); return; }
              setD(() => saving = true);
              try {
                await api.post('/epi/maintenance', {
                  'epcId': epcId, 'type': type, 'description': description.text,
                  'cost': cost.text.isEmpty ? null : double.tryParse(cost.text),
                  'nextMaintenanceAt': nextMaintenanceAt?.toIso8601String(),
                });
                if (context.mounted) Navigator.pop(c);
                load();
              } catch (e) { setD(() { saving = false; formError = '$e'; }); }
            },
            child: Text(saving ? 'Enregistrement…' : 'Enregistrer'),
          ),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: _openForm, icon: const Icon(Icons.add, size: 16), label: const Text('Nouvelle intervention'))),
          const SizedBox(height: 8),
          if (items.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text('Aucune intervention enregistrée', style: TextStyle(color: QhseColors.textSecondary))),
          ...items.map((m) => Card(child: ListTile(
                leading: Icon(Icons.build, color: m['type'] == 'CORRECTIVE' ? QhseColors.red : QhseColors.blue),
                title: Text(m['epc']?['name'] ?? '—'),
                subtitle: Text('${m['type'] == 'PREVENTIVE' ? 'Préventive' : 'Corrective'} • ${(m['date'] ?? '').toString().substring(0, 10)}${m['description'] != null && m['description'] != '' ? ' • ${m['description']}' : ''}'),
                trailing: m['nextMaintenanceAt'] != null ? Text('Échéance\n${(m['nextMaintenanceAt']).toString().substring(0, 10)}', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: QhseColors.textSecondary)) : null,
              ))),
        ],
      ),
    );
  }
}

class MatrixTab extends StatefulWidget {
  const MatrixTab({super.key});
  @override
  State<MatrixTab> createState() => _MatrixTabState();
}

class _MatrixTabState extends State<MatrixTab> {
  final api = Api();
  List items = [], epis = [], epcs = [];
  bool loading = true;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      items = List.from(await api.get('/epi/job-risk-protection'));
      epis = List.from(await api.get('/epi/catalog'));
      epcs = List.from(await api.get('/epi/epc'));
    } catch (_) {}
    setState(() => loading = false);
  }

  Future<void> _openForm({Map? record}) async {
    final jobTitle = TextEditingController(text: record?['jobTitle'] ?? '');
    final hazard = TextEditingController(text: record?['hazard'] ?? '');
    final riskDescription = TextEditingController(text: record?['riskDescription'] ?? '');
    final preventionMeasure = TextEditingController(text: record?['preventionMeasure'] ?? '');
    String? epiId = record?['epiId'];
    String? epcId = record?['epcId'];
    String? formError;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
        title: Text(record == null ? 'Nouvelle ligne — Poste/Risque/Protection' : 'Modifier la ligne'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: jobTitle, decoration: const InputDecoration(labelText: 'Poste')),
            TextField(controller: hazard, decoration: const InputDecoration(labelText: 'Danger')),
            TextField(controller: riskDescription, decoration: const InputDecoration(labelText: 'Risque')),
            TextField(controller: preventionMeasure, decoration: const InputDecoration(labelText: 'Mesure de prévention')),
            DropdownButtonFormField<String>(
              value: epiId, isExpanded: true,
              items: epis.map<DropdownMenuItem<String>>((e) => DropdownMenuItem(value: e['id'] as String, child: Text(e['name']))).toList(),
              onChanged: (v) => setD(() => epiId = v),
              decoration: const InputDecoration(labelText: 'EPI associé'),
            ),
            DropdownButtonFormField<String>(
              value: epcId, isExpanded: true,
              items: epcs.map<DropdownMenuItem<String>>((e) => DropdownMenuItem(value: e['id'] as String, child: Text(e['name']))).toList(),
              onChanged: (v) => setD(() => epcId = v),
              decoration: const InputDecoration(labelText: 'EPC associé'),
            ),
            if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
          ]),
        ),
        actions: [
          if (record != null) TextButton(
            onPressed: () async {
              try { await api.delete('/epi/job-risk-protection/${record['id']}'); if (context.mounted) Navigator.pop(c); load(); }
              catch (e) { setD(() => formError = '$e'); }
            },
            child: const Text('Supprimer', style: TextStyle(color: QhseColors.red)),
          ),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              final payload = {'jobTitle': jobTitle.text, 'hazard': hazard.text, 'riskDescription': riskDescription.text, 'preventionMeasure': preventionMeasure.text, 'epiId': epiId, 'epcId': epcId};
              try {
                if (record != null) await api.patch('/epi/job-risk-protection/${record['id']}', payload);
                else await api.post('/epi/job-risk-protection', {'code': 'JRP-${DateTime.now().millisecondsSinceEpoch}', ...payload});
                if (context.mounted) Navigator.pop(c);
                load();
              } catch (e) { setD(() => formError = '$e'); }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: () => _openForm(), icon: const Icon(Icons.add, size: 16), label: const Text('Ligne'))),
          const SizedBox(height: 8),
          if (items.isEmpty) Padding(padding: EdgeInsets.all(16), child: Text('Aucune ligne enregistrée', style: TextStyle(color: QhseColors.textSecondary))),
          ...items.map((m) => Card(child: ListTile(
                title: Text('${m['jobTitle']} — ${m['hazard']}'),
                subtitle: Text('${m['riskDescription'] ?? ''} • EPI: ${m['epi']?['name'] ?? '—'} • EPC: ${m['epc']?['name'] ?? '—'}'),
                onTap: () => _openForm(record: m),
              ))),
        ],
      ),
    );
  }
}

// --- Signature électronique — dessin réel au doigt, sans dépendance externe ---
class SignatureCanvas extends StatefulWidget {
  final String label;
  final void Function(String? base64Png) onChanged;
  const SignatureCanvas({super.key, required this.label, required this.onChanged});
  @override
  State<SignatureCanvas> createState() => SignatureCanvasState();
}

class SignatureCanvasState extends State<SignatureCanvas> {
  final GlobalKey _boundaryKey = GlobalKey();
  final List<Offset?> _points = [];

  Future<String?> capture() async {
    if (_points.where((p) => p != null).isEmpty) return null;
    final boundary = _boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    return 'data:image/png;base64,${base64Encode(bytes)}';
  }

  void clear() { setState(() => _points.clear()); widget.onChanged(null); }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(widget.label, style: TextStyle(fontSize: 12, color: QhseColors.textSecondary)),
        TextButton(onPressed: clear, child: const Text('Effacer', style: TextStyle(fontSize: 12))),
      ]),
      RepaintBoundary(
        key: _boundaryKey,
        child: GestureDetector(
          onPanStart: (d) => setState(() => _points.add(d.localPosition)),
          onPanUpdate: (d) { setState(() => _points.add(d.localPosition)); widget.onChanged('pending'); },
          onPanEnd: (_) => setState(() => _points.add(null)),
          child: Container(
            height: 140, width: double.infinity,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: CustomPaint(painter: _SignaturePainter(_points)),
          ),
        ),
      ),
    ]);
  }
}

class _SignaturePainter extends CustomPainter {
  final List<Offset?> points;
  _SignaturePainter(this.points);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..strokeWidth = 2..strokeCap = StrokeCap.round;
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) canvas.drawLine(points[i]!, points[i + 1]!, paint);
    }
  }
  @override
  bool shouldRepaint(_SignaturePainter oldDelegate) => true;
}

// --- Attribution (dotation) avec signature électronique ---
class AttributionTab extends StatefulWidget {
  const AttributionTab({super.key});
  @override
  State<AttributionTab> createState() => _AttributionTabState();
}

class _AttributionTabState extends State<AttributionTab> {
  final api = Api();
  List items = [], epis = [], employees = [];
  bool loading = true;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      items = List.from(await api.get('/epi/assignments'));
      epis = List.from(await api.get('/epi/catalog'));
      employees = List.from(await api.get('/epi/employees'));
    } catch (_) {}
    setState(() => loading = false);
  }

  Future<void> _openForm() async {
    final empKey = GlobalKey<SignatureCanvasState>();
    final respKey = GlobalKey<SignatureCanvasState>();
    String? employeeId, epiId;
    final quantity = TextEditingController(text: '1');
    final size = TextEditingController();
    final reason = TextEditingController();
    final expectedDays = TextEditingController();
    String condition = 'Neuf';
    String? formError;
    bool saving = false;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
        title: const Text('Nouvelle dotation EPI'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: employeeId, isExpanded: true,
              items: employees.map<DropdownMenuItem<String>>((e) => DropdownMenuItem(value: e['id'] as String, child: Text('${e['firstName']} ${e['lastName']}'))).toList(),
              onChanged: (v) => setD(() => employeeId = v),
              decoration: const InputDecoration(labelText: 'Employé'),
            ),
            DropdownButtonFormField<String>(
              value: epiId, isExpanded: true,
              items: epis.map<DropdownMenuItem<String>>((e) => DropdownMenuItem(value: e['id'] as String, child: Text(e['name']))).toList(),
              onChanged: (v) => setD(() => epiId = v),
              decoration: const InputDecoration(labelText: 'EPI'),
            ),
            TextField(controller: quantity, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantité')),
            TextField(controller: size, decoration: const InputDecoration(labelText: 'Taille')),
            TextField(controller: expectedDays, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Durée prévue (jours, optionnel)')),
            TextField(controller: reason, decoration: const InputDecoration(labelText: 'Motif')),
            const SizedBox(height: 8),
            SignatureCanvas(key: empKey, label: 'Signature du salarié', onChanged: (_) {}),
            const SizedBox(height: 8),
            SignatureCanvas(key: respKey, label: 'Signature du responsable', onChanged: (_) {}),
            if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          FilledButton(
            onPressed: saving ? null : () async {
              if (employeeId == null || epiId == null) { setD(() => formError = 'Employé et EPI obligatoires'); return; }
              setD(() => saving = true);
              final empSig = await empKey.currentState?.capture();
              final respSig = await respKey.currentState?.capture();
              if (empSig == null || respSig == null) { setD(() { saving = false; formError = 'Les deux signatures sont requises'; }); return; }
              final me = await api.currentUser();
              final distributedAt = DateTime.now();
              final days = int.tryParse(expectedDays.text);
              final renewalAt = days != null ? distributedAt.add(Duration(days: days)).toIso8601String() : null;
              try {
                await api.post('/epi/assignments', {
                  'code': 'DOT-${DateTime.now().millisecondsSinceEpoch}',
                  'employeeId': employeeId, 'epiId': epiId, 'quantity': int.tryParse(quantity.text) ?? 1, 'size': size.text,
                  'distributedAt': distributedAt.toIso8601String(), 'renewalAt': renewalAt,
                  'expectedDurationDays': days, 'reason': reason.text, 'condition': condition,
                  'responsibleId': me?['id'], 'employeeSignature': empSig, 'responsibleSignature': respSig,
                });
                if (context.mounted) Navigator.pop(c);
                load();
              } catch (e) { setD(() { saving = false; formError = '$e'; }); }
            },
            child: Text(saving ? 'Enregistrement…' : 'Valider la dotation'),
          ),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: _openForm, icon: const Icon(Icons.add, size: 16), label: const Text('Nouvelle dotation'))),
          const SizedBox(height: 8),
          if (items.isEmpty) Padding(padding: EdgeInsets.all(16), child: Text('Aucune dotation enregistrée', style: TextStyle(color: QhseColors.textSecondary))),
          ...items.map((a) => Card(child: ListTile(
                title: Text('${a['code']} — ${a['employee']?['firstName'] ?? ''} ${a['employee']?['lastName'] ?? ''}'),
                subtitle: Text('${a['epi']?['name'] ?? '—'} • qté ${a['quantity']} • ${(a['distributedAt'] ?? '').toString().substring(0, 10)}'),
              ))),
        ],
      ),
    );
  }
}

// --- Renouvellements par paliers (30 / 60 / 90 jours, expirés) ---
class RenewalBucketsTab extends StatefulWidget {
  const RenewalBucketsTab({super.key});
  @override
  State<RenewalBucketsTab> createState() => _RenewalBucketsTabState();
}

class _RenewalBucketsTabState extends State<RenewalBucketsTab> {
  final api = Api();
  Map<String, dynamic> buckets = {'expired': [], 'within30': [], 'within60': [], 'within90': []};
  bool loading = true;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try { buckets = Map<String, dynamic>.from(await api.get('/epi/renewal-buckets')); } catch (_) {}
    setState(() => loading = false);
  }

  Widget _section(String title, String key, Color color) {
    final list = List.from(buckets[key] ?? []);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
      const SizedBox(height: 6),
      if (list.isEmpty) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text('Aucune dotation dans ce palier', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12))),
      ...list.map((r) => Card(child: ListTile(
            title: Text('${r['employee']?['firstName'] ?? ''} ${r['employee']?['lastName'] ?? ''}'),
            subtitle: Text(r['epi']?['name'] ?? '—'),
            trailing: Text((r['renewalAt'] ?? '').toString().substring(0, 10), style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ))),
      const SizedBox(height: 16),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _section('🔴 Expirés', 'expired', QhseColors.red),
          _section('🔴 Sous 30 jours', 'within30', QhseColors.red),
          _section('🟠 Sous 60 jours', 'within60', QhseColors.amber),
          _section('🟡 Sous 90 jours', 'within90', QhseColors.blue),
        ],
      ),
    );
  }
}
