import 'package:flutter/material.dart';
import '../services/api.dart';
import '../theme.dart';
import '../i18n/i18n.dart';
import 'load_error_view.dart';
import '../services/sync_queue.dart';

Map<String, String> get kCanalLabels => {
  'TELEPHONE': t('reclamationsPages.canalTelephone'), 'EMAIL': t('reclamationsPages.canalEmail'), 'SITE_WEB': t('reclamationsPages.canalSiteWeb'), 'RESEAUX_SOCIAUX': t('reclamationsPages.canalReseauxSociaux'),
  'COURRIER': t('reclamationsPages.canalCourrier'), 'COMMERCIAL': t('reclamationsPages.canalCommercial'), 'SAV': t('reclamationsPages.canalSav'), 'DIRECTE': t('reclamationsPages.canalDirecte'), 'AUTRE': t('reclamationsPages.canalAutre'),
};
const List<String> kCategoriesProbleme = [
  'Défaut produit', 'Non-conformité', 'Produit endommagé', 'Erreur de quantité', 'Erreur de livraison',
  'Retard de livraison', 'Emballage', 'Étiquetage', 'Facturation', 'Service', 'Communication', 'Délai',
  'Support technique', 'Comportement du personnel', 'Hygiène', 'Sécurité', 'Autre',
];
const Map<String, String> _kCategorieProblemeKeys = {
  'Défaut produit': 'reclamationsPages.catDefautProduit', 'Non-conformité': 'reclamationsPages.catNonConformite',
  'Produit endommagé': 'reclamationsPages.catProduitEndommage', 'Erreur de quantité': 'reclamationsPages.catErreurQuantite',
  'Erreur de livraison': 'reclamationsPages.catErreurLivraison', 'Retard de livraison': 'reclamationsPages.catRetardLivraison',
  'Emballage': 'reclamationsPages.catEmballage', 'Étiquetage': 'reclamationsPages.catEtiquetage',
  'Facturation': 'reclamationsPages.catFacturation', 'Service': 'reclamationsPages.catService',
  'Communication': 'reclamationsPages.catCommunication', 'Délai': 'reclamationsPages.catDelai',
  'Support technique': 'reclamationsPages.catSupportTechnique', 'Comportement du personnel': 'reclamationsPages.catComportementPersonnel',
  'Hygiène': 'reclamationsPages.catHygiene', 'Sécurité': 'reclamationsPages.catSecurite', 'Autre': 'reclamationsPages.catAutre',
};
String categorieProblemeLabel(String c) => t(_kCategorieProblemeKeys[c] ?? '') != '' ? t(_kCategorieProblemeKeys[c]!) : c;
Color graviteColor(String? g) => {'Critique': QhseColors.red, 'Majeure': QhseColors.red, 'Élevée': QhseColors.red, 'Modérée': QhseColors.amber, 'Faible': QhseColors.textSecondary}[g] ?? QhseColors.textSecondary;
Color niveauColor(String? n) => {'CRITIQUE': QhseColors.red, 'URGENT': QhseColors.red, 'ATTENTION': QhseColors.amber, 'INFORMATION': QhseColors.blue}[n] ?? QhseColors.textSecondary;

// --- Création / modification (enregistrement) ---
Future<void> showReclamationDialog(BuildContext context, Api api, {Map? record, required VoidCallback onSaved}) async {
  final client = TextEditingController(text: record?['client'] ?? '');
  final motif = TextEditingController(text: record?['motif'] ?? '');
  final description = TextEditingController(text: record?['description'] ?? '');
  final produitService = TextEditingController(text: record?['produitService'] ?? '');
  final lotNumber = TextEditingController(text: record?['lotNumber'] ?? '');
  final delaiCibleJours = TextEditingController(text: record?['delaiCibleJours']?.toString() ?? '');
  String? canal = record?['canal'];
  String? categorieProbleme = record?['categorieProbleme'];
  String gravite = record?['gravite'] ?? 'Faible';
  String statut = record?['statut'] ?? 'OPEN';
  DateTime date = record != null ? DateTime.parse(record['date']) : DateTime.now();
  String? formError;
  bool saving = false;
  await showDialog(
    context: context,
    builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
      title: Text(record == null ? t('reclamationsPages.dialogTitreNouvelle') : t('reclamationsPages.dialogTitreModifier')),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: client, decoration: InputDecoration(labelText: t('reclamationsPages.champClient'))),
            TextField(controller: motif, decoration: InputDecoration(labelText: t('reclamationsPages.champMotif'))),
            TextField(controller: description, decoration: InputDecoration(labelText: t('reclamationsPages.champDescription')), maxLines: 2),
            DropdownButtonFormField<String>(
              value: canal, isExpanded: true,
              items: kCanalLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
              onChanged: (v) => setD(() => canal = v), decoration: InputDecoration(labelText: t('reclamationsPages.champCanal')),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t('reclamationsPages.dateReception', {'date': '${date.day}/${date.month}/${date.year}'})),
              trailing: const Icon(Icons.edit_calendar),
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2035));
                if (d != null) setD(() => date = d);
              },
            ),
            TextField(controller: produitService, decoration: InputDecoration(labelText: t('reclamationsPages.champProduitService'))),
            TextField(controller: lotNumber, decoration: InputDecoration(labelText: t('reclamationsPages.champLotNumber'))),
            DropdownButtonFormField<String>(
              value: categorieProbleme, isExpanded: true,
              items: kCategoriesProbleme.map((c) => DropdownMenuItem(value: c, child: Text(categorieProblemeLabel(c)))).toList(),
              onChanged: (v) => setD(() => categorieProbleme = v), decoration: InputDecoration(labelText: t('reclamationsPages.champNatureProbleme')),
            ),
            DropdownButtonFormField<String>(
              value: gravite,
              items: [DropdownMenuItem(value: 'Faible', child: Text(t('reclamationsPages.graviteFaible'))), DropdownMenuItem(value: 'Modérée', child: Text(t('reclamationsPages.graviteModeree'))), DropdownMenuItem(value: 'Majeure', child: Text(t('reclamationsPages.graviteMajeure'))), DropdownMenuItem(value: 'Critique', child: Text(t('reclamationsPages.graviteCritique')))],
              onChanged: (v) => setD(() => gravite = v ?? 'Faible'), decoration: InputDecoration(labelText: t('reclamationsPages.champGravite')),
            ),
            TextField(controller: delaiCibleJours, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('reclamationsPages.champDelaiCible'))),
            if (record != null) DropdownButtonFormField<String>(
              value: statut,
              items: [DropdownMenuItem(value: 'OPEN', child: Text(t('reclamationsPages.statutOuverte'))), DropdownMenuItem(value: 'CLOSED', child: Text(t('reclamationsPages.statutCloturee')))],
              onChanged: (v) => setD(() => statut = v ?? 'OPEN'), decoration: InputDecoration(labelText: t('reclamationsPages.champStatut')),
            ),
            if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
          ]),
        ),
      ),
      actions: [
        if (record != null) TextButton(
          onPressed: () async {
            try { await api.delete('/business/reclamations/${record['id']}'); if (context.mounted) Navigator.pop(c); onSaved(); }
            catch (e) { setD(() => formError = '$e'); }
          },
          child: Text(t('reclamationsPages.supprimer'), style: const TextStyle(color: QhseColors.red)),
        ),
        TextButton(onPressed: () => Navigator.pop(c), child: Text(t('reclamationsPages.annuler'))),
        FilledButton(
          onPressed: saving ? null : () async {
            setD(() => saving = true);
            final payload = {
              'client': client.text, 'motif': motif.text, 'description': description.text, 'canal': canal,
              'date': date.toIso8601String(), 'produitService': produitService.text.isEmpty ? null : produitService.text,
              'lotNumber': lotNumber.text.isEmpty ? null : lotNumber.text, 'categorieProbleme': categorieProbleme,
              'gravite': gravite, 'statut': statut, 'delaiCibleJours': delaiCibleJours.text.isEmpty ? null : int.tryParse(delaiCibleJours.text),
            };
            final createPayload = {'code': 'REC-${DateTime.now().millisecondsSinceEpoch}', ...payload};
            try {
              if (record != null) await api.patch('/business/reclamations/${record['id']}', payload);
              else await api.post('/business/reclamations', createPayload);
              if (context.mounted) Navigator.pop(c);
              onSaved();
            } on ApiException catch (e) {
              if (e.networkError && record == null) {
                await SyncQueue.enqueue('reclamation', 'CREATE', createPayload);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('reclamationsPages.messageHorsLigne')), duration: const Duration(seconds: 4)));
                  Navigator.pop(c);
                }
                onSaved();
              } else {
                setD(() { saving = false; formError = '$e'; });
              }
            } catch (e) { setD(() { saving = false; formError = '$e'; }); }
          },
          child: Text(saving ? t('reclamationsPages.enregistrementEnCours') : t('reclamationsPages.enregistrer')),
        ),
      ],
    )),
  );
}

// --- Écran principal, à onglets ---
class ReclamationsHome extends StatefulWidget {
  const ReclamationsHome({super.key});
  @override
  State<ReclamationsHome> createState() => _ReclamationsHomeState();
}

class _ReclamationsHomeState extends State<ReclamationsHome> {
  final api = Api();
  List items = [];
  Map stats = {'volume': {}, 'performance': {}, 'pareto': [], 'parClient': [], 'parProduit': [], 'parProcessus': []};
  List alertes = [];
  Map score = {'score': null, 'detail': []};
  bool loading = true;
  Object? error;
  int tabIndex = 0;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      items = List.from(await api.get('/business/reclamations'));
      stats = Map.from(await api.get('/business/reclamations-stats'));
      alertes = List.from(await api.get('/business/reclamations-alertes'));
      score = Map.from(await api.get('/business/reclamations-score'));
    } catch (e) { error = e; }
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext c) {
    final volume = Map.from(stats['volume'] ?? {});
    final performance = Map.from(stats['performance'] ?? {});
    final pareto = List.from(stats['pareto'] ?? []);
    final scoreValue = score['score'];
    final scoreLevel = scoreValue == null ? null : scoreValue >= 80 ? {'label': t('reclamationsPages.niveauExcellent'), 'color': QhseColors.green} : scoreValue >= 65 ? {'label': t('reclamationsPages.niveauBon'), 'color': QhseColors.green} : scoreValue >= 50 ? {'label': t('reclamationsPages.niveauASurveiller'), 'color': QhseColors.amber} : {'label': t('reclamationsPages.niveauInsuffisant'), 'color': QhseColors.red};

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('reclamationsPages.titre')),
          bottom: TabBar(onTap: (i) => setState(() => tabIndex = i), tabs: [Tab(text: t('reclamationsPages.ongletTableauBord')), Tab(text: t('reclamationsPages.ongletRegistre'))]),
        ),
        floatingActionButton: FloatingActionButton.extended(onPressed: () => showReclamationDialog(context, api, onSaved: load), icon: const Icon(Icons.add), label: Text(t('reclamationsPages.nouvelleReclamation'))),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? LoadErrorView(error: error, onRetry: load)
            : IndexedStack(index: tabIndex, children: [
                // Tableau de bord
                RefreshIndicator(
                  onRefresh: load,
                  child: ListView(padding: const EdgeInsets.all(12), children: [
                    Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t('reclamationsPages.scoreGlobal'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      Row(children: [
                        Text(scoreValue != null ? '$scoreValue/100' : '—', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 32, color: scoreLevel?['color'] as Color? ?? QhseColors.textPrimary)),
                        if (scoreLevel != null) Padding(padding: const EdgeInsets.only(left: 10), child: Text(scoreLevel['label'] as String, style: TextStyle(color: scoreLevel['color'] as Color, fontWeight: FontWeight.w600))),
                      ]),
                    ]))),
                    const SizedBox(height: 12),
                    KpiBar([
                      KpiStat(t('reclamationsPages.kpiReclamations'), '${volume['total'] ?? 0}', color: QhseColors.amber, icon: Icons.notifications_outlined),
                      KpiStat(t('reclamationsPages.kpiOuvertes'), '${volume['ouvertes'] ?? 0}', color: QhseColors.blue, icon: Icons.hourglass_empty),
                      KpiStat(t('reclamationsPages.kpiCritiques'), '${volume['critiques'] ?? 0}', color: QhseColors.red, icon: Icons.warning_amber_outlined),
                      KpiStat(t('reclamationsPages.kpiEnRetard'), '${volume['enRetard'] ?? 0}', color: (volume['enRetard'] ?? 0) > 0 ? QhseColors.red : QhseColors.green, icon: Icons.timer_off_outlined),
                    ]),
                    const SizedBox(height: 16),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(t('reclamationsPages.alertesAutomatiques'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('${alertes.length}', style: TextStyle(color: QhseColors.textSecondary)),
                    ]),
                    const SizedBox(height: 6),
                    if (alertes.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(t('reclamationsPages.aucuneAlerte'), style: TextStyle(color: QhseColors.green)))
                    else ...alertes.map((a) => Card(child: ListTile(
                          title: Text('${a['client']} — ${a['motif']}'),
                          subtitle: Text(List.from(a['motifs'] ?? []).map((m) => m['label']).join(' · '), style: const TextStyle(fontSize: 11)),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: niveauColor(a['niveau']).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                            child: Text(a['niveau'] ?? '', style: TextStyle(color: niveauColor(a['niveau']), fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                          onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => ReclamationDetailPage(reclamationId: a['id']))).then((_) => load()),
                        ))),
                    const SizedBox(height: 16),
                    Text(t('reclamationsPages.performance'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 6),
                    Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
                      _statRow(t('reclamationsPages.tauxCloture'), performance['tauxCloture']),
                      _statRow(t('reclamationsPages.tauxClotureDelai'), performance['tauxClotureDelai']),
                      _statRow(t('reclamationsPages.delaiMoyenResolution'), performance['delaiMoyenResolution'], suffix: ''),
                    ]))),
                    const SizedBox(height: 16),
                    Text(t('reclamationsPages.paretoCauses'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 6),
                    if (pareto.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(t('reclamationsPages.aucuneReclamationClassifiee'), style: TextStyle(color: QhseColors.textSecondary)))
                    else ...pareto.map((p) => Card(child: ListTile(
                          title: Text(p['name'] ?? ''),
                          trailing: Text(t('reclamationsPages.paretoDetail', {'value': '${p['value']}', 'pct': '${p['pct']}', 'cumul': '${p['cumulPct']}'}), style: const TextStyle(fontSize: 11)),
                        ))),
                  ]),
                ),
                // Registre
                RefreshIndicator(
                  onRefresh: load,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: items.isEmpty
                        ? [Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(t('reclamationsPages.aucuneReclamationEnregistree'))))]
                        : items.map((r) => Card(child: ListTile(
                              title: Text('${r['client']} — ${r['motif']}'),
                              subtitle: Text('${r['produitService'] ?? ''} • ${(r['date'] ?? '').toString().substring(0, 10)}'),
                              leading: Icon(Icons.circle, size: 12, color: graviteColor(r['gravite'])),
                              trailing: Text(r['statut'] == 'OPEN' ? t('reclamationsPages.statutOuverte') : t('reclamationsPages.statutCloturee'), style: TextStyle(fontSize: 11, color: r['statut'] == 'OPEN' ? QhseColors.amber : QhseColors.green)),
                              onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => ReclamationDetailPage(reclamationId: r['id']))).then((_) => load()),
                              onLongPress: () => showReclamationDialog(context, api, record: r, onSaved: load),
                            ))).toList(),
                  ),
                ),
              ]),
      ),
    );
  }

  Widget _statRow(String label, dynamic value, {String suffix = '%'}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(fontSize: 12, color: QhseColors.textSecondary)),
          Text(value != null ? '$value$suffix' : '—', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      );
}

// --- Fiche détaillée : cycle de vie complet ---
class ReclamationDetailPage extends StatefulWidget {
  final String reclamationId;
  const ReclamationDetailPage({super.key, required this.reclamationId});
  @override
  State<ReclamationDetailPage> createState() => _ReclamationDetailPageState();
}

class _ReclamationDetailPageState extends State<ReclamationDetailPage> {
  final api = Api();
  Map? r;
  bool loading = true;
  bool saving = false;
  List users = [];
  final form = <String, dynamic>{};
  final costCtrls = <String, TextEditingController>{};

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      r = Map.from(await api.get('/business/reclamations/${widget.reclamationId}'));
      users = List.from(await api.get('/users'));
      form['dateAccuseReception'] = r!['dateAccuseReception'];
      form['datePremiereReponse'] = r!['datePremiereReponse'];
      form['dateResolutionReelle'] = r!['dateResolutionReelle'];
      form['dateCloture'] = r!['dateCloture'];
      form['actionCurative'] = r!['actionCurative'];
      form['actionCurativeResponsableId'] = r!['actionCurativeResponsableId'];
      form['causeRacine'] = r!['causeRacine'];
      form['efficacite'] = r!['efficacite'];
      form['satisfaction'] = r!['satisfaction'];
      for (final k in ['coutRemboursement', 'coutRemplacement', 'coutTransport', 'coutMainOeuvre', 'coutAutres']) {
        costCtrls[k] ??= TextEditingController(text: r![k]?.toString() ?? '');
      }
    } catch (_) {}
    setState(() => loading = false);
  }

  Future<void> pickDate(String field) async {
    final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2035));
    if (d != null) setState(() => form[field] = d.toIso8601String());
  }

  Future<void> save() async {
    setState(() => saving = true);
    try {
      final payload = Map<String, dynamic>.from(form);
      for (final k in costCtrls.keys) { payload[k] = costCtrls[k]!.text.isEmpty ? null : double.tryParse(costCtrls[k]!.text); }
      await api.patch('/business/reclamations/${widget.reclamationId}', payload);
      await load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('reclamationsPages.enregistreSnackbar'))));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    setState(() => saving = false);
  }

  Future<void> addAction() async {
    final title = TextEditingController(text: t('reclamationsPages.actionTitrePrefixe', {'client': '${r?['client']}'}));
    String? formError;
    bool savingAction = false;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
        title: Text(t('reclamationsPages.nouvelleActionCorrective')),
        content: TextField(controller: title, decoration: InputDecoration(labelText: t('reclamationsPages.champTitre'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(t('reclamationsPages.annuler'))),
          FilledButton(onPressed: savingAction ? null : () async {
            setD(() => savingAction = true);
            try {
              await api.post('/business/actions', {'code': 'ACT-${DateTime.now().millisecondsSinceEpoch}', 'title': title.text, 'priority': 2, 'status': 'OPEN', 'reclamationId': widget.reclamationId});
              if (context.mounted) Navigator.pop(c);
              load();
            } catch (e) { setD(() { savingAction = false; formError = '$e'; }); }
          }, child: Text(savingAction ? '…' : t('reclamationsPages.creer'))),
        ],
      )),
    );
  }

  String _fmtDate(dynamic v) => v == null ? '—' : (v as String).substring(0, 10);

  @override
  Widget build(BuildContext context) {
    if (loading || r == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final costTotal = costCtrls.values.fold<double>(0, (s, ctrl) => s + (double.tryParse(ctrl.text) ?? 0));
    return Scaffold(
      appBar: AppBar(title: Text(r!['client'] ?? '')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: ListTile(title: Text(r!['motif'] ?? ''), subtitle: Text('${r!['produitService'] ?? ''} • ${r!['statut'] == 'OPEN' ? t('reclamationsPages.statutOuverte') : t('reclamationsPages.statutCloturee')}'), trailing: Text(t('reclamationsPages.coutTotal', {'value': costTotal.toStringAsFixed(0)}), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11)))),
        const SizedBox(height: 16),

        Text(t('reclamationsPages.slaEtDelais'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 6),
        ...[
          ['dateAccuseReception', t('reclamationsPages.slaAccuseReception')], ['datePremiereReponse', t('reclamationsPages.slaPremiereReponse')],
          ['dateResolutionReelle', t('reclamationsPages.slaResolutionReelle')], ['dateCloture', t('reclamationsPages.slaCloture')],
        ].map((f) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(f[1]),
              subtitle: Text(_fmtDate(form[f[0]])),
              trailing: const Icon(Icons.edit_calendar, size: 18),
              onTap: () => pickDate(f[0]),
            )),

        const SizedBox(height: 12),
        Text(t('reclamationsPages.actionCurativeTitre'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 6),
        TextFormField(initialValue: form['actionCurative'], decoration: InputDecoration(labelText: t('reclamationsPages.champActionRealisee')), onChanged: (v) => form['actionCurative'] = v),
        DropdownButtonFormField<String>(
          value: form['actionCurativeResponsableId'], isExpanded: true,
          items: users.map<DropdownMenuItem<String>>((u) => DropdownMenuItem(value: u['id'] as String, child: Text('${u['firstName']} ${u['lastName']}'))).toList(),
          onChanged: (v) => setState(() => form['actionCurativeResponsableId'] = v),
          decoration: InputDecoration(labelText: t('reclamationsPages.champResponsable')),
        ),

        const SizedBox(height: 12),
        Text(t('reclamationsPages.analyseDesCauses'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 6),
        TextFormField(initialValue: form['causeRacine'], decoration: InputDecoration(labelText: t('reclamationsPages.champCauseRacine')), onChanged: (v) => form['causeRacine'] = v),

        const SizedBox(height: 12),
        Text(t('reclamationsPages.efficaciteEtSatisfaction'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: form['efficacite'],
          items: [DropdownMenuItem(value: 'EFFICACE', child: Text(t('reclamationsPages.efficaciteEfficace'))), DropdownMenuItem(value: 'PARTIELLEMENT_EFFICACE', child: Text(t('reclamationsPages.efficacitePartiellement'))), DropdownMenuItem(value: 'INEFFICACE', child: Text(t('reclamationsPages.efficaciteInefficace')))],
          onChanged: (v) => setState(() => form['efficacite'] = v), decoration: InputDecoration(labelText: t('reclamationsPages.champEfficaciteAction')),
        ),
        DropdownButtonFormField<String>(
          value: form['satisfaction'],
          items: [DropdownMenuItem(value: 'SATISFAIT', child: Text(t('reclamationsPages.satisfactionSatisfait'))), DropdownMenuItem(value: 'PARTIELLEMENT_SATISFAIT', child: Text(t('reclamationsPages.satisfactionPartiellement'))), DropdownMenuItem(value: 'INSATISFAIT', child: Text(t('reclamationsPages.satisfactionInsatisfait')))],
          onChanged: (v) => setState(() => form['satisfaction'] = v), decoration: InputDecoration(labelText: t('reclamationsPages.champSatisfactionClient')),
        ),

        const SizedBox(height: 12),
        Text(t('reclamationsPages.coutsDetailles'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 6),
        ...[
          ['coutRemboursement', t('reclamationsPages.coutRemboursement')], ['coutRemplacement', t('reclamationsPages.coutRemplacement')], ['coutTransport', t('reclamationsPages.coutTransport')],
          ['coutMainOeuvre', t('reclamationsPages.coutMainOeuvre')], ['coutAutres', t('reclamationsPages.coutAutres')],
        ].map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(controller: costCtrls[f[0]], keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: f[1]), onChanged: (_) => setState(() {})),
            )),

        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(t('reclamationsPages.planActionsCorrectives'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          TextButton(onPressed: addAction, child: Text(t('reclamationsPages.plusAction'))),
        ]),
        if (List.from(r!['actions'] ?? []).isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(t('reclamationsPages.aucuneActionLiee'), style: TextStyle(color: QhseColors.textSecondary)))
        else ...List.from(r!['actions'] ?? []).map((a) => Card(child: ListTile(dense: true, title: Text(a['title'] ?? ''), trailing: Text(a['status'] ?? '', style: const TextStyle(fontSize: 11))))),

        const SizedBox(height: 20),
        FilledButton(onPressed: saving ? null : save, child: Text(saving ? t('reclamationsPages.enregistrementEnCours') : t('reclamationsPages.enregistrer'))),
      ]),
    );
  }
}
