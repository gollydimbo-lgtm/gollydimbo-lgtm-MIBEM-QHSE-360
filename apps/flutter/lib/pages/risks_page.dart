import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api.dart';
import '../services/sync_queue.dart';
import '../theme.dart';
import 'attachment_helpers.dart';
import 'capa_link_widget.dart';

Color _niveauColor(String? n) => {
      'CRITIQUE': QhseColors.red,
      'ELEVE': QhseColors.amber,
      'MODERE': const Color(0xFFB45309),
      'FAIBLE': QhseColors.green,
    }[n] ?? QhseColors.textSecondary;
String _niveauLabel(String? n) => {'CRITIQUE': 'Critique', 'ELEVE': 'Élevé', 'MODERE': 'Modéré', 'FAIBLE': 'Faible'}[n] ?? '—';
Color _alerteColor(String? n) => {'CRITIQUE': QhseColors.red, 'URGENT': QhseColors.red, 'ATTENTION': QhseColors.amber}[n] ?? QhseColors.textSecondary;
// Hiérarchie de prévention (point 9 du cahier des charges) — suggestion,
// jamais une liste figée côté serveur.
const List<List<String>> kRiskMeasureTypes = [
  ['SUPPRESSION', 'Suppression du danger'],
  ['SUBSTITUTION', 'Substitution'],
  ['PROTECTION_COLLECTIVE', 'Protection collective'],
  ['TECHNIQUE', 'Mesure technique'],
  ['ORGANISATIONNELLE', 'Mesure organisationnelle'],
  ['PROCEDURE', 'Procédure / instruction'],
  ['FORMATION', 'Formation / information'],
  ['SIGNALISATION', 'Signalisation'],
  ['EPI', 'EPI'],
  ['AUTRE', 'Autre'],
];

// --- Écran principal à 4 onglets, comme le tableau de bord web ---
class RisksPage extends StatefulWidget {
  const RisksPage({super.key});
  @override
  State<RisksPage> createState() => _RisksPageState();
}

class _RisksPageState extends State<RisksPage> {
  final api = Api();
  List items = [], categories = [], workUnits = [], alertes = [];
  Map dashboard = {};
  bool loading = true;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      items = List.from(await api.get('/business/risks'));
      dashboard = Map.from(await api.get('/business/risk-dashboard'));
      alertes = List.from(await api.get('/business/risk-alertes'));
      categories = List.from(await api.get('/business/risk-categories'));
      workUnits = List.from(await api.get('/business/work-units'));
    } catch (_) {}
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext c) => DefaultTabController(
    length: 5,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Registre des risques'),
        bottom: const TabBar(isScrollable: true, tabs: [
          Tab(text: "Vue d'ensemble"), Tab(text: 'Registre'), Tab(text: 'Hiérarchisation'), Tab(text: 'Cartographie'), Tab(text: 'Paramétrage'),
        ]),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const RiskFormPage())).then((_) => load()),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau risque'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(children: [_buildApercu(c), _buildRegistre(c), _buildHierarchisation(c), _buildCartographie(c), _buildParametrage(c)]),
    ),
  );

  Widget _buildApercu(BuildContext c) => RefreshIndicator(
    onRefresh: load,
    child: ListView(padding: const EdgeInsets.all(12), children: [
      KpiBar([
        KpiStat('Recensés', '${dashboard['total'] ?? items.length}', color: QhseColors.blue, icon: Icons.warning_amber_outlined),
        KpiStat('Critiques', '${dashboard['critiques'] ?? 0}', color: QhseColors.red, icon: Icons.error_outline),
        KpiStat('Élevés', '${dashboard['eleves'] ?? 0}', color: QhseColors.amber, icon: Icons.error_outline),
        KpiStat('Non maîtrisés', '${dashboard['nonMaitrises'] ?? 0}', color: (dashboard['nonMaitrises'] ?? 0) > 0 ? QhseColors.red : QhseColors.green, icon: Icons.gpp_bad_outlined),
      ]),
      const SizedBox(height: 8),
      KpiBar([
        KpiStat('Actions en retard', '${dashboard['actionsEnRetard'] ?? 0}', color: (dashboard['actionsEnRetard'] ?? 0) > 0 ? QhseColors.red : QhseColors.green, icon: Icons.timer_off_outlined),
        KpiStat('À réévaluer', '${dashboard['aReevaluer'] ?? 0}', color: (dashboard['aReevaluer'] ?? 0) > 0 ? QhseColors.amber : QhseColors.green, icon: Icons.refresh),
        KpiStat('Taux de maîtrise', '${dashboard['tauxMaitrise'] ?? '—'}%', color: QhseColors.blue, icon: Icons.shield_outlined),
        KpiStat('Clôture actions', '${dashboard['tauxClotureActions'] ?? '—'}%', color: QhseColors.blue, icon: Icons.task_alt),
      ]),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Alertes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        Text('${alertes.length}', style: TextStyle(color: QhseColors.textSecondary)),
      ]),
      const SizedBox(height: 6),
      if (alertes.isEmpty)
        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Aucune alerte — tout est sous contrôle', style: TextStyle(color: QhseColors.green)))
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

  Widget _buildRegistre(BuildContext c) => RefreshIndicator(
    onRefresh: load,
    child: items.isEmpty
        ? ListView(children: const [Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Aucun risque enregistré')))])
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final r = items[i];
              final score = r['grossScore'] ?? r['score'] ?? 0;
              final color = _niveauColor(r['grossLevel']);
              return Card(child: ListTile(
                leading: CircleAvatar(backgroundColor: color, child: Text('$score', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                title: Text('${r['code']} — ${r['hazard']}'),
                subtitle: Text('${r['category']?['label'] ?? 'Sans catégorie'} · ${r['workUnit']?['name'] ?? 'Sans unité'}'),
                trailing: Text(_niveauLabel(r['grossLevel']), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
                onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => RiskDetailPage(riskId: r['id']))).then((_) => load()),
              ));
            },
          ),
  );

  Widget _buildHierarchisation(BuildContext c) {
    final groups = [
      {'id': 'CRITIQUE', 'label': 'Priorité immédiate — Critiques', 'color': QhseColors.red},
      {'id': 'ELEVE', 'label': 'Priorité haute — Élevés', 'color': QhseColors.amber},
      {'id': 'MODERE', 'label': 'Priorité moyenne — Modérés', 'color': const Color(0xFFB45309)},
      {'id': 'FAIBLE', 'label': 'Surveillance — Faibles', 'color': QhseColors.green},
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
              Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Aucun risque', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
            else
              ...risques.map((r) => Card(child: ListTile(
                    dense: true,
                    title: Text(r['hazard'] ?? ''),
                    subtitle: Text(r['workUnit']?['name'] ?? 'Sans unité'),
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
        Text('Répartition par niveau de criticité', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: items.isEmpty
              ? Center(child: Text('Aucun risque enregistré', style: TextStyle(color: QhseColors.textSecondary)))
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
        Text('Répartition par catégorie', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        if (categories.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('Aucune donnée', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
        else
          ...categories.map((cat) => Card(child: ListTile(dense: true, title: Text(cat), trailing: Text('${parCategorie[cat]}', style: const TextStyle(fontWeight: FontWeight.bold))))),
        const SizedBox(height: 20),
        Text('Rapport de synthèse', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Total recensés : ${items.length}', style: const TextStyle(fontSize: 13)),
          Text('Critiques : ${parNiveau['CRITIQUE']} · Élevés : ${parNiveau['ELEVE']} · Modérés : ${parNiveau['MODERE']} · Faibles : ${parNiveau['FAIBLE']}', style: const TextStyle(fontSize: 13)),
          Text('Taux de maîtrise : ${dashboard['tauxMaitrise'] ?? '—'}% · Actions en retard : ${dashboard['actionsEnRetard'] ?? 0}', style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
          Text('Ce rapport se recompose à partir du registre actuel — il ne s\'agit pas d\'un document figé.', style: TextStyle(fontSize: 11, color: QhseColors.textSecondary, fontStyle: FontStyle.italic)),
        ]))),
      ]),
    );
  }

  Widget _buildParametrage(BuildContext c) => RefreshIndicator(
    onRefresh: load,
    child: ListView(padding: const EdgeInsets.all(12), children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Catégories de risques', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        TextButton.icon(onPressed: () => showRiskCategoryDialog(c, api, onSaved: load), icon: const Icon(Icons.add, size: 16), label: const Text('Ajouter')),
      ]),
      if (categories.isEmpty)
        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Aucune catégorie définie — la liste reste entièrement libre', style: TextStyle(color: QhseColors.textSecondary)))
      else
        ...categories.map((cat) => Card(child: ListTile(dense: true, title: Text(cat['label'] ?? ''), subtitle: Text(cat['code'] ?? ''), onTap: () => showRiskCategoryDialog(c, api, record: cat, onSaved: load)))),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Unités de travail', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        TextButton.icon(onPressed: () => showWorkUnitDialog(c, api, onSaved: load), icon: const Icon(Icons.add, size: 16), label: const Text('Ajouter')),
      ]),
      if (workUnits.isEmpty)
        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Aucune unité de travail définie', style: TextStyle(color: QhseColors.textSecondary)))
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
      title: const Text('Archiver ce risque ?'),
      content: const Text("Le risque ne sera pas supprimé définitivement, seulement archivé (conserve l'historique QHSE)."),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Archiver'))],
    ));
    if (confirm != true) return;
    try { await api.delete('/business/risks/${widget.riskId}'); if (mounted) Navigator.pop(context); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  @override
  Widget build(BuildContext c) {
    if (loading) return Scaffold(appBar: AppBar(title: const Text('Risque')), body: const Center(child: CircularProgressIndicator()));
    if (error != null || risk == null) return Scaffold(appBar: AppBar(title: const Text('Risque')), body: Center(child: Text(error ?? 'Introuvable')));
    final r = risk!;
    final measures = List.from(r['riskMeasures'] ?? []);
    final evaluations = List.from(r['evaluations'] ?? [])..sort((a, b) => (a['evaluatedAt'] as String).compareTo(b['evaluatedAt'] as String));
    return Scaffold(
      appBar: AppBar(title: Text(r['hazard'] ?? ''), actions: [
        IconButton(icon: const Icon(Icons.camera_alt_outlined), onPressed: () => captureAndLinkPhoto(context, api, 'RISK', r['id'])),
        IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => RiskFormPage(record: r))).then((_) => load())),
        IconButton(icon: const Icon(Icons.archive_outlined), onPressed: deleteRisk),
      ]),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Text('${r['category']?['label'] ?? 'Sans catégorie'} · ${r['workUnit']?['name'] ?? 'Sans unité de travail'}', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _scoreCard('Risque brut', r['grossScore'] ?? r['score'], r['grossLevel'])),
            const SizedBox(width: 8),
            Expanded(child: _scoreCard('Risque résiduel', r['residualScore'], r['residualLevel'])),
          ]),
          const SizedBox(height: 8),
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Statut de maîtrise', style: TextStyle(fontSize: 12)),
            Text(
              r['controlStatus'] == 'MAITRISE' ? 'Maîtrisé' : r['controlStatus'] == 'PARTIELLEMENT_MAITRISE' ? 'Partiel' : 'Non maîtrisé',
              style: TextStyle(fontWeight: FontWeight.bold, color: r['controlStatus'] == 'MAITRISE' ? QhseColors.green : r['controlStatus'] == 'PARTIELLEMENT_MAITRISE' ? QhseColors.amber : QhseColors.red),
            ),
          ]))),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Mesures de prévention (${measures.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            TextButton.icon(onPressed: () => showRiskMeasureDialog(c, api, riskId: r['id'], onSaved: load), icon: const Icon(Icons.add, size: 16), label: const Text('Mesure')),
          ]),
          if (measures.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Aucune mesure de prévention enregistrée', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
          else
            ...measures.map((m) => Card(child: ListTile(
                  dense: true,
                  title: Text(m['description'] ?? ''),
                  subtitle: Text('${kRiskMeasureTypes.firstWhere((t) => t[0] == m['type'], orElse: () => ['', m['type'] ?? ''])[1]} · Efficacité ${m['efficacite']}/5'),
                  trailing: IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () async { await api.delete('/business/risk-measures/${m['id']}'); load(); }),
                ))),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Historique des évaluations (${evaluations.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            TextButton.icon(onPressed: () => showReevaluateDialog(c, api, risk: r, onSaved: load), icon: const Icon(Icons.refresh, size: 16), label: const Text('Réévaluer')),
          ]),
          if (evaluations.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Aucune évaluation enregistrée', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
          else
            ...evaluations.reversed.map((ev) => Card(child: ListTile(
                  dense: true,
                  title: Text('${ev['evaluatedAt'].toString().substring(0, 10)} — Brut ${ev['grossScore']} (${ev['grossLevel']})'),
                  subtitle: Text(ev['residualScore'] != null ? 'Résiduel ${ev['residualScore']} (${ev['residualLevel']})${ev['note'] != null ? ' · ${ev['note']}' : ''}' : ev['note'] ?? ''),
                ))),

          const SizedBox(height: 20),
          CapaLinksSection(sourceModule: 'RISK', sourceEntityId: r['id'], prefill: {'title': 'Maîtriser le risque — ${r['hazard'] ?? ''}', 'source': 'RISK'}),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le danger est obligatoire')));
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pas de réseau : risque enregistré hors-ligne, il sera synchronisé automatiquement.'), duration: Duration(seconds: 4)));
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
    appBar: AppBar(title: Text(editing ? 'Modifier le risque' : 'Nouveau risque')),
    body: loadingLists
        ? const Center(child: CircularProgressIndicator())
        : ListView(padding: const EdgeInsets.all(16), children: [
            TextField(controller: hazard, decoration: const InputDecoration(labelText: 'Danger identifié')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: categoryId, isExpanded: true, decoration: const InputDecoration(labelText: 'Catégorie'),
              items: [const DropdownMenuItem<String>(value: null, child: Text('—')), ...categories.map<DropdownMenuItem<String>>((cat) => DropdownMenuItem<String>(value: cat['id'] as String, child: Text(cat['label'] ?? '')))],
              onChanged: (v) => setState(() => categoryId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: workUnitId, isExpanded: true, decoration: const InputDecoration(labelText: 'Unité de travail'),
              items: [const DropdownMenuItem<String>(value: null, child: Text('—')), ...workUnits.map<DropdownMenuItem<String>>((w) => DropdownMenuItem<String>(value: w['id'] as String, child: Text(w['name'] ?? '')))],
              onChanged: (v) => setState(() => workUnitId = v),
            ),
            const SizedBox(height: 12),
            TextField(controller: activity, decoration: const InputDecoration(labelText: 'Activité concernée')),
            const SizedBox(height: 12),
            TextField(controller: hazardousSituation, decoration: const InputDecoration(labelText: 'Situation dangereuse')),
            const SizedBox(height: 12),
            TextField(controller: hazardousEvent, decoration: const InputDecoration(labelText: 'Événement redouté')),
            const SizedBox(height: 12),
            TextField(controller: potentialDamage, decoration: const InputDecoration(labelText: 'Dommage potentiel')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: exposedPersons, decoration: const InputDecoration(labelText: 'Personnes exposées'))),
              const SizedBox(width: 8),
              SizedBox(width: 90, child: TextField(controller: exposedPersonCount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Nombre'))),
            ]),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: method, decoration: const InputDecoration(labelText: "Méthode d'évaluation"),
              items: const [DropdownMenuItem(value: 'GP', child: Text('Gravité × Probabilité')), DropdownMenuItem(value: 'GPE', child: Text('Gravité × Probabilité × Exposition'))],
              onChanged: (v) => setState(() => method = v ?? 'GP'),
            ),
            const SizedBox(height: 8),
            _slider('Gravité', severity, (v) => setState(() => severity = v)),
            _slider('Probabilité', probability, (v) => setState(() => probability = v)),
            if (method == 'GPE') _slider('Exposition', exposure, (v) => setState(() => exposure = v)),
            Text('Score brut (aperçu) : $grossScore', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(controller: measures, maxLines: 2, decoration: const InputDecoration(labelText: 'Mesures de prévention existantes (résumé)')),
            const SizedBox(height: 12),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Évaluer le risque résiduel', style: TextStyle(fontSize: 13)), value: hasResidual, onChanged: (v) => setState(() => hasResidual = v)),
            if (hasResidual) ...[
              _slider('Gravité résiduelle', residualSeverity, (v) => setState(() => residualSeverity = v)),
              _slider('Probabilité résiduelle', residualProbability, (v) => setState(() => residualProbability = v)),
              if (method == 'GPE') _slider('Exposition résiduelle', residualExposure, (v) => setState(() => residualExposure = v)),
              Text('Score résiduel (aperçu) : $residualScoreValue', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
            if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : submit, child: Text(busy ? 'Envoi...' : 'Enregistrer'))),
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
    title: Text(record == null ? 'Nouvelle catégorie' : 'Modifier la catégorie'),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: code, decoration: const InputDecoration(labelText: 'Code')),
      TextField(controller: label, decoration: const InputDecoration(labelText: 'Libellé')),
      if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
    ])),
    actions: [
      if (record != null) TextButton(onPressed: () async {
        try { await api.delete('/business/risk-categories/${record['id']}'); if (context.mounted) Navigator.pop(c); onSaved(); }
        catch (e) { setD(() => formError = '$e'); }
      }, child: const Text('Supprimer', style: TextStyle(color: QhseColors.red))),
      TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
      FilledButton(onPressed: saving ? null : () async {
        setD(() => saving = true);
        final payload = {'code': code.text.trim(), 'label': label.text.trim()};
        try {
          if (record != null) await api.patch('/business/risk-categories/${record['id']}', payload);
          else await api.post('/business/risk-categories', payload);
          if (context.mounted) Navigator.pop(c);
          onSaved();
        } catch (e) { setD(() { saving = false; formError = '$e'; }); }
      }, child: Text(saving ? '…' : 'Enregistrer')),
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
    title: const Text('Nouvelle unité de travail'),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: name, decoration: const InputDecoration(labelText: 'Nom')),
      TextField(controller: department, decoration: const InputDecoration(labelText: 'Département')),
      TextField(controller: service, decoration: const InputDecoration(labelText: 'Service')),
      if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
    ])),
    actions: [
      TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
      FilledButton(onPressed: saving ? null : () async {
        setD(() => saving = true);
        try {
          await api.post('/business/work-units', {'code': genCode('WU'), 'name': name.text.trim(), 'department': department.text.trim().isEmpty ? null : department.text.trim(), 'service': service.text.trim().isEmpty ? null : service.text.trim()});
          if (context.mounted) Navigator.pop(c);
          onSaved();
        } catch (e) { setD(() { saving = false; formError = '$e'; }); }
      }, child: Text(saving ? '…' : 'Enregistrer')),
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
    title: const Text('Nouvelle mesure de prévention'),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: description, maxLines: 2, decoration: const InputDecoration(labelText: 'Description')),
      DropdownButtonFormField<String>(
        value: type, isExpanded: true, decoration: const InputDecoration(labelText: 'Type (hiérarchie de prévention)'),
        items: kRiskMeasureTypes.map((t) => DropdownMenuItem(value: t[0], child: Text(t[1]))).toList(),
        onChanged: (v) => setD(() => type = v ?? 'TECHNIQUE'),
      ),
      Row(children: [
        Expanded(child: Text('Efficacité : $efficacite / 5')),
        Expanded(child: Slider(value: efficacite.toDouble(), min: 1, max: 5, divisions: 4, label: '$efficacite', onChanged: (v) => setD(() => efficacite = v.round()))),
      ]),
      if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
    ])),
    actions: [
      TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
      FilledButton(onPressed: saving ? null : () async {
        if (description.text.trim().isEmpty) { setD(() => formError = 'La description est obligatoire'); return; }
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
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pas de réseau : mesure enregistrée hors-ligne, elle sera synchronisée automatiquement.'), duration: Duration(seconds: 4)));
            }
            onSaved();
          } else {
            setD(() { saving = false; formError = '$e'; });
          }
        } catch (e) { setD(() { saving = false; formError = '$e'; }); }
      }, child: Text(saving ? '…' : 'Ajouter')),
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
    title: const Text('Réévaluer le risque'),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Gravité : $severity / 5'),
      Slider(value: severity.toDouble(), min: 1, max: 5, divisions: 4, label: '$severity', onChanged: (v) => setD(() => severity = v.round())),
      Text('Probabilité : $probability / 5'),
      Slider(value: probability.toDouble(), min: 1, max: 5, divisions: 4, label: '$probability', onChanged: (v) => setD(() => probability = v.round())),
      const Divider(),
      Text('Gravité résiduelle : ${residualSeverity ?? '—'}'),
      Slider(value: (residualSeverity ?? 3).toDouble(), min: 1, max: 5, divisions: 4, label: '${residualSeverity ?? 3}', onChanged: (v) => setD(() => residualSeverity = v.round())),
      Text('Probabilité résiduelle : ${residualProbability ?? '—'}'),
      Slider(value: (residualProbability ?? 3).toDouble(), min: 1, max: 5, divisions: 4, label: '${residualProbability ?? 3}', onChanged: (v) => setD(() => residualProbability = v.round())),
      TextField(controller: note, decoration: const InputDecoration(labelText: 'Note (optionnel)')),
      if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
    ])),
    actions: [
      TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
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
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pas de réseau : réévaluation enregistrée hors-ligne, elle sera synchronisée automatiquement.'), duration: Duration(seconds: 4)));
            }
            onSaved();
          } else {
            setD(() { saving = false; formError = '$e'; });
          }
        } catch (e) { setD(() { saving = false; formError = '$e'; }); }
      }, child: Text(saving ? '…' : 'Réévaluer')),
    ],
  )));
}
