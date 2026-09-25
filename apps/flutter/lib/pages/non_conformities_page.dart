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
import 'capa_link_widget.dart';
import 'validation_history_widgets.dart';
import 'document_link_widget.dart';
import 'attachments_widget.dart';
import 'load_error_view.dart';

Map<String, String> get _ncStatusLabels => {'OPEN': t('nonConformitiesPageFlt.statut.ouverte'), 'IN_PROGRESS': t('nonConformitiesPageFlt.statut.enCours'), 'CLOSED': t('nonConformitiesPageFlt.statut.cloturee')};
Map<String, String> get _ncCriticiteLabels => {'MINEURE': t('nonConformitiesPageFlt.criticite.mineure'), 'MODEREE': t('nonConformitiesPageFlt.criticite.moderee'), 'MAJEURE': t('nonConformitiesPageFlt.criticite.majeure'), 'CRITIQUE': t('nonConformitiesPageFlt.criticite.critique')};
Map<String, String> get _ncEffLabels => {'EFFICACE': t('nonConformitiesPageFlt.efficacite.efficace'), 'PARTIELLEMENT_EFFICACE': t('nonConformitiesPageFlt.efficacite.partiellementEfficace'), 'INEFFICACE': t('nonConformitiesPageFlt.efficacite.inefficace')};

Color _ncCriticiteColor(String? n) => {
      'CRITIQUE': QhseColors.red, 'MAJEURE': QhseColors.amber,
      'MODEREE': const Color(0xFFB45309), 'MINEURE': QhseColors.green,
    }[n] ?? QhseColors.textSecondary;
// Export CSV du registre (finding #30 de l'audit — export manquant côté
// mobile alors qu'il existe déjà côté web, cf. exportNcExcel).
String _csvEscape(String v) => v.contains(',') || v.contains('"') || v.contains('\n') ? '"${v.replaceAll('"', '""')}"' : v;

// --- Écran principal : tableau de bord + registre des non-conformités ---
class NonConformitiesPage extends StatefulWidget {
  const NonConformitiesPage({super.key});
  @override
  State<NonConformitiesPage> createState() => _NonConformitiesPageState();
}

class _NonConformitiesPageState extends State<NonConformitiesPage> {
  final api = Api();
  List items = [], recurrentes = [], trends = [], alertes = [];
  Map dashboard = {}, ncSettings = {};
  Map? syntheseDirection;
  bool syntheseLoading = false;
  bool loading = true;
  Object? error;
  bool exporting = false;
  String? filter;
  bool multiSelectMode = false;
  Set<String> selectedIds = {};
  // Recherche harmonisée (audit priorité 7, finding #18 — déjà côté web,
  // absente côté mobile).
  String search = '';

  @override
  void initState() { super.initState(); load(); }

  // --- Export CSV du registre des non-conformités (mêmes colonnes que
  // l'export Excel du back-office, cf. exportNcExcel côté web) ---
  Future<void> exportCsv() async {
    setState(() => exporting = true);
    try {
      final headers = [t('nonConformitiesPageFlt.csv.code'), t('nonConformitiesPageFlt.csv.titre'), t('nonConformitiesPageFlt.csv.source'), t('nonConformitiesPageFlt.csv.type'), t('nonConformitiesPageFlt.csv.criticite'), t('nonConformitiesPageFlt.csv.score'), t('nonConformitiesPageFlt.csv.uniteTravail'), t('nonConformitiesPageFlt.csv.responsable'), t('nonConformitiesPageFlt.csv.date'), t('nonConformitiesPageFlt.csv.echeance'), t('nonConformitiesPageFlt.csv.statut'), t('nonConformitiesPageFlt.csv.efficacite')];
      final buffer = StringBuffer();
      buffer.writeln(headers.map((v) => _csvEscape(v)).join(','));
      for (final n in items) {
        buffer.writeln([
          n['code'], n['title'], n['source'] ?? '', n['classification'] ?? '', n['criticiteNiveau'] ?? '', n['criticiteScore'] ?? '',
          n['workUnit']?['name'] ?? '', n['responsible'] != null ? '${n['responsible']['firstName']} ${n['responsible']['lastName']}' : '',
          n['occurredAt'] != null ? DateTime.parse(n['occurredAt']).toIso8601String().substring(0, 10) : '',
          n['dueDate'] != null ? DateTime.parse(n['dueDate']).toIso8601String().substring(0, 10) : '',
          n['status'] ?? '', n['effectivenessResult'] ?? '',
        ].map((v) => _csvEscape('$v')).join(','));
      }
      final dir = await getTemporaryDirectory();
      final fileName = 'Non-conformites-${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes([0xEF, 0xBB, 0xBF, ...buffer.toString().codeUnits]);
      await Share.shareXFiles([XFile(file.path)], text: t('nonConformitiesPageFlt.share.registre'));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    setState(() => exporting = false);
  }

  Future<void> generateSynthese() async {
    setState(() => syntheseLoading = true);
    try { syntheseDirection = Map.from(await api.get('/business/nc-synthese-direction')); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
    setState(() => syntheseLoading = false);
  }

  Color _alerteColor(String? n) => {
        'CRITIQUE': QhseColors.red, 'URGENT': QhseColors.red,
        'ATTENTION': QhseColors.amber, 'INFORMATION': QhseColors.blue,
      }[n] ?? QhseColors.textSecondary;

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final q = filter != null ? '?status=$filter' : '';
      items = List.from(await api.get('/business/non-conformities$q'));
      dashboard = Map.from(await api.get('/business/nc-dashboard'));
      recurrentes = List.from(await api.get('/business/nc-recurrentes'));
      trends = List.from(await api.get('/business/nc-trends'));
      ncSettings = Map.from(await api.get('/business/nc-settings'));
      alertes = List.from(await api.get('/business/nc-alertes'));
    } catch (e) { error = e; }
    setState(() => loading = false);
  }

  Future<void> editSettings() async {
    final seuilModeree = TextEditingController(text: '${ncSettings['seuilModeree'] ?? 20}');
    final seuilMajeure = TextEditingController(text: '${ncSettings['seuilMajeure'] ?? 50}');
    final seuilCritique = TextEditingController(text: '${ncSettings['seuilCritique'] ?? 75}');
    final delai = TextEditingController(text: '${ncSettings['delaiStandardJours'] ?? 30}');
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: Text(t('nonConformitiesPageFlt.settings.titre')),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: seuilModeree, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('nonConformitiesPageFlt.settings.seuilModeree'))),
        TextField(controller: seuilMajeure, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('nonConformitiesPageFlt.settings.seuilMajeure'))),
        TextField(controller: seuilCritique, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('nonConformitiesPageFlt.settings.seuilCritique'))),
        TextField(controller: delai, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('nonConformitiesPageFlt.settings.delai'))),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t('nonConformitiesPageFlt.common.annuler'))), FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(t('nonConformitiesPageFlt.common.enregistrer')))],
    ));
    if (ok != true) return;
    try {
      await api.patch('/business/nc-settings', {
        'seuilModeree': int.tryParse(seuilModeree.text) ?? 20, 'seuilMajeure': int.tryParse(seuilMajeure.text) ?? 50,
        'seuilCritique': int.tryParse(seuilCritique.text) ?? 75, 'delaiStandardJours': int.tryParse(delai.text) ?? 30,
      });
      load();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  Future<void> delete(Map n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t('nonConformitiesPageFlt.delete.titre')),
        content: Text(t('nonConformitiesPageFlt.delete.message', {'code': '${n['code']}', 'titre': '${n['title']}'})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t('nonConformitiesPageFlt.common.annuler'))),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(t('nonConformitiesPageFlt.delete.confirmer'), style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.delete('/business/non-conformities/${n['id']}');
      load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext c) => DefaultTabController(
    length: 3,
    child: Scaffold(
      appBar: AppBar(
        title: Text(t('nonConformitiesPageFlt.titre')),
        bottom: TabBar(tabs: [Tab(text: t('nonConformitiesPageFlt.onglets.registre')), Tab(text: t('nonConformitiesPageFlt.onglets.recurrence')), Tab(text: t('nonConformitiesPageFlt.onglets.analyses'))]),
        actions: [
          IconButton(
            icon: Icon(multiSelectMode ? Icons.close : Icons.checklist_outlined),
            tooltip: multiSelectMode ? t('nonConformitiesPageFlt.selection.annuler') : t('nonConformitiesPageFlt.selection.multiple'),
            onPressed: () => setState(() { multiSelectMode = !multiSelectMode; selectedIds = {}; }),
          ),
          IconButton(icon: exporting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.ios_share), tooltip: t('nonConformitiesPageFlt.export.tooltip'), onPressed: exporting ? null : exportCsv),
          IconButton(icon: const Icon(Icons.settings_outlined), tooltip: t('nonConformitiesPageFlt.settings.tooltip'), onPressed: editSettings),
        ],
      ),
      floatingActionButton: multiSelectMode
          ? (selectedIds.isNotEmpty
              ? FloatingActionButton.extended(
                  onPressed: () async {
                    final sources = selectedIds.map((id) {
                      final n = items.firstWhere((x) => x['id'] == id, orElse: () => {});
                      return {'sourceModule': 'NON_CONFORMITY', 'sourceEntityId': id, 'label': '${n['code'] ?? ''} — ${n['title'] ?? ''}'};
                    }).toList();
                    final ok = await Navigator.push(c, MaterialPageRoute(builder: (_) => CapaCommonFormPage(sources: List<Map<String, String>>.from(sources.map((s) => s.map((k, v) => MapEntry(k, '$v')))))));
                    if (ok == true) { setState(() { multiSelectMode = false; selectedIds = {}; }); load(); }
                  },
                  icon: const Icon(Icons.merge_type),
                  label: Text(t('nonConformitiesPageFlt.capa.commune', {'count': '${selectedIds.length}'})),
                )
              : null)
          : FloatingActionButton.extended(
              onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const NcFormPage())).then((_) => load()),
              icon: const Icon(Icons.add),
              label: Text(t('nonConformitiesPageFlt.fab.declarer')),
            ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? LoadErrorView(error: error, onRetry: load)
          : TabBarView(children: [_buildRegistre(c), _buildRecurrence(), _buildAnalyses()]),
    ),
  );

  List get _filteredItems {
    if (search.trim().isEmpty) return items;
    final q = search.trim().toLowerCase();
    return items.where((n) => ('${n['code'] ?? ''} ${n['title'] ?? ''} ${n['source'] ?? ''}').toLowerCase().contains(q)).toList();
  }

  Widget _buildRegistre(BuildContext c) => Column(children: [
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(spacing: 8, children: [
        ChoiceChip(label: Text(t('nonConformitiesPageFlt.filtre.toutes')), selected: filter == null, onSelected: (_) { filter = null; load(); }),
        for (final s in _ncStatusLabels.keys)
          ChoiceChip(label: Text(_ncStatusLabels[s]!), selected: filter == s, onSelected: (_) { filter = s; load(); }),
      ]),
    ),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        decoration: InputDecoration(prefixIcon: const Icon(Icons.search, size: 20), hintText: t('nonConformitiesPageFlt.recherche.hint'), isDense: true, border: const OutlineInputBorder()),
        onChanged: (v) => setState(() => search = v),
      ),
    ),
    Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: KpiBar([
        KpiStat(t('nonConformitiesPageFlt.kpi.total'), '${dashboard['total'] ?? items.length}', color: QhseColors.red, icon: Icons.error_outline),
        KpiStat(t('nonConformitiesPageFlt.kpi.ouvertes'), '${dashboard['ouvertes'] ?? 0}', color: QhseColors.amber, icon: Icons.hourglass_empty),
        KpiStat(t('nonConformitiesPageFlt.kpi.critiques'), '${dashboard['critiques'] ?? 0}', color: (dashboard['critiques'] ?? 0) > 0 ? QhseColors.red : QhseColors.green, icon: Icons.warning_amber_outlined),
        KpiStat(t('nonConformitiesPageFlt.kpi.enRetard'), '${dashboard['enRetard'] ?? 0}', color: (dashboard['enRetard'] ?? 0) > 0 ? QhseColors.red : QhseColors.green, icon: Icons.timer_off_outlined),
        KpiStat(t('nonConformitiesPageFlt.kpi.tauxCloture'), '${dashboard['tauxCloture'] ?? '—'}%', color: QhseColors.blue, icon: Icons.check_circle_outline),
      ]),
    ),
    Expanded(
      child: RefreshIndicator(
        onRefresh: load,
        child: _filteredItems.isEmpty
            ? ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(search.trim().isEmpty ? t('nonConformitiesPageFlt.vide.aucuneNc') : t('nonConformitiesPageFlt.vide.aucunResultat'))))])
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _filteredItems.length,
                itemBuilder: (_, i) {
                  final n = _filteredItems[i];
                  final actions = List.from(n['actions'] ?? []);
                  final selected = selectedIds.contains(n['id']);
                  return Card(
                    child: ListTile(
                      leading: multiSelectMode
                          ? Checkbox(value: selected, onChanged: (_) => setState(() { if (selected) { selectedIds.remove(n['id']); } else { selectedIds.add(n['id']); } }))
                          : n['criticiteNiveau'] != null
                              ? CircleAvatar(backgroundColor: _ncCriticiteColor(n['criticiteNiveau']), child: Text('${n['criticiteScore'] ?? ''}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)))
                              : null,
                      title: Text('${n['code']} — ${n['title']}'),
                      subtitle: Text('${_ncStatusLabels[n['status']] ?? n['status']} · ${t('nonConformitiesPageFlt.item.actions', {'count': '${actions.length}'})}${n['criticiteNiveau'] != null ? ' · ${_ncCriticiteLabels[n['criticiteNiveau']]}' : ''}'),
                      selected: selected,
                      onTap: multiSelectMode
                          ? () => setState(() { if (selected) { selectedIds.remove(n['id']); } else { selectedIds.add(n['id']); } })
                          : () => Navigator.push(c, MaterialPageRoute(builder: (_) => NonConformityDetailPage(ncId: n['id']))).then((_) => load()),
                      onLongPress: multiSelectMode || !Api.canManage ? null : () => delete(n),
                    ),
                  );
                },
              ),
      ),
    ),
  ]);

  Widget _buildRecurrence() => RefreshIndicator(
    onRefresh: load,
    child: recurrentes.isEmpty
        ? ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(t('nonConformitiesPageFlt.vide.aucuneRecurrence'))))])
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: recurrentes.length,
            itemBuilder: (_, i) {
              final r = recurrentes[i];
              return Card(child: Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Expanded(child: Text('${r['titre']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: QhseColors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Text(t('nonConformitiesPageFlt.recurrence.occurrences', {'count': '${r['occurrences']}'}), style: TextStyle(color: QhseColors.red, fontSize: 11))),
                ]),
                const SizedBox(height: 4),
                Text(t('nonConformitiesPageFlt.recurrence.derniereOccurrence', {'processus': '${r['processus']}', 'date': '${r['derniereOccurrence']}'.substring(0, 10)}), style: TextStyle(color: QhseColors.textSecondary, fontSize: 11)),
              ])));
            },
          ),
  );

  Widget _buildAnalyses() => RefreshIndicator(
    onRefresh: load,
    child: ListView(padding: const EdgeInsets.all(16), children: [
      Text(t('nonConformitiesPageFlt.analyses.alertesTitre'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: QhseColors.textPrimary)),
      const SizedBox(height: 4),
      Text(t('nonConformitiesPageFlt.analyses.alertesCount', {'count': '${alertes.length}'}), style: TextStyle(fontSize: 11, color: QhseColors.textSecondary)),
      const SizedBox(height: 8),
      alertes.isEmpty
          ? Card(child: Padding(padding: const EdgeInsets.all(16), child: Center(child: Text(t('nonConformitiesPageFlt.analyses.aucuneAlerte'), style: TextStyle(color: QhseColors.textSecondary)))))
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
      const SizedBox(height: 20),
      Text(t('nonConformitiesPageFlt.analyses.evolutionTitre'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: QhseColors.textPrimary)),
      const SizedBox(height: 8),
      SizedBox(height: 200, child: trends.isEmpty ? Center(child: Text(t('nonConformitiesPageFlt.analyses.pasAssezDonnees'), style: TextStyle(color: QhseColors.textSecondary))) : _NcTrendChart(trends: trends)),
      const SizedBox(height: 20),
      Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t('nonConformitiesPageFlt.analyses.coutTitre'), style: TextStyle(fontSize: 12, color: QhseColors.textSecondary)),
        const SizedBox(height: 4),
        Text('${dashboard['coutTotalNonQualite'] ?? '—'}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        Text(t('nonConformitiesPageFlt.analyses.coutMoyen', {'value': '${dashboard['coutMoyenParNc'] ?? '—'}'}), style: TextStyle(fontSize: 12, color: QhseColors.textSecondary)),
      ]))),
      const SizedBox(height: 20),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(t('nonConformitiesPageFlt.analyses.syntheseTitre'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: QhseColors.textPrimary)),
        FilledButton.icon(
          onPressed: syntheseLoading ? null : generateSynthese,
          icon: syntheseLoading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.summarize_outlined, size: 16),
          label: Text(t('nonConformitiesPageFlt.analyses.genererBtn')),
        ),
      ]),
      if (syntheseDirection != null) ...[
        const SizedBox(height: 8),
        Text(t('nonConformitiesPageFlt.analyses.genereLe', {'date': (syntheseDirection!['genereLe'] ?? '').toString().substring(0, 10)}), style: TextStyle(fontSize: 11, color: QhseColors.textSecondary)),
        const SizedBox(height: 8),
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final entry in <List<Object?>>[
            [t('nonConformitiesPageFlt.synthese.totalNc'), syntheseDirection!['dashboard']?['total']],
            [t('nonConformitiesPageFlt.synthese.ncCritiques'), syntheseDirection!['dashboard']?['critiques']],
            [t('nonConformitiesPageFlt.synthese.ncMajeures'), syntheseDirection!['dashboard']?['majeures']],
            [t('nonConformitiesPageFlt.synthese.tauxCloture'), syntheseDirection!['dashboard']?['tauxCloture'] != null ? '${syntheseDirection!['dashboard']['tauxCloture']}%' : '—'],
            [t('nonConformitiesPageFlt.synthese.actionsEnRetard'), syntheseDirection!['dashboard']?['actionsEnRetard']],
            [t('nonConformitiesPageFlt.synthese.coutTotal'), syntheseDirection!['dashboard']?['coutTotalNonQualite']],
          ])
            Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${entry[0]}', style: TextStyle(fontSize: 12, color: QhseColors.textSecondary)),
              Text('${entry[1] ?? '—'}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ])),
        ]))),
        if ((syntheseDirection!['processusLesPlusProblematiques'] as List?)?.isNotEmpty ?? false) ...[
          const SizedBox(height: 12),
          Text(t('nonConformitiesPageFlt.synthese.processusProblematiques'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: QhseColors.textPrimary)),
          for (final p in (syntheseDirection!['processusLesPlusProblematiques'] as List))
            ListTile(dense: true, title: Text('${p['processus']}', style: const TextStyle(fontSize: 12)), trailing: Text('${p['nombre']}')),
        ],
        if ((syntheseDirection!['principalesRecurrences'] as List?)?.isNotEmpty ?? false) ...[
          const SizedBox(height: 12),
          Text(t('nonConformitiesPageFlt.synthese.principalesRecurrences'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: QhseColors.textPrimary)),
          for (final r in (syntheseDirection!['principalesRecurrences'] as List))
            ListTile(dense: true, title: Text('${r['titre']}', style: const TextStyle(fontSize: 12)), trailing: Text('${r['occurrences']}')),
        ],
      ],
    ]),
  );
}

/// Évolution mensuelle des nouvelles NC (fl_chart LineChart, même style que
/// les autres graphiques déjà présents dans l'app).
class _NcTrendChart extends StatelessWidget {
  final List trends;
  const _NcTrendChart({required this.trends});

  @override
  Widget build(BuildContext context) {
    final spots = [for (int i = 0; i < trends.length; i++) FlSpot(i.toDouble(), ((trends[i]['nouvelles'] ?? 0) as num).toDouble())];
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
      lineBarsData: [LineChartBarData(spots: spots, isCurved: true, color: QhseColors.red, barWidth: 2, dotData: const FlDotData(show: true), belowBarData: BarAreaData(show: true, color: QhseColors.red.withOpacity(0.08)))],
    ));
  }
}

// --- Formulaire de déclaration / modification ---
class NcFormPage extends StatefulWidget {
  final Map? record;
  const NcFormPage({super.key, this.record});
  @override
  State<NcFormPage> createState() => _NcFormPageState();
}

class _NcFormPageState extends State<NcFormPage> {
  final api = Api();
  bool get editing => widget.record != null;
  List workUnits = [], users = [];
  final title = TextEditingController();
  final description = TextEditingController();
  final source = TextEditingController(text: 'Terrain');
  final classification = TextEditingController();
  DateTime occurredAt = DateTime.now();
  DateTime? dueDate;
  String? workUnitId, declarantId, responsibleId;
  int? gravite, probabilite, etendue;
  bool busy = false, loadingLists = true;
  String? error;

  @override
  void initState() {
    super.initState();
    final n = widget.record;
    if (n != null) {
      title.text = n['title'] ?? '';
      description.text = n['description'] ?? '';
      source.text = n['source'] ?? '';
      classification.text = n['classification'] ?? '';
      occurredAt = DateTime.tryParse(n['occurredAt'] ?? '') ?? occurredAt;
      dueDate = n['dueDate'] != null ? DateTime.tryParse(n['dueDate']) : null;
      workUnitId = n['workUnitId']; declarantId = n['declarantId']; responsibleId = n['responsibleId'];
      gravite = n['gravite']; probabilite = n['probabilite']; etendue = n['etendue'];
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

  Future<void> pickDate(bool isDue) async {
    final d = await showDatePicker(context: context, initialDate: isDue ? (dueDate ?? DateTime.now()) : occurredAt, firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 730)));
    if (d != null) setState(() { if (isDue) dueDate = d; else occurredAt = d; });
  }

  Future<void> submit() async {
    if (title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('nonConformitiesPageFlt.form.titreObligatoire'))));
      return;
    }
    setState(() { busy = true; error = null; });
    final payload = {
      'title': title.text.trim(), 'description': description.text.trim().isEmpty ? null : description.text.trim(),
      'source': source.text.trim().isEmpty ? null : source.text.trim(), 'classification': classification.text.trim().isEmpty ? null : classification.text.trim(),
      'occurredAt': occurredAt.toIso8601String(), 'dueDate': dueDate?.toIso8601String(),
      'workUnitId': workUnitId, 'declarantId': declarantId, 'responsibleId': responsibleId,
      'gravite': gravite, 'probabilite': probabilite, 'etendue': etendue, 'severity': gravite ?? 2,
    };
    try {
      if (editing) {
        await api.patch('/business/non-conformities/${widget.record!['id']}', payload);
      } else {
        await api.post('/business/non-conformities', {'code': genCode('NC'), ...payload});
      }
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (e.networkError && !editing) {
        await SyncQueue.enqueue('nonConformity', 'CREATE', {'code': genCode('NC'), ...payload});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('nonConformitiesPageFlt.form.horsLigne')), duration: const Duration(seconds: 4)));
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

  Widget _criticiteSlider(String label, int? value, ValueChanged<int> onChanged) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$label : ${value ?? '—'} / 5', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Slider(value: (value ?? 1).toDouble(), min: 1, max: 5, divisions: 4, label: '${value ?? 1}', onChanged: (v) => onChanged(v.round())),
      ]);

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text(editing ? t('nonConformitiesPageFlt.form.titreModifier') : t('nonConformitiesPageFlt.form.titreNouvelle'))),
    body: loadingLists
        ? const Center(child: CircularProgressIndicator())
        : ListView(padding: const EdgeInsets.all(16), children: [
            TextField(controller: title, decoration: InputDecoration(labelText: t('nonConformitiesPageFlt.form.champTitre'))),
            const SizedBox(height: 12),
            TextField(controller: description, maxLines: 4, decoration: InputDecoration(labelText: t('nonConformitiesPageFlt.form.champDescription'))),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: source, decoration: InputDecoration(labelText: t('nonConformitiesPageFlt.form.champOrigine')))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: classification, decoration: InputDecoration(labelText: t('nonConformitiesPageFlt.form.champType')))),
            ]),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: workUnitId, isExpanded: true, decoration: InputDecoration(labelText: t('nonConformitiesPageFlt.form.champUnite')),
              items: [const DropdownMenuItem<String>(value: null, child: Text('—')), ...workUnits.map<DropdownMenuItem<String>>((w) => DropdownMenuItem<String>(value: w['id'] as String, child: Text(w['name'] ?? '')))],
              onChanged: (v) => setState(() => workUnitId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: responsibleId, isExpanded: true, decoration: InputDecoration(labelText: t('nonConformitiesPageFlt.form.champResponsable')),
              items: [const DropdownMenuItem<String>(value: null, child: Text('—')), ...users.map<DropdownMenuItem<String>>((u) => DropdownMenuItem<String>(value: u['id'] as String, child: Text('${u['firstName']} ${u['lastName']}')))],
              onChanged: (v) => setState(() => responsibleId = v),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: () => pickDate(false), icon: const Icon(Icons.event), label: Text(t('nonConformitiesPageFlt.form.dateLabel', {'date': occurredAt.toIso8601String().substring(0, 10)}))),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: () => pickDate(true), icon: const Icon(Icons.event_busy), label: Text(dueDate != null ? t('nonConformitiesPageFlt.form.echeanceLabel', {'date': dueDate!.toIso8601String().substring(0, 10)}) : t('nonConformitiesPageFlt.form.echeanceOptionnel'))),
            const SizedBox(height: 16),
            Text(t('nonConformitiesPageFlt.form.criticiteAuto'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: QhseColors.textSecondary)),
            _criticiteSlider(t('nonConformitiesPageFlt.form.gravite'), gravite, (v) => setState(() => gravite = v)),
            _criticiteSlider(t('nonConformitiesPageFlt.form.probabilite'), probabilite, (v) => setState(() => probabilite = v)),
            _criticiteSlider(t('nonConformitiesPageFlt.form.etendue'), etendue, (v) => setState(() => etendue = v)),
            if (editing && widget.record!['criticiteScore'] != null) Text(t('nonConformitiesPageFlt.form.scoreActuel', {'score': '${widget.record!['criticiteScore']}', 'niveau': '${_ncCriticiteLabels[widget.record!['criticiteNiveau']]}'}), style: const TextStyle(fontWeight: FontWeight.bold)),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : submit, child: Text(busy ? t('nonConformitiesPageFlt.form.envoi') : t('nonConformitiesPageFlt.common.enregistrer')))),
          ]),
  );
}

// --- Détail : confinement, causes, coûts, vérification d'efficacité ---
class NonConformityDetailPage extends StatefulWidget {
  final String ncId;
  const NonConformityDetailPage({super.key, required this.ncId});
  @override
  State<NonConformityDetailPage> createState() => _NonConformityDetailPageState();
}

class _NonConformityDetailPageState extends State<NonConformityDetailPage> {
  final api = Api();
  Map? nc;
  bool loading = true, busy = false;
  String? error;
  List<dynamic> suggestions = [];
  bool loadingSuggestions = true;
  String effResult = '';
  final effNotes = TextEditingController();

  @override
  void initState() { super.initState(); load(); loadSuggestions(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try { nc = Map.from(await api.get('/business/non-conformities/${widget.ncId}')); }
    catch (e) { error = '$e'; }
    setState(() => loading = false);
  }

  Future<void> loadSuggestions() async {
    try {
      final r = await api.post('/recommendations/suggest', {'title': nc?['title'] ?? '', 'description': nc?['description'] ?? ''});
      suggestions = List.from(r['suggestions'] ?? []);
    } catch (_) {}
    setState(() => loadingSuggestions = false);
  }

  Future<void> saveEffectiveness() async {
    if (effResult.isEmpty) return;
    setState(() => busy = true);
    try {
      await api.post('/business/non-conformities/${widget.ncId}/effectiveness', {'result': effResult, 'notes': effNotes.text.trim().isEmpty ? null : effNotes.text.trim()});
      load();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
    setState(() => busy = false);
  }

  Future<void> close() async {
    setState(() => busy = true);
    try { await api.post('/business/non-conformities/${widget.ncId}/close', {}); load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
    setState(() => busy = false);
  }

  Future<void> reopen() async {
    setState(() => busy = true);
    try { await api.post('/business/non-conformities/${widget.ncId}/reopen', {}); load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
    setState(() => busy = false);
  }

  Future<void> createAction(String initialTitle) async {
    final tCtrl = TextEditingController(text: initialTitle);
    final r = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t('nonConformitiesPageFlt.action.nouvelleTitre')),
        content: TextField(controller: tCtrl, maxLines: 2, decoration: InputDecoration(labelText: t('nonConformitiesPageFlt.action.champTitre'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t('nonConformitiesPageFlt.action.refuser'))),
          FilledButton(onPressed: () => Navigator.pop(context, tCtrl.text), child: Text(t('nonConformitiesPageFlt.action.accepter'))),
        ],
      ),
    );
    if (r == null || r.trim().isEmpty) return;
    try {
      final due = DateTime.now().add(const Duration(days: 7));
      await api.post('/business/actions', {
        'code': genCode('ACT'), 'title': r.trim(), 'status': 'OPEN', 'priority': 2,
        'dueDate': due.toIso8601String(), 'nonConformityId': widget.ncId,
      });
      load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> addContainment() async {
    final type = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: Text(t('nonConformitiesPageFlt.confinement.titre')),
      content: TextField(controller: type, decoration: InputDecoration(labelText: t('nonConformitiesPageFlt.confinement.champHint'))),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t('nonConformitiesPageFlt.common.annuler'))), FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(t('nonConformitiesPageFlt.common.ajouter')))],
    ));
    if (ok != true || type.text.trim().isEmpty) return;
    try { await api.post('/business/nc-containment-actions', {'type': type.text.trim(), 'nonConformityId': widget.ncId}); load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  Future<void> addCause() async {
    final desc = TextEditingController();
    String methode = '5_POURQUOI';
    bool estRacine = false;
    final ok = await showDialog<bool>(context: context, builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
      title: Text(t('nonConformitiesPageFlt.causes.titre')),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: methode, items: [DropdownMenuItem(value: '5_POURQUOI', child: Text(t('nonConformitiesPageFlt.causes.methode5pourquoi'))), DropdownMenuItem(value: 'ISHIKAWA', child: Text(t('nonConformitiesPageFlt.causes.methodeIshikawa'))), DropdownMenuItem(value: 'AUTRE', child: Text(t('nonConformitiesPageFlt.causes.methodeAutre')))], onChanged: (v) => setD(() => methode = v ?? '5_POURQUOI')),
        TextField(controller: desc, maxLines: 2, decoration: InputDecoration(labelText: t('nonConformitiesPageFlt.causes.champDescription'))),
        CheckboxListTile(contentPadding: EdgeInsets.zero, value: estRacine, title: Text(t('nonConformitiesPageFlt.causes.caseRacine'), style: const TextStyle(fontSize: 13)), onChanged: (v) => setD(() => estRacine = v ?? false)),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t('nonConformitiesPageFlt.common.annuler'))), FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(t('nonConformitiesPageFlt.common.ajouter')))],
    )));
    if (ok != true || desc.text.trim().isEmpty) return;
    try { await api.post('/business/nc-causes', {'methode': methode, 'description': desc.text.trim(), 'estRacine': estRacine, 'nonConformityId': widget.ncId}); load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  Future<void> addCost() async {
    final type = TextEditingController();
    final montant = TextEditingController();
    final desc = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: Text(t('nonConformitiesPageFlt.analyses.coutTitre')),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: type, decoration: InputDecoration(labelText: t('nonConformitiesPageFlt.cost.champType'))),
        TextField(controller: montant, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: t('nonConformitiesPageFlt.cost.champMontant'))),
        TextField(controller: desc, decoration: InputDecoration(labelText: t('nonConformitiesPageFlt.cost.champDescription'))),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t('nonConformitiesPageFlt.common.annuler'))), FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(t('nonConformitiesPageFlt.common.ajouter')))],
    ));
    if (ok != true || type.text.trim().isEmpty || montant.text.trim().isEmpty) return;
    try {
      await api.post('/business/nc-costs', {
        'type': type.text.trim(), 'montant': double.tryParse(montant.text.trim()) ?? 0,
        'description': desc.text.trim().isEmpty ? null : desc.text.trim(), 'nonConformityId': widget.ncId,
      });
      load();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  @override
  Widget build(BuildContext c) {
    if (loading) return Scaffold(appBar: AppBar(title: Text(t('nonConformitiesPageFlt.detail.titre'))), body: const Center(child: CircularProgressIndicator()));
    if (error != null || nc == null) return Scaffold(appBar: AppBar(title: Text(t('nonConformitiesPageFlt.detail.titre'))), body: Center(child: Text(error ?? t('nonConformitiesPageFlt.detail.introuvable'))));
    final n = nc!;
    final actions = List.from(n['actions'] ?? []);
    final containment = List.from(n['containmentActions'] ?? []);
    final causes = List.from(n['causes'] ?? []);
    final costs = List.from(n['costs'] ?? []);

    return Scaffold(
      appBar: AppBar(title: Text('${n['code']}'), actions: [
        IconButton(icon: const Icon(Icons.camera_alt_outlined), onPressed: () => captureAndLinkPhoto(context, api, 'NON_CONFORMITY', n['id'])),
        IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => NcFormPage(record: n))).then((_) => load())),
      ]),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('${n['title']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (n['description'] != null) Text('${n['description']}'),
            const SizedBox(height: 12),
            Row(children: [
              Chip(label: Text(_ncStatusLabels[n['status']] ?? n['status'])),
              if (n['status'] == 'CLOSED') ...[const SizedBox(width: 8), OutlinedButton(onPressed: busy ? null : reopen, child: Text(t('nonConformitiesPageFlt.detail.reouvrir')))]
              else ...[const SizedBox(width: 8), FilledButton(
                  // Finding #23 — pas de clôture pendant que la validation est en cours.
                  onPressed: busy || n['effectivenessResult'] != 'EFFICACE' || n['validationStatus'] == 'SOUMISE' || n['validationStatus'] == 'REJETEE' ? null : close,
                  child: Text(t('nonConformitiesPageFlt.detail.cloturer')),
                )],
            ]),
            if (n['criticiteNiveau'] != null) ...[
              const SizedBox(height: 8),
              Text(t('nonConformitiesPageFlt.detail.criticiteLabel', {'score': '${n['criticiteScore']}', 'niveau': '${_ncCriticiteLabels[n['criticiteNiveau']]}'}), style: TextStyle(color: _ncCriticiteColor(n['criticiteNiveau']), fontWeight: FontWeight.bold)),
            ],
            const SizedBox(height: 20),
            CapaLinksSection(sourceModule: 'NON_CONFORMITY', sourceEntityId: n['id'], prefill: {'title': 'Traiter — ${n['title']}', 'source': 'Non-conformité', 'criticite': n['criticiteNiveau']}),
            DocumentLinksSection(sourceModule: 'NON_CONFORMITY', sourceEntityId: n['id']),
            ValidationWorkflowSection(item: n, endpointBase: '/business/non-conformities/${n['id']}', onChanged: load),
            const SizedBox(height: 12),
            HistorySection(module: 'NC', entityId: n['id']),
            const SizedBox(height: 12),

            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(t('nonConformitiesPageFlt.detail.confinementTitre'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              TextButton.icon(onPressed: addContainment, icon: const Icon(Icons.add, size: 16), label: Text(t('nonConformitiesPageFlt.common.ajouter'))),
            ]),
            if (containment.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(t('nonConformitiesPageFlt.detail.aucunConfinement'), style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
            else ...containment.map((ca) => Card(child: ListTile(dense: true, title: Text('${ca['type']}'), subtitle: Text(ca['description'] ?? '')))),

            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(t('nonConformitiesPageFlt.causes.titre'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              TextButton.icon(onPressed: addCause, icon: const Icon(Icons.add, size: 16), label: Text(t('nonConformitiesPageFlt.common.ajouter'))),
            ]),
            if (causes.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(t('nonConformitiesPageFlt.detail.aucuneCause'), style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
            else ...causes.map((cs) => Card(child: ListTile(dense: true, title: Text('${cs['description']}'), subtitle: Text('${cs['methode']}${cs['estRacine'] == true ? ' · Racine' : ''}')))),

            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(costs.isNotEmpty ? t('nonConformitiesPageFlt.detail.coutAvecTotal', {'total': '${costs.fold<double>(0, (s, c) => s + ((c['montant'] ?? 0) as num).toDouble())}'}) : t('nonConformitiesPageFlt.analyses.coutTitre'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              TextButton.icon(onPressed: addCost, icon: const Icon(Icons.add, size: 16), label: Text(t('nonConformitiesPageFlt.common.ajouter'))),
            ]),
            if (costs.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(t('nonConformitiesPageFlt.detail.aucunCout'), style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
            else ...costs.map((co) => Card(child: ListTile(dense: true, title: Text('${co['type']}'), subtitle: co['description'] != null ? Text('${co['description']}') : null, trailing: Text('${co['montant']}', style: const TextStyle(fontWeight: FontWeight.bold))))),

            const SizedBox(height: 16),
            Text(t('nonConformitiesPageFlt.detail.verifTitre'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            if (n['effectivenessResult'] != null) Text(t('nonConformitiesPageFlt.detail.dernierResultat', {'resultat': '${_ncEffLabels[n['effectivenessResult']]}'}), style: TextStyle(color: n['effectivenessResult'] == 'EFFICACE' ? QhseColors.green : n['effectivenessResult'] == 'INEFFICACE' ? QhseColors.red : QhseColors.amber)),
            DropdownButtonFormField<String>(
              value: effResult.isEmpty ? null : effResult, decoration: InputDecoration(labelText: t('nonConformitiesPageFlt.detail.champResultat')),
              items: [DropdownMenuItem(value: 'EFFICACE', child: Text(t('nonConformitiesPageFlt.efficacite.efficace'))), DropdownMenuItem(value: 'PARTIELLEMENT_EFFICACE', child: Text(t('nonConformitiesPageFlt.efficacite.partiellementEfficace'))), DropdownMenuItem(value: 'INEFFICACE', child: Text(t('nonConformitiesPageFlt.efficacite.inefficace')))],
              onChanged: (v) => setState(() => effResult = v ?? ''),
            ),
            TextField(controller: effNotes, decoration: InputDecoration(labelText: t('nonConformitiesPageFlt.detail.champNotes'))),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: OutlinedButton(onPressed: busy || effResult.isEmpty ? null : saveEffectiveness, child: Text(t('nonConformitiesPageFlt.detail.enregistrerVerif')))),

            const SizedBox(height: 16),
            AttachmentsSection(ownerType: 'NON_CONFORMITY', ownerId: n['id']),
            const SizedBox(height: 4),

            if (!loadingSuggestions && suggestions.isNotEmpty) ...[
              Text(t('nonConformitiesPageFlt.detail.suggestionsTitre'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(t('nonConformitiesPageFlt.detail.suggestionsDesc'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              ...suggestions.map((s) => Card(
                    color: Colors.indigo.withOpacity(0.04),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${s['category']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 6),
                        ...List.from(s['actions'] ?? []).map((a) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(children: [
                                const Icon(Icons.arrow_right, size: 18),
                                Expanded(child: Text('$a', style: const TextStyle(fontSize: 13))),
                                IconButton(icon: const Icon(Icons.add_circle_outline, size: 20), tooltip: t('nonConformitiesPageFlt.detail.suggestionAction'), onPressed: () => createAction('$a')),
                              ]),
                            )),
                      ]),
                    ),
                  )),
              const SizedBox(height: 20),
            ],
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(t('nonConformitiesPageFlt.detail.actionsTitre'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              TextButton.icon(onPressed: () => createAction(''), icon: const Icon(Icons.add), label: Text(t('nonConformitiesPageFlt.common.ajouter'))),
            ]),
            if (actions.isEmpty) Padding(padding: const EdgeInsets.all(8), child: Text(t('nonConformitiesPageFlt.detail.aucuneAction'))),
            ...actions.map((a) => Card(child: ListTile(title: Text('${a['title']}'), subtitle: Text('${a['status']}')))),
          ],
        ),
      ),
    );
  }
}
