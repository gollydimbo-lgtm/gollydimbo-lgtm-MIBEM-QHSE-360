import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api.dart';
import '../services/sync_queue.dart';
import '../theme.dart';
import '../i18n/i18n.dart';
import 'load_error_view.dart';

// ============================================================================
// ÉQUIPEMENTS — module terrain + gestion (Phase 4B puis extension parité
// web) : consultation hors-ligne du registre (cache local), identification
// par scan QR, déclaration de contrôles réglementaires, et désormais aussi
// tableau de bord, maintenance (plans + interventions), étalonnage des
// instruments de mesure et consignation/cadenassage (LOTO), alignés sur le
// vrai flux du tableau de bord web (voir EquipmentPage/EquipmentDetailModal
// dans apps/web/src/App.jsx).
// ============================================================================

const equipmentEtatValues = ['ACTIF', 'EN_MAINTENANCE', 'EN_ATTENTE_REPARATION', 'HORS_SERVICE', 'CONSIGNE', 'REFORME', 'MIS_AU_REBUT', 'REMPLACE'];
String equipmentEtatLabel(String? k) => k == null ? '—' : (equipmentEtatValues.contains(k) ? t('equipment.etat.$k') : k);

const equipmentCriticiteValues = ['FAIBLE', 'MODERE', 'ELEVE', 'CRITIQUE'];
String equipmentCriticiteLabel(String? k) => k == null ? '—' : (equipmentCriticiteValues.contains(k) ? t('equipment.criticite.$k') : k);

const equipmentControlStatutValues = ['CONFORME', 'CONFORME_AVEC_OBSERVATIONS', 'NON_CONFORME', 'EN_ATTENTE', 'EXPIRE'];
String equipmentControlStatutLabel(String? k) => k == null ? '—' : (equipmentControlStatutValues.contains(k) ? t('equipment.controlStatut.$k') : k);

const equipmentCalibrationResultatValues = ['CONFORME', 'CONFORME_AVEC_AJUSTEMENT', 'NON_CONFORME'];
String equipmentCalibrationResultatLabel(String? k) => k == null ? '—' : (equipmentCalibrationResultatValues.contains(k) ? t('equipment.calibrationResultat.$k') : k);

const equipmentConsignationStatutValues = ['EN_COURS', 'LEVEE'];
String equipmentConsignationStatutLabel(String? k) => k == null ? '—' : (equipmentConsignationStatutValues.contains(k) ? t('equipment.consignationStatut.$k') : k);

const equipmentMaintenanceFrequenceValues = ['CALENDAIRE', 'HEURES', 'KM', 'CYCLES', 'RECOMMANDATION_FABRICANT', 'RISQUE'];
String equipmentMaintenanceFrequenceLabel(String? k) => k == null ? '—' : (equipmentMaintenanceFrequenceValues.contains(k) ? t('equipment.maintenanceFrequence.$k') : k);

const equipmentMaintenanceRecordStatutValues = ['PLANIFIEE', 'EN_COURS', 'TERMINEE', 'REPORTEE'];
String equipmentMaintenanceRecordStatutLabel(String? k) => k == null ? '—' : (equipmentMaintenanceRecordStatutValues.contains(k) ? t('equipment.maintenanceRecordStatut.$k') : k);

Color equipmentEtatColor(String? etat) => {
      'ACTIF': QhseColors.green, 'EN_MAINTENANCE': QhseColors.blue, 'EN_ATTENTE_REPARATION': QhseColors.amber,
      'HORS_SERVICE': QhseColors.red, 'CONSIGNE': QhseColors.red, 'REFORME': QhseColors.textSecondary, 'MIS_AU_REBUT': QhseColors.textSecondary,
    }[etat] ?? QhseColors.textSecondary;

Color equipmentCriticiteColor(String? n) => {
      'CRITIQUE': QhseColors.red, 'ELEVE': QhseColors.amber, 'MODERE': const Color(0xFFB45309), 'FAIBLE': QhseColors.green,
    }[n] ?? QhseColors.textSecondary;

Color equipmentCalibrationResultatColor(String? r) => {
      'CONFORME': QhseColors.green, 'CONFORME_AVEC_AJUSTEMENT': QhseColors.amber, 'NON_CONFORME': QhseColors.red,
    }[r] ?? QhseColors.textSecondary;

Color equipmentConsignationStatutColor(String? s) => s == 'EN_COURS' ? QhseColors.red : QhseColors.green;

DateTime? equipmentNextDueDate(Map e) {
  final dates = <DateTime>[];
  for (final p in List.from(e['maintenancePlans'] ?? [])) { final d = p['dateProchaine']; if (d != null) dates.add(DateTime.parse(d)); }
  for (final c in List.from(e['controls'] ?? [])) { final d = c['dateProchainControle']; if (d != null) dates.add(DateTime.parse(d)); }
  for (final c in List.from(e['calibrations'] ?? [])) { final d = c['dateProchaineEtalonnage']; if (d != null) dates.add(DateTime.parse(d)); }
  if (dates.isEmpty) return null;
  dates.sort();
  return dates.first;
}

bool equipmentIsOverdue(Map e) { final d = equipmentNextDueDate(e); return d != null && d.isBefore(DateTime.now()); }
bool equipmentHasNonConformiteOuverte(Map e) => List.from(e['nonConformities'] ?? []).any((n) => n['status'] != 'CLOSED');
String fmtDate(dynamic v) => v == null ? '—' : DateTime.parse(v).toIso8601String().substring(0, 10);
String fmtMoney(dynamic v) => v == null ? '—' : '${(v as num).toStringAsFixed(0)} FCFA';

/// Cache local du registre équipements — permet de consulter et de
/// sélectionner un équipement même sans réseau (le scan QR reste
/// utilisable hors-ligne grâce à ce cache : on retrouve l'équipement par
/// son qrToken sans appeler le serveur).
class EquipmentCache {
  static const _key = 'equipment_cache_v1';
  static Future<void> save(List items) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(items));
  }
  static Future<List> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null) return [];
    try { return List.from(jsonDecode(raw)); } catch (_) { return []; }
  }
}

class EquipmentPage extends StatefulWidget {
  const EquipmentPage({super.key});
  @override
  State<EquipmentPage> createState() => _EquipmentPageState();
}

class _EquipmentPageState extends State<EquipmentPage> {
  final api = Api();
  List items = [];
  Map? categories;
  Map? dashboard;
  bool loading = true;
  bool offline = false;
  bool showDashboard = false;
  String search = '';
  String filter = 'TOUS';

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final fresh = List.from(await api.get('/business/equipment'));
      items = fresh;
      offline = false;
      await EquipmentCache.save(fresh);
    } catch (_) {
      items = await EquipmentCache.load();
      offline = true;
    }
    if (!offline) {
      try { dashboard = Map.from(await api.get('/business/equipment-dashboard')); } catch (_) { dashboard = null; }
      try { categories = {for (final c in List.from(await api.get('/business/equipment-categories'))) c['id']: c['label']}; } catch (_) { categories = null; }
    }
    setState(() => loading = false);
  }

  Future<void> scan() async {
    final token = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const EquipmentQrScannerPage()));
    if (token == null || token.isEmpty) return;
    Map? found;
    try {
      found = Map.from(await api.get('/business/equipment/qr/$token'));
    } catch (_) {
      // Hors-ligne ou serveur injoignable : on cherche l'équipement dans le
      // cache local par son qrToken, comme le ferait le serveur.
      found = items.cast<Map>().firstWhere((e) => e['qrToken'] == token, orElse: () => {});
      if (found.isEmpty) found = null;
    }
    if (found == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('equipment.notFoundQr'))));
      return;
    }
    if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => EquipmentDetailPage(equipment: found!, onChanged: load)));
  }

  List get filtered {
    var list = items;
    if (filter == 'EN_RETARD') list = list.where((e) => equipmentIsOverdue(e)).toList();
    else if (filter == 'CRITIQUES') list = list.where((e) => e['criticiteNiveau'] == 'CRITIQUE').toList();
    else if (filter == 'NON_CONFORMES') list = list.where((e) => equipmentHasNonConformiteOuverte(e)).toList();
    else if (filter == 'MAINTENANCE') list = list.where((e) => e['etat'] == 'EN_MAINTENANCE').toList();
    else if (filter == 'HORS_SERVICE') list = list.where((e) => ['HORS_SERVICE', 'CONSIGNE', 'REFORME', 'MIS_AU_REBUT'].contains(e['etat'])).toList();
    if (search.trim().isNotEmpty) {
      final q = search.trim().toLowerCase();
      list = list.where((e) => '${e['code']} ${e['name']}'.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  String? categoryLabel(Map e) {
    final direct = e['categoryEq']?['label'];
    if (direct != null) return direct.toString();
    final id = e['categoryId'];
    if (id != null && categories != null) return categories![id]?.toString();
    return null;
  }

  Widget _buildDashboard() {
    final dash = dashboard;
    if (dash == null) return const SizedBox.shrink();
    final parEtat = Map<String, dynamic>.from(dash['parEtat'] ?? {});
    final parCriticite = Map<String, dynamic>.from(dash['parCriticite'] ?? {});
    final topCouts = List.from(dash['topCouts'] ?? []);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('equipment.dashboard.title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _kpiChip(t('equipment.dashboard.disponibilite'), dash['tauxDisponibilite'] != null ? '${dash['tauxDisponibilite']}%' : '—', QhseColors.green),
            _kpiChip(t('equipment.dashboard.indiceConformite'), dash['indiceConformite'] != null ? '${dash['indiceConformite']}%' : '—', QhseColors.blue),
            _kpiChip(t('equipment.dashboard.enRetard'), '${dash['enRetard'] ?? 0}', QhseColors.red),
            _kpiChip(t('equipment.dashboard.critiquesNonTraites'), '${dash['critiquesNonTraites'] ?? 0}', QhseColors.red),
            _kpiChip(t('equipment.dashboard.coutMaintenance'), fmtMoney(dash['coutTotalMaintenance']), QhseColors.amber),
            _kpiChip(t('equipment.dashboard.coutEtalonControles'), fmtMoney((dash['coutTotalEtalonnage'] ?? 0) + (dash['coutTotalControles'] ?? 0)), QhseColors.amber),
          ]),
          const SizedBox(height: 14),
          Text(t('equipment.dashboard.repartitionEtat'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: parEtat.entries.map((e) => Chip(
                label: Text(t('equipment.countSuffix', {'label': equipmentEtatLabel(e.key), 'value': '${e.value}'}), style: const TextStyle(fontSize: 11)),
                backgroundColor: equipmentEtatColor(e.key).withOpacity(0.15),
              )).toList()),
          const SizedBox(height: 10),
          Text(t('equipment.dashboard.repartitionCriticite'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: parCriticite.entries.map((e) => Chip(
                label: Text(t('equipment.countSuffix', {'label': equipmentCriticiteLabel(e.key), 'value': '${e.value}'}), style: const TextStyle(fontSize: 11)),
                backgroundColor: equipmentCriticiteColor(e.key).withOpacity(0.15),
              )).toList()),
          if (topCouts.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(t('equipment.dashboard.topCouts'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            ...topCouts.map((t) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Expanded(child: Text('${t['code']} — ${t['name']}', style: const TextStyle(fontSize: 12))),
                    Text(fmtMoney(t['total']), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                )),
          ],
        ]),
      ),
    );
  }

  Widget _kpiChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
        Text(label, style: TextStyle(color: color, fontSize: 10)),
      ]),
    );
  }

  @override
  Widget build(BuildContext c) {
    final list = filtered;
    return Scaffold(
      appBar: AppBar(title: Text(t('equipment.appBarTitle')), actions: [
        if (offline) Padding(padding: const EdgeInsets.only(right: 8), child: Center(child: Chip(label: Text(t('equipment.offline')), backgroundColor: const Color(0xFFFFE0B2)))),
        if (!offline && dashboard != null)
          IconButton(
            tooltip: t('equipment.dashboardTooltip'),
            icon: Icon(Icons.insights, color: showDashboard ? QhseColors.blue : null),
            onPressed: () => setState(() => showDashboard = !showDashboard),
          ),
      ]),
      // mobile_scanner ne supporte pas Windows/desktop (fédération de
      // plugins) : sur ces plateformes, l'identification se fait par la
      // recherche texte ci-dessus plutôt que par un bouton qui échouerait.
      floatingActionButton: (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)
          ? FloatingActionButton.extended(onPressed: scan, icon: const Icon(Icons.qr_code_scanner), label: Text(t('equipment.scanQr')))
          : null,
      body: loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
        onRefresh: load,
        child: ListView(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: t('equipment.searchHint'), border: const OutlineInputBorder()),
              onChanged: (v) => setState(() => search = v),
            ),
          ),
          if (showDashboard) Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: _buildDashboard()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
              for (final f in const ['TOUS', 'EN_RETARD', 'CRITIQUES', 'NON_CONFORMES', 'MAINTENANCE', 'HORS_SERVICE'])
                Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(t('equipment.filter.$f')), selected: filter == f, onSelected: (_) => setState(() => filter = f))),
            ])),
          ),
          const SizedBox(height: 8),
          if (list.isEmpty)
            Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(t('equipment.emptyFiltered'))))
          else
            ...list.map((e) {
              final overdue = equipmentIsOverdue(e);
              final cat = categoryLabel(e);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Card(child: ListTile(
                  leading: Icon(Icons.precision_manufacturing, color: overdue ? QhseColors.red : equipmentEtatColor(e['etat'])),
                  title: Text('${e['code']} — ${e['name']}'),
                  subtitle: Text('${cat != null ? '$cat • ' : ''}${e['site']?['name'] ?? t('equipment.siteNonRenseigne')} • ${equipmentEtatLabel(e['etat']?.toString())}'),
                  trailing: overdue ? Chip(label: Text(t('equipment.filter.EN_RETARD')), backgroundColor: const Color(0xFFFFCDD2)) : (e['criticiteNiveau'] == 'CRITIQUE' ? Chip(label: Text(t('equipment.criticite.CRITIQUE')), backgroundColor: equipmentCriticiteColor('CRITIQUE').withOpacity(0.2)) : null),
                  onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => EquipmentDetailPage(equipment: Map.from(e), onChanged: load))),
                )),
              );
            }),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}

class EquipmentDetailPage extends StatefulWidget {
  final Map equipment;
  final VoidCallback onChanged;
  const EquipmentDetailPage({super.key, required this.equipment, required this.onChanged});
  @override
  State<EquipmentDetailPage> createState() => _EquipmentDetailPageState();
}

class _EquipmentDetailPageState extends State<EquipmentDetailPage> with SingleTickerProviderStateMixin {
  final api = Api();
  late Map e = widget.equipment;
  bool refreshing = false;
  late TabController tabController;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    setState(() => refreshing = true);
    try { e = Map.from(await api.get('/business/equipment/${e['id']}')); } catch (_) { /* reste sur les données déjà connues (hors-ligne) */ }
    setState(() => refreshing = false);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${e['code']}'),
        actions: [IconButton(onPressed: refreshing ? null : refresh, icon: const Icon(Icons.refresh))],
        bottom: TabBar(
          controller: tabController,
          isScrollable: true,
          tabs: [
            Tab(text: t('equipment.tab.identification')),
            Tab(text: t('equipment.tab.maintenance')),
            Tab(text: t('equipment.tab.controles')),
            Tab(text: t('equipment.tab.etalonnage')),
            Tab(text: t('equipment.tab.consignation')),
          ],
        ),
      ),
      body: TabBarView(controller: tabController, children: [
        _EquipmentIdentificationTab(equipment: e),
        _EquipmentMaintenanceTab(equipmentId: e['id'].toString(), onChanged: refresh),
        _EquipmentControlsTab(equipmentId: e['id'].toString(), onChanged: refresh),
        _EquipmentCalibrationsTab(equipmentId: e['id'].toString(), onChanged: refresh),
        _EquipmentConsignationsTab(equipmentId: e['id'].toString(), onChanged: refresh),
      ]),
    );
  }
}

Widget _sectionTitle(String t) => Padding(padding: const EdgeInsets.only(bottom: 6, top: 4), child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold)));
Widget _emptyHint(String t) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(t, style: TextStyle(color: QhseColors.textSecondary)));

// ---------------------------------------------------------------------------
// Onglet Identification
// ---------------------------------------------------------------------------

class _EquipmentIdentificationTab extends StatelessWidget {
  final Map equipment;
  const _EquipmentIdentificationTab({required this.equipment});

  Widget _row(String label, dynamic value) {
    final v = (value == null || '$value'.trim().isEmpty) ? '—' : '$value';
    return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [
      SizedBox(width: 140, child: Text(label, style: TextStyle(color: QhseColors.textSecondary, fontSize: 12))),
      Expanded(child: Text(v)),
    ]));
  }

  @override
  Widget build(BuildContext context) {
    final e = equipment;
    final nonConformities = List.from(e['nonConformities'] ?? []);
    final next = equipmentNextDueDate(e);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text(e['name'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        Chip(label: Text(equipmentEtatLabel(e['etat']?.toString())), backgroundColor: equipmentEtatColor(e['etat']).withOpacity(0.15), labelStyle: TextStyle(color: equipmentEtatColor(e['etat']))),
        if (e['criticiteNiveau'] != null) Chip(label: Text(t('equipment.criticiteAxisLabel', {'value': equipmentCriticiteLabel(e['criticiteNiveau']?.toString())})), backgroundColor: equipmentCriticiteColor(e['criticiteNiveau']).withOpacity(0.15), labelStyle: TextStyle(color: equipmentCriticiteColor(e['criticiteNiveau']))),
        if (next != null) Chip(label: Text(t('equipment.prochaineEcheance', {'date': fmtDate(next.toIso8601String())})), backgroundColor: (next.isBefore(DateTime.now()) ? QhseColors.red : QhseColors.blue).withOpacity(0.15)),
      ]),
      const SizedBox(height: 16),
      Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t('equipment.identificationTitle'), style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _row(t('equipment.field.categorie'), e['categoryEq']?['label'] ?? e['category']),
        _row(t('equipment.field.type'), [e['type'], e['sousType']].where((x) => x != null && '$x'.isNotEmpty).join(' / ')),
        _row(t('equipment.field.site'), e['site']?['name']),
        _row(t('equipment.field.serviceUnite'), e['workUnit']?['name']),
        _row(t('equipment.field.marqueModele'), [e['marque'], e['modele']].where((x) => x != null && '$x'.isNotEmpty).join(' ')),
        _row(t('equipment.field.numeroSerie'), e['numeroSerie']),
        _row(t('equipment.field.anneeFabrication'), e['anneeFabrication']),
        _row(t('equipment.field.responsable'), e['responsable'] != null ? '${e['responsable']['firstName']} ${e['responsable']['lastName']}' : null),
        _row(t('equipment.field.batimentZone'), [e['batiment'], e['zone']].where((x) => x != null && '$x'.isNotEmpty).join(' / ')),
      ]))),
      if (e['criticiteSecurite'] != null || e['criticiteQualite'] != null || e['criticiteEnvironnement'] != null || e['criticiteProduction'] != null) ...[
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('equipment.criticiteParAxe'), style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(spacing: 16, children: [
            Text(t('equipment.axis.securite', {'value': '${e['criticiteSecurite'] ?? '—'}'})),
            Text(t('equipment.axis.qualite', {'value': '${e['criticiteQualite'] ?? '—'}'})),
            Text(t('equipment.axis.environnement', {'value': '${e['criticiteEnvironnement'] ?? '—'}'})),
            Text(t('equipment.axis.production', {'value': '${e['criticiteProduction'] ?? '—'}'})),
          ]),
        ]))),
      ],
      if (e['notes'] != null && '${e['notes']}'.trim().isNotEmpty) ...[
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('equipment.notes'), style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('${e['notes']}'),
        ]))),
      ],
      const SizedBox(height: 12),
      _sectionTitle(t('equipment.ncLieesTitle', {'count': '${nonConformities.length}'})),
      if (nonConformities.isEmpty) _emptyHint(t('equipment.ncLieesEmpty'))
      else ...nonConformities.map((n) => Card(child: ListTile(leading: const Icon(Icons.report, color: Colors.red), title: Text(n['title'] ?? ''), subtitle: Text('${n['code']} • ${n['status']}')))),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Onglet Maintenance (plans préventifs + interventions + statistiques)
// ---------------------------------------------------------------------------

class _EquipmentMaintenanceTab extends StatefulWidget {
  final String equipmentId;
  final VoidCallback onChanged;
  const _EquipmentMaintenanceTab({required this.equipmentId, required this.onChanged});
  @override
  State<_EquipmentMaintenanceTab> createState() => _EquipmentMaintenanceTabState();
}

class _EquipmentMaintenanceTabState extends State<_EquipmentMaintenanceTab> {
  final api = Api();
  List plans = [];
  List records = [];
  Map? stats;
  List users = [];
  bool loading = true;
  Object? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final results = await Future.wait([
        api.get('/business/equipment-maintenance-plans?equipmentId=${widget.equipmentId}'),
        api.get('/business/equipment-maintenance-records?equipmentId=${widget.equipmentId}'),
        api.get('/business/equipment/${widget.equipmentId}/maintenance-stats'),
        api.get('/users'),
      ]);
      plans = List.from(results[0]);
      records = List.from(results[1]);
      stats = Map.from(results[2]);
      users = List.from(results[3]);
    } catch (e) { error = e; }
    if (mounted) setState(() => loading = false);
  }

  Future<void> reload() async { await load(); widget.onChanged(); }

  Future<void> newPlan() async {
    final designationCtrl = TextEditingController();
    String frequenceType = 'CALENDAIRE';
    final valeurCtrl = TextEditingController(text: '30');
    String? responsableId;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => StatefulBuilder(builder: (dctx, setD) => AlertDialog(
        title: Text(t('equipment.dialog.newPlan')),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: designationCtrl, decoration: InputDecoration(labelText: t('equipment.dialog.designation'))),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: frequenceType,
            decoration: InputDecoration(labelText: t('equipment.dialog.typeFrequence')),
            items: equipmentMaintenanceFrequenceValues.map((k) => DropdownMenuItem(value: k, child: Text(equipmentMaintenanceFrequenceLabel(k)))).toList(),
            onChanged: (v) => setD(() => frequenceType = v ?? frequenceType),
          ),
          const SizedBox(height: 12),
          TextField(controller: valeurCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('equipment.dialog.valeur'))),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: responsableId,
            decoration: InputDecoration(labelText: t('equipment.dialog.responsableOptional')),
            items: [const DropdownMenuItem(value: null, child: Text('—')), ...users.map((u) => DropdownMenuItem(value: u['id'].toString(), child: Text('${u['firstName']} ${u['lastName']}')))],
            onChanged: (v) => setD(() => responsableId = v),
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.of(dctx).pop(false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.of(dctx).pop(true), child: Text(t('equipment.dialog.create'))),
        ],
      )),
    );
    if (ok != true || designationCtrl.text.trim().isEmpty) return;
    try {
      await api.post('/business/equipment-maintenance-plans', {
        'equipmentId': widget.equipmentId,
        'designation': designationCtrl.text.trim(),
        'frequenceType': frequenceType,
        'frequenceValeur': num.tryParse(valeurCtrl.text.trim()) ?? 0,
        'responsableId': responsableId,
      });
      reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('equipment.error', {'error': '$e'}))));
    }
  }

  Future<void> newRecord() async {
    String type = 'CORRECTIVE';
    String statut = 'TERMINEE';
    String? planId;
    DateTime? datePanne;
    DateTime? dateDebut;
    DateTime? dateFin;
    final dureeCtrl = TextEditingController();
    final coutCtrl = TextEditingController();
    final descriptionCtrl = TextEditingController();
    final causeCtrl = TextEditingController();
    Future<DateTime?> pick(BuildContext ctx) => showDatePicker(context: ctx, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 3650)));
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => StatefulBuilder(builder: (dctx, setD) => AlertDialog(
        title: Text(t('equipment.dialog.newRecord')),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            value: type,
            decoration: InputDecoration(labelText: t('equipment.dialog.type')),
            items: [DropdownMenuItem(value: 'CORRECTIVE', child: Text(t('equipment.dialog.typeCorrective'))), DropdownMenuItem(value: 'PREVENTIVE', child: Text(t('equipment.dialog.typePreventive')))],
            onChanged: (v) => setD(() => type = v ?? type),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: statut,
            decoration: InputDecoration(labelText: t('equipment.dialog.statut')),
            items: equipmentMaintenanceRecordStatutValues.map((k) => DropdownMenuItem(value: k, child: Text(equipmentMaintenanceRecordStatutLabel(k)))).toList(),
            onChanged: (v) => setD(() => statut = v ?? statut),
          ),
          if (type == 'PREVENTIVE') ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: planId,
              decoration: InputDecoration(labelText: t('equipment.dialog.planLieOptional')),
              items: [const DropdownMenuItem(value: null, child: Text('—')), ...plans.map((p) => DropdownMenuItem(value: p['id'].toString(), child: Text(p['designation'] ?? '')))],
              onChanged: (v) => setD(() => planId = v),
            ),
          ],
          if (type == 'CORRECTIVE') ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: () async { final d = await pick(dctx); if (d != null) setD(() => datePanne = d); }, child: Text(datePanne == null ? t('equipment.dialog.datePanne') : fmtDate(datePanne!.toIso8601String()))),
          ],
          const SizedBox(height: 12),
          OutlinedButton(onPressed: () async { final d = await pick(dctx); if (d != null) setD(() => dateDebut = d); }, child: Text(dateDebut == null ? t('equipment.dialog.debutIntervention') : fmtDate(dateDebut!.toIso8601String()))),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: () async { final d = await pick(dctx); if (d != null) setD(() => dateFin = d); }, child: Text(dateFin == null ? t('equipment.dialog.finIntervention') : fmtDate(dateFin!.toIso8601String()))),
          const SizedBox(height: 12),
          TextField(controller: dureeCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('equipment.dialog.dureeOptional'))),
          const SizedBox(height: 12),
          TextField(controller: coutCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('equipment.dialog.coutOptional'))),
          if (type == 'CORRECTIVE') ...[
            const SizedBox(height: 12),
            TextField(controller: causeCtrl, decoration: InputDecoration(labelText: t('equipment.dialog.causePanneOptional'))),
          ],
          const SizedBox(height: 12),
          TextField(controller: descriptionCtrl, maxLines: 2, decoration: InputDecoration(labelText: t('equipment.dialog.descriptionOptional'))),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.of(dctx).pop(false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.of(dctx).pop(true), child: const Text('Enregistrer')),
        ],
      )),
    );
    if (ok != true) return;
    try {
      await api.post('/business/equipment-maintenance-records', {
        'equipmentId': widget.equipmentId,
        'type': type,
        'statut': statut,
        'planId': planId,
        'datePanne': datePanne?.toIso8601String(),
        'dateDebut': dateDebut?.toIso8601String(),
        'dateFin': dateFin?.toIso8601String(),
        'dureeHeures': dureeCtrl.text.trim().isEmpty ? null : num.tryParse(dureeCtrl.text.trim()),
        'cout': coutCtrl.text.trim().isEmpty ? null : num.tryParse(coutCtrl.text.trim()),
        'description': descriptionCtrl.text.trim().isEmpty ? null : descriptionCtrl.text.trim(),
        'causePanne': causeCtrl.text.trim().isEmpty ? null : causeCtrl.text.trim(),
      });
      reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('equipment.error', {'error': '$e'}))));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return LoadErrorView(error: error, onRetry: load);
    final s = stats;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        if (s != null) Wrap(spacing: 8, runSpacing: 8, children: [
          Chip(label: Text(t('equipment.maintenance.pannes', {'value': '${s['nombrePannes'] ?? 0}'}))),
          Chip(label: Text(t('equipment.maintenance.mtbf', {'value': '${s['mtbfHeures'] != null ? (s['mtbfHeures'] as num).round() : '—'}'}))),
          Chip(label: Text(t('equipment.maintenance.mttr', {'value': '${s['mttrHeures'] != null ? (s['mttrHeures'] as num).round() : '—'}'}))),
          Chip(label: Text(t('equipment.maintenance.disponibiliteChip', {'value': s['disponibilite'] != null ? '${((s['disponibilite'] as num) * 100).round()}%' : '—'}))),
        ]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(t('equipment.maintenance.plansTitle'), style: const TextStyle(fontWeight: FontWeight.bold)),
          TextButton.icon(onPressed: newPlan, icon: const Icon(Icons.add, size: 18), label: Text(t('equipment.maintenance.newPlanBtn'))),
        ]),
        if (plans.isEmpty) _emptyHint(t('equipment.maintenance.plansEmpty'))
        else ...plans.map((p) => Card(child: ListTile(
              title: Text(p['designation'] ?? ''),
              subtitle: Text(t('equipment.maintenance.planSubtitle', {'valeur': '${p['frequenceValeur']}', 'freq': equipmentMaintenanceFrequenceLabel(p['frequenceType']?.toString()), 'date': fmtDate(p['dateProchaine'])})),
            ))),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(t('equipment.maintenance.interventionsTitle'), style: const TextStyle(fontWeight: FontWeight.bold)),
          TextButton.icon(onPressed: newRecord, icon: const Icon(Icons.add, size: 18), label: Text(t('equipment.dialog.newRecord'))),
        ]),
        if (records.isEmpty) _emptyHint(t('equipment.maintenance.recordsEmpty'))
        else ...records.map((r) => Card(child: ListTile(
              title: Text(r['type'] == 'PREVENTIVE' ? t('equipment.maintenance.recordTypePreventive') : t('equipment.maintenance.recordTypeCorrective')),
              subtitle: Text('${equipmentMaintenanceRecordStatutLabel(r['statut']?.toString())} • ${fmtDate(r['datePanne'] ?? r['dateDebut'])}${r['dureeHeures'] != null ? ' • ${r['dureeHeures']} h' : ''}${r['cout'] != null ? ' • ${fmtMoney(r['cout'])}' : ''}'),
            ))),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Onglet Contrôles réglementaires
// ---------------------------------------------------------------------------

class _EquipmentControlsTab extends StatefulWidget {
  final String equipmentId;
  final VoidCallback onChanged;
  const _EquipmentControlsTab({required this.equipmentId, required this.onChanged});
  @override
  State<_EquipmentControlsTab> createState() => _EquipmentControlsTabState();
}

class _EquipmentControlsTabState extends State<_EquipmentControlsTab> {
  final api = Api();
  List controls = [];
  bool loading = true;
  Object? error;
  String? genId;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try { controls = List.from(await api.get('/business/equipment-controls?equipmentId=${widget.equipmentId}')); } catch (e) { error = e; }
    if (mounted) setState(() => loading = false);
  }

  Future<void> reload() async { await load(); widget.onChanged(); }

  Future<void> newControl() async {
    final saved = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => EquipmentControlFormPage(equipmentId: widget.equipmentId)));
    if (saved == true) reload();
  }

  Future<void> generateNc(String id) async {
    setState(() => genId = id);
    try { await api.post('/business/equipment-controls/$id/generate-nc', {}); await reload(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('equipment.error', {'error': '$e'})))); }
    setState(() => genId = null);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return LoadErrorView(error: error, onRetry: load);
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(t('equipment.controls.title'), style: const TextStyle(fontWeight: FontWeight.bold)),
          TextButton.icon(onPressed: newControl, icon: const Icon(Icons.add, size: 18), label: Text(t('equipment.controls.newBtn'))),
        ]),
        if (controls.isEmpty) _emptyHint(t('equipment.controls.empty'))
        else ...controls.map((ctl) => Card(child: ListTile(
              leading: Icon(Icons.fact_check, color: ctl['statut'] == 'NON_CONFORME' ? QhseColors.red : QhseColors.green),
              title: Text(ctl['designation'] ?? ''),
              subtitle: Text('${equipmentControlStatutLabel(ctl['statut']?.toString())} • ${fmtDate(ctl['dateControle'])}${ctl['dateProchainControle'] != null ? ' • ' + t('equipment.controls.prochain', {'date': fmtDate(ctl['dateProchainControle'])}) : ''}'),
              trailing: (ctl['statut'] == 'NON_CONFORME' && ctl['nonConformityId'] == null)
                  ? TextButton(onPressed: genId == ctl['id'] ? null : () => generateNc(ctl['id'].toString()), child: Text(genId == ctl['id'] ? '…' : t('equipment.controls.generateNc')))
                  : (ctl['nonConformityId'] != null ? Text(t('equipment.controls.ncCreee'), style: const TextStyle(fontSize: 11)) : null),
            ))),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Onglet Étalonnage des instruments de mesure
// ---------------------------------------------------------------------------

class _EquipmentCalibrationsTab extends StatefulWidget {
  final String equipmentId;
  final VoidCallback onChanged;
  const _EquipmentCalibrationsTab({required this.equipmentId, required this.onChanged});
  @override
  State<_EquipmentCalibrationsTab> createState() => _EquipmentCalibrationsTabState();
}

class _EquipmentCalibrationsTabState extends State<_EquipmentCalibrationsTab> {
  final api = Api();
  List calibrations = [];
  bool loading = true;
  Object? error;
  String? genId;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try { calibrations = List.from(await api.get('/business/equipment-calibrations?equipmentId=${widget.equipmentId}')); } catch (e) { error = e; }
    if (mounted) setState(() => loading = false);
  }

  Future<void> reload() async { await load(); widget.onChanged(); }

  Future<void> newCalibration() async {
    DateTime dateEtalonnage = DateTime.now();
    DateTime? dateProchaineEtalonnage;
    String resultat = 'CONFORME';
    final organismeCtrl = TextEditingController();
    final certificatCtrl = TextEditingController();
    final incertitudeCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => StatefulBuilder(builder: (dctx, setD) => AlertDialog(
        title: Text(t('equipment.calibrations.newBtn')),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          OutlinedButton(
            onPressed: () async {
              final d = await showDatePicker(context: dctx, initialDate: dateEtalonnage, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 3650)));
              if (d != null) setD(() => dateEtalonnage = d);
            },
            child: Text(t('equipment.dialog.dateEtalonnage', {'date': fmtDate(dateEtalonnage.toIso8601String())})),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () async {
              final d = await showDatePicker(context: dctx, initialDate: dateProchaineEtalonnage ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 3650)));
              if (d != null) setD(() => dateProchaineEtalonnage = d);
            },
            child: Text(dateProchaineEtalonnage == null ? t('equipment.dialog.prochainEtalonnageOptional') : fmtDate(dateProchaineEtalonnage!.toIso8601String())),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: resultat,
            decoration: InputDecoration(labelText: t('equipment.dialog.resultat')),
            items: equipmentCalibrationResultatValues.map((k) => DropdownMenuItem(value: k, child: Text(equipmentCalibrationResultatLabel(k)))).toList(),
            onChanged: (v) => setD(() => resultat = v ?? resultat),
          ),
          const SizedBox(height: 12),
          TextField(controller: organismeCtrl, decoration: InputDecoration(labelText: t('equipment.dialog.organismeOptional'))),
          const SizedBox(height: 12),
          TextField(controller: certificatCtrl, decoration: InputDecoration(labelText: t('equipment.dialog.certificatOptional'))),
          const SizedBox(height: 12),
          TextField(controller: incertitudeCtrl, decoration: InputDecoration(labelText: t('equipment.dialog.incertitudeOptional'))),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.of(dctx).pop(false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.of(dctx).pop(true), child: const Text('Enregistrer')),
        ],
      )),
    );
    if (ok != true) return;
    try {
      await api.post('/business/equipment-calibrations', {
        'equipmentId': widget.equipmentId,
        'dateEtalonnage': dateEtalonnage.toIso8601String(),
        'dateProchaineEtalonnage': dateProchaineEtalonnage?.toIso8601String(),
        'resultat': resultat,
        'organismeEtalonneur': organismeCtrl.text.trim().isEmpty ? null : organismeCtrl.text.trim(),
        'certificatNumero': certificatCtrl.text.trim().isEmpty ? null : certificatCtrl.text.trim(),
        'incertitude': incertitudeCtrl.text.trim().isEmpty ? null : incertitudeCtrl.text.trim(),
      });
      reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('equipment.error', {'error': '$e'}))));
    }
  }

  Future<void> generateNc(String id) async {
    setState(() => genId = id);
    try { await api.post('/business/equipment-calibrations/$id/generate-nc', {}); await reload(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('equipment.error', {'error': '$e'})))); }
    setState(() => genId = null);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return LoadErrorView(error: error, onRetry: load);
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(t('equipment.calibrations.title'), style: const TextStyle(fontWeight: FontWeight.bold)),
          TextButton.icon(onPressed: newCalibration, icon: const Icon(Icons.add, size: 18), label: Text(t('equipment.calibrations.newBtn'))),
        ]),
        if (calibrations.isEmpty) _emptyHint(t('equipment.calibrations.empty'))
        else ...calibrations.map((cal) => Card(child: ListTile(
              leading: Icon(Icons.rule, color: equipmentCalibrationResultatColor(cal['resultat'])),
              title: Text(equipmentCalibrationResultatLabel(cal['resultat']?.toString())),
              subtitle: Text('${fmtDate(cal['dateEtalonnage'])} → ' + t('equipment.controls.prochain', {'date': fmtDate(cal['dateProchaineEtalonnage'])}) + (cal['nePasUtiliser'] == true ? ' • ' + t('equipment.calibrations.nePasUtiliser') : '')),
              trailing: (cal['resultat'] != 'CONFORME' && cal['nonConformityId'] == null)
                  ? TextButton(onPressed: genId == cal['id'] ? null : () => generateNc(cal['id'].toString()), child: Text(genId == cal['id'] ? '…' : t('equipment.controls.generateNc')))
                  : (cal['nonConformityId'] != null ? Text(t('equipment.controls.ncCreee'), style: const TextStyle(fontSize: 11)) : null),
            ))),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Onglet Consignation / cadenassage (LOTO)
// ---------------------------------------------------------------------------

class _EquipmentConsignationsTab extends StatefulWidget {
  final String equipmentId;
  final VoidCallback onChanged;
  const _EquipmentConsignationsTab({required this.equipmentId, required this.onChanged});
  @override
  State<_EquipmentConsignationsTab> createState() => _EquipmentConsignationsTabState();
}

class _EquipmentConsignationsTabState extends State<_EquipmentConsignationsTab> {
  final api = Api();
  List consignations = [];
  List users = [];
  bool loading = true;
  Object? error;
  String? busyId;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final results = await Future.wait([
        api.get('/business/equipment-consignations?equipmentId=${widget.equipmentId}'),
        api.get('/users'),
      ]);
      consignations = List.from(results[0]);
      users = List.from(results[1]);
    } catch (e) { error = e; }
    if (mounted) setState(() => loading = false);
  }

  Future<void> reload() async { await load(); widget.onChanged(); }

  Future<void> newConsignation() async {
    final motifCtrl = TextEditingController();
    final risqueCtrl = TextEditingController();
    final mesureCtrl = TextEditingController();
    DateTime? dateFinPrevue;
    String? responsableId;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => StatefulBuilder(builder: (dctx, setD) => AlertDialog(
        title: Text(t('equipment.dialog.newConsignation')),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: motifCtrl, decoration: InputDecoration(labelText: t('equipment.dialog.motif'))),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () async {
              final d = await showDatePicker(context: dctx, initialDate: dateFinPrevue ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 3650)));
              if (d != null) setD(() => dateFinPrevue = d);
            },
            child: Text(dateFinPrevue == null ? t('equipment.dialog.finPrevueOptional') : fmtDate(dateFinPrevue!.toIso8601String())),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: responsableId,
            decoration: InputDecoration(labelText: t('equipment.dialog.responsableOptional')),
            items: [const DropdownMenuItem(value: null, child: Text('—')), ...users.map((u) => DropdownMenuItem(value: u['id'].toString(), child: Text('${u['firstName']} ${u['lastName']}')))],
            onChanged: (v) => setD(() => responsableId = v),
          ),
          const SizedBox(height: 12),
          TextField(controller: risqueCtrl, decoration: InputDecoration(labelText: t('equipment.dialog.risqueAssocieOptional'))),
          const SizedBox(height: 12),
          TextField(controller: mesureCtrl, decoration: InputDecoration(labelText: t('equipment.dialog.mesureMaitriseOptional'))),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.of(dctx).pop(false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.of(dctx).pop(true), child: const Text('Enregistrer')),
        ],
      )),
    );
    if (ok != true || motifCtrl.text.trim().isEmpty) return;
    try {
      await api.post('/business/equipment-consignations', {
        'equipmentId': widget.equipmentId,
        'motif': motifCtrl.text.trim(),
        'dateFinPrevue': dateFinPrevue?.toIso8601String(),
        'responsableId': responsableId,
        'risqueAssocie': risqueCtrl.text.trim().isEmpty ? null : risqueCtrl.text.trim(),
        'mesureControle': mesureCtrl.text.trim().isEmpty ? null : mesureCtrl.text.trim(),
      });
      reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('equipment.error', {'error': '$e'}))));
    }
  }

  Future<void> lever(String id) async {
    setState(() => busyId = id);
    try { await api.post('/business/equipment-consignations/$id/lever', {}); await reload(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('equipment.error', {'error': '$e'})))); }
    setState(() => busyId = null);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return LoadErrorView(error: error, onRetry: load);
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Text(t('equipment.consignations.hint'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(t('equipment.consignations.title'), style: const TextStyle(fontWeight: FontWeight.bold)),
          TextButton.icon(onPressed: newConsignation, icon: const Icon(Icons.add, size: 18), label: Text(t('equipment.consignations.newBtn'))),
        ]),
        if (consignations.isEmpty) _emptyHint(t('equipment.consignations.empty'))
        else ...consignations.map((c) => Card(child: ListTile(
              leading: Icon(Icons.lock, color: equipmentConsignationStatutColor(c['statut'])),
              title: Text(c['motif'] ?? ''),
              subtitle: Text('${fmtDate(c['dateDebut'])} → ${fmtDate(c['dateFinPrevue'])} • ${equipmentConsignationStatutLabel(c['statut']?.toString())}'),
              trailing: c['statut'] == 'EN_COURS'
                  ? TextButton(onPressed: busyId == c['id'] ? null : () => lever(c['id'].toString()), child: Text(busyId == c['id'] ? '…' : t('equipment.consignations.lever')))
                  : null,
            ))),
      ]),
    );
  }
}

class EquipmentControlFormPage extends StatefulWidget {
  final String equipmentId;
  const EquipmentControlFormPage({super.key, required this.equipmentId});
  @override
  State<EquipmentControlFormPage> createState() => _EquipmentControlFormPageState();
}

class _EquipmentControlFormPageState extends State<EquipmentControlFormPage> {
  final api = Api();
  final designation = TextEditingController();
  final organisme = TextEditingController();
  final referenceReglementaire = TextEditingController();
  final observations = TextEditingController();
  DateTime dateControle = DateTime.now();
  DateTime? dateProchainControle;
  String statut = 'CONFORME';
  bool busy = false;
  String? error;

  Future<void> pickDate(bool prochain) async {
    final d = await showDatePicker(context: context, initialDate: prochain ? (dateProchainControle ?? DateTime.now()) : dateControle, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 3650)));
    if (d == null) return;
    setState(() { if (prochain) dateProchainControle = d; else dateControle = d; });
  }

  Future<void> submit() async {
    if (designation.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('equipment.controlForm.designationRequired'))));
      return;
    }
    setState(() { busy = true; error = null; });
    final payload = {
      'equipmentId': widget.equipmentId,
      'designation': designation.text.trim(),
      'organisme': organisme.text.trim().isEmpty ? null : organisme.text.trim(),
      'referenceReglementaire': referenceReglementaire.text.trim().isEmpty ? null : referenceReglementaire.text.trim(),
      'dateControle': dateControle.toIso8601String(),
      'dateProchainControle': dateProchainControle?.toIso8601String(),
      'statut': statut,
      'observations': observations.text.trim().isEmpty ? null : observations.text.trim(),
    };
    try {
      await api.post('/business/equipment-controls', payload);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (e.networkError) {
        await SyncQueue.enqueue('equipmentControl', 'CREATE', payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('equipment.controlForm.offlineQueued')), duration: const Duration(seconds: 4)));
          Navigator.pop(context, true);
        }
      } else {
        setState(() { busy = false; error = '$e'; });
      }
    } catch (e) {
      setState(() { busy = false; error = '$e'; });
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text(t('equipment.controlForm.title'))),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      TextField(controller: designation, decoration: InputDecoration(labelText: t('equipment.controlForm.designationField'), border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: organisme, decoration: InputDecoration(labelText: t('equipment.controlForm.organismeField'), border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: referenceReglementaire, decoration: InputDecoration(labelText: t('equipment.controlForm.referenceField'), border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: () => pickDate(false), icon: const Icon(Icons.event), label: Text(t('equipment.controlForm.controleDate', {'date': fmtDate(dateControle.toIso8601String())})))),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton.icon(onPressed: () => pickDate(true), icon: const Icon(Icons.event_repeat), label: Text(dateProchainControle == null ? t('equipment.controlForm.prochainOptional') : fmtDate(dateProchainControle!.toIso8601String())))),
      ]),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: statut,
        decoration: InputDecoration(labelText: t('equipment.dialog.statut'), border: const OutlineInputBorder()),
        items: equipmentControlStatutValues.map((k) => DropdownMenuItem(value: k, child: Text(equipmentControlStatutLabel(k)))).toList(),
        onChanged: (v) => setState(() => statut = v ?? statut),
      ),
      const SizedBox(height: 12),
      TextField(controller: observations, maxLines: 3, decoration: InputDecoration(labelText: t('equipment.controlForm.observationsOptional'), border: const OutlineInputBorder())),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
      const SizedBox(height: 20),
      FilledButton(onPressed: busy ? null : submit, child: busy ? const CircularProgressIndicator() : Text(t('equipment.controlForm.submitBtn'))),
    ]),
  );
}

/// Scanner de QR code équipement — fonctionne entièrement hors-ligne (la
/// caméra décode localement le texte du QR, qui contient l'URL
/// `.../business/equipment/qr/<token>` générée par le tableau de bord web ;
/// seule la RÉSOLUTION du token en fiche équipement a besoin du réseau, avec
/// repli sur le cache local géré par [EquipmentPage.scan]).
class EquipmentQrScannerPage extends StatefulWidget {
  const EquipmentQrScannerPage({super.key});
  @override
  State<EquipmentQrScannerPage> createState() => _EquipmentQrScannerPageState();
}

class _EquipmentQrScannerPageState extends State<EquipmentQrScannerPage> {
  bool handled = false;

  void onDetect(BarcodeCapture capture) {
    if (handled) return;
    final raw = capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
    if (raw == null || raw.isEmpty) return;
    // Le QR encode une URL complète se terminant par le token ; on ne
    // dépend pas du domaine/port encodé (peut différer de l'adresse
    // serveur configurée dans Réglages) — seul le dernier segment compte.
    final segments = raw.split('/').where((s) => s.isNotEmpty).toList();
    final token = segments.isNotEmpty ? segments.last : raw;
    handled = true;
    Navigator.pop(context, token);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text(t('equipment.scanner.title'))),
    body: MobileScanner(onDetect: onDetect),
  );
}
