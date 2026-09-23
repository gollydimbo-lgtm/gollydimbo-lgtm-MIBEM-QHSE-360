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
import 'attachments_widget.dart';
import 'load_error_view.dart';

const _ncStatusLabels = {'OPEN': 'Ouverte', 'IN_PROGRESS': 'En cours', 'CLOSED': 'Clôturée'};
const _ncCriticiteLabels = {'MINEURE': 'Mineure', 'MODEREE': 'Modérée', 'MAJEURE': 'Majeure', 'CRITIQUE': 'Critique'};
const _ncEffLabels = {'EFFICACE': 'Efficace', 'PARTIELLEMENT_EFFICACE': 'Partiellement efficace', 'INEFFICACE': 'Inefficace'};

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

  @override
  void initState() { super.initState(); load(); }

  // --- Export CSV du registre des non-conformités (mêmes colonnes que
  // l'export Excel du back-office, cf. exportNcExcel côté web) ---
  Future<void> exportCsv() async {
    setState(() => exporting = true);
    try {
      final headers = ['Code', 'Titre', 'Source', 'Type', 'Criticité', 'Score', 'Unité de travail', 'Responsable', 'Date', 'Échéance', 'Statut', 'Efficacité'];
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
      await Share.shareXFiles([XFile(file.path)], text: 'Registre des non-conformités');
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
      title: const Text('Paramétrage des seuils de criticité'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: seuilModeree, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Seuil Modérée (score ≥)')),
        TextField(controller: seuilMajeure, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Seuil Majeure (score ≥)')),
        TextField(controller: seuilCritique, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Seuil Critique (score ≥)')),
        TextField(controller: delai, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Délai standard de traitement (jours)')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Enregistrer'))],
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
        title: const Text('Confirmer la suppression'),
        content: Text('Supprimer définitivement « ${n['code']} — ${n['title']} » ? Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Supprimer', style: TextStyle(color: Colors.red))),
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
        title: const Text('Non-conformités'),
        bottom: const TabBar(tabs: [Tab(text: 'Registre'), Tab(text: 'Récurrence'), Tab(text: 'Analyses')]),
        actions: [
          IconButton(
            icon: Icon(multiSelectMode ? Icons.close : Icons.checklist_outlined),
            tooltip: multiSelectMode ? 'Annuler la sélection' : 'Sélection multiple (CAPA commune)',
            onPressed: () => setState(() { multiSelectMode = !multiSelectMode; selectedIds = {}; }),
          ),
          IconButton(icon: exporting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.ios_share), tooltip: 'Exporter le registre', onPressed: exporting ? null : exportCsv),
          IconButton(icon: const Icon(Icons.settings_outlined), tooltip: 'Paramétrage des seuils', onPressed: editSettings),
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
                  label: Text('CAPA commune (${selectedIds.length})'),
                )
              : null)
          : FloatingActionButton.extended(
              onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const NcFormPage())).then((_) => load()),
              icon: const Icon(Icons.add),
              label: const Text('Déclarer une NC'),
            ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? LoadErrorView(error: error, onRetry: load)
          : TabBarView(children: [_buildRegistre(c), _buildRecurrence(), _buildAnalyses()]),
    ),
  );

  Widget _buildRegistre(BuildContext c) => Column(children: [
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(spacing: 8, children: [
        ChoiceChip(label: const Text('Toutes'), selected: filter == null, onSelected: (_) { filter = null; load(); }),
        for (final s in _ncStatusLabels.keys)
          ChoiceChip(label: Text(_ncStatusLabels[s]!), selected: filter == s, onSelected: (_) { filter = s; load(); }),
      ]),
    ),
    Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: KpiBar([
        KpiStat('Total', '${dashboard['total'] ?? items.length}', color: QhseColors.red, icon: Icons.error_outline),
        KpiStat('Ouvertes', '${dashboard['ouvertes'] ?? 0}', color: QhseColors.amber, icon: Icons.hourglass_empty),
        KpiStat('Critiques', '${dashboard['critiques'] ?? 0}', color: (dashboard['critiques'] ?? 0) > 0 ? QhseColors.red : QhseColors.green, icon: Icons.warning_amber_outlined),
        KpiStat('En retard', '${dashboard['enRetard'] ?? 0}', color: (dashboard['enRetard'] ?? 0) > 0 ? QhseColors.red : QhseColors.green, icon: Icons.timer_off_outlined),
        KpiStat('Taux de clôture', '${dashboard['tauxCloture'] ?? '—'}%', color: QhseColors.blue, icon: Icons.check_circle_outline),
      ]),
    ),
    Expanded(
      child: RefreshIndicator(
        onRefresh: load,
        child: items.isEmpty
            ? ListView(children: const [Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Aucune non-conformité')))])
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final n = items[i];
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
                      subtitle: Text('${_ncStatusLabels[n['status']] ?? n['status']} · ${actions.length} action(s)${n['criticiteNiveau'] != null ? ' · ${_ncCriticiteLabels[n['criticiteNiveau']]}' : ''}'),
                      selected: selected,
                      onTap: multiSelectMode
                          ? () => setState(() { if (selected) { selectedIds.remove(n['id']); } else { selectedIds.add(n['id']); } })
                          : () => Navigator.push(c, MaterialPageRoute(builder: (_) => NonConformityDetailPage(ncId: n['id']))).then((_) => load()),
                      onLongPress: multiSelectMode ? null : () => delete(n),
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
        ? ListView(children: const [Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Aucune non-conformité récurrente détectée')))])
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: recurrentes.length,
            itemBuilder: (_, i) {
              final r = recurrentes[i];
              return Card(child: Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Expanded(child: Text('${r['titre']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: QhseColors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Text('${r['occurrences']}× constatée', style: TextStyle(color: QhseColors.red, fontSize: 11))),
                ]),
                const SizedBox(height: 4),
                Text('${r['processus']} · dernière occurrence le ${'${r['derniereOccurrence']}'.substring(0, 10)}', style: TextStyle(color: QhseColors.textSecondary, fontSize: 11)),
              ])));
            },
          ),
  );

  Widget _buildAnalyses() => RefreshIndicator(
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
      const SizedBox(height: 20),
      Text('Évolution sur 12 mois — nouvelles NC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: QhseColors.textPrimary)),
      const SizedBox(height: 8),
      SizedBox(height: 200, child: trends.isEmpty ? Center(child: Text('Pas encore assez de données', style: TextStyle(color: QhseColors.textSecondary))) : _NcTrendChart(trends: trends)),
      const SizedBox(height: 20),
      Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Coût de non-qualité', style: TextStyle(fontSize: 12, color: QhseColors.textSecondary)),
        const SizedBox(height: 4),
        Text('${dashboard['coutTotalNonQualite'] ?? '—'}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        Text('Moyenne par NC : ${dashboard['coutMoyenParNc'] ?? '—'}', style: TextStyle(fontSize: 12, color: QhseColors.textSecondary)),
      ]))),
      const SizedBox(height: 20),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Synthèse direction', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: QhseColors.textPrimary)),
        FilledButton.icon(
          onPressed: syntheseLoading ? null : generateSynthese,
          icon: syntheseLoading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.summarize_outlined, size: 16),
          label: const Text('Générer'),
        ),
      ]),
      if (syntheseDirection != null) ...[
        const SizedBox(height: 8),
        Text('Générée le ${(syntheseDirection!['genereLe'] ?? '').toString().substring(0, 10)}', style: TextStyle(fontSize: 11, color: QhseColors.textSecondary)),
        const SizedBox(height: 8),
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final entry in <List<Object?>>[
            ['Total NC', syntheseDirection!['dashboard']?['total']],
            ['NC critiques', syntheseDirection!['dashboard']?['critiques']],
            ['NC majeures', syntheseDirection!['dashboard']?['majeures']],
            ['Taux de clôture', syntheseDirection!['dashboard']?['tauxCloture'] != null ? '${syntheseDirection!['dashboard']['tauxCloture']}%' : '—'],
            ['Actions en retard', syntheseDirection!['dashboard']?['actionsEnRetard']],
            ['Coût total de non-qualité', syntheseDirection!['dashboard']?['coutTotalNonQualite']],
          ])
            Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${entry[0]}', style: TextStyle(fontSize: 12, color: QhseColors.textSecondary)),
              Text('${entry[1] ?? '—'}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ])),
        ]))),
        if ((syntheseDirection!['processusLesPlusProblematiques'] as List?)?.isNotEmpty ?? false) ...[
          const SizedBox(height: 12),
          Text('Processus les plus problématiques', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: QhseColors.textPrimary)),
          for (final p in (syntheseDirection!['processusLesPlusProblematiques'] as List))
            ListTile(dense: true, title: Text('${p['processus']}', style: const TextStyle(fontSize: 12)), trailing: Text('${p['nombre']}')),
        ],
        if ((syntheseDirection!['principalesRecurrences'] as List?)?.isNotEmpty ?? false) ...[
          const SizedBox(height: 12),
          Text('Principales récurrences', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: QhseColors.textPrimary)),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le titre est obligatoire')));
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pas de réseau : NC enregistrée hors-ligne, elle sera synchronisée automatiquement.'), duration: Duration(seconds: 4)));
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
    appBar: AppBar(title: Text(editing ? 'Modifier la non-conformité' : 'Nouvelle non-conformité')),
    body: loadingLists
        ? const Center(child: CircularProgressIndicator())
        : ListView(padding: const EdgeInsets.all(16), children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Titre')),
            const SizedBox(height: 12),
            TextField(controller: description, maxLines: 4, decoration: const InputDecoration(labelText: 'Description')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: source, decoration: const InputDecoration(labelText: 'Origine'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: classification, decoration: const InputDecoration(labelText: 'Type de NC'))),
            ]),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: workUnitId, isExpanded: true, decoration: const InputDecoration(labelText: 'Unité de travail / zone'),
              items: [const DropdownMenuItem<String>(value: null, child: Text('—')), ...workUnits.map<DropdownMenuItem<String>>((w) => DropdownMenuItem<String>(value: w['id'] as String, child: Text(w['name'] ?? '')))],
              onChanged: (v) => setState(() => workUnitId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: responsibleId, isExpanded: true, decoration: const InputDecoration(labelText: 'Responsable du traitement'),
              items: [const DropdownMenuItem<String>(value: null, child: Text('—')), ...users.map<DropdownMenuItem<String>>((u) => DropdownMenuItem<String>(value: u['id'] as String, child: Text('${u['firstName']} ${u['lastName']}')))],
              onChanged: (v) => setState(() => responsibleId = v),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: () => pickDate(false), icon: const Icon(Icons.event), label: Text('Date : ${occurredAt.toIso8601String().substring(0, 10)}')),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: () => pickDate(true), icon: const Icon(Icons.event_busy), label: Text(dueDate != null ? 'Échéance : ${dueDate!.toIso8601String().substring(0, 10)}' : 'Échéance (optionnel)')),
            const SizedBox(height: 16),
            Text('Criticité — score calculé automatiquement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: QhseColors.textSecondary)),
            _criticiteSlider('Gravité', gravite, (v) => setState(() => gravite = v)),
            _criticiteSlider('Probabilité', probabilite, (v) => setState(() => probabilite = v)),
            _criticiteSlider('Étendue', etendue, (v) => setState(() => etendue = v)),
            if (editing && widget.record!['criticiteScore'] != null) Text('Score actuel : ${widget.record!['criticiteScore']}/100 (${_ncCriticiteLabels[widget.record!['criticiteNiveau']]})', style: const TextStyle(fontWeight: FontWeight.bold)),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : submit, child: Text(busy ? 'Envoi...' : 'Enregistrer'))),
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
    final t = TextEditingController(text: initialTitle);
    final r = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nouvelle action corrective'),
        content: TextField(controller: t, maxLines: 2, decoration: const InputDecoration(labelText: 'Titre de l\'action (modifiable)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Refuser')),
          FilledButton(onPressed: () => Navigator.pop(context, t.text), child: const Text('Accepter')),
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
      title: const Text('Action de confinement'),
      content: TextField(controller: type, decoration: const InputDecoration(labelText: 'Ex. Blocage produit, quarantaine, tri...')),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Ajouter'))],
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
      title: const Text('Analyse des causes'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: methode, items: const [DropdownMenuItem(value: '5_POURQUOI', child: Text('5 Pourquoi')), DropdownMenuItem(value: 'ISHIKAWA', child: Text('Ishikawa (5M)')), DropdownMenuItem(value: 'AUTRE', child: Text('Autre'))], onChanged: (v) => setD(() => methode = v ?? '5_POURQUOI')),
        TextField(controller: desc, maxLines: 2, decoration: const InputDecoration(labelText: 'Description de la cause')),
        CheckboxListTile(contentPadding: EdgeInsets.zero, value: estRacine, title: const Text('Cause racine', style: TextStyle(fontSize: 13)), onChanged: (v) => setD(() => estRacine = v ?? false)),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Ajouter'))],
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
      title: const Text('Coût de non-qualité'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: type, decoration: const InputDecoration(labelText: 'Type (ex. Rebuts, retouches, transport...)')),
        TextField(controller: montant, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Montant')),
        TextField(controller: desc, decoration: const InputDecoration(labelText: 'Description (optionnel)')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Ajouter'))],
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
    if (loading) return Scaffold(appBar: AppBar(title: const Text('Non-conformité')), body: const Center(child: CircularProgressIndicator()));
    if (error != null || nc == null) return Scaffold(appBar: AppBar(title: const Text('Non-conformité')), body: Center(child: Text(error ?? 'Introuvable')));
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
              if (n['status'] == 'CLOSED') ...[const SizedBox(width: 8), OutlinedButton(onPressed: busy ? null : reopen, child: const Text('Réouvrir'))]
              else ...[const SizedBox(width: 8), FilledButton(
                  onPressed: busy || n['effectivenessResult'] != 'EFFICACE' ? null : close,
                  child: const Text('Clôturer'),
                )],
            ]),
            if (n['criticiteNiveau'] != null) ...[
              const SizedBox(height: 8),
              Text('Criticité : ${n['criticiteScore']}/100 (${_ncCriticiteLabels[n['criticiteNiveau']]})', style: TextStyle(color: _ncCriticiteColor(n['criticiteNiveau']), fontWeight: FontWeight.bold)),
            ],
            const SizedBox(height: 20),
            CapaLinksSection(sourceModule: 'NON_CONFORMITY', sourceEntityId: n['id'], prefill: {'title': 'Traiter — ${n['title']}', 'source': 'Non-conformité', 'criticite': n['criticiteNiveau']}),
            DocumentLinksSection(sourceModule: 'NON_CONFORMITY', sourceEntityId: n['id']),

            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Confinement / actions immédiates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              TextButton.icon(onPressed: addContainment, icon: const Icon(Icons.add, size: 16), label: const Text('Ajouter')),
            ]),
            if (containment.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('Aucune action de confinement', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
            else ...containment.map((ca) => Card(child: ListTile(dense: true, title: Text('${ca['type']}'), subtitle: Text(ca['description'] ?? '')))),

            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Analyse des causes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              TextButton.icon(onPressed: addCause, icon: const Icon(Icons.add, size: 16), label: const Text('Ajouter')),
            ]),
            if (causes.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('Aucune cause enregistrée', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
            else ...causes.map((cs) => Card(child: ListTile(dense: true, title: Text('${cs['description']}'), subtitle: Text('${cs['methode']}${cs['estRacine'] == true ? ' · Racine' : ''}')))),

            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Coût de non-qualité${costs.isNotEmpty ? ' (${costs.fold<double>(0, (s, c) => s + ((c['montant'] ?? 0) as num).toDouble())})' : ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              TextButton.icon(onPressed: addCost, icon: const Icon(Icons.add, size: 16), label: const Text('Ajouter')),
            ]),
            if (costs.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('Aucun coût enregistré', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
            else ...costs.map((co) => Card(child: ListTile(dense: true, title: Text('${co['type']}'), subtitle: co['description'] != null ? Text('${co['description']}') : null, trailing: Text('${co['montant']}', style: const TextStyle(fontWeight: FontWeight.bold))))),

            const SizedBox(height: 16),
            const Text("Vérification d'efficacité", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            if (n['effectivenessResult'] != null) Text('Dernier résultat : ${_ncEffLabels[n['effectivenessResult']]}', style: TextStyle(color: n['effectivenessResult'] == 'EFFICACE' ? QhseColors.green : n['effectivenessResult'] == 'INEFFICACE' ? QhseColors.red : QhseColors.amber)),
            DropdownButtonFormField<String>(
              value: effResult.isEmpty ? null : effResult, decoration: const InputDecoration(labelText: 'Résultat'),
              items: const [DropdownMenuItem(value: 'EFFICACE', child: Text('Efficace')), DropdownMenuItem(value: 'PARTIELLEMENT_EFFICACE', child: Text('Partiellement efficace')), DropdownMenuItem(value: 'INEFFICACE', child: Text('Inefficace'))],
              onChanged: (v) => setState(() => effResult = v ?? ''),
            ),
            TextField(controller: effNotes, decoration: const InputDecoration(labelText: 'Notes (optionnel)')),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: OutlinedButton(onPressed: busy || effResult.isEmpty ? null : saveEffectiveness, child: const Text('Enregistrer la vérification'))),

            const SizedBox(height: 16),
            AttachmentsSection(ownerType: 'NON_CONFORMITY', ownerId: n['id']),
            const SizedBox(height: 4),

            if (!loadingSuggestions && suggestions.isNotEmpty) ...[
              const Text('Suggestions du moteur de recommandations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              const Text('Proposées automatiquement à partir du type de non-conformité. La décision reste humaine : acceptez, modifiez, refusez ou ajoutez librement.', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                                IconButton(icon: const Icon(Icons.add_circle_outline, size: 20), tooltip: 'Accepter / modifier', onPressed: () => createAction('$a')),
                              ]),
                            )),
                      ]),
                    ),
                  )),
              const SizedBox(height: 20),
            ],
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Actions correctives', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              TextButton.icon(onPressed: () => createAction(''), icon: const Icon(Icons.add), label: const Text('Ajouter')),
            ]),
            if (actions.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Aucune action pour l\'instant')),
            ...actions.map((a) => Card(child: ListTile(title: Text('${a['title']}'), subtitle: Text('${a['status']}')))),
          ],
        ),
      ),
    );
  }
}
