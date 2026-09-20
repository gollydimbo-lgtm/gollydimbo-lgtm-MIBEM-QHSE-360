import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api.dart';
import '../services/sync_queue.dart';
import '../main.dart';
import '../theme.dart';
import 'attachment_helpers.dart';

const _capaStatusLabels = {
  'DRAFT': 'Brouillon', 'TO_ANALYZE': 'À analyser', 'PLANNED': 'Planifiée', 'ASSIGNED': 'Assignée',
  'OPEN': 'En cours', 'VALIDATION_PENDING': 'Soumise à validation', 'COMPLETED': 'Action réalisée',
  'EFFECTIVENESS_CHECK': "Évaluation de l'efficacité", 'VALIDATED': 'Validée', 'CLOSED': 'Clôturée',
  'SUSPENDED': 'Suspendue', 'BLOCKED': 'Bloquée', 'REJECTED': 'Rejetée', 'TO_REDO': 'À reprendre', 'CANCELLED': 'Annulée',
};
const _capaTypeLabels = {
  'CURATIVE': 'Curative / immédiate', 'CORRECTIVE': 'Corrective', 'PREVENTIVE': 'Préventive', 'AMELIORATION': 'Amélioration',
  'MAITRISE': 'Maîtrise', 'REDUCTION_RISQUE': 'Réduction du risque', 'REGLEMENTAIRE': 'Réglementaire', 'AUDIT': "Issue d'audit", 'AUTRE': 'Autre',
};
const _capaEffLabels = {'EFFICACE': 'Efficace', 'PARTIELLEMENT_EFFICACE': 'Partiellement efficace', 'INEFFICACE': 'Inefficace'};
const _capaNiveauLabels = {'EXCELLENT': 'Excellent', 'BON': 'Bon', 'A_SURVEILLER': 'À surveiller', 'INSUFFISANT': 'Insuffisant', 'CRITIQUE': 'Critique'};

Color _capaCriticiteColor(String? n) => {
      'CRITIQUE': QhseColors.red, 'MAJEURE': QhseColors.amber,
      'MINEURE': const Color(0xFFB45309), 'NON_CRITIQUE': QhseColors.green,
    }[n] ?? QhseColors.textSecondary;
Color _capaNiveauColor(String? n) => {
      'EXCELLENT': QhseColors.green, 'BON': QhseColors.green, 'A_SURVEILLER': QhseColors.amber,
      'INSUFFISANT': QhseColors.red, 'CRITIQUE': QhseColors.red,
    }[n] ?? QhseColors.textSecondary;

// --- Écran principal : tableau de bord + plan d'action CAPA ---
class ActionsPage extends StatefulWidget {
  const ActionsPage({super.key});
  @override
  State<ActionsPage> createState() => _ActionsPageState();
}

class _ActionsPageState extends State<ActionsPage> {
  final api = Api();
  List items = [];
  Map dashboard = {}, score = {};
  List trends = [];
  List alertes = [];
  bool loading = true;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final all = List.from(await api.get('/business/actions'));
      items = all.where((a) => a['parentActionId'] == null).toList();
      dashboard = Map.from(await api.get('/business/action-dashboard'));
      score = Map.from(await api.get('/business/action-performance-score'));
      trends = List.from(await api.get('/business/action-trends'));
      alertes = List.from(await api.get('/business/action-alertes'));
    } catch (_) {}
    setState(() => loading = false);
  }

  bool _isCritical(Map a, DateTime now) {
    final due = a['dueDate'] != null ? DateTime.tryParse(a['dueDate']) : null;
    final overdue = due != null && a['status'] != 'CLOSED' && due.isBefore(now);
    return a['criticite'] == 'CRITIQUE' || overdue || a['effectivenessResult'] == 'INEFFICACE' || a['status'] == 'BLOCKED';
  }

  @override
  Widget build(BuildContext c) {
    final now = DateTime.now();
    final critiques = items.where((a) => _isCritical(a, now)).toList();
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(title: const Text('Actions CAPA'), bottom: const TabBar(tabs: [Tab(text: "Plan d'action"), Tab(text: 'Critiques'), Tab(text: 'Analyses')])),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const CapaFormPage())).then((_) => load()),
          icon: const Icon(Icons.add),
          label: const Text('Nouvelle action'),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(children: [
                _buildList(c, items, now, empty: 'Aucune action'),
                _buildList(c, critiques, now, empty: 'Aucune action critique — tout est sous contrôle'),
                _buildAnalyses(c),
              ]),
      ),
    );
  }

  Widget _buildList(BuildContext c, List list, DateTime now, {required String empty}) => RefreshIndicator(
    onRefresh: load,
    child: Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: KpiBar([
          KpiStat('Total', '${dashboard['total'] ?? items.length}', color: QhseColors.blue, icon: Icons.build_outlined),
          KpiStat('Ouvertes', '${dashboard['ouvertes'] ?? 0}', color: QhseColors.amber, icon: Icons.pending_actions),
          KpiStat('Terminées', '${dashboard['terminees'] ?? 0}', color: QhseColors.green, icon: Icons.check_circle_outline),
          KpiStat('En retard', '${dashboard['enRetard'] ?? 0}', color: (dashboard['enRetard'] ?? 0) > 0 ? QhseColors.red : QhseColors.green, icon: Icons.warning_amber_outlined),
          KpiStat('Critiques', '${dashboard['critiques'] ?? 0}', color: (dashboard['critiques'] ?? 0) > 0 ? QhseColors.red : QhseColors.green, icon: Icons.error_outline),
        ]),
      ),
      Expanded(
        child: list.isEmpty
            ? ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(empty)))])
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final a = list[i];
                  final due = a['dueDate'] != null ? DateTime.tryParse(a['dueDate']) : null;
                  final overdue = due != null && a['status'] != 'CLOSED' && due.isBefore(now);
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        a['status'] == 'CLOSED' ? Icons.check_circle : (overdue ? Icons.error : Icons.pending_actions),
                        color: a['status'] == 'CLOSED' ? Colors.green : (overdue ? Colors.red : Colors.orange),
                      ),
                      title: Text('${a['code']} — ${a['title']}'),
                      subtitle: Text('${_capaStatusLabels[a['status']] ?? a['status']}${a['actionType'] != null ? ' · ${_capaTypeLabels[a['actionType']] ?? a['actionType']}' : ''}${due != null ? ' · échéance ${due.toIso8601String().substring(0, 10)}' : ''}${overdue ? ' ⚠️ en retard' : ''}'),
                      trailing: a['avancement'] != null ? Text('${a['avancement']}%', style: const TextStyle(fontWeight: FontWeight.bold)) : null,
                      onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => CapaDetailPage(actionId: a['id']))).then((_) => load()),
                    ),
                  );
                },
              ),
      ),
    ]),
  );

  Color _alerteColor(String? n) => {
        'CRITIQUE': QhseColors.red, 'URGENT': QhseColors.red,
        'ATTENTION': QhseColors.amber, 'INFORMATION': QhseColors.blue,
      }[n] ?? QhseColors.textSecondary;

  Widget _buildAnalyses(BuildContext c) => RefreshIndicator(
    onRefresh: load,
    child: ListView(padding: const EdgeInsets.all(16), children: [
      Text('Alertes (avec escalade)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: QhseColors.textPrimary)),
      const SizedBox(height: 4),
      Text('${alertes.length} point(s) nécessitant attention', style: TextStyle(fontSize: 11, color: QhseColors.textSecondary)),
      const SizedBox(height: 8),
      alertes.isEmpty
          ? Card(child: Padding(padding: const EdgeInsets.all(16), child: Center(child: Text('Aucune alerte — tout est sous contrôle', style: TextStyle(color: QhseColors.textSecondary)))))
          : Card(child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(children: [
              for (final a in alertes)
                ListTile(
                  dense: true,
                  title: Text('${a['label']}', style: const TextStyle(fontSize: 13)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: _alerteColor(a['niveau']).withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                    child: Text('${a['niveau']}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _alerteColor(a['niveau']))),
                  ),
                ),
            ]))),
      const SizedBox(height: 16),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        Text('Score de performance CAPA', style: TextStyle(fontSize: 12, color: QhseColors.textSecondary)),
        const SizedBox(height: 4),
        Text('${score['score'] ?? '—'}', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: _capaNiveauColor(score['niveau']))),
        Text(_capaNiveauLabels[score['niveau']] ?? '—', style: TextStyle(color: _capaNiveauColor(score['niveau']), fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text("Taux d'efficacité : ${score['tauxEfficacite'] ?? '—'}%", style: TextStyle(fontSize: 12, color: QhseColors.textSecondary)),
      ]))),
      const SizedBox(height: 16),
      Text('Évolution sur 12 mois — créées vs réalisées', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: QhseColors.textPrimary)),
      const SizedBox(height: 8),
      SizedBox(height: 200, child: trends.isEmpty ? Center(child: Text('Pas encore assez de données', style: TextStyle(color: QhseColors.textSecondary))) : _CapaTrendChart(trends: trends)),
    ]),
  );
}

/// Évolution mensuelle créées/réalisées (fl_chart LineChart, même style que
/// le graphique déjà utilisé sur le tableau de bord principal).
class _CapaTrendChart extends StatelessWidget {
  final List trends;
  const _CapaTrendChart({required this.trends});

  List<FlSpot> _toSpots(String key) => [for (int i = 0; i < trends.length; i++) FlSpot(i.toDouble(), ((trends[i][key] ?? 0) as num).toDouble())];

  @override
  Widget build(BuildContext context) => LineChart(LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: QhseColors.border, strokeWidth: 1)),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 26, getTitlesWidget: (v, m) => Text(v.toInt().toString(), style: TextStyle(fontSize: 9, color: QhseColors.textSecondary)))),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, interval: 1, getTitlesWidget: (v, m) {
            final i = v.toInt();
            return Padding(padding: const EdgeInsets.only(top: 4), child: Text(i >= 0 && i < trends.length ? '${trends[i]['label'] ?? ''}' : '', style: TextStyle(fontSize: 9, color: QhseColors.textSecondary)));
          })),
        ),
        lineBarsData: [
          LineChartBarData(spots: _toSpots('creees'), isCurved: true, color: QhseColors.blue, barWidth: 2, dotData: const FlDotData(show: true), belowBarData: BarAreaData(show: true, color: QhseColors.blue.withOpacity(0.08))),
          LineChartBarData(spots: _toSpots('realisees'), isCurved: true, color: QhseColors.green, barWidth: 2, dotData: const FlDotData(show: true), belowBarData: BarAreaData(show: true, color: QhseColors.green.withOpacity(0.08))),
        ],
      ));
}

// --- Formulaire de création / modification ---
class CapaFormPage extends StatefulWidget {
  final Map? record;
  final String? parentActionId;
  final String? sourceModule;
  final String? sourceEntityId;
  final Map<String, dynamic> prefillData;
  final List<String> selectedAttachmentIds;
  const CapaFormPage({super.key, this.record, this.parentActionId, this.sourceModule, this.sourceEntityId, this.prefillData = const {}, this.selectedAttachmentIds = const []});
  @override
  State<CapaFormPage> createState() => _CapaFormPageState();
}

class _CapaFormPageState extends State<CapaFormPage> {
  final api = Api();
  bool get editing => widget.record != null;
  List workUnits = [], users = [];
  final title = TextEditingController();
  final description = TextEditingController();
  final source = TextEditingController();
  DateTime? dueDate;
  String? actionType, criticite, workUnitId, responsibleId;
  int priority = 2, avancement = 0;
  bool busy = false, loadingLists = true;
  String? error;

  @override
  void initState() {
    super.initState();
    final a = widget.record;
    if (a != null) {
      title.text = a['title'] ?? '';
      description.text = a['description'] ?? '';
      source.text = a['source'] ?? '';
      dueDate = a['dueDate'] != null ? DateTime.tryParse(a['dueDate']) : null;
      actionType = a['actionType']; criticite = a['criticite']; workUnitId = a['workUnitId']; responsibleId = a['responsibleId'];
      priority = a['priority'] ?? 2; avancement = a['avancement'] ?? 0;
    } else if (widget.prefillData.isNotEmpty) {
      title.text = widget.prefillData['title'] ?? '';
      description.text = widget.prefillData['description'] ?? '';
      source.text = widget.prefillData['source'] ?? '';
      criticite = widget.prefillData['criticite'];
      actionType = widget.prefillData['actionType'];
      workUnitId = widget.prefillData['workUnitId'];
      responsibleId = widget.prefillData['responsibleId'];
      priority = widget.prefillData['priority'] ?? 2;
      if (widget.prefillData['dueDate'] != null) dueDate = DateTime.tryParse('${widget.prefillData['dueDate']}');
    }
    loadLists();
  }

  Future<void> loadLists() async {
    try {
      workUnits = List.from(await api.get('/business/work-units'));
      users = List.from(await api.get('/users'));
    } catch (_) {}
    setState(() => loadingLists = false);
  }

  Future<void> pickDate() async {
    final d = await showDatePicker(context: context, initialDate: dueDate ?? DateTime.now(), firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 730)));
    if (d != null) setState(() => dueDate = d);
  }

  Future<void> submit() async {
    if (title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le titre est obligatoire')));
      return;
    }
    setState(() { busy = true; error = null; });
    final payload = {
      'title': title.text.trim(), 'description': description.text.trim().isEmpty ? null : description.text.trim(),
      'source': source.text.trim().isEmpty ? null : source.text.trim(), 'actionType': actionType, 'criticite': criticite,
      'priority': priority, 'avancement': avancement, 'dueDate': dueDate?.toIso8601String(),
      'workUnitId': workUnitId, 'responsibleId': responsibleId,
      if (widget.parentActionId != null) 'parentActionId': widget.parentActionId,
    };
    try {
      if (editing) {
        await api.patch('/business/actions/${widget.record!['id']}', payload);
      } else if (widget.sourceModule != null && widget.sourceEntityId != null) {
        // Matrice de liaison générique — le point de création commun à
        // tous les modules plutôt qu'une implémentation par module.
        final created = await api.post('/business/capa-links/create-from-source', {'code': genCode('ACT'), ...payload, 'sourceModule': widget.sourceModule, 'sourceEntityId': widget.sourceEntityId});
        // Pièces jointes cochées à l'écran de confirmation — jamais
        // dupliquées, seulement référencées sur la nouvelle CAPA.
        for (final attachmentId in widget.selectedAttachmentIds) {
          try { await api.post('/attachments/link', {'ownerType': 'ACTION', 'ownerId': created['id'], 'attachmentId': attachmentId}); } catch (_) {}
        }
      } else {
        await api.post('/business/actions', {'code': genCode('ACT'), ...payload});
      }
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (e.networkError && !editing) {
        await SyncQueue.enqueue('action', 'CREATE', {'code': genCode('ACT'), ...payload});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pas de réseau : action enregistrée hors-ligne, elle sera synchronisée automatiquement.'), duration: Duration(seconds: 4)));
          Navigator.pop(context);
        }
      } else {
        setState(() { busy = false; error = '$e'; });
        return;
      }
    } catch (e) {
      setState(() { busy = false; error = '$e'; });
      return;
    }
    setState(() => busy = false);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text(widget.parentActionId != null ? 'Nouvelle sous-action' : editing ? "Modifier l'action" : 'Nouvelle action CAPA')),
    body: loadingLists
        ? const Center(child: CircularProgressIndicator())
        : ListView(padding: const EdgeInsets.all(16), children: [
            if (widget.sourceModule != null)
              Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: QhseColors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text("Informations récupérées automatiquement depuis la source — modifiez-les librement avant d'enregistrer.", style: TextStyle(color: QhseColors.blue, fontSize: 11))),
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Action')),
            const SizedBox(height: 12),
            TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: actionType, isExpanded: true, decoration: const InputDecoration(labelText: "Type d'action"),
              items: [const DropdownMenuItem<String>(value: null, child: Text('—')), ..._capaTypeLabels.entries.map((e) => DropdownMenuItem<String>(value: e.key, child: Text(e.value)))],
              onChanged: (v) => setState(() => actionType = v),
            ),
            const SizedBox(height: 12),
            TextField(controller: source, decoration: const InputDecoration(labelText: 'Source / origine')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: criticite, isExpanded: true, decoration: const InputDecoration(labelText: 'Criticité'),
              items: const [DropdownMenuItem<String>(value: null, child: Text('—')), DropdownMenuItem(value: 'NON_CRITIQUE', child: Text('Non critique')), DropdownMenuItem(value: 'MINEURE', child: Text('Mineure')), DropdownMenuItem(value: 'MAJEURE', child: Text('Majeure')), DropdownMenuItem(value: 'CRITIQUE', child: Text('Critique'))],
              onChanged: (v) => setState(() => criticite = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: priority, decoration: const InputDecoration(labelText: 'Priorité'),
              items: const [DropdownMenuItem(value: 1, child: Text('Urgente')), DropdownMenuItem(value: 2, child: Text('Haute')), DropdownMenuItem(value: 3, child: Text('Moyenne')), DropdownMenuItem(value: 4, child: Text('Faible'))],
              onChanged: (v) => setState(() => priority = v ?? 2),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: responsibleId, isExpanded: true, decoration: const InputDecoration(labelText: 'Responsable'),
              items: [const DropdownMenuItem<String>(value: null, child: Text('—')), ...users.map<DropdownMenuItem<String>>((u) => DropdownMenuItem<String>(value: u['id'] as String, child: Text('${u['firstName']} ${u['lastName']}')))],
              onChanged: (v) => setState(() => responsibleId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: workUnitId, isExpanded: true, decoration: const InputDecoration(labelText: 'Unité de travail / service'),
              items: [const DropdownMenuItem<String>(value: null, child: Text('—')), ...workUnits.map<DropdownMenuItem<String>>((w) => DropdownMenuItem<String>(value: w['id'] as String, child: Text(w['name'] ?? '')))],
              onChanged: (v) => setState(() => workUnitId = v),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: pickDate, icon: const Icon(Icons.event), label: Text(dueDate != null ? 'Échéance : ${dueDate!.toIso8601String().substring(0, 10)}' : 'Échéance')),
            const SizedBox(height: 16),
            Text('Avancement : $avancement%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Slider(value: avancement.toDouble(), min: 0, max: 100, divisions: 4, label: '$avancement%', onChanged: (v) => setState(() => avancement = v.round())),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : submit, child: Text(busy ? 'Envoi...' : 'Enregistrer'))),
          ]),
  );
}

// --- Détail : sous-actions, causes, efficacité, clôture, prolongation ---
class CapaDetailPage extends StatefulWidget {
  final String actionId;
  const CapaDetailPage({super.key, required this.actionId});
  @override
  State<CapaDetailPage> createState() => _CapaDetailPageState();
}

class _CapaDetailPageState extends State<CapaDetailPage> {
  final api = Api();
  Map? action;
  bool loading = true, busy = false;
  String? error;
  String effResult = '';
  final effNotes = TextEditingController();

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() => loading = true);
    try { action = Map.from(await api.get('/business/actions/${widget.actionId}')); }
    catch (e) { error = '$e'; }
    setState(() => loading = false);
  }

  Future<void> saveEffectiveness() async {
    if (effResult.isEmpty) return;
    setState(() => busy = true);
    try {
      await api.post('/business/actions/${widget.actionId}/effectiveness', {'result': effResult, 'notes': effNotes.text.trim().isEmpty ? null : effNotes.text.trim()});
      load();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
    setState(() => busy = false);
  }

  Future<void> close() async {
    setState(() => busy = true);
    try { await api.post('/business/actions/${widget.actionId}/close', {}); load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
    setState(() => busy = false);
  }

  Future<void> reopen() async {
    setState(() => busy = true);
    try { await api.post('/business/actions/${widget.actionId}/reopen', {}); load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
    setState(() => busy = false);
  }

  Future<void> addCause() async {
    final desc = TextEditingController();
    String methode = '5_POURQUOI';
    bool estRacine = false;
    final ok = await showDialog<bool>(context: context, builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
      title: const Text('Analyse des causes'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: methode, items: const [DropdownMenuItem(value: '5_POURQUOI', child: Text('5 Pourquoi')), DropdownMenuItem(value: 'ISHIKAWA', child: Text('Ishikawa (5M)')), DropdownMenuItem(value: 'AUTRE', child: Text('Autre'))], onChanged: (v) => setD(() => methode = v ?? '5_POURQUOI')),
        TextField(controller: desc, maxLines: 2, decoration: const InputDecoration(labelText: 'Description de la cause')),
        CheckboxListTile(contentPadding: EdgeInsets.zero, value: estRacine, title: const Text('Cause racine', style: TextStyle(fontSize: 13)), onChanged: (v) => setD(() => estRacine = v ?? false)),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Ajouter'))],
    )));
    if (ok != true || desc.text.trim().isEmpty) return;
    try { await api.post('/business/action-causes', {'methode': methode, 'description': desc.text.trim(), 'estRacine': estRacine, 'actionId': widget.actionId}); load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  Future<void> requestExtension() async {
    DateTime? newDate;
    final motif = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
      title: const Text('Demander une prolongation'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        OutlinedButton.icon(
          onPressed: () async { final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365))); if (d != null) setD(() => newDate = d); },
          icon: const Icon(Icons.event), label: Text(newDate != null ? newDate!.toIso8601String().substring(0, 10) : 'Choisir la nouvelle échéance'),
        ),
        TextField(controller: motif, decoration: const InputDecoration(labelText: 'Motif')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Confirmer'))],
    )));
    if (ok != true || newDate == null || motif.text.trim().isEmpty) return;
    try { await api.post('/business/actions/${widget.actionId}/extensions', {'nouvelleEcheance': newDate!.toIso8601String(), 'motif': motif.text.trim()}); load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  @override
  Widget build(BuildContext c) {
    if (loading) return Scaffold(appBar: AppBar(title: const Text('Action CAPA')), body: const Center(child: CircularProgressIndicator()));
    if (error != null || action == null) return Scaffold(appBar: AppBar(title: const Text('Action CAPA')), body: Center(child: Text(error ?? 'Introuvable')));
    final a = action!;
    final subActions = List.from(a['subActions'] ?? []);
    final causes = List.from(a['causes'] ?? []);
    final extensions = List.from(a['extensions'] ?? []);

    return Scaffold(
      appBar: AppBar(title: Text('${a['code']}'), actions: [
        IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => CapaFormPage(record: a))).then((_) => load())),
      ]),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Text('${a['title']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          if (a['description'] != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${a['description']}')),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 6, children: [
            Chip(label: Text(_capaStatusLabels[a['status']] ?? a['status'])),
            if (a['actionType'] != null) Chip(label: Text(_capaTypeLabels[a['actionType']] ?? a['actionType'])),
            if (a['criticite'] != null) Chip(label: Text(a['criticite']), backgroundColor: _capaCriticiteColor(a['criticite']).withOpacity(0.15)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            if (a['status'] == 'CLOSED') OutlinedButton(onPressed: busy ? null : reopen, child: const Text('Réouvrir'))
            else FilledButton(onPressed: busy || a['effectivenessResult'] != 'EFFICACE' ? null : close, child: const Text('Clôturer')),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: requestExtension, child: const Text('Prolonger')),
          ]),
          const SizedBox(height: 16),
          Text('Avancement : ${a['avancement'] ?? 0}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: (a['avancement'] ?? 0) / 100, minHeight: 8)),
          const SizedBox(height: 20),

          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Plan d\'action — sous-actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            TextButton.icon(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => CapaFormPage(parentActionId: a['id']))).then((_) => load()), icon: const Icon(Icons.add, size: 16), label: const Text('Sous-action')),
          ]),
          if (subActions.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('Aucune sous-action', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
          else ...subActions.map((sa) => Card(child: ListTile(dense: true, title: Text('${sa['title']}'), subtitle: Text('${_capaStatusLabels[sa['status']] ?? sa['status']} · ${sa['avancement'] ?? 0}%')))),

          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Analyse des causes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            TextButton.icon(onPressed: addCause, icon: const Icon(Icons.add, size: 16), label: const Text('Ajouter')),
          ]),
          if (causes.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('Aucune cause enregistrée', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
          else ...causes.map((cs) => Card(child: ListTile(dense: true, title: Text('${cs['description']}'), subtitle: Text('${cs['methode']}${cs['estRacine'] == true ? ' · Racine' : ''}')))),

          const SizedBox(height: 16),
          const Text("Vérification d'efficacité", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          if (a['effectivenessResult'] != null) Text('Dernier résultat : ${_capaEffLabels[a['effectivenessResult']]}', style: TextStyle(color: a['effectivenessResult'] == 'EFFICACE' ? QhseColors.green : a['effectivenessResult'] == 'INEFFICACE' ? QhseColors.red : QhseColors.amber)),
          DropdownButtonFormField<String>(
            value: effResult.isEmpty ? null : effResult, decoration: const InputDecoration(labelText: 'Résultat'),
            items: const [DropdownMenuItem(value: 'EFFICACE', child: Text('Efficace')), DropdownMenuItem(value: 'PARTIELLEMENT_EFFICACE', child: Text('Partiellement efficace')), DropdownMenuItem(value: 'INEFFICACE', child: Text('Inefficace'))],
            onChanged: (v) => setState(() => effResult = v ?? ''),
          ),
          TextField(controller: effNotes, decoration: const InputDecoration(labelText: 'Notes (optionnel)')),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: OutlinedButton(onPressed: busy || effResult.isEmpty ? null : saveEffectiveness, child: const Text('Enregistrer la vérification'))),

          if (extensions.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Prolongations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ...extensions.map((ex) => Card(child: ListTile(dense: true, title: Text('${ex['nouvelleEcheance'].toString().substring(0, 10)}'), subtitle: Text('${ex['motif']}')))),
          ],
        ]),
      ),
    );
  }
}
