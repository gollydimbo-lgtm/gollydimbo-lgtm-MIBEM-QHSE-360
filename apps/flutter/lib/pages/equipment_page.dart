import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api.dart';
import '../services/sync_queue.dart';
import '../theme.dart';

// ============================================================================
// ÉQUIPEMENTS — module terrain + gestion (Phase 4B puis extension parité
// web) : consultation hors-ligne du registre (cache local), identification
// par scan QR, déclaration de contrôles réglementaires, et désormais aussi
// tableau de bord, maintenance (plans + interventions), étalonnage des
// instruments de mesure et consignation/cadenassage (LOTO), alignés sur le
// vrai flux du tableau de bord web (voir EquipmentPage/EquipmentDetailModal
// dans apps/web/src/App.jsx).
// ============================================================================

const equipmentEtatLabels = {
  'ACTIF': 'Actif', 'EN_MAINTENANCE': 'En maintenance', 'EN_ATTENTE_REPARATION': 'En attente de réparation',
  'HORS_SERVICE': 'Hors service', 'CONSIGNE': 'Consigné', 'REFORME': 'Réformé', 'MIS_AU_REBUT': 'Mis au rebut', 'REMPLACE': 'Remplacé',
};
const equipmentCriticiteLabels = {'FAIBLE': 'Faible', 'MODERE': 'Modéré', 'ELEVE': 'Élevé', 'CRITIQUE': 'Critique'};
const equipmentControlStatutLabels = {
  'CONFORME': 'Conforme', 'CONFORME_AVEC_OBSERVATIONS': 'Conforme avec observations', 'NON_CONFORME': 'Non conforme',
  'EN_ATTENTE': 'En attente', 'EXPIRE': 'Expiré',
};
const equipmentCalibrationResultatLabels = {
  'CONFORME': 'Conforme', 'CONFORME_AVEC_AJUSTEMENT': 'Conforme avec ajustement', 'NON_CONFORME': 'Non conforme',
};
const equipmentConsignationStatutLabels = {'EN_COURS': 'En cours', 'LEVEE': 'Levée'};
const equipmentMaintenanceFrequenceLabels = {
  'CALENDAIRE': 'Calendaire (jours)', 'HEURES': 'Heures de fonctionnement', 'KM': 'Kilométrage',
  'CYCLES': 'Cycles', 'RECOMMANDATION_FABRICANT': 'Recommandation fabricant', 'RISQUE': 'Basée sur le risque',
};
const equipmentMaintenanceRecordStatutLabels = {
  'PLANIFIEE': 'Planifiée', 'EN_COURS': 'En cours', 'TERMINEE': 'Terminée', 'REPORTEE': 'Reportée',
};

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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Équipement introuvable pour ce code QR (et absent du cache local hors-ligne).')));
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
          const Text('Tableau de bord', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _kpiChip('Disponibilité', dash['tauxDisponibilite'] != null ? '${dash['tauxDisponibilite']}%' : '—', QhseColors.green),
            _kpiChip('Indice conformité', dash['indiceConformite'] != null ? '${dash['indiceConformite']}%' : '—', QhseColors.blue),
            _kpiChip('Échéances en retard', '${dash['enRetard'] ?? 0}', QhseColors.red),
            _kpiChip('Critiques non traités', '${dash['critiquesNonTraites'] ?? 0}', QhseColors.red),
            _kpiChip('Coût maintenance', fmtMoney(dash['coutTotalMaintenance']), QhseColors.amber),
            _kpiChip('Coût étalon. + contrôles', fmtMoney((dash['coutTotalEtalonnage'] ?? 0) + (dash['coutTotalControles'] ?? 0)), QhseColors.amber),
          ]),
          const SizedBox(height: 14),
          const Text('Répartition par état', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: parEtat.entries.map((e) => Chip(
                label: Text('${equipmentEtatLabels[e.key] ?? e.key} : ${e.value}', style: const TextStyle(fontSize: 11)),
                backgroundColor: equipmentEtatColor(e.key).withOpacity(0.15),
              )).toList()),
          const SizedBox(height: 10),
          const Text('Répartition par criticité', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: parCriticite.entries.map((e) => Chip(
                label: Text('${equipmentCriticiteLabels[e.key] ?? e.key} : ${e.value}', style: const TextStyle(fontSize: 11)),
                backgroundColor: equipmentCriticiteColor(e.key).withOpacity(0.15),
              )).toList()),
          if (topCouts.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('Top 5 des coûts de maintenance', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
      appBar: AppBar(title: const Text('Équipements'), actions: [
        if (offline) const Padding(padding: EdgeInsets.only(right: 8), child: Center(child: Chip(label: Text('Hors-ligne'), backgroundColor: Color(0xFFFFE0B2)))),
        if (!offline && dashboard != null)
          IconButton(
            tooltip: 'Tableau de bord',
            icon: Icon(Icons.insights, color: showDashboard ? QhseColors.blue : null),
            onPressed: () => setState(() => showDashboard = !showDashboard),
          ),
      ]),
      // mobile_scanner ne supporte pas Windows/desktop (fédération de
      // plugins) : sur ces plateformes, l'identification se fait par la
      // recherche texte ci-dessus plutôt que par un bouton qui échouerait.
      floatingActionButton: (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)
          ? FloatingActionButton.extended(onPressed: scan, icon: const Icon(Icons.qr_code_scanner), label: const Text('Scanner un QR'))
          : null,
      body: loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
        onRefresh: load,
        child: ListView(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Rechercher un équipement...', border: OutlineInputBorder()),
              onChanged: (v) => setState(() => search = v),
            ),
          ),
          if (showDashboard) Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: _buildDashboard()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
              for (final f in const [['TOUS', 'Tous'], ['EN_RETARD', 'En retard'], ['CRITIQUES', 'Critiques'], ['NON_CONFORMES', 'Non conformes'], ['MAINTENANCE', 'Maintenance'], ['HORS_SERVICE', 'Hors service']])
                Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(f[1]), selected: filter == f[0], onSelected: (_) => setState(() => filter = f[0]))),
            ])),
          ),
          const SizedBox(height: 8),
          if (list.isEmpty)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Aucun équipement pour ce filtre')))
          else
            ...list.map((e) {
              final overdue = equipmentIsOverdue(e);
              final cat = categoryLabel(e);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Card(child: ListTile(
                  leading: Icon(Icons.precision_manufacturing, color: overdue ? QhseColors.red : equipmentEtatColor(e['etat'])),
                  title: Text('${e['code']} — ${e['name']}'),
                  subtitle: Text('${cat != null ? '$cat • ' : ''}${e['site']?['name'] ?? 'Site non renseigné'} • ${equipmentEtatLabels[e['etat']] ?? e['etat']}'),
                  trailing: overdue ? const Chip(label: Text('En retard'), backgroundColor: Color(0xFFFFCDD2)) : (e['criticiteNiveau'] == 'CRITIQUE' ? Chip(label: const Text('Critique'), backgroundColor: equipmentCriticiteColor('CRITIQUE').withOpacity(0.2)) : null),
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
          tabs: const [
            Tab(text: 'Identification'),
            Tab(text: 'Maintenance'),
            Tab(text: 'Contrôles'),
            Tab(text: 'Étalonnage'),
            Tab(text: 'Consignation'),
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
        Chip(label: Text(equipmentEtatLabels[e['etat']] ?? '${e['etat']}'), backgroundColor: equipmentEtatColor(e['etat']).withOpacity(0.15), labelStyle: TextStyle(color: equipmentEtatColor(e['etat']))),
        if (e['criticiteNiveau'] != null) Chip(label: Text('Criticité ${equipmentCriticiteLabels[e['criticiteNiveau']] ?? e['criticiteNiveau']}'), backgroundColor: equipmentCriticiteColor(e['criticiteNiveau']).withOpacity(0.15), labelStyle: TextStyle(color: equipmentCriticiteColor(e['criticiteNiveau']))),
        if (next != null) Chip(label: Text('Prochaine échéance ${fmtDate(next.toIso8601String())}'), backgroundColor: (next.isBefore(DateTime.now()) ? QhseColors.red : QhseColors.blue).withOpacity(0.15)),
      ]),
      const SizedBox(height: 16),
      Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Identification', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _row('Catégorie', e['categoryEq']?['label'] ?? e['category']),
        _row('Type', [e['type'], e['sousType']].where((x) => x != null && '$x'.isNotEmpty).join(' / ')),
        _row('Site', e['site']?['name']),
        _row('Service / unité', e['workUnit']?['name']),
        _row('Marque / modèle', [e['marque'], e['modele']].where((x) => x != null && '$x'.isNotEmpty).join(' ')),
        _row('N° de série', e['numeroSerie']),
        _row('Année de fabrication', e['anneeFabrication']),
        _row('Responsable', e['responsable'] != null ? '${e['responsable']['firstName']} ${e['responsable']['lastName']}' : null),
        _row('Bâtiment / zone', [e['batiment'], e['zone']].where((x) => x != null && '$x'.isNotEmpty).join(' / ')),
      ]))),
      if (e['criticiteSecurite'] != null || e['criticiteQualite'] != null || e['criticiteEnvironnement'] != null || e['criticiteProduction'] != null) ...[
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Criticité par axe', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(spacing: 16, children: [
            Text('Sécurité : ${e['criticiteSecurite'] ?? '—'}'),
            Text('Qualité : ${e['criticiteQualite'] ?? '—'}'),
            Text('Environnement : ${e['criticiteEnvironnement'] ?? '—'}'),
            Text('Production : ${e['criticiteProduction'] ?? '—'}'),
          ]),
        ]))),
      ],
      if (e['notes'] != null && '${e['notes']}'.trim().isNotEmpty) ...[
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Notes', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('${e['notes']}'),
        ]))),
      ],
      const SizedBox(height: 12),
      _sectionTitle('Non-conformités liées (${nonConformities.length})'),
      if (nonConformities.isEmpty) _emptyHint('Aucune non-conformité liée')
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

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() => loading = true);
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
    } catch (_) {}
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
        title: const Text('Nouveau plan de maintenance'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: designationCtrl, decoration: const InputDecoration(labelText: 'Désignation')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: frequenceType,
            decoration: const InputDecoration(labelText: 'Type de fréquence'),
            items: equipmentMaintenanceFrequenceLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (v) => setD(() => frequenceType = v ?? frequenceType),
          ),
          const SizedBox(height: 12),
          TextField(controller: valeurCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Valeur')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: responsableId,
            decoration: const InputDecoration(labelText: 'Responsable (optionnel)'),
            items: [const DropdownMenuItem(value: null, child: Text('—')), ...users.map((u) => DropdownMenuItem(value: u['id'].toString(), child: Text('${u['firstName']} ${u['lastName']}')))],
            onChanged: (v) => setD(() => responsableId = v),
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.of(dctx).pop(false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.of(dctx).pop(true), child: const Text('Créer')),
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
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
        title: const Text('Nouvelle intervention'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            value: type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: const [DropdownMenuItem(value: 'CORRECTIVE', child: Text('Corrective (panne)')), DropdownMenuItem(value: 'PREVENTIVE', child: Text('Préventive'))],
            onChanged: (v) => setD(() => type = v ?? type),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: statut,
            decoration: const InputDecoration(labelText: 'Statut'),
            items: equipmentMaintenanceRecordStatutLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (v) => setD(() => statut = v ?? statut),
          ),
          if (type == 'PREVENTIVE') ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: planId,
              decoration: const InputDecoration(labelText: 'Plan lié (optionnel)'),
              items: [const DropdownMenuItem(value: null, child: Text('—')), ...plans.map((p) => DropdownMenuItem(value: p['id'].toString(), child: Text(p['designation'] ?? '')))],
              onChanged: (v) => setD(() => planId = v),
            ),
          ],
          if (type == 'CORRECTIVE') ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: () async { final d = await pick(dctx); if (d != null) setD(() => datePanne = d); }, child: Text(datePanne == null ? 'Date de panne' : fmtDate(datePanne!.toIso8601String()))),
          ],
          const SizedBox(height: 12),
          OutlinedButton(onPressed: () async { final d = await pick(dctx); if (d != null) setD(() => dateDebut = d); }, child: Text(dateDebut == null ? "Début d'intervention" : fmtDate(dateDebut!.toIso8601String()))),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: () async { final d = await pick(dctx); if (d != null) setD(() => dateFin = d); }, child: Text(dateFin == null ? "Fin d'intervention" : fmtDate(dateFin!.toIso8601String()))),
          const SizedBox(height: 12),
          TextField(controller: dureeCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Durée (heures, optionnel)')),
          const SizedBox(height: 12),
          TextField(controller: coutCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Coût (optionnel)')),
          if (type == 'CORRECTIVE') ...[
            const SizedBox(height: 12),
            TextField(controller: causeCtrl, decoration: const InputDecoration(labelText: 'Cause de la panne (optionnel)')),
          ],
          const SizedBox(height: 12),
          TextField(controller: descriptionCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Description (optionnel)')),
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final s = stats;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        if (s != null) Wrap(spacing: 8, runSpacing: 8, children: [
          Chip(label: Text('Pannes : ${s['nombrePannes'] ?? 0}')),
          Chip(label: Text('MTBF (h) : ${s['mtbfHeures'] != null ? (s['mtbfHeures'] as num).round() : '—'}')),
          Chip(label: Text('MTTR (h) : ${s['mttrHeures'] != null ? (s['mttrHeures'] as num).round() : '—'}')),
          Chip(label: Text('Disponibilité : ${s['disponibilite'] != null ? '${((s['disponibilite'] as num) * 100).round()}%' : '—'}')),
        ]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Plans de maintenance préventive', style: TextStyle(fontWeight: FontWeight.bold)),
          TextButton.icon(onPressed: newPlan, icon: const Icon(Icons.add, size: 18), label: const Text('Nouveau plan')),
        ]),
        if (plans.isEmpty) _emptyHint('Aucun plan de maintenance préventive')
        else ...plans.map((p) => Card(child: ListTile(
              title: Text(p['designation'] ?? ''),
              subtitle: Text('${p['frequenceValeur']} (${equipmentMaintenanceFrequenceLabels[p['frequenceType']] ?? p['frequenceType']}) • Prochaine : ${fmtDate(p['dateProchaine'])}'),
            ))),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Interventions', style: TextStyle(fontWeight: FontWeight.bold)),
          TextButton.icon(onPressed: newRecord, icon: const Icon(Icons.add, size: 18), label: const Text('Nouvelle intervention')),
        ]),
        if (records.isEmpty) _emptyHint('Aucune intervention enregistrée')
        else ...records.map((r) => Card(child: ListTile(
              title: Text(r['type'] == 'PREVENTIVE' ? 'Préventive' : 'Corrective'),
              subtitle: Text('${equipmentMaintenanceRecordStatutLabels[r['statut']] ?? r['statut']} • ${fmtDate(r['datePanne'] ?? r['dateDebut'])}${r['dureeHeures'] != null ? ' • ${r['dureeHeures']} h' : ''}${r['cout'] != null ? ' • ${fmtMoney(r['cout'])}' : ''}'),
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
  String? genId;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() => loading = true);
    try { controls = List.from(await api.get('/business/equipment-controls?equipmentId=${widget.equipmentId}')); } catch (_) {}
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
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e'))); }
    setState(() => genId = null);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Contrôles réglementaires', style: TextStyle(fontWeight: FontWeight.bold)),
          TextButton.icon(onPressed: newControl, icon: const Icon(Icons.add, size: 18), label: const Text('Nouveau')),
        ]),
        if (controls.isEmpty) _emptyHint('Aucun contrôle réglementaire enregistré')
        else ...controls.map((ctl) => Card(child: ListTile(
              leading: Icon(Icons.fact_check, color: ctl['statut'] == 'NON_CONFORME' ? QhseColors.red : QhseColors.green),
              title: Text(ctl['designation'] ?? ''),
              subtitle: Text('${equipmentControlStatutLabels[ctl['statut']] ?? ctl['statut']} • ${fmtDate(ctl['dateControle'])}${ctl['dateProchainControle'] != null ? ' • prochain : ${fmtDate(ctl['dateProchainControle'])}' : ''}'),
              trailing: (ctl['statut'] == 'NON_CONFORME' && ctl['nonConformityId'] == null)
                  ? TextButton(onPressed: genId == ctl['id'] ? null : () => generateNc(ctl['id'].toString()), child: Text(genId == ctl['id'] ? '…' : 'Générer une NC'))
                  : (ctl['nonConformityId'] != null ? const Text('NC créée', style: TextStyle(fontSize: 11)) : null),
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
  String? genId;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() => loading = true);
    try { calibrations = List.from(await api.get('/business/equipment-calibrations?equipmentId=${widget.equipmentId}')); } catch (_) {}
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
        title: const Text('Nouvel étalonnage'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          OutlinedButton(
            onPressed: () async {
              final d = await showDatePicker(context: dctx, initialDate: dateEtalonnage, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 3650)));
              if (d != null) setD(() => dateEtalonnage = d);
            },
            child: Text('Date d\'étalonnage : ${fmtDate(dateEtalonnage.toIso8601String())}'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () async {
              final d = await showDatePicker(context: dctx, initialDate: dateProchaineEtalonnage ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 3650)));
              if (d != null) setD(() => dateProchaineEtalonnage = d);
            },
            child: Text(dateProchaineEtalonnage == null ? 'Prochain étalonnage (optionnel)' : fmtDate(dateProchaineEtalonnage!.toIso8601String())),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: resultat,
            decoration: const InputDecoration(labelText: 'Résultat'),
            items: equipmentCalibrationResultatLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (v) => setD(() => resultat = v ?? resultat),
          ),
          const SizedBox(height: 12),
          TextField(controller: organismeCtrl, decoration: const InputDecoration(labelText: 'Organisme étalonneur (optionnel)')),
          const SizedBox(height: 12),
          TextField(controller: certificatCtrl, decoration: const InputDecoration(labelText: 'N° certificat (optionnel)')),
          const SizedBox(height: 12),
          TextField(controller: incertitudeCtrl, decoration: const InputDecoration(labelText: 'Incertitude (optionnel)')),
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  Future<void> generateNc(String id) async {
    setState(() => genId = id);
    try { await api.post('/business/equipment-calibrations/$id/generate-nc', {}); await reload(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e'))); }
    setState(() => genId = null);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Étalonnage des instruments de mesure', style: TextStyle(fontWeight: FontWeight.bold)),
          TextButton.icon(onPressed: newCalibration, icon: const Icon(Icons.add, size: 18), label: const Text('Nouvel étalonnage')),
        ]),
        if (calibrations.isEmpty) _emptyHint('Aucun étalonnage enregistré')
        else ...calibrations.map((cal) => Card(child: ListTile(
              leading: Icon(Icons.rule, color: equipmentCalibrationResultatColor(cal['resultat'])),
              title: Text('${equipmentCalibrationResultatLabels[cal['resultat']] ?? cal['resultat']}'),
              subtitle: Text('${fmtDate(cal['dateEtalonnage'])} → prochain : ${fmtDate(cal['dateProchaineEtalonnage'])}${cal['nePasUtiliser'] == true ? ' • NE PAS UTILISER' : ''}'),
              trailing: (cal['resultat'] != 'CONFORME' && cal['nonConformityId'] == null)
                  ? TextButton(onPressed: genId == cal['id'] ? null : () => generateNc(cal['id'].toString()), child: Text(genId == cal['id'] ? '…' : 'Générer une NC'))
                  : (cal['nonConformityId'] != null ? const Text('NC créée', style: TextStyle(fontSize: 11)) : null),
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
  String? busyId;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final results = await Future.wait([
        api.get('/business/equipment-consignations?equipmentId=${widget.equipmentId}'),
        api.get('/users'),
      ]);
      consignations = List.from(results[0]);
      users = List.from(results[1]);
    } catch (_) {}
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
        title: const Text('Nouvelle consignation'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: motifCtrl, decoration: const InputDecoration(labelText: 'Motif')),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () async {
              final d = await showDatePicker(context: dctx, initialDate: dateFinPrevue ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 3650)));
              if (d != null) setD(() => dateFinPrevue = d);
            },
            child: Text(dateFinPrevue == null ? 'Fin prévue (optionnel)' : fmtDate(dateFinPrevue!.toIso8601String())),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: responsableId,
            decoration: const InputDecoration(labelText: 'Responsable (optionnel)'),
            items: [const DropdownMenuItem(value: null, child: Text('—')), ...users.map((u) => DropdownMenuItem(value: u['id'].toString(), child: Text('${u['firstName']} ${u['lastName']}')))],
            onChanged: (v) => setD(() => responsableId = v),
          ),
          const SizedBox(height: 12),
          TextField(controller: risqueCtrl, decoration: const InputDecoration(labelText: 'Risque associé (optionnel)')),
          const SizedBox(height: 12),
          TextField(controller: mesureCtrl, decoration: const InputDecoration(labelText: 'Mesure de maîtrise (optionnel)')),
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  Future<void> lever(String id) async {
    setState(() => busyId = id);
    try { await api.post('/business/equipment-consignations/$id/lever', {}); await reload(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e'))); }
    setState(() => busyId = null);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Tant qu\'une consignation est en cours, l\'équipement passe à l\'état Consigné', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Consignation / cadenassage (LOTO)', style: TextStyle(fontWeight: FontWeight.bold)),
          TextButton.icon(onPressed: newConsignation, icon: const Icon(Icons.add, size: 18), label: const Text('Nouvelle')),
        ]),
        if (consignations.isEmpty) _emptyHint('Aucune consignation enregistrée')
        else ...consignations.map((c) => Card(child: ListTile(
              leading: Icon(Icons.lock, color: equipmentConsignationStatutColor(c['statut'])),
              title: Text(c['motif'] ?? ''),
              subtitle: Text('${fmtDate(c['dateDebut'])} → ${fmtDate(c['dateFinPrevue'])} • ${equipmentConsignationStatutLabels[c['statut']] ?? c['statut']}'),
              trailing: c['statut'] == 'EN_COURS'
                  ? TextButton(onPressed: busyId == c['id'] ? null : () => lever(c['id'].toString()), child: Text(busyId == c['id'] ? '…' : 'Lever'))
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La désignation du contrôle est obligatoire')));
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pas de réseau : contrôle enregistré hors-ligne, il sera synchronisé automatiquement.'), duration: Duration(seconds: 4)));
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
    appBar: AppBar(title: const Text('Nouveau contrôle terrain')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      TextField(controller: designation, decoration: const InputDecoration(labelText: 'Désignation *', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: organisme, decoration: const InputDecoration(labelText: 'Organisme (optionnel)', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: referenceReglementaire, decoration: const InputDecoration(labelText: 'Référence réglementaire (optionnel)', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: () => pickDate(false), icon: const Icon(Icons.event), label: Text('Contrôle : ${fmtDate(dateControle.toIso8601String())}'))),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton.icon(onPressed: () => pickDate(true), icon: const Icon(Icons.event_repeat), label: Text(dateProchainControle == null ? 'Prochain (optionnel)' : fmtDate(dateProchainControle!.toIso8601String())))),
      ]),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: statut,
        decoration: const InputDecoration(labelText: 'Statut', border: OutlineInputBorder()),
        items: equipmentControlStatutLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
        onChanged: (v) => setState(() => statut = v ?? statut),
      ),
      const SizedBox(height: 12),
      TextField(controller: observations, maxLines: 3, decoration: const InputDecoration(labelText: 'Observations (optionnel)', border: OutlineInputBorder())),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
      const SizedBox(height: 20),
      FilledButton(onPressed: busy ? null : submit, child: busy ? const CircularProgressIndicator() : const Text('Enregistrer le contrôle')),
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
    appBar: AppBar(title: const Text('Scanner le QR de l\'équipement')),
    body: MobileScanner(onDetect: onDetect),
  );
}
