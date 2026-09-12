import 'package:flutter/material.dart';
import '../services/api.dart';
import '../theme.dart';

Color _niveauColor(String? n) => {'CRITIQUE': QhseColors.red, 'URGENT': QhseColors.red, 'ATTENTION': QhseColors.amber}[n] ?? QhseColors.textSecondary;
Color _criticiteColor(int c) => c >= 12 ? QhseColors.red : c >= 6 ? QhseColors.amber : QhseColors.green;
String _criticiteLabel(int c) => c >= 12 ? 'Critique' : c >= 6 ? 'Élevé' : 'Faible/Modéré';
const Map<String, String> _scoreErgoLabel = {'FAIBLE': 'Faible', 'MODERE': 'Modéré', 'ELEVE': 'Élevé', 'CRITIQUE': 'Critique'};
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

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      visites = List.from(await api.get('/business/visites-medicales'));
      risques = List.from(await api.get('/business/risques-sanitaires'));
      ergonomies = List.from(await api.get('/business/analyses-ergonomiques'));
      tms = List.from(await api.get('/business/tms-signalements'));
      alertes = List.from(await api.get('/business/hygiene-alertes'));
      indice = Map.from(await api.get('/business/hygiene-indice-global'));
      facteurs = List.from(await api.get('/business/penibilite-facteurs'));
      expositions = List.from(await api.get('/business/penibilite-expositions'));
    } catch (_) {}
    setState(() => loading = false);
  }

  Future<void> _creerFacteur(BuildContext context) async {
    final ctrl = TextEditingController();
    await showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text('Nouveau facteur de pénibilité'),
      content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Nom du facteur')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
        FilledButton(onPressed: () async {
          if (ctrl.text.trim().isEmpty) return;
          try { await api.post('/business/penibilite-facteurs', {'nom': ctrl.text.trim()}); if (context.mounted) Navigator.pop(c); load(); }
          catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
        }, child: const Text('Ajouter')),
      ],
    ));
  }

  Future<void> _enregistrerExposition(BuildContext context) async {
    if (facteurs.isEmpty) return;
    String facteurId = facteurs.first['id'];
    final poste = TextEditingController();
    final niveau = TextEditingController();
    await showDialog(context: context, builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
      title: const Text('Enregistrer une exposition'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(
          value: facteurId, isExpanded: true,
          items: facteurs.map<DropdownMenuItem<String>>((f) => DropdownMenuItem(value: f['id'] as String, child: Text(f['nom']))).toList(),
          onChanged: (v) => setD(() => facteurId = v!),
          decoration: const InputDecoration(labelText: 'Facteur'),
        ),
        TextField(controller: poste, decoration: const InputDecoration(labelText: 'Poste (optionnel)')),
        TextField(controller: niveau, decoration: const InputDecoration(labelText: "Niveau d'exposition (optionnel)")),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
        FilledButton(onPressed: () async {
          try {
            await api.post('/business/penibilite-expositions', {'facteurId': facteurId, 'poste': poste.text.isEmpty ? null : poste.text, 'niveauExposition': niveau.text.isEmpty ? null : niveau.text});
            if (context.mounted) Navigator.pop(c);
            load();
          } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
        }, child: const Text('Enregistrer')),
      ],
    )));
  }

  @override
  Widget build(BuildContext c) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Hygiène au travail'),
          bottom: const TabBar(isScrollable: true, tabs: [Tab(text: 'Médecine du travail'), Tab(text: 'Risques sanitaires'), Tab(text: 'Ergonomie & TMS'), Tab(text: 'Pilotage')]),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
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
      floatingActionButton: FloatingActionButton.extended(onPressed: () => showVisiteMedicaleDialog(c, api, onSaved: load), icon: const Icon(Icons.add), label: const Text('Visite')),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(padding: const EdgeInsets.all(12), children: [
          KpiBar([
            KpiStat('Visites', '${visites.length}', color: QhseColors.blue, icon: Icons.favorite_outline),
            KpiStat('En retard', '$enRetard', color: QhseColors.red, icon: Icons.warning_amber_outlined),
            KpiStat('Avec réserves', '$avecReserves', color: QhseColors.amber, icon: Icons.info_outline),
            KpiStat('Inaptes', '$inaptes', color: QhseColors.red, icon: Icons.block),
          ]),
          const SizedBox(height: 12),
          if (visites.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('Aucune visite enregistrée', style: TextStyle(color: QhseColors.textSecondary))))
          else ...visites.map((v) {
            final late = v['prochaineVisite'] != null && DateTime.parse(v['prochaineVisite']).isBefore(now);
            return Card(child: ListTile(
              title: Text(v['employeNom'] ?? ''),
              subtitle: Text('${v['poste'] ?? ''} • ${v['aptitude'] ?? 'Aptitude non renseignée'}'),
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
      floatingActionButton: FloatingActionButton.extended(onPressed: () => showRisqueSanitaireDialog(c, api, onSaved: load), icon: const Icon(Icons.add), label: const Text('Évaluer un risque')),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(padding: const EdgeInsets.all(12), children: [
          KpiBar([
            KpiStat('Risques', '${risques.length}', color: QhseColors.blue, icon: Icons.health_and_safety_outlined),
            KpiStat('Critiques', '$critiques', color: critiques > 0 ? QhseColors.red : QhseColors.green, icon: Icons.warning_amber_outlined),
            KpiStat('Personnes exposées', '${risques.fold<int>(0, (s, r) => s + ((r['nombrePersonnesExposees'] ?? 0) as int))}', color: QhseColors.amber, icon: Icons.people_outline),
          ]),
          const SizedBox(height: 12),
          if (risques.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('Aucun risque sanitaire évalué', style: TextStyle(color: QhseColors.textSecondary))))
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
    for (final t in tms) { final z = t['zoneCorporelle'] ?? 'Autre'; parZone[z] = (parZone[z] ?? 0) + 1; }
    return Scaffold(
      floatingActionButton: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        FloatingActionButton.extended(heroTag: 'tms', onPressed: () => showTmsSignalementDialog(c, api, onSaved: load), icon: const Icon(Icons.accessibility_new), label: const Text('TMS'), backgroundColor: QhseColors.amber),
        const SizedBox(width: 10),
        FloatingActionButton.extended(heroTag: 'ergo', onPressed: () => showAnalyseErgonomiqueDialog(c, api, onSaved: load), icon: const Icon(Icons.add), label: const Text('Poste')),
      ]),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(padding: const EdgeInsets.all(12), children: [
          KpiBar([
            KpiStat('Postes analysés', '${ergonomies.length}', color: QhseColors.blue, icon: Icons.chair_alt_outlined),
            KpiStat('Critiques/élevés', '${ergonomies.where((e) => ['ELEVE', 'CRITIQUE'].contains(e['scoreErgonomique'])).length}', color: QhseColors.red, icon: Icons.warning_amber_outlined),
            KpiStat('Signalements TMS', '${tms.length}', color: QhseColors.amber, icon: Icons.healing_outlined),
          ]),
          const SizedBox(height: 12),
          const Text('Analyses ergonomiques', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          if (ergonomies.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Aucun poste analysé', style: TextStyle(color: QhseColors.textSecondary)))
          else ...ergonomies.map((e) => Card(child: ListTile(
                title: Text(e['poste'] ?? ''),
                trailing: Text(_scoreErgoLabel[e['scoreErgonomique']] ?? '', style: TextStyle(color: _scoreErgoColor(e['scoreErgonomique']), fontWeight: FontWeight.bold)),
                onTap: () => showAnalyseErgonomiqueDialog(c, api, record: e, onSaved: load),
              ))),
          const SizedBox(height: 16),
          const Text('Signalements TMS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          if (parZone.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Wrap(spacing: 8, runSpacing: 6, children: parZone.entries.map((e) => Chip(label: Text('${e.key} : ${e.value}'))).toList())),
          if (tms.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Aucun signalement', style: TextStyle(color: QhseColors.textSecondary)))
          else ...tms.map((t) => Card(child: ListTile(
                dense: true,
                title: Text('${t['zoneCorporelle']} — ${t['poste'] ?? '—'}'),
                subtitle: Text((t['dateSignalement'] ?? '').toString().substring(0, 10)),
                trailing: Text(t['statut'] ?? '', style: const TextStyle(fontSize: 11)),
                onTap: () => showTmsSignalementDialog(c, api, record: t, onSaved: load),
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
          const Text('Indice Hygiène au travail', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Text(indiceValue != null ? '$indiceValue/100' : '—', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 32, color: indiceColor)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: List.from(indice['detail'] ?? []).map<Widget>((d) => Chip(label: Text('${d['nom']} : ${d['valeur'] ?? '—'}${d['valeur'] != null ? '%' : ''}', style: const TextStyle(fontSize: 11)))).toList()),
        ]))),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Alertes automatiques', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          Text('${alertes.length}', style: TextStyle(color: QhseColors.textSecondary)),
        ]),
        const SizedBox(height: 6),
        if (alertes.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Aucune alerte — tout est sous contrôle', style: TextStyle(color: QhseColors.green)))
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
          const Text('Pénibilité', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          Row(children: [
            TextButton(onPressed: () => _creerFacteur(c), child: const Text('+ Facteur')),
            if (facteurs.isNotEmpty) TextButton(onPressed: () => _enregistrerExposition(c), child: const Text('+ Exposition')),
          ]),
        ]),
        if (expositions.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(facteurs.isEmpty ? 'Ajoutez un facteur de pénibilité pour commencer' : 'Aucune exposition enregistrée', style: TextStyle(color: QhseColors.textSecondary)))
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
    title: Text(record == null ? 'Nouvelle visite médicale' : 'Modifier la visite'),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: employeNom, decoration: const InputDecoration(labelText: 'Employé')),
      TextField(controller: poste, decoration: const InputDecoration(labelText: 'Poste')),
      TextField(controller: service, decoration: const InputDecoration(labelText: 'Service (optionnel)')),
      DropdownButtonFormField<String>(
        value: aptitude, decoration: const InputDecoration(labelText: 'Aptitude'),
        items: const [DropdownMenuItem(value: 'Apte', child: Text('Apte')), DropdownMenuItem(value: 'Apte avec réserves', child: Text('Apte avec réserves')), DropdownMenuItem(value: 'Inapte', child: Text('Inapte'))],
        onChanged: (v) => setD(() => aptitude = v),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(prochaineVisite == null ? 'Prochaine visite' : 'Prochaine visite : ${prochaineVisite!.day}/${prochaineVisite!.month}/${prochaineVisite!.year}'),
        trailing: const Icon(Icons.edit_calendar),
        onTap: () async { final d = await showDatePicker(context: context, initialDate: prochaineVisite ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2035)); if (d != null) setD(() => prochaineVisite = d); },
      ),
      if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
    ])),
    actions: [
      if (record != null) TextButton(onPressed: () async {
        try { await api.delete('/business/visites-medicales/${record['id']}'); if (context.mounted) Navigator.pop(c); onSaved(); }
        catch (e) { setD(() => formError = '$e'); }
      }, child: const Text('Supprimer', style: TextStyle(color: QhseColors.red))),
      TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
      FilledButton(onPressed: saving ? null : () async {
        setD(() => saving = true);
        final payload = {'employeNom': employeNom.text, 'poste': poste.text, 'service': service.text.isEmpty ? null : service.text, 'aptitude': aptitude, 'prochaineVisite': prochaineVisite?.toIso8601String()};
        try {
          if (record != null) await api.patch('/business/visites-medicales/${record['id']}', payload);
          else await api.post('/business/visites-medicales', {'code': 'VM-${DateTime.now().millisecondsSinceEpoch}', ...payload});
          if (context.mounted) Navigator.pop(c);
          onSaved();
        } catch (e) { setD(() { saving = false; formError = '$e'; }); }
      }, child: Text(saving ? '…' : 'Enregistrer')),
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
    title: Text(record == null ? 'Nouveau risque sanitaire' : 'Modifier le risque'),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      DropdownButtonFormField<String>(
        value: categorie, isExpanded: true, decoration: const InputDecoration(labelText: 'Catégorie'),
        items: const [DropdownMenuItem(value: 'PHYSIQUE', child: Text('Physique')), DropdownMenuItem(value: 'CHIMIQUE', child: Text('Chimique')), DropdownMenuItem(value: 'BIOLOGIQUE', child: Text('Biologique')), DropdownMenuItem(value: 'CONDITIONS_TRAVAIL', child: Text('Conditions de travail'))],
        onChanged: (v) => setD(() => categorie = v),
      ),
      TextField(controller: danger, decoration: const InputDecoration(labelText: 'Danger')),
      TextField(controller: poste, decoration: const InputDecoration(labelText: 'Poste (optionnel)')),
      TextField(controller: zone, decoration: const InputDecoration(labelText: 'Zone (optionnel)')),
      TextField(controller: personnes, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Personnes exposées (optionnel)')),
      Row(children: [
        Expanded(child: DropdownButtonFormField<int>(value: gravite, decoration: const InputDecoration(labelText: 'Gravité'), items: [1, 2, 3, 4].map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(), onChanged: (v) => setD(() => gravite = v!))),
        const SizedBox(width: 8),
        Expanded(child: DropdownButtonFormField<int>(value: probabilite, decoration: const InputDecoration(labelText: 'Probabilité'), items: [1, 2, 3, 4].map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(), onChanged: (v) => setD(() => probabilite = v!))),
      ]),
      Padding(padding: const EdgeInsets.only(top: 6), child: Text('Criticité calculée : ${gravite * probabilite} (${_criticiteLabel(gravite * probabilite)})', style: TextStyle(color: _criticiteColor(gravite * probabilite), fontSize: 12))),
      if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
    ])),
    actions: [
      if (record != null) TextButton(onPressed: () async {
        try { await api.delete('/business/risques-sanitaires/${record['id']}'); if (context.mounted) Navigator.pop(c); onSaved(); }
        catch (e) { setD(() => formError = '$e'); }
      }, child: const Text('Supprimer', style: TextStyle(color: QhseColors.red))),
      TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
      FilledButton(onPressed: saving ? null : () async {
        setD(() => saving = true);
        final payload = {'categorie': categorie, 'danger': danger.text, 'poste': poste.text.isEmpty ? null : poste.text, 'zone': zone.text.isEmpty ? null : zone.text, 'nombrePersonnesExposees': personnes.text.isEmpty ? null : int.tryParse(personnes.text), 'gravite': gravite, 'probabilite': probabilite};
        try {
          if (record != null) await api.patch('/business/risques-sanitaires/${record['id']}', payload);
          else await api.post('/business/risques-sanitaires', {'code': 'RS-${DateTime.now().millisecondsSinceEpoch}', ...payload});
          if (context.mounted) Navigator.pop(c);
          onSaved();
        } catch (e) { setD(() { saving = false; formError = '$e'; }); }
      }, child: Text(saving ? '…' : 'Enregistrer')),
    ],
  )));
}

const List<String> _facteursErgonomiques = ['stationDeboutProlongee', 'stationAssiseProlongee', 'travailRepetitif', 'manutentionChargesLourdes', 'posturesContraignantes', 'ecranInformatiquePosture', 'vibrations', 'eclairageInsuffisant', 'espaceInsuffisant'];
const Map<String, String> _facteursErgonomiquesLabels = {
  'stationDeboutProlongee': 'Station debout prolongée', 'stationAssiseProlongee': 'Station assise prolongée', 'travailRepetitif': 'Travail répétitif',
  'manutentionChargesLourdes': 'Manutention de charges lourdes', 'posturesContraignantes': 'Postures contraignantes', 'ecranInformatiquePosture': 'Poste écran mal positionné',
  'vibrations': 'Vibrations', 'eclairageInsuffisant': 'Éclairage insuffisant', 'espaceInsuffisant': 'Espace insuffisant',
};

Future<void> showAnalyseErgonomiqueDialog(BuildContext context, Api api, {Map? record, required VoidCallback onSaved}) async {
  final poste = TextEditingController(text: record?['poste'] ?? '');
  final zone = TextEditingController(text: record?['zone'] ?? '');
  final facteurs = <String, bool>{for (final f in _facteursErgonomiques) f: record?[f] ?? false};
  String? formError;
  bool saving = false;
  await showDialog(context: context, builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
    title: Text(record == null ? 'Analyser un poste' : "Modifier l'analyse"),
    content: SizedBox(width: 340, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: poste, decoration: const InputDecoration(labelText: 'Poste')),
      TextField(controller: zone, decoration: const InputDecoration(labelText: 'Zone (optionnel)')),
      const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.only(top: 8, bottom: 4), child: Text('Facteurs de risque observés', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
      ..._facteursErgonomiques.map((f) => CheckboxListTile(
            contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, dense: true,
            title: Text(_facteursErgonomiquesLabels[f]!, style: const TextStyle(fontSize: 12)),
            value: facteurs[f], onChanged: (v) => setD(() => facteurs[f] = v ?? false),
          )),
      Builder(builder: (context) {
        final count = facteurs.values.where((v) => v).length;
        final label = count >= 6 ? 'Critique' : count >= 4 ? 'Élevé' : count >= 2 ? 'Modéré' : 'Faible';
        final color = count >= 4 ? QhseColors.red : count >= 2 ? QhseColors.amber : QhseColors.green;
        return Padding(padding: const EdgeInsets.only(top: 6), child: Text('Score calculé : $label ($count facteur${count > 1 ? 's' : ''})', style: TextStyle(color: color, fontSize: 12)));
      }),
      if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
    ]))),
    actions: [
      if (record != null) TextButton(onPressed: () async {
        try { await api.delete('/business/analyses-ergonomiques/${record['id']}'); if (context.mounted) Navigator.pop(c); onSaved(); }
        catch (e) { setD(() => formError = '$e'); }
      }, child: const Text('Supprimer', style: TextStyle(color: QhseColors.red))),
      TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
      FilledButton(onPressed: saving ? null : () async {
        setD(() => saving = true);
        final payload = {'poste': poste.text, 'zone': zone.text.isEmpty ? null : zone.text, ...facteurs};
        try {
          if (record != null) await api.patch('/business/analyses-ergonomiques/${record['id']}', payload);
          else await api.post('/business/analyses-ergonomiques', {'code': 'ERG-${DateTime.now().millisecondsSinceEpoch}', ...payload});
          if (context.mounted) Navigator.pop(c);
          onSaved();
        } catch (e) { setD(() { saving = false; formError = '$e'; }); }
      }, child: Text(saving ? '…' : 'Enregistrer')),
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
    title: Text(record == null ? 'Signaler une situation TMS' : 'Modifier le signalement'),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      DropdownButtonFormField<String>(
        value: zoneCorporelle, decoration: const InputDecoration(labelText: 'Zone corporelle'),
        items: ['Dos', 'Épaules', 'Cou', 'Poignets', 'Mains', 'Coudes', 'Genoux', 'Jambes', 'Pieds', 'Autre'].map((z) => DropdownMenuItem(value: z, child: Text(z))).toList(),
        onChanged: (v) => setD(() => zoneCorporelle = v),
      ),
      TextField(controller: poste, decoration: const InputDecoration(labelText: 'Poste (optionnel)')),
      TextField(controller: activite, decoration: const InputDecoration(labelText: 'Activité (optionnel)')),
      if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
    ])),
    actions: [
      if (record != null) TextButton(onPressed: () async {
        try { await api.delete('/business/tms-signalements/${record['id']}'); if (context.mounted) Navigator.pop(c); onSaved(); }
        catch (e) { setD(() => formError = '$e'); }
      }, child: const Text('Supprimer', style: TextStyle(color: QhseColors.red))),
      TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
      FilledButton(onPressed: saving ? null : () async {
        if (zoneCorporelle == null) { setD(() => formError = 'La zone corporelle est requise'); return; }
        setD(() => saving = true);
        final payload = {'zoneCorporelle': zoneCorporelle, 'poste': poste.text.isEmpty ? null : poste.text, 'activite': activite.text.isEmpty ? null : activite.text};
        try {
          if (record != null) await api.patch('/business/tms-signalements/${record['id']}', payload);
          else await api.post('/business/tms-signalements', {'code': 'TMS-${DateTime.now().millisecondsSinceEpoch}', ...payload});
          if (context.mounted) Navigator.pop(c);
          onSaved();
        } catch (e) { setD(() { saving = false; formError = '$e'; }); }
      }, child: Text(saving ? '…' : 'Enregistrer')),
    ],
  )));
}
