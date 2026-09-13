import 'package:flutter/material.dart';
import '../services/api.dart';
import '../theme.dart';

Color _niveauColor(String? n) => {'CRITIQUE': QhseColors.red, 'URGENT': QhseColors.red, 'ATTENTION': QhseColors.amber}[n] ?? QhseColors.textSecondary;
Color _criticiteColor(int c) => c >= 12 ? QhseColors.red : c >= 6 ? QhseColors.amber : QhseColors.green;
String _criticiteLabel(int c) => c >= 12 ? 'Critique' : c >= 6 ? 'Élevé' : 'Faible/Modéré';
const List<String> kCategoriesEnv = ['Déchets', 'Eau', 'Énergie', 'Carburants', 'Émissions atmosphériques', 'GES / Carbone', 'Effluents', 'Sols', 'Produits chimiques', 'Nuisances', 'Biodiversité'];
const Map<String, String> kVeilleStatutLabels = {
  'A_TRAITER': 'À traiter', 'EN_COURS': 'En cours', 'INTEGREE': 'Intégrée', 'CONFORME': 'Conforme',
  'PARTIELLEMENT_CONFORME': 'Partiellement conforme', 'NON_CONFORME': 'Non conforme', 'NON_APPLICABLE': 'Non applicable', 'A_VERIFIER': 'À vérifier',
};
Color _veilleStatutColor(String? s) => {'CONFORME': QhseColors.green, 'INTEGREE': QhseColors.green, 'PARTIELLEMENT_CONFORME': QhseColors.amber, 'NON_CONFORME': QhseColors.red, 'A_VERIFIER': QhseColors.amber, 'A_TRAITER': QhseColors.amber, 'EN_COURS': QhseColors.blue}[s] ?? QhseColors.textSecondary;
String _dv(dynamic v, [String suffix = '']) => v == null ? 'Aucune donnée' : '$v$suffix';

// --- Écran principal à 6 onglets ---
class EnvironnementHome extends StatefulWidget {
  const EnvironnementHome({super.key});
  @override
  State<EnvironnementHome> createState() => _EnvironnementHomeState();
}

class _EnvironnementHomeState extends State<EnvironnementHome> {
  final api = Api();
  List releves = [], aspects = [], veille = [], produits = [], indicateurs = [], alertes = [];
  Map dashboard = {};
  bool loading = true;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      releves = List.from(await api.get('/business/environment'));
      aspects = List.from(await api.get('/business/environnement-aspects'));
      dashboard = Map.from(await api.get('/business/environnement-dashboard'));
      alertes = List.from(await api.get('/business/environnement-alertes'));
      veille = List.from(await api.get('/business/veille-reglementaire'));
      produits = List.from(await api.get('/business/produits-chimiques'));
      indicateurs = List.from(await api.get('/business/indicateurs-qualite?domaine=ENVIRONNEMENT'));
    } catch (_) {}
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext c) {
    final veilleEnv = veille.where((v) => v['domaine'] == 'Environnement').toList();
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Environnement'),
          bottom: const TabBar(isScrollable: true, tabs: [
            Tab(text: "Vue d'ensemble"), Tab(text: 'Relevés'), Tab(text: 'Aspects & Impacts'),
            Tab(text: 'Conformité'), Tab(text: 'Produits chimiques'), Tab(text: 'Indicateurs'),
          ]),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
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
          const Text('Score environnemental global', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Text(score != null ? '$score/100' : 'Aucune donnée disponible', style: TextStyle(fontWeight: FontWeight.bold, fontSize: score != null ? 32 : 16, color: scoreColor)),
          if (dashboard['scoreDetail'] != null) Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(spacing: 8, runSpacing: 6, children: List.from(dashboard['scoreDetail']).map<Widget>((d) => Chip(label: Text('${d['nom']} : ${d['valeur'] ?? '—'}${d['valeur'] != null ? '%' : ''}', style: const TextStyle(fontSize: 11)))).toList()),
          ),
        ]))),
        const SizedBox(height: 12),
        KpiBar([
          KpiStat('Conformité', _dv(dashboard['tauxConformite'], '%'), color: QhseColors.blue, icon: Icons.shield_outlined),
          KpiStat('Déchets', _dv(dashboard['dechets']), color: QhseColors.amber, icon: Icons.delete_outline),
          KpiStat('Eau', _dv(dashboard['eau']), color: QhseColors.blue, icon: Icons.water_drop_outlined),
          KpiStat('Énergie', _dv(dashboard['energie']), color: QhseColors.amber, icon: Icons.bolt_outlined),
        ]),
        const SizedBox(height: 8),
        KpiBar([
          KpiStat('Valorisation déchets', _dv(dashboard['tauxValorisationDechets'], '%'), color: QhseColors.green, icon: Icons.recycling),
          KpiStat('Conf. réglementaire', _dv(dashboard['tauxConformiteReglementaire'], '%'), color: QhseColors.blue, icon: Icons.gavel_outlined),
          KpiStat('Aspects significatifs', '${dashboard['aspectsSignificatifs'] ?? 0}', color: (dashboard['aspectsSignificatifs'] ?? 0) > 0 ? QhseColors.red : QhseColors.green, icon: Icons.warning_amber_outlined),
          KpiStat('Actions en retard', '${dashboard['actionsEnRetard'] ?? 0}', color: (dashboard['actionsEnRetard'] ?? 0) > 0 ? QhseColors.red : QhseColors.green, icon: Icons.timer_off_outlined),
        ]),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Alertes environnementales', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
      ]),
    );
  }

  Widget _buildReleves(BuildContext c) => Scaffold(
        floatingActionButton: FloatingActionButton.extended(onPressed: () => showReleveDialog(c, api, onSaved: load), icon: const Icon(Icons.add), label: const Text('Relevé')),
        body: RefreshIndicator(
          onRefresh: load,
          child: releves.isEmpty
              ? ListView(children: const [Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Aucun relevé enregistré')))])
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
      floatingActionButton: FloatingActionButton.extended(onPressed: () => showAspectDialog(c, api, onSaved: load), icon: const Icon(Icons.add), label: const Text('Aspect')),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(padding: const EdgeInsets.all(12), children: [
          KpiBar([
            KpiStat('Aspects', '${aspects.length}', color: QhseColors.blue, icon: Icons.eco_outlined),
            KpiStat('Significatifs', '$significatifs', color: significatifs > 0 ? QhseColors.red : QhseColors.green, icon: Icons.warning_amber_outlined),
          ]),
          const SizedBox(height: 12),
          if (aspects.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('Aucun aspect identifié', style: TextStyle(color: QhseColors.textSecondary))))
          else ...aspects.map((a) => Card(child: ListTile(
                leading: Icon(Icons.circle, size: 12, color: _criticiteColor(a['criticite'] ?? 1)),
                title: Text(a['aspect'] ?? ''),
                subtitle: Text(a['milieu'] ?? '—'),
                trailing: Text('${a['criticite']} (${_criticiteLabel(a['criticite'] ?? 1)})', style: TextStyle(color: _criticiteColor(a['criticite'] ?? 1), fontWeight: FontWeight.bold, fontSize: 11)),
                onTap: () => showAspectDialog(c, api, record: a, onSaved: load),
              ))),
        ]),
      ),
    );
  }

  Widget _buildConformite(BuildContext c, List veilleEnv) => Scaffold(
        floatingActionButton: FloatingActionButton.extended(onPressed: () => showVeilleEnvDialog(c, api, onSaved: load), icon: const Icon(Icons.add), label: const Text('Exigence')),
        body: RefreshIndicator(
          onRefresh: load,
          child: ListView(padding: const EdgeInsets.all(12), children: [
            KpiBar([
              KpiStat('Exigences', '${veilleEnv.length}', color: QhseColors.blue, icon: Icons.gavel_outlined),
              KpiStat('Non conformes', '${veilleEnv.where((v) => v['statut'] == 'NON_CONFORME').length}', color: QhseColors.red, icon: Icons.warning_amber_outlined),
              KpiStat('À vérifier', '${veilleEnv.where((v) => v['statut'] == 'A_VERIFIER').length}', color: QhseColors.amber, icon: Icons.help_outline),
            ]),
            const SizedBox(height: 12),
            if (veilleEnv.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('Aucune exigence environnementale enregistrée', style: TextStyle(color: QhseColors.textSecondary))))
            else ...veilleEnv.map((v) => Card(child: ListTile(
                  title: Text((v['texte'] ?? '').toString().length > 50 ? '${v['texte'].toString().substring(0, 50)}…' : v['texte'] ?? ''),
                  trailing: Text(kVeilleStatutLabels[v['statut']] ?? v['statut'] ?? '', style: TextStyle(color: _veilleStatutColor(v['statut']), fontWeight: FontWeight.bold, fontSize: 11)),
                  onTap: () => showVeilleEnvDialog(c, api, record: v, onSaved: load),
                ))),
          ]),
        ),
      );

  Widget _buildProduits(BuildContext c) {
    final now = DateTime.now();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(onPressed: () => showProduitChimiqueDialog(c, api, onSaved: load), icon: const Icon(Icons.add), label: const Text('Produit')),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(padding: const EdgeInsets.all(12), children: [
          KpiBar([
            KpiStat('Produits', '${produits.length}', color: QhseColors.blue, icon: Icons.science_outlined),
            KpiStat('FDS manquantes', '${produits.where((p) => p['fdsDisponible'] != true).length}', color: QhseColors.amber, icon: Icons.description_outlined),
            KpiStat('Expirés', '${produits.where((p) => p['dateExpiration'] != null && DateTime.parse(p['dateExpiration']).isBefore(now)).length}', color: QhseColors.red, icon: Icons.warning_amber_outlined),
          ]),
          const SizedBox(height: 12),
          if (produits.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('Aucun produit chimique enregistré', style: TextStyle(color: QhseColors.textSecondary))))
          else ...produits.map((p) {
            final expired = p['dateExpiration'] != null && DateTime.parse(p['dateExpiration']).isBefore(now);
            return Card(child: ListTile(
              title: Text(p['nom'] ?? ''),
              subtitle: Text('${p['classification'] ?? '—'} • Stock : ${p['quantiteStockee'] ?? '—'}${p['unite'] ?? ''}'),
              trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                if (p['fdsDisponible'] != true) Text('FDS manquante', style: TextStyle(fontSize: 10, color: QhseColors.amber)),
                if (expired) Text('Expiré', style: TextStyle(fontSize: 10, color: QhseColors.red, fontWeight: FontWeight.bold)),
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
      floatingActionButton: FloatingActionButton.extended(onPressed: () => showIndicateurEnvDialog(c, api, onSaved: load), icon: const Icon(Icons.add), label: const Text('Indicateur')),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(padding: const EdgeInsets.all(12), children: [
          KpiBar([
            KpiStat('Indicateurs', '${indicateurs.length}', color: QhseColors.blue, icon: Icons.insights_outlined),
            KpiStat('Dans la cible', '$cibles', color: QhseColors.green, icon: Icons.check_circle_outline),
            KpiStat('Hors cible', '${indicateurs.length - cibles}', color: QhseColors.red, icon: Icons.error_outline),
          ]),
          const SizedBox(height: 12),
          if (indicateurs.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('Aucun indicateur environnemental — créez-en un librement (nom, formule, unité, fréquence, seuils, source)', style: TextStyle(color: QhseColors.textSecondary))))
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
    title: Text(record == null ? 'Nouveau relevé environnemental' : 'Modifier le relevé'),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      DropdownButtonFormField<String>(
        value: categorie, isExpanded: true, decoration: const InputDecoration(labelText: 'Catégorie'),
        items: kCategoriesEnv.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
        onChanged: (v) => setD(() => categorie = v),
      ),
      TextField(controller: type, decoration: const InputDecoration(labelText: 'Type de relevé')),
      Row(children: [
        Expanded(child: TextField(controller: value, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Valeur'))),
        const SizedBox(width: 8),
        Expanded(child: TextField(controller: unit, decoration: const InputDecoration(labelText: 'Unité'))),
      ]),
      TextField(controller: site, decoration: const InputDecoration(labelText: 'Site (optionnel)')),
      DropdownButtonFormField<bool>(
        value: conforme, decoration: const InputDecoration(labelText: 'Conformité (optionnel)'),
        items: const [DropdownMenuItem(value: true, child: Text('Conforme')), DropdownMenuItem(value: false, child: Text('Non conforme'))],
        onChanged: (v) => setD(() => conforme = v),
      ),
      if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
    ])),
    actions: [
      if (record != null) TextButton(onPressed: () async {
        try { await api.delete('/business/environment/${record['id']}'); if (context.mounted) Navigator.pop(c); onSaved(); }
        catch (e) { setD(() => formError = '$e'); }
      }, child: const Text('Supprimer', style: TextStyle(color: QhseColors.red))),
      TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
      FilledButton(onPressed: saving ? null : () async {
        setD(() => saving = true);
        final payload = {'categorie': categorie, 'type': type.text, 'value': double.tryParse(value.text), 'unit': unit.text.isEmpty ? null : unit.text, 'site': site.text.isEmpty ? null : site.text, 'conforme': conforme};
        try {
          if (record != null) await api.patch('/business/environment/${record['id']}', payload);
          else await api.post('/business/environment', {'code': 'ENV-${DateTime.now().millisecondsSinceEpoch}', ...payload, 'recordedAt': DateTime.now().toIso8601String()});
          if (context.mounted) Navigator.pop(c);
          onSaved();
        } catch (e) { setD(() { saving = false; formError = '$e'; }); }
      }, child: Text(saving ? '…' : 'Enregistrer')),
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
    title: Text(record == null ? 'Nouvel aspect environnemental' : "Modifier l'aspect"),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: aspect, decoration: const InputDecoration(labelText: 'Aspect environnemental')),
      DropdownButtonFormField<String>(
        value: milieu, decoration: const InputDecoration(labelText: 'Milieu concerné'),
        items: ['Air', 'Eau', 'Sol', 'Sous-sol', 'Biodiversité', 'Ressources naturelles', 'Population', 'Climat'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
        onChanged: (v) => setD(() => milieu = v),
      ),
      const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.only(top: 8), child: Text('Criticité = Fréquence × Gravité × Probabilité ÷ Maîtrise', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)))),
      Row(children: [
        Expanded(child: DropdownButtonFormField<int>(value: frequence, decoration: const InputDecoration(labelText: 'Fréq.'), items: [1, 2, 3, 4].map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(), onChanged: (v) => setD(() => frequence = v!))),
        const SizedBox(width: 6),
        Expanded(child: DropdownButtonFormField<int>(value: gravite, decoration: const InputDecoration(labelText: 'Gravité'), items: [1, 2, 3, 4].map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(), onChanged: (v) => setD(() => gravite = v!))),
      ]),
      Row(children: [
        Expanded(child: DropdownButtonFormField<int>(value: probabilite, decoration: const InputDecoration(labelText: 'Proba.'), items: [1, 2, 3, 4].map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(), onChanged: (v) => setD(() => probabilite = v!))),
        const SizedBox(width: 6),
        Expanded(child: DropdownButtonFormField<int>(value: maitrise, decoration: const InputDecoration(labelText: 'Maîtrise'), items: [1, 2, 3, 4].map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(), onChanged: (v) => setD(() => maitrise = v!))),
      ]),
      Builder(builder: (context) {
        final crit = ((frequence * gravite * probabilite) / maitrise).round();
        return Padding(padding: const EdgeInsets.only(top: 6), child: Text('Criticité calculée : $crit (${_criticiteLabel(crit)})', style: TextStyle(color: _criticiteColor(crit), fontSize: 12)));
      }),
      if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
    ])),
    actions: [
      if (record != null) TextButton(onPressed: () async {
        try { await api.delete('/business/environnement-aspects/${record['id']}'); if (context.mounted) Navigator.pop(c); onSaved(); }
        catch (e) { setD(() => formError = '$e'); }
      }, child: const Text('Supprimer', style: TextStyle(color: QhseColors.red))),
      TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
      FilledButton(onPressed: saving ? null : () async {
        setD(() => saving = true);
        final payload = {'aspect': aspect.text, 'milieu': milieu, 'gravite': gravite, 'probabilite': probabilite, 'frequence': frequence, 'maitrise': maitrise};
        try {
          if (record != null) await api.patch('/business/environnement-aspects/${record['id']}', payload);
          else await api.post('/business/environnement-aspects', {'code': 'ASP-${DateTime.now().millisecondsSinceEpoch}', ...payload});
          if (context.mounted) Navigator.pop(c);
          onSaved();
        } catch (e) { setD(() { saving = false; formError = '$e'; }); }
      }, child: Text(saving ? '…' : 'Enregistrer')),
    ],
  )));
}

Future<void> showVeilleEnvDialog(BuildContext context, Api api, {Map? record, required VoidCallback onSaved}) async {
  final texte = TextEditingController(text: record?['texte'] ?? '');
  String statut = record?['statut'] ?? 'A_TRAITER';
  String? formError;
  bool saving = false;
  await showDialog(context: context, builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
    title: Text(record == null ? 'Nouvelle exigence' : "Modifier l'exigence"),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: texte, maxLines: 3, decoration: const InputDecoration(labelText: 'Texte réglementaire')),
      DropdownButtonFormField<String>(
        value: statut, isExpanded: true, decoration: const InputDecoration(labelText: 'Statut'),
        items: kVeilleStatutLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
        onChanged: (v) => setD(() => statut = v ?? 'A_TRAITER'),
      ),
      if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
    ])),
    actions: [
      if (record != null) TextButton(onPressed: () async {
        try { await api.delete('/business/veille-reglementaire/${record['id']}'); if (context.mounted) Navigator.pop(c); onSaved(); }
        catch (e) { setD(() => formError = '$e'); }
      }, child: const Text('Supprimer', style: TextStyle(color: QhseColors.red))),
      TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
      FilledButton(onPressed: saving ? null : () async {
        setD(() => saving = true);
        final payload = {'texte': texte.text, 'domaine': 'Environnement', 'statut': statut};
        try {
          if (record != null) await api.patch('/business/veille-reglementaire/${record['id']}', payload);
          else await api.post('/business/veille-reglementaire', {'code': 'VEI-${DateTime.now().millisecondsSinceEpoch}', ...payload});
          if (context.mounted) Navigator.pop(c);
          onSaved();
        } catch (e) { setD(() { saving = false; formError = '$e'; }); }
      }, child: Text(saving ? '…' : 'Enregistrer')),
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
    title: Text(record == null ? 'Nouveau produit chimique' : 'Modifier le produit'),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: nom, decoration: const InputDecoration(labelText: 'Nom')),
      Row(children: [
        Expanded(child: TextField(controller: quantite, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Quantité stockée'))),
        const SizedBox(width: 8),
        Expanded(child: TextField(controller: unite, decoration: const InputDecoration(labelText: 'Unité'))),
      ]),
      CheckboxListTile(contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, title: const Text('Rétention en place', style: TextStyle(fontSize: 12)), value: retention, onChanged: (v) => setD(() => retention = v ?? false)),
      CheckboxListTile(contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, title: const Text('FDS disponible', style: TextStyle(fontSize: 12)), value: fdsDisponible, onChanged: (v) => setD(() => fdsDisponible = v ?? false)),
      if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
    ])),
    actions: [
      if (record != null) TextButton(onPressed: () async {
        try { await api.delete('/business/produits-chimiques/${record['id']}'); if (context.mounted) Navigator.pop(c); onSaved(); }
        catch (e) { setD(() => formError = '$e'); }
      }, child: const Text('Supprimer', style: TextStyle(color: QhseColors.red))),
      TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
      FilledButton(onPressed: saving ? null : () async {
        setD(() => saving = true);
        final payload = {'nom': nom.text, 'quantiteStockee': double.tryParse(quantite.text), 'unite': unite.text.isEmpty ? null : unite.text, 'retention': retention, 'fdsDisponible': fdsDisponible};
        try {
          if (record != null) await api.patch('/business/produits-chimiques/${record['id']}', payload);
          else await api.post('/business/produits-chimiques', {'code': 'CHIM-${DateTime.now().millisecondsSinceEpoch}', ...payload});
          if (context.mounted) Navigator.pop(c);
          onSaved();
        } catch (e) { setD(() { saving = false; formError = '$e'; }); }
      }, child: Text(saving ? '…' : 'Enregistrer')),
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
    title: const Text('Nouvel indicateur environnemental'),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: indicateur, decoration: const InputDecoration(labelText: 'Nom de l\'indicateur')),
      TextField(controller: formule, decoration: const InputDecoration(labelText: 'Formule (optionnel)')),
      Row(children: [
        Expanded(child: TextField(controller: actuel, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Actuel'))),
        const SizedBox(width: 8),
        Expanded(child: TextField(controller: cible, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Cible'))),
      ]),
      TextField(controller: unite, decoration: const InputDecoration(labelText: 'Unité')),
      if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
    ])),
    actions: [
      TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
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
      }, child: Text(saving ? '…' : 'Enregistrer')),
    ],
  )));
}
