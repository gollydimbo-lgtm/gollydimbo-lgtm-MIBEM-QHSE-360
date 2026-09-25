import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api.dart';
import '../theme.dart';
import '../services/sync_queue.dart';
import '../i18n/i18n.dart';

// ============================================================================
// OBJECTIFS QHSE — parité complète avec le module web : tableau de bord,
// matrice filtrable, fiche détaillée (SMART, KPI manuels/auto, actions CAPA,
// risques/opportunités, revues PDCA, commentaires), bibliothèque de modèles
// et checklist de recette CA-01 à CA-49. Aucun calcul recalculé côté
// Flutter : avancement/statut/SMART viennent tels quels de l'API, comme
// pour la Veille réglementaire et les Équipements.
// ============================================================================

const objFamilleValues = ['QUALITE', 'HYGIENE', 'SECURITE', 'ENVIRONNEMENT', 'TRANSVERSAL'];
String objFamilleLabel(String? k) => k == null ? '—' : (objFamilleValues.contains(k) ? t('objectifsQhse.famille.$k') : k);
const objClassificationValues = ['STRATEGIQUE', 'TACTIQUE', 'OPERATIONNEL', 'REGLEMENTAIRE', 'CLIENT', 'AMELIORATION_CONTINUE', 'CONFORMITE', 'PREVENTION'];
String objClassificationLabel(String? k) => k == null ? '—' : (objClassificationValues.contains(k) ? t('objectifsQhse.classification.$k') : k);
const objPriorites = ['CRITIQUE', 'HAUTE', 'MOYENNE', 'FAIBLE'];
const objFrequences = ['QUOTIDIENNE', 'HEBDOMADAIRE', 'MENSUELLE', 'TRIMESTRIELLE', 'SEMESTRIELLE', 'ANNUELLE'];
const objStatutValues = ['ATTEINT', 'EN_COURS', 'EN_RETARD', 'A_RISQUE', 'A_SURVEILLER', 'NON_DEMARRE', 'ARCHIVE', 'SUSPENDU', 'ABANDONNE', 'CLOTURE'];
String objStatutLabel(String? k) => k == null ? '—' : (objStatutValues.contains(k) ? t('objectifsQhse.statut.$k') : k);
const objRecetteStatutValues = ['NON_TESTE', 'EN_COURS', 'CONFORME', 'NON_CONFORME', 'BLOQUE'];
String objRecetteStatutLabel(String? k) => k == null ? '—' : (objRecetteStatutValues.contains(k) ? t('objectifsQhse.recetteStatut.$k') : k);

Color objStatutColor(String? v) => {
  'ATTEINT': QhseColors.green, 'EN_COURS': QhseColors.blue, 'EN_RETARD': QhseColors.red, 'A_RISQUE': QhseColors.red,
  'A_SURVEILLER': QhseColors.amber, 'NON_DEMARRE': QhseColors.textSecondary, 'ARCHIVE': QhseColors.textSecondary,
  'SUSPENDU': QhseColors.amber, 'ABANDONNE': QhseColors.textSecondary, 'CLOTURE': QhseColors.green,
}[v] ?? QhseColors.textSecondary;
Color objRecetteColor(String? v) => {'NON_TESTE': QhseColors.textSecondary, 'EN_COURS': QhseColors.blue, 'CONFORME': QhseColors.green, 'NON_CONFORME': QhseColors.red, 'BLOQUE': QhseColors.red}[v] ?? QhseColors.textSecondary;

String objFmtDate(dynamic v) => v == null ? '—' : DateTime.parse(v).toIso8601String().substring(0, 10);
String objUserName(dynamic u) => u == null ? '—' : '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim();

Widget objChip(String label, Color color) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(999)),
  child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
);
Widget objKpi(String label, String value, Color color) => Expanded(
  child: Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: TextStyle(fontSize: 11, color: QhseColors.textSecondary)),
    const SizedBox(height: 4),
    Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
  ]))),
);
Widget objSectionTitle(String t) => Padding(padding: const EdgeInsets.only(top: 12, bottom: 6), child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold)));
Widget objEmpty(String t) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(t, style: TextStyle(color: QhseColors.textSecondary, fontSize: 13)));

class _ObjDonut extends StatelessWidget {
  final Map<String, dynamic> data;
  final List<Color> colors;
  const _ObjDonut({required this.data, required this.colors});
  @override
  Widget build(BuildContext context) {
    final entries = data.entries.where((e) => (e.value as num? ?? 0) > 0).toList();
    if (entries.isEmpty) return Center(child: Text(t('objectifsQhse.noData'), style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)));
    return Row(children: [
      Expanded(
        child: PieChart(PieChartData(
          sectionsSpace: 2, centerSpaceRadius: 30,
          sections: [
            for (int i = 0; i < entries.length; i++)
              PieChartSectionData(
                value: (entries[i].value as num).toDouble(), color: colors[i % colors.length], radius: 30,
                title: '${entries[i].value}', titleStyle: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
              ),
          ],
        )),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (int i = 0; i < entries.length; i++)
            Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: colors[i % colors.length], shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Expanded(child: Text((objFamilleValues.contains(entries[i].key) ? objFamilleLabel(entries[i].key) : objStatutLabel(entries[i].key)), style: TextStyle(fontSize: 10, color: QhseColors.textSecondary), overflow: TextOverflow.ellipsis)),
            ])),
        ]),
      ),
    ]);
  }
}
class ObjectifsQhsePage extends StatelessWidget {
  const ObjectifsQhsePage({super.key});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('objectifsQhse.appBarTitle')),
          bottom: TabBar(isScrollable: true, tabs: [
            Tab(text: t('objectifsQhse.tab.dashboard')), Tab(text: t('objectifsQhse.tab.objectifs')), Tab(text: t('objectifsQhse.tab.bibliotheque')), Tab(text: t('objectifsQhse.tab.recette')),
          ]),
        ),
        body: const TabBarView(children: [
          ObjectifsDashboardTab(), ObjectifsMatrixTab(), ObjectifLibraryTab(), ObjectifRecetteTab(),
        ]),
      ),
    );
  }
}

class ObjectifsDashboardTab extends StatefulWidget {
  const ObjectifsDashboardTab({super.key});
  @override
  State<ObjectifsDashboardTab> createState() => _ObjectifsDashboardTabState();
}

class _ObjectifsDashboardTabState extends State<ObjectifsDashboardTab> {
  final api = Api();
  Map? dash;
  List alertes = [];
  String? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() => error = null);
    try {
      dash = Map.from(await api.get('/business/objectifs-qhse/dashboard'));
      final a = await api.get('/business/objectifs-qhse/alertes');
      alertes = a is List ? a : (a['data'] ?? []);
    } catch (e) { error = '$e'; }
    if (mounted) setState(() {});
  }

  Color niveauColor(String? n) => n == 'CRITIQUE' ? QhseColors.red : n == 'ELEVE' ? QhseColors.amber : QhseColors.textSecondary;

  @override
  Widget build(BuildContext c) {
    if (error != null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!), TextButton(onPressed: load, child: Text(t('objectifsQhse.retry')))]));
    if (dash == null) return const Center(child: CircularProgressIndicator());
    final d = dash!;
    final parFamille = Map<String, dynamic>.from(d['parFamille'] ?? {});
    final parStatut = Map<String, dynamic>.from(d['parStatut'] ?? {});
    final colors = [QhseColors.blue, QhseColors.green, QhseColors.amber, QhseColors.red, const Color(0xFF8B5CF6), QhseColors.textSecondary];
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(padding: const EdgeInsets.all(12), children: [
        Row(children: [objKpi(t('objectifsQhse.kpi.objectifsActifs'), '${d['total'] ?? 0}', QhseColors.blue), const SizedBox(width: 8), objKpi(t('objectifsQhse.kpi.atteints'), '${d['atteints'] ?? 0}', QhseColors.green)]),
        const SizedBox(height: 8),
        Row(children: [objKpi(t('objectifsQhse.kpi.enCours'), '${d['enCours'] ?? 0}', QhseColors.blue), const SizedBox(width: 8), objKpi(t('objectifsQhse.kpi.enRetard'), '${d['enRetard'] ?? 0}', QhseColors.red)]),
        const SizedBox(height: 8),
        Row(children: [objKpi(t('objectifsQhse.kpi.aRisque'), '${d['aRisque'] ?? 0}', QhseColors.red), const SizedBox(width: 8), objKpi(t('objectifsQhse.kpi.nonDemarres'), '${d['nonDemarres'] ?? 0}', QhseColors.textSecondary)]),
        const SizedBox(height: 8),
        Row(children: [objKpi(t('objectifsQhse.kpi.tauxGlobalAtteinte'), d['tauxGlobalAtteinte'] != null ? '${d['tauxGlobalAtteinte']}%' : '—', QhseColors.green)]),
        const SizedBox(height: 4),
        Text(d['methodeCalcul'] ?? '', style: TextStyle(color: QhseColors.textSecondary, fontSize: 11)),
        const SizedBox(height: 8),
        Row(children: [objKpi(t('objectifsQhse.kpi.actionsOuvertes'), '${d['actionsOuvertes'] ?? 0}', QhseColors.blue), const SizedBox(width: 8), objKpi(t('objectifsQhse.kpi.actionsEnRetard'), '${d['actionsEnRetard'] ?? 0}', QhseColors.red)]),
        objSectionTitle(t('objectifsQhse.dashboard.repartitionFamille')),
        Container(padding: const EdgeInsets.all(12), height: 160, decoration: BoxDecoration(color: QhseColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: QhseColors.border)), child: _ObjDonut(data: parFamille, colors: colors)),
        objSectionTitle(t('objectifsQhse.dashboard.repartitionStatut')),
        Container(padding: const EdgeInsets.all(12), height: 160, decoration: BoxDecoration(color: QhseColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: QhseColors.border)), child: _ObjDonut(data: parStatut, colors: colors)),
        objSectionTitle(t('objectifsQhse.dashboard.alertesTitle', {'count': '${alertes.length}'})),
        if (alertes.isEmpty) objEmpty(t('objectifsQhse.dashboard.alertesEmpty')) else ...alertes.map((a) => Card(
          child: ListTile(
            leading: CircleAvatar(backgroundColor: niveauColor(a['niveau']), radius: 6, child: const SizedBox.shrink()),
            title: Text('${a['code'] ?? ''} — ${a['titre'] ?? ''}'),
            subtitle: Text([
              if (a['responsable'] != null) a['responsable'],
              if (a['echeance'] != null) t('objectifsQhse.dashboard.echeanceInline', {'date': objFmtDate(a['echeance'])}),
              if (a['joursRestants'] != null) (a['joursRestants'] >= 0 ? t('objectifsQhse.dashboard.joursRestants', {'value': '${a['joursRestants']}'}) : t('objectifsQhse.dashboard.joursRetard', {'value': '${(a['joursRestants'] as int).abs()}'})),
            ].join(' · ')),
            onTap: () async {
              final ok = await Navigator.push<bool>(c, MaterialPageRoute(builder: (_) => ObjectifDetailPage(objectifId: a['id'])));
              if (ok == true) load();
            },
          ),
        )),
      ]),
    );
  }
}
class ObjectifsMatrixTab extends StatefulWidget {
  const ObjectifsMatrixTab({super.key});
  @override
  State<ObjectifsMatrixTab> createState() => _ObjectifsMatrixTabState();
}

class _ObjectifsMatrixTabState extends State<ObjectifsMatrixTab> {
  final api = Api();
  List items = [];
  bool loading = true;
  String? error;
  String famille = 'TOUS';
  String statut = 'TOUS';
  String search = '';

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final params = <String>[];
      if (famille != 'TOUS') params.add('famille=$famille');
      if (statut != 'TOUS') params.add('statut=$statut');
      final qs = params.isEmpty ? '' : '?${params.join('&')}';
      items = List.from(await api.get('/business/objectifs-qhse$qs'));
    } catch (e) { error = '$e'; }
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext c) {
    final filtered = items.where((o) {
      if (search.isEmpty) return true;
      final t = '${o['code']} ${o['titre']}'.toLowerCase();
      return t.contains(search.toLowerCase());
    }).toList();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final saved = await Navigator.push<bool>(c, MaterialPageRoute(builder: (_) => const ObjectifFormPage()));
          if (saved == true) load();
        },
        icon: const Icon(Icons.add), label: Text(t('objectifsQhse.newObjectif')),
      ),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(12, 12, 12, 0), child: TextField(
          decoration: InputDecoration(hintText: t('objectifsQhse.matrix.searchHint'), prefixIcon: const Icon(Icons.search), border: const OutlineInputBorder(), isDense: true),
          onChanged: (v) => setState(() => search = v),
        )),
        Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 0), child: Row(children: [
          Expanded(child: DropdownButtonFormField<String>(
            value: famille, isExpanded: true, decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
            items: [DropdownMenuItem(value: 'TOUS', child: Text(t('objectifsQhse.matrix.allFamilies'))), ...objFamilleValues.map((k) => DropdownMenuItem(value: k, child: Text(objFamilleLabel(k))))],
            onChanged: (v) { setState(() => famille = v ?? 'TOUS'); load(); },
          )),
          const SizedBox(width: 8),
          Expanded(child: DropdownButtonFormField<String>(
            value: statut, isExpanded: true, decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
            items: [DropdownMenuItem(value: 'TOUS', child: Text(t('objectifsQhse.matrix.allStatuts'))), ...objStatutValues.map((k) => DropdownMenuItem(value: k, child: Text(objStatutLabel(k))))],
            onChanged: (v) { setState(() => statut = v ?? 'TOUS'); load(); },
          )),
        ])),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!), TextButton(onPressed: load, child: Text(t('objectifsQhse.retry')))]))
                  : RefreshIndicator(onRefresh: load, child: filtered.isEmpty
                      ? ListView(children: [objEmpty(t('objectifsQhse.matrix.emptyFiltered'))])
                      : ListView.builder(padding: const EdgeInsets.all(12), itemCount: filtered.length, itemBuilder: (_, i) {
                          final o = filtered[i];
                          return Card(child: ListTile(
                            title: Text(o['titre'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('${o['famille'] != null ? objFamilleLabel(o['famille']?.toString()) : ''} • ${o['avancement'] != null ? '${o['avancement']}%' : '—'}'),
                            trailing: objChip(objStatutLabel(o['statutCalcule']?.toString()), objStatutColor(o['statutCalcule'])),
                            onTap: () async {
                              await Navigator.push(c, MaterialPageRoute(builder: (_) => ObjectifDetailPage(objectifId: o['id'])));
                              load();
                            },
                          ));
                        })),
        ),
      ]),
    );
  }
}
String _objGenCode() => 'OBJ-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

class ObjectifFormPage extends StatefulWidget {
  final Map? record;
  const ObjectifFormPage({super.key, this.record});
  @override
  State<ObjectifFormPage> createState() => _ObjectifFormPageState();
}

class _ObjectifFormPageState extends State<ObjectifFormPage> {
  final api = Api();
  late final titre = TextEditingController(text: widget.record?['titre'] ?? '');
  late final description = TextEditingController(text: widget.record?['description'] ?? '');
  late final categorie = TextEditingController(text: widget.record?['categorie'] ?? '');
  late final activiteConcernee = TextEditingController(text: widget.record?['activiteConcernee'] ?? '');
  late final valeurInitiale = TextEditingController(text: widget.record?['valeurInitiale']?.toString() ?? '');
  late final cible = TextEditingController(text: widget.record?['cible']?.toString() ?? '');
  late final actuel = TextEditingController(text: widget.record?['actuel']?.toString() ?? '0');
  late final unite = TextEditingController(text: widget.record?['unite'] ?? '');
  late final seuilMin = TextEditingController(text: widget.record?['seuilMin']?.toString() ?? '');
  late final seuilMax = TextEditingController(text: widget.record?['seuilMax']?.toString() ?? '');
  late final directionResponsable = TextEditingController(text: widget.record?['directionResponsable'] ?? '');
  late final budget = TextEditingController(text: widget.record?['budget']?.toString() ?? '');
  late final importanceStrategique = TextEditingController(text: widget.record?['importanceStrategique'] ?? '');
  String famille = 'TRANSVERSAL';
  String? classification;
  String? priorite;
  String? frequenceMesure;
  bool sensInverse = false;
  DateTime? dateDebut;
  DateTime? echeance;
  String? responsableId;
  String? valideurId;
  String? processusId;
  String? workUnitId;
  List<String> contributeurIds = [];
  List users = [];
  List processusList = [];
  List workUnits = [];
  bool busy = false;
  String? error;

  bool get editing => widget.record != null && widget.record!['id'] != null;

  @override
  void initState() {
    super.initState();
    famille = widget.record?['famille'] ?? 'TRANSVERSAL';
    classification = widget.record?['classification'];
    priorite = widget.record?['priorite'];
    frequenceMesure = widget.record?['frequenceMesure'];
    sensInverse = widget.record?['sensInverse'] == true;
    responsableId = widget.record?['responsableId'];
    valideurId = widget.record?['valideurId'];
    processusId = widget.record?['processusId'];
    workUnitId = widget.record?['workUnitId'];
    contributeurIds = List<String>.from(widget.record?['contributeurIds'] ?? []);
    if (widget.record?['dateDebut'] != null) dateDebut = DateTime.parse(widget.record!['dateDebut']);
    if (widget.record?['echeance'] != null) echeance = DateTime.parse(widget.record!['echeance']);
    Future.wait([api.get('/users'), api.get('/business/processus'), api.get('/business/work-units')])
        .then((r) { if (mounted) setState(() { users = List.from(r[0]); processusList = List.from(r[1]); workUnits = List.from(r[2]); }); }).catchError((_) {});
  }

  Future<void> pickDate(bool isEcheance) async {
    final d = await showDatePicker(context: context, initialDate: (isEcheance ? echeance : dateDebut) ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 3650)));
    if (d == null) return;
    setState(() { if (isEcheance) echeance = d; else dateDebut = d; });
  }

  Future<void> submit() async {
    if (titre.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('objectifsQhse.form.titreRequired')))); return; }
    if (cible.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('objectifsQhse.form.cibleRequiredMsg')))); return; }
    setState(() { busy = true; error = null; });
    final payload = {
      'titre': titre.text.trim(), 'description': description.text.trim().isEmpty ? null : description.text.trim(),
      'famille': famille, 'classification': classification, 'categorie': categorie.text.trim().isEmpty ? null : categorie.text.trim(),
      'activiteConcernee': activiteConcernee.text.trim().isEmpty ? null : activiteConcernee.text.trim(),
      'valeurInitiale': valeurInitiale.text.trim().isEmpty ? null : num.tryParse(valeurInitiale.text.trim()),
      'cible': num.tryParse(cible.text.trim()) ?? 0, 'actuel': num.tryParse(actuel.text.trim()) ?? 0,
      'sensInverse': sensInverse, 'unite': unite.text.trim().isEmpty ? null : unite.text.trim(),
      'seuilMin': seuilMin.text.trim().isEmpty ? null : num.tryParse(seuilMin.text.trim()),
      'seuilMax': seuilMax.text.trim().isEmpty ? null : num.tryParse(seuilMax.text.trim()),
      'frequenceMesure': frequenceMesure, 'dateDebut': dateDebut?.toIso8601String(), 'echeance': echeance?.toIso8601String(),
      'responsableId': responsableId, 'valideurId': valideurId, 'contributeurIds': contributeurIds,
      'directionResponsable': directionResponsable.text.trim().isEmpty ? null : directionResponsable.text.trim(),
      'budget': budget.text.trim().isEmpty ? null : num.tryParse(budget.text.trim()),
      'priorite': priorite, 'importanceStrategique': importanceStrategique.text.trim().isEmpty ? null : importanceStrategique.text.trim(),
      'processusId': processusId, 'workUnitId': workUnitId,
    };
    final createPayload = {'code': _objGenCode(), ...payload};
    try {
      if (editing) await api.patch('/business/objectifs-qhse/${widget.record!['id']}', payload);
      else await api.post('/business/objectifs-qhse', createPayload);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (e.networkError && !editing) {
        await SyncQueue.enqueue('objectifQhse', 'CREATE', createPayload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('objectifsQhse.form.offlineQueued')), duration: const Duration(seconds: 4)));
          Navigator.pop(context, true);
        }
      } else {
        setState(() { busy = false; error = '$e'; });
      }
    } catch (e) { setState(() { busy = false; error = '$e'; }); }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text(editing ? t('objectifsQhse.form.editTitle') : t('objectifsQhse.form.createTitle'))),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      TextField(controller: titre, decoration: InputDecoration(labelText: t('objectifsQhse.form.titre'), border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: description, maxLines: 2, decoration: InputDecoration(labelText: t('objectifsQhse.form.description'), border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: famille, decoration: InputDecoration(labelText: t('objectifsQhse.form.famille'), border: const OutlineInputBorder()),
        items: objFamilleValues.map((k) => DropdownMenuItem(value: k, child: Text(objFamilleLabel(k)))).toList(),
        onChanged: (v) => setState(() => famille = v ?? famille),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: classification, decoration: InputDecoration(labelText: t('objectifsQhse.form.classification'), border: const OutlineInputBorder()),
        items: [const DropdownMenuItem(value: null, child: Text('—')), ...objClassificationValues.map((k) => DropdownMenuItem(value: k, child: Text(objClassificationLabel(k))))],
        onChanged: (v) => setState(() => classification = v),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: priorite, decoration: InputDecoration(labelText: t('objectifsQhse.form.priorite'), border: const OutlineInputBorder()),
        items: [const DropdownMenuItem(value: null, child: Text('—')), ...objPriorites.map((p) => DropdownMenuItem(value: p, child: Text(p)))],
        onChanged: (v) => setState(() => priorite = v),
      ),
      const SizedBox(height: 12),
      TextField(controller: categorie, decoration: InputDecoration(labelText: t('objectifsQhse.form.categorie'), border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: activiteConcernee, decoration: InputDecoration(labelText: t('objectifsQhse.form.activiteConcernee'), border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: TextField(controller: valeurInitiale, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('objectifsQhse.form.valeurInitiale'), border: const OutlineInputBorder()))),
        const SizedBox(width: 8),
        Expanded(child: TextField(controller: cible, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('objectifsQhse.form.cibleRequired'), border: const OutlineInputBorder()))),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: TextField(controller: actuel, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('objectifsQhse.form.actuel'), border: const OutlineInputBorder()))),
        const SizedBox(width: 8),
        Expanded(child: TextField(controller: unite, decoration: InputDecoration(labelText: t('objectifsQhse.form.unite'), border: const OutlineInputBorder()))),
      ]),
      const SizedBox(height: 12),
      SwitchListTile(
        contentPadding: EdgeInsets.zero, title: Text(t('objectifsQhse.form.sensInverse')),
        subtitle: Text(t('objectifsQhse.form.sensInverseHint'), style: const TextStyle(fontSize: 11)),
        value: sensInverse, onChanged: (v) => setState(() => sensInverse = v),
      ),
      Row(children: [
        Expanded(child: TextField(controller: seuilMin, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('objectifsQhse.form.seuilMin'), border: const OutlineInputBorder()))),
        const SizedBox(width: 8),
        Expanded(child: TextField(controller: seuilMax, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('objectifsQhse.form.seuilMax'), border: const OutlineInputBorder()))),
      ]),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: frequenceMesure, decoration: InputDecoration(labelText: t('objectifsQhse.form.frequenceMesure'), border: const OutlineInputBorder()),
        items: [const DropdownMenuItem(value: null, child: Text('—')), ...objFrequences.map((f) => DropdownMenuItem(value: f, child: Text(f[0] + f.substring(1).toLowerCase())))],
        onChanged: (v) => setState(() => frequenceMesure = v),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: () => pickDate(false), icon: const Icon(Icons.event), label: Text(dateDebut == null ? t('objectifsQhse.form.dateDebut') : objFmtDate(dateDebut!.toIso8601String())))),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton.icon(onPressed: () => pickDate(true), icon: const Icon(Icons.flag), label: Text(echeance == null ? t('objectifsQhse.form.echeance') : objFmtDate(echeance!.toIso8601String())))),
      ]),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: users.any((u) => u['id'] == responsableId) ? responsableId : null,
        decoration: InputDecoration(labelText: t('objectifsQhse.form.responsablePilote'), border: const OutlineInputBorder()),
        items: [const DropdownMenuItem(value: null, child: Text('—')), ...users.map((u) => DropdownMenuItem(value: u['id'] as String, child: Text(objUserName(u))))],
        onChanged: (v) => setState(() => responsableId = v),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: users.any((u) => u['id'] == valideurId) ? valideurId : null,
        decoration: InputDecoration(labelText: t('objectifsQhse.form.valideur'), border: const OutlineInputBorder()),
        items: [const DropdownMenuItem(value: null, child: Text('—')), ...users.map((u) => DropdownMenuItem(value: u['id'] as String, child: Text(objUserName(u))))],
        onChanged: (v) => setState(() => valideurId = v),
      ),
      const SizedBox(height: 12),
      Wrap(spacing: 6, runSpacing: 6, children: users.map<Widget>((u) {
        final selected = contributeurIds.contains(u['id']);
        return FilterChip(
          label: Text(objUserName(u), style: const TextStyle(fontSize: 12)), selected: selected,
          onSelected: (v) => setState(() { if (v) contributeurIds.add(u['id']); else contributeurIds.remove(u['id']); }),
        );
      }).toList()),
      const SizedBox(height: 12),
      TextField(controller: directionResponsable, decoration: InputDecoration(labelText: t('objectifsQhse.form.directionResponsable'), border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: budget, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('objectifsQhse.form.budget'), border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: importanceStrategique, decoration: InputDecoration(labelText: t('objectifsQhse.form.importanceStrategique'), border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: processusList.any((p) => p['id'] == processusId) ? processusId : null,
        decoration: InputDecoration(labelText: t('objectifsQhse.form.processusConcerne'), border: const OutlineInputBorder()),
        items: [const DropdownMenuItem(value: null, child: Text('—')), ...processusList.map((p) => DropdownMenuItem(value: p['id'] as String, child: Text(p['nom'])))],
        onChanged: (v) => setState(() => processusId = v),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: workUnits.any((w) => w['id'] == workUnitId) ? workUnitId : null,
        decoration: InputDecoration(labelText: t('objectifsQhse.form.uniteTravail'), border: const OutlineInputBorder()),
        items: [const DropdownMenuItem(value: null, child: Text('—')), ...workUnits.map((w) => DropdownMenuItem(value: w['id'] as String, child: Text(w['name'])))],
        onChanged: (v) => setState(() => workUnitId = v),
      ),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
      const SizedBox(height: 20),
      FilledButton(onPressed: busy ? null : submit, child: busy ? const CircularProgressIndicator() : Text(t('objectifsQhse.save'))),
    ]),
  );
}
class ObjectifKpiFormPage extends StatefulWidget {
  final String objectifId;
  const ObjectifKpiFormPage({super.key, required this.objectifId});
  @override
  State<ObjectifKpiFormPage> createState() => _ObjectifKpiFormPageState();
}

class _ObjectifKpiFormPageState extends State<ObjectifKpiFormPage> {
  final api = Api();
  String sourceType = 'MANUEL';
  String? sourceKey;
  List catalog = [];
  final nom = TextEditingController();
  final valeurInitiale = TextEditingController();
  final cible = TextEditingController();
  final valeurActuelle = TextEditingController();
  bool sensInverse = false;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    api.get('/business/objectifs-qhse/kpi-catalog').then((v) { if (mounted) setState(() => catalog = List.from(v)); }).catchError((_) {});
  }

  Future<void> submit() async {
    setState(() => busy = true);
    try {
      Map payload;
      if (sourceType == 'AUTO') {
        final entry = catalog.firstWhere((c) => c['key'] == sourceKey, orElse: () => null);
        payload = {
          'nom': entry?['nom'] ?? nom.text.trim(), 'sourceType': 'AUTO', 'sourceKey': sourceKey,
          'unite': entry?['unite'], 'sensInverse': entry?['sensInverse'] ?? false,
          'cible': cible.text.trim().isEmpty ? null : num.tryParse(cible.text.trim()),
          'valeurInitiale': valeurInitiale.text.trim().isEmpty ? null : num.tryParse(valeurInitiale.text.trim()),
        };
      } else {
        payload = {
          'nom': nom.text.trim(), 'sourceType': 'MANUEL', 'sensInverse': sensInverse,
          'cible': cible.text.trim().isEmpty ? null : num.tryParse(cible.text.trim()),
          'valeurInitiale': valeurInitiale.text.trim().isEmpty ? null : num.tryParse(valeurInitiale.text.trim()),
          'valeurActuelle': valeurActuelle.text.trim().isEmpty ? null : num.tryParse(valeurActuelle.text.trim()),
        };
      }
      await api.post('/business/objectifs-qhse/${widget.objectifId}/kpis', payload);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => busy = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text(t('objectifsQhse.kpiForm.title'))),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      SegmentedButton<String>(
        segments: [ButtonSegment(value: 'MANUEL', label: Text(t('objectifsQhse.kpiForm.manuel'))), ButtonSegment(value: 'AUTO', label: Text(t('objectifsQhse.kpiForm.automatique')))],
        selected: {sourceType}, onSelectionChanged: (s) => setState(() => sourceType = s.first),
      ),
      const SizedBox(height: 12),
      if (sourceType == 'AUTO')
        DropdownButtonFormField<String>(
          value: sourceKey, isExpanded: true, decoration: InputDecoration(labelText: t('objectifsQhse.kpiForm.indicateurCatalogue'), border: const OutlineInputBorder()),
          items: catalog.map<DropdownMenuItem<String>>((cat) => DropdownMenuItem(value: cat['key'] as String, child: Text('${cat['nom']} (${cat['valeur'] ?? '—'} ${cat['unite'] ?? ''})', overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) => setState(() => sourceKey = v),
        )
      else
        TextField(controller: nom, decoration: InputDecoration(labelText: t('objectifsQhse.kpiForm.nomKpi'), border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: TextField(controller: valeurInitiale, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('objectifsQhse.kpiForm.valInitiale'), border: const OutlineInputBorder()))),
        const SizedBox(width: 8),
        Expanded(child: TextField(controller: cible, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('objectifsQhse.kpiForm.cible'), border: const OutlineInputBorder()))),
      ]),
      if (sourceType == 'MANUEL') ...[
        const SizedBox(height: 12),
        TextField(controller: valeurActuelle, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('objectifsQhse.kpiForm.valActuelle'), border: const OutlineInputBorder())),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(t('objectifsQhse.form.sensInverse')), value: sensInverse, onChanged: (v) => setState(() => sensInverse = v)),
      ],
      const SizedBox(height: 20),
      FilledButton(onPressed: busy ? null : submit, child: busy ? const CircularProgressIndicator() : Text(t('objectifsQhse.kpiForm.ajouter'))),
    ]),
  );
}

class ObjectifRiskLinkFormPage extends StatefulWidget {
  final String objectifId;
  const ObjectifRiskLinkFormPage({super.key, required this.objectifId});
  @override
  State<ObjectifRiskLinkFormPage> createState() => _ObjectifRiskLinkFormPageState();
}

class _ObjectifRiskLinkFormPageState extends State<ObjectifRiskLinkFormPage> {
  final api = Api();
  List risks = [];
  String? riskId;
  String type = 'RISQUE';
  bool busy = false;

  @override
  void initState() { super.initState(); api.get('/business/risks').then((v) { if (mounted) setState(() => risks = List.from(v)); }).catchError((_) {}); }

  Future<void> submit() async {
    if (riskId == null) return;
    setState(() => busy = true);
    try {
      await api.post('/business/objectifs-qhse/${widget.objectifId}/risks', {'riskId': riskId, 'type': type});
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => busy = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text(t('objectifsQhse.riskForm.title'))),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      DropdownButtonFormField<String>(
        value: riskId, isExpanded: true, decoration: InputDecoration(labelText: t('objectifsQhse.riskForm.risqueField'), border: const OutlineInputBorder()),
        items: risks.map<DropdownMenuItem<String>>((r) => DropdownMenuItem(value: r['id'] as String, child: Text('${r['code']} — ${r['hazard']}', overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (v) => setState(() => riskId = v),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: type, decoration: InputDecoration(labelText: t('objectifsQhse.riskForm.type'), border: const OutlineInputBorder()),
        items: [DropdownMenuItem(value: 'RISQUE', child: Text(t('objectifsQhse.riskForm.typeRisque'))), DropdownMenuItem(value: 'OPPORTUNITE', child: Text(t('objectifsQhse.riskForm.typeOpportunite')))],
        onChanged: (v) => setState(() => type = v ?? type),
      ),
      const SizedBox(height: 20),
      FilledButton(onPressed: busy ? null : submit, child: busy ? const CircularProgressIndicator() : Text(t('objectifsQhse.riskForm.lier'))),
    ]),
  );
}

class ObjectifActionFormPage extends StatefulWidget {
  final String objectifId;
  const ObjectifActionFormPage({super.key, required this.objectifId});
  @override
  State<ObjectifActionFormPage> createState() => _ObjectifActionFormPageState();
}

class _ObjectifActionFormPageState extends State<ObjectifActionFormPage> {
  final api = Api();
  String mode = 'CREATE';
  final title = TextEditingController();
  DateTime? dueDate;
  String? responsibleId;
  List users = [];
  List actions = [];
  String? existingId;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    Future.wait([api.get('/users'), api.get('/business/actions')]).then((r) { if (mounted) setState(() { users = List.from(r[0]); actions = List.from(r[1]).where((a) => a['objectifQhseId'] == null).toList(); }); }).catchError((_) {});
  }

  Future<void> submit() async {
    setState(() => busy = true);
    try {
      if (mode == 'CREATE') {
        if (title.text.trim().isEmpty) { setState(() => busy = false); return; }
        await api.post('/business/objectifs-qhse/${widget.objectifId}/actions', {
          'title': title.text.trim(), 'dueDate': dueDate?.toIso8601String(), 'responsibleId': responsibleId,
        });
      } else {
        if (existingId == null) { setState(() => busy = false); return; }
        await api.post('/business/objectifs-qhse/${widget.objectifId}/actions/$existingId/link', {});
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => busy = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text(t('objectifsQhse.actionForm.title'))),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      SegmentedButton<String>(
        segments: [ButtonSegment(value: 'CREATE', label: Text(t('objectifsQhse.actionForm.nouvelle'))), ButtonSegment(value: 'LINK', label: Text(t('objectifsQhse.actionForm.existante')))],
        selected: {mode}, onSelectionChanged: (s) => setState(() => mode = s.first),
      ),
      const SizedBox(height: 12),
      if (mode == 'CREATE') ...[
        TextField(controller: title, decoration: InputDecoration(labelText: t('objectifsQhse.actionForm.titreAction'), border: const OutlineInputBorder())),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: () async {
          final d = await showDatePicker(context: c, initialDate: dueDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 3650)));
          if (d != null) setState(() => dueDate = d);
        }, icon: const Icon(Icons.event), label: Text(dueDate == null ? t('objectifsQhse.form.echeance') : objFmtDate(dueDate!.toIso8601String()))),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: responsibleId, decoration: InputDecoration(labelText: t('objectifsQhse.actionForm.responsable'), border: const OutlineInputBorder()),
          items: [const DropdownMenuItem(value: null, child: Text('—')), ...users.map((u) => DropdownMenuItem(value: u['id'] as String, child: Text(objUserName(u))))],
          onChanged: (v) => setState(() => responsibleId = v),
        ),
      ] else
        DropdownButtonFormField<String>(
          value: existingId, isExpanded: true, decoration: InputDecoration(labelText: t('objectifsQhse.actionForm.actionExistante'), border: const OutlineInputBorder()),
          items: actions.map<DropdownMenuItem<String>>((a) => DropdownMenuItem(value: a['id'] as String, child: Text('${a['code']} — ${a['title']}', overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) => setState(() => existingId = v),
        ),
      const SizedBox(height: 20),
      FilledButton(onPressed: busy ? null : submit, child: busy ? const CircularProgressIndicator() : Text(t('objectifsQhse.actionForm.valider'))),
    ]),
  );
}

class ObjectifReviewFormPage extends StatefulWidget {
  final String objectifId;
  final num cibleActuelle;
  const ObjectifReviewFormPage({super.key, required this.objectifId, required this.cibleActuelle});
  @override
  State<ObjectifReviewFormPage> createState() => _ObjectifReviewFormPageState();
}

class _ObjectifReviewFormPageState extends State<ObjectifReviewFormPage> {
  final api = Api();
  final resultats = TextEditingController();
  final ecarts = TextEditingController();
  final analyseCauses = TextEditingController();
  final actionsProposees = TextEditingController();
  final nouvelleCible = TextEditingController();
  String? decision;
  bool busy = false;

  Future<void> submit() async {
    setState(() => busy = true);
    try {
      await api.post('/business/objectifs-qhse/${widget.objectifId}/reviews', {
        'resultats': resultats.text.trim().isEmpty ? null : resultats.text.trim(),
        'ecarts': ecarts.text.trim().isEmpty ? null : ecarts.text.trim(),
        'analyseCauses': analyseCauses.text.trim().isEmpty ? null : analyseCauses.text.trim(),
        'decision': decision,
        'nouvelleCible': nouvelleCible.text.trim().isEmpty ? null : num.tryParse(nouvelleCible.text.trim()),
        'actionsProposees': actionsProposees.text.trim().isEmpty ? null : actionsProposees.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => busy = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text(t('objectifsQhse.reviewForm.title'))),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      TextField(controller: resultats, maxLines: 2, decoration: InputDecoration(labelText: t('objectifsQhse.reviewForm.resultats'), border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: ecarts, maxLines: 2, decoration: InputDecoration(labelText: t('objectifsQhse.reviewForm.ecarts'), border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: analyseCauses, maxLines: 2, decoration: InputDecoration(labelText: t('objectifsQhse.reviewForm.analyseCauses'), border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: decision, decoration: InputDecoration(labelText: t('objectifsQhse.reviewForm.decision'), border: const OutlineInputBorder()),
        items: [
          const DropdownMenuItem(value: null, child: Text('—')), DropdownMenuItem(value: 'MAINTIEN', child: Text(t('objectifsQhse.reviewForm.decisionMaintien'))),
          DropdownMenuItem(value: 'REVISION_CIBLE', child: Text(t('objectifsQhse.reviewForm.decisionRevision'))), DropdownMenuItem(value: 'CLOTURE', child: Text(t('objectifsQhse.reviewForm.decisionCloture'))),
          DropdownMenuItem(value: 'ABANDON', child: Text(t('objectifsQhse.reviewForm.decisionAbandon'))),
        ],
        onChanged: (v) => setState(() => decision = v),
      ),
      if (decision == 'REVISION_CIBLE') ...[
        const SizedBox(height: 12),
        TextField(controller: nouvelleCible, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('objectifsQhse.reviewForm.nouvelleCible', {'value': '${widget.cibleActuelle}'}), border: const OutlineInputBorder())),
      ],
      const SizedBox(height: 12),
      TextField(controller: actionsProposees, maxLines: 2, decoration: InputDecoration(labelText: t('objectifsQhse.reviewForm.actionsProposees'), border: const OutlineInputBorder())),
      const SizedBox(height: 20),
      FilledButton(onPressed: busy ? null : submit, child: busy ? const CircularProgressIndicator() : Text(t('objectifsQhse.reviewForm.enregistrerRevue'))),
    ]),
  );
}
class ObjectifDetailPage extends StatefulWidget {
  final String objectifId;
  const ObjectifDetailPage({super.key, required this.objectifId});
  @override
  State<ObjectifDetailPage> createState() => _ObjectifDetailPageState();
}

class _ObjectifDetailPageState extends State<ObjectifDetailPage> {
  final api = Api();
  Map? o;
  List history = [];
  bool loading = true;
  String? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      o = Map.from(await api.get('/business/objectifs-qhse/${widget.objectifId}'));
      final h = await api.get('/business/objectifs-qhse/${widget.objectifId}/history');
      history = h is List ? h : (h['data'] ?? []);
    } catch (e) { error = '$e'; }
    setState(() => loading = false);
  }

  Future<void> shareFiche() async {
    final r = o;
    if (r == null) return;
    final buf = StringBuffer();
    buf.writeln(t('objectifsQhse.share.header', {'code': '${r['code'] ?? ''}'}));
    buf.writeln(r['titre'] ?? '');
    buf.writeln(t('objectifsQhse.line.famille', {'value': r['famille'] != null ? objFamilleLabel(r['famille']?.toString()) : '—'}));
    buf.writeln(t('objectifsQhse.line.statut', {'value': r['statutCalcule'] != null ? objStatutLabel(r['statutCalcule']?.toString()) : '—'}));
    buf.writeln(t('objectifsQhse.line.avancement', {'value': r['avancement'] != null ? '${r['avancement']}%' : '—'}));
    buf.writeln('${r['actuel'] ?? '—'}${r['unite'] ?? ''} → cible ${r['cible'] ?? '—'}${r['unite'] ?? ''}');
    buf.writeln(t('objectifsQhse.line.responsable', {'value': objUserName(r['responsable'])}));
    buf.writeln(t('objectifsQhse.line.echeance', {'value': objFmtDate(r['echeance'])}));
    try {
      await Share.share(buf.toString(), subject: t('objectifsQhse.share.header', {'code': '${r['code'] ?? ''}'}));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> deleteKpi(String id, String label) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: Text(t('objectifsQhse.confirm')), content: Text(t('objectifsQhse.detail.deleteKpiConfirm', {'label': label})),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer'))],
    ));
    if (ok != true) return;
    try { await api.delete('/business/objectifs-qhse-kpis/$id'); load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  Future<void> unlinkAction(String actionId) async {
    try { await api.post('/business/objectifs-qhse-actions/$actionId/unlink', {}); load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  Future<void> unlinkRisk(String linkId) async {
    try { await api.delete('/business/objectifs-qhse-risks/$linkId'); load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  Future<void> addComment() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: Text(t('objectifsQhse.detail.addCommentTitle')),
      content: TextField(controller: controller, maxLines: 3, decoration: InputDecoration(hintText: t('objectifsQhse.detail.commentHint'), border: const OutlineInputBorder())),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(t('objectifsQhse.send')))],
    ));
    if (ok != true || controller.text.trim().isEmpty) return;
    try { await api.post('/business/objectifs-qhse/${widget.objectifId}/comments', {'contenu': controller.text.trim()}); load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  Future<void> duplicate() async {
    final controller = TextEditingController(text: '${DateTime.now().year + 1}');
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: Text(t('objectifsQhse.detail.duplicateTitle')),
      content: TextField(controller: controller, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('objectifsQhse.detail.anneeField'), border: const OutlineInputBorder())),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(t('objectifsQhse.detail.dupliquer')))],
    ));
    if (ok != true) return;
    try {
      await api.post('/business/objectifs-qhse/${widget.objectifId}/duplicate', {'annee': int.tryParse(controller.text.trim())});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('objectifsQhse.detail.duplicatedMsg'))));
      load();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  Future<void> restore() async {
    try { await api.post('/business/objectifs-qhse/${widget.objectifId}/restore', {}); load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  @override
  Widget build(BuildContext c) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (error != null) return Scaffold(body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!), TextButton(onPressed: load, child: const Text('Réessayer'))])));
    final r = o!;
    final kpis = List.from(r['kpis'] ?? []);
    final actions = List.from(r['actions'] ?? []);
    final objectifRisks = List.from(r['objectifRisks'] ?? []);
    final reviews = List.from(r['reviews'] ?? []);
    final comments = List.from(r['comments'] ?? []);
    final smart = Map.from(r['smart'] ?? {'conforme': true, 'manquants': []});
    final avancement = (r['avancement'] as num?)?.toDouble();
    return Scaffold(
      appBar: AppBar(title: Text(r['titre'] ?? '', overflow: TextOverflow.ellipsis), actions: [
        IconButton(icon: const Icon(Icons.share), tooltip: t('objectifsQhse.detail.shareTooltip'), onPressed: shareFiche),
        IconButton(icon: const Icon(Icons.edit), onPressed: () async {
          final saved = await Navigator.push<bool>(c, MaterialPageRoute(builder: (_) => ObjectifFormPage(record: r)));
          if (saved == true) load();
        }),
      ]),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            objChip(objFamilleLabel(r['famille']?.toString()), QhseColors.blue),
            objChip(objStatutLabel(r['statutCalcule']?.toString()), objStatutColor(r['statutCalcule'])),
            if (r['priorite'] != null) objChip(r['priorite'], QhseColors.amber),
            if (smart['conforme'] != true) objChip(t('objectifsQhse.detail.nonSmart'), QhseColors.red),
            if (r['archivedAt'] != null) objChip(t('objectifsQhse.statut.ARCHIVE'), QhseColors.textSecondary),
          ]),
          if (r['description'] != null && '${r['description']}'.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(r['description'], style: TextStyle(color: QhseColors.textSecondary)),
          ],
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${r['actuel']}${r['unite'] ?? ''} → cible ${r['cible']}${r['unite'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(avancement != null ? '${avancement.toStringAsFixed(0)}%' : '—', style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 4),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: (avancement ?? 0) / 100, minHeight: 8, backgroundColor: QhseColors.border, color: objStatutColor(r['statutCalcule']))),
          if (smart['conforme'] != true) ...[
            const SizedBox(height: 10),
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: QhseColors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
              child: Text(t('objectifsQhse.detail.smartManquants', {'list': List<String>.from(smart['manquants'] ?? []).join(', ')}), style: TextStyle(color: QhseColors.red, fontSize: 12))),
          ],
          const SizedBox(height: 10),
          Text(t('objectifsQhse.line.responsable', {'value': objUserName(r['responsable'])}), style: TextStyle(fontSize: 12, color: QhseColors.textSecondary)),
          Text(t('objectifsQhse.line.valideur', {'value': objUserName(r['valideur'])}), style: TextStyle(fontSize: 12, color: QhseColors.textSecondary)),
          Text(t('objectifsQhse.line.echeance', {'value': objFmtDate(r['echeance'])}), style: TextStyle(fontSize: 12, color: QhseColors.textSecondary)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton(onPressed: duplicate, child: Text(t('objectifsQhse.detail.dupliquerBtn'))),
            if (r['archivedAt'] != null) OutlinedButton(onPressed: restore, child: Text(t('objectifsQhse.detail.restaurer'))),
          ]),
          objSectionTitle(t('objectifsQhse.detail.kpiSectionTitle', {'count': '${kpis.length}'})),
          if (kpis.isEmpty) objEmpty(t('objectifsQhse.detail.kpiEmpty')) else ...kpis.map((k) => Card(child: ListTile(
            title: Text('${k['nom']}${k['sourceType'] == 'AUTO' ? t('objectifsQhse.detail.autoSuffix') : ''}'),
            subtitle: Text('${k['valeurActuelle'] ?? '—'} ${k['unite'] ?? ''}${k['cible'] != null ? t('objectifsQhse.detail.kpiCibleInline', {'value': '${k['cible']}'}) : ''}${k['avancement'] != null ? ' · ${k['avancement']}%' : ''}'),
            trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => deleteKpi(k['id'], k['nom'] ?? '')),
          ))),
          OutlinedButton.icon(onPressed: () async {
            final ok = await Navigator.push<bool>(c, MaterialPageRoute(builder: (_) => ObjectifKpiFormPage(objectifId: r['id'])));
            if (ok == true) load();
          }, icon: const Icon(Icons.add), label: Text(t('objectifsQhse.detail.addKpiBtn'))),
          objSectionTitle(t('objectifsQhse.detail.actionsSectionTitle', {'count': '${actions.length}'})),
          if (actions.isEmpty) objEmpty(t('objectifsQhse.detail.actionsEmpty')) else ...actions.map((a) => Card(child: ListTile(
            title: Text(a['title'] ?? ''),
            subtitle: Text('${a['code']} • ${a['status']}${a['dueDate'] != null ? ' • ' + t('objectifsQhse.dashboard.echeanceInline', {'date': objFmtDate(a['dueDate'])}) : ''}'),
            trailing: IconButton(icon: const Icon(Icons.link_off), onPressed: () => unlinkAction(a['id'])),
          ))),
          OutlinedButton.icon(onPressed: () async {
            final ok = await Navigator.push<bool>(c, MaterialPageRoute(builder: (_) => ObjectifActionFormPage(objectifId: r['id'])));
            if (ok == true) load();
          }, icon: const Icon(Icons.add), label: Text(t('objectifsQhse.actionForm.title'))),
          objSectionTitle(t('objectifsQhse.detail.risksSectionTitle', {'count': '${objectifRisks.length}'})),
          if (objectifRisks.isEmpty) objEmpty(t('objectifsQhse.detail.risksEmpty')) else ...objectifRisks.map((link) => Card(child: ListTile(
            title: Text('${link['risk']?['code'] ?? ''} — ${link['risk']?['hazard'] ?? ''}'),
            subtitle: Text(link['type'] == 'OPPORTUNITE' ? t('objectifsQhse.riskForm.typeOpportunite') : t('objectifsQhse.riskForm.typeRisque')),
            trailing: IconButton(icon: const Icon(Icons.link_off), onPressed: () => unlinkRisk(link['id'])),
          ))),
          OutlinedButton.icon(onPressed: () async {
            final ok = await Navigator.push<bool>(c, MaterialPageRoute(builder: (_) => ObjectifRiskLinkFormPage(objectifId: r['id'])));
            if (ok == true) load();
          }, icon: const Icon(Icons.add), label: Text(t('objectifsQhse.detail.lierRisqueBtn'))),
          objSectionTitle(t('objectifsQhse.detail.reviewsSectionTitle', {'count': '${reviews.length}'})),
          if (reviews.isEmpty) objEmpty(t('objectifsQhse.detail.reviewsEmpty')) else ...reviews.map((rv) => Card(child: ListTile(
            title: Text('${objFmtDate(rv['dateRevue'])}${rv['decision'] != null ? ' · ${rv['decision']}' : ''}'),
            subtitle: Text(rv['resultats'] ?? '—', maxLines: 2, overflow: TextOverflow.ellipsis),
          ))),
          OutlinedButton.icon(onPressed: () async {
            final ok = await Navigator.push<bool>(c, MaterialPageRoute(builder: (_) => ObjectifReviewFormPage(objectifId: r['id'], cibleActuelle: r['cible'] ?? 0)));
            if (ok == true) load();
          }, icon: const Icon(Icons.add), label: Text(t('objectifsQhse.detail.newReviewBtn'))),
          objSectionTitle(t('objectifsQhse.detail.commentsSectionTitle', {'count': '${comments.length}'})),
          if (comments.isEmpty) objEmpty(t('objectifsQhse.detail.commentsEmpty')) else ...comments.map((cm) => Card(child: ListTile(
            title: Text(cm['contenu'] ?? ''),
            subtitle: Text(objFmtDate(cm['createdAt'])),
          ))),
          OutlinedButton.icon(onPressed: addComment, icon: const Icon(Icons.add_comment), label: Text(t('objectifsQhse.detail.addCommentTitle'))),
          objSectionTitle(t('objectifsQhse.detail.historySectionTitle', {'count': '${history.length}'})),
          if (history.isEmpty) objEmpty(t('objectifsQhse.detail.historyEmpty')) else ...history.map((e) => Card(child: ListTile(
            title: Text('${e['libelle'] ?? e['action'] ?? ''}${e['auteur'] != null ? ' · ${e['auteur']}' : ''}'),
            subtitle: Text('${objFmtDate(e['date'])}${e['action'] == 'REVISION_CIBLE' && e['ancienneCible'] != null && e['nouvelleCible'] != null ? ' · cible ${e['ancienneCible']} → ${e['nouvelleCible']}' : ''}'),
          ))),
        ]),
      ),
    );
  }
}

class ObjectifLibraryTab extends StatefulWidget {
  const ObjectifLibraryTab({super.key});
  @override
  State<ObjectifLibraryTab> createState() => _ObjectifLibraryTabState();
}

class _ObjectifLibraryTabState extends State<ObjectifLibraryTab> {
  List library = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final res = await Api().get('/business/objectifs-qhse/library');
      setState(() => library = res is List ? res : (res['data'] ?? []));
    } catch (_) {
      setState(() => library = []);
    }
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (library.isEmpty) return objEmpty(t('objectifsQhse.library.empty'));
    final Map<String, List> byFamille = {};
    for (final t in library) {
      final f = (t['famille'] ?? 'AUTRE').toString();
      byFamille.putIfAbsent(f, () => []).add(t);
    }
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(t('objectifsQhse.library.intro'),
                style: const TextStyle(color: Colors.grey)),
          ),
          for (final entry in byFamille.entries) ...[
            objSectionTitle('${objFamilleValues.contains(entry.key) ? objFamilleLabel(entry.key) : entry.key} (${entry.value.length})'),
            ...entry.value.map((obj) => Card(
                  child: ListTile(
                    title: Text(obj['titre'] ?? obj['libelle'] ?? '—'),
                    subtitle: Text(obj['description'] ?? obj['objectif'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: FilledButton(
                      onPressed: () async {
                        final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => ObjectifFormPage(record: Map<String, dynamic>.from(obj)..remove('id'))));
                        if (ok == true && context.mounted) Navigator.pop(context, true);
                      },
                      child: Text(t('objectifsQhse.library.utiliser')),
                    ),
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

class ObjectifRecetteTab extends StatefulWidget {
  const ObjectifRecetteTab({super.key});
  @override
  State<ObjectifRecetteTab> createState() => _ObjectifRecetteTabState();
}

class _ObjectifRecetteTabState extends State<ObjectifRecetteTab> {
  List criteres = [];
  List users = [];
  bool loading = true;
  String filter = 'TOUS';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final res = await Api().get('/business/objectifs-qhse/recette');
      final u = await Api().get('/users');
      setState(() {
        criteres = res is List ? res : (res['data'] ?? []);
        users = u is List ? u : (u['data'] ?? []);
      });
    } catch (_) {
      setState(() => criteres = []);
    }
    setState(() => loading = false);
  }

  Future<void> editCritere(Map c) async {
    String statut = c['statut'] ?? 'NON_TESTE';
    DateTime? dateTest = c['dateTest'] != null ? DateTime.tryParse(c['dateTest']) : null;
    String? testeurId = c['testeurId'];
    final commentaireCtrl = TextEditingController(text: c['commentaire'] ?? '');
    final anomalieCtrl = TextEditingController(text: c['anomalie'] ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(builder: (dialogCtx, setD) {
        return AlertDialog(
          title: Text(t('objectifsQhse.recette.dialogTitle', {'code': '${c['code'] ?? ''}', 'libelle': '${c['libelle'] ?? ''}'})),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              DropdownButtonFormField<String>(
                value: statut,
                decoration: InputDecoration(labelText: t('objectifsQhse.recette.statutField')),
                items: objRecetteStatutValues.map((k) => DropdownMenuItem(value: k, child: Text(objRecetteStatutLabel(k)))).toList(),
                onChanged: (v) => setD(() => statut = v ?? statut),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(dateTest == null ? t('objectifsQhse.recette.dateTest') : objFmtDate(dateTest!.toIso8601String())),
                trailing: const Icon(Icons.calendar_today, size: 18),
                onTap: () async {
                  final d = await showDatePicker(context: dialogCtx, initialDate: dateTest ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
                  if (d != null) setD(() => dateTest = d);
                },
              ),
              DropdownButtonFormField<String>(
                value: testeurId,
                decoration: InputDecoration(labelText: t('objectifsQhse.recette.testeur')),
                items: users.map<DropdownMenuItem<String>>((u) => DropdownMenuItem(value: u['id'] as String, child: Text(objUserName(u)))).toList(),
                onChanged: (v) => setD(() => testeurId = v),
              ),
              const SizedBox(height: 8),
              TextField(controller: commentaireCtrl, decoration: InputDecoration(labelText: t('objectifsQhse.recette.commentaire')), maxLines: 2),
              const SizedBox(height: 8),
              TextField(controller: anomalieCtrl, decoration: InputDecoration(labelText: t('objectifsQhse.recette.anomalie')), maxLines: 2),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(dialogCtx, true), child: Text(t('objectifsQhse.save'))),
          ],
        );
      }),
    );
    if (saved == true) {
      try {
        await Api().patch('/business/objectifs-qhse/recette/${c['id']}', {
          'statut': statut,
          'dateTest': dateTest?.toIso8601String(),
          'testeurId': testeurId,
          'commentaire': commentaireCtrl.text,
          'anomalie': anomalieCtrl.text,
        });
        load();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('objectifsQhse.recette.saveError', {'error': '$e'}))));
      }
    }
  }

  Future<void> exportCsv() async {
    try {
      final rows = <List<String>>[
        [t('objectifsQhse.recette.col.code'), t('objectifsQhse.recette.col.libelle'), t('objectifsQhse.recette.col.statut'), t('objectifsQhse.recette.col.dateTest'), t('objectifsQhse.recette.col.testeur'), t('objectifsQhse.recette.col.commentaire'), t('objectifsQhse.recette.col.anomalie')],
      ];
      for (final c in criteres) {
        rows.add([
          c['code'] ?? '',
          c['libelle'] ?? '',
          objRecetteStatutLabel(c['statut']?.toString()),
          c['dateTest'] != null ? objFmtDate(c['dateTest']) : '',
          objUserName(users.firstWhere((u) => u['id'] == c['testeurId'], orElse: () => {})),
          (c['commentaire'] ?? '').toString().replaceAll(',', ';'),
          (c['anomalie'] ?? '').toString().replaceAll(',', ';'),
        ]);
      }
      final csv = rows.map((r) => r.map((v) => '"${v.toString().replaceAll('"', '""')}"').join(',')).join('\n');
      final bytes = <int>[0xEF, 0xBB, 0xBF, ...utf8.encode(csv)];
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/recette_objectifs_qhse.csv');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: t('objectifsQhse.recette.shareText'));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('objectifsQhse.recette.exportError', {'error': '$e'}))));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final filtered = filter == 'TOUS' ? criteres : criteres.where((c) => c['statut'] == filter).toList();
    final total = criteres.length;
    final conforme = criteres.where((c) => c['statut'] == 'CONFORME').length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(child: Text(t('objectifsQhse.recette.progressLine', {'conforme': '$conforme', 'total': '$total'}), style: const TextStyle(fontWeight: FontWeight.bold))),
            IconButton(onPressed: exportCsv, icon: const Icon(Icons.download), tooltip: t('objectifsQhse.recette.exportTooltip')),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SizedBox(
            height: 40,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              const SizedBox(width: 4),
              ChoiceChip(label: Text(t('objectifsQhse.recette.tousChip')), selected: filter == 'TOUS', onSelected: (_) => setState(() => filter = 'TOUS')),
              const SizedBox(width: 6),
              ...objRecetteStatutValues.map((k) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(label: Text(objRecetteStatutLabel(k)), selected: filter == k, onSelected: (_) => setState(() => filter = k)),
                  )),
            ]),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? objEmpty(t('objectifsQhse.recette.empty'))
              : RefreshIndicator(
                  onRefresh: load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final c = filtered[i];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(backgroundColor: objRecetteColor(c['statut']), child: Text(c['code']?.toString().replaceAll('CA-', '') ?? '?', style: const TextStyle(fontSize: 11, color: Colors.white))),
                          title: Text(c['libelle'] ?? c['code'] ?? ''),
                          subtitle: Text(objRecetteStatutLabel(c['statut']?.toString())),
                          onTap: () => editCritere(c),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
