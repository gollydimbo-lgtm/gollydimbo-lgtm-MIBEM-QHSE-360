import 'package:flutter/material.dart';
import '../services/api.dart';
import '../theme.dart';
import '../i18n/i18n.dart';
import 'safety_talk_detail_page.dart';
import 'safety_talk_form_page.dart';
import 'load_error_view.dart';

Map<String, String> get statusLabels => {
  'DRAFT': t('safetyTalkPageFlt.statutBrouillon'),
  'APPROVED': t('safetyTalkPageFlt.statutValide'),
  'DELIVERED': t('safetyTalkPageFlt.statutAnime'),
  'ANNULE': t('safetyTalkPageFlt.statutAnnule'),
  'REPORTE': t('safetyTalkPageFlt.statutReporte'),
};

Color statusColor(String? s) => {
      'DRAFT': QhseColors.blue,
      'APPROVED': QhseColors.amber,
      'DELIVERED': QhseColors.green,
      'ANNULE': QhseColors.textSecondary,
      'REPORTE': QhseColors.red,
    }[s] ??
    QhseColors.textSecondary;

Map<String, String> get prioriteLabels => {
  'FAIBLE': t('safetyTalkPageFlt.prioriteFaible'),
  'MOYENNE': t('safetyTalkPageFlt.prioriteMoyenne'),
  'ELEVEE': t('safetyTalkPageFlt.prioriteElevee'),
  'CRITIQUE': t('safetyTalkPageFlt.prioriteCritique'),
};

Color prioriteColor(String? p) => {
      'FAIBLE': QhseColors.textSecondary,
      'MOYENNE': QhseColors.blue,
      'ELEVEE': QhseColors.amber,
      'CRITIQUE': QhseColors.red,
    }[p] ??
    QhseColors.blue;

Widget prioriteChip(String? p) {
  final label = prioriteLabels[p] ?? p ?? '—';
  final c = prioriteColor(p);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
    child: Text(label, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold)),
  );
}

String fmtDate(dynamic v) => v == null ? '—' : '$v'.substring(0, 10);

/// Page principale du module "Quart d'heure sécurité" (Safety Talk).
/// Reconstruite en page à onglets pour mettre en avant, dès la vue
/// d'ensemble, le point le plus important du cahier des charges : le moteur
/// de recommandation de thèmes. Nom de classe conservé (référencé depuis
/// main.dart et security_hub_page.dart).
class SafetyTalkPage extends StatefulWidget {
  const SafetyTalkPage({super.key});
  @override
  State<SafetyTalkPage> createState() => _SafetyTalkPageState();
}

class _SafetyTalkPageState extends State<SafetyTalkPage> {
  @override
  Widget build(BuildContext c) => DefaultTabController(
    length: 3,
    child: Scaffold(
      appBar: AppBar(
        title: Text(t('safetyTalkPageFlt.titre')),
        bottom: TabBar(tabs: [
          Tab(text: t('safetyTalkPageFlt.ongletApercu')), Tab(text: t('safetyTalkPageFlt.ongletSeances')), Tab(text: t('safetyTalkPageFlt.ongletMatrice')),
        ]),
      ),
      body: const TabBarView(children: [_OverviewTab(), _SeancesTab(), _MatrixTab()]),
    ),
  );
}

// --- Onglet 1 : Vue d'ensemble — KPI puis, bien visible, la zone des
// thèmes recommandés par le moteur d'analyse. ---
class _OverviewTab extends StatefulWidget {
  const _OverviewTab();
  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  final api = Api();
  Map dash = {};
  List recommendations = [];
  bool loading = true, refreshingReco = false;
  Object? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      dash = Map.from(await api.get('/safety-talks/dashboard'));
      recommendations = List.from(await api.get('/safety-talks/recommendations'));
    } catch (e) { error = e; }
    setState(() => loading = false);
  }

  Future<void> refreshAnalyse() async {
    setState(() => refreshingReco = true);
    try {
      recommendations = List.from(await api.post('/safety-talks/recommendations/refresh', {}));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('safetyTalkPageFlt.analyseActualisee'))));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    setState(() => refreshingReco = false);
  }

  Future<void> decision(String id, String decision) async {
    try {
      await api.post('/safety-talks/recommendations/$id/decision', {'decision': decision});
      setState(() => recommendations.removeWhere((r) => r['id'] == id));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> acceptAndGenerate(String id) async {
    try {
      final created = Map.from(await api.post('/safety-talks/recommendations/$id/generate', {}));
      setState(() => recommendations.removeWhere((r) => r['id'] == id));
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => SafetyTalkDetailPage(safetyTalkId: created['id']))).then((_) => load());
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
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
          KpiStat(t('safetyTalkPageFlt.kpiPlanifies'), '${n('planifies')}', color: QhseColors.blue, icon: Icons.event_available),
          KpiStat(t('safetyTalkPageFlt.kpiRealises'), '${n('realises')}', color: QhseColors.green, icon: Icons.check_circle_outline),
          KpiStat(t('safetyTalkPageFlt.kpiEnRetard'), '${n('enRetard')}', color: n('enRetard') > 0 ? QhseColors.red : QhseColors.green, icon: Icons.timer_off_outlined),
          KpiStat(t('safetyTalkPageFlt.kpiAnnules'), '${n('annules')}', color: QhseColors.textSecondary, icon: Icons.cancel_outlined),
          KpiStat(t('safetyTalkPageFlt.kpiTauxRealisation'), '${dash['tauxRealisation'] ?? 0}%', color: QhseColors.green, icon: Icons.trending_up),
          KpiStat(t('safetyTalkPageFlt.kpiParticipants'), '${n('participants')}', color: QhseColors.blue, icon: Icons.groups_outlined),
          KpiStat(t('safetyTalkPageFlt.kpiTauxParticipation'), '${dash['tauxParticipation'] ?? 0}%', color: QhseColors.blue, icon: Icons.how_to_reg_outlined),
          KpiStat(t('safetyTalkPageFlt.kpiThemesTraites'), '${n('themesTraites')}', color: QhseColors.blue, icon: Icons.topic_outlined),
          KpiStat(t('safetyTalkPageFlt.kpiRemonteesTerrain'), '${n('remonteesTerrain')}', color: QhseColors.amber, icon: Icons.campaign_outlined),
          KpiStat(t('safetyTalkPageFlt.kpiDangersDetectes'), '${n('dangersDetectes')}', color: QhseColors.red, icon: Icons.warning_amber_outlined),
          KpiStat(t('safetyTalkPageFlt.kpiActionsCreees'), '${n('actionsCreees')}', color: QhseColors.blue, icon: Icons.playlist_add_check),
          KpiStat(t('safetyTalkPageFlt.kpiActionsCloturees'), '${n('actionsClotures')}', color: QhseColors.green, icon: Icons.task_alt),
          KpiStat(t('safetyTalkPageFlt.kpiActionsEnRetard'), '${n('actionsEnRetard')}', color: n('actionsEnRetard') > 0 ? QhseColors.red : QhseColors.green, icon: Icons.hourglass_bottom),
          KpiStat(t('safetyTalkPageFlt.kpiSujetsAutoGeneres'), '${n('sujetsAutoGeneres')}', color: QhseColors.blue, icon: Icons.auto_awesome),
        ]),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(child: Text(t('safetyTalkPageFlt.themesRecommandes', {'count': '${recommendations.length}'}), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            OutlinedButton.icon(
              onPressed: refreshingReco ? null : refreshAnalyse,
              icon: refreshingReco
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh, size: 16),
              label: Text(t('safetyTalkPageFlt.actualiserAnalyse')),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: Text(
            t('safetyTalkPageFlt.descriptionRecommandations'),
            style: TextStyle(color: QhseColors.textSecondary, fontSize: 11),
          ),
        ),
        const SizedBox(height: 8),
        if (recommendations.isEmpty)
          Padding(padding: const EdgeInsets.all(16), child: Center(child: Text(t('safetyTalkPageFlt.aucuneRecommandation'), style: TextStyle(color: QhseColors.textSecondary))))
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(children: recommendations.map<Widget>((r) => _recoCard(r)).toList()),
          ),
      ]),
    );
  }

  Widget _recoCard(Map r) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${r['theme']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
          prioriteChip(r['priorite']),
        ]),
        const SizedBox(height: 4),
        Text('${r['motif']}', style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 6),
        Row(children: [
          Icon(Icons.hub_outlined, size: 13, color: QhseColors.textSecondary),
          const SizedBox(width: 4),
          Text(t('safetyTalkPageFlt.sources', {'value': '${r['sourceModules'] ?? '—'}'}), style: TextStyle(color: QhseColors.textSecondary, fontSize: 11)),
          const SizedBox(width: 12),
          Icon(Icons.bolt, size: 13, color: QhseColors.textSecondary),
          const SizedBox(width: 4),
          Text(t('safetyTalkPageFlt.score', {'value': '${r['score'] ?? 0}'}), style: TextStyle(color: QhseColors.textSecondary, fontSize: 11)),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: [
          FilledButton.icon(
            onPressed: () => acceptAndGenerate(r['id']),
            icon: const Icon(Icons.check, size: 15),
            label: Text(t('safetyTalkPageFlt.accepterEtGenerer')),
          ),
          OutlinedButton.icon(
            onPressed: () => decision(r['id'], 'REPORTER'),
            icon: const Icon(Icons.schedule, size: 15),
            label: Text(t('safetyTalkPageFlt.reporter')),
          ),
          TextButton.icon(
            onPressed: () => decision(r['id'], 'IGNORER'),
            icon: const Icon(Icons.close, size: 15),
            label: Text(t('safetyTalkPageFlt.ignorer')),
          ),
        ]),
      ]),
    ),
  );
}

// --- Onglet 2 : Liste des séances (recherche par statut) ---
class _SeancesTab extends StatefulWidget {
  const _SeancesTab();
  @override
  State<_SeancesTab> createState() => _SeancesTabState();
}

class _SeancesTabState extends State<_SeancesTab> {
  final api = Api();
  List talks = [];
  bool loading = true;
  Object? error;
  String? statusFilter;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try { talks = List.from(await api.get('/safety-talks')); } catch (e) { error = e; }
    setState(() => loading = false);
  }

  List get _filtered => statusFilter == null ? talks : talks.where((tk) => tk['status'] == statusFilter).toList();

  @override
  Widget build(BuildContext c) => Scaffold(
    body: Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(spacing: 8, children: [
          ChoiceChip(label: Text(t('safetyTalkPageFlt.toutes')), selected: statusFilter == null, onSelected: (_) => setState(() => statusFilter = null)),
          for (final s in statusLabels.keys)
            ChoiceChip(label: Text(statusLabels[s]!), selected: statusFilter == s, onSelected: (_) => setState(() => statusFilter = s)),
        ]),
      ),
      Expanded(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? LoadErrorView(error: error, onRetry: load)
            : RefreshIndicator(
                onRefresh: load,
                child: _filtered.isEmpty
                    ? ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(t('safetyTalkPageFlt.aucuneSeance'))))])
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                          final tk = _filtered[i];
                          return Card(
                            child: ListTile(
                              title: Text('${tk['title']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('${t('safetyTalkPageFlt.semaineDu', {'date': fmtDate(tk['weekStart'])})}${tk['origineType'] == 'AUTO_RECOMMANDE' ? t('safetyTalkPageFlt.autoGenere') : ''}'),
                              trailing: Chip(
                                label: Text(statusLabels[tk['status']] ?? '${tk['status']}'),
                                backgroundColor: statusColor(tk['status']).withOpacity(0.15),
                                labelStyle: TextStyle(color: statusColor(tk['status']), fontSize: 11),
                              ),
                              onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => SafetyTalkDetailPage(safetyTalkId: tk['id']))).then((_) => load()),
                            ),
                          );
                        },
                      ),
              ),
      ),
    ]),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const SafetyTalkFormPage())).then((v) { if (v != null) load(); }),
      icon: const Icon(Icons.add),
      label: Text(t('safetyTalkPageFlt.nouvelleFiche')),
    ),
  );
}

// --- Onglet 3 : Matrice (rapprochement recommandation ↔ séance générée) ---
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
    try { rows = List.from(await api.get('/safety-talks/matrice')); } catch (e) { error = e; }
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext c) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return LoadErrorView(error: error, onRetry: load);
    if (rows.isEmpty) {
      return RefreshIndicator(onRefresh: load, child: ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(t('safetyTalkPageFlt.aucuneDonnee'))))]));
    }
    return RefreshIndicator(
      onRefresh: load,
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              DataColumn(label: Text(t('safetyTalkPageFlt.colSource'))), DataColumn(label: Text(t('safetyTalkPageFlt.colEvenement'))), DataColumn(label: Text(t('safetyTalkPageFlt.colRisque'))),
              DataColumn(label: Text(t('safetyTalkPageFlt.colTheme'))), DataColumn(label: Text(t('safetyTalkPageFlt.colPriorite'))), DataColumn(label: Text(t('safetyTalkPageFlt.colStatut'))),
            ],
            rows: rows.map((r) => DataRow(cells: [
              DataCell(Text('${r['source'] ?? ''}')), DataCell(Text('${r['evenement'] ?? '—'}')), DataCell(Text('${r['risque'] ?? '—'}')),
              DataCell(Text('${r['theme'] ?? ''}')), DataCell(prioriteChip(r['priorite'])), DataCell(Text('${statusLabels[r['statut']] ?? r['statut'] ?? ''}')),
            ])).toList(),
          ),
        ),
      ),
    );
  }
}
