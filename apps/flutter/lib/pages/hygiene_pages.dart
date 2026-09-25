import 'package:flutter/material.dart';
import '../services/api.dart';
import '../services/sync_queue.dart';
import '../theme.dart';
import '../i18n/i18n.dart';
import 'load_error_view.dart';

Color _niveauColor(String? n) => {'CRITIQUE': QhseColors.red, 'URGENT': QhseColors.red, 'ATTENTION': QhseColors.amber}[n] ?? QhseColors.textSecondary;
Color _criticiteColor(int c) => c >= 12 ? QhseColors.red : c >= 6 ? QhseColors.amber : QhseColors.green;
String _criticiteLabel(int c) => c >= 12 ? t('hygienePagesFlt.criticiteCritique') : c >= 6 ? t('hygienePagesFlt.criticiteElevee') : t('hygienePagesFlt.criticiteFaibleModere');
Map<String, String> get _scoreErgoLabel => {'FAIBLE': t('hygienePagesFlt.scoreErgoFaible'), 'MODERE': t('hygienePagesFlt.scoreErgoModere'), 'ELEVE': t('hygienePagesFlt.scoreErgoEleve'), 'CRITIQUE': t('hygienePagesFlt.scoreErgoCritique')};
Color _scoreErgoColor(String? s) => {'FAIBLE': QhseColors.green, 'MODERE': QhseColors.amber, 'ELEVE': QhseColors.red, 'CRITIQUE': QhseColors.red}[s] ?? QhseColors.textSecondary;

// --- Écran principal à 4 onglets ---
class HygieneHome extends StatefulWidget {
  const HygieneHome({super.key});
  @override
  State<HygieneHome> createState() => _HygieneHomeState();
}

class _HygieneHomeState extends State<HygieneHome> with SingleTickerProviderStateMixin {
  final api = Api();
  List visites = [], risques = [], ergonomies = [], tms = [], alertes = [], facteurs = [], expositions = [];
  Map indice = {'indice': null, 'detail': []};
  bool loading = true;
  Object? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      visites = List.from(await api.get('/business/visites-medicales'));
      risques = List.from(await api.get('/business/risques-sanitaires'));
      ergonomies = List.from(await api.get('/business/analyses-ergonomiques'));
      tms = List.from(await api.get('/business/tms-signalements'));
      alertes = List.from(await api.get('/business/hygiene-alertes'));
      indice = Map.from(await api.get('/business/hygiene-indice-global'));
      facteurs = List.from(await api.get('/business/penibilite-facteurs'));
      expositions = List.from(await api.get('/business/penibilite-expositions'));
    } catch (e) { error = e; }
    setState(() => loading = false);
  }

  Future<void> _creerFacteur(BuildContext context) async {
    final ctrl = TextEditingController();
    await showDialog(context: context, builder: (c) => AlertDialog(
      title: Text(t('hygienePagesFlt.dialogNouveauFacteur')),
      content: TextField(controller: ctrl, decoration: InputDecoration(labelText: t('hygienePagesFlt.champNomFacteur'))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(t('hygienePagesFlt.annuler'))),
        FilledButton(onPressed: () async {
          if (ctrl.text.trim().isEmpty) return;
          try { await api.post('/business/penibilite-facteurs', {'nom': ctrl.text.trim()}); if (context.mounted) Navigator.pop(c); load(); }
          catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
        }, child: Text(t('hygienePagesFlt.ajouter'))),
      ],
    ));
  }

  Future<void> _enregistrerExposition(BuildContext context) async {
    if (facteurs.isEmpty) return;
    String facteurId = facteurs.first['id'];
    final poste = TextEditingController();
    final niveau = TextEditingController();
    await showDialog(context: context, builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
      title: Text(t('hygienePagesFlt.dialogEnregistrerExposition')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(
          value: facteurId, isExpanded: true,
          items: facteurs.map<DropdownMenuItem<String>>((f) => DropdownMenuItem(value: f['id'] as String, child: Text(f['nom']))).toList(),
          onChanged: (v) => setD(() => facteurId = v!),
          decoration: InputDecoration(labelText: t('hygienePagesFlt.champFacteur')),
        ),
        TextField(controller: poste, decoration: InputDecoration(labelText: t('hygienePagesFlt.champPoste'))),
        TextField(controller: niveau, decoration: InputDecoration(labelText: t('hygienePagesFlt.champNiveauExposition'))),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(t('hygienePagesFlt.annuler'))),
        FilledButton(onPressed: () async {
          try {
            await api.post('/business/penibilite-expositions', {'facteurId': facteurId, 'poste': poste.text.isEmpty ? null : poste.text, 'niveauExposition': niveau.text.isEmpty ? null : niveau.text});
            if (context.mounted) Navigator.pop(c);
            load();
          } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
        }, child: Text(t('hygienePagesFlt.enregistrer'))),
      ],
    )));
  }

  @override
  Widget build(BuildContext c) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('hygienePagesFlt.titre')),
          bottom: TabBar(isScrollable: true, tabs: [Tab(text: t('hygienePagesFlt.ongletMedecine')), Tab(text: t('hygienePagesFlt.ongletRisques')), Tab(text: t('hygienePagesFlt.ongletErgonomie')), Tab(text: t('hygienePagesFlt.ongletPilotage'))]),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? LoadErrorView(error: error, onRetry: load)
            : TabBarView(children: [
                _buildMedecine(c),
                _buildRisques(c),
                _buildErgonomie(c),
                _buildPilotage(c),
              ]),
      ),
    );
  }

  Widget _buildMedecine(BuildContext c) {
    final now = DateTime.now();
    final enRetard = visites.where((v) => v['prochaineVisite'] != null && DateTime.parse(v['prochaineVisite']).isBefore(now)).length;
    final avecReserves = visites.where((v) => v['aptitude'] == 'Apte avec réserves').length;
    final inaptes = visites.where((v) => v['aptitude'] == 'Inapte').length;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(onPressed: () => showVisiteMedicaleDialog(c, api, onSaved: load), icon: const Icon(Icons.add), label: Text(t('hygienePagesFlt.fabVisite'))),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(padding: const EdgeInsets.all(12), children: [
          KpiBar([
            KpiStat(t('hygienePagesFlt.kpiVisites'), '${visites.length}', color: QhseColors.blue, icon: Icons.favorite_outline),
            KpiStat(t('hygienePagesFlt.kpiEnRetard'), '$enRetard', color: QhseColors.red, icon: Icons.warning_amber_outlined),
            KpiStat(t('hygienePagesFlt.kpiAvecReserves'), '$avecReserves', color: QhseColors.amber, icon: Icons.info_outline),
            KpiStat(t('hygienePagesFlt.kpiInaptes'), '$inaptes', color: QhseColors.red, icon: Icons.block),
          ]),
          const SizedBox(height: 12),
          if (visites.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(t('hygienePagesFlt.aucuneVisite'), style: TextStyle(color: QhseColors.textSecondary))))
          else ...visites.map((v) {
            final late = v['prochaineVisite'] != null && DateTime.parse(v['prochaineVisite']).isBefore(now);
            return Card(child: ListTile(
              title: Text(v['employeNom'] ?? ''),
              subtitle: Text('${v['poste'] ?? ''} • ${v['aptitude'] ?? t('hygienePagesFlt.aptitudeNonRenseignee')}'),
              trailing: v['prochaineVisite'] != null ? Text(DateTime.parse(v['prochaineVisite']).toString().substring(0, 10), style: TextStyle(color: late ? QhseColors.red : QhseColors.green, fontSize: 11)) : null,
              onTap: () => showVisiteMedicaleDialog(c, api, record: v, onSaved: load),
            ));
          }),
        ]),
      ),
    );
  }

  Widget _buildRisques(BuildContext c) {
    final critiques = risques.where((r) => (r['criticite'] ?? 0) >= 12 && r['statut'] == 'ACTIVE').length;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(onPressed: () => showRisqueSanitaireDialog(c, api, onSaved: load), icon: const Icon(Icons.add), label: Text(t('hygienePagesFlt.fabEvaluerRisque'))),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(padding: const EdgeInsets.all(12), children: [
          KpiBar([
            KpiStat(t('hygienePagesFlt.kpiRisques'), '${risques.length}', color: QhseColors.blue, icon: Icons.health_and_safety_outlined),
            KpiStat(t('hygienePagesFlt.kpiCritiques'), '$critiques', color: critiques > 0 ? QhseColors.red : QhseColors.green, icon: Icons.warning_amber_outlined),
            KpiStat(t('hygienePagesFlt.kpiPersonnesExposees'), '${risques.fold<int>(0, (s, r) => s + ((r['nombrePersonnesExposees'] ?? 0) as int))}', color: QhseColors.amber, icon: Icons.people_outline),
          ]),
          const SizedBox(height: 12),
          if (risques.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(t('hygienePagesFlt.aucunRisque'), style: TextStyle(color: QhseColors.textSecondary))))
          else ...risques.map((r) => Card(child: ListTile(
                leading: Icon(Icons.circle, size: 12, color: _criticiteColor(r['criticite'] ?? 1)),
                title: Text(r['danger'] ?? ''),
                subtitle: Text('${r['categorie'] ?? ''} • ${[r['poste'], r['zone']].where((x) => x != null).join(' / ')}'),
                trailing: Text('${r['criticite']} (${_criticiteLabel(r['criticite'] ?? 1)})', style: TextStyle(color: _criticiteColor(r['criticite'] ?? 1), fontWeight: FontWeight.bold, fontSize: 11)),
                onTap: () => showRisqueSanitaireDialog(c, api, record: r, onSaved: load),
              ))),
        ]),
      ),
    );
  }

  Widget _buildErgonomie(BuildContext c) {
    final parZone = <String, int>{};
    for (final tk in tms) { final z = tk['zoneCorporelle'] ?? 'Autre'; parZone[z] = (parZone[z] ?? 0) + 1; }
    return Scaffold(
      floatingActionButton: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        FloatingActionButton.extended(heroTag: 'tms', onPressed: () => showTmsSignalementDialog(c, api, onSaved: load), icon: const Icon(Icons.accessibility_new), label: Text(t('hygienePagesFlt.fabTms')), backgroundColor: QhseColors.amber),
        const SizedBox(width: 10),
        FloatingActionButton.extended(heroTag: 'ergo', onPressed: () => showAnalyseErgonomiqueDialog(c, api, onSaved: load), icon: const Icon(Icons.add), label: Text(t('hygienePagesFlt.fabPoste'))),
      ]),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(padding: const EdgeInsets.all(12), children: [
          KpiBar([
            KpiStat(t('hygienePagesFlt.kpiPostesAnalyses'), '${ergonomies.length}', color: QhseColors.blue, icon: Icons.chair_alt_outlined),
            KpiStat(t('hygienePagesFlt.kpiCritiquesElevees'), '${ergonomies.where((e) => ['ELEVE', 'CRITIQUE'].contains(e['scoreErgonomique'])).length}', color: QhseColors.red, icon: Icons.warning_amber_outlined),
            KpiStat(t('hygienePagesFlt.kpiSignalementsTms'), '${tms.length}', color: QhseColors.amber, icon: Icons.healing_outlined),
          ]),
          const SizedBox(height: 12),
          Text(t('hygienePagesFlt.analysesErgonomiques'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          if (ergonomies.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(t('hygienePagesFlt.aucunPosteAnalyse'), style: TextStyle(color: QhseColors.textSecondary)))
          else ...ergonomies.map((e) => Card(child: ListTile(
                title: Text(e['poste'] ?? ''),
                trailing: Text(_scoreErgoLabel[e['scoreErgonomique']] ?? '', style: TextStyle(color: _scoreErgoColor(e['scoreErgonomique']), fontWeight: FontWeight.bold)),
                onTap: () => showAnalyseErgonomiqueDialog(c, api, record: e, onSaved: load),
              ))),
          const SizedBox(height: 16),
          Text(t('hygienePagesFlt.sectionSignalementsTms'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          if (parZone.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Wrap(spacing: 8, runSpacing: 6, children: parZone.entries.map((e) => Chip(label: Text('${e.key} : ${e.value}'))).toList())),
          if (tms.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(t('hygienePagesFlt.aucunSignalement'), style: TextStyle(color: QhseColors.textSecondary)))
          else ...tms.map((tk) => Card(child: ListTile(
                dense: true,
                title: Text('${tk['zoneCorporelle']} — ${tk['poste'] ?? '—'}'),
                subtitle: Text((tk['dateSignalement'] ?? '').toString().substring(0, 10)),
                trailing: Text(tk['statut'] ?? '', style: const TextStyle(fontSize: 11)),
                onTap: () => showTmsSignalementDialog(c, api, record: tk, onSaved: load),
              ))),
        ]),
      ),
    );
  }

  Widget _buildPilotage(BuildContext c) {
    final indiceValue = indice['indice'];
    final indiceColor = indiceValue == null ? QhseColors.textPrimary : indiceValue >= 90 ? QhseColors.green : indiceValue >= 75 ? QhseColors.green : indiceValue >= 60 ? QhseColors.amber : QhseColors.red;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(padding: const EdgeInsets.all(12), children: [
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('hygienePagesFlt.indiceTitre'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Text(indiceValue != null ? '$indiceValue/100' : '—', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 32, color: indiceColor)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: List.from(indice['detail'] ?? []).map<Widget>((d) => Chip(label: Text('${d['nom']} : ${d['valeur'] ?? '—'}${d['valeur'] != null ? '%' : ''}', style: const TextStyle(fontSize: 11)))).toList()),
        ]))),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(t('hygienePagesFlt.alertesAutomatiques'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          Text('${alertes.length}', style: TextStyle(color: QhseColors.textSecondary)),
        ]),
        const SizedBox(height: 6),
        if (alertes.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(t('hygienePagesFlt.aucuneAlerte'), style: TextStyle(color: QhseColors.green)))
        else ...alertes.map((a) => Card(child: ListTile(
              dense: true,
              title: Text(a['label'] ?? ''),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: _niveauColor(a['niveau']).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: Text(a['niveau'] ?? '', style: TextStyle(color: _niveauColor(a['niveau']), fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ))),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(t('hygienePagesFlt.penibilite'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          Row(children: [
            TextButton(onPressed: () => _creerFacteur(c), child: Text(t('hygienePagesFlt.plusFacteur'))),
            if (facteurs.isNotEmpty) TextButton(onPressed: () => _enregistrerExposition(c), child: Text(t('hygienePagesFlt.plusExposition'))),
          ]),
        ]),
        if (expositions.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(facteurs.isEmpty ? t('hygienePagesFlt.ajoutezFacteur') : t('hygienePagesFlt.aucuneExposition'), style: TextStyle(color: QhseColors.textSecondary)))
        else ...expositions.map((ex) => Card(child: ListTile(
              dense: true,
              title: Text(ex['facteur']?['nom'] ?? '—'),
              subtitle: Text(ex['poste'] ?? '—'),
              trailing: Text(ex['niveauExposition'] ?? '—', style: const TextStyle(fontSize: 11)),
            ))),
      ]),
    );
  }
}

// --- Formulaires ---
Future<void> showVisiteMedicaleDialog(BuildContext context, Api api, {Map? record, required VoidCallback onSaved}) async {
  final employeNom = TextEditingController(text: record?['employeNom'] ?? '');
  final poste = TextEditingController(text: record?['poste'] ?? '');
  final service = TextEditingController(text: record?['service'] ?? '');
  String? aptitude = record?['aptitude'];
  DateTime? prochaineVisite = record?['prochaineVisite'] != null ? DateTime.parse(record!['prochaineVisite']) : null;
  String? formError;
  bool saving = false;
  await showDialog(context: context, builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
    title: Text(record == null ? t('hygienePagesFlt.dialogNouvelleVisite') : t('hygienePagesFlt.dialogModifierVisite')),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: employeNom, decoration: InputDecoration(labelText: t('hygienePagesFlt.champEmploye'))),
      TextField(controller: poste, decoration: InputDecoration(labelText: t('hygienePagesFlt.champPosteVisite'))),
      TextField(controller: service, decoration: InputDecoration(labelText: t('hygienePagesFlt.champServiceOptionnel'))),
      DropdownButtonFormField<String>(
        value: aptitude, decoration: InputDecoration(labelText: t('hygienePagesFlt.champAptitude')),
        items: [DropdownMenuItem(value: 'Apte', child: Text(t('hygienePagesFlt.aptitudeApte'))), DropdownMenuItem(value: 'Apte avec réserves', child: Text(t('hygienePagesFlt.aptitudeApteReserves'))), DropdownMenuItem(value: 'Inapte', child: Text(t('hygienePagesFlt.aptitudeInapte')))],
        onChanged: (v) => setD(() => aptitude = v),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(prochaineVisite == null ? t('hygienePagesFlt.prochaineVisiteLabel') : t('hygienePagesFlt.prochaineVisiteAvecDate', {'date': '${prochaineVisite!.day}/${prochaineVisite!.month}/${prochaineVisite!.year}'})),
        trailing: const Icon(Icons.edit_calendar),
        onTap: () async { final d = await showDatePicker(context: context, initialDate: prochaineVisite ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2035)); if (d != null) setD(() => prochaineVisite = d); },
      ),
      if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
    ])),
    actions: [
      if (record != null) TextButton(onPressed: () async {
        try { await api.delete('/business/visites-medicales/${record['id']}'); if (context.mounted) Navigator.pop(c); onSaved(); }
        catch (e) { setD(() => formError = '$e'); }
      }, child: Text(t('hygienePagesFlt.supprimer'), style: const TextStyle(color: QhseColors.red))),
      TextButton(onPressed: () => Navigator.pop(c), child: Text(t('hygienePagesFlt.annuler'))),
      FilledButton(onPressed: saving ? null : () async {
        setD(() => saving = true);
        final payload = {'employeNom': employeNom.text, 'poste': poste.text, 'service': service.text.isEmpty ? null : service.text, 'aptitude': aptitude, 'prochaineVisite': prochaineVisite?.toIso8601String()};
        try {
          if (record != null) await api.patch('/business/visites-medicales/${record['id']}', payload);
          else await api.post('/business/visites-medicales', {'code': 'VM-${DateTime.now().millisecondsSinceEpoch}', ...payload});
          if (context.mounted) Navigator.pop(c);
          onSaved();
        } catch (e) { setD(() { saving = false; formError = '$e'; }); }
      }, child: Text(saving ? '…' : t('hygienePagesFlt.enregistrer'))),
    ],
  )));
}

Future<void> showRisqueSanitaireDialog(BuildContext context, Api api, {Map? record, required VoidCallback onSaved}) async {
  final danger = TextEditingController(text: record?['danger'] ?? '');
  final poste = TextEditingController(text: record?['poste'] ?? '');
  final zone = TextEditingController(text: record?['zone'] ?? '');
  final personnes = TextEditingController(text: record?['nombrePersonnesExposees']?.toString() ?? '');
  String? categorie = record?['categorie'];
  int gravite = record?['gravite'] ?? 1;
  int probabilite = record?['probabilite'] ?? 1;
  String? formError;
  bool saving = false;
  await showDialog(context: context, builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
    title: Text(record == null ? t('hygienePagesFlt.dialogNouveauRisque') : t('hygienePagesFlt.dialogModifierRisque')),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      DropdownButtonFormField<String>(
        value: categorie, isExpanded: true, decoration: InputDecoration(labelText: t('hygienePagesFlt.champCategorie')),
        items: [DropdownMenuItem(value: 'PHYSIQUE', child: Text(t('hygienePagesFlt.categoriePhysique'))), DropdownMenuItem(value: 'CHIMIQUE', child: Text(t('hygienePagesFlt.categorieChimique'))), DropdownMenuItem(value: 'BIOLOGIQUE', child: Text(t('hygienePagesFlt.categorieBiologique'))), DropdownMenuItem(value: 'CONDITIONS_TRAVAIL', child: Text(t('hygienePagesFlt.categorieConditionsTravail')))],
        onChanged: (v) => setD(() => categorie = v),
      ),
      TextField(controller: danger, decoration: InputDecoration(labelText: t('hygienePagesFlt.champDanger'))),
      TextField(controller: poste, decoration: InputDecoration(labelText: t('hygienePagesFlt.champPoste'))),
      TextField(controller: zone, decoration: InputDecoration(labelText: t('hygienePagesFlt.champZoneOptionnel'))),
      TextField(controller: personnes, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('hygienePagesFlt.champPersonnesExposees'))),
      Row(children: [
        Expanded(child: DropdownButtonFormField<int>(value: gravite, decoration: InputDecoration(labelText: t('hygienePagesFlt.champGravite')), items: [1, 2, 3, 4].map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(), onChanged: (v) => setD(() => gravite = v!))),
        const SizedBox(width: 8),
        Expanded(child: DropdownButtonFormField<int>(value: probabilite, decoration: InputDecoration(labelText: t('hygienePagesFlt.champProbabilite')), items: [1, 2, 3, 4].map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(), onChanged: (v) => setD(() => probabilite = v!))),
      ]),
      Padding(padding: const EdgeInsets.only(top: 6), child: Text(t('hygienePagesFlt.criticiteCalculee', {'value': '${gravite * probabilite}', 'label': _criticiteLabel(gravite * probabilite)}), style: TextStyle(color: _criticiteColor(gravite * probabilite), fontSize: 12))),
      if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
    ])),
    actions: [
      if (record != null) TextButton(onPressed: () async {
        try { await api.delete('/business/risques-sanitaires/${record['id']}'); if (context.mounted) Navigator.pop(c); onSaved(); }
        catch (e) { setD(() => formError = '$e'); }
      }, child: Text(t('hygienePagesFlt.supprimer'), style: const TextStyle(color: QhseColors.red))),
      TextButton(onPressed: () => Navigator.pop(c), child: Text(t('hygienePagesFlt.annuler'))),
      FilledButton(onPressed: saving ? null : () async {
        setD(() => saving = true);
        final payload = {'categorie': categorie, 'danger': danger.text, 'poste': poste.text.isEmpty ? null : poste.text, 'zone': zone.text.isEmpty ? null : zone.text, 'nombrePersonnesExposees': personnes.text.isEmpty ? null : int.tryParse(personnes.text), 'gravite': gravite, 'probabilite': probabilite};
        try {
          if (record != null) await api.patch('/business/risques-sanitaires/${record['id']}', payload);
          else await api.post('/business/risques-sanitaires', {'code': 'RS-${DateTime.now().millisecondsSinceEpoch}', ...payload});
          if (context.mounted) Navigator.pop(c);
          onSaved();
        } catch (e) { setD(() { saving = false; formError = '$e'; }); }
      }, child: Text(saving ? '…' : t('hygienePagesFlt.enregistrer'))),
    ],
  )));
}

const List<String> _facteursErgonomiques = ['stationDeboutProlongee', 'stationAssiseProlongee', 'travailRepetitif', 'manutentionChargesLourdes', 'posturesContraignantes', 'ecranInformatiquePosture', 'vibrations', 'eclairageInsuffisant', 'espaceInsuffisant'];
Map<String, String> get _facteursErgonomiquesLabels => {
  'stationDeboutProlongee': t('hygienePagesFlt.facteurStationDeboutProlongee'), 'stationAssiseProlongee': t('hygienePagesFlt.facteurStationAssiseProlongee'), 'travailRepetitif': t('hygienePagesFlt.facteurTravailRepetitif'),
  'manutentionChargesLourdes': t('hygienePagesFlt.facteurManutentionChargesLourdes'), 'posturesContraignantes': t('hygienePagesFlt.facteurPosturesContraignantes'), 'ecranInformatiquePosture': t('hygienePagesFlt.facteurEcranInformatiquePosture'),
  'vibrations': t('hygienePagesFlt.facteurVibrations'), 'eclairageInsuffisant': t('hygienePagesFlt.facteurEclairageInsuffisant'), 'espaceInsuffisant': t('hygienePagesFlt.facteurEspaceInsuffisant'),
};

const Map<String, String> _kZoneCorporelleKeys = {
  'Dos': 'hygienePagesFlt.zoneDos', 'Épaules': 'hygienePagesFlt.zoneEpaules', 'Cou': 'hygienePagesFlt.zoneCou',
  'Poignets': 'hygienePagesFlt.zonePoignets', 'Mains': 'hygienePagesFlt.zoneMains', 'Coudes': 'hygienePagesFlt.zoneCoudes',
  'Genoux': 'hygienePagesFlt.zoneGenoux', 'Jambes': 'hygienePagesFlt.zoneJambes', 'Pieds': 'hygienePagesFlt.zonePieds', 'Autre': 'hygienePagesFlt.zoneAutre',
};
String zoneCorporelleLabel(String z) => _kZoneCorporelleKeys.containsKey(z) ? t(_kZoneCorporelleKeys[z]!) : z;

Future<void> showAnalyseErgonomiqueDialog(BuildContext context, Api api, {Map? record, required VoidCallback onSaved}) async {
  final poste = TextEditingController(text: record?['poste'] ?? '');
  final zone = TextEditingController(text: record?['zone'] ?? '');
  final facteurs = <String, bool>{for (final f in _facteursErgonomiques) f: record?[f] ?? false};
  String? formError;
  bool saving = false;
  await showDialog(context: context, builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
    title: Text(record == null ? t('hygienePagesFlt.dialogAnalyserPoste') : t('hygienePagesFlt.dialogModifierAnalyse')),
    content: SizedBox(width: 340, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: poste, decoration: InputDecoration(labelText: t('hygienePagesFlt.champPoste'))),
      TextField(controller: zone, decoration: InputDecoration(labelText: t('hygienePagesFlt.champZoneOptionnel'))),
      Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(top: 8, bottom: 4), child: Text(t('hygienePagesFlt.facteursRisqueObserves'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
      ..._facteursErgonomiques.map((f) => CheckboxListTile(
            contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, dense: true,
            title: Text(_facteursErgonomiquesLabels[f]!, style: const TextStyle(fontSize: 12)),
            value: facteurs[f], onChanged: (v) => setD(() => facteurs[f] = v ?? false),
          )),
      Builder(builder: (context) {
        final count = facteurs.values.where((v) => v).length;
        final label = count >= 6 ? t('hygienePagesFlt.scoreErgoCritique') : count >= 4 ? t('hygienePagesFlt.scoreErgoEleve') : count >= 2 ? t('hygienePagesFlt.scoreErgoModere') : t('hygienePagesFlt.scoreErgoFaible');
        final color = count >= 4 ? QhseColors.red : count >= 2 ? QhseColors.amber : QhseColors.green;
        return Padding(padding: const EdgeInsets.only(top: 6), child: Text(t('hygienePagesFlt.scoreCalcule', {'label': label, 'count': '$count', 'suffix': count > 1 ? 's' : ''}), style: TextStyle(color: color, fontSize: 12)));
      }),
      if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
    ]))),
    actions: [
      if (record != null) TextButton(onPressed: () async {
        try { await api.delete('/business/analyses-ergonomiques/${record['id']}'); if (context.mounted) Navigator.pop(c); onSaved(); }
        catch (e) { setD(() => formError = '$e'); }
      }, child: Text(t('hygienePagesFlt.supprimer'), style: const TextStyle(color: QhseColors.red))),
      TextButton(onPressed: () => Navigator.pop(c), child: Text(t('hygienePagesFlt.annuler'))),
      FilledButton(onPressed: saving ? null : () async {
        setD(() => saving = true);
        final payload = {'poste': poste.text, 'zone': zone.text.isEmpty ? null : zone.text, ...facteurs};
        try {
          if (record != null) await api.patch('/business/analyses-ergonomiques/${record['id']}', payload);
          else await api.post('/business/analyses-ergonomiques', {'code': 'ERG-${DateTime.now().millisecondsSinceEpoch}', ...payload});
          if (context.mounted) Navigator.pop(c);
          onSaved();
        } catch (e) { setD(() { saving = false; formError = '$e'; }); }
      }, child: Text(saving ? '…' : t('hygienePagesFlt.enregistrer'))),
    ],
  )));
}

Future<void> showTmsSignalementDialog(BuildContext context, Api api, {Map? record, required VoidCallback onSaved}) async {
  String? zoneCorporelle = record?['zoneCorporelle'];
  final poste = TextEditingController(text: record?['poste'] ?? '');
  final activite = TextEditingController(text: record?['activite'] ?? '');
  String? formError;
  bool saving = false;
  await showDialog(context: context, builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
    title: Text(record == null ? t('hygienePagesFlt.dialogSignalerTms') : t('hygienePagesFlt.dialogModifierSignalement')),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      DropdownButtonFormField<String>(
        value: zoneCorporelle, decoration: InputDecoration(labelText: t('hygienePagesFlt.champZoneCorporelle')),
        items: ['Dos', 'Épaules', 'Cou', 'Poignets', 'Mains', 'Coudes', 'Genoux', 'Jambes', 'Pieds', 'Autre'].map((z) => DropdownMenuItem(value: z, child: Text(zoneCorporelleLabel(z)))).toList(),
        onChanged: (v) => setD(() => zoneCorporelle = v),
      ),
      TextField(controller: poste, decoration: InputDecoration(labelText: t('hygienePagesFlt.champPoste'))),
      TextField(controller: activite, decoration: InputDecoration(labelText: t('hygienePagesFlt.champActiviteOptionnel'))),
      if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
    ])),
    actions: [
      if (record != null) TextButton(onPressed: () async {
        try { await api.delete('/business/tms-signalements/${record['id']}'); if (context.mounted) Navigator.pop(c); onSaved(); }
        catch (e) { setD(() => formError = '$e'); }
      }, child: Text(t('hygienePagesFlt.supprimer'), style: const TextStyle(color: QhseColors.red))),
      TextButton(onPressed: () => Navigator.pop(c), child: Text(t('hygienePagesFlt.annuler'))),
      FilledButton(onPressed: saving ? null : () async {
        if (zoneCorporelle == null) { setD(() => formError = t('hygienePagesFlt.erreurZoneRequise')); return; }
        setD(() => saving = true);
        final payload = {'zoneCorporelle': zoneCorporelle, 'poste': poste.text.isEmpty ? null : poste.text, 'activite': activite.text.isEmpty ? null : activite.text};
        try {
          if (record != null) await api.patch('/business/tms-signalements/${record['id']}', payload);
          else await api.post('/business/tms-signalements', {'code': 'TMS-${DateTime.now().millisecondsSinceEpoch}', ...payload});
          if (context.mounted) Navigator.pop(c);
          onSaved();
        } on ApiException catch (e) {
          if (e.networkError && record == null) {
            await SyncQueue.enqueue('tmsSignalement', 'CREATE', {'code': 'TMS-${DateTime.now().millisecondsSinceEpoch}', ...payload});
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('hygienePagesFlt.messageHorsLigneTms')), duration: const Duration(seconds: 4)));
              Navigator.pop(c);
            }
            onSaved();
          } else {
            setD(() { saving = false; formError = '$e'; });
          }
        } catch (e) { setD(() { saving = false; formError = '$e'; }); }
      }, child: Text(saving ? '…' : t('hygienePagesFlt.enregistrer'))),
    ],
  )));
}
