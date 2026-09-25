import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api.dart';
import '../services/sync_queue.dart';
import '../theme.dart';
import '../i18n/i18n.dart';
import 'attachment_helpers.dart';
import 'capa_link_widget.dart';
import 'validation_history_widgets.dart';
import 'load_error_view.dart';

Color _niveauColor(String? n) => {
      'CRITIQUE': QhseColors.red,
      'ELEVE': QhseColors.amber,
      'MODERE': const Color(0xFFB45309),
      'FAIBLE': QhseColors.green,
    }[n] ?? QhseColors.textSecondary;
String _niveauLabel(String? n) => {'CRITIQUE': t('risksPageFlt.niveau.critique'), 'ELEVE': t('risksPageFlt.niveau.eleve'), 'MODERE': t('risksPageFlt.niveau.modere'), 'FAIBLE': t('risksPageFlt.niveau.faible')}[n] ?? '—';
Color _alerteColor(String? n) => {'CRITIQUE': QhseColors.red, 'URGENT': QhseColors.red, 'ATTENTION': QhseColors.amber}[n] ?? QhseColors.textSecondary;
// Export CSV du registre (finding #30 de l'audit — export manquant côté
// mobile alors qu'il existe déjà côté web pour Risques/NC).
String _csvEscape(String v) => v.contains(',') || v.contains('"') || v.contains('\n') ? '"${v.replaceAll('"', '""')}"' : v;
// Hiérarchie de prévention (point 9 du cahier des charges) — suggestion,
// jamais une liste figée côté serveur.
List<List<String>> get kRiskMeasureTypes => [
  ['SUPPRESSION', t('risksPageFlt.measureTypes.suppression')],
  ['SUBSTITUTION', t('risksPageFlt.measureTypes.substitution')],
  ['PROTECTION_COLLECTIVE', t('risksPageFlt.measureTypes.protectionCollective')],
  ['TECHNIQUE', t('risksPageFlt.measureTypes.technique')],
  ['ORGANISATIONNELLE', t('risksPageFlt.measureTypes.organisationnelle')],
  ['PROCEDURE', t('risksPageFlt.measureTypes.procedure')],
  ['FORMATION', t('risksPageFlt.measureTypes.formation')],
  ['SIGNALISATION', t('risksPageFlt.measureTypes.signalisation')],
  ['EPI', t('risksPageFlt.measureTypes.epi')],
  ['AUTRE', t('risksPageFlt.measureTypes.autre')],
];

// --- Écran principal à 4 onglets, comme le tableau de bord web ---
class RisksPage extends StatefulWidget {
  const RisksPage({super.key});
  @override
  State<RisksPage> createState() => _RisksPageState();
}

class _RisksPageState extends State<RisksPage> {
  final api = Api();
  List items = [], categories = [], workUnits = [], alertes = [], top10 = [];
  Map dashboard = {};
  bool loading = true;
  Object? error;
  bool exporting = false;
  final searchCtrl = TextEditingController();
  List? searchResults;
  int _searchToken = 0;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      items = List.from(await api.get('/business/risks'));
      dashboard = Map.from(await api.get('/business/risk-dashboard'));
      alertes = List.from(await api.get('/business/risk-alertes'));
      categories = List.from(await api.get('/business/risk-categories'));
      workUnits = List.from(await api.get('/business/work-units'));
      top10 = List.from(await api.get('/business/risk-top10'));
    } catch (e) { error = e; }
    setState(() => loading = false);
  }

  Future<void> _onSearchChanged(String q) async {
    final token = ++_searchToken;
    if (q.trim().isEmpty) { setState(() => searchResults = null); return; }
    await Future.delayed(const Duration(milliseconds: 300));
    if (token != _searchToken) return;
    try {
      final res = List.from(await api.get('/business/risks-search?q=${Uri.encodeQueryComponent(q.trim())}'));
      if (token == _searchToken && mounted) setState(() => searchResults = res);
    } catch (_) {
      if (token == _searchToken && mounted) setState(() => searchResults = []);
    }
  }

  @override
  void dispose() { searchCtrl.dispose(); super.dispose(); }

  // --- Export CSV du registre des risques (mêmes colonnes que l'export
  // Excel du back-office, cf. exportRisquesExcel côté web) ---
  Future<void> exportCsv() async {
    setState(() => exporting = true);
    try {
      final headers = [t('risksPageFlt.csv.code'), t('risksPageFlt.csv.danger'), t('risksPageFlt.csv.categorie'), t('risksPageFlt.csv.uniteTravail'), t('risksPageFlt.csv.situationDangereuse'), t('risksPageFlt.csv.evenementRedoute'), t('risksPageFlt.csv.dommagePotentiel'), t('risksPageFlt.csv.personnesExposees'), t('risksPageFlt.csv.methode'), t('risksPageFlt.csv.gravite'), t('risksPageFlt.csv.probabilite'), t('risksPageFlt.csv.exposition'), t('risksPageFlt.csv.scoreBrut'), t('risksPageFlt.csv.niveau'), t('risksPageFlt.csv.graviteResiduelle'), t('risksPageFlt.csv.probabiliteResiduelle'), t('risksPageFlt.csv.scoreResiduel'), t('risksPageFlt.csv.niveauResiduel'), t('risksPageFlt.csv.statutMaitrise'), t('risksPageFlt.csv.prochaineReevaluation')];
      final buffer = StringBuffer();
      buffer.writeln(headers.map((v) => _csvEscape(v)).join(','));
      for (final r in items) {
        buffer.writeln([
          r['code'], r['hazard'], r['category']?['label'] ?? '', r['workUnit']?['name'] ?? '', r['hazardousSituation'] ?? '', r['hazardousEvent'] ?? '', r['potentialDamage'] ?? '', r['exposedPersons'] ?? '',
          r['method'] ?? '', r['severity'] ?? '', r['probability'] ?? '', r['exposure'] ?? '', r['grossScore'] ?? r['score'] ?? '', r['grossLevel'] ?? '', r['residualSeverity'] ?? '', r['residualProbability'] ?? '', r['residualScore'] ?? '', r['residualLevel'] ?? '',
          r['controlStatus'] ?? '', r['nextReviewDate'] != null ? DateTime.parse(r['nextReviewDate']).toIso8601String().substring(0, 10) : '',
        ].map((v) => _csvEscape('$v')).join(','));
      }
      final dir = await getTemporaryDirectory();
      final fileName = 'Registre-des-risques-${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes([0xEF, 0xBB, 0xBF, ...buffer.toString().codeUnits]);
      await Share.shareXFiles([XFile(file.path)], text: t('risksPageFlt.share.registre'));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    setState(() => exporting = false);
  }

  @override
  Widget build(BuildContext c) => DefaultTabController(
    length: 6,
    child: Scaffold(
      appBar: AppBar(
        title: Text(t('risksPageFlt.titre')),
        actions: [IconButton(icon: exporting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.ios_share), onPressed: exporting ? null : exportCsv, tooltip: t('risksPageFlt.export.tooltip'))],
        bottom: TabBar(isScrollable: true, tabs: [
          Tab(text: t('risksPageFlt.onglets.vueEnsemble')), Tab(text: t('risksPageFlt.onglets.registre')), Tab(text: t('risksPageFlt.onglets.hierarchisation')), Tab(text: t('risksPageFlt.onglets.cartographie')), Tab(text: t('risksPageFlt.onglets.top10')), Tab(text: t('risksPageFlt.onglets.parametrage')),
        ]),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const RiskFormPage())).then((_) => load()),
        icon: const Icon(Icons.add),
        label: Text(t('risksPageFlt.fab.nouveau')),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? LoadErrorView(error: error, onRetry: load)
          : TabBarView(children: [_buildApercu(c), _buildRegistre(c), _buildHierarchisation(c), _buildCartographie(c), _buildTop10(c), _buildParametrage(c)]),
    ),
  );

  Widget _buildTop10(BuildContext c) => RefreshIndicator(
    onRefresh: load,
    child: top10.isEmpty
        ? ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(t('risksPageFlt.vide.aucunRisque'))))])
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: top10.length,
            itemBuilder: (_, i) {
              final r = top10[i];
              final color = _niveauColor(r['grossLevel']);
              final nbActions = (r['actions'] as List?)?.length ?? 0;
              return Card(child: ListTile(
                leading: CircleAvatar(backgroundColor: color, child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                title: Text('${r['hazard']}'),
                subtitle: Text('${r['workUnit']?['name'] ?? '—'} · ${r['category']?['label'] ?? '—'} · ${t('risksPageFlt.top10.score', {'value': '${r['grossScore'] ?? '—'}'})} · ${nbActions > 0 ? t('risksPageFlt.top10.actionsCount', {'count': '$nbActions'}) : t('risksPageFlt.top10.aucuneAction')}'),
                onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => RiskDetailPage(riskId: r['id']))).then((_) => load()),
              ));
            },
          ),
  );

  Widget _buildApercu(BuildContext c) => RefreshIndicator(
    onRefresh: load,
    child: ListView(padding: const EdgeInsets.all(12), children: [
      KpiBar([
        KpiStat(t('risksPageFlt.kpi.recenses'), '${dashboard['total'] ?? items.length}', color: QhseColors.blue, icon: Icons.warning_amber_outlined),
        KpiStat(t('risksPageFlt.kpi.critiques'), '${dashboard['critiques'] ?? 0}', color: QhseColors.red, icon: Icons.error_outline),
        KpiStat(t('risksPageFlt.kpi.eleves'), '${dashboard['eleves'] ?? 0}', color: QhseColors.amber, icon: Icons.error_outline),
        KpiStat(t('risksPageFlt.kpi.nonMaitrises'), '${dashboard['nonMaitrises'] ?? 0}', color: (dashboard['nonMaitrises'] ?? 0) > 0 ? QhseColors.red : QhseColors.green, icon: Icons.gpp_bad_outlined),
      ]),
      const SizedBox(height: 8),
      KpiBar([
        KpiStat(t('risksPageFlt.kpi.actionsEnRetard'), '${dashboard['actionsEnRetard'] ?? 0}', color: (dashboard['actionsEnRetard'] ?? 0) > 0 ? QhseColors.red : QhseColors.green, icon: Icons.timer_off_outlined),
        KpiStat(t('risksPageFlt.kpi.aReevaluer'), '${dashboard['aReevaluer'] ?? 0}', color: (dashboard['aReevaluer'] ?? 0) > 0 ? QhseColors.amber : QhseColors.green, icon: Icons.refresh),
        KpiStat(t('risksPageFlt.kpi.tauxMaitrise'), '${dashboard['tauxMaitrise'] ?? '—'}%', color: QhseColors.blue, icon: Icons.shield_outlined),
        KpiStat(t('risksPageFlt.kpi.clotureActions'), '${dashboard['tauxClotureActions'] ?? '—'}%', color: QhseColors.blue, icon: Icons.task_alt),
      ]),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(t('risksPageFlt.apercu.alertesTitre'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        Text('${alertes.length}', style: TextStyle(color: QhseColors.textSecondary)),
      ]),
      const SizedBox(height: 6),
      if (alertes.isEmpty)
        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(t('risksPageFlt.apercu.aucuneAlerte'), style: TextStyle(color: QhseColors.green)))
      else
        ...alertes.map((a) => Card(child: ListTile(
              dense: true,
              title: Text(a['label'] ?? ''),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: _alerteColor(a['niveau']).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: Text(a['niveau'] ?? '', style: TextStyle(color: _alerteColor(a['niveau']), fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ))),
    ]),
  );

  Widget _buildRegistre(BuildContext c) {
    final list = searchResults ?? items;
    return RefreshIndicator(
      onRefresh: load,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: searchCtrl,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: t('risksPageFlt.registre.rechercheHint'),
              prefixIcon: const Icon(Icons.search, size: 18),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(searchResults != null ? t('risksPageFlt.vide.aucunResultat') : t('risksPageFlt.vide.aucunRisque'))))])
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final r = list[i];
                    final score = r['grossScore'] ?? r['score'] ?? 0;
                    final color = _niveauColor(r['grossLevel']);
                    return Card(child: ListTile(
                      leading: CircleAvatar(backgroundColor: color, child: Text('$score', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      title: Text('${r['code']} — ${r['hazard']}'),
                      subtitle: Text('${r['category']?['label'] ?? t('risksPageFlt.registre.sansCategorie')} · ${r['workUnit']?['name'] ?? t('risksPageFlt.registre.sansUnite')}'),
                      trailing: Text(_niveauLabel(r['grossLevel']), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
                      onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => RiskDetailPage(riskId: r['id']))).then((_) => load()),
                    ));
                  },
                ),
        ),
      ]),
    );
  }

  Widget _buildHierarchisation(BuildContext c) {
    final groups = [
      {'id': 'CRITIQUE', 'label': t('risksPageFlt.hierarchisation.critique'), 'color': QhseColors.red},
      {'id': 'ELEVE', 'label': t('risksPageFlt.hierarchisation.eleve'), 'color': QhseColors.amber},
      {'id': 'MODERE', 'label': t('risksPageFlt.hierarchisation.modere'), 'color': const Color(0xFFB45309)},
      {'id': 'FAIBLE', 'label': t('risksPageFlt.hierarchisation.faible'), 'color': QhseColors.green},
    ];
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: groups.map((g) {
          final risques = items.where((r) => (r['grossLevel'] ?? 'FAIBLE') == g['id']).toList()
            ..sort((a, b) => ((b['grossScore'] ?? b['score'] ?? 0) as num).compareTo((a['grossScore'] ?? a['score'] ?? 0) as num));
          final color = g['color'] as Color;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(top: 12, bottom: 6), child: Text('${g['label']} (${risques.length})', style: TextStyle(fontWeight: FontWeight.bold, color: color))),
            if (risques.isEmpty)
              Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(t('risksPageFlt.hierarchisation.aucunRisque'), style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
            else
              ...risques.map((r) => Card(child: ListTile(
                    dense: true,
                    title: Text(r['hazard'] ?? ''),
                    subtitle: Text(r['workUnit']?['name'] ?? t('risksPageFlt.registre.sansUnite')),
                    trailing: Text('${r['grossScore'] ?? r['score'] ?? 0}', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                    onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => RiskDetailPage(riskId: r['id']))).then((_) => load()),
                  ))),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildCartographie(BuildContext c) {
    final niveaux = ['CRITIQUE', 'ELEVE', 'MODERE', 'FAIBLE'];
    final parNiveau = {for (final n in niveaux) n: items.where((r) => (r['grossLevel'] ?? 'FAIBLE') == n).length};
    final parCategorie = <String, int>{};
    for (final r in items) {
      final label = r['category']?['label'] ?? 'Sans catégorie';
      parCategorie[label] = (parCategorie[label] ?? 0) + 1;
    }
    final categories = parCategorie.keys.toList()..sort((a, b) => parCategorie[b]!.compareTo(parCategorie[a]!));
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(padding: const EdgeInsets.all(12), children: [
        Text(t('risksPageFlt.cartographie.repartitionNiveau'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: items.isEmpty
              ? Center(child: Text(t('risksPageFlt.vide.aucunRisque'), style: TextStyle(color: QhseColors.textSecondary)))
              : BarChart(BarChartData(
                  gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: QhseColors.border, strokeWidth: 1)),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 26, getTitlesWidget: (v, m) => Text(v.toInt().toString(), style: TextStyle(fontSize: 9, color: QhseColors.textSecondary)))),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 26, getTitlesWidget: (v, m) {
                      final i = v.toInt();
                      return Padding(padding: const EdgeInsets.only(top: 4), child: Text(i >= 0 && i < niveaux.length ? _niveauLabel(niveaux[i]) : '', style: TextStyle(fontSize: 9, color: QhseColors.textSecondary)));
                    })),
                  ),
                  barGroups: [for (int i = 0; i < niveaux.length; i++) BarChartGroupData(x: i, barRods: [BarChartRodData(toY: parNiveau[niveaux[i]]!.toDouble(), color: _niveauColor(niveaux[i]), width: 28, borderRadius: BorderRadius.circular(4))])],
                )),
        ),
        const SizedBox(height: 20),
        Text(t('risksPageFlt.cartographie.repartitionCategorie'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        if (categories.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(t('risksPageFlt.cartographie.aucuneDonnee'), style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
        else
          ...categories.map((cat) => Card(child: ListTile(dense: true, title: Text(cat), trailing: Text('${parCategorie[cat]}', style: const TextStyle(fontWeight: FontWeight.bold))))),
        const SizedBox(height: 20),
        Text(t('risksPageFlt.cartographie.rapportSynthese'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('risksPageFlt.cartographie.totalRecenses', {'count': '${items.length}'}), style: const TextStyle(fontSize: 13)),
          Text(t('risksPageFlt.cartographie.repartitionDetail', {'critiques': '${parNiveau['CRITIQUE']}', 'eleves': '${parNiveau['ELEVE']}', 'moderes': '${parNiveau['MODERE']}', 'faibles': '${parNiveau['FAIBLE']}'}), style: const TextStyle(fontSize: 13)),
          Text(t('risksPageFlt.cartographie.tauxEtActions', {'taux': '${dashboard['tauxMaitrise'] ?? '—'}', 'actions': '${dashboard['actionsEnRetard'] ?? 0}'}), style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
          Text(t('risksPageFlt.cartographie.rapportNote'), style: TextStyle(fontSize: 11, color: QhseColors.textSecondary, fontStyle: FontStyle.italic)),
        ]))),
      ]),
    );
  }

  Widget _buildParametrage(BuildContext c) => RefreshIndicator(
    onRefresh: load,
    child: ListView(padding: const EdgeInsets.all(12), children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(t('risksPageFlt.parametrage.categoriesTitre'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        TextButton.icon(onPressed: () => showRiskCategoryDialog(c, api, onSaved: load), icon: const Icon(Icons.add, size: 16), label: Text(t('risksPageFlt.common.ajouter'))),
      ]),
      if (categories.isEmpty)
        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(t('risksPageFlt.parametrage.aucuneCategorie'), style: TextStyle(color: QhseColors.textSecondary)))
      else
        ...categories.map((cat) => Card(child: ListTile(dense: true, title: Text(cat['label'] ?? ''), subtitle: Text(cat['code'] ?? ''), onTap: () => showRiskCategoryDialog(c, api, record: cat, onSaved: load)))),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(t('risksPageFlt.parametrage.unitesTitre'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        TextButton.icon(onPressed: () => showWorkUnitDialog(c, api, onSaved: load), icon: const Icon(Icons.add, size: 16), label: Text(t('risksPageFlt.common.ajouter'))),
      ]),
      if (workUnits.isEmpty)
        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(t('risksPageFlt.parametrage.aucuneUnite'), style: TextStyle(color: QhseColors.textSecondary)))
      else
        ...workUnits.map((w) => Card(child: ListTile(dense: true, title: Text(w['name'] ?? ''), subtitle: Text('${w['department'] ?? '—'} · ${w['service'] ?? '—'}')))),
    ]),
  );
}

// --- Détail d'un risque : mesures de prévention + historique + actions ---
class RiskDetailPage extends StatefulWidget {
  final String riskId;
  const RiskDetailPage({super.key, required this.riskId});
  @override
  State<RiskDetailPage> createState() => _RiskDetailPageState();
}

class _RiskDetailPageState extends State<RiskDetailPage> {
  final api = Api();
  Map? risk;
  bool loading = true;
  String? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() => loading = true);
    try { risk = Map.from(await api.get('/business/risks/${widget.riskId}')); }
    catch (e) { error = '$e'; }
    setState(() => loading = false);
  }

  Future<void> deleteRisk() async {
    final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: Text(t('risksPageFlt.detail.archiverTitre')),
      content: Text(t('risksPageFlt.detail.archiverMessage')),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t('risksPageFlt.common.annuler'))), FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(t('risksPageFlt.detail.archiverBtn')))],
    ));
    if (confirm != true) return;
    try { await api.delete('/business/risks/${widget.riskId}'); if (mounted) Navigator.pop(context); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  @override
  Widget build(BuildContext c) {
    if (loading) return Scaffold(appBar: AppBar(title: Text(t('risksPageFlt.detail.titre'))), body: const Center(child: CircularProgressIndicator()));
    if (error != null || risk == null) return Scaffold(appBar: AppBar(title: Text(t('risksPageFlt.detail.titre'))), body: Center(child: Text(error ?? t('risksPageFlt.detail.introuvable'))));
    final r = risk!;
    final measures = List.from(r['riskMeasures'] ?? []);
    final evaluations = List.from(r['evaluations'] ?? [])..sort((a, b) => (a['evaluatedAt'] as String).compareTo(b['evaluatedAt'] as String));
    return Scaffold(
      appBar: AppBar(title: Text(r['hazard'] ?? ''), actions: [
        IconButton(icon: const Icon(Icons.camera_alt_outlined), onPressed: () => captureAndLinkPhoto(context, api, 'RISK', r['id'])),
        IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => RiskFormPage(record: r))).then((_) => load())),
        if (Api.canManage) IconButton(icon: const Icon(Icons.archive_outlined), onPressed: deleteRisk),
      ]),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Text('${r['category']?['label'] ?? t('risksPageFlt.registre.sansCategorie')} · ${r['workUnit']?['name'] ?? t('risksPageFlt.detail.sansUniteTravail')}', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _scoreCard(t('risksPageFlt.detail.risqueBrut'), r['grossScore'] ?? r['score'], r['grossLevel'])),
            const SizedBox(width: 8),
            Expanded(child: _scoreCard(t('risksPageFlt.detail.risqueResiduel'), r['residualScore'], r['residualLevel'])),
          ]),
          const SizedBox(height: 8),
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(t('risksPageFlt.detail.statutMaitriseLabel'), style: const TextStyle(fontSize: 12)),
            Text(
              r['controlStatus'] == 'MAITRISE' ? t('risksPageFlt.detail.maitrise') : r['controlStatus'] == 'PARTIELLEMENT_MAITRISE' ? t('risksPageFlt.detail.partiel') : t('risksPageFlt.detail.nonMaitrise'),
              style: TextStyle(fontWeight: FontWeight.bold, color: r['controlStatus'] == 'MAITRISE' ? QhseColors.green : r['controlStatus'] == 'PARTIELLEMENT_MAITRISE' ? QhseColors.amber : QhseColors.red),
            ),
          ]))),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(t('risksPageFlt.detail.mesuresTitre', {'count': '${measures.length}'}), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            TextButton.icon(onPressed: () => showRiskMeasureDialog(c, api, riskId: r['id'], onSaved: load), icon: const Icon(Icons.add, size: 16), label: Text(t('risksPageFlt.detail.mesureBtn'))),
          ]),
          if (measures.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(t('risksPageFlt.detail.aucuneMesure'), style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
          else
            ...measures.map((m) => Card(child: ListTile(
                  dense: true,
                  title: Text(m['description'] ?? ''),
                  subtitle: Text('${kRiskMeasureTypes.firstWhere((mt) => mt[0] == m['type'], orElse: () => ['', m['type'] ?? ''])[1]} · ${t('risksPageFlt.detail.efficacite', {'value': '${m['efficacite']}'})}'),
                  trailing: IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () async { await api.delete('/business/risk-measures/${m['id']}'); load(); }),
                ))),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(t('risksPageFlt.detail.historiqueTitre', {'count': '${evaluations.length}'}), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            TextButton.icon(onPressed: () => showReevaluateDialog(c, api, risk: r, onSaved: load), icon: const Icon(Icons.refresh, size: 16), label: Text(t('risksPageFlt.detail.reevaluerBtn'))),
          ]),
          if (evaluations.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(t('risksPageFlt.detail.aucuneEvaluation'), style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
          else
            ...evaluations.reversed.map((ev) => Card(child: ListTile(
                  dense: true,
                  title: Text(t('risksPageFlt.detail.evalBrut', {'date': ev['evaluatedAt'].toString().substring(0, 10), 'score': '${ev['grossScore']}', 'level': '${ev['grossLevel']}'})),
                  subtitle: Text(ev['residualScore'] != null ? '${t('risksPageFlt.detail.evalResiduel', {'score': '${ev['residualScore']}', 'level': '${ev['residualLevel']}'})}${ev['note'] != null ? ' · ${ev['note']}' : ''}' : ev['note'] ?? ''),
                ))),

          const SizedBox(height: 20),
          CapaLinksSection(sourceModule: 'RISK', sourceEntityId: r['id'], prefill: {'title': t('risksPageFlt.detail.capaPrefillTitre', {'hazard': '${r['hazard'] ?? ''}'}), 'source': 'RISK'}),
          const SizedBox(height: 12),
          ValidationWorkflowSection(item: r, endpointBase: '/business/risks/${r['id']}', onChanged: load),
          const SizedBox(height: 12),
          HistorySection(module: 'RISK', entityId: r['id']),
        ]),
      ),
    );
  }

  Widget _scoreCard(String label, dynamic score, String? level) => Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, color: QhseColors.textSecondary)),
        const SizedBox(height: 4),
        Text('${score ?? '—'}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _niveauColor(level))),
        Text(_niveauLabel(level), style: TextStyle(fontSize: 11, color: _niveauColor(level))),
      ])));
}

// --- Formulaire création/modification, avec le moteur d'évaluation complet ---
class RiskFormPage extends StatefulWidget {
  final Map? record;
  const RiskFormPage({super.key, this.record});
  @override
  State<RiskFormPage> createState() => _RiskFormPageState();
}

class _RiskFormPageState extends State<RiskFormPage> {
  final api = Api();
  bool get editing => widget.record != null;
  List categories = [], workUnits = [];
  final hazard = TextEditingController();
  final activity = TextEditingController();
  final hazardousSituation = TextEditingController();
  final hazardousEvent = TextEditingController();
  final potentialDamage = TextEditingController();
  final exposedPersons = TextEditingController();
  final exposedPersonCount = TextEditingController();
  final measures = TextEditingController();
  String? categoryId, workUnitId;
  String method = 'GP';
  int severity = 3, probability = 3, exposure = 1;
  bool hasResidual = false;
  int residualSeverity = 3, residualProbability = 3, residualExposure = 1;
  bool busy = false, loadingLists = true;
  String? error;

  int get grossScore => method == 'GPE' ? severity * probability * exposure : severity * probability;
  int get residualScoreValue => method == 'GPE' ? residualSeverity * residualProbability * residualExposure : residualSeverity * residualProbability;

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    if (r != null) {
      hazard.text = r['hazard'] ?? '';
      activity.text = r['activity'] ?? '';
      hazardousSituation.text = r['hazardousSituation'] ?? '';
      hazardousEvent.text = r['hazardousEvent'] ?? '';
      potentialDamage.text = r['potentialDamage'] ?? '';
      exposedPersons.text = r['exposedPersons'] ?? '';
      exposedPersonCount.text = r['exposedPersonCount']?.toString() ?? '';
      measures.text = r['measures'] ?? '';
      categoryId = r['categoryId'];
      workUnitId = r['workUnitId'];
      method = r['method'] ?? 'GP';
      severity = (r['severity'] ?? 3) as int;
      probability = (r['probability'] ?? 3) as int;
      exposure = (r['exposure'] ?? 1) as int;
      if (r['residualSeverity'] != null && r['residualProbability'] != null) {
        hasResidual = true;
        residualSeverity = r['residualSeverity'] as int;
        residualProbability = r['residualProbability'] as int;
        residualExposure = (r['residualExposure'] ?? 1) as int;
      }
    }
    loadLists();
  }

  Future<void> loadLists() async {
    try {
      categories = List.from(await api.get('/business/risk-categories'));
      workUnits = List.from(await api.get('/business/work-units'));
    } catch (_) {}
    setState(() => loadingLists = false);
  }

  Future<void> submit() async {
    if (hazard.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('risksPageFlt.form.dangerObligatoire'))));
      return;
    }
    setState(() { busy = true; error = null; });
    final payload = {
      'hazard': hazard.text.trim(),
      'categoryId': categoryId, 'workUnitId': workUnitId,
      'activity': activity.text.trim().isEmpty ? null : activity.text.trim(),
      'hazardousSituation': hazardousSituation.text.trim().isEmpty ? null : hazardousSituation.text.trim(),
      'hazardousEvent': hazardousEvent.text.trim().isEmpty ? null : hazardousEvent.text.trim(),
      'potentialDamage': potentialDamage.text.trim().isEmpty ? null : potentialDamage.text.trim(),
      'exposedPersons': exposedPersons.text.trim().isEmpty ? null : exposedPersons.text.trim(),
      'exposedPersonCount': exposedPersonCount.text.trim().isEmpty ? null : int.tryParse(exposedPersonCount.text.trim()),
      'method': method, 'severity': severity, 'probability': probability, 'exposure': exposure,
      'measures': measures.text.trim().isEmpty ? null : measures.text.trim(),
      if (hasResidual) 'residualSeverity': residualSeverity,
      if (hasResidual) 'residualProbability': residualProbability,
      if (hasResidual) 'residualExposure': residualExposure,
    };
    final createPayload = {'code': genCode('RISK'), 'status': 'ACTIVE', ...payload};
    try {
      if (editing) {
        await api.patch('/business/risks/${widget.record!['id']}', payload);
      } else {
        await api.post('/business/risks', createPayload);
      }
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (e.networkError && !editing) {
        await SyncQueue.enqueue('risk', 'CREATE', createPayload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('risksPageFlt.form.horsLigne')), duration: const Duration(seconds: 4)));
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

  Widget _slider(String label, int value, ValueChanged<int> onChanged) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$label : $value / 5', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Slider(value: value.toDouble(), min: 1, max: 5, divisions: 4, label: '$value', onChanged: (v) => onChanged(v.round())),
      ]);

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text(editing ? t('risksPageFlt.form.titreModifier') : t('risksPageFlt.fab.nouveau'))),
    body: loadingLists
        ? const Center(child: CircularProgressIndicator())
        : ListView(padding: const EdgeInsets.all(16), children: [
            TextField(controller: hazard, decoration: InputDecoration(labelText: t('risksPageFlt.form.champDanger'))),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: categoryId, isExpanded: true, decoration: InputDecoration(labelText: t('risksPageFlt.form.champCategorie')),
              items: [const DropdownMenuItem<String>(value: null, child: Text('—')), ...categories.map<DropdownMenuItem<String>>((cat) => DropdownMenuItem<String>(value: cat['id'] as String, child: Text(cat['label'] ?? '')))],
              onChanged: (v) => setState(() => categoryId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: workUnitId, isExpanded: true, decoration: InputDecoration(labelText: t('risksPageFlt.form.champUnite')),
              items: [const DropdownMenuItem<String>(value: null, child: Text('—')), ...workUnits.map<DropdownMenuItem<String>>((w) => DropdownMenuItem<String>(value: w['id'] as String, child: Text(w['name'] ?? '')))],
              onChanged: (v) => setState(() => workUnitId = v),
            ),
            const SizedBox(height: 12),
            TextField(controller: activity, decoration: InputDecoration(labelText: t('risksPageFlt.form.champActivite'))),
            const SizedBox(height: 12),
            TextField(controller: hazardousSituation, decoration: InputDecoration(labelText: t('risksPageFlt.form.champSituation'))),
            const SizedBox(height: 12),
            TextField(controller: hazardousEvent, decoration: InputDecoration(labelText: t('risksPageFlt.form.champEvenement'))),
            const SizedBox(height: 12),
            TextField(controller: potentialDamage, decoration: InputDecoration(labelText: t('risksPageFlt.form.champDommage'))),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: exposedPersons, decoration: InputDecoration(labelText: t('risksPageFlt.form.champPersonnes')))),
              const SizedBox(width: 8),
              SizedBox(width: 90, child: TextField(controller: exposedPersonCount, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('risksPageFlt.form.champNombre')))),
            ]),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: method, decoration: InputDecoration(labelText: t('risksPageFlt.form.champMethode')),
              items: [DropdownMenuItem(value: 'GP', child: Text(t('risksPageFlt.form.methodeGP'))), DropdownMenuItem(value: 'GPE', child: Text(t('risksPageFlt.form.methodeGPE')))],
              onChanged: (v) => setState(() => method = v ?? 'GP'),
            ),
            const SizedBox(height: 8),
            _slider(t('risksPageFlt.form.gravite'), severity, (v) => setState(() => severity = v)),
            _slider(t('risksPageFlt.form.probabilite'), probability, (v) => setState(() => probability = v)),
            if (method == 'GPE') _slider(t('risksPageFlt.form.exposition'), exposure, (v) => setState(() => exposure = v)),
            Text(t('risksPageFlt.form.scoreBrutApercu', {'score': '$grossScore'}), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(controller: measures, maxLines: 2, decoration: InputDecoration(labelText: t('risksPageFlt.form.champMesuresResume'))),
            const SizedBox(height: 12),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(t('risksPageFlt.form.evaluerResiduel'), style: const TextStyle(fontSize: 13)), value: hasResidual, onChanged: (v) => setState(() => hasResidual = v)),
            if (hasResidual) ...[
              _slider(t('risksPageFlt.form.graviteResiduelle'), residualSeverity, (v) => setState(() => residualSeverity = v)),
              _slider(t('risksPageFlt.form.probabiliteResiduelle'), residualProbability, (v) => setState(() => residualProbability = v)),
              if (method == 'GPE') _slider(t('risksPageFlt.form.expositionResiduelle'), residualExposure, (v) => setState(() => residualExposure = v)),
              Text(t('risksPageFlt.form.scoreResiduelApercu', {'score': '$residualScoreValue'}), style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
            if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : submit, child: Text(busy ? t('risksPageFlt.common.envoi') : t('risksPageFlt.common.enregistrer')))),
          ]),
  );
}

// --- Dialogues : catégories, unités de travail, mesures, réévaluation ---
Future<void> showRiskCategoryDialog(BuildContext context, Api api, {Map? record, required VoidCallback onSaved}) async {
  final code = TextEditingController(text: record?['code'] ?? '');
  final label = TextEditingController(text: record?['label'] ?? '');
  String? formError;
  bool saving = false;
  await showDialog(context: context, builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
    title: Text(record == null ? t('risksPageFlt.dialogCategorie.nouvelle') : t('risksPageFlt.dialogCategorie.modifier')),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: code, decoration: InputDecoration(labelText: t('risksPageFlt.dialogCategorie.champCode'))),
      TextField(controller: label, decoration: InputDecoration(labelText: t('risksPageFlt.dialogCategorie.champLibelle'))),
      if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
    ])),
    actions: [
      if (record != null) TextButton(onPressed: () async {
        try { await api.delete('/business/risk-categories/${record['id']}'); if (context.mounted) Navigator.pop(c); onSaved(); }
        catch (e) { setD(() => formError = '$e'); }
      }, child: Text(t('risksPageFlt.common.supprimer'), style: const TextStyle(color: QhseColors.red))),
      TextButton(onPressed: () => Navigator.pop(c), child: Text(t('risksPageFlt.common.annuler'))),
      FilledButton(onPressed: saving ? null : () async {
        setD(() => saving = true);
        final payload = {'code': code.text.trim(), 'label': label.text.trim()};
        try {
          if (record != null) await api.patch('/business/risk-categories/${record['id']}', payload);
          else await api.post('/business/risk-categories', payload);
          if (context.mounted) Navigator.pop(c);
          onSaved();
        } catch (e) { setD(() { saving = false; formError = '$e'; }); }
      }, child: Text(saving ? '…' : t('risksPageFlt.common.enregistrer'))),
    ],
  )));
}

Future<void> showWorkUnitDialog(BuildContext context, Api api, {required VoidCallback onSaved}) async {
  final name = TextEditingController();
  final department = TextEditingController();
  final service = TextEditingController();
  String? formError;
  bool saving = false;
  await showDialog(context: context, builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
    title: Text(t('risksPageFlt.dialogUnite.titre')),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: name, decoration: InputDecoration(labelText: t('risksPageFlt.dialogUnite.champNom'))),
      TextField(controller: department, decoration: InputDecoration(labelText: t('risksPageFlt.dialogUnite.champDepartement'))),
      TextField(controller: service, decoration: InputDecoration(labelText: t('risksPageFlt.dialogUnite.champService'))),
      if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
    ])),
    actions: [
      TextButton(onPressed: () => Navigator.pop(c), child: Text(t('risksPageFlt.common.annuler'))),
      FilledButton(onPressed: saving ? null : () async {
        setD(() => saving = true);
        try {
          await api.post('/business/work-units', {'code': genCode('WU'), 'name': name.text.trim(), 'department': department.text.trim().isEmpty ? null : department.text.trim(), 'service': service.text.trim().isEmpty ? null : service.text.trim()});
          if (context.mounted) Navigator.pop(c);
          onSaved();
        } catch (e) { setD(() { saving = false; formError = '$e'; }); }
      }, child: Text(saving ? '…' : t('risksPageFlt.common.enregistrer'))),
    ],
  )));
}

Future<void> showRiskMeasureDialog(BuildContext context, Api api, {required String riskId, required VoidCallback onSaved}) async {
  final description = TextEditingController();
  String type = 'TECHNIQUE';
  int efficacite = 3;
  String? formError;
  bool saving = false;
  await showDialog(context: context, builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
    title: Text(t('risksPageFlt.dialogMesure.titre')),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: description, maxLines: 2, decoration: InputDecoration(labelText: t('risksPageFlt.dialogMesure.champDescription'))),
      DropdownButtonFormField<String>(
        value: type, isExpanded: true, decoration: InputDecoration(labelText: t('risksPageFlt.dialogMesure.champType')),
        items: kRiskMeasureTypes.map((mt) => DropdownMenuItem(value: mt[0], child: Text(mt[1]))).toList(),
        onChanged: (v) => setD(() => type = v ?? 'TECHNIQUE'),
      ),
      Row(children: [
        Expanded(child: Text(t('risksPageFlt.dialogMesure.efficaciteLabel', {'value': '$efficacite'}))),
        Expanded(child: Slider(value: efficacite.toDouble(), min: 1, max: 5, divisions: 4, label: '$efficacite', onChanged: (v) => setD(() => efficacite = v.round()))),
      ]),
      if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
    ])),
    actions: [
      TextButton(onPressed: () => Navigator.pop(c), child: Text(t('risksPageFlt.common.annuler'))),
      FilledButton(onPressed: saving ? null : () async {
        if (description.text.trim().isEmpty) { setD(() => formError = t('risksPageFlt.dialogMesure.descriptionObligatoire')); return; }
        setD(() => saving = true);
        final payload = {'riskId': riskId, 'description': description.text.trim(), 'type': type, 'efficacite': efficacite};
        try {
          await api.post('/business/risk-measures', payload);
          if (context.mounted) Navigator.pop(c);
          onSaved();
        } on ApiException catch (e) {
          if (e.networkError) {
            await SyncQueue.enqueue('riskMeasure', 'CREATE', payload);
            if (context.mounted) {
              Navigator.pop(c);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('risksPageFlt.dialogMesure.horsLigne')), duration: const Duration(seconds: 4)));
            }
            onSaved();
          } else {
            setD(() { saving = false; formError = '$e'; });
          }
        } catch (e) { setD(() { saving = false; formError = '$e'; }); }
      }, child: Text(saving ? '…' : t('risksPageFlt.common.ajouter'))),
    ],
  )));
}

// Réévaluation — conserve l'ancienne évaluation dans l'historique (appel du
// endpoint dédié /reevaluate), jamais un simple écrasement des valeurs.
Future<void> showReevaluateDialog(BuildContext context, Api api, {required Map risk, required VoidCallback onSaved}) async {
  int severity = (risk['severity'] ?? 3) as int;
  int probability = (risk['probability'] ?? 3) as int;
  int? residualSeverity = risk['residualSeverity'] as int?;
  int? residualProbability = risk['residualProbability'] as int?;
  final note = TextEditingController();
  String? formError;
  bool saving = false;
  await showDialog(context: context, builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
    title: Text(t('risksPageFlt.dialogReeval.titre')),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t('risksPageFlt.dialogReeval.gravite', {'value': '$severity'})),
      Slider(value: severity.toDouble(), min: 1, max: 5, divisions: 4, label: '$severity', onChanged: (v) => setD(() => severity = v.round())),
      Text(t('risksPageFlt.dialogReeval.probabilite', {'value': '$probability'})),
      Slider(value: probability.toDouble(), min: 1, max: 5, divisions: 4, label: '$probability', onChanged: (v) => setD(() => probability = v.round())),
      const Divider(),
      Text(t('risksPageFlt.dialogReeval.graviteResiduelle', {'value': '${residualSeverity ?? '—'}'})),
      Slider(value: (residualSeverity ?? 3).toDouble(), min: 1, max: 5, divisions: 4, label: '${residualSeverity ?? 3}', onChanged: (v) => setD(() => residualSeverity = v.round())),
      Text(t('risksPageFlt.dialogReeval.probabiliteResiduelle', {'value': '${residualProbability ?? '—'}'})),
      Slider(value: (residualProbability ?? 3).toDouble(), min: 1, max: 5, divisions: 4, label: '${residualProbability ?? 3}', onChanged: (v) => setD(() => residualProbability = v.round())),
      TextField(controller: note, decoration: InputDecoration(labelText: t('risksPageFlt.dialogReeval.champNote'))),
      if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
    ])),
    actions: [
      TextButton(onPressed: () => Navigator.pop(c), child: Text(t('risksPageFlt.common.annuler'))),
      FilledButton(onPressed: saving ? null : () async {
        setD(() => saving = true);
        final payload = {
          'severity': severity, 'probability': probability,
          'residualSeverity': residualSeverity, 'residualProbability': residualProbability,
          'note': note.text.trim().isEmpty ? null : note.text.trim(),
        };
        try {
          await api.post('/business/risks/${risk['id']}/reevaluate', payload);
          if (context.mounted) Navigator.pop(c);
          onSaved();
        } on ApiException catch (e) {
          if (e.networkError) {
            await SyncQueue.enqueue('riskReevaluate', 'UPDATE', payload, entityId: risk['id'] as String);
            if (context.mounted) {
              Navigator.pop(c);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('risksPageFlt.form.horsLigneReeval')), duration: const Duration(seconds: 4)));
            }
            onSaved();
          } else {
            setD(() { saving = false; formError = '$e'; });
          }
        } catch (e) { setD(() { saving = false; formError = '$e'; }); }
      }, child: Text(saving ? '…' : t('risksPageFlt.dialogReeval.reevaluerBtn'))),
    ],
  )));
}
