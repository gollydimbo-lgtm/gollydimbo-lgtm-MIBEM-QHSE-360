import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api.dart';
import '../services/sync_queue.dart';
import '../theme.dart';
import 'load_error_view.dart';
import '../i18n/i18n.dart';

Color _niveauColor(String? n) => {'CRITIQUE': QhseColors.red, 'URGENT': QhseColors.red, 'ATTENTION': QhseColors.amber}[n] ?? QhseColors.textSecondary;
Color _criticiteColor(int c) => c >= 12 ? QhseColors.red : c >= 6 ? QhseColors.amber : QhseColors.green;
String _criticiteLabel(int c) => c >= 12 ? t('environnement.critiqueLabel') : c >= 6 ? t('environnement.eleveLabel') : t('environnement.faibleModereLabel');
const List<String> kCategoriesEnv = ['Déchets', 'Eau', 'Énergie', 'Carburants', 'Émissions atmosphériques', 'GES / Carbone', 'Effluents', 'Sols', 'Produits chimiques', 'Nuisances', 'Biodiversité'];
const Map<String, String> _categorieEnvKeys = {
  'Déchets': 'catDechets', 'Eau': 'catEau', 'Énergie': 'catEnergie', 'Carburants': 'catCarburants',
  'Émissions atmosphériques': 'catEmissionsAtmospheriques', 'GES / Carbone': 'catGesCarbone', 'Effluents': 'catEffluents',
  'Sols': 'catSols', 'Produits chimiques': 'catProduitsChimiques', 'Nuisances': 'catNuisances', 'Biodiversité': 'catBiodiversite',
};
String _categorieEnvLabel(String? cat) => cat == null ? '—' : t('environnement.${_categorieEnvKeys[cat] ?? 'catDechets'}');
const List<String> kMilieuxEnv = ['Air', 'Eau', 'Sol', 'Sous-sol', 'Biodiversité', 'Ressources naturelles', 'Population', 'Climat'];
const Map<String, String> _milieuEnvKeys = {
  'Air': 'milieuAir', 'Eau': 'milieuEau', 'Sol': 'milieuSol', 'Sous-sol': 'milieuSousSol',
  'Biodiversité': 'milieuBiodiversite', 'Ressources naturelles': 'milieuRessourcesNaturelles', 'Population': 'milieuPopulation', 'Climat': 'milieuClimat',
};
String _milieuEnvLabel(String? m) => m == null ? '—' : t('environnement.${_milieuEnvKeys[m] ?? 'milieuAir'}');
const Map<String, String> kVeilleStatutKeys = {
  'A_TRAITER': 'veilleATraiter', 'EN_COURS': 'veilleEnCours', 'INTEGREE': 'veilleIntegree', 'CONFORME': 'veilleConforme',
  'PARTIELLEMENT_CONFORME': 'veillePartiellementConforme', 'NON_CONFORME': 'veilleNonConforme', 'NON_APPLICABLE': 'veilleNonApplicable', 'A_VERIFIER': 'veilleAVerifier',
};
String kVeilleStatutLabel(String? s) { if (s == null) return ''; final k = kVeilleStatutKeys[s]; return k == null ? s : t('environnement.$k'); }
Color _veilleStatutColor(String? s) => {'CONFORME': QhseColors.green, 'INTEGREE': QhseColors.green, 'PARTIELLEMENT_CONFORME': QhseColors.amber, 'NON_CONFORME': QhseColors.red, 'A_VERIFIER': QhseColors.amber, 'A_TRAITER': QhseColors.amber, 'EN_COURS': QhseColors.blue}[s] ?? QhseColors.textSecondary;
String _dv(dynamic v, [String suffix = '']) => v == null ? t('environnement.aucuneDonnee') : '$v$suffix';

// --- Écran principal à 6 onglets ---
class EnvironnementHome extends StatefulWidget {
  const EnvironnementHome({super.key});
  @override
  State<EnvironnementHome> createState() => _EnvironnementHomeState();
}

class _EnvironnementHomeState extends State<EnvironnementHome> {
  final api = Api();
  List releves = [], aspects = [], veille = [], produits = [], indicateurs = [], alertes = [], tendances = [];
  Map dashboard = {};
  bool loading = true;
  Object? error;
  String? generatingRiskAspectId;

  @override
  void initState() { super.initState(); load(); }

  Future<void> generateRiskFromAspect(String id) async {
    setState(() => generatingRiskAspectId = id);
    try { await api.post('/business/environnement-aspects/$id/generate-risk', {}); await load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
    if (mounted) setState(() => generatingRiskAspectId = null);
  }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      releves = List.from(await api.get('/business/environment'));
      aspects = List.from(await api.get('/business/environnement-aspects'));
      dashboard = Map.from(await api.get('/business/environnement-dashboard'));
      alertes = List.from(await api.get('/business/environnement-alertes'));
      tendances = List.from(await api.get('/business/environnement-tendances'));
      veille = List.from(await api.get('/business/veille-reglementaire'));
      produits = List.from(await api.get('/business/produits-chimiques'));
      indicateurs = List.from(await api.get('/business/indicateurs-qualite?domaine=ENVIRONNEMENT'));
    } catch (e) { error = e; }
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext c) {
    final veilleEnv = veille.where((v) => v['domaine'] == 'Environnement').toList();
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('environnement.pageTitle')),
          bottom: TabBar(isScrollable: true, tabs: [
            Tab(text: t('environnement.tabApercu')), Tab(text: t('environnement.tabReleves')), Tab(text: t('environnement.tabAspects')),
            Tab(text: t('environnement.tabConformite')), Tab(text: t('environnement.tabProduits')), Tab(text: t('environnement.tabIndicateurs')),
          ]),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? LoadErrorView(error: error, onRetry: load)
            : TabBarView(children: [
                _buildApercu(c),
                _buildReleves(c),
                _buildAspects(c),
                _buildConformite(c, veilleEnv),
                _buildProduits(c),
                _buildIndicateurs(c),
              ]),
      ),
    );
  }

  Widget _buildApercu(BuildContext c) {
    final score = dashboard['score'];
    final scoreColor = score == null ? QhseColors.textPrimary : score >= 80 ? QhseColors.green : score >= 60 ? QhseColors.amber : QhseColors.red;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(padding: const EdgeInsets.all(12), children: [
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('environnement.scoreTitle'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Text(score != null ? '$score/100' : t('environnement.aucuneDonneeDisponible'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: score != null ? 32 : 16, color: scoreColor)),
          if (dashboard['scoreDetail'] != null) Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(spacing: 8, runSpacing: 6, children: List.from(dashboard['scoreDetail']).map<Widget>((d) => Chip(label: Text('${d['nom']} : ${d['valeur'] ?? '—'}${d['valeur'] != null ? '%' : ''}', style: const TextStyle(fontSize: 11)))).toList()),
          ),
        ]))),
        const SizedBox(height: 12),
        KpiBar([
          KpiStat(t('environnement.kpiConformite'), _dv(dashboard['tauxConformite'], '%'), color: QhseColors.blue, icon: Icons.shield_outlined),
          KpiStat(t('environnement.kpiDechets'), _dv(dashboard['dechets']), color: QhseColors.amber, icon: Icons.delete_outline),
          KpiStat(t('environnement.kpiEau'), _dv(dashboard['eau']), color: QhseColors.blue, icon: Icons.water_drop_outlined),
          KpiStat(t('environnement.kpiEnergie'), _dv(dashboard['energie']), color: QhseColors.amber, icon: Icons.bolt_outlined),
        ]),
        const SizedBox(height: 8),
        KpiBar([
          KpiStat(t('environnement.kpiValorisationDechets'), _dv(dashboard['tauxValorisationDechets'], '%'), color: QhseColors.green, icon: Icons.recycling),
          KpiStat(t('environnement.kpiConfReglementaire'), _dv(dashboard['tauxConformiteReglementaire'], '%'), color: QhseColors.blue, icon: Icons.gavel_outlined),
          KpiStat(t('environnement.kpiAspectsSignificatifs'), '${dashboard['aspectsSignificatifs'] ?? 0}', color: (dashboard['aspectsSignificatifs'] ?? 0) > 0 ? QhseColors.red : QhseColors.green, icon: Icons.warning_amber_outlined),
          KpiStat(t('environnement.kpiActionsEnRetard'), '${dashboard['actionsEnRetard'] ?? 0}', color: (dashboard['actionsEnRetard'] ?? 0) > 0 ? QhseColors.red : QhseColors.green, icon: Icons.timer_off_outlined),
        ]),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(t('environnement.alertesTitle'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          Text('${alertes.length}', style: TextStyle(color: QhseColors.textSecondary)),
        ]),
        const SizedBox(height: 6),
        if (alertes.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(t('environnement.aucuneAlerte'), style: TextStyle(color: QhseColors.green)))
        else ...alertes.map((a) => Card(child: ListTile(
              dense: true,
              title: Text(a['label'] ?? ''),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: _niveauColor(a['niveau']).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: Text(a['niveau'] ?? '', style: TextStyle(color: _niveauColor(a['niveau']), fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ))),
        const SizedBox(height: 20),
        Text(t('environnement.tendancesTitle'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        Text(t('environnement.tendancesSubtitle'), style: TextStyle(color: QhseColors.textSecondary, fontSize: 11)),
        const SizedBox(height: 8),
        if (tendances.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(t('environnement.aucuneDonneeTendance'), style: TextStyle(color: QhseColors.textSecondary)))
        else
          ...tendances.map((tendance) {
            final points = List.from(tendance['points'] ?? []);
            final spots = [for (int i = 0; i < points.length; i++) FlSpot(i.toDouble(), ((points[i]['valeur'] ?? 0) as num).toDouble())];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${tendance['categorie']}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: QhseColors.textSecondary)),
                const SizedBox(height: 6),
                SizedBox(
                  height: 140,
                  child: points.isEmpty
                      ? Center(child: Text(t('environnement.pasDeDonnees'), style: TextStyle(color: QhseColors.textSecondary, fontSize: 11)))
                      : LineChart(LineChartData(
                          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: QhseColors.border, strokeWidth: 1)),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, getTitlesWidget: (v, meta) {
                              final i = v.toInt();
                              if (i < 0 || i >= points.length) return const SizedBox.shrink();
                              return Text('${points[i]['mois']}', style: TextStyle(fontSize: 9, color: QhseColors.textSecondary));
                            })),
                            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32, getTitlesWidget: (v, meta) => Text('${v.toInt()}', style: TextStyle(fontSize: 9, color: QhseColors.textSecondary)))),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [LineChartBarData(spots: spots, isCurved: true, color: QhseColors.blue, barWidth: 2, dotData: const FlDotData(show: true))],
                        )),
                ),
              ]),
            );
          }),
      ]),
    );
  }

  Widget _buildReleves(BuildContext c) => Scaffold(
        floatingActionButton: FloatingActionButton.extended(onPressed: () => showReleveDialog(c, api, onSaved: load), icon: const Icon(Icons.add), label: Text(t('environnement.fabReleve'))),
        body: RefreshIndicator(
          onRefresh: load,
          child: releves.isEmpty
              ? ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(t('environnement.aucunReleve'))))])
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: releves.length,
                  itemBuilder: (_, i) {
                    final r = releves[i];
                    return Card(child: ListTile(
                      title: Text(r['type'] ?? ''),
                      subtitle: Text('${r['categorie'] ?? '—'} • ${r['value'] ?? '—'}${r['unit'] ?? ''} • ${(r['recordedAt'] ?? '').toString().substring(0, 10)}'),
                      trailing: r['conforme'] == null ? null : Icon(Icons.circle, size: 12, color: r['conforme'] == true ? QhseColors.green : QhseColors.red),
                      onTap: () => showReleveDialog(c, api, record: r, onSaved: load),
                    ));
                  },
                ),
        ),
      );

  Widget _buildAspects(BuildContext c) {
    final significatifs = aspects.where((a) => a['significatif'] == true && a['statut'] == 'ACTIVE').length;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(onPressed: () => showAspectDialog(c, api, onSaved: load), icon: const Icon(Icons.add), label: Text(t('environnement.fabAspect'))),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(padding: const EdgeInsets.all(12), children: [
          KpiBar([
            KpiStat(t('environnement.kpiAspects'), '${aspects.length}', color: QhseColors.blue, icon: Icons.eco_outlined),
            KpiStat(t('environnement.kpiSignificatifs'), '$significatifs', color: significatifs > 0 ? QhseColors.red : QhseColors.green, icon: Icons.warning_amber_outlined),
          ]),
          const SizedBox(height: 12),
          if (aspects.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(t('environnement.aucunAspect'), style: TextStyle(color: QhseColors.textSecondary))))
          else ...aspects.map((a) => Card(child: ListTile(
                leading: Icon(Icons.circle, size: 12, color: _criticiteColor(a['criticite'] ?? 1)),
                title: Text(a['aspect'] ?? ''),
                subtitle: Text(a['milieu'] ?? '—'),
                trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${a['criticite']} (${_criticiteLabel(a['criticite'] ?? 1)})', style: TextStyle(color: _criticiteColor(a['criticite'] ?? 1), fontWeight: FontWeight.bold, fontSize: 11)),
                  // Finding #34 — un aspect significatif peut générer un risque formel,
                  // même logique que le web (calculerRisque, jamais ressaisi à la main).
                  if (a['significatif'] == true)
                    a['riskId'] != null
                        ? Text(t('environnement.risqueCree'), style: const TextStyle(color: QhseColors.green, fontSize: 10))
                        : TextButton(
                            onPressed: generatingRiskAspectId == a['id'] ? null : () => generateRiskFromAspect(a['id']),
                            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                            child: Text(generatingRiskAspectId == a['id'] ? t('environnement.enCours') : t('environnement.genererUnRisque'), style: const TextStyle(fontSize: 10, color: QhseColors.red)),
                          ),
                ]),
                onTap: () => showAspectDialog(c, api, record: a, onSaved: load),
              ))),
        ]),
      ),
    );
  }

  Widget _buildConformite(BuildContext c, List veilleEnv) => Scaffold(
        floatingActionButton: FloatingActionButton.extended(onPressed: () => showVeilleEnvDialog(c, api, onSaved: load), icon: const Icon(Icons.add), label: Text(t('environnement.fabExigence'))),
        body: RefreshIndicator(
          onRefresh: load,
          child: ListView(padding: const EdgeInsets.all(12), children: [
            KpiBar([
              KpiStat(t('environnement.kpiExigences'), '${veilleEnv.length}', color: QhseColors.blue, icon: Icons.gavel_outlined),
              KpiStat(t('environnement.kpiNonConformes'), '${veilleEnv.where((v) => v['statut'] == 'NON_CONFORME').length}', color: QhseColors.red, icon: Icons.warning_amber_outlined),
              KpiStat(t('environnement.kpiAVerifier'), '${veilleEnv.where((v) => v['statut'] == 'A_VERIFIER').length}', color: QhseColors.amber, icon: Icons.help_outline),
            ]),
            const SizedBox(height: 12),
            if (veilleEnv.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(t('environnement.aucuneExigence'), style: TextStyle(color: QhseColors.textSecondary))))
            else ...veilleEnv.map((v) => Card(child: ListTile(
                  title: Text((v['texte'] ?? '').toString().length > 50 ? '${v['texte'].toString().substring(0, 50)}…' : v['texte'] ?? ''),
                  trailing: Text(kVeilleStatutLabel(v['statut']), style: TextStyle(color: _veilleStatutColor(v['statut']), fontWeight: FontWeight.bold, fontSize: 11)),
                  onTap: () => showVeilleEnvDialog(c, api, record: v, onSaved: load),
                ))),
          ]),
        ),
      );

  Widget _buildProduits(BuildContext c) {
    final now = DateTime.now();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(onPressed: () => showProduitChimiqueDialog(c, api, onSaved: load), icon: const Icon(Icons.add), label: Text(t('environnement.fabProduit'))),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(padding: const EdgeInsets.all(12), children: [
          KpiBar([
            KpiStat(t('environnement.kpiProduits'), '${produits.length}', color: QhseColors.blue, icon: Icons.science_outlined),
            KpiStat(t('environnement.kpiFdsManquantes'), '${produits.where((p) => p['fdsDisponible'] != true).length}', color: QhseColors.amber, icon: Icons.description_outlined),
            KpiStat(t('environnement.kpiExpires'), '${produits.where((p) => p['dateExpiration'] != null && DateTime.parse(p['dateExpiration']).isBefore(now)).length}', color: QhseColors.red, icon: Icons.warning_amber_outlined),
          ]),
          const SizedBox(height: 12),
          if (produits.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(t('environnement.aucunProduit'), style: TextStyle(color: QhseColors.textSecondary))))
          else ...produits.map((p) {
            final expired = p['dateExpiration'] != null && DateTime.parse(p['dateExpiration']).isBefore(now);
            return Card(child: ListTile(
              title: Text(p['nom'] ?? ''),
              subtitle: Text('${p['classification'] ?? '—'} • Stock : ${p['quantiteStockee'] ?? '—'}${p['unite'] ?? ''}'),
              trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                if (p['fdsDisponible'] != true) Text(t('environnement.fdsManquante'), style: TextStyle(fontSize: 10, color: QhseColors.amber)),
                if (expired) Text(t('environnement.expire'), style: TextStyle(fontSize: 10, color: QhseColors.red, fontWeight: FontWeight.bold)),
              ]),
              onTap: () => showProduitChimiqueDialog(c, api, record: p, onSaved: load),
            ));
          }),
        ]),
      ),
    );
  }

  Widget _buildIndicateurs(BuildContext c) {
    final cibles = indicateurs.where((i) => (i['sensInverse'] == true) ? (i['actuel'] <= i['cible']) : (i['actuel'] >= i['cible'])).length;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(onPressed: () => showIndicateurEnvDialog(c, api, onSaved: load), icon: const Icon(Icons.add), label: Text(t('environnement.fabIndicateur'))),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(padding: const EdgeInsets.all(12), children: [
          KpiBar([
            KpiStat(t('environnement.kpiIndicateurs'), '${indicateurs.length}', color: QhseColors.blue, icon: Icons.insights_outlined),
            KpiStat(t('environnement.kpiDansLaCible'), '$cibles', color: QhseColors.green, icon: Icons.check_circle_outline),
            KpiStat(t('environnement.kpiHorsCible'), '${indicateurs.length - cibles}', color: QhseColors.red, icon: Icons.error_outline),
          ]),
          const SizedBox(height: 12),
          if (indicateurs.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(t('environnement.aucunIndicateur'), style: TextStyle(color: QhseColors.textSecondary))))
          else ...indicateurs.map((i) {
            final atteint = i['sensInverse'] == true ? i['actuel'] <= i['cible'] : i['actuel'] >= i['cible'];
            return Card(child: ListTile(
              title: Text(i['indicateur'] ?? ''),
              subtitle: Text('${i['actuel']}${i['unite'] ?? ''} / ${i['cible']}${i['unite'] ?? ''}'),
              trailing: Icon(Icons.circle, size: 12, color: atteint ? QhseColors.green : QhseColors.amber),
            ));
          }),
        ]),
      ),
    );
  }
}

// --- Formulaires ---
Future<void> showReleveDialog(BuildContext context, Api api, {Map? record, required VoidCallback onSaved}) async {
  final type = TextEditingController(text: record?['type'] ?? '');
  final value = TextEditingController(text: record?['value']?.toString() ?? '');
  final unit = TextEditingController(text: record?['unit'] ?? '');
  final site = TextEditingController(text: record?['site'] ?? '');
  String? categorie = record?['categorie'];
  bool? conforme = record?['conforme'];
  String? formError;
  bool saving = false;
  await showDialog(context: context, builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
    title: Text(record == null ? t('environnement.nouveauReleveTitle') : t('environnement.modifierReleveTitle')),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      DropdownButtonFormField<String>(
        value: categorie, isExpanded: true, decoration: InputDecoration(labelText: t('environnement.categorie')),
        items: kCategoriesEnv.map((cat) => DropdownMenuItem(value: cat, child: Text(_categorieEnvLabel(cat)))).toList(),
        onChanged: (v) => setD(() => categorie = v),
      ),
      TextField(controller: type, decoration: InputDecoration(labelText: t('environnement.typeDeReleve'))),
      Row(children: [
        Expanded(child: TextField(controller: value, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: t('environnement.valeur')))),
        const SizedBox(width: 8),
        Expanded(child: TextField(controller: unit, decoration: InputDecoration(labelText: t('environnement.unite')))),
      ]),
      TextField(controller: site, decoration: InputDecoration(labelText: t('environnement.siteOptionnel'))),
      DropdownButtonFormField<bool>(
        value: conforme, decoration: InputDecoration(labelText: t('environnement.conformiteOptionnelle')),
        items: [DropdownMenuItem(value: true, child: Text(t('environnement.conformiteConforme'))), DropdownMenuItem(value: false, child: Text(t('environnement.conformiteNonConforme')))],
        onChanged: (v) => setD(() => conforme = v),
      ),
      if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
    ])),
    actions: [
      if (record != null) TextButton(onPressed: () async {
        try { await api.delete('/business/environment/${record['id']}'); if (context.mounted) Navigator.pop(c); onSaved(); }
        catch (e) { setD(() => formError = '$e'); }
      }, child: Text(t('environnement.supprimer'), style: const TextStyle(color: QhseColors.red))),
      TextButton(onPressed: () => Navigator.pop(c), child: Text(t('environnement.annuler'))),
      FilledButton(onPressed: saving ? null : () async {
        setD(() => saving = true);
        final payload = {'categorie': categorie, 'type': type.text, 'value': double.tryParse(value.text), 'unit': unit.text.isEmpty ? null : unit.text, 'site': site.text.isEmpty ? null : site.text, 'conforme': conforme};
        try {
          if (record != null) await api.patch('/business/environment/${record['id']}', payload);
          else await api.post('/business/environment', {'code': 'ENV-${DateTime.now().millisecondsSinceEpoch}', ...payload, 'recordedAt': DateTime.now().toIso8601String()});
          if (context.mounted) Navigator.pop(c);
          onSaved();
        } on ApiException catch (e) {
          if (e.networkError && record == null) {
            await SyncQueue.enqueue('environmentRecord', 'CREATE', {'code': 'ENV-${DateTime.now().millisecondsSinceEpoch}', ...payload, 'recordedAt': DateTime.now().toIso8601String()});
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('environnement.releveHorsLigne')), duration: const Duration(seconds: 4)));
              Navigator.pop(c);
            }
            onSaved();
          } else {
            setD(() { saving = false; formError = '$e'; });
          }
        } catch (e) { setD(() { saving = false; formError = '$e'; }); }
      }, child: Text(saving ? t('environnement.enCours') : t('environnement.enregistrer'))),
    ],
  )));
}

Future<void> showAspectDialog(BuildContext context, Api api, {Map? record, required VoidCallback onSaved}) async {
  final aspect = TextEditingController(text: record?['aspect'] ?? '');
  String? milieu = record?['milieu'];
  int gravite = record?['gravite'] ?? 1, probabilite = record?['probabilite'] ?? 1, frequence = record?['frequence'] ?? 1, maitrise = record?['maitrise'] ?? 1;
  String? formError;
  bool saving = false;
  await showDialog(context: context, builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
    title: Text(record == null ? t('environnement.nouvelAspectTitle') : t('environnement.modifierAspectTitle')),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: aspect, decoration: InputDecoration(labelText: t('environnement.aspectEnvironnemental'))),
      DropdownButtonFormField<String>(
        value: milieu, decoration: InputDecoration(labelText: t('environnement.milieuConcerne')),
        items: kMilieuxEnv.map((m) => DropdownMenuItem(value: m, child: Text(_milieuEnvLabel(m)))).toList(),
        onChanged: (v) => setD(() => milieu = v),
      ),
      Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(top: 8), child: Text(t('environnement.criticiteFormule'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)))),
      Row(children: [
        Expanded(child: DropdownButtonFormField<int>(value: frequence, decoration: InputDecoration(labelText: t('environnement.freq')), items: [1, 2, 3, 4].map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(), onChanged: (v) => setD(() => frequence = v!))),
        const SizedBox(width: 6),
        Expanded(child: DropdownButtonFormField<int>(value: gravite, decoration: InputDecoration(labelText: t('environnement.graviteLabel')), items: [1, 2, 3, 4].map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(), onChanged: (v) => setD(() => gravite = v!))),
      ]),
      Row(children: [
        Expanded(child: DropdownButtonFormField<int>(value: probabilite, decoration: InputDecoration(labelText: t('environnement.probaLabel')), items: [1, 2, 3, 4].map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(), onChanged: (v) => setD(() => probabilite = v!))),
        const SizedBox(width: 6),
        Expanded(child: DropdownButtonFormField<int>(value: maitrise, decoration: InputDecoration(labelText: t('environnement.maitriseLabel')), items: [1, 2, 3, 4].map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(), onChanged: (v) => setD(() => maitrise = v!))),
      ]),
      Builder(builder: (context) {
        final crit = ((frequence * gravite * probabilite) / maitrise).round();
        return Padding(padding: const EdgeInsets.only(top: 6), child: Text(t('environnement.criticiteCalculee', {'crit': '$crit', 'label': _criticiteLabel(crit)}), style: TextStyle(color: _criticiteColor(crit), fontSize: 12)));
      }),
      if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
    ])),
    actions: [
      if (record != null) TextButton(onPressed: () async {
        try { await api.delete('/business/environnement-aspects/${record['id']}'); if (context.mounted) Navigator.pop(c); onSaved(); }
        catch (e) { setD(() => formError = '$e'); }
      }, child: Text(t('environnement.supprimer'), style: const TextStyle(color: QhseColors.red))),
      TextButton(onPressed: () => Navigator.pop(c), child: Text(t('environnement.annuler'))),
      FilledButton(onPressed: saving ? null : () async {
        setD(() => saving = true);
        final payload = {'aspect': aspect.text, 'milieu': milieu, 'gravite': gravite, 'probabilite': probabilite, 'frequence': frequence, 'maitrise': maitrise};
        try {
          if (record != null) await api.patch('/business/environnement-aspects/${record['id']}', payload);
          else await api.post('/business/environnement-aspects', {'code': 'ASP-${DateTime.now().millisecondsSinceEpoch}', ...payload});
          if (context.mounted) Navigator.pop(c);
          onSaved();
        } catch (e) { setD(() { saving = false; formError = '$e'; }); }
      }, child: Text(saving ? t('environnement.enCours') : t('environnement.enregistrer'))),
    ],
  )));
}

Future<void> showVeilleEnvDialog(BuildContext context, Api api, {Map? record, required VoidCallback onSaved}) async {
  final texte = TextEditingController(text: record?['texte'] ?? '');
  String statut = record?['statut'] ?? 'A_TRAITER';
  String? formError;
  bool saving = false;
  await showDialog(context: context, builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
    title: Text(record == null ? t('environnement.nouvelleExigenceTitle') : t('environnement.modifierExigenceTitle')),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: texte, maxLines: 3, decoration: InputDecoration(labelText: t('environnement.texteReglementaire'))),
      DropdownButtonFormField<String>(
        value: statut, isExpanded: true, decoration: InputDecoration(labelText: t('environnement.statut')),
        items: kVeilleStatutKeys.keys.map((k) => DropdownMenuItem(value: k, child: Text(kVeilleStatutLabel(k)))).toList(),
        onChanged: (v) => setD(() => statut = v ?? 'A_TRAITER'),
      ),
      if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
    ])),
    actions: [
      if (record != null) TextButton(onPressed: () async {
        try { await api.delete('/business/veille-reglementaire/${record['id']}'); if (context.mounted) Navigator.pop(c); onSaved(); }
        catch (e) { setD(() => formError = '$e'); }
      }, child: Text(t('environnement.supprimer'), style: const TextStyle(color: QhseColors.red))),
      TextButton(onPressed: () => Navigator.pop(c), child: Text(t('environnement.annuler'))),
      FilledButton(onPressed: saving ? null : () async {
        setD(() => saving = true);
        final payload = {'texte': texte.text, 'domaine': 'Environnement', 'statut': statut};
        try {
          if (record != null) await api.patch('/business/veille-reglementaire/${record['id']}', payload);
          else await api.post('/business/veille-reglementaire', {'code': 'VEI-${DateTime.now().millisecondsSinceEpoch}', ...payload});
          if (context.mounted) Navigator.pop(c);
          onSaved();
        } catch (e) { setD(() { saving = false; formError = '$e'; }); }
      }, child: Text(saving ? t('environnement.enCours') : t('environnement.enregistrer'))),
    ],
  )));
}

Future<void> showProduitChimiqueDialog(BuildContext context, Api api, {Map? record, required VoidCallback onSaved}) async {
  final nom = TextEditingController(text: record?['nom'] ?? '');
  final quantite = TextEditingController(text: record?['quantiteStockee']?.toString() ?? '');
  final unite = TextEditingController(text: record?['unite'] ?? '');
  bool retention = record?['retention'] ?? false;
  bool fdsDisponible = record?['fdsDisponible'] ?? false;
  String? formError;
  bool saving = false;
  await showDialog(context: context, builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
    title: Text(record == null ? t('environnement.nouveauProduitTitle') : t('environnement.modifierProduitTitle')),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: nom, decoration: InputDecoration(labelText: t('environnement.nom'))),
      Row(children: [
        Expanded(child: TextField(controller: quantite, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: t('environnement.quantiteStockee')))),
        const SizedBox(width: 8),
        Expanded(child: TextField(controller: unite, decoration: InputDecoration(labelText: t('environnement.unite')))),
      ]),
      CheckboxListTile(contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, title: Text(t('environnement.retentionEnPlace'), style: const TextStyle(fontSize: 12)), value: retention, onChanged: (v) => setD(() => retention = v ?? false)),
      CheckboxListTile(contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, title: Text(t('environnement.fdsDisponible'), style: const TextStyle(fontSize: 12)), value: fdsDisponible, onChanged: (v) => setD(() => fdsDisponible = v ?? false)),
      if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
    ])),
    actions: [
      if (record != null) TextButton(onPressed: () async {
        try { await api.delete('/business/produits-chimiques/${record['id']}'); if (context.mounted) Navigator.pop(c); onSaved(); }
        catch (e) { setD(() => formError = '$e'); }
      }, child: Text(t('environnement.supprimer'), style: const TextStyle(color: QhseColors.red))),
      TextButton(onPressed: () => Navigator.pop(c), child: Text(t('environnement.annuler'))),
      FilledButton(onPressed: saving ? null : () async {
        setD(() => saving = true);
        final payload = {'nom': nom.text, 'quantiteStockee': double.tryParse(quantite.text), 'unite': unite.text.isEmpty ? null : unite.text, 'retention': retention, 'fdsDisponible': fdsDisponible};
        try {
          if (record != null) await api.patch('/business/produits-chimiques/${record['id']}', payload);
          else await api.post('/business/produits-chimiques', {'code': 'CHIM-${DateTime.now().millisecondsSinceEpoch}', ...payload});
          if (context.mounted) Navigator.pop(c);
          onSaved();
        } catch (e) { setD(() { saving = false; formError = '$e'; }); }
      }, child: Text(saving ? t('environnement.enCours') : t('environnement.enregistrer'))),
    ],
  )));
}

Future<void> showIndicateurEnvDialog(BuildContext context, Api api, {required VoidCallback onSaved}) async {
  final indicateur = TextEditingController();
  final actuel = TextEditingController();
  final cible = TextEditingController();
  final unite = TextEditingController();
  final formule = TextEditingController();
  String? formError;
  bool saving = false;
  await showDialog(context: context, builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
    title: Text(t('environnement.nouvelIndicateurTitle')),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: indicateur, decoration: InputDecoration(labelText: t('environnement.nomIndicateur'))),
      TextField(controller: formule, decoration: InputDecoration(labelText: t('environnement.formuleOptionnel'))),
      Row(children: [
        Expanded(child: TextField(controller: actuel, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: t('environnement.actuel')))),
        const SizedBox(width: 8),
        Expanded(child: TextField(controller: cible, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: t('environnement.cible')))),
      ]),
      TextField(controller: unite, decoration: InputDecoration(labelText: t('environnement.unite'))),
      if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
    ])),
    actions: [
      TextButton(onPressed: () => Navigator.pop(c), child: Text(t('environnement.annuler'))),
      FilledButton(onPressed: saving ? null : () async {
        setD(() => saving = true);
        try {
          await api.post('/business/indicateurs-qualite', {
            'code': 'IND-${DateTime.now().millisecondsSinceEpoch}', 'domaine': 'ENVIRONNEMENT',
            'indicateur': indicateur.text, 'formule': formule.text.isEmpty ? null : formule.text,
            'actuel': double.tryParse(actuel.text) ?? 0, 'cible': double.tryParse(cible.text) ?? 0, 'unite': unite.text,
          });
          if (context.mounted) Navigator.pop(c);
          onSaved();
        } catch (e) { setD(() { saving = false; formError = '$e'; }); }
      }, child: Text(saving ? t('environnement.enCours') : t('environnement.enregistrer'))),
    ],
  )));
}
