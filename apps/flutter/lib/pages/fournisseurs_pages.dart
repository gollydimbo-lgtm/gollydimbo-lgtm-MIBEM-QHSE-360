import 'package:flutter/material.dart';
import '../services/api.dart';
import '../theme.dart';
import '../i18n/i18n.dart';
import 'capa_link_widget.dart';
import 'load_error_view.dart';
import '../services/sync_queue.dart';

Map<String, String> get kFournisseurStatutLabels => {
  'PROSPECT': t('fournisseursPages.statutProspect'), 'EN_QUALIFICATION': t('fournisseursPages.statutEnQualification'), 'EN_ATTENTE_HOMOLOGATION': t('fournisseursPages.statutEnAttenteHomologation'),
  'HOMOLOGUE': t('fournisseursPages.statutHomologue'), 'HOMOLOGUE_CONDITIONS': t('fournisseursPages.statutHomologueConditions'), 'SOUS_SURVEILLANCE': t('fournisseursPages.statutSousSurveillance'),
  'SUSPENDU': t('fournisseursPages.statutSuspendu'), 'BLOQUE': t('fournisseursPages.statutBloque'), 'INACTIF': t('fournisseursPages.statutInactif'), 'RETIRE': t('fournisseursPages.statutRetireDuPanel'),
};
Color _niveauColor(String? n) => {'CRITIQUE': QhseColors.red, 'URGENT': QhseColors.red, 'ATTENTION': QhseColors.amber}[n] ?? QhseColors.textSecondary;
int? _scoreApprox(Map f) {
  final vals = [f['scoreQualite'], f['scoreLivraison'], f['scoreQhse'], f['scoreCommercial'], f['scoreReactivite']].whereType<num>().toList();
  return vals.isEmpty ? null : (vals.reduce((a, b) => a + b) / vals.length).round();
}

// --- Écran principal : tableau de bord + registre ---
class FournisseursHome extends StatefulWidget {
  const FournisseursHome({super.key});
  @override
  State<FournisseursHome> createState() => _FournisseursHomeState();
}

class _FournisseursHomeState extends State<FournisseursHome> {
  final api = Api();
  List items = [];
  Map classement = {'top': [], 'flop': []};
  List alertes = [];
  List matrice = [];
  bool loading = true;
  Object? error;
  int tabIndex = 0;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      items = List.from(await api.get('/business/fournisseurs'));
      classement = Map.from(await api.get('/business/fournisseurs-classement'));
      alertes = List.from(await api.get('/business/fournisseurs-alertes'));
      matrice = List.from(await api.get('/business/fournisseurs-matrice-risque'));
    } catch (e) { error = e; }
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext c) {
    final criticiteCount = items.where((f) => f['criticite'] == true).length;
    final nonHomologues = items.where((f) => ['EN_ATTENTE_HOMOLOGATION', 'EN_QUALIFICATION'].contains(f['statut'])).length;
    final top = List.from(classement['top'] ?? []);
    final flop = List.from(classement['flop'] ?? []);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('fournisseursPages.titre')),
          bottom: TabBar(onTap: (i) => setState(() => tabIndex = i), tabs: [Tab(text: t('fournisseursPages.tabTableauDeBord')), Tab(text: t('fournisseursPages.tabRegistre'))]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => showFournisseurDialog(context, api, onSaved: load),
          icon: const Icon(Icons.add),
          label: Text(t('fournisseursPages.fournisseur')),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? LoadErrorView(error: error, onRetry: load)
            : IndexedStack(index: tabIndex, children: [
                RefreshIndicator(
                  onRefresh: load,
                  child: ListView(padding: const EdgeInsets.all(12), children: [
                    KpiBar([
                      KpiStat(t('fournisseursPages.kpiFournisseurs'), '${items.length}', color: QhseColors.blue, icon: Icons.local_shipping_outlined),
                      KpiStat(t('fournisseursPages.kpiCritiques'), '$criticiteCount', color: criticiteCount > 0 ? QhseColors.red : QhseColors.green, icon: Icons.warning_amber_outlined),
                      KpiStat(t('fournisseursPages.kpiEnAttenteHomologation'), '$nonHomologues', color: nonHomologues > 0 ? QhseColors.amber : QhseColors.green, icon: Icons.hourglass_empty),
                    ]),
                    const SizedBox(height: 16),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(t('fournisseursPages.alertesAutomatiques'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('${alertes.length}', style: TextStyle(color: QhseColors.textSecondary)),
                    ]),
                    const SizedBox(height: 6),
                    if (alertes.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(t('fournisseursPages.aucuneAlerte'), style: TextStyle(color: QhseColors.green)))
                    else ...alertes.map((a) => Card(child: ListTile(
                          title: Text(a['nom'] ?? ''),
                          subtitle: Text(List.from(a['motifs'] ?? []).map((m) => m['label']).join(' · '), style: const TextStyle(fontSize: 11)),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: _niveauColor(a['niveau']).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                            child: Text(a['niveau'] ?? '', style: TextStyle(color: _niveauColor(a['niveau']), fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                          onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => FournisseurDetailPage(fournisseurId: a['id']))).then((_) => load()),
                        ))),
                    if (matrice.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(t('fournisseursPages.matriceDeRisque'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 6),
                      ...matrice.map((r) => Card(child: ListTile(
                            dense: true,
                            title: Text('${r['fournisseur'] ?? '—'} — ${r['hazard'] ?? ''}'),
                            trailing: Text('${r['score']}', style: TextStyle(fontWeight: FontWeight.bold, color: (r['score'] ?? 0) >= 12 ? QhseColors.red : (r['score'] ?? 0) >= 6 ? QhseColors.amber : QhseColors.green)),
                          ))),
                    ],
                    const SizedBox(height: 16),
                    Text(t('fournisseursPages.top10Fournisseurs'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 6),
                    if (top.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(t('fournisseursPages.aucunFournisseurAvecScore'), style: TextStyle(color: QhseColors.textSecondary)))
                    else ...top.asMap().entries.map((e) => ListTile(
                          dense: true,
                          title: Text('${e.key + 1}. ${e.value['nom']}'),
                          trailing: Text('${e.value['score']}%', style: TextStyle(color: QhseColors.green, fontWeight: FontWeight.bold)),
                          onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => FournisseurDetailPage(fournisseurId: e.value['id']))).then((_) => load()),
                        )),
                    const SizedBox(height: 16),
                    Text(t('fournisseursPages.moinsPerformants'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 6),
                    if (flop.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(t('fournisseursPages.aucunFournisseurAvecScore'), style: TextStyle(color: QhseColors.textSecondary)))
                    else ...flop.asMap().entries.map((e) => ListTile(
                          dense: true,
                          title: Text('${e.key + 1}. ${e.value['nom']}'),
                          trailing: Text('${e.value['score']}%', style: TextStyle(color: (e.value['score'] ?? 0) < 50 ? QhseColors.red : QhseColors.amber, fontWeight: FontWeight.bold)),
                          onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => FournisseurDetailPage(fournisseurId: e.value['id']))).then((_) => load()),
                        )),
                  ]),
                ),
                RefreshIndicator(
                  onRefresh: load,
                  child: items.isEmpty
                      ? ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(t('fournisseursPages.aucunFournisseurEnregistre'))))])
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: items.length,
                          itemBuilder: (_, i) {
                            final f = items[i];
                            final score = _scoreApprox(f);
                            return Card(child: ListTile(
                              title: Text(f['nom'] ?? ''),
                              subtitle: Text('${f['typeFournisseur'] ?? f['categorie'] ?? '—'} • ${kFournisseurStatutLabels[f['statut']] ?? f['statut'] ?? ''}'),
                              trailing: score != null ? Text('$score%', style: TextStyle(fontWeight: FontWeight.bold, color: score >= 85 ? QhseColors.green : score >= 70 ? QhseColors.amber : QhseColors.red)) : null,
                              onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => FournisseurDetailPage(fournisseurId: f['id']))).then((_) => load()),
                            ));
                          },
                        ),
                ),
              ]),
      ),
    );
  }
}

// --- Création / modification ---
Future<void> showFournisseurDialog(BuildContext context, Api api, {Map? record, required VoidCallback onSaved}) async {
  final nom = TextEditingController(text: record?['nom'] ?? '');
  final categorie = TextEditingController(text: record?['categorie'] ?? '');
  final contactNom = TextEditingController(text: record?['contactNom'] ?? '');
  final capaciteTechnique = TextEditingController(text: record?['capaciteTechnique'] ?? '');
  final scoreQualite = TextEditingController(text: record?['scoreQualite']?.toString() ?? '');
  final scoreLivraison = TextEditingController(text: record?['scoreLivraison']?.toString() ?? '');
  final scoreQhse = TextEditingController(text: record?['scoreQhse']?.toString() ?? '');
  String? typeFournisseur = record?['typeFournisseur'];
  String statut = record?['statut'] ?? 'HOMOLOGUE';
  bool criticite = record?['criticite'] ?? false;
  String? formError;
  bool saving = false;
  await showDialog(
    context: context,
    builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
      title: Text(record == null ? t('fournisseursPages.nouveauFournisseur') : t('fournisseursPages.modifierLeFournisseur')),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nom, decoration: InputDecoration(labelText: t('fournisseursPages.raisonSociale'))),
            DropdownButtonFormField<String>(
              value: typeFournisseur, isExpanded: true,
              decoration: InputDecoration(labelText: t('fournisseursPages.type')),
              items: [
                DropdownMenuItem(value: 'FOURNISSEUR', child: Text(t('fournisseursPages.typeFournisseur'))), DropdownMenuItem(value: 'PRESTATAIRE', child: Text(t('fournisseursPages.typePrestataire'))),
                DropdownMenuItem(value: 'SOUS_TRAITANT', child: Text(t('fournisseursPages.typeSousTraitant'))), DropdownMenuItem(value: 'TRANSPORTEUR', child: Text(t('fournisseursPages.typeTransporteur'))), DropdownMenuItem(value: 'AUTRE', child: Text(t('fournisseursPages.typeAutre'))),
              ],
              onChanged: (v) => setD(() => typeFournisseur = v),
            ),
            TextField(controller: categorie, decoration: InputDecoration(labelText: t('fournisseursPages.categorieOptionnel'))),
            TextField(controller: contactNom, decoration: InputDecoration(labelText: t('fournisseursPages.contactOptionnel'))),
            TextField(controller: capaciteTechnique, decoration: InputDecoration(labelText: t('fournisseursPages.capaciteTechniqueOptionnel')), maxLines: 2),
            DropdownButtonFormField<String>(
              value: statut, isExpanded: true,
              decoration: InputDecoration(labelText: t('fournisseursPages.statut')),
              items: kFournisseurStatutLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
              onChanged: (v) => setD(() => statut = v ?? 'HOMOLOGUE'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading,
              title: Text(t('fournisseursPages.fournisseurCritique'), style: const TextStyle(fontSize: 12)),
              value: criticite, onChanged: (v) => setD(() => criticite = v ?? false),
            ),
            Align(alignment: Alignment.centerLeft, child: Text(t('fournisseursPages.scoresParDomaine'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            Row(children: [
              Expanded(child: TextField(controller: scoreQualite, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('fournisseursPages.qualite')))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: scoreLivraison, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('fournisseursPages.livraison')))),
            ]),
            TextField(controller: scoreQhse, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('fournisseursPages.qhse'))),
            if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
          ]),
        ),
      ),
      actions: [
        if (record != null) TextButton(
          onPressed: () async {
            try { await api.delete('/business/fournisseurs/${record['id']}'); if (context.mounted) Navigator.pop(c); onSaved(); }
            catch (e) { setD(() => formError = '$e'); }
          },
          child: Text(t('fournisseursPages.supprimer'), style: const TextStyle(color: QhseColors.red)),
        ),
        TextButton(onPressed: () => Navigator.pop(c), child: Text(t('fournisseursPages.annuler'))),
        FilledButton(onPressed: saving ? null : () async {
          setD(() => saving = true);
          final payload = {
            'nom': nom.text, 'typeFournisseur': typeFournisseur, 'categorie': categorie.text.isEmpty ? null : categorie.text,
            'contactNom': contactNom.text.isEmpty ? null : contactNom.text, 'capaciteTechnique': capaciteTechnique.text.isEmpty ? null : capaciteTechnique.text,
            'statut': statut, 'criticite': criticite,
            'scoreQualite': scoreQualite.text.isEmpty ? null : int.tryParse(scoreQualite.text),
            'scoreLivraison': scoreLivraison.text.isEmpty ? null : int.tryParse(scoreLivraison.text),
            'scoreQhse': scoreQhse.text.isEmpty ? null : int.tryParse(scoreQhse.text),
          };
          final createPayload = {'code': 'FOUR-${DateTime.now().millisecondsSinceEpoch}', ...payload};
          try {
            if (record != null) await api.patch('/business/fournisseurs/${record['id']}', payload);
            else await api.post('/business/fournisseurs', createPayload);
            if (context.mounted) Navigator.pop(c);
            onSaved();
          } on ApiException catch (e) {
            if (e.networkError && record == null) {
              await SyncQueue.enqueue('fournisseur', 'CREATE', createPayload);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('fournisseursPages.enregistreHorsLigne')), duration: const Duration(seconds: 4)));
                Navigator.pop(c);
              }
              onSaved();
            } else {
              setD(() { saving = false; formError = '$e'; });
            }
          } catch (e) { setD(() { saving = false; formError = '$e'; }); }
        }, child: Text(saving ? '…' : t('fournisseursPages.enregistrer'))),
      ],
    )),
  );
}

// --- Fiche 360° ---
class FournisseurDetailPage extends StatefulWidget {
  final String fournisseurId;
  const FournisseurDetailPage({super.key, required this.fournisseurId});
  @override
  State<FournisseurDetailPage> createState() => _FournisseurDetailPageState();
}

class _FournisseurDetailPageState extends State<FournisseurDetailPage> {
  final api = Api();
  Map? f;
  Map? score;
  bool loading = true;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      f = Map.from(await api.get('/business/fournisseurs/${widget.fournisseurId}'));
      score = Map.from(await api.get('/business/fournisseurs/${widget.fournisseurId}/score'));
    } catch (_) {}
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (loading || f == null || score == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final scoreValue = score!['score'];
    final scoreColor = scoreValue == null ? QhseColors.textPrimary : scoreValue >= 85 ? QhseColors.green : scoreValue >= 70 ? QhseColors.amber : QhseColors.red;
    final ncOuvertes = List.from(f!['nonConformities'] ?? []).where((n) => n['status'] == 'OPEN').length;
    final actionsOuvertes = List.from(f!['actions'] ?? []).where((a) => a['status'] != 'CLOSED').length;

    return Scaffold(
      appBar: AppBar(
        title: Text(f!['nom'] ?? ''),
        actions: [IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => showFournisseurDialog(context, api, record: f, onSaved: load))],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(scoreValue != null ? '$scoreValue/100' : '—', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 32, color: scoreColor)),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(kFournisseurStatutLabels[f!['statut']] ?? f!['statut'] ?? '', style: const TextStyle(fontSize: 12)),
              if (f!['criticite'] == true) Text(t('fournisseursPages.critique'), style: TextStyle(color: QhseColors.red, fontSize: 11, fontWeight: FontWeight.bold)),
            ]),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: List.from(score!['detail'] ?? []).map<Widget>((d) => Chip(label: Text('${d['nom']} : ${d['valeur'] ?? '—'}${d['valeur'] != null ? '%' : ''}', style: const TextStyle(fontSize: 11)))).toList()),
        ]))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(10), child: Column(children: [Text('$ncOuvertes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: ncOuvertes > 0 ? QhseColors.red : QhseColors.textPrimary)), Text(t('fournisseursPages.ncOuvertes'), style: const TextStyle(fontSize: 11))])))),
          const SizedBox(width: 8),
          Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(10), child: Column(children: [Text('$actionsOuvertes', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), Text(t('fournisseursPages.actionsOuvertes'), style: const TextStyle(fontSize: 11))])))),
          const SizedBox(width: 8),
          Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(10), child: Column(children: [Text('${List.from(f!['certifications'] ?? []).length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), Text(t('fournisseursPages.certifications'), style: const TextStyle(fontSize: 11))])))),
        ]),
        const SizedBox(height: 16),
        if (f!['capaciteTechnique'] != null) ...[Text(t('fournisseursPages.capaciteTechniqueLigne', {'valeur': '${f!['capaciteTechnique']}'}), style: const TextStyle(fontSize: 12)), const SizedBox(height: 6)],
        if (f!['capaciteCommerciale'] != null) ...[Text(t('fournisseursPages.capaciteCommercialeLigne', {'valeur': '${f!['capaciteCommerciale']}'}), style: const TextStyle(fontSize: 12)), const SizedBox(height: 6)],
        if (f!['situationFinanciere'] != null) ...[Text(t('fournisseursPages.situationFinanciereLigne', {'valeur': '${f!['situationFinanciere']}'}), style: const TextStyle(fontSize: 12)), const SizedBox(height: 6)],
        if (List.from(f!['nonConformities'] ?? []).isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(t('fournisseursPages.nonConformitesRecentes'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ...List.from(f!['nonConformities']).take(5).map((n) => Card(child: ListTile(dense: true, title: Text(n['title'] ?? ''), trailing: Text(n['status'] ?? '', style: const TextStyle(fontSize: 11))))),
        ],
        if (List.from(f!['actions'] ?? []).isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(t('fournisseursPages.actions'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ...List.from(f!['actions']).take(5).map((a) => Card(child: ListTile(dense: true, title: Text(a['title'] ?? ''), trailing: Text(a['status'] ?? '', style: const TextStyle(fontSize: 11))))),
        ],
        const SizedBox(height: 20),
        CapaLinksSection(sourceModule: 'FOURNISSEUR', sourceEntityId: f!['id'], prefill: {'title': t('fournisseursPages.planDeProgres', {'nom': '${f!['nom'] ?? ''}'}), 'source': 'FOURNISSEUR'}),
      ]),
    );
  }
}
