import 'package:flutter/material.dart';
import '../services/api.dart';
import '../theme.dart';
import 'attachment_helpers.dart';
import 'haccp_study_detail_page.dart';
import 'haccp_monitoring_form_page.dart';
import 'load_error_view.dart';
import '../services/sync_queue.dart';

// Libellés partagés par tout le module HACCP (page, fiche étude, fiche CCP,
// formulaire de relevé) — centralisés ici pour éviter les divergences entre
// écrans.
const haccpStudyStatusLabels = {
  'BROUILLON': 'Brouillon',
  'EN_VALIDATION': 'En validation',
  'VALIDE': 'Validé',
  'SUSPENDU': 'Suspendu',
  'ARCHIVE': 'Archivé',
};

Color haccpStudyStatusColor(String? s) => {
      'BROUILLON': QhseColors.blue,
      'EN_VALIDATION': QhseColors.amber,
      'VALIDE': QhseColors.green,
      'SUSPENDU': QhseColors.red,
      'ARCHIVE': QhseColors.textSecondary,
    }[s] ??
    QhseColors.textSecondary;

const haccpNiveauRisqueLabels = {
  'FAIBLE': 'Faible',
  'MODERE': 'Modéré',
  'SIGNIFICATIF': 'Significatif',
  'CRITIQUE': 'Critique',
};

Color haccpNiveauRisqueColor(String? n) => {
      'FAIBLE': QhseColors.green,
      'MODERE': QhseColors.blue,
      'SIGNIFICATIF': QhseColors.amber,
      'CRITIQUE': QhseColors.red,
    }[n] ??
    QhseColors.textSecondary;

const haccpMonitoringStatutLabels = {
  'A_REALISER': 'À réaliser',
  'EN_RETARD': 'En retard',
  'REALISE': 'Réalisé',
  'CONFORME': 'Conforme',
  'NON_CONFORME': 'Non conforme',
  'ANNULE': 'Annulé',
  'JUSTIFIE': 'Justifié',
};

Color haccpMonitoringStatutColor(String? s) => {
      'A_REALISER': QhseColors.blue,
      'EN_RETARD': QhseColors.red,
      'REALISE': QhseColors.blue,
      'CONFORME': QhseColors.green,
      'NON_CONFORME': QhseColors.red,
      'ANNULE': QhseColors.textSecondary,
      'JUSTIFIE': QhseColors.amber,
    }[s] ??
    QhseColors.textSecondary;

Widget haccpChip(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );

String haccpFmtDate(dynamic v) => v == null ? '—' : '$v'.substring(0, 10);
String haccpFmtDateTime(dynamic v) => v == null ? '—' : '$v'.replaceFirst('T', ' ').substring(0, 16);

/// Page principale du module HACCP. Reconstruite en page à onglets pour
/// mettre en avant, dès l'ouverture, l'écran terrain le plus important du
/// module : les contrôles CCP du jour et en retard (onglet "Vue d'ensemble").
/// Nom de classe conservé (référencé depuis main.dart).
class HaccpPage extends StatefulWidget {
  const HaccpPage({super.key});
  @override
  State<HaccpPage> createState() => _HaccpPageState();
}

class _HaccpPageState extends State<HaccpPage> {
  @override
  Widget build(BuildContext c) => DefaultTabController(
    length: 4,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('HACCP'),
        bottom: const TabBar(tabs: [
          Tab(text: "Vue d'ensemble"), Tab(text: 'Études'), Tab(text: 'PRP'), Tab(text: 'Matrice'),
        ]),
      ),
      body: const TabBarView(children: [_OverviewTab(), _StudiesTab(), _PrpTab(), _MatrixTab()]),
    ),
  );
}

// --- Onglet 1 : Vue d'ensemble — KPI puis, mis en avant en priorité, les
// contrôles CCP du jour et en retard : c'est le geste terrain quotidien le
// plus important du module. ---
class _OverviewTab extends StatefulWidget {
  const _OverviewTab();
  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  final api = Api();
  Map dash = {};
  List today = [], overdue = [];
  bool loading = true;
  Object? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      dash = Map.from(await api.get('/haccp/dashboard'));
      today = List.from(await api.get('/haccp/monitoring/today'));
      overdue = List.from(await api.get('/haccp/monitoring/overdue'));
    } catch (e) { error = e; }
    setState(() => loading = false);
  }

  Future<void> openRecord(Map record) async {
    final ccp = record['ccp'] is Map ? Map.from(record['ccp']) : null;
    if (ccp == null) return;
    final result = await Navigator.push(context, MaterialPageRoute(
      builder: (_) => HaccpMonitoringFormPage(ccp: ccp, existing: record),
    ));
    if (result != null) load();
  }

  Widget _recordTile(Map m, {required bool late_}) {
    final ccp = m['ccp'] is Map ? Map.from(m['ccp']) : {};
    return Card(
      child: ListTile(
        leading: Icon(late_ ? Icons.timer_off_outlined : Icons.event_available, color: late_ ? QhseColors.red : QhseColors.blue),
        title: Text('${ccp['reference'] ?? '—'} — ${ccp['dangerMaitrise'] ?? ccp['parametre'] ?? ''}'),
        subtitle: Text('Prévu le ${haccpFmtDateTime(m['datePrevue'])}${ccp['limiteCritique'] != null ? ' · limite : ${ccp['limiteCritique']}' : ''}'),
        trailing: FilledButton(onPressed: () => openRecord(m), child: const Text('Saisir')),
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return LoadErrorView(error: error, onRetry: load);
    int n(String k) => dash[k] is num ? (dash[k] as num).toInt() : 0;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(padding: const EdgeInsets.symmetric(vertical: 12), children: [
        KpiBar([
          KpiStat('Études validées', '${n('etudesActives')}/${n('etudesTotal')}', color: QhseColors.blue, icon: Icons.fact_check_outlined),
          KpiStat('CCP actifs', '${n('ccp')}', color: QhseColors.red, icon: Icons.gpp_maybe_outlined),
          KpiStat('CP actifs', '${n('cp')}', color: QhseColors.blue, icon: Icons.shield_outlined),
          KpiStat('CCP en anomalie', '${n('ccpEnAnomalie')}', color: n('ccpEnAnomalie') > 0 ? QhseColors.red : QhseColors.green, icon: Icons.warning_amber_outlined),
          KpiStat('Taux de réalisation', '${dash['tauxRealisation'] ?? 0}%', color: QhseColors.green, icon: Icons.trending_up),
          KpiStat('Taux de conformité', '${dash['tauxConformite'] ?? 0}%', color: QhseColors.green, icon: Icons.verified_outlined),
          KpiStat('Contrôles non conformes', '${n('controlesNonConformes')}', color: n('controlesNonConformes') > 0 ? QhseColors.red : QhseColors.green, icon: Icons.report_gmailerrorred),
          KpiStat('Contrôles en retard', '${n('controlesEnRetard')}', color: n('controlesEnRetard') > 0 ? QhseColors.red : QhseColors.green, icon: Icons.hourglass_bottom),
          KpiStat('NC ouvertes', '${n('ncOuvertes')}', color: n('ncOuvertes') > 0 ? QhseColors.red : QhseColors.green, icon: Icons.error_outline),
          KpiStat('Actions ouvertes', '${n('actionsOuvertes')}', color: QhseColors.blue, icon: Icons.playlist_add_check),
          KpiStat('Actions en retard', '${n('actionsEnRetard')}', color: n('actionsEnRetard') > 0 ? QhseColors.red : QhseColors.green, icon: Icons.timer_off_outlined),
          KpiStat('Dangers identifiés', '${n('dangers')}', color: QhseColors.amber, icon: Icons.bug_report_outlined),
        ]),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('Contrôles en retard (${overdue.length})', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: overdue.isNotEmpty ? QhseColors.red : null)),
        ),
        const SizedBox(height: 6),
        if (overdue.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), child: Text('Aucun contrôle en retard', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
        else
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Column(children: overdue.map((m) => _recordTile(m, late_: true)).toList())),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('Contrôles du jour (${today.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        const SizedBox(height: 6),
        if (today.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), child: Text('Aucun contrôle prévu aujourd\'hui', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
        else
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Column(children: today.map((m) => _recordTile(m, late_: false)).toList())),
      ]),
    );
  }
}

// --- Onglet 2 : Études HACCP — liste + création (la configuration complète
// se fait ensuite dans la fiche détail, au bureau). ---
class _StudiesTab extends StatefulWidget {
  const _StudiesTab();
  @override
  State<_StudiesTab> createState() => _StudiesTabState();
}

class _StudiesTabState extends State<_StudiesTab> {
  final api = Api();
  List studies = [];
  List users = [];
  bool loading = true;
  Object? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      studies = List.from(await api.get('/haccp/studies'));
      users = List.from(await api.get('/users'));
    } catch (e) { error = e; }
    setState(() => loading = false);
  }

  String userName(String? id) {
    if (id == null) return '—';
    final u = users.firstWhere((x) => x['id'] == id, orElse: () => null);
    return u == null ? '—' : '${u['firstName']} ${u['lastName']}';
  }

  Future<void> create() async {
    final name = TextEditingController();
    final code = TextEditingController(text: genCode('HACCP'));
    final produit = TextEditingController();
    final activite = TextEditingController();
    String? responsableId;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dc) => StatefulBuilder(builder: (dc, setD) => AlertDialog(
        title: const Text('Nouvelle étude HACCP'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Nom de l\'étude *')),
          const SizedBox(height: 10),
          TextField(controller: code, decoration: const InputDecoration(labelText: 'Code')),
          const SizedBox(height: 10),
          TextField(controller: produit, decoration: const InputDecoration(labelText: 'Produit concerné')),
          const SizedBox(height: 10),
          TextField(controller: activite, decoration: const InputDecoration(labelText: 'Activité / ligne')),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            isExpanded: true, decoration: const InputDecoration(labelText: 'Responsable'), value: responsableId,
            items: [const DropdownMenuItem<String>(value: null, child: Text('—')), ...users.map<DropdownMenuItem<String>>((u) => DropdownMenuItem<String>(value: u['id'] as String, child: Text('${u['firstName']} ${u['lastName']}')))],
            onChanged: (v) => setD(() => responsableId = v),
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dc, false), child: const Text('Annuler')),
          FilledButton(onPressed: name.text.trim().isEmpty ? null : () => Navigator.pop(dc, true), child: const Text('Créer')),
        ],
      )),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    final payload = {
      'code': code.text.trim().isEmpty ? genCode('HACCP') : code.text.trim(),
      'name': name.text.trim(),
      'produit': produit.text.trim().isEmpty ? null : produit.text.trim(),
      'activite': activite.text.trim().isEmpty ? null : activite.text.trim(),
      'responsableId': responsableId,
    };
    try {
      final created = Map.from(await api.post('/haccp/studies', payload));
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => HaccpStudyDetailPage(studyId: created['id']))).then((_) => load());
      }
    } on ApiException catch (e) {
      if (e.networkError) {
        await SyncQueue.enqueue('haccpStudy', 'CREATE', payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pas de réseau : étude HACCP enregistrée hors-ligne, elle sera synchronisée automatiquement.'), duration: Duration(seconds: 4)));
          load();
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
            ? LoadErrorView(error: error, onRetry: load)
        : RefreshIndicator(
            onRefresh: load,
            child: studies.isEmpty
                ? ListView(children: const [Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Aucune étude HACCP')))])
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                    itemCount: studies.length,
                    itemBuilder: (_, i) {
                      final s = studies[i];
                      return Card(
                        child: ListTile(
                          title: Text('${s['code'] ?? ''} — ${s['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${s['produit'] ?? ''}${s['produit'] != null && s['responsableId'] != null ? ' · ' : ''}${userName(s['responsableId'])} · v${s['version'] ?? '1.0'}'),
                          trailing: haccpChip(haccpStudyStatusLabels[s['status']] ?? '${s['status']}', haccpStudyStatusColor(s['status'])),
                          onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => HaccpStudyDetailPage(studyId: s['id']))).then((_) => load()),
                        ),
                      );
                    },
                  ),
          ),
    floatingActionButton: FloatingActionButton.extended(onPressed: create, icon: const Icon(Icons.add), label: const Text('Nouvelle étude')),
  );
}

// --- Onglet 3 : PRP — programmes prérequis / bonnes pratiques d'hygiène ---
const _prpTypeLabels = {
  'NETTOYAGE_DESINFECTION': 'Nettoyage / désinfection',
  'LUTTE_NUISIBLES': 'Lutte contre les nuisibles',
  'HYGIENE_PERSONNEL': 'Hygiène du personnel',
  'MAINTENANCE': 'Maintenance des équipements',
  'APPROVISIONNEMENT_EAU': 'Approvisionnement en eau',
  'GESTION_DECHETS': 'Gestion des déchets',
  'FORMATION': 'Formation du personnel',
  'TRACABILITE': 'Traçabilité / rappel',
  'AUTRE': 'Autre',
};

class _PrpTab extends StatefulWidget {
  const _PrpTab();
  @override
  State<_PrpTab> createState() => _PrpTabState();
}

class _PrpTabState extends State<_PrpTab> {
  final api = Api();
  List prps = [], users = [];
  bool loading = true;
  Object? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      prps = List.from(await api.get('/haccp/prps'));
      users = List.from(await api.get('/users'));
    } catch (e) { error = e; }
    setState(() => loading = false);
  }

  String userName(String? id) {
    if (id == null) return '—';
    final u = users.firstWhere((x) => x['id'] == id, orElse: () => null);
    return u == null ? '—' : '${u['firstName']} ${u['lastName']}';
  }

  Future<void> editPrp([Map? prp]) async {
    final libelle = TextEditingController(text: prp?['libelle'] ?? '');
    final description = TextEditingController(text: prp?['description'] ?? '');
    final frequence = TextEditingController(text: prp?['frequence'] ?? '');
    String type = prp?['type'] ?? _prpTypeLabels.keys.first;
    String? responsableId = prp?['responsableId'];
    bool active = prp?['active'] ?? true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dc) => StatefulBuilder(builder: (dc, setD) => AlertDialog(
        title: Text(prp == null ? 'Nouveau PRP' : 'Modifier le PRP'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          DropdownButtonFormField<String>(
            isExpanded: true, decoration: const InputDecoration(labelText: 'Type'), value: type,
            items: _prpTypeLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (v) => setD(() => type = v ?? type),
          ),
          const SizedBox(height: 10),
          TextField(controller: libelle, decoration: const InputDecoration(labelText: 'Libellé *')),
          const SizedBox(height: 10),
          TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
          const SizedBox(height: 10),
          TextField(controller: frequence, decoration: const InputDecoration(labelText: 'Fréquence (ex : Hebdomadaire)')),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            isExpanded: true, decoration: const InputDecoration(labelText: 'Responsable'), value: responsableId,
            items: [const DropdownMenuItem<String>(value: null, child: Text('—')), ...users.map<DropdownMenuItem<String>>((u) => DropdownMenuItem<String>(value: u['id'] as String, child: Text('${u['firstName']} ${u['lastName']}')))],
            onChanged: (v) => setD(() => responsableId = v),
          ),
          CheckboxListTile(contentPadding: EdgeInsets.zero, value: active, title: const Text('Actif', style: TextStyle(fontSize: 13)), onChanged: (v) => setD(() => active = v ?? true)),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dc, false), child: const Text('Annuler')),
          FilledButton(onPressed: libelle.text.trim().isEmpty ? null : () => Navigator.pop(dc, true), child: const Text('Enregistrer')),
        ],
      )),
    );
    if (ok != true || libelle.text.trim().isEmpty) return;
    final payload = {
      'type': type, 'libelle': libelle.text.trim(),
      'description': description.text.trim().isEmpty ? null : description.text.trim(),
      'frequence': frequence.text.trim().isEmpty ? null : frequence.text.trim(),
      'responsableId': responsableId, 'active': active,
    };
    try {
      if (prp == null) {
        await api.post('/haccp/prps', payload);
      } else {
        await api.patch('/haccp/prps/${prp['id']}', payload);
      }
      load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> deletePrp(Map prp) async {
    final ok = await showDialog<bool>(context: context, builder: (dc) => AlertDialog(
      title: const Text('Supprimer ce PRP ?'),
      content: Text('${prp['libelle']}'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dc, false), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(dc, true), child: const Text('Supprimer')),
      ],
    ));
    if (ok != true) return;
    try { await api.delete('/haccp/prps/${prp['id']}'); load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
            ? LoadErrorView(error: error, onRetry: load)
        : RefreshIndicator(
            onRefresh: load,
            child: prps.isEmpty
                ? ListView(children: const [Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Aucun PRP enregistré')))])
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                    itemCount: prps.length,
                    itemBuilder: (_, i) {
                      final p = prps[i];
                      return Card(
                        child: ListTile(
                          leading: Icon(Icons.cleaning_services_outlined, color: p['active'] == true ? QhseColors.green : QhseColors.textSecondary),
                          title: Text('${p['libelle']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${_prpTypeLabels[p['type']] ?? p['type']}${p['frequence'] != null ? ' · ${p['frequence']}' : ''} · ${userName(p['responsableId'])}'),
                          onTap: () => editPrp(p),
                          trailing: IconButton(icon: const Icon(Icons.delete_outline, size: 20), onPressed: () => deletePrp(p)),
                        ),
                      );
                    },
                  ),
          ),
    floatingActionButton: FloatingActionButton.extended(onPressed: () => editPrp(), icon: const Icon(Icons.add), label: const Text('Nouveau PRP')),
  );
}

// --- Onglet 4 : Matrice — vue plate étude/étape/danger/CCP/statut ---
class _MatrixTab extends StatefulWidget {
  const _MatrixTab();
  @override
  State<_MatrixTab> createState() => _MatrixTabState();
}

class _MatrixTabState extends State<_MatrixTab> {
  final api = Api();
  List rows = [];
  bool loading = true;
  Object? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try { rows = List.from(await api.get('/haccp/matrice')); } catch (e) { error = e; }
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext c) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return LoadErrorView(error: error, onRetry: load);
    if (rows.isEmpty) {
      return RefreshIndicator(onRefresh: load, child: ListView(children: const [Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Aucune donnée')))]));
    }
    return RefreshIndicator(
      onRefresh: load,
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Étude')), DataColumn(label: Text('Étape')), DataColumn(label: Text('Danger')),
              DataColumn(label: Text('Type')), DataColumn(label: Text('Niveau de risque')), DataColumn(label: Text('CCP/CP')), DataColumn(label: Text('Statut')),
            ],
            rows: rows.map((r) => DataRow(cells: [
              DataCell(Text('${r['etudeCode'] ?? ''} — ${r['etude'] ?? ''}')), DataCell(Text('${r['etape'] ?? ''}')), DataCell(Text('${r['danger'] ?? ''}')),
              DataCell(Text('${r['type'] ?? '—'}')),
              DataCell(r['niveauRisque'] != null ? haccpChip(haccpNiveauRisqueLabels[r['niveauRisque']] ?? '${r['niveauRisque']}', haccpNiveauRisqueColor(r['niveauRisque'])) : const Text('—')),
              DataCell(Text(r['ccp'] != null ? '${r['ccp']} (${r['ccpType']})' : '—')),
              DataCell(Text('${r['statut'] ?? '—'}')),
            ])).toList(),
          ),
        ),
      ),
    );
  }
}
