import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api.dart';
import '../services/sync_queue.dart';
import '../theme.dart';

// ============================================================================
// ÉQUIPEMENTS — module terrain (Phase 4B) : consultation hors-ligne du
// registre (mise en cache locale), identification par scan QR, et
// déclaration de contrôles réglementaires sur le terrain, synchronisée
// automatiquement dès le retour du réseau via SyncQueue (voir sync_queue.dart
// et POST /sync/push côté serveur). La création/modification complète d'un
// équipement (identification détaillée, criticité, plans de maintenance...)
// reste réservée au tableau de bord web — ce module mobile est pensé pour le
// geste terrain rapide, pas la gestion de la fiche équipement.
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

Color equipmentEtatColor(String? etat) => {
      'ACTIF': QhseColors.green, 'EN_MAINTENANCE': QhseColors.blue, 'EN_ATTENTE_REPARATION': QhseColors.amber,
      'HORS_SERVICE': QhseColors.red, 'CONSIGNE': QhseColors.red, 'REFORME': QhseColors.textSecondary, 'MIS_AU_REBUT': QhseColors.textSecondary,
    }[etat] ?? QhseColors.textSecondary;

Color equipmentCriticiteColor(String? n) => {
      'CRITIQUE': QhseColors.red, 'ELEVE': QhseColors.amber, 'MODERE': const Color(0xFFB45309), 'FAIBLE': QhseColors.green,
    }[n] ?? QhseColors.textSecondary;

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
String fmtDate(dynamic v) => v == null ? '—' : DateTime.parse(v).toIso8601String().substring(0, 10);

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
  bool loading = true;
  bool offline = false;
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
    else if (filter == 'NON_CONFORMES') list = list.where((e) => List.from(e['nonConformities'] ?? []).any((n) => n['status'] != 'CLOSED')).toList();
    if (search.trim().isNotEmpty) {
      final q = search.trim().toLowerCase();
      list = list.where((e) => '${e['code']} ${e['name']}'.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext c) {
    final list = filtered;
    return Scaffold(
      appBar: AppBar(title: const Text('Équipements'), actions: [
        if (offline) const Padding(padding: EdgeInsets.only(right: 12), child: Center(child: Chip(label: Text('Hors-ligne'), backgroundColor: Color(0xFFFFE0B2)))),
      ]),
      // mobile_scanner ne supporte pas Windows/desktop (fédération de
      // plugins) : sur ces plateformes, l'identification se fait par la
      // recherche texte ci-dessus plutôt que par un bouton qui échouerait.
      floatingActionButton: (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)
          ? FloatingActionButton.extended(onPressed: scan, icon: const Icon(Icons.qr_code_scanner), label: const Text('Scanner un QR'))
          : null,
      body: loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
        onRefresh: load,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Rechercher un équipement...', border: OutlineInputBorder()),
              onChanged: (v) => setState(() => search = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
              for (final f in const [['TOUS', 'Tous'], ['EN_RETARD', 'En retard'], ['CRITIQUES', 'Critiques'], ['NON_CONFORMES', 'Non conformes']])
                Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(f[1]), selected: filter == f[0], onSelected: (_) => setState(() => filter = f[0]))),
            ])),
          ),
          Expanded(
            child: list.isEmpty
                ? ListView(children: const [Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Aucun équipement pour ce filtre')))])
                : ListView.builder(padding: const EdgeInsets.all(12), itemCount: list.length, itemBuilder: (_, i) {
                    final e = list[i];
                    final overdue = equipmentIsOverdue(e);
                    return Card(child: ListTile(
                      leading: Icon(Icons.precision_manufacturing, color: overdue ? QhseColors.red : equipmentEtatColor(e['etat'])),
                      title: Text('${e['code']} — ${e['name']}'),
                      subtitle: Text('${e['site']?['name'] ?? 'Site non renseigné'} • ${equipmentEtatLabels[e['etat']] ?? e['etat']}'),
                      trailing: overdue ? const Chip(label: Text('En retard'), backgroundColor: Color(0xFFFFCDD2)) : (e['criticiteNiveau'] == 'CRITIQUE' ? Chip(label: const Text('Critique'), backgroundColor: equipmentCriticiteColor('CRITIQUE').withOpacity(0.2)) : null),
                      onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => EquipmentDetailPage(equipment: Map.from(e), onChanged: load))),
                    ));
                  }),
          ),
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

class _EquipmentDetailPageState extends State<EquipmentDetailPage> {
  final api = Api();
  late Map e = widget.equipment;
  bool refreshing = false;

  Future<void> refresh() async {
    setState(() => refreshing = true);
    try { e = Map.from(await api.get('/business/equipment/${e['id']}')); } catch (_) { /* reste sur les données déjà connues (hors-ligne) */ }
    setState(() => refreshing = false);
    widget.onChanged();
  }

  Future<void> newControl() async {
    final saved = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => EquipmentControlFormPage(equipmentId: e['id'])));
    if (saved == true) refresh();
  }

  @override
  Widget build(BuildContext c) {
    final controls = List.from(e['controls'] ?? []);
    final maintenancePlans = List.from(e['maintenancePlans'] ?? []);
    final calibrations = List.from(e['calibrations'] ?? []);
    final nonConformities = List.from(e['nonConformities'] ?? []);
    final next = equipmentNextDueDate(e);
    return Scaffold(
      appBar: AppBar(title: Text('${e['code']}'), actions: [IconButton(onPressed: refreshing ? null : refresh, icon: const Icon(Icons.refresh))]),
      floatingActionButton: FloatingActionButton.extended(onPressed: newControl, icon: const Icon(Icons.fact_check), label: const Text('Nouveau contrôle')),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(padding: const EdgeInsets.all(16), children: [
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
            _row('Site', e['site']?['name']),
            _row('Service / unité', e['workUnit']?['name']),
            _row('Marque / modèle', [e['marque'], e['modele']].where((x) => x != null && '$x'.isNotEmpty).join(' ')),
            _row('N° de série', e['numeroSerie']),
            _row('Responsable', e['responsable'] != null ? '${e['responsable']['firstName']} ${e['responsable']['lastName']}' : null),
            _row('Bâtiment / zone', [e['batiment'], e['zone']].where((x) => x != null && '$x'.isNotEmpty).join(' / ')),
          ]))),
          const SizedBox(height: 12),
          _sectionTitle('Plans de maintenance actifs (${maintenancePlans.length})'),
          if (maintenancePlans.isEmpty) _empty('Aucun plan de maintenance actif')
          else ...maintenancePlans.map((p) => Card(child: ListTile(title: Text(p['designation'] ?? p['type'] ?? 'Maintenance'), subtitle: Text('Prochaine échéance : ${fmtDate(p['dateProchaine'])}')))),
          const SizedBox(height: 12),
          _sectionTitle('Contrôles réglementaires (${controls.length})'),
          if (controls.isEmpty) _empty('Aucun contrôle enregistré')
          else ...controls.map((ctl) => Card(child: ListTile(
                leading: Icon(Icons.fact_check, color: ctl['statut'] == 'NON_CONFORME' ? QhseColors.red : QhseColors.green),
                title: Text(ctl['designation'] ?? ''),
                subtitle: Text('${equipmentControlStatutLabels[ctl['statut']] ?? ctl['statut']} • ${fmtDate(ctl['dateControle'])}${ctl['dateProchainControle'] != null ? ' • prochain : ${fmtDate(ctl['dateProchainControle'])}' : ''}'),
              ))),
          const SizedBox(height: 12),
          _sectionTitle('Étalonnages (${calibrations.length})'),
          if (calibrations.isEmpty) _empty('Aucun étalonnage enregistré')
          else ...calibrations.map((cal) => Card(child: ListTile(title: Text(cal['instrument'] ?? 'Étalonnage'), subtitle: Text('Prochain : ${fmtDate(cal['dateProchaineEtalonnage'])}')))),
          const SizedBox(height: 12),
          _sectionTitle('Non-conformités liées (${nonConformities.length})'),
          if (nonConformities.isEmpty) _empty('Aucune non-conformité liée')
          else ...nonConformities.map((n) => Card(child: ListTile(leading: const Icon(Icons.report, color: Colors.red), title: Text(n['title'] ?? ''), subtitle: Text('${n['code']} • ${n['status']}')))),
        ]),
      ),
    );
  }

  Widget _row(String label, dynamic value) {
    final v = (value == null || '$value'.trim().isEmpty) ? '—' : '$value';
    return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [
      SizedBox(width: 140, child: Text(label, style: TextStyle(color: QhseColors.textSecondary, fontSize: 12))),
      Expanded(child: Text(v)),
    ]));
  }
  Widget _sectionTitle(String t) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold)));
  Widget _empty(String t) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(t, style: TextStyle(color: QhseColors.textSecondary)));
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
