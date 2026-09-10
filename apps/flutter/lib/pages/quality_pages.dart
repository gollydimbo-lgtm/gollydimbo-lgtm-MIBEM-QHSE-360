import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api.dart';
import '../theme.dart';

const Map<String, String> kDomainLabels = {
  'QUALITE': 'Qualité (centré produit/ligne/lot)',
  'SECURITE': 'Sécurité',
  'HYGIENE': 'Hygiène',
  'ENVIRONNEMENT': 'Environnement',
  'EPI_EPC': 'EPI/EPC',
  'MAINTENANCE': 'Maintenance',
  'FOURNISSEUR': 'Fournisseur',
  'AUTRE': 'Autre',
};
const Map<String, String> kFrequencyLabels = {
  'DAILY': 'Quotidienne', 'WEEKLY': 'Hebdomadaire', 'MONTHLY': 'Mensuelle',
  'QUARTERLY': 'Trimestrielle', 'BIANNUAL': 'Semestrielle', 'ANNUAL': 'Annuelle', 'CUSTOM': 'Personnalisée',
};
const Map<String, String> kDecisionLabels = {
  'CONFORME': 'Conforme', 'CONFORME_SOUS_RESERVE': 'Conforme sous réserve', 'NON_CONFORME': 'Non conforme', 'REFUSE': 'Refusé',
};

// --- Création / modification d'un type de contrôle ---
Future<void> showControlTypeDialog(BuildContext context, Api api, {Map? record, required VoidCallback onSaved}) async {
  final name = TextEditingController(text: record?['name'] ?? '');
  String domain = record?['domain'] ?? 'QUALITE';
  String? formError;
  bool saving = false;
  await showDialog(
    context: context,
    builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
      title: Text(record == null ? 'Nouveau type de contrôle' : 'Modifier le type'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Nom')),
          DropdownButtonFormField<String>(
            value: domain, isExpanded: true,
            items: kDomainLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (v) => setD(() => domain = v ?? 'QUALITE'),
            decoration: const InputDecoration(labelText: 'Domaine'),
          ),
          if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
        ]),
      ),
      actions: [
        if (record != null) TextButton(
          onPressed: () async {
            try { await api.delete('/quality/types/${record['id']}'); if (context.mounted) Navigator.pop(c); onSaved(); }
            catch (e) { setD(() => formError = '$e'); }
          },
          child: const Text('Supprimer', style: TextStyle(color: QhseColors.red)),
        ),
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
        FilledButton(
          onPressed: saving ? null : () async {
            setD(() => saving = true);
            try {
              if (record != null) await api.patch('/quality/types/${record['id']}', {'name': name.text, 'domain': domain});
              else await api.post('/quality/types', {'code': 'CTYPE-${DateTime.now().millisecondsSinceEpoch}', 'name': name.text, 'domain': domain});
              if (context.mounted) Navigator.pop(c);
              onSaved();
            } catch (e) { setD(() { saving = false; formError = '$e'; }); }
          },
          child: Text(saving ? 'Enregistrement…' : 'Enregistrer'),
        ),
      ],
    )),
  );
}

// --- Tableau de bord Contrôles qualité, à onglets ---
class QualityHome extends StatefulWidget {
  const QualityHome({super.key});
  @override
  State<QualityHome> createState() => _QualityHomeState();
}

class _QualityHomeState extends State<QualityHome> {
  final api = Api();
  List controls = [];
  List types = [];
  List schedules = [];
  Map<String, dynamic> buckets = {'overdue': [], 'dueSoon': [], 'upcoming': []};
  bool loading = true;
  String domainFilter = '';
  int tabIndex = 0;
  bool generatingId = false;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      controls = List.from(await api.get('/quality/controls'));
      types = List.from(await api.get('/quality/types'));
      schedules = List.from(await api.get('/quality/schedules'));
      buckets = Map<String, dynamic>.from(await api.get('/quality/schedules-buckets'));
    } catch (_) {}
    setState(() => loading = false);
  }

  List get filtered => domainFilter.isEmpty ? controls : controls.where((c) => c['domain'] == domainFilter).toList();
  List get domains => controls.map((c) => c['domain']).toSet().toList();

  List<KpiStat> get kpis {
    final list = filtered;
    final soumis = list.where((c) => c['status'] != 'DRAFT' && c['status'] != 'IN_PROGRESS').toList();
    final conformes = list.where((c) => c['status'] == 'COMPLIANT').length;
    final nonConformes = list.where((c) => c['status'] == 'NON_COMPLIANT').length;
    final enAttente = list.where((c) => c['status'] == 'DRAFT' || c['status'] == 'IN_PROGRESS').length;
    final taux = soumis.isEmpty ? null : (conformes / soumis.length * 100).round();
    final overdue = (buckets['overdue'] as List? ?? []).length;
    return [
      KpiStat('Contrôles enregistrés', '${list.length}', color: QhseColors.blue, icon: Icons.fact_check_outlined),
      KpiStat('En attente', '$enAttente', color: QhseColors.amber, icon: Icons.hourglass_empty),
      KpiStat('Conformes', '$conformes', color: QhseColors.green, icon: Icons.check_circle_outline),
      KpiStat('Non conformes', '$nonConformes', color: QhseColors.red, icon: Icons.error_outline),
      KpiStat('Taux de conformité', taux == null ? '—' : '$taux%', color: QhseColors.amber, icon: Icons.insights_outlined),
      KpiStat('Contrôles en retard', '$overdue', color: overdue > 0 ? QhseColors.red : QhseColors.green, icon: Icons.warning_amber_outlined),
    ];
  }

  Future<void> generateNow(Map s) async {
    setState(() => generatingId = true);
    try {
      await api.post('/quality/schedules/${s['id']}/generate', {});
      await load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    setState(() => generatingId = false);
  }

  Future<void> _openScheduleDialog({Map? record}) async {
    String? typeId = record?['typeId'];
    String frequency = record?['frequency'] ?? 'WEEKLY';
    final name = TextEditingController(text: record?['name'] ?? '');
    final intervalDays = TextEditingController(text: record?['intervalDays']?.toString() ?? '');
    DateTime nextDueDate = record != null ? DateTime.parse(record['nextDueDate']) : DateTime.now();
    String? formError;
    bool saving = false;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
        title: Text(record == null ? 'Nouveau planning' : 'Modifier le planning'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Nom')),
            DropdownButtonFormField<String>(
              value: typeId, isExpanded: true,
              items: types.map<DropdownMenuItem<String>>((t) => DropdownMenuItem(value: t['id'] as String, child: Text(t['name']))).toList(),
              onChanged: (v) => setD(() => typeId = v),
              decoration: const InputDecoration(labelText: 'Type de contrôle (optionnel)'),
            ),
            DropdownButtonFormField<String>(
              value: frequency,
              items: kFrequencyLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
              onChanged: (v) => setD(() => frequency = v ?? 'WEEKLY'),
              decoration: const InputDecoration(labelText: 'Fréquence'),
            ),
            if (frequency == 'CUSTOM') TextField(controller: intervalDays, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Intervalle (jours)')),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Prochaine échéance : ${nextDueDate.day}/${nextDueDate.month}/${nextDueDate.year}'),
              trailing: const Icon(Icons.edit_calendar),
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: nextDueDate, firstDate: DateTime(2020), lastDate: DateTime(2035));
                if (d != null) setD(() => nextDueDate = d);
              },
            ),
            if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
          ]),
        ),
        actions: [
          if (record != null) TextButton(
            onPressed: () async {
              try { await api.delete('/quality/schedules/${record['id']}'); if (context.mounted) Navigator.pop(c); load(); }
              catch (e) { setD(() => formError = '$e'); }
            },
            child: const Text('Supprimer', style: TextStyle(color: QhseColors.red)),
          ),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          FilledButton(
            onPressed: saving ? null : () async {
              setD(() => saving = true);
              final payload = {'name': name.text, 'typeId': typeId, 'frequency': frequency, 'intervalDays': intervalDays.text.isEmpty ? null : int.tryParse(intervalDays.text), 'nextDueDate': nextDueDate.toIso8601String()};
              try {
                if (record != null) await api.patch('/quality/schedules/${record['id']}', payload);
                else await api.post('/quality/schedules', {'code': 'SCHED-${DateTime.now().millisecondsSinceEpoch}', ...payload});
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

  Widget _scheduleSection(String title, List items, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color))),
      if (items.isEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Aucun planning dans ce palier', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12))),
      ...items.map((s) => Card(child: ListTile(
            title: Text(s['name'] ?? ''),
            subtitle: Text('${kFrequencyLabels[s['frequency']] ?? s['frequency']} • échéance ${(s['nextDueDate'] ?? '').toString().substring(0, 10)}'),
            onTap: () => _openScheduleDialog(record: s),
            trailing: TextButton(onPressed: () => generateNow(s), child: const Text('Générer')),
          ))),
    ]);
  }

  @override
  Widget build(BuildContext c) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Contrôle Qualité'),
          bottom: TabBar(
            onTap: (i) => setState(() => tabIndex = i),
            tabs: const [Tab(text: 'Tableau de bord'), Tab(text: 'Registre'), Tab(text: 'Planification')],
          ),
        ),
        floatingActionButton: tabIndex == 2
            ? FloatingActionButton.extended(onPressed: () => _openScheduleDialog(), icon: const Icon(Icons.add), label: const Text('Planning'))
            : FloatingActionButton.extended(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const NewControlPage())).then((_) => load()), icon: const Icon(Icons.add), label: const Text('Nouveau contrôle')),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : IndexedStack(index: tabIndex, children: [
                // Tableau de bord
                RefreshIndicator(
                  onRefresh: load,
                  child: ListView(padding: const EdgeInsets.only(top: 12, bottom: 12), children: [
                    if (domains.length > 1)
                      SizedBox(
                        height: 40,
                        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
                          Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: const Text('Tous domaines'), selected: domainFilter.isEmpty, onSelected: (_) => setState(() => domainFilter = ''))),
                          ...domains.map((d) => Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: Text('$d'), selected: domainFilter == d, onSelected: (_) => setState(() => domainFilter = d)))),
                        ]),
                      ),
                    const SizedBox(height: 8),
                    KpiBar(kpis),
                  ]),
                ),
                // Registre
                RefreshIndicator(
                  onRefresh: load,
                  child: ListView(
                    padding: const EdgeInsets.only(top: 12, bottom: 12),
                    children: filtered.isEmpty
                        ? const [Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Aucun contrôle enregistré')))]
                        : filtered.map((x) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Card(child: ListTile(
                                title: Text('${x['code']} — ${x['status']}'),
                                subtitle: Text('${x['type']?['name'] ?? x['domain'] ?? ''} • ${x['lotNumber'] ?? ''} • ${(x['controlDate'] ?? '').toString().substring(0, 10)}'),
                                trailing: x['finalDecision'] != null ? Text(kDecisionLabels[x['finalDecision']] ?? x['finalDecision'], style: const TextStyle(fontSize: 11)) : null,
                                onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => ControlPage(controlId: x['id']))).then((_) => load()),
                              )),
                            )).toList(),
                  ),
                ),
                // Planification
                RefreshIndicator(
                  onRefresh: load,
                  child: ListView(padding: const EdgeInsets.all(12), children: [
                    _scheduleSection('🔴 En retard', buckets['overdue'] ?? [], QhseColors.red),
                    _scheduleSection('🟡 Sous 7 jours', buckets['dueSoon'] ?? [], QhseColors.amber),
                    _scheduleSection('À venir', buckets['upcoming'] ?? [], QhseColors.blue),
                  ]),
                ),
              ]),
      ),
    );
  }
}

// --- Nouveau contrôle : type d'abord, champs conditionnels ensuite ---
class NewControlPage extends StatefulWidget {
  const NewControlPage({super.key});
  @override
  State<NewControlPage> createState() => _NewControlPageState();
}

class _NewControlPageState extends State<NewControlPage> {
  final api = Api();
  final code = TextEditingController(text: 'CTRL-${DateTime.now().millisecondsSinceEpoch}');
  final lot = TextEditingController();
  List sites = [], products = [], shifts = [], templates = [], types = [];
  String? siteId, lineId, machineId, productId, formatId, shiftId, templateId, typeId;
  List lines = [], machines = [], formats = [];
  bool busy = false;

  Map? get selectedType => types.firstWhereOrNullLocal((t) => t['id'] == typeId);
  String get domain => selectedType?['domain'] ?? 'QUALITE';
  bool get isQualite => domain == 'QUALITE';

  Future<void> init() async {
    try {
      final r = await api.get('/quality/catalogs');
      sites = List.from(r[0]); products = List.from(r[1]); shifts = List.from(r[2]);
      types = List.from(await api.get('/quality/types'));
      templates = List.from(await api.get('/quality/templates'));
      setState(() {});
    } catch (e) { _msg('$e'); }
  }

  @override
  void initState() { super.initState(); init(); }

  List get filteredTemplates => typeId == null ? templates : templates.where((t) => t['typeId'] == typeId).toList();

  Future<void> create() async {
    if (isQualite && (lineId == null || productId == null || shiftId == null || lot.text.isEmpty)) { _msg('Ligne, produit, quart et lot sont obligatoires pour un contrôle qualité'); return; }
    setState(() => busy = true);
    try {
      final x = await api.post('/quality/controls', {
        'code': code.text, 'domain': domain, 'typeId': typeId,
        'siteId': siteId, 'lineId': isQualite ? lineId : null, 'machineId': machineId,
        'productId': isQualite ? productId : null, 'formatId': formatId,
        'shiftId': isQualite ? shiftId : null, 'lotNumber': isQualite ? lot.text : null,
        'templateId': templateId,
      });
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ControlPage(controlId: x['id'])));
    } catch (e) { _msg('$e'); }
    setState(() => busy = false);
  }

  void _msg(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: const Text('Nouveau contrôle')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(controller: code, decoration: const InputDecoration(labelText: 'Code contrôle')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: typeId, isExpanded: true,
                  items: types.map<DropdownMenuItem<String>>((t) => DropdownMenuItem(value: t['id'] as String, child: Text(t['name']))).toList(),
                  onChanged: (v) => setState(() { typeId = v; templateId = null; }),
                  decoration: const InputDecoration(labelText: 'Type de contrôle (optionnel = qualité classique)'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: () => showControlTypeDialog(context, api, onSaved: () async { types = List.from(await api.get('/quality/types')); setState(() {}); }), child: const Text('+ Type')),
            ]),
            const SizedBox(height: 10),
            if (isQualite) ...[
              _drop('Site', siteId, sites.map((x) => DropdownMenuItem<String>(value: x['id'] as String, child: Text(x['name']))).toList(), (v) {
                siteId = v; final s = sites.firstWhere((x) => x['id'] == v); setState(() { lines = List.from(s['lines'] ?? []); lineId = null; machineId = null; });
              }),
              _drop('Ligne', lineId, lines.map((x) => DropdownMenuItem<String>(value: x['id'] as String, child: Text(x['name']))).toList(), (v) {
                lineId = v; final l = lines.firstWhere((x) => x['id'] == v); setState(() => machines = List.from(l['machines'] ?? []));
              }),
              _drop('Machine', machineId, machines.map((x) => DropdownMenuItem<String>(value: x['id'] as String, child: Text(x['name']))).toList(), (v) => setState(() => machineId = v)),
              _drop('Produit', productId, products.map((x) => DropdownMenuItem<String>(value: x['id'] as String, child: Text(x['name']))).toList(), (v) {
                productId = v; final p = products.firstWhere((x) => x['id'] == v); setState(() => formats = List.from(p['formats'] ?? []));
              }),
              _drop('Format', formatId, formats.map((x) => DropdownMenuItem<String>(value: x['id'] as String, child: Text(x['label']))).toList(), (v) => setState(() => formatId = v)),
              _drop('Quart', shiftId, shifts.map((x) => DropdownMenuItem<String>(value: x['id'] as String, child: Text(x['name']))).toList(), (v) => setState(() => shiftId = v)),
              TextField(controller: lot, decoration: const InputDecoration(labelText: 'Numéro de lot')),
              const SizedBox(height: 10),
            ],
            _drop('Modèle de contrôle (optionnel)', templateId, filteredTemplates.map<DropdownMenuItem<String>>((x) => DropdownMenuItem<String>(value: x['id'] as String, child: Text(x['name']))).toList(), (v) => setState(() => templateId = v)),
            const SizedBox(height: 18),
            FilledButton.icon(onPressed: busy ? null : create, icon: const Icon(Icons.play_arrow), label: Text(busy ? 'Création...' : 'Démarrer le contrôle')),
          ],
        ),
      );

  Widget _drop(String label, String? value, List<DropdownMenuItem<String>> items, ValueChanged<String?> onChanged) =>
      Padding(padding: const EdgeInsets.only(bottom: 10), child: DropdownButtonFormField<String>(value: value, isExpanded: true, decoration: InputDecoration(labelText: label), items: items, onChanged: onChanged));
}

extension _FirstWhereOrNull on List {
  Map? firstWhereOrNullLocal(bool Function(Map) test) {
    for (final e in this) { if (test(e as Map)) return e; }
    return null;
  }
}

// --- Saisie des résultats point par point + soumission ---
class ControlPage extends StatefulWidget {
  final String controlId;
  const ControlPage({super.key, required this.controlId});
  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  final api = Api();
  Map<String, dynamic>? c;
  Map<String, dynamic> vals = {};
  Map<String, bool> naFlags = {};
  Map<String, TextEditingController> textCtrls = {};
  bool loading = true;
  bool submitting = false;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      c = Map<String, dynamic>.from(await api.get('/quality/controls/${widget.controlId}'));
      for (final r in List.from(c?['results'] ?? [])) {
        vals[r['pointId']] = r['value'];
        naFlags[r['pointId']] = r['notApplicable'] == true;
      }
    } catch (_) {}
    setState(() => loading = false);
  }

  Future<void> result(dynamic p, dynamic value, {bool notApplicable = false}) async {
    try {
      await api.post('/quality/controls/${widget.controlId}/results', {'pointId': p['id'], 'value': value, 'notApplicable': notApplicable});
      vals[p['id']] = value;
      naFlags[p['id']] = notApplicable;
      setState(() {});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> photo() async {
    String? name; Uint8List? bytes; String mime = 'image/jpeg';
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
      final r = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (r == null || r.files.single.bytes == null) return;
      name = r.files.single.name; bytes = r.files.single.bytes;
    } else {
      final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 75);
      if (x == null) return;
      name = x.name; bytes = await x.readAsBytes();
    }
    try {
      final a = await api.post('/attachments/base64', {'fileName': name, 'mimeType': mime, 'base64': base64Encode(bytes!)});
      await api.post('/quality/controls/${widget.controlId}/attachments', {'attachmentId': a['id']});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo ajoutée au contrôle')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  bool get closed => ['COMPLIANT', 'NON_COMPLIANT', 'CANCELLED'].contains(c?['status']);
  List get missingRequired {
    final pts = List.from(c?['template']?['points'] ?? []);
    return pts.where((p) => p['required'] == true && naFlags[p['id']] != true && vals[p['id']] == null).toList();
  }

  Future<void> submit() async {
    setState(() => submitting = true);
    try { await api.post('/quality/controls/${widget.controlId}/submit', {}); await load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
    setState(() => submitting = false);
  }

  Future<void> sign() async {
    final controller = TextEditingController();
    final s = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Signature numérique'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Nom / signature')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Signer')),
        ],
      ),
    );
    if (s != null && s.isNotEmpty) await api.post('/quality/controls/${widget.controlId}/signatures', {'type': 'CONTROLLER', 'signatureData': s});
  }

  Future<void> delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Supprimer définitivement le contrôle ${c?['code']} ? Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer', style: TextStyle(color: QhseColors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try { await api.delete('/quality/controls/${widget.controlId}'); if (mounted) Navigator.pop(context); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  Widget _pointInput(Map p) {
    final id = p['id'];
    final isNa = naFlags[id] == true;
    final closedOrNa = closed || isNa;
    Widget input;
    switch (p['type']) {
      case 'NUMERIC':
        textCtrls[id] ??= TextEditingController(text: vals[id]?.toString() ?? '');
        input = TextField(controller: textCtrls[id], enabled: !closedOrNa, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: p['unit'] ?? 'Valeur'), onSubmitted: (v) => result(p, num.tryParse(v)));
        break;
      case 'CHOICE':
        final choices = List<String>.from(p['choices'] ?? []);
        input = DropdownButtonFormField<String>(value: vals[id] as String?, items: choices.map((ch) => DropdownMenuItem(value: ch, child: Text(ch))).toList(), onChanged: closedOrNa ? null : (v) { if (v != null) result(p, v); }, decoration: const InputDecoration(labelText: 'Choix'));
        break;
      case 'TEXT':
      case 'PHOTO':
        textCtrls[id] ??= TextEditingController(text: vals[id]?.toString() ?? '');
        input = TextField(controller: textCtrls[id], enabled: !closedOrNa, decoration: const InputDecoration(labelText: 'Réponse'), onSubmitted: (v) => result(p, v));
        break;
      default:
        input = Switch(value: vals[id] == true, onChanged: closedOrNa ? null : (v) => result(p, v));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      input,
      if (!closed) CheckboxListTile(
        dense: true, contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading,
        title: const Text('Non applicable', style: TextStyle(fontSize: 12)),
        value: isNa,
        onChanged: (v) => result(p, null, notApplicable: v ?? false),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final pts = List.from(c?['template']?['points'] ?? []);
    final missing = missingRequired;
    return Scaffold(
      appBar: AppBar(title: Text('${c?['code']}'), actions: [IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Supprimer', onPressed: delete)]),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Card(child: ListTile(
          title: Text('${c?['productRef']?['name'] ?? c?['type']?['name'] ?? c?['domain'] ?? ''}${c?['lotNumber'] != null ? ' • lot ${c?['lotNumber']}' : ''}'),
          subtitle: Text('${c?['productionLine']?['name'] ?? ''} ${c?['shiftRef']?['name'] ?? ''} • ${c?['status']}'.trim()),
        )),
        if (c?['finalDecision'] != null || c?['conformityRate'] != null)
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            if (c?['conformityRate'] != null) Text('Taux de conformité : ${c?['conformityRate']}%', style: const TextStyle(fontWeight: FontWeight.bold)),
            if (c?['finalDecision'] != null) Text(kDecisionLabels[c?['finalDecision']] ?? c?['finalDecision'], style: TextStyle(fontWeight: FontWeight.bold, color: c?['finalDecision'] == 'CONFORME' ? QhseColors.green : c?['finalDecision'] == 'REFUSE' ? QhseColors.red : QhseColors.amber)),
          ]))),
        ...pts.map((p) => Card(child: Padding(padding: const EdgeInsets.all(8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${p['label']}${p['required'] == true ? ' *' : ''}${p['critical'] == true ? '  ⚠ critique' : ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              _pointInput(p),
            ])))),
        const SizedBox(height: 8),
        if (!closed) OutlinedButton.icon(onPressed: photo, icon: const Icon(Icons.camera_alt), label: const Text('Ajouter une photo')),
        if (!closed) OutlinedButton.icon(onPressed: sign, icon: const Icon(Icons.draw), label: const Text('Signer')),
        if (!closed && missing.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('${missing.length} point(s) obligatoire(s) restant(s) avant de pouvoir soumettre.', style: const TextStyle(color: QhseColors.amber, fontSize: 12))),
        if (!closed) FilledButton.icon(onPressed: (submitting || missing.isNotEmpty) ? null : submit, icon: const Icon(Icons.check_circle), label: Text(submitting ? 'Soumission...' : 'Soumettre et générer les NC')),
        if (closed) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text('Ce contrôle est clôturé — plus aucune modification possible.', style: TextStyle(color: QhseColors.textSecondary))),
      ]),
    );
  }
}
