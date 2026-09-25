import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api.dart';
import '../services/sync_queue.dart';
import '../main.dart';
import '../theme.dart';
import 'attachment_helpers.dart';
import 'capa_link_widget.dart';
import 'document_link_widget.dart';
import 'load_error_view.dart';
import 'validation_history_widgets.dart';
import '../i18n/i18n.dart';

// Export CSV du registre (finding #30/#17 de l'audit — export manquant
// côté mobile pour les Audits, déjà présent côté web).
String _auditCsvEscape(String v) => v.contains(',') || v.contains('"') || v.contains('\n') ? '"${v.replaceAll('"', '""')}"' : v;

const _auditStatusLabels = {
  'DRAFT': 'auditsPageFlt.statut.draft', 'PLANNED': 'auditsPageFlt.statut.planned', 'TO_PREPARE': 'auditsPageFlt.statut.toPrepare', 'PREPARING': 'auditsPageFlt.statut.preparing',
  'READY': 'auditsPageFlt.statut.ready', 'IN_PROGRESS': 'auditsPageFlt.statut.inProgress', 'COMPLETED': 'auditsPageFlt.statut.completed', 'REPORT_PENDING': 'auditsPageFlt.statut.reportPending',
  'VALIDATION_PENDING': 'auditsPageFlt.statut.validationPending', 'VALIDATED': 'auditsPageFlt.statut.validated', 'CLOSED': 'auditsPageFlt.statut.closed',
  'POSTPONED': 'auditsPageFlt.statut.postponed', 'CANCELLED': 'auditsPageFlt.statut.cancelled',
};
String _statusLabel(dynamic s) => s != null && _auditStatusLabels[s] != null ? t(_auditStatusLabels[s]!) : (s?.toString() ?? '');
const _classificationLabels = {
  'CONFORME': 'auditsPageFlt.classification.conforme', 'POINT_FORT': 'auditsPageFlt.classification.pointFort', 'PISTE_AMELIORATION': 'auditsPageFlt.classification.pisteAmelioration',
  'OBSERVATION': 'auditsPageFlt.classification.observation', 'NC_MINEURE': 'auditsPageFlt.classification.ncMineure', 'NC_MAJEURE': 'auditsPageFlt.classification.ncMajeure',
};
String _classificationLabel(dynamic k) => k != null && _classificationLabels[k] != null ? t(_classificationLabels[k]!) : (k?.toString() ?? t('auditsPageFlt.classification.standard'));
const _resultatLabels = {
  'NON_EVALUE': 'auditsPageFlt.resultat.nonEvalue', 'CONFORME': 'auditsPageFlt.resultat.conforme', 'NON_CONFORME': 'auditsPageFlt.resultat.nonConforme',
  'PARTIELLEMENT_CONFORME': 'auditsPageFlt.resultat.partiellementConforme', 'NON_APPLICABLE': 'auditsPageFlt.resultat.nonApplicable', 'OBSERVATION': 'auditsPageFlt.resultat.observation',
  'PISTE_AMELIORATION': 'auditsPageFlt.resultat.pisteAmelioration', 'BONNE_PRATIQUE': 'auditsPageFlt.resultat.bonnePratique', 'A_VERIFIER': 'auditsPageFlt.resultat.aVerifier',
};

// --- Écran principal : tableau de bord + registre des audits ---
// Le paramétrage (types, référentiels, check-lists, programme, auditeurs,
// analyses) reste géré depuis le web ; cet écran couvre le cœur du travail
// terrain : consulter, réaliser et documenter un audit déjà programmé.
class AuditsPage extends StatefulWidget {
  const AuditsPage({super.key});
  @override
  State<AuditsPage> createState() => _AuditsPageState();
}

class _AuditsPageState extends State<AuditsPage> {
  final api = Api();
  List items = [];
  Map dashboard = {};
  List trends = [];
  List ncRecurrentes = [];
  Map? synthese;
  bool loading = true;
  Object? error;
  bool exporting = false;
  // Recherche harmonisée (audit priorité 7, finding #18).
  String search = '';

  Future<void> exportCsv() async {
    setState(() => exporting = true);
    try {
      final headers = ['Code', 'Titre', 'Type', 'Date', 'Statut', 'Score'];
      final buffer = StringBuffer();
      buffer.writeln(headers.map((v) => _auditCsvEscape(v)).join(','));
      for (final a in items) {
        buffer.writeln([
          a['code'], a['title'], a['type']?['label'] ?? '', _date(a['auditDate']),
          _statusLabel(a['status']), a['score'] != null ? '${a['score']}%' : '',
        ].map((v) => _auditCsvEscape('$v')).join(','));
      }
      final dir = await getTemporaryDirectory();
      final fileName = 'Audits-${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes([0xEF, 0xBB, 0xBF, ...buffer.toString().codeUnits]);
      await Share.shareXFiles([XFile(file.path)], text: 'Registre des audits');
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
      items = List.from(await api.get('/business/audits'));
      dashboard = Map.from(await api.get('/business/audit-dashboard'));
      trends = List.from(await api.get('/business/audit-trends'));
      ncRecurrentes = List.from(await api.get('/business/audit-nc-recurrentes'));
    } catch (e) { error = e; }
    setState(() => loading = false);
  }

  Future<void> loadSynthese() async {
    try { synthese = Map.from(await api.get('/business/audit-synthese-direction')); setState(() {}); } catch (_) {}
  }

  @override
  Widget build(BuildContext c) => DefaultTabController(
    length: 3,
    child: Scaffold(
      appBar: AppBar(
        title: Text(t('auditsPageFlt.titre')),
        actions: [
          IconButton(icon: exporting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.ios_share), tooltip: t('auditsPageFlt.exporterTooltip'), onPressed: exporting ? null : exportCsv),
          IconButton(icon: const Icon(Icons.people_outline), tooltip: t('auditsPageFlt.auditeursTooltip'), onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const AuditeursPage()))),
          IconButton(icon: const Icon(Icons.settings_outlined), tooltip: t('auditsPageFlt.parametrageTooltip'), onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const AuditParametragePage())).then((_) => load())),
        ],
        bottom: TabBar(tabs: [Tab(text: t('auditsPageFlt.ongletApercu')), Tab(text: t('auditsPageFlt.ongletRegistre')), Tab(text: t('auditsPageFlt.ongletAnalyses'))]),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const AuditFormPage())).then((_) => load()),
        icon: const Icon(Icons.add),
        label: Text(t('auditsPageFlt.planifierBtn')),
      ),
      body: loading ? const Center(child: CircularProgressIndicator()) : error != null ? LoadErrorView(error: error, onRetry: load) : TabBarView(children: [_buildApercu(c), _buildRegistre(c), _buildAnalyses(c)]),
    ),
  );

  Widget _buildApercu(BuildContext c) => RefreshIndicator(
    onRefresh: load,
    child: ListView(padding: const EdgeInsets.all(12), children: [
      KpiBar([
        KpiStat(t('auditsPageFlt.kpiAuProgramme'), '${dashboard['total'] ?? items.length}', color: QhseColors.blue, icon: Icons.assignment_turned_in_outlined),
        KpiStat(t('auditsPageFlt.kpiEnCours'), '${dashboard['enCours'] ?? 0}', color: QhseColors.blue, icon: Icons.schedule),
        KpiStat(t('auditsPageFlt.kpiRealises'), '${dashboard['realises'] ?? 0}', color: QhseColors.green, icon: Icons.check_circle_outline),
        KpiStat(t('auditsPageFlt.kpiEnRetard'), '${dashboard['enRetard'] ?? 0}', color: (dashboard['enRetard'] ?? 0) > 0 ? QhseColors.red : QhseColors.green, icon: Icons.warning_amber_outlined),
      ]),
      const SizedBox(height: 8),
      KpiBar([
        KpiStat(t('auditsPageFlt.kpiTauxConformite'), '${dashboard['tauxConformite'] ?? '—'}%', color: QhseColors.green, icon: Icons.shield_outlined),
        KpiStat(t('auditsPageFlt.kpiScoreMoyen'), '${dashboard['scoreMoyen'] ?? '—'}', color: QhseColors.blue, icon: Icons.assessment_outlined),
        KpiStat(t('auditsPageFlt.kpiNcMajeures'), '${dashboard['ncMajeures'] ?? 0}', color: (dashboard['ncMajeures'] ?? 0) > 0 ? QhseColors.red : QhseColors.green, icon: Icons.error_outline),
        KpiStat(t('auditsPageFlt.kpiConstatsOuverts'), '${dashboard['constatsOuverts'] ?? 0}', color: (dashboard['constatsOuverts'] ?? 0) > 0 ? QhseColors.amber : QhseColors.green, icon: Icons.fact_check_outlined),
      ]),
    ]),
  );

  List get _filteredAudits {
    if (search.trim().isEmpty) return items;
    final q = search.trim().toLowerCase();
    return items.where((a) => ('${a['code'] ?? ''} ${a['title'] ?? ''} ${a['type']?['label'] ?? ''}').toLowerCase().contains(q)).toList();
  }

  Widget _buildRegistre(BuildContext c) => RefreshIndicator(
    onRefresh: load,
    child: Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          decoration: InputDecoration(prefixIcon: const Icon(Icons.search, size: 18), hintText: t('auditsPageFlt.rechercheHint'), isDense: true, border: const OutlineInputBorder()),
          onChanged: (v) => setState(() => search = v),
        ),
      ),
      Expanded(
        child: _filteredAudits.isEmpty
            ? ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(search.trim().isEmpty ? t('auditsPageFlt.aucunAuditPlanifie') : t('auditsPageFlt.aucunResultatRecherche'))))])
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _filteredAudits.length,
                itemBuilder: (_, i) {
                  final a = _filteredAudits[i];
                  return Card(child: ListTile(
                    leading: const Icon(Icons.assignment_turned_in, size: 32),
                    title: Text('${a['code']} — ${a['title']}'),
                    subtitle: Text('${_statusLabel(a['status'])} · ${_date(a['auditDate'])}${a['type'] != null ? ' · ${a['type']['label']}' : ''}'),
                    trailing: a['score'] != null ? Text('${a['score']}%', style: const TextStyle(fontWeight: FontWeight.bold)) : null,
                    onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => AuditDetailPage(auditId: a['id']))).then((_) => load()),
                  ));
                },
              ),
      ),
    ]),
  );

  String _date(dynamic v) => v == null ? '' : v.toString().substring(0, 10);

  Widget _buildAnalyses(BuildContext c) => RefreshIndicator(
    onRefresh: load,
    child: ListView(padding: const EdgeInsets.all(12), children: [
      Text(t('auditsPageFlt.tendanceTitre'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      const SizedBox(height: 8),
      SizedBox(height: 200, child: trends.isEmpty ? Center(child: Text(t('auditsPageFlt.pasAssezDeDonnees'), style: TextStyle(color: QhseColors.textSecondary))) : _AuditTrendChart(trends: trends)),
      const SizedBox(height: 20),
      Text(t('auditsPageFlt.ncRecurrentesTitre', {'count': '${ncRecurrentes.length}'}), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      const SizedBox(height: 8),
      if (ncRecurrentes.isEmpty)
        Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(t('auditsPageFlt.aucuneRecurrence'), style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
      else
        ...ncRecurrentes.map((r) => Card(child: ListTile(
              dense: true,
              title: Text('${r['description'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text('${r['processus']} · ${t('auditsPageFlt.occurrences', {'count': '${r['occurrences']}'})}'),
              trailing: Icon(Icons.repeat, color: QhseColors.amber),
            ))),
      const SizedBox(height: 20),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(t('auditsPageFlt.syntheseDirectionTitre'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        TextButton.icon(onPressed: loadSynthese, icon: const Icon(Icons.summarize_outlined, size: 16), label: Text(t('auditsPageFlt.genererBtn'))),
      ]),
      if (synthese != null) ...[
        const SizedBox(height: 8),
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('auditsPageFlt.genereLe', {'date': _date(synthese!['genereLe'])}), style: TextStyle(fontSize: 11, color: QhseColors.textSecondary)),
          const SizedBox(height: 10),
          Text(t('auditsPageFlt.processusPlusPerformants'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ...List.from(synthese!['processusLesPlusPerformants'] ?? []).map((p) => Text('• ${p['processus']} — ${p['tauxConformiteMoyen'] ?? '—'}%', style: const TextStyle(fontSize: 12))),
          const SizedBox(height: 10),
          Text(t('auditsPageFlt.processusPlusProblematiques'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ...List.from(synthese!['processusLesPlusProblematiques'] ?? []).map((p) => Text('• ${p['processus']} — ${p['tauxConformiteMoyen'] ?? '—'}%', style: const TextStyle(fontSize: 12))),
        ]))),
      ],
      const SizedBox(height: 20),
      Text(t('auditsPageFlt.comparaisonPeriodesTitre'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      const SizedBox(height: 8),
      const _AuditComparaisonPanel(),
    ]),
  );
}

/// Évolution mensuelle du nombre d'audits réalisés et du taux de conformité
/// moyen (même style fl_chart que les autres modules de l'application).
class _AuditTrendChart extends StatelessWidget {
  final List trends;
  const _AuditTrendChart({required this.trends});

  @override
  Widget build(BuildContext context) {
    final spots = [for (int i = 0; i < trends.length; i++) FlSpot(i.toDouble(), ((trends[i]['realises'] ?? 0) as num).toDouble())];
    return LineChart(LineChartData(
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
      lineBarsData: [LineChartBarData(spots: spots, isCurved: true, color: QhseColors.blue, barWidth: 2, dotData: const FlDotData(show: true), belowBarData: BarAreaData(show: true, color: QhseColors.blue.withOpacity(0.08)))],
    ));
  }
}

/// Formulaire de comparaison de deux périodes (point 34 du cahier des
/// charges) — recompose les mêmes KPI que le tableau de bord.
class _AuditComparaisonPanel extends StatefulWidget {
  const _AuditComparaisonPanel();
  @override
  State<_AuditComparaisonPanel> createState() => _AuditComparaisonPanelState();
}

class _AuditComparaisonPanelState extends State<_AuditComparaisonPanel> {
  final api = Api();
  DateTime? debut1, fin1, debut2, fin2;
  Map? result;
  bool busy = false;

  Future<void> pick(void Function(DateTime) set) async {
    final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (d != null) setState(() => set(d));
  }

  String _f(DateTime? d) => d == null ? '—' : d.toIso8601String().substring(0, 10);

  Future<void> compare() async {
    if (debut1 == null || fin1 == null || debut2 == null || fin2 == null) return;
    setState(() => busy = true);
    try {
      result = Map.from(await api.get('/business/audit-comparaison?debut1=${debut1!.toIso8601String()}&fin1=${fin1!.toIso8601String()}&debut2=${debut2!.toIso8601String()}&fin2=${fin2!.toIso8601String()}'));
    } catch (_) {}
    setState(() => busy = false);
  }

  @override
  Widget build(BuildContext c) => Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t('auditsPageFlt.periode1'), style: TextStyle(fontSize: 12, color: QhseColors.textSecondary)),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => pick((d) => debut1 = d), child: Text(t('auditsPageFlt.debutLabel', {'date': _f(debut1)})))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton(onPressed: () => pick((d) => fin1 = d), child: Text(t('auditsPageFlt.finLabel', {'date': _f(fin1)})))),
        ]),
        const SizedBox(height: 10),
        Text(t('auditsPageFlt.periode2'), style: TextStyle(fontSize: 12, color: QhseColors.textSecondary)),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => pick((d) => debut2 = d), child: Text(t('auditsPageFlt.debutLabel', {'date': _f(debut2)})))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton(onPressed: () => pick((d) => fin2 = d), child: Text(t('auditsPageFlt.finLabel', {'date': _f(fin2)})))),
        ]),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : compare, child: Text(busy ? '…' : t('auditsPageFlt.comparerBtn')))),
        if (result != null) ...[
          const SizedBox(height: 12),
          Table(children: [
            TableRow(children: [const Text(''), Text(t('auditsPageFlt.periode1'), style: const TextStyle(fontWeight: FontWeight.bold)), Text(t('auditsPageFlt.periode2'), style: const TextStyle(fontWeight: FontWeight.bold))]),
            TableRow(children: [Text(t('auditsPageFlt.rowAudits')), Text('${result!['periode1']['nombreAudits']}'), Text('${result!['periode2']['nombreAudits']}')]),
            TableRow(children: [Text(t('auditsPageFlt.rowTauxConformite')), Text('${result!['periode1']['tauxConformiteMoyen'] ?? '—'}%'), Text('${result!['periode2']['tauxConformiteMoyen'] ?? '—'}%')]),
            TableRow(children: [Text(t('auditsPageFlt.rowScoreMoyen')), Text('${result!['periode1']['scoreMoyen'] ?? '—'}'), Text('${result!['periode2']['scoreMoyen'] ?? '—'}')]),
            TableRow(children: [Text(t('auditsPageFlt.rowNcMajeures')), Text('${result!['periode1']['ncMajeures']}'), Text('${result!['periode2']['ncMajeures']}')]),
            TableRow(children: [Text(t('auditsPageFlt.rowNcMineures')), Text('${result!['periode1']['ncMineures']}'), Text('${result!['periode2']['ncMineures']}')]),
          ]),
        ],
      ])));
}

// --- Détail d'un audit : check-list, constats, signatures, actions ---
class AuditDetailPage extends StatefulWidget {
  final String auditId;
  const AuditDetailPage({super.key, required this.auditId});
  @override
  State<AuditDetailPage> createState() => _AuditDetailPageState();
}

const _signatureRoleLabels = {
  'AUDITEUR': 'auditsPageFlt.role.auditeur', 'RESPONSABLE_AUDITE': 'auditsPageFlt.role.responsableAudite',
  'RESPONSABLE_QHSE': 'auditsPageFlt.role.responsableQhse', 'VALIDATEUR': 'auditsPageFlt.role.validateur',
};
String _roleLabel(dynamic r) => r != null && _signatureRoleLabels[r] != null ? t(_signatureRoleLabels[r]!) : (r?.toString() ?? '');

class _AuditDetailPageState extends State<AuditDetailPage> {
  final api = Api();
  Map? audit;
  List users = [];
  bool loading = true;
  String? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      audit = Map.from(await api.get('/business/audits/${widget.auditId}'));
      users = List.from(await api.get('/users'));
    }
    catch (e) { error = '$e'; }
    setState(() => loading = false);
  }

  Future<void> saveResponse(String itemId, Map patch) async {
    try { await api.post('/business/audits/${widget.auditId}/responses/$itemId', patch); load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  Future<void> addSignatureRole(String role) async {
    try { await api.post('/business/audits/${widget.auditId}/signatures', {'role': role}); load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  Future<void> signAs(String signatureId, String signataireId) async {
    try { await api.post('/business/audit-signatures/$signatureId/sign', {'signataireId': signataireId}); load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  @override
  Widget build(BuildContext c) {
    if (loading) return Scaffold(appBar: AppBar(title: Text(t('auditsPageFlt.auditTitreGenerique'))), body: const Center(child: CircularProgressIndicator()));
    if (error != null || audit == null) return Scaffold(appBar: AppBar(title: Text(t('auditsPageFlt.auditTitreGenerique'))), body: Center(child: Text(error ?? t('auditsPageFlt.introuvable'))));
    final a = audit!;
    final checklist = a['checklist'];
    final responses = List.from(a['responses'] ?? []);
    final findings = List.from(a['auditFindings'] ?? []);
    final signatures = List.from(a['signatures'] ?? []);

    return Scaffold(
      appBar: AppBar(title: Text(a['title'] ?? ''), actions: [
        IconButton(icon: const Icon(Icons.camera_alt_outlined), onPressed: () => captureAndLinkPhoto(context, api, 'AUDIT', a['id'])),
        IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => AuditFormPage(record: a))).then((_) => load())),
      ]),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Text('${_statusLabel(a['status'])} · ${a['auditDate'].toString().substring(0, 10)}', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)),
          if (a['independenceWarning'] == true)
            Container(margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: QhseColors.amber.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: Text(t('auditsPageFlt.avertissementIndependance'), style: TextStyle(color: QhseColors.amber, fontSize: 12))),
          if (a['scoreObtenu'] != null || a['tauxConformite'] != null) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _scoreCard(t('auditsPageFlt.scoreLabel'), a['scoreObtenu'] != null ? '${a['scoreObtenu']} / ${a['scoreMax']}' : '—')),
              const SizedBox(width: 8),
              Expanded(child: _scoreCard(t('auditsPageFlt.kpiTauxConformite'), a['tauxConformite'] != null ? '${a['tauxConformite']}%' : '—')),
            ]),
          ],

          if (checklist != null) ...[
            const SizedBox(height: 20),
            Text(t('auditsPageFlt.checklistTitre', {'titre': '${checklist['title']}', 'count': '${(checklist['items'] as List).length}'}), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            ...List.from(checklist['items']).map((it) {
              final resp = responses.firstWhere((r) => r['checklistItemId'] == it['id'], orElse: () => null);
              return Card(child: Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${it['numero'] != null ? '${it['numero']}. ' : ''}${it['question']}', style: const TextStyle(fontSize: 13)),
                if (it['critereAttendu'] != null) Text(t('auditsPageFlt.critereAttenduLabel', {'critere': '${it['critereAttendu']}'}), style: TextStyle(fontSize: 11, color: QhseColors.textSecondary)),
                const SizedBox(height: 6),
                DropdownButton<String>(
                  value: resp?['resultat'] ?? 'NON_EVALUE', isDense: true, isExpanded: true,
                  items: _resultatLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(t(e.value), style: const TextStyle(fontSize: 12)))).toList(),
                  onChanged: (v) => saveResponse(it['id'], {'resultat': v, 'score': resp?['score'], 'commentaire': resp?['commentaire']}),
                ),
              ])));
            }),
          ],

          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(t('auditsPageFlt.constatsTitre', {'count': '${findings.length}'}), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            TextButton.icon(onPressed: () => showAddFindingDialog(context, api, auditId: a['id'], onSaved: load), icon: const Icon(Icons.add, size: 16), label: Text(t('auditsPageFlt.constatBtn'))),
          ]),
          if (findings.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(t('auditsPageFlt.aucunConstat'), style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
          else
            ...findings.map((f) => Card(child: Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(f['description'] ?? '', style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('${_classificationLabel(f['classification'])}${f['criticite'] != null ? ' · ${f['criticite']}' : ''}${f['nonConformityId'] != null ? ' · ${t('auditsPageFlt.ncGeneree')}' : ''}${f['riskId'] != null ? ' · ${t('auditsPageFlt.risqueGenere')}' : ''}', style: TextStyle(fontSize: 11, color: QhseColors.textSecondary)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, children: [
                    if (f['nonConformityId'] == null) _actionChip(context, t('auditsPageFlt.chipNc'), QhseColors.red, () async { await api.post('/business/audit-findings/${f['id']}/generate-nc', {}); load(); }),
                    if (f['riskId'] == null) _actionChip(context, t('auditsPageFlt.chipRisque'), QhseColors.amber, () async { await api.post('/business/audit-findings/${f['id']}/generate-risk', {}); load(); }),
                    _actionChip(context, t('auditsPageFlt.chipAction'), QhseColors.blue, () async { await api.post('/business/audit-findings/${f['id']}/generate-action', {}); load(); }),
                  ]),
                ])))),

          const SizedBox(height: 20),
          Text(t('auditsPageFlt.signaturesTitre'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final entry in _signatureRoleLabels.entries)
              if (!signatures.any((s) => s['role'] == entry.key))
                ActionChip(
                  label: Text('+ ${t(entry.value)}', style: TextStyle(fontSize: 11, color: QhseColors.textSecondary)),
                  backgroundColor: QhseColors.cardAlt,
                  onPressed: () => addSignatureRole(entry.key),
                ),
          ]),
          const SizedBox(height: 6),
          if (signatures.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(t('auditsPageFlt.aucuneSignature'), style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
          else
            ...signatures.map((s) => Card(child: ListTile(
                  dense: true,
                  title: Text(_roleLabel(s['role'])),
                  subtitle: s['statut'] == 'SIGNE'
                      ? Text(t('auditsPageFlt.signePar', {'nom': '${s['signataire']?['firstName'] ?? ''} ${s['signataire']?['lastName'] ?? ''}', 'date': s['signedAt'].toString().substring(0, 10)}), style: TextStyle(color: QhseColors.green, fontSize: 11))
                      : DropdownButton<String>(
                          isDense: true,
                          hint: Text(t('auditsPageFlt.signerEnTantQue'), style: TextStyle(fontSize: 11, color: QhseColors.textSecondary)),
                          items: users.map<DropdownMenuItem<String>>((u) => DropdownMenuItem(value: u['id'] as String, child: Text('${u['firstName']} ${u['lastName']}', style: const TextStyle(fontSize: 12)))).toList(),
                          onChanged: (v) { if (v != null) signAs(s['id'], v); },
                        ),
                ))),

          const SizedBox(height: 20),
          CapaLinksSection(sourceModule: 'AUDIT', sourceEntityId: a['id'], prefill: {'title': t('auditsPageFlt.suiteAuditPrefill', {'titre': '${a['title']}'}), 'source': 'AUDIT'}),
          const SizedBox(height: 12),
          HistorySection(module: 'AUDIT', entityId: a['id']),
          DocumentLinksSection(sourceModule: 'AUDIT', sourceEntityId: a['id']),
        ]),
      ),
    );
  }

  Widget _scoreCard(String label, String value) => Card(child: Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, color: QhseColors.textSecondary)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ])));

  Widget _actionChip(BuildContext c, String label, Color color, VoidCallback onTap) => ActionChip(
        label: Text(label, style: TextStyle(fontSize: 11, color: color)),
        backgroundColor: color.withOpacity(0.15),
        onPressed: () async { onTap(); },
      );
}

Future<void> showAddFindingDialog(BuildContext context, Api api, {required String auditId, required VoidCallback onSaved}) async {
  final description = TextEditingController();
  String classification = '';
  String criticite = '';
  bool critical = false;
  bool saving = false;
  String? error;
  await showDialog(context: context, builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
    title: Text(t('auditsPageFlt.nouveauConstatTitre')),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: description, maxLines: 3, decoration: InputDecoration(labelText: t('auditsPageFlt.descriptionLabel'))),
      DropdownButtonFormField<String>(
        value: classification.isEmpty ? null : classification, isExpanded: true, decoration: InputDecoration(labelText: t('auditsPageFlt.classificationLabel')),
        items: _classificationLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(t(e.value)))).toList(),
        onChanged: (v) => setD(() => classification = v ?? ''),
      ),
      DropdownButtonFormField<String>(
        value: criticite.isEmpty ? null : criticite, isExpanded: true, decoration: InputDecoration(labelText: t('auditsPageFlt.criticiteLabel')),
        items: [DropdownMenuItem(value: 'FAIBLE', child: Text(t('auditsPageFlt.criticiteFaible'))), DropdownMenuItem(value: 'MODEREE', child: Text(t('auditsPageFlt.criticiteModeree'))), DropdownMenuItem(value: 'ELEVEE', child: Text(t('auditsPageFlt.criticiteElevee'))), DropdownMenuItem(value: 'CRITIQUE', child: Text(t('auditsPageFlt.criticiteCritique')))],
        onChanged: (v) => setD(() => criticite = v ?? ''),
      ),
      CheckboxListTile(contentPadding: EdgeInsets.zero, value: critical, title: Text(t('auditsPageFlt.constatCritiqueLabel'), style: const TextStyle(fontSize: 13)), onChanged: (v) => setD(() => critical = v ?? false)),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
    ])),
    actions: [
      TextButton(onPressed: () => Navigator.pop(c), child: Text(t('auditsPageFlt.annulerBtn'))),
      FilledButton(onPressed: saving ? null : () async {
        if (description.text.trim().isEmpty) { setD(() => error = t('auditsPageFlt.descriptionObligatoire')); return; }
        setD(() => saving = true);
        try {
          await api.post('/business/audits/$auditId/findings', {'description': description.text.trim(), 'classification': classification.isEmpty ? null : classification, 'criticite': criticite.isEmpty ? null : criticite, 'critical': critical});
          if (context.mounted) Navigator.pop(c);
          onSaved();
        } catch (e) { setD(() { saving = false; error = '$e'; }); }
      }, child: Text(saving ? '…' : t('auditsPageFlt.ajouterBtn'))),
    ],
  )));
}

// --- Formulaire de planification / modification ---
class AuditFormPage extends StatefulWidget {
  final Map? record;
  const AuditFormPage({super.key, this.record});
  @override
  State<AuditFormPage> createState() => _AuditFormPageState();
}

class _AuditFormPageState extends State<AuditFormPage> {
  final api = Api();
  bool get editing => widget.record != null;
  List types = [], referentials = [], workUnits = [], processus = [], users = [], checklists = [];
  final title = TextEditingController();
  final reference = TextEditingController();
  final objectif = TextEditingController();
  DateTime auditDate = DateTime.now().add(const Duration(days: 7));
  String? typeId, referentialId, workUnitId, processusId, auditorId, responsableAuditeId, checklistId;
  String status = 'PLANNED';
  bool busy = false, loadingLists = true;
  String? error;

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    if (r != null) {
      title.text = r['title'] ?? '';
      reference.text = r['reference'] ?? '';
      objectif.text = r['objectif'] ?? '';
      auditDate = DateTime.tryParse(r['auditDate'] ?? '') ?? auditDate;
      typeId = r['typeId']; referentialId = r['referentialId']; workUnitId = r['workUnitId'];
      processusId = r['processusId']; auditorId = r['auditorId']; responsableAuditeId = r['responsableAuditeId'];
      checklistId = r['checklistId']; status = r['status'] ?? 'PLANNED';
    }
    loadLists();
  }

  Future<void> loadLists() async {
    try {
      types = List.from(await api.get('/business/audit-types'));
      referentials = List.from(await api.get('/business/audit-referentials'));
      workUnits = List.from(await api.get('/business/work-units'));
      processus = List.from(await api.get('/business/processus'));
      users = List.from(await api.get('/users'));
      checklists = List.from(await api.get('/business/audit-checklists'));
    } catch (_) {}
    setState(() => loadingLists = false);
  }

  Future<void> pickDate() async {
    final d = await showDatePicker(context: context, initialDate: auditDate, firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 730)));
    if (d != null) setState(() => auditDate = d);
  }

  Future<void> submit() async {
    if (title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('auditsPageFlt.titreObligatoire'))));
      return;
    }
    setState(() { busy = true; error = null; });
    final payload = {
      'title': title.text.trim(), 'reference': reference.text.trim().isEmpty ? null : reference.text.trim(),
      'objectif': objectif.text.trim().isEmpty ? null : objectif.text.trim(),
      'auditDate': auditDate.toIso8601String(), 'status': status,
      'typeId': typeId, 'referentialId': referentialId, 'workUnitId': workUnitId, 'processusId': processusId,
      'auditorId': auditorId, 'responsableAuditeId': responsableAuditeId, 'checklistId': checklistId,
    };
    try {
      if (editing) {
        await api.patch('/business/audits/${widget.record!['id']}', payload);
      } else {
        await api.post('/business/audits', {'code': genCode('AUD'), ...payload});
      }
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (e.networkError && !editing) {
        await SyncQueue.enqueue('audit', 'CREATE', {'code': genCode('AUD'), ...payload});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('auditsPageFlt.horsLigneMessage')), duration: const Duration(seconds: 4)));
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
    appBar: AppBar(title: Text(editing ? t('auditsPageFlt.modifierAuditTitre') : t('auditsPageFlt.planifierAuditTitre'))),
    body: loadingLists
        ? const Center(child: CircularProgressIndicator())
        : ListView(padding: const EdgeInsets.all(16), children: [
            TextField(controller: title, decoration: InputDecoration(labelText: t('auditsPageFlt.titreLabel'))),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: typeId, isExpanded: true, decoration: InputDecoration(labelText: t('auditsPageFlt.typeAuditLabel')),
              items: [DropdownMenuItem<String>(value: null, child: Text(t('auditsPageFlt.tiretVide'))), ...types.map<DropdownMenuItem<String>>((tp) => DropdownMenuItem<String>(value: tp['id'] as String, child: Text(tp['label'] ?? '')))],
              onChanged: (v) => setState(() => typeId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: referentialId, isExpanded: true, decoration: InputDecoration(labelText: t('auditsPageFlt.referentielLabel')),
              items: [DropdownMenuItem<String>(value: null, child: Text(t('auditsPageFlt.tiretVide'))), ...referentials.map<DropdownMenuItem<String>>((r) => DropdownMenuItem<String>(value: r['id'] as String, child: Text(r['label'] ?? '')))],
              onChanged: (v) => setState(() => referentialId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: checklistId, isExpanded: true, decoration: InputDecoration(labelText: t('auditsPageFlt.checklistAppliqueeLabel')),
              items: [DropdownMenuItem<String>(value: null, child: Text(t('auditsPageFlt.tiretVide'))), ...checklists.map<DropdownMenuItem<String>>((cl) => DropdownMenuItem<String>(value: cl['id'] as String, child: Text(cl['title'] ?? '')))],
              onChanged: (v) => setState(() => checklistId = v),
            ),
            const SizedBox(height: 12),
            TextField(controller: reference, decoration: InputDecoration(labelText: t('auditsPageFlt.referenceLabel'))),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: pickDate, icon: const Icon(Icons.event), label: Text(t('auditsPageFlt.dateLabel', {'date': auditDate.toIso8601String().substring(0, 10)}))),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: workUnitId, isExpanded: true, decoration: InputDecoration(labelText: t('auditsPageFlt.uniteTravailLabel')),
              items: [DropdownMenuItem<String>(value: null, child: Text(t('auditsPageFlt.tiretVide'))), ...workUnits.map<DropdownMenuItem<String>>((w) => DropdownMenuItem<String>(value: w['id'] as String, child: Text(w['name'] ?? '')))],
              onChanged: (v) => setState(() => workUnitId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: processusId, isExpanded: true, decoration: InputDecoration(labelText: t('auditsPageFlt.processusLabel')),
              items: [DropdownMenuItem<String>(value: null, child: Text(t('auditsPageFlt.tiretVide'))), ...processus.map<DropdownMenuItem<String>>((p) => DropdownMenuItem<String>(value: p['id'] as String, child: Text(p['nom'] ?? '')))],
              onChanged: (v) => setState(() => processusId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: auditorId, isExpanded: true, decoration: InputDecoration(labelText: t('auditsPageFlt.auditeurLabel')),
              items: [DropdownMenuItem<String>(value: null, child: Text(t('auditsPageFlt.tiretVide'))), ...users.map<DropdownMenuItem<String>>((u) => DropdownMenuItem<String>(value: u['id'] as String, child: Text('${u['firstName']} ${u['lastName']}')))],
              onChanged: (v) => setState(() => auditorId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: responsableAuditeId, isExpanded: true, decoration: InputDecoration(labelText: t('auditsPageFlt.responsableAuditeLabel')),
              items: [DropdownMenuItem<String>(value: null, child: Text(t('auditsPageFlt.tiretVide'))), ...users.map<DropdownMenuItem<String>>((u) => DropdownMenuItem<String>(value: u['id'] as String, child: Text('${u['firstName']} ${u['lastName']}')))],
              onChanged: (v) => setState(() => responsableAuditeId = v),
            ),
            const SizedBox(height: 12),
            TextField(controller: objectif, decoration: InputDecoration(labelText: t('auditsPageFlt.objectifLabel'))),
            if (editing) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: status, isExpanded: true, decoration: InputDecoration(labelText: t('auditsPageFlt.statutLabel')),
                items: _auditStatusLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(t(e.value)))).toList(),
                onChanged: (v) => setState(() => status = v ?? 'PLANNED'),
              ),
            ],
            if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : submit, child: Text(busy ? t('auditsPageFlt.envoiEnCours') : editing ? t('auditsPageFlt.enregistrerBtn') : t('auditsPageFlt.planifierBtn')))),
          ]),
  );
}

// --- Auditeurs : profils, compétences, charge et indépendance ---
class AuditeursPage extends StatefulWidget {
  const AuditeursPage({super.key});
  @override
  State<AuditeursPage> createState() => _AuditeursPageState();
}

class _AuditeursPageState extends State<AuditeursPage> {
  final api = Api();
  List items = [];
  bool loading = true;
  Object? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try { items = List.from(await api.get('/business/auditeurs')); } catch (e) { error = e; }
    setState(() => loading = false);
  }

  Future<void> editProfile(Map u) async {
    final profile = Map.from(u['profile'] ?? {});
    final competence = TextEditingController(text: profile['competence'] ?? '');
    final formation = TextEditingController(text: profile['formation'] ?? '');
    final experience = TextEditingController(text: '${profile['experienceAnnees'] ?? ''}');
    final habilitation = TextEditingController(text: profile['habilitation'] ?? '');
    bool disponible = profile['disponible'] ?? true;
    await showDialog(context: context, builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
      title: Text('${u['firstName']} ${u['lastName']}'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: competence, decoration: InputDecoration(labelText: t('auditsPageFlt.competenceLabel'))),
        TextField(controller: formation, decoration: InputDecoration(labelText: t('auditsPageFlt.formationLabel'))),
        TextField(controller: experience, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('auditsPageFlt.experienceLabel'))),
        TextField(controller: habilitation, decoration: InputDecoration(labelText: t('auditsPageFlt.habilitationLabel'))),
        CheckboxListTile(contentPadding: EdgeInsets.zero, value: disponible, title: Text(t('auditsPageFlt.disponibleLabel'), style: const TextStyle(fontSize: 13)), onChanged: (v) => setD(() => disponible = v ?? true)),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(t('auditsPageFlt.annulerBtn'))),
        FilledButton(onPressed: () async {
          try {
            await api.patch('/business/auditeurs/${u['id']}/profile', {
              'competence': competence.text.trim().isEmpty ? null : competence.text.trim(),
              'formation': formation.text.trim().isEmpty ? null : formation.text.trim(),
              'experienceAnnees': int.tryParse(experience.text.trim()),
              'habilitation': habilitation.text.trim().isEmpty ? null : habilitation.text.trim(),
              'disponible': disponible,
            });
            if (c.mounted) Navigator.pop(c);
            load();
          } catch (e) { if (c.mounted) ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text('$e'))); }
        }, child: Text(t('auditsPageFlt.enregistrerBtn'))),
      ],
    )));
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text(t('auditsPageFlt.auditeursTitre'))),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
            ? LoadErrorView(error: error, onRetry: load)
        : RefreshIndicator(
            onRefresh: load,
            child: items.isEmpty
                ? ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(t('auditsPageFlt.aucunAuditeur'))))])
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final u = items[i];
                      final profile = u['profile'];
                      return Card(child: ListTile(
                        leading: CircleAvatar(child: Text('${u['firstName']?[0] ?? '?'}')),
                        title: Text('${u['firstName']} ${u['lastName']}'),
                        subtitle: Text(t('auditsPageFlt.auditeurSubtitle', {'realises': '${u['nombreAuditsRealises']}', 'enCours': '${u['nombreAuditsEnCours']}'}) + (u['performanceMoyenne'] != null ? ' · ${t('auditsPageFlt.scoreMoyenInline', {'valeur': '${u['performanceMoyenne']}'})}' : '') + (profile != null && profile['disponible'] == false ? ' · ${t('auditsPageFlt.indisponible')}' : '')),
                        trailing: IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => editProfile(u)),
                      ));
                    },
                  ),
          ),
  );
}

// --- Paramétrage : types, référentiels, check-lists, programme d'audit ---
class AuditParametragePage extends StatefulWidget {
  const AuditParametragePage({super.key});
  @override
  State<AuditParametragePage> createState() => _AuditParametragePageState();
}

class _AuditParametragePageState extends State<AuditParametragePage> {
  @override
  Widget build(BuildContext c) => DefaultTabController(
    length: 4,
    child: Scaffold(
      appBar: AppBar(title: Text(t('auditsPageFlt.parametrageTitre')), bottom: TabBar(isScrollable: true, tabs: [Tab(text: t('auditsPageFlt.ongletTypes')), Tab(text: t('auditsPageFlt.ongletReferentiels')), Tab(text: t('auditsPageFlt.ongletChecklists')), Tab(text: t('auditsPageFlt.ongletProgramme'))])),
      body: const TabBarView(children: [_AuditTypesTab(), _AuditReferentialsTab(), _AuditChecklistsTab(), _AuditProgramTab()]),
    ),
  );
}

class _AuditTypesTab extends StatefulWidget {
  const _AuditTypesTab();
  @override
  State<_AuditTypesTab> createState() => _AuditTypesTabState();
}

class _AuditTypesTabState extends State<_AuditTypesTab> {
  final api = Api();
  List items = [];
  bool loading = true;
  Object? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try { items = List.from(await api.get('/business/audit-types')); } catch (e) { error = e; }
    setState(() => loading = false);
  }

  Future<void> addDialog() async {
    final label = TextEditingController();
    await showDialog(context: context, builder: (c) => AlertDialog(
      title: Text(t('auditsPageFlt.nouveauTypeTitre')),
      content: TextField(controller: label, decoration: InputDecoration(labelText: t('auditsPageFlt.libelleLabel'))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(t('auditsPageFlt.annulerBtn'))),
        FilledButton(onPressed: () async {
          if (label.text.trim().isEmpty) return;
          await api.post('/business/audit-types', {'code': genCode('ATY'), 'label': label.text.trim()});
          if (c.mounted) Navigator.pop(c);
          load();
        }, child: Text(t('auditsPageFlt.ajouterBtn'))),
      ],
    ));
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    floatingActionButton: FloatingActionButton(onPressed: addDialog, child: const Icon(Icons.add)),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
            ? LoadErrorView(error: error, onRetry: load)
        : RefreshIndicator(
            onRefresh: load,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final tItem = items[i];
                return Card(child: ListTile(
                  title: Text(tItem['label'] ?? ''),
                  subtitle: Text(tItem['code'] ?? ''),
                  trailing: Api.canManage ? IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async { await api.delete('/business/audit-types/${tItem['id']}'); load(); }) : null,
                ));
              },
            ),
          ),
  );
}

class _AuditReferentialsTab extends StatefulWidget {
  const _AuditReferentialsTab();
  @override
  State<_AuditReferentialsTab> createState() => _AuditReferentialsTabState();
}

class _AuditReferentialsTabState extends State<_AuditReferentialsTab> {
  final api = Api();
  List items = [];
  bool loading = true;
  Object? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try { items = List.from(await api.get('/business/audit-referentials')); } catch (e) { error = e; }
    setState(() => loading = false);
  }

  Future<void> addDialog() async {
    final label = TextEditingController();
    final description = TextEditingController();
    await showDialog(context: context, builder: (c) => AlertDialog(
      title: Text(t('auditsPageFlt.nouveauReferentielTitre')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: label, decoration: InputDecoration(labelText: t('auditsPageFlt.libelleLabel'))),
        TextField(controller: description, decoration: InputDecoration(labelText: t('auditsPageFlt.descriptionLabel'))),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(t('auditsPageFlt.annulerBtn'))),
        FilledButton(onPressed: () async {
          if (label.text.trim().isEmpty) return;
          await api.post('/business/audit-referentials', {'code': genCode('ARF'), 'label': label.text.trim(), 'description': description.text.trim().isEmpty ? null : description.text.trim()});
          if (c.mounted) Navigator.pop(c);
          load();
        }, child: Text(t('auditsPageFlt.ajouterBtn'))),
      ],
    ));
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    floatingActionButton: FloatingActionButton(onPressed: addDialog, child: const Icon(Icons.add)),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
            ? LoadErrorView(error: error, onRetry: load)
        : RefreshIndicator(
            onRefresh: load,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final r = items[i];
                return Card(child: ListTile(
                  title: Text(r['label'] ?? ''),
                  subtitle: Text(r['description'] ?? r['code'] ?? ''),
                  trailing: Api.canManage ? IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async { await api.delete('/business/audit-referentials/${r['id']}'); load(); }) : null,
                ));
              },
            ),
          ),
  );
}

class _AuditChecklistsTab extends StatefulWidget {
  const _AuditChecklistsTab();
  @override
  State<_AuditChecklistsTab> createState() => _AuditChecklistsTabState();
}

class _AuditChecklistsTabState extends State<_AuditChecklistsTab> {
  final api = Api();
  List items = [];
  bool loading = true;
  Object? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try { items = List.from(await api.get('/business/audit-checklists')); } catch (e) { error = e; }
    setState(() => loading = false);
  }

  Future<void> addDialog() async {
    final title = TextEditingController();
    await showDialog(context: context, builder: (c) => AlertDialog(
      title: Text(t('auditsPageFlt.nouvelleChecklistTitre')),
      content: TextField(controller: title, decoration: InputDecoration(labelText: t('auditsPageFlt.titreLabel'))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(t('auditsPageFlt.annulerBtn'))),
        FilledButton(onPressed: () async {
          if (title.text.trim().isEmpty) return;
          await api.post('/business/audit-checklists', {'code': genCode('CKL'), 'title': title.text.trim()});
          if (c.mounted) Navigator.pop(c);
          load();
        }, child: Text(t('auditsPageFlt.ajouterBtn'))),
      ],
    ));
  }

  Future<void> addItemDialog(Map checklist) async {
    final question = TextEditingController();
    final critere = TextEditingController();
    String criticite = 'FAIBLE';
    await showDialog(context: context, builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
      title: Text(t('auditsPageFlt.questionChecklistTitre', {'titre': '${checklist['title']}'})),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: question, decoration: InputDecoration(labelText: t('auditsPageFlt.questionLabel'))),
        TextField(controller: critere, decoration: InputDecoration(labelText: t('auditsPageFlt.critereAttenduChampLabel'))),
        DropdownButtonFormField<String>(
          value: criticite, isExpanded: true, decoration: InputDecoration(labelText: t('auditsPageFlt.criticiteLabel')),
          items: [DropdownMenuItem(value: 'FAIBLE', child: Text(t('auditsPageFlt.criticiteFaible'))), DropdownMenuItem(value: 'MOYENNE', child: Text(t('auditsPageFlt.criticiteMoyenne'))), DropdownMenuItem(value: 'ELEVEE', child: Text(t('auditsPageFlt.criticiteElevee'))), DropdownMenuItem(value: 'CRITIQUE', child: Text(t('auditsPageFlt.criticiteCritique')))],
          onChanged: (v) => setD(() => criticite = v ?? 'FAIBLE'),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(t('auditsPageFlt.annulerBtn'))),
        FilledButton(onPressed: () async {
          if (question.text.trim().isEmpty) return;
          await api.post('/business/audit-checklist-items', {'checklistId': checklist['id'], 'question': question.text.trim(), 'critereAttendu': critere.text.trim().isEmpty ? null : critere.text.trim(), 'criticite': criticite});
          if (c.mounted) Navigator.pop(c);
          load();
        }, child: Text(t('auditsPageFlt.ajouterBtn'))),
      ],
    )));
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    floatingActionButton: FloatingActionButton(onPressed: addDialog, child: const Icon(Icons.add)),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
            ? LoadErrorView(error: error, onRetry: load)
        : RefreshIndicator(
            onRefresh: load,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final cl = items[i];
                final itemsList = List.from(cl['items'] ?? []);
                return Card(child: ExpansionTile(
                  title: Text(cl['title'] ?? ''),
                  subtitle: Text(t('auditsPageFlt.questionsCount', {'count': '${itemsList.length}'})),
                  children: [
                    ...itemsList.map((it) => ListTile(dense: true, title: Text(it['question'] ?? ''), subtitle: it['critereAttendu'] != null ? Text(it['critereAttendu']) : null)),
                    Padding(padding: const EdgeInsets.only(bottom: 8), child: TextButton.icon(onPressed: () => addItemDialog(cl), icon: const Icon(Icons.add, size: 16), label: Text(t('auditsPageFlt.ajouterQuestionBtn')))),
                  ],
                ));
              },
            ),
          ),
  );
}

class _AuditProgramTab extends StatefulWidget {
  const _AuditProgramTab();
  @override
  State<_AuditProgramTab> createState() => _AuditProgramTabState();
}

class _AuditProgramTabState extends State<_AuditProgramTab> {
  final api = Api();
  List items = [], types = [], workUnits = [], users = [];
  bool loading = true;
  Object? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      items = List.from(await api.get('/business/audit-programs'));
      types = List.from(await api.get('/business/audit-types'));
      workUnits = List.from(await api.get('/business/work-units'));
      users = List.from(await api.get('/users'));
    } catch (e) { error = e; }
    setState(() => loading = false);
  }

  Future<void> addDialog() async {
    final title = TextEditingController();
    final year = TextEditingController(text: '${DateTime.now().year}');
    String? typeId, workUnitId, auditeurId;
    DateTime? datePrevue;
    await showDialog(context: context, builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
      title: Text(t('auditsPageFlt.nouvelleLigneProgrammeTitre')),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: title, decoration: InputDecoration(labelText: t('auditsPageFlt.titreLabel'))),
        TextField(controller: year, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('auditsPageFlt.anneeLabel'))),
        DropdownButtonFormField<String>(
          value: typeId, isExpanded: true, decoration: InputDecoration(labelText: t('auditsPageFlt.typeLabelCourt')),
          items: [DropdownMenuItem<String>(value: null, child: Text(t('auditsPageFlt.tiretVide'))), ...types.map<DropdownMenuItem<String>>((tp) => DropdownMenuItem<String>(value: tp['id'] as String, child: Text(tp['label'] ?? '')))],
          onChanged: (v) => setD(() => typeId = v),
        ),
        DropdownButtonFormField<String>(
          value: workUnitId, isExpanded: true, decoration: InputDecoration(labelText: t('auditsPageFlt.uniteTravailLabelCourt')),
          items: [DropdownMenuItem<String>(value: null, child: Text(t('auditsPageFlt.tiretVide'))), ...workUnits.map<DropdownMenuItem<String>>((w) => DropdownMenuItem<String>(value: w['id'] as String, child: Text(w['name'] ?? '')))],
          onChanged: (v) => setD(() => workUnitId = v),
        ),
        DropdownButtonFormField<String>(
          value: auditeurId, isExpanded: true, decoration: InputDecoration(labelText: t('auditsPageFlt.auditeurPrincipalLabel')),
          items: [DropdownMenuItem<String>(value: null, child: Text(t('auditsPageFlt.tiretVide'))), ...users.map<DropdownMenuItem<String>>((u) => DropdownMenuItem<String>(value: u['id'] as String, child: Text('${u['firstName']} ${u['lastName']}')))],
          onChanged: (v) => setD(() => auditeurId = v),
        ),
        OutlinedButton.icon(onPressed: () async {
          final d = await showDatePicker(context: c, initialDate: DateTime.now(), firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime.now().add(const Duration(days: 730)));
          if (d != null) setD(() => datePrevue = d);
        }, icon: const Icon(Icons.event), label: Text(datePrevue == null ? t('auditsPageFlt.datePrevueLabel') : datePrevue!.toIso8601String().substring(0, 10))),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(t('auditsPageFlt.annulerBtn'))),
        FilledButton(onPressed: () async {
          if (title.text.trim().isEmpty) return;
          await api.post('/business/audit-programs', {
            'code': genCode('PRG'), 'title': title.text.trim(), 'year': int.tryParse(year.text.trim()) ?? DateTime.now().year,
            'typeId': typeId, 'workUnitId': workUnitId, 'auditeurPrincipalId': auditeurId,
            'datePrevue': datePrevue?.toIso8601String(),
          });
          if (c.mounted) Navigator.pop(c);
          load();
        }, child: Text(t('auditsPageFlt.ajouterBtn'))),
      ],
    )));
  }

  Future<void> generateAudit(Map program) async {
    try { await api.post('/business/audit-programs/${program['id']}/generate-audit', {}); load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    floatingActionButton: FloatingActionButton(onPressed: addDialog, child: const Icon(Icons.add)),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
            ? LoadErrorView(error: error, onRetry: load)
        : RefreshIndicator(
            onRefresh: load,
            child: items.isEmpty
                ? ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(t('auditsPageFlt.aucuneLigneProgramme'))))])
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final p = items[i];
                      return Card(child: ListTile(
                        title: Text('${p['title']} (${p['year']})'),
                        subtitle: Text('${p['statut']}${p['datePrevue'] != null ? ' · ${p['datePrevue'].toString().substring(0, 10)}' : ''}'),
                        trailing: p['auditId'] == null
                            ? TextButton(onPressed: () => generateAudit(p), child: Text(t('auditsPageFlt.genererBtn')))
                            : const Icon(Icons.check_circle, color: QhseColors.green),
                      ));
                    },
                  ),
          ),
  );
}
