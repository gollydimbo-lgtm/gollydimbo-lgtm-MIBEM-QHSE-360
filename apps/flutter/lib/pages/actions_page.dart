import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api.dart';
import '../services/sync_queue.dart';
import '../main.dart';
import '../theme.dart';
import '../i18n/i18n.dart';
import 'attachment_helpers.dart';
import 'load_error_view.dart';
import 'validation_history_widgets.dart';

// Export CSV du registre (finding #30/#17 de l'audit — export manquant
// côté mobile pour les Actions CAPA, déjà présent côté web).
String _capaCsvEscape(String v) => v.contains(',') || v.contains('"') || v.contains('\n') ? '"${v.replaceAll('"', '""')}"' : v;

Map<String, String> _capaStatusLabels() => {
  'DRAFT': t('actionsPage.status.draft'), 'TO_ANALYZE': t('actionsPage.status.toAnalyze'), 'PLANNED': t('actionsPage.status.planned'), 'ASSIGNED': t('actionsPage.status.assigned'),
  'OPEN': t('actionsPage.status.open'), 'VALIDATION_PENDING': t('actionsPage.status.validationPending'), 'COMPLETED': t('actionsPage.status.completed'),
  'EFFECTIVENESS_CHECK': t('actionsPage.status.effectivenessCheck'), 'VALIDATED': t('actionsPage.status.validated'), 'CLOSED': t('actionsPage.status.closed'),
  'SUSPENDED': t('actionsPage.status.suspended'), 'BLOCKED': t('actionsPage.status.blocked'), 'REJECTED': t('actionsPage.status.rejected'), 'TO_REDO': t('actionsPage.status.toRedo'), 'CANCELLED': t('actionsPage.status.cancelled'),
};
Map<String, String> _capaTypeLabels() => {
  'CURATIVE': t('actionsPage.type.curative'), 'CORRECTIVE': t('actionsPage.type.corrective'), 'PREVENTIVE': t('actionsPage.type.preventive'), 'AMELIORATION': t('actionsPage.type.amelioration'),
  'MAITRISE': t('actionsPage.type.maitrise'), 'REDUCTION_RISQUE': t('actionsPage.type.reductionRisque'), 'REGLEMENTAIRE': t('actionsPage.type.reglementaire'), 'AUDIT': t('actionsPage.type.audit'), 'AUTRE': t('actionsPage.type.autre'),
};
Map<String, String> _capaEffLabels() => {'EFFICACE': t('actionsPage.eff.efficace'), 'PARTIELLEMENT_EFFICACE': t('actionsPage.eff.partiellementEfficace'), 'INEFFICACE': t('actionsPage.eff.inefficace')};
Map<String, String> _capaNiveauLabels() => {'EXCELLENT': t('actionsPage.niveau.excellent'), 'BON': t('actionsPage.niveau.bon'), 'A_SURVEILLER': t('actionsPage.niveau.aSurveiller'), 'INSUFFISANT': t('actionsPage.niveau.insuffisant'), 'CRITIQUE': t('actionsPage.niveau.critique')};

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
  Object? error;
  bool exporting = false;
  // Recherche harmonisée (audit priorité 7, finding #18).
  String search = '';

  Future<void> exportCsv() async {
    setState(() => exporting = true);
    try {
      final headers = [t('actionsPage.csv.code'), t('actionsPage.csv.titre'), t('actionsPage.csv.type'), t('actionsPage.csv.statut'), t('actionsPage.csv.avancement'), t('actionsPage.csv.echeance'), t('actionsPage.csv.efficacite')];
      final buffer = StringBuffer();
      buffer.writeln(headers.map((v) => _capaCsvEscape(v)).join(','));
      for (final a in items) {
        buffer.writeln([
          a['code'], a['title'], _capaTypeLabels()[a['actionType']] ?? a['actionType'] ?? '', _capaStatusLabels()[a['status']] ?? a['status'] ?? '',
          a['avancement'] != null ? '${a['avancement']}%' : '',
          a['dueDate'] != null ? DateTime.parse(a['dueDate']).toIso8601String().substring(0, 10) : '',
          _capaEffLabels()[a['effectivenessResult']] ?? a['effectivenessResult'] ?? '',
        ].map((v) => _capaCsvEscape('$v')).join(','));
      }
      final dir = await getTemporaryDirectory();
      final fileName = 'Actions-CAPA-${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes([0xEF, 0xBB, 0xBF, ...buffer.toString().codeUnits]);
      await Share.shareXFiles([XFile(file.path)], text: t('actionsPage.shareText'));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    setState(() => exporting = false);
  }

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final all = List.from(await api.get('/business/actions'));
      items = all.where((a) => a['parentActionId'] == null).toList();
      dashboard = Map.from(await api.get('/business/action-dashboard'));
      score = Map.from(await api.get('/business/action-performance-score'));
      trends = List.from(await api.get('/business/action-trends'));
      alertes = List.from(await api.get('/business/action-alertes'));
    } catch (e) { error = e; }
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
        appBar: AppBar(title: Text(t('actionsPage.title')), actions: [
          IconButton(icon: exporting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.ios_share), tooltip: t('actionsPage.exportTooltip'), onPressed: exporting ? null : exportCsv),
        ], bottom: TabBar(tabs: [Tab(text: t('actionsPage.tabPlan')), Tab(text: t('actionsPage.tabCritiques')), Tab(text: t('actionsPage.tabAnalyses'))])),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const CapaFormPage())).then((_) => load()),
          icon: const Icon(Icons.add),
          label: Text(t('actionsPage.nouvelleAction')),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? LoadErrorView(error: error, onRetry: load)
            : TabBarView(children: [
                _buildList(c, items, now, empty: t('actionsPage.aucuneAction')),
                _buildList(c, critiques, now, empty: t('actionsPage.aucuneActionCritique')),
                _buildAnalyses(c),
              ]),
      ),
    );
  }

  Widget _buildList(BuildContext c, List rawList, DateTime now, {required String empty}) => RefreshIndicator(
    onRefresh: load,
    child: Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: TextField(
          decoration: InputDecoration(prefixIcon: const Icon(Icons.search, size: 18), hintText: t('actionsPage.searchHint'), isDense: true, border: const OutlineInputBorder()),
          onChanged: (v) => setState(() => search = v),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: KpiBar([
          KpiStat(t('actionsPage.kpi.total'), '${dashboard['total'] ?? items.length}', color: QhseColors.blue, icon: Icons.build_outlined),
          KpiStat(t('actionsPage.kpi.ouvertes'), '${dashboard['ouvertes'] ?? 0}', color: QhseColors.amber, icon: Icons.pending_actions),
          KpiStat(t('actionsPage.kpi.terminees'), '${dashboard['terminees'] ?? 0}', color: QhseColors.green, icon: Icons.check_circle_outline),
          KpiStat(t('actionsPage.kpi.enRetard'), '${dashboard['enRetard'] ?? 0}', color: (dashboard['enRetard'] ?? 0) > 0 ? QhseColors.red : QhseColors.green, icon: Icons.warning_amber_outlined),
          KpiStat(t('actionsPage.kpi.critiques'), '${dashboard['critiques'] ?? 0}', color: (dashboard['critiques'] ?? 0) > 0 ? QhseColors.red : QhseColors.green, icon: Icons.error_outline),
        ]),
      ),
      Builder(builder: (_) {
        final list = search.trim().isEmpty
            ? rawList
            : rawList.where((a) => ('${a['code'] ?? ''} ${a['title'] ?? ''}').toLowerCase().contains(search.trim().toLowerCase())).toList();
        return Expanded(
        child: list.isEmpty
            ? ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(search.trim().isEmpty ? empty : t('actionsPage.aucunResultat'))))])
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
                      subtitle: Text('${_capaStatusLabels()[a['status']] ?? a['status']}${a['actionType'] != null ? ' · ${_capaTypeLabels()[a['actionType']] ?? a['actionType']}' : ''}${due != null ? t('actionsPage.echeanceSuffix', {'date': due.toIso8601String().substring(0, 10)}) : ''}${overdue ? t('actionsPage.enRetardSuffix') : ''}'),
                      trailing: a['avancement'] != null ? Text('${a['avancement']}%', style: const TextStyle(fontWeight: FontWeight.bold)) : null,
                      onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => CapaDetailPage(actionId: a['id']))).then((_) => load()),
                    ),
                  );
                },
              ),
      );
      }),
    ]),
  );

  Color _alerteColor(String? n) => {
        'CRITIQUE': QhseColors.red, 'URGENT': QhseColors.red,
        'ATTENTION': QhseColors.amber, 'INFORMATION': QhseColors.blue,
      }[n] ?? QhseColors.textSecondary;

  Widget _buildAnalyses(BuildContext c) => RefreshIndicator(
    onRefresh: load,
    child: ListView(padding: const EdgeInsets.all(16), children: [
      Text(t('actionsPage.alertesTitle'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: QhseColors.textPrimary)),
      const SizedBox(height: 4),
      Text(t('actionsPage.alertesCount', {'count': '${alertes.length}'}), style: TextStyle(fontSize: 11, color: QhseColors.textSecondary)),
      const SizedBox(height: 8),
      alertes.isEmpty
          ? Card(child: Padding(padding: const EdgeInsets.all(16), child: Center(child: Text(t('actionsPage.aucuneAlerte'), style: TextStyle(color: QhseColors.textSecondary)))))
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
        Text(t('actionsPage.scoreTitle'), style: TextStyle(fontSize: 12, color: QhseColors.textSecondary)),
        const SizedBox(height: 4),
        Text('${score['score'] ?? '—'}', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: _capaNiveauColor(score['niveau']))),
        Text(_capaNiveauLabels()[score['niveau']] ?? '—', style: TextStyle(color: _capaNiveauColor(score['niveau']), fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(t('actionsPage.tauxEfficacite', {'value': '${score['tauxEfficacite'] ?? '—'}'}), style: TextStyle(fontSize: 12, color: QhseColors.textSecondary)),
      ]))),
      const SizedBox(height: 16),
      Text(t('actionsPage.evolutionTitle'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: QhseColors.textPrimary)),
      const SizedBox(height: 8),
      SizedBox(height: 200, child: trends.isEmpty ? Center(child: Text(t('actionsPage.pasAssezDeDonnees'), style: TextStyle(color: QhseColors.textSecondary))) : _CapaTrendChart(trends: trends)),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('actionsPage.titreObligatoire'))));
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('actionsPage.horsLigneMessage')), duration: const Duration(seconds: 4)));
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
    appBar: AppBar(title: Text(widget.parentActionId != null ? t('actionsPage.nouvelleSousAction') : editing ? t('actionsPage.modifierAction') : t('actionsPage.nouvelleActionCapa'))),
    body: loadingLists
        ? const Center(child: CircularProgressIndicator())
        : ListView(padding: const EdgeInsets.all(16), children: [
            if (widget.sourceModule != null)
              Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: QhseColors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(t('actionsPage.infoSourceBanner'), style: TextStyle(color: QhseColors.blue, fontSize: 11))),
            TextField(controller: title, decoration: InputDecoration(labelText: t('actionsPage.actionLabel'))),
            const SizedBox(height: 12),
            TextField(controller: description, maxLines: 3, decoration: InputDecoration(labelText: t('actionsPage.descriptionLabel'))),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: actionType, isExpanded: true, decoration: InputDecoration(labelText: t('actionsPage.typeActionLabel')),
              items: [const DropdownMenuItem<String>(value: null, child: Text('—')), ..._capaTypeLabels().entries.map((e) => DropdownMenuItem<String>(value: e.key, child: Text(e.value)))],
              onChanged: (v) => setState(() => actionType = v),
            ),
            const SizedBox(height: 12),
            TextField(controller: source, decoration: InputDecoration(labelText: t('actionsPage.sourceLabel'))),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: criticite, isExpanded: true, decoration: InputDecoration(labelText: t('actionsPage.criticiteLabel')),
              items: [const DropdownMenuItem<String>(value: null, child: Text('—')), DropdownMenuItem(value: 'NON_CRITIQUE', child: Text(t('actionsPage.criticiteOptions.nonCritique'))), DropdownMenuItem(value: 'MINEURE', child: Text(t('actionsPage.criticiteOptions.mineure'))), DropdownMenuItem(value: 'MAJEURE', child: Text(t('actionsPage.criticiteOptions.majeure'))), DropdownMenuItem(value: 'CRITIQUE', child: Text(t('actionsPage.criticiteOptions.critique')))],
              onChanged: (v) => setState(() => criticite = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: priority, decoration: InputDecoration(labelText: t('actionsPage.prioriteLabel')),
              items: [DropdownMenuItem(value: 1, child: Text(t('actionsPage.priorite.urgente'))), DropdownMenuItem(value: 2, child: Text(t('actionsPage.priorite.haute'))), DropdownMenuItem(value: 3, child: Text(t('actionsPage.priorite.moyenne'))), DropdownMenuItem(value: 4, child: Text(t('actionsPage.priorite.faible')))],
              onChanged: (v) => setState(() => priority = v ?? 2),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: responsibleId, isExpanded: true, decoration: InputDecoration(labelText: t('actionsPage.responsableLabel')),
              items: [const DropdownMenuItem<String>(value: null, child: Text('—')), ...users.map<DropdownMenuItem<String>>((u) => DropdownMenuItem<String>(value: u['id'] as String, child: Text('${u['firstName']} ${u['lastName']}')))],
              onChanged: (v) => setState(() => responsibleId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: workUnitId, isExpanded: true, decoration: InputDecoration(labelText: t('actionsPage.workUnitLabel')),
              items: [const DropdownMenuItem<String>(value: null, child: Text('—')), ...workUnits.map<DropdownMenuItem<String>>((w) => DropdownMenuItem<String>(value: w['id'] as String, child: Text(w['name'] ?? '')))],
              onChanged: (v) => setState(() => workUnitId = v),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: pickDate, icon: const Icon(Icons.event), label: Text(dueDate != null ? t('actionsPage.echeanceValeur', {'date': dueDate!.toIso8601String().substring(0, 10)}) : t('actionsPage.echeanceLabel'))),
            const SizedBox(height: 16),
            Text(t('actionsPage.avancementValeur', {'value': '$avancement'}), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Slider(value: avancement.toDouble(), min: 0, max: 100, divisions: 4, label: '$avancement%', onChanged: (v) => setState(() => avancement = v.round())),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : submit, child: Text(busy ? t('actionsPage.envoiEnCours') : t('actionsPage.enregistrer')))),
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
      title: Text(t('actionsPage.analyseCausesTitle')),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: methode, items: [DropdownMenuItem(value: '5_POURQUOI', child: Text(t('actionsPage.methode.cinqPourquoi'))), DropdownMenuItem(value: 'ISHIKAWA', child: Text(t('actionsPage.methode.ishikawa'))), DropdownMenuItem(value: 'AUTRE', child: Text(t('actionsPage.methode.autre')))], onChanged: (v) => setD(() => methode = v ?? '5_POURQUOI')),
        TextField(controller: desc, maxLines: 2, decoration: InputDecoration(labelText: t('actionsPage.descriptionCauseLabel'))),
        CheckboxListTile(contentPadding: EdgeInsets.zero, value: estRacine, title: Text(t('actionsPage.causeRacineCheckbox'), style: const TextStyle(fontSize: 13)), onChanged: (v) => setD(() => estRacine = v ?? false)),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t('actionsPage.annuler'))), FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(t('actionsPage.ajouter')))],
    )));
    if (ok != true || desc.text.trim().isEmpty) return;
    try { await api.post('/business/action-causes', {'methode': methode, 'description': desc.text.trim(), 'estRacine': estRacine, 'actionId': widget.actionId}); load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  Future<void> requestExtension() async {
    DateTime? newDate;
    final motif = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
      title: Text(t('actionsPage.prolongationTitle')),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        OutlinedButton.icon(
          onPressed: () async { final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365))); if (d != null) setD(() => newDate = d); },
          icon: const Icon(Icons.event), label: Text(newDate != null ? newDate!.toIso8601String().substring(0, 10) : t('actionsPage.choisirEcheance')),
        ),
        TextField(controller: motif, decoration: InputDecoration(labelText: t('actionsPage.motifLabel'))),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t('actionsPage.annuler'))), FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(t('actionsPage.confirmer')))],
    )));
    if (ok != true || newDate == null || motif.text.trim().isEmpty) return;
    try { await api.post('/business/actions/${widget.actionId}/extensions', {'nouvelleEcheance': newDate!.toIso8601String(), 'motif': motif.text.trim()}); load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  @override
  Widget build(BuildContext c) {
    if (loading) return Scaffold(appBar: AppBar(title: Text(t('actionsPage.detailTitle'))), body: const Center(child: CircularProgressIndicator()));
    if (error != null || action == null) return Scaffold(appBar: AppBar(title: Text(t('actionsPage.detailTitle'))), body: Center(child: Text(error ?? t('actionsPage.introuvable'))));
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
            Chip(label: Text(_capaStatusLabels()[a['status']] ?? a['status'])),
            if (a['actionType'] != null) Chip(label: Text(_capaTypeLabels()[a['actionType']] ?? a['actionType'])),
            if (a['criticite'] != null) Chip(label: Text(a['criticite']), backgroundColor: _capaCriticiteColor(a['criticite']).withOpacity(0.15)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            if (a['status'] == 'CLOSED') OutlinedButton(onPressed: busy ? null : reopen, child: Text(t('actionsPage.reouvrir')))
            else FilledButton(onPressed: busy || a['effectivenessResult'] != 'EFFICACE' || a['validationStatus'] == 'SOUMISE' || a['validationStatus'] == 'REJETEE' ? null : close, child: Text(t('actionsPage.cloturer'))),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: requestExtension, child: Text(t('actionsPage.prolonger'))),
          ]),
          const SizedBox(height: 16),
          Text(t('actionsPage.avancementValeur', {'value': '${a['avancement'] ?? 0}'}), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: (a['avancement'] ?? 0) / 100, minHeight: 8)),
          const SizedBox(height: 20),
          ValidationWorkflowSection(item: a, endpointBase: '/business/actions/${a['id']}', onChanged: load),
          const SizedBox(height: 12),
          HistorySection(module: 'ACTION', entityId: a['id']),
          const SizedBox(height: 12),

          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(t('actionsPage.sousActionsTitle'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            TextButton.icon(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => CapaFormPage(parentActionId: a['id']))).then((_) => load()), icon: const Icon(Icons.add, size: 16), label: Text(t('actionsPage.sousActionBtn'))),
          ]),
          if (subActions.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(t('actionsPage.aucuneSousAction'), style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
          else ...subActions.map((sa) => Card(child: ListTile(dense: true, title: Text('${sa['title']}'), subtitle: Text('${_capaStatusLabels()[sa['status']] ?? sa['status']} · ${sa['avancement'] ?? 0}%')))),

          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(t('actionsPage.causesTitle'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            TextButton.icon(onPressed: addCause, icon: const Icon(Icons.add, size: 16), label: Text(t('actionsPage.ajouter'))),
          ]),
          if (causes.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(t('actionsPage.aucuneCause'), style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
          else ...causes.map((cs) => Card(child: ListTile(dense: true, title: Text('${cs['description']}'), subtitle: Text('${cs['methode']}${cs['estRacine'] == true ? t('actionsPage.racineSuffix') : ''}')))),

          const SizedBox(height: 16),
          Text(t('actionsPage.verificationEfficaciteTitle'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          if (a['effectivenessResult'] != null) Text(t('actionsPage.dernierResultat', {'value': '${_capaEffLabels()[a['effectivenessResult']]}'}), style: TextStyle(color: a['effectivenessResult'] == 'EFFICACE' ? QhseColors.green : a['effectivenessResult'] == 'INEFFICACE' ? QhseColors.red : QhseColors.amber)),
          DropdownButtonFormField<String>(
            value: effResult.isEmpty ? null : effResult, decoration: InputDecoration(labelText: t('actionsPage.resultatLabel')),
            items: [DropdownMenuItem(value: 'EFFICACE', child: Text(t('actionsPage.eff.efficace'))), DropdownMenuItem(value: 'PARTIELLEMENT_EFFICACE', child: Text(t('actionsPage.eff.partiellementEfficace'))), DropdownMenuItem(value: 'INEFFICACE', child: Text(t('actionsPage.eff.inefficace')))],
            onChanged: (v) => setState(() => effResult = v ?? ''),
          ),
          TextField(controller: effNotes, decoration: InputDecoration(labelText: t('actionsPage.notesLabel'))),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: OutlinedButton(onPressed: busy || effResult.isEmpty ? null : saveEffectiveness, child: Text(t('actionsPage.enregistrerVerification')))),

          if (extensions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(t('actionsPage.prolongationsTitle'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ...extensions.map((ex) => Card(child: ListTile(dense: true, title: Text('${ex['nouvelleEcheance'].toString().substring(0, 10)}'), subtitle: Text('${ex['motif']}')))),
          ],
        ]),
      ),
    );
  }
}
