import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api.dart';
import '../theme.dart';
import 'load_error_view.dart';
import 'capa_link_widget.dart';
import '../services/sync_queue.dart';
import '../i18n/i18n.dart';

const Map<String, String> kDomainKeys = {
  'QUALITE': 'domQualite',
  'SECURITE': 'domSecurite',
  'HYGIENE': 'domHygiene',
  'ENVIRONNEMENT': 'domEnvironnement',
  'EPI_EPC': 'domEpiEpc',
  'MAINTENANCE': 'domMaintenance',
  'FOURNISSEUR': 'domFournisseur',
  'AUTRE': 'domAutre',
};
String kDomainLabel(String? v) => v == null ? '—' : t('quality.${kDomainKeys[v] ?? 'domAutre'}');
const Map<String, String> kFrequencyKeys = {
  'DAILY': 'freqDaily', 'WEEKLY': 'freqWeekly', 'MONTHLY': 'freqMonthly',
  'QUARTERLY': 'freqQuarterly', 'BIANNUAL': 'freqBiannual', 'ANNUAL': 'freqAnnual', 'CUSTOM': 'freqCustom',
};
String kFrequencyLabel(String? v) { if (v == null) return '—'; final k = kFrequencyKeys[v]; return k == null ? v : t('quality.$k'); }
const Map<String, String> kDecisionKeys = {
  'CONFORME': 'decConforme', 'CONFORME_SOUS_RESERVE': 'decConformeSousReserve', 'NON_CONFORME': 'decNonConforme', 'REFUSE': 'decRefuse',
};
String kDecisionLabel(String? v) { if (v == null) return '—'; final k = kDecisionKeys[v]; return k == null ? v : t('quality.$k'); }

List<MapEntry<String, int>> _groupCount(List items, String Function(dynamic) keyFn) {
  final counts = <String, int>{};
  for (final item in items) {
    final key = keyFn(item);
    counts[key] = (counts[key] ?? 0) + 1;
  }
  final entries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return entries;
}

/// Anneau avec légende — même principe que celui du tableau de bord
/// général, pour rester visuellement cohérent dans toute l'application.
class _LabeledDonut extends StatelessWidget {
  final List<MapEntry<String, int>> entries;
  final List<Color> colors;
  const _LabeledDonut({required this.entries, required this.colors});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return Center(child: Text(t('quality.aucuneDonnee'), style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)));
    return Row(children: [
      Expanded(
        child: PieChart(
          PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 34,
            sections: [
              for (int i = 0; i < entries.length; i++)
                PieChartSectionData(
                  value: entries[i].value.toDouble(),
                  color: colors[i % colors.length],
                  radius: 34,
                  title: '${entries[i].value}',
                  titleStyle: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < entries.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: colors[i % colors.length], shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Expanded(child: Text(entries[i].key, style: TextStyle(fontSize: 10, color: QhseColors.textSecondary), overflow: TextOverflow.ellipsis)),
                ]),
              ),
          ],
        ),
      ),
    ]);
  }
}

/// Un petit panneau avec titre — même habillage que les Panel du web.
class _DashPanel extends StatelessWidget {
  final String title;
  final Widget child;
  const _DashPanel({required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: QhseColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: QhseColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: QhseColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          SizedBox(height: 160, child: child),
        ]),
      );
}

// --- Création / modification d'un type de contrôle ---
Future<void> showControlTypeDialog(BuildContext context, Api api, {Map? record, required VoidCallback onSaved}) async {
  final name = TextEditingController(text: record?['name'] ?? '');
  String domain = record?['domain'] ?? 'QUALITE';
  String? formError;
  bool saving = false;
  await showDialog(
    context: context,
    builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
      title: Text(record == null ? t('quality.nouveauTypeTitle') : t('quality.modifierTypeTitle')),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: InputDecoration(labelText: t('quality.nom'))),
          DropdownButtonFormField<String>(
            value: domain, isExpanded: true,
            items: kDomainKeys.keys.map((k) => DropdownMenuItem(value: k, child: Text(kDomainLabel(k)))).toList(),
            onChanged: (v) => setD(() => domain = v ?? 'QUALITE'),
            decoration: InputDecoration(labelText: t('quality.domaine')),
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
          child: Text(t('quality.supprimer'), style: const TextStyle(color: QhseColors.red)),
        ),
        TextButton(onPressed: () => Navigator.pop(c), child: Text(t('quality.annuler'))),
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
          child: Text(saving ? t('quality.enregistrementEnCours') : t('quality.enregistrer')),
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
  Object? error;
  String domainFilter = '';
  int tabIndex = 0;
  bool generatingId = false;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      controls = List.from(await api.get('/quality/controls'));
      types = List.from(await api.get('/quality/types'));
      schedules = List.from(await api.get('/quality/schedules'));
      buckets = Map<String, dynamic>.from(await api.get('/quality/schedules-buckets'));
    } catch (e) { error = e; }
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
      KpiStat(t('quality.kpiControlesEnregistres'), '${list.length}', color: QhseColors.blue, icon: Icons.fact_check_outlined),
      KpiStat(t('quality.kpiEnAttente'), '$enAttente', color: QhseColors.amber, icon: Icons.hourglass_empty),
      KpiStat(t('quality.kpiConformes'), '$conformes', color: QhseColors.green, icon: Icons.check_circle_outline),
      KpiStat(t('quality.kpiNonConformes'), '$nonConformes', color: QhseColors.red, icon: Icons.error_outline),
      KpiStat(t('quality.kpiTauxConformite'), taux == null ? '—' : '$taux%', color: QhseColors.amber, icon: Icons.insights_outlined),
      KpiStat(t('quality.kpiControlesEnRetard'), '$overdue', color: overdue > 0 ? QhseColors.red : QhseColors.green, icon: Icons.warning_amber_outlined),
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
        title: Text(record == null ? t('quality.nouveauPlanningTitle') : t('quality.modifierPlanningTitle')),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: InputDecoration(labelText: t('quality.nom'))),
            DropdownButtonFormField<String>(
              value: typeId, isExpanded: true,
              items: types.map<DropdownMenuItem<String>>((t) => DropdownMenuItem(value: t['id'] as String, child: Text(t['name']))).toList(),
              onChanged: (v) => setD(() => typeId = v),
              decoration: InputDecoration(labelText: t('quality.typeControleOptionnel')),
            ),
            DropdownButtonFormField<String>(
              value: frequency,
              items: kFrequencyKeys.keys.map((k) => DropdownMenuItem(value: k, child: Text(kFrequencyLabel(k)))).toList(),
              onChanged: (v) => setD(() => frequency = v ?? 'WEEKLY'),
              decoration: InputDecoration(labelText: t('quality.frequence')),
            ),
            if (frequency == 'CUSTOM') TextField(controller: intervalDays, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('quality.intervalleJours'))),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t('quality.prochaineEcheance', {'date': '${nextDueDate.day}/${nextDueDate.month}/${nextDueDate.year}'})),
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
            child: Text(t('quality.supprimer'), style: const TextStyle(color: QhseColors.red)),
          ),
          TextButton(onPressed: () => Navigator.pop(c), child: Text(t('quality.annuler'))),
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
            child: Text(saving ? t('quality.enregistrementEnCours') : t('quality.enregistrer')),
          ),
        ],
      )),
    );
  }

  Widget _scheduleSection(String title, List items, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color))),
      if (items.isEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(t('quality.aucunPlanningPalier'), style: TextStyle(color: QhseColors.textSecondary, fontSize: 12))),
      ...items.map((s) => Card(child: ListTile(
            title: Text(s['name'] ?? ''),
            subtitle: Text(t('quality.echeancePrefix', {'freq': kFrequencyLabel(s['frequency']), 'date': (s['nextDueDate'] ?? '').toString().substring(0, 10)})),
            onTap: () => _openScheduleDialog(record: s),
            trailing: TextButton(onPressed: () => generateNow(s), child: Text(t('quality.generer'))),
          ))),
    ]);
  }

  @override
  Widget build(BuildContext c) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('quality.pageTitle')),
          bottom: TabBar(
            onTap: (i) => setState(() => tabIndex = i),
            tabs: [Tab(text: t('quality.tabTableauDeBord')), Tab(text: t('quality.tabRegistre')), Tab(text: t('quality.tabPlanification'))],
          ),
        ),
        floatingActionButton: tabIndex == 2
            ? FloatingActionButton.extended(onPressed: () => _openScheduleDialog(), icon: const Icon(Icons.add), label: Text(t('quality.fabPlanning')))
            : FloatingActionButton.extended(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const NewControlPage())).then((_) => load()), icon: const Icon(Icons.add), label: Text(t('quality.fabNouveauControle'))),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? LoadErrorView(error: error, onRetry: load)
            : IndexedStack(index: tabIndex, children: [
                // Tableau de bord
                RefreshIndicator(
                  onRefresh: load,
                  child: ListView(padding: const EdgeInsets.only(top: 12, bottom: 12), children: [
                    if (domains.length > 1)
                      SizedBox(
                        height: 40,
                        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
                          Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: Text(t('quality.tousDomaines')), selected: domainFilter.isEmpty, onSelected: (_) => setState(() => domainFilter = ''))),
                          ...domains.map((d) => Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: Text('$d'), selected: domainFilter == d, onSelected: (_) => setState(() => domainFilter = d)))),
                        ]),
                      ),
                    const SizedBox(height: 8),
                    KpiBar(kpis),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(children: [
                        _DashPanel(
                          title: t('quality.controlesParDomaine'),
                          child: _LabeledDonut(
                            entries: _groupCount(filtered, (c) => '${c['domain']}'),
                            colors: const [QhseColors.blue, QhseColors.green, QhseColors.amber, QhseColors.red, Color(0xFF8B5CF6), Color(0xFFEC4899)],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _DashPanel(
                          title: t('quality.controlesParType'),
                          child: _LabeledDonut(
                            entries: _groupCount(filtered.where((c) => c['type'] != null).toList(), (c) => c['type']?['name'] ?? t('quality.sansType')),
                            colors: const [QhseColors.blue, QhseColors.green, QhseColors.amber, QhseColors.red, Color(0xFF8B5CF6), Color(0xFFEC4899)],
                          ),
                        ),
                      ]),
                    ),
                  ]),
                ),
                // Registre
                RefreshIndicator(
                  onRefresh: load,
                  child: ListView(
                    padding: const EdgeInsets.only(top: 12, bottom: 12),
                    children: filtered.isEmpty
                        ? [Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(t('quality.aucunControleEnregistre'))))]
                        : filtered.map((x) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Card(child: ListTile(
                                title: Text('${x['code']} — ${x['status']}'),
                                subtitle: Text('${x['type']?['name'] ?? x['domain'] ?? ''} • ${x['lotNumber'] ?? ''} • ${(x['controlDate'] ?? '').toString().substring(0, 10)}'),
                                trailing: x['finalDecision'] != null ? Text(kDecisionLabel(x['finalDecision']), style: const TextStyle(fontSize: 11)) : null,
                                onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => ControlPage(controlId: x['id']))).then((_) => load()),
                              )),
                            )).toList(),
                  ),
                ),
                // Planification
                RefreshIndicator(
                  onRefresh: load,
                  child: ListView(padding: const EdgeInsets.all(12), children: [
                    _scheduleSection(t('quality.enRetardTitre'), buckets['overdue'] ?? [], QhseColors.red),
                    _scheduleSection(t('quality.sous7JoursTitre'), buckets['dueSoon'] ?? [], QhseColors.amber),
                    _scheduleSection(t('quality.aVenirTitre'), buckets['upcoming'] ?? [], QhseColors.blue),
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
    if (isQualite && (lineId == null || productId == null || shiftId == null || lot.text.isEmpty)) { _msg(t('quality.champsObligatoiresQualite')); return; }
    setState(() => busy = true);
    final payload = {
      'code': code.text, 'domain': domain, 'typeId': typeId,
      'siteId': siteId, 'lineId': isQualite ? lineId : null, 'machineId': machineId,
      'productId': isQualite ? productId : null, 'formatId': formatId,
      'shiftId': isQualite ? shiftId : null, 'lotNumber': isQualite ? lot.text : null,
      'templateId': templateId,
    };
    try {
      final x = await api.post('/quality/controls', payload);
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ControlPage(controlId: x['id'])));
    } on ApiException catch (e) {
      if (e.networkError) {
        await SyncQueue.enqueue('qualityControl', 'CREATE', payload);
        if (mounted) {
          _msg(t('quality.controleHorsLigne'));
          Navigator.pop(context);
        }
      } else {
        _msg('$e');
      }
    } catch (e) { _msg('$e'); }
    setState(() => busy = false);
  }

  void _msg(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: Text(t('quality.nouveauControleTitle'))),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(controller: code, decoration: InputDecoration(labelText: t('quality.codeControle'))),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: typeId, isExpanded: true,
                  items: types.map<DropdownMenuItem<String>>((t) => DropdownMenuItem(value: t['id'] as String, child: Text(t['name']))).toList(),
                  onChanged: (v) => setState(() { typeId = v; templateId = null; }),
                  decoration: InputDecoration(labelText: t('quality.typeControleQualiteClassique')),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: () => showControlTypeDialog(context, api, onSaved: () async { types = List.from(await api.get('/quality/types')); setState(() {}); }), child: Text(t('quality.ajouterType'))),
            ]),
            const SizedBox(height: 10),
            if (isQualite) ...[
              _drop(t('quality.site'), siteId, sites.map((x) => DropdownMenuItem<String>(value: x['id'] as String, child: Text(x['name']))).toList(), (v) {
                siteId = v; final s = sites.firstWhere((x) => x['id'] == v); setState(() { lines = List.from(s['lines'] ?? []); lineId = null; machineId = null; });
              }),
              _drop(t('quality.ligne'), lineId, lines.map((x) => DropdownMenuItem<String>(value: x['id'] as String, child: Text(x['name']))).toList(), (v) {
                lineId = v; final l = lines.firstWhere((x) => x['id'] == v); setState(() => machines = List.from(l['machines'] ?? []));
              }),
              _drop(t('quality.machine'), machineId, machines.map((x) => DropdownMenuItem<String>(value: x['id'] as String, child: Text(x['name']))).toList(), (v) => setState(() => machineId = v)),
              _drop(t('quality.produit'), productId, products.map((x) => DropdownMenuItem<String>(value: x['id'] as String, child: Text(x['name']))).toList(), (v) {
                productId = v; final p = products.firstWhere((x) => x['id'] == v); setState(() => formats = List.from(p['formats'] ?? []));
              }),
              _drop(t('quality.format'), formatId, formats.map((x) => DropdownMenuItem<String>(value: x['id'] as String, child: Text(x['label']))).toList(), (v) => setState(() => formatId = v)),
              _drop(t('quality.quart'), shiftId, shifts.map((x) => DropdownMenuItem<String>(value: x['id'] as String, child: Text(x['name']))).toList(), (v) => setState(() => shiftId = v)),
              TextField(controller: lot, decoration: InputDecoration(labelText: t('quality.numeroDeLot'))),
              const SizedBox(height: 10),
            ],
            _drop(t('quality.modeleControleOptionnel'), templateId, filteredTemplates.map<DropdownMenuItem<String>>((x) => DropdownMenuItem<String>(value: x['id'] as String, child: Text(x['name']))).toList(), (v) => setState(() => templateId = v)),
            const SizedBox(height: 18),
            FilledButton.icon(onPressed: busy ? null : create, icon: const Icon(Icons.play_arrow), label: Text(busy ? t('quality.creationEnCours') : t('quality.demarrerLeControle'))),
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
  bool samplingInit = false;
  bool savingSampling = false;
  final lotSizeCtrl = TextEditingController();
  final sampleSizeCtrl = TextEditingController();
  final samplingMethodCtrl = TextEditingController();
  final acceptanceThresholdCtrl = TextEditingController();
  final rejectionThresholdCtrl = TextEditingController();

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      c = Map<String, dynamic>.from(await api.get('/quality/controls/${widget.controlId}'));
      for (final r in List.from(c?['results'] ?? [])) {
        vals[r['pointId']] = r['value'];
        naFlags[r['pointId']] = r['notApplicable'] == true;
      }
      if (!samplingInit) {
        lotSizeCtrl.text = c?['lotSize']?.toString() ?? '';
        sampleSizeCtrl.text = c?['sampleSize']?.toString() ?? '';
        samplingMethodCtrl.text = c?['samplingMethod'] ?? '';
        acceptanceThresholdCtrl.text = c?['acceptanceThreshold']?.toString() ?? '';
        rejectionThresholdCtrl.text = c?['rejectionThreshold']?.toString() ?? '';
        samplingInit = true;
      }
    } catch (_) {}
    setState(() => loading = false);
  }

  Future<void> saveSampling() async {
    setState(() => savingSampling = true);
    try {
      await api.patch('/quality/controls/${widget.controlId}', {
        'lotSize': lotSizeCtrl.text.isEmpty ? null : int.tryParse(lotSizeCtrl.text),
        'sampleSize': sampleSizeCtrl.text.isEmpty ? null : int.tryParse(sampleSizeCtrl.text),
        'samplingMethod': samplingMethodCtrl.text.isEmpty ? null : samplingMethodCtrl.text,
        'acceptanceThreshold': acceptanceThresholdCtrl.text.isEmpty ? null : double.tryParse(acceptanceThresholdCtrl.text),
        'rejectionThreshold': rejectionThresholdCtrl.text.isEmpty ? null : double.tryParse(rejectionThresholdCtrl.text),
      });
      await load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    setState(() => savingSampling = false);
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('quality.photoAjoutee'))));
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
        title: Text(t('quality.signatureNumeriqueTitle')),
        content: TextField(controller: controller, decoration: InputDecoration(labelText: t('quality.nomSignature'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t('quality.annuler'))),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: Text(t('quality.signer'))),
        ],
      ),
    );
    if (s != null && s.isNotEmpty) await api.post('/quality/controls/${widget.controlId}/signatures', {'type': 'CONTROLLER', 'signatureData': s});
  }

  Future<void> delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('quality.confirmerSuppressionTitle')),
        content: Text(t('quality.supprimerDefinitivement', {'code': '${c?['code']}'})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('quality.annuler'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t('quality.supprimer'), style: const TextStyle(color: QhseColors.red))),
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
        input = TextField(controller: textCtrls[id], enabled: !closedOrNa, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: p['unit'] ?? t('quality.valeur')), onSubmitted: (v) => result(p, num.tryParse(v)));
        break;
      case 'CHOICE':
        final choices = List<String>.from(p['choices'] ?? []);
        input = DropdownButtonFormField<String>(value: vals[id] as String?, items: choices.map((ch) => DropdownMenuItem(value: ch, child: Text(ch))).toList(), onChanged: closedOrNa ? null : (v) { if (v != null) result(p, v); }, decoration: InputDecoration(labelText: t('quality.choix')));
        break;
      case 'TEXT':
      case 'PHOTO':
        textCtrls[id] ??= TextEditingController(text: vals[id]?.toString() ?? '');
        input = TextField(controller: textCtrls[id], enabled: !closedOrNa, decoration: InputDecoration(labelText: t('quality.reponse')), onSubmitted: (v) => result(p, v));
        break;
      default:
        input = Switch(value: vals[id] == true, onChanged: closedOrNa ? null : (v) => result(p, v));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      input,
      if (!closed) CheckboxListTile(
        dense: true, contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading,
        title: Text(t('quality.nonApplicable'), style: const TextStyle(fontSize: 12)),
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
      appBar: AppBar(title: Text('${c?['code']}'), actions: [IconButton(icon: const Icon(Icons.delete_outline), tooltip: t('quality.supprimerTooltip'), onPressed: delete)]),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Card(child: ListTile(
          title: Text('${c?['productRef']?['name'] ?? c?['type']?['name'] ?? c?['domain'] ?? ''}${c?['lotNumber'] != null ? t('quality.lotSuffix', {'lot': '${c?['lotNumber']}'}) : ''}'),
          subtitle: Text('${c?['productionLine']?['name'] ?? ''} ${c?['shiftRef']?['name'] ?? ''} • ${c?['status']}'.trim()),
        )),
        if (c?['finalDecision'] != null || c?['conformityRate'] != null)
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            if (c?['conformityRate'] != null) Text(t('quality.tauxConformitePrefix', {'taux': '${c?['conformityRate']}'}), style: const TextStyle(fontWeight: FontWeight.bold)),
            if (c?['finalDecision'] != null) Text(kDecisionLabel(c?['finalDecision']), style: TextStyle(fontWeight: FontWeight.bold, color: c?['finalDecision'] == 'CONFORME' ? QhseColors.green : c?['finalDecision'] == 'REFUSE' ? QhseColors.red : QhseColors.amber)),
          ]))),
        if (!closed)
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('quality.echantillonnageOptionnel'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: lotSizeCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('quality.tailleDuLot'), isDense: true))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: sampleSizeCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('quality.echantillon'), isDense: true))),
            ]),
            const SizedBox(height: 8),
            TextField(controller: samplingMethodCtrl, decoration: InputDecoration(labelText: t('quality.methode'), isDense: true)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: acceptanceThresholdCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: t('quality.seuilAcceptation'), isDense: true))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: rejectionThresholdCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: t('quality.seuilRejet'), isDense: true))),
            ]),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: savingSampling ? null : saveSampling, child: Text(savingSampling ? t('quality.enCours') : t('quality.enregistrer')))),
          ]))),
        ...pts.map((p) => Card(child: Padding(padding: const EdgeInsets.all(8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${p['label']}${p['required'] == true ? ' *' : ''}${p['critical'] == true ? '  ⚠ critique' : ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              _pointInput(p),
            ])))),
        const SizedBox(height: 8),
        if (!closed) OutlinedButton.icon(onPressed: photo, icon: const Icon(Icons.camera_alt), label: Text(t('quality.ajouterUnePhoto'))),
        if (!closed) OutlinedButton.icon(onPressed: sign, icon: const Icon(Icons.draw), label: Text(t('quality.signer'))),
        if (!closed && missing.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(t('quality.pointsObligatoiresRestants', {'count': '${missing.length}'}), style: const TextStyle(color: QhseColors.amber, fontSize: 12))),
        if (!closed) FilledButton.icon(onPressed: (submitting || missing.isNotEmpty) ? null : submit, icon: const Icon(Icons.check_circle), label: Text(submitting ? t('quality.soumissionEnCours') : t('quality.soumettreEtGenererNc'))),
        if (closed) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(t('quality.controleCloture'), style: TextStyle(color: QhseColors.textSecondary))),
        // Finding #31 — lien CAPA promu pour un contrôle non conforme ou refusé,
        // au même titre que les autres modules (parité avec l'app web).
        if (c?['status'] == 'NON_COMPLIANT' || c?['finalDecision'] == 'REFUSE')
          CapaLinksSection(sourceModule: 'CONTROLE', sourceEntityId: c!['id'], prefill: {'title': t('quality.traiterControleNonConformePrefix', {'code': '${c?['code'] ?? ''}'}), 'source': t('quality.sourceControleQualite')}),
      ]),
    );
  }
}
