import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../services/api.dart';
import '../services/sync_queue.dart';
import '../theme.dart';
import 'load_error_view.dart';
import '../i18n/i18n.dart';

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
  Object? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    error = null;
    try { items = List.from(await api.get(widget.endpoint)); } catch (e) { error = e; }
    setState(() => loading = false);
  }

  Future<void> _openForm({Map? record}) async {
    final name = TextEditingController(text: record?['name'] ?? '');
    String? formError;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
        title: Text(record == null ? t('epiEpcPages.nouvelleCategorieTitre', {'label': widget.label}) : t('epiEpcPages.modifierCategorieTitre')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: InputDecoration(labelText: t('epiEpcPages.nomLabel'))),
          if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
        ]),
        actions: [
          if (record != null) TextButton(
            onPressed: () async {
              try { await api.delete('${widget.endpoint}/${record['id']}'); if (context.mounted) Navigator.pop(c); load(); }
              catch (e) { setD(() => formError = '$e'); }
            },
            child: Text(t('epiEpcPages.supprimerBtn'), style: const TextStyle(color: QhseColors.red)),
          ),
          TextButton(onPressed: () => Navigator.pop(c), child: Text(t('epiEpcPages.annulerBtn'))),
          FilledButton(
            onPressed: () async {
              try {
                if (record != null) await api.patch('${widget.endpoint}/${record['id']}', {'name': name.text});
                else await api.post(widget.endpoint, {'name': name.text});
                if (context.mounted) Navigator.pop(c);
                load();
              } catch (e) { setD(() => formError = '$e'); }
            },
            child: Text(t('epiEpcPages.enregistrerBtn')),
          ),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return LoadErrorView(error: error, onRetry: load);
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: () => _openForm(), icon: const Icon(Icons.add, size: 16), label: Text(t('epiEpcPages.categorieBtn')))),
          const SizedBox(height: 8),
          if (items.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(t('epiEpcPages.aucuneCategorie'), style: TextStyle(color: QhseColors.textSecondary))),
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
  Object? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    error = null;
    try { items = List.from(await api.get('/epi/employees')); } catch (e) { error = e; }
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
        title: Text(record == null ? t('epiEpcPages.nouvelEmployeTitre') : t('epiEpcPages.modifierEmployeTitre')),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: matricule, decoration: InputDecoration(labelText: t('epiEpcPages.matriculeLabel'))),
            TextField(controller: firstName, decoration: InputDecoration(labelText: t('epiEpcPages.prenomLabel'))),
            TextField(controller: lastName, decoration: InputDecoration(labelText: t('epiEpcPages.nomLabel'))),
            TextField(controller: department, decoration: InputDecoration(labelText: t('epiEpcPages.departementLabel'))),
            TextField(controller: position, decoration: InputDecoration(labelText: t('epiEpcPages.posteLabel'))),
            if (record != null) CheckboxListTile(value: active, title: Text(t('epiEpcPages.actifLabel')), onChanged: (v) => setD(() => active = v ?? true), controlAffinity: ListTileControlAffinity.leading),
            if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
          ]),
        ),
        actions: [
          if (record != null) TextButton(
            onPressed: () async {
              try { await api.delete('/epi/employees/${record['id']}'); if (context.mounted) Navigator.pop(c); load(); }
              catch (e) { setD(() => formError = '$e'); }
            },
            child: Text(t('epiEpcPages.supprimerBtn'), style: const TextStyle(color: QhseColors.red)),
          ),
          TextButton(onPressed: () => Navigator.pop(c), child: Text(t('epiEpcPages.annulerBtn'))),
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
            child: Text(t('epiEpcPages.enregistrerBtn')),
          ),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return LoadErrorView(error: error, onRetry: load);
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: () => _openForm(), icon: const Icon(Icons.person_add_alt_1, size: 16), label: Text(t('epiEpcPages.employeBtn')))),
          const SizedBox(height: 8),
          if (items.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(t('epiEpcPages.aucunEmploye'), style: TextStyle(color: QhseColors.textSecondary))),
          ...items.map((e) => Card(child: ListTile(
                title: Text('${e['firstName']} ${e['lastName']}'),
                subtitle: Text('${e['matricule']} • ${e['department'] ?? '—'} • ${e['position'] ?? '—'}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  // Point 35 — fiche employé unifiée, même vue transversale que le web.
                  IconButton(icon: const Icon(Icons.badge_outlined, size: 20), tooltip: t('epiEpcPages.voirFicheTooltip'), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmployeeDossierPage(employee: e)))),
                  Icon(Icons.circle, size: 10, color: e['active'] == true ? QhseColors.green : QhseColors.red),
                ]),
                onTap: () => _openForm(record: e),
              ))),
        ],
      ),
    );
  }
}

// Point 35 — fiche employé unifiée : lecture seule, rassemble ce qui existe
// déjà ailleurs (événements sécurité victime/témoin, dotations EPI,
// habilitations, formations, expositions) sans dupliquer aucune donnée.
class EmployeeDossierPage extends StatefulWidget {
  final Map employee;
  const EmployeeDossierPage({super.key, required this.employee});
  @override
  State<EmployeeDossierPage> createState() => _EmployeeDossierPageState();
}

class _EmployeeDossierPageState extends State<EmployeeDossierPage> {
  final api = Api();
  Map? dossier;
  bool loading = true;
  Object? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try { dossier = Map.from(await api.get('/epi/employees/${widget.employee['id']}/dossier')); }
    catch (e) { error = e; }
    if (mounted) setState(() => loading = false);
  }

  Widget _section(String title, List items, String Function(Map) titleFn, String Function(Map) subtitleFn) {
    return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      const SizedBox(height: 6),
      if (items.isEmpty) Text(t('epiEpcPages.aucunElement'), style: TextStyle(color: QhseColors.textSecondary, fontSize: 12))
      else ...items.map((it) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text('${titleFn(Map.from(it))} — ${subtitleFn(Map.from(it))}', style: const TextStyle(fontSize: 12)))),
    ])));
  }

  @override
  Widget build(BuildContext context) {
    final d = dossier;
    return Scaffold(
      appBar: AppBar(title: Text(t('epiEpcPages.ficheTitre', {'nom': '${widget.employee['firstName']} ${widget.employee['lastName']}'}))),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? LoadErrorView(error: error, onRetry: load)
              : RefreshIndicator(
                  onRefresh: load,
                  child: ListView(padding: const EdgeInsets.all(12), children: [
                    _section(t('epiEpcPages.evenementsConcerne'), List.from(d?['evenementsConcerne'] ?? []), (e) => '${e['title']}', (e) => '${e['type']}'),
                    _section(t('epiEpcPages.evenementsTemoin'), List.from(d?['evenementsTemoin'] ?? []), (e) => '${e['title']}', (e) => '${e['type']}'),
                    _section(t('epiEpcPages.dotationsEpi'), List.from(d?['dotationsEpi'] ?? []), (a) => '${a['epi']?['name'] ?? '—'}', (a) => a['renewalAt'] != null ? t('epiEpcPages.renouvellementLe', {'date': a['renewalAt'].toString().substring(0, 10)}) : '—'),
                    _section(t('epiEpcPages.habilitations'), List.from(d?['habilitations'] ?? []), (h) => '${h['intitule']}', (h) => '${h['statut']}'),
                    _section(t('epiEpcPages.formations'), List.from(d?['formations'] ?? []), (f) => '${f['training']?['title'] ?? f['training']?['intitule'] ?? '—'}', (f) => '${f['resultat'] ?? '—'}'),
                    _section(t('epiEpcPages.expositionsSurveillees'), List.from(d?['expositions'] ?? []), (ex) => '${ex['agentDangereux'] ?? '—'}', (ex) => ex['conforme'] == null ? '—' : (ex['conforme'] == true ? t('epiEpcPages.conforme') : t('epiEpcPages.nonConforme'))),
                  ]),
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
  Object? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    error = null;
    try {
      items = List.from(await api.get('/epi/epc'));
      categories = List.from(await api.get('/epi/epc-categories'));
    } catch (e) { error = e; }
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
        title: Text(record == null ? t('epiEpcPages.nouvelEpcTitre') : t('epiEpcPages.modifierEpcTitre')),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: code, enabled: record == null, decoration: InputDecoration(labelText: t('epiEpcPages.codeLabel'))),
            TextField(controller: name, decoration: InputDecoration(labelText: t('epiEpcPages.designationLabel'))),
            DropdownButtonFormField<String>(
              value: categoryId, isExpanded: true,
              items: categories.map<DropdownMenuItem<String>>((cat) => DropdownMenuItem(value: cat['id'] as String, child: Text(cat['name']))).toList(),
              onChanged: (v) => setD(() => categoryId = v),
              decoration: InputDecoration(labelText: t('epiEpcPages.categorieLabel')),
            ),
            TextField(controller: location, decoration: InputDecoration(labelText: t('epiEpcPages.localisationLabel'))),
            TextField(controller: zone, decoration: InputDecoration(labelText: t('epiEpcPages.zoneLabel'))),
            TextField(controller: manufacturer, decoration: InputDecoration(labelText: t('epiEpcPages.fabricantLabel'))),
            DropdownButtonFormField<String>(
              value: status,
              items: [DropdownMenuItem(value: 'ACTIVE', child: Text(t('epiEpcPages.statutActif'))), DropdownMenuItem(value: 'MAINTENANCE', child: Text(t('epiEpcPages.statutMaintenance'))), DropdownMenuItem(value: 'NON_CONFORME', child: Text(t('epiEpcPages.statutNonConforme'))), DropdownMenuItem(value: 'HORS_SERVICE', child: Text(t('epiEpcPages.statutHorsService')))],
              onChanged: (v) => setD(() => status = v ?? 'ACTIVE'),
              decoration: InputDecoration(labelText: t('epiEpcPages.statutLabel')),
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
            child: Text(t('epiEpcPages.supprimerBtn'), style: const TextStyle(color: QhseColors.red)),
          ),
          TextButton(onPressed: () => Navigator.pop(c), child: Text(t('epiEpcPages.annulerBtn'))),
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
            child: Text(t('epiEpcPages.enregistrerBtn')),
          ),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return LoadErrorView(error: error, onRetry: load);
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: () => _openForm(), icon: const Icon(Icons.add, size: 16), label: Text(t('epiEpcPages.epcBtn')))),
          const SizedBox(height: 8),
          if (items.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(t('epiEpcPages.aucunEpc'), style: TextStyle(color: QhseColors.textSecondary))),
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
        title: Text(record == null ? t('epiEpcPages.nouvelEpiTitre') : t('epiEpcPages.modifierEpiTitre')),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: code, enabled: record == null, decoration: InputDecoration(labelText: t('epiEpcPages.codeLabel'))),
            TextField(controller: name, decoration: InputDecoration(labelText: t('epiEpcPages.designationLabel'))),
            DropdownButtonFormField<String>(
              value: categoryId, isExpanded: true,
              items: categories.map<DropdownMenuItem<String>>((cat) => DropdownMenuItem(value: cat['id'] as String, child: Text(cat['name']))).toList(),
              onChanged: (v) => setD(() => categoryId = v),
              decoration: InputDecoration(labelText: t('epiEpcPages.categorieLabel')),
            ),
            DropdownButtonFormField<String>(
              value: frequency,
              items: [DropdownMenuItem(value: 'DAILY', child: Text(t('epiEpcPages.frequenceQuotidienne'))), DropdownMenuItem(value: 'ANNUAL', child: Text(t('epiEpcPages.frequenceAnnuelle')))],
              onChanged: (v) => setD(() => frequency = v ?? 'DAILY'),
              decoration: InputDecoration(labelText: t('epiEpcPages.frequenceDistributionLabel')),
            ),
            Row(children: [
              Expanded(child: TextField(controller: manufacturer, decoration: InputDecoration(labelText: t('epiEpcPages.fabricantLabel')))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: model, decoration: InputDecoration(labelText: t('epiEpcPages.modeleLabel')))),
            ]),
            TextField(controller: standard, decoration: InputDecoration(labelText: t('epiEpcPages.normeApplicableLabel'))),
            TextField(controller: location, decoration: InputDecoration(labelText: t('epiEpcPages.emplacementLabel'))),
            Row(children: [
              Expanded(child: TextField(controller: minStock, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('epiEpcPages.stockMinimumLabel')))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: maxStock, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('epiEpcPages.stockMaximumLabel')))),
            ]),
            CheckboxListTile(value: disposable, title: Text(t('epiEpcPages.jetableLabel')), onChanged: (v) => setD(() => disposable = v ?? false), controlAffinity: ListTileControlAffinity.leading),
            CheckboxListTile(value: shared, title: Text(t('epiEpcPages.partageLabel')), onChanged: (v) => setD(() => shared = v ?? false), controlAffinity: ListTileControlAffinity.leading),
            if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
          ]),
        ),
        actions: [
          if (record != null) TextButton(
            onPressed: () async {
              try { await api.delete('/epi/catalog/${record['id']}'); if (context.mounted) Navigator.pop(c); load(); }
              catch (e) { setD(() => formError = '$e'); }
            },
            child: Text(t('epiEpcPages.supprimerBtn'), style: const TextStyle(color: QhseColors.red)),
          ),
          TextButton(onPressed: () => Navigator.pop(c), child: Text(t('epiEpcPages.annulerBtn'))),
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
            child: Text(t('epiEpcPages.enregistrerBtn')),
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
              ? t('epiEpcPages.stockRestantJournalier', {'stock': '$s', 'distribues': '${e['dailyDistributed'] ?? 0}'})
              : t('epiEpcPages.stockRestant', {'stock': '$s'}),
        ),
        trailing: low ? Chip(label: Text(t('epiEpcPages.stockBas')), backgroundColor: const Color(0xFFFFCDD2)) : null,
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
        OutlinedButton(onPressed: load, child: Text(t('epiEpcPages.reessayerBtn'))),
      ]));
    }
    final daily = stock.where((e) => e['frequency'] == 'DAILY').toList();
    final annual = stock.where((e) => e['frequency'] == 'ANNUAL').toList();
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: () => _openForm(), icon: const Icon(Icons.add, size: 16), label: Text(t('epiEpcPages.nouvelEpiBtn')))),
          const SizedBox(height: 8),
          Text(t('epiEpcPages.epiJournaliersTitre'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          ...daily.map((e) => _epiCard(e)),
          if (daily.isEmpty) Padding(padding: const EdgeInsets.all(8), child: Text(t('epiEpcPages.aucunEpiJournalier'), style: TextStyle(color: QhseColors.textSecondary))),
          const SizedBox(height: 16),
          Text(t('epiEpcPages.epiAnnuelsTitre'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          ...annual.map((e) => _epiCard(e)),
          if (annual.isEmpty) Padding(padding: const EdgeInsets.all(8), child: Text(t('epiEpcPages.aucunEpiAnnuel'), style: TextStyle(color: QhseColors.textSecondary))),
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
  Object? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    error = null;
    try {
      epiInsp = List.from(await api.get('/epi/epi-inspections'));
      epcInsp = List.from(await api.get('/epi/epc-inspections'));
      epis = List.from(await api.get('/epi/catalog'));
      epcs = List.from(await api.get('/epi/epc'));
    } catch (e) { error = e; }
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
        title: Text(isEpi ? t('epiEpcPages.nouvelleInspectionEpiTitre') : t('epiEpcPages.nouvelleInspectionEpcTitre')),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: targetId, isExpanded: true,
              items: options.map<DropdownMenuItem<String>>((o) => DropdownMenuItem(value: o['id'] as String, child: Text(o['name']))).toList(),
              onChanged: (v) => setD(() => targetId = v),
              decoration: InputDecoration(labelText: isEpi ? t('epiEpcPages.epiInspecteLabel') : t('epiEpcPages.epcInspecteLabel')),
            ),
            DropdownButtonFormField<String>(
              value: result,
              items: [DropdownMenuItem(value: 'CONFORME', child: Text(t('epiEpcPages.resultatConforme'))), DropdownMenuItem(value: 'NON_CONFORME', child: Text(t('epiEpcPages.resultatNonConforme'))), DropdownMenuItem(value: 'A_SURVEILLER', child: Text(t('epiEpcPages.resultatASurveiller'))), DropdownMenuItem(value: 'A_REFORMER', child: Text(t('epiEpcPages.resultatAReformer')))],
              onChanged: (v) => setD(() => result = v ?? 'CONFORME'),
              decoration: InputDecoration(labelText: t('epiEpcPages.resultatLabel')),
            ),
            TextField(controller: observations, decoration: InputDecoration(labelText: t('epiEpcPages.observationsLabel')), maxLines: 2),
            if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(t('epiEpcPages.annulerBtn'))),
          FilledButton(
            onPressed: () async {
              if (targetId == null) { setD(() => formError = t('epiEpcPages.selectionnezEquipement')); return; }
              final endpoint = isEpi ? '/epi/epi-inspections' : '/epi/epc-inspections';
              final key = isEpi ? 'epiId' : 'epcId';
              final payload = {key: targetId, 'result': result, 'observations': observations.text};
              try {
                await api.post(endpoint, payload);
                if (context.mounted) Navigator.pop(c);
                load();
              } on ApiException catch (e) {
                if (e.networkError) {
                  await SyncQueue.enqueue(isEpi ? 'epiInspection' : 'epcInspection', 'CREATE', payload);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('epiEpcPages.horsLigneInspectionMessage')), duration: const Duration(seconds: 4)));
                    Navigator.pop(c);
                  }
                  load();
                } else {
                  setD(() => formError = '$e');
                }
              } catch (e) { setD(() => formError = '$e'); }
            },
            child: Text(t('epiEpcPages.enregistrerBtn')),
          ),
        ],
      )),
    );
  }

  Color _resultColor(String? r) => r == 'NON_CONFORME' || r == 'A_REFORMER' ? QhseColors.red : r == 'A_SURVEILLER' ? QhseColors.amber : QhseColors.green;
  String _resultLabel(String? r) => {'CONFORME': t('epiEpcPages.resultatConforme'), 'NON_CONFORME': t('epiEpcPages.resultatNonConforme'), 'A_SURVEILLER': t('epiEpcPages.resultatASurveiller'), 'A_REFORMER': t('epiEpcPages.resultatAReformer')}[r] ?? '$r';
  bool _isBad(String? r) => r == 'NON_CONFORME' || r == 'A_REFORMER';

  Future<void> _createNcQuick({required String title, String? description, required String source, required int severity, String? epiId, String? epcId}) async {
    final titleCtrl = TextEditingController(text: title);
    final descCtrl = TextEditingController(text: description ?? '');
    String? formError;
    bool saving = false;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
        title: Text(t('epiEpcPages.nouvelleNcTitre')),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: titleCtrl, decoration: InputDecoration(labelText: t('epiEpcPages.titreLabel'))),
            TextField(controller: descCtrl, decoration: InputDecoration(labelText: t('epiEpcPages.descriptionLabel')), maxLines: 2),
            if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(t('epiEpcPages.annulerBtn'))),
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
            child: Text(saving ? t('epiEpcPages.enregistrementEnCours') : t('epiEpcPages.creerBtn')),
          ),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return LoadErrorView(error: error, onRetry: load);
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(children: [
            Expanded(child: Text(t('epiEpcPages.inspectionsEpiTitre'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
            FilledButton.icon(onPressed: () => _openForm(isEpi: true), icon: const Icon(Icons.add, size: 16), label: Text(t('epiEpcPages.nouvelleBtn'))),
          ]),
          const SizedBox(height: 6),
          if (epiInsp.isEmpty) Padding(padding: const EdgeInsets.all(8), child: Text(t('epiEpcPages.aucuneInspectionEpi'), style: TextStyle(color: QhseColors.textSecondary))),
          ...epiInsp.map((i) => Card(child: ListTile(
                title: Text(i['epi']?['name'] ?? '—'),
                subtitle: Text(i['observations'] ?? ''),
                trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(_resultLabel(i['result']), style: TextStyle(color: _resultColor(i['result']), fontSize: 12, fontWeight: FontWeight.w600)),
                  if (_isBad(i['result']))
                    TextButton(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 24)),
                      onPressed: () => _createNcQuick(
                        title: t('epiEpcPages.epiNonConformeTitre', {'nom': '${i['epi']?['name'] ?? ''}'}),
                        description: i['observations'],
                        source: 'EPI', severity: i['result'] == 'A_REFORMER' ? 3 : 2, epiId: i['epiId'],
                      ),
                      child: Text(t('epiEpcPages.creerNcBtn'), style: const TextStyle(fontSize: 11, color: QhseColors.red)),
                    ),
                ]),
              ))),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: Text(t('epiEpcPages.inspectionsEpcTitre'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
            FilledButton.icon(onPressed: () => _openForm(isEpi: false), icon: const Icon(Icons.add, size: 16), label: Text(t('epiEpcPages.nouvelleBtn'))),
          ]),
          const SizedBox(height: 6),
          if (epcInsp.isEmpty) Padding(padding: const EdgeInsets.all(8), child: Text(t('epiEpcPages.aucuneInspectionEpc'), style: TextStyle(color: QhseColors.textSecondary))),
          ...epcInsp.map((i) => Card(child: ListTile(
                title: Text(i['epc']?['name'] ?? '—'),
                subtitle: Text(i['observations'] ?? ''),
                trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(_resultLabel(i['result']), style: TextStyle(color: _resultColor(i['result']), fontSize: 12, fontWeight: FontWeight.w600)),
                  if (_isBad(i['result']))
                    TextButton(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 24)),
                      onPressed: () => _createNcQuick(
                        title: t('epiEpcPages.epcNonConformeTitre', {'nom': '${i['epc']?['name'] ?? ''}'}),
                        description: i['observations'],
                        source: 'EPC', severity: i['result'] == 'A_REFORMER' ? 3 : 2, epcId: i['epcId'],
                      ),
                      child: Text(t('epiEpcPages.creerNcBtn'), style: const TextStyle(fontSize: 11, color: QhseColors.red)),
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
  Object? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    error = null;
    try {
      items = List.from(await api.get('/epi/maintenance'));
      epcs = List.from(await api.get('/epi/epc'));
    } catch (e) { error = e; }
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
        title: Text(t('epiEpcPages.nouvelleInterventionTitre')),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: epcId, isExpanded: true,
              items: epcs.map<DropdownMenuItem<String>>((e) => DropdownMenuItem(value: e['id'] as String, child: Text('${e['code']} — ${e['name']}'))).toList(),
              onChanged: (v) => setD(() => epcId = v),
              decoration: InputDecoration(labelText: t('epiEpcPages.equipementLabel')),
            ),
            DropdownButtonFormField<String>(
              value: type,
              items: [DropdownMenuItem(value: 'PREVENTIVE', child: Text(t('epiEpcPages.typePreventive'))), DropdownMenuItem(value: 'CORRECTIVE', child: Text(t('epiEpcPages.typeCorrective')))],
              onChanged: (v) => setD(() => type = v ?? 'PREVENTIVE'),
              decoration: InputDecoration(labelText: t('epiEpcPages.typeInterventionLabel')),
            ),
            TextField(controller: description, decoration: InputDecoration(labelText: t('epiEpcPages.descriptionLabel')), maxLines: 2),
            TextField(controller: cost, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('epiEpcPages.coutOptionnelLabel'))),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(nextMaintenanceAt == null ? t('epiEpcPages.prochaineEcheanceLabel') : t('epiEpcPages.echeanceValeur', {'jour': '${nextMaintenanceAt!.day}', 'mois': '${nextMaintenanceAt!.month}', 'annee': '${nextMaintenanceAt!.year}'})),
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
          TextButton(onPressed: () => Navigator.pop(c), child: Text(t('epiEpcPages.annulerBtn'))),
          FilledButton(
            onPressed: saving ? null : () async {
              if (epcId == null) { setD(() => formError = t('epiEpcPages.selectionnezEquipement')); return; }
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
            child: Text(saving ? t('epiEpcPages.enregistrementEnCours') : t('epiEpcPages.enregistrerBtn')),
          ),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return LoadErrorView(error: error, onRetry: load);
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: _openForm, icon: const Icon(Icons.add, size: 16), label: Text(t('epiEpcPages.nouvelleInterventionBtn')))),
          const SizedBox(height: 8),
          if (items.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(t('epiEpcPages.aucuneIntervention'), style: TextStyle(color: QhseColors.textSecondary))),
          ...items.map((m) => Card(child: ListTile(
                leading: Icon(Icons.build, color: m['type'] == 'CORRECTIVE' ? QhseColors.red : QhseColors.blue),
                title: Text(m['epc']?['name'] ?? '—'),
                subtitle: Text('${m['type'] == 'PREVENTIVE' ? t('epiEpcPages.typePreventive') : t('epiEpcPages.typeCorrective')} • ${(m['date'] ?? '').toString().substring(0, 10)}${m['description'] != null && m['description'] != '' ? ' • ${m['description']}' : ''}'),
                trailing: m['nextMaintenanceAt'] != null ? Text(t('epiEpcPages.echeanceLabel', {'date': (m['nextMaintenanceAt']).toString().substring(0, 10)}), textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: QhseColors.textSecondary)) : null,
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
  Object? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    error = null;
    try {
      items = List.from(await api.get('/epi/job-risk-protection'));
      epis = List.from(await api.get('/epi/catalog'));
      epcs = List.from(await api.get('/epi/epc'));
    } catch (e) { error = e; }
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
        title: Text(record == null ? t('epiEpcPages.nouvelleLigneMatriceTitre') : t('epiEpcPages.modifierLigneTitre')),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: jobTitle, decoration: InputDecoration(labelText: t('epiEpcPages.posteLabel'))),
            TextField(controller: hazard, decoration: InputDecoration(labelText: t('epiEpcPages.dangerLabel'))),
            TextField(controller: riskDescription, decoration: InputDecoration(labelText: t('epiEpcPages.risqueLabel'))),
            TextField(controller: preventionMeasure, decoration: InputDecoration(labelText: t('epiEpcPages.mesurePreventionLabel'))),
            DropdownButtonFormField<String>(
              value: epiId, isExpanded: true,
              items: epis.map<DropdownMenuItem<String>>((e) => DropdownMenuItem(value: e['id'] as String, child: Text(e['name']))).toList(),
              onChanged: (v) => setD(() => epiId = v),
              decoration: InputDecoration(labelText: t('epiEpcPages.epiAssocieLabel')),
            ),
            DropdownButtonFormField<String>(
              value: epcId, isExpanded: true,
              items: epcs.map<DropdownMenuItem<String>>((e) => DropdownMenuItem(value: e['id'] as String, child: Text(e['name']))).toList(),
              onChanged: (v) => setD(() => epcId = v),
              decoration: InputDecoration(labelText: t('epiEpcPages.epcAssocieLabel')),
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
            child: Text(t('epiEpcPages.supprimerBtn'), style: const TextStyle(color: QhseColors.red)),
          ),
          TextButton(onPressed: () => Navigator.pop(c), child: Text(t('epiEpcPages.annulerBtn'))),
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
            child: Text(t('epiEpcPages.enregistrerBtn')),
          ),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return LoadErrorView(error: error, onRetry: load);
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: () => _openForm(), icon: const Icon(Icons.add, size: 16), label: Text(t('epiEpcPages.ligneBtn')))),
          const SizedBox(height: 8),
          if (items.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(t('epiEpcPages.aucuneLigne'), style: TextStyle(color: QhseColors.textSecondary))),
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
  Object? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    error = null;
    try {
      items = List.from(await api.get('/epi/assignments'));
      epis = List.from(await api.get('/epi/catalog'));
      employees = List.from(await api.get('/epi/employees'));
    } catch (e) { error = e; }
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
          TextButton(onPressed: () => Navigator.pop(c), child: Text(t('epiEpcPages.annulerBtn'))),
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
    if (error != null) return LoadErrorView(error: error, onRetry: load);
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
  Object? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    error = null;
    try { buckets = Map<String, dynamic>.from(await api.get('/epi/renewal-buckets')); } catch (e) { error = e; }
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
    if (error != null) return LoadErrorView(error: error, onRetry: load);
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
