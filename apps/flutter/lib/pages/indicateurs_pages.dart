import 'package:flutter/material.dart';
import '../services/api.dart';
import '../theme.dart';

Map<String, dynamic> indicateurStatus(double? actuel, double? cible, bool sensInverse, double? seuilVert, double? seuilOrange) {
  if (actuel == null) return {'color': null, 'label': '—'};
  if (seuilVert != null && seuilOrange != null) {
    final good = sensInverse ? actuel <= seuilVert : actuel >= seuilVert;
    final warn = sensInverse ? actuel <= seuilOrange : actuel >= seuilOrange;
    if (good) return {'color': QhseColors.green, 'label': 'Conforme'};
    if (warn) return {'color': QhseColors.amber, 'label': 'À surveiller'};
    return {'color': QhseColors.red, 'label': 'Non conforme'};
  }
  if (cible == null) return {'color': null, 'label': '—'};
  final ratio = sensInverse ? (cible == 0 ? (actuel == 0 ? 1.0 : 0.0) : cible / (actuel <= 0 ? 0.0001 : actuel)) : (cible == 0 ? 1.0 : actuel / cible);
  if (ratio >= 1) return {'color': QhseColors.green, 'label': 'Conforme'};
  if (ratio >= 0.7) return {'color': QhseColors.amber, 'label': 'À surveiller'};
  return {'color': QhseColors.red, 'label': 'Non conforme'};
}

class IndicateursQualitePage extends StatefulWidget {
  const IndicateursQualitePage({super.key});
  @override
  State<IndicateursQualitePage> createState() => _IndicateursQualitePageState();
}

class _IndicateursQualitePageState extends State<IndicateursQualitePage> {
  final api = Api();
  List items = [];
  List autoItems = [];
  Map indiceGlobal = {'indice': null, 'detail': []};
  bool loading = true;
  bool showPonderation = false;
  String? categorieFilter;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      items = List.from(await api.get('/business/indicateurs-qualite'));
      autoItems = List.from(await api.get('/business/indicateurs-auto-compare'));
      indiceGlobal = Map.from(await api.get('/business/indice-global-qualite'));
    } catch (_) {}
    setState(() => loading = false);
  }

  Future<void> _savePonderation(String autoKey, String poids) async {
    try { await api.post('/business/indicateurs-ponderation', {'autoKey': autoKey, 'poids': double.tryParse(poids) ?? 1}); load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  Future<void> _addMesure(Map ind) async {
    final valeur = TextEditingController();
    final commentaire = TextEditingController();
    String? formError;
    bool saving = false;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
        title: Text('Nouvelle mesure — ${ind['indicateur']}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: valeur, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Valeur')),
          TextField(controller: commentaire, decoration: const InputDecoration(labelText: 'Commentaire (optionnel)')),
          if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          FilledButton(onPressed: saving ? null : () async {
            setD(() => saving = true);
            try {
              await api.post('/business/indicateurs-qualite/${ind['id']}/mesures', {'valeur': double.tryParse(valeur.text) ?? 0, 'commentaire': commentaire.text.isEmpty ? null : commentaire.text});
              if (context.mounted) Navigator.pop(c);
              load();
            } catch (e) { setD(() { saving = false; formError = '$e'; }); }
          }, child: Text(saving ? '…' : 'Enregistrer')),
        ],
      )),
    );
  }

  Future<void> _createAction(Map ind) async {
    final actuel = (ind['actuel'] as num?) ?? 0;
    final cible = (ind['cible'] as num?) ?? 0;
    final ecart = ((actuel - cible) * 100).round() / 100;
    final title = TextEditingController(text: "Corriger l'écart — ${ind['indicateur']}");
    final description = TextEditingController(text: 'Valeur actuelle $actuel${ind['unite'] ?? ''}, cible $cible${ind['unite'] ?? ''} (écart ${ecart > 0 ? '+' : ''}$ecart${ind['unite'] ?? ''}).');
    String? formError;
    bool saving = false;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
        title: const Text('Créer une action corrective'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: title, decoration: const InputDecoration(labelText: 'Titre')),
          TextField(controller: description, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
          if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          FilledButton(onPressed: saving ? null : () async {
            setD(() => saving = true);
            try {
              await api.post('/business/actions', {'code': 'ACT-${DateTime.now().millisecondsSinceEpoch}', 'title': title.text, 'description': description.text, 'priority': 2, 'status': 'OPEN'});
              if (context.mounted) Navigator.pop(c);
            } catch (e) { setD(() { saving = false; formError = '$e'; }); }
          }, child: Text(saving ? '…' : 'Créer')),
        ],
      )),
    );
  }

  Future<void> _showDetail(Map ind) async {
    List mesures = [];
    try { mesures = List.from(await api.get('/business/indicateurs-qualite/${ind['id']}/mesures')); } catch (_) {}
    final actuel = (ind['actuel'] as num?) ?? 0;
    final cible = (ind['cible'] as num?) ?? 0;
    final atteint = ind['sensInverse'] == true ? actuel <= cible : actuel >= cible;
    final ecart = ((actuel - cible) * 100).round() / 100;
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(ind['indicateur'] ?? ''),
        content: SizedBox(
          width: 340,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                Column(children: [Text('Actuel', style: TextStyle(fontSize: 11, color: QhseColors.textSecondary)), Text('$actuel${ind['unite'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
                Column(children: [Text('Cible', style: TextStyle(fontSize: 11, color: QhseColors.textSecondary)), Text('$cible${ind['unite'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
                Column(children: [Text('Écart', style: TextStyle(fontSize: 11, color: QhseColors.textSecondary)), Text('${ecart > 0 ? '+' : ''}$ecart${ind['unite'] ?? ''}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: atteint ? QhseColors.green : QhseColors.red))]),
              ]),
              if (ind['categorie'] != null || ind['formule'] != null) Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text('${ind['categorie'] != null ? 'Catégorie : ${ind['categorie']}\n' : ''}${ind['formule'] != null ? 'Formule : ${ind['formule']}' : ''}', style: TextStyle(fontSize: 12, color: QhseColors.textSecondary)),
              ),
              if (!atteint) Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () { Navigator.pop(c); _createAction(ind); }, child: const Text('Créer une action corrective'))),
              ),
              const Divider(),
              const Text('Historique des mesures', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              if (mesures.isEmpty) Text('Aucune mesure enregistrée', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12))
              else ...mesures.map((m) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Expanded(child: Text('${(m['periode'] ?? '').toString().substring(0, 10)}${m['commentaire'] != null ? ' — ${m['commentaire']}' : ''}', style: const TextStyle(fontSize: 12))),
                      Text('${m['valeur']}${ind['unite'] ?? ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  )),
            ]),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Fermer'))],
      ),
    );
  }

  Future<void> _addOrEdit({Map? record}) async {
    final indicateur = TextEditingController(text: record?['indicateur'] ?? '');
    final actuel = TextEditingController(text: record?['actuel']?.toString() ?? '');
    final cible = TextEditingController(text: record?['cible']?.toString() ?? '');
    final unite = TextEditingController(text: record?['unite'] ?? '');
    final categorie = TextEditingController(text: record?['categorie'] ?? '');
    final formule = TextEditingController(text: record?['formule'] ?? '');
    final seuilVert = TextEditingController(text: record?['seuilVert']?.toString() ?? '');
    final seuilOrange = TextEditingController(text: record?['seuilOrange']?.toString() ?? '');
    bool sensInverse = record?['sensInverse'] ?? false;
    String? formError;
    bool saving = false;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
        title: Text(record == null ? 'Nouvel indicateur' : 'Modifier l\'indicateur'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: indicateur, decoration: const InputDecoration(labelText: 'Indicateur')),
            TextField(controller: categorie, decoration: const InputDecoration(labelText: 'Catégorie (optionnel)')),
            TextField(controller: formule, decoration: const InputDecoration(labelText: 'Formule (optionnel)')),
            Row(children: [
              Expanded(child: TextField(controller: actuel, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Actuel'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: cible, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Cible'))),
            ]),
            TextField(controller: unite, decoration: const InputDecoration(labelText: 'Unité (%, ...)')),
            Row(children: [
              Expanded(child: TextField(controller: seuilVert, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Seuil vert'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: seuilOrange, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Seuil orange'))),
            ]),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Sens inverse (atteint si actuel ≤ cible)', style: TextStyle(fontSize: 12)),
              value: sensInverse, onChanged: (v) => setD(() => sensInverse = v ?? false),
            ),
            if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
          ]),
        ),
        actions: [
          if (record != null) TextButton(
            onPressed: () async {
              try { await api.delete('/business/indicateurs-qualite/${record['id']}'); if (context.mounted) Navigator.pop(c); load(); }
              catch (e) { setD(() => formError = '$e'); }
            },
            child: const Text('Supprimer', style: TextStyle(color: QhseColors.red)),
          ),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          FilledButton(onPressed: saving ? null : () async {
            setD(() => saving = true);
            final payload = {
              'indicateur': indicateur.text, 'actuel': double.tryParse(actuel.text) ?? 0, 'cible': double.tryParse(cible.text) ?? 0,
              'unite': unite.text, 'sensInverse': sensInverse, 'categorie': categorie.text.isEmpty ? null : categorie.text,
              'formule': formule.text.isEmpty ? null : formule.text,
              'seuilVert': seuilVert.text.isEmpty ? null : double.tryParse(seuilVert.text),
              'seuilOrange': seuilOrange.text.isEmpty ? null : double.tryParse(seuilOrange.text),
            };
            try {
              if (record != null) await api.patch('/business/indicateurs-qualite/${record['id']}', payload);
              else await api.post('/business/indicateurs-qualite', {'code': 'IND-${DateTime.now().millisecondsSinceEpoch}', ...payload});
              if (context.mounted) Navigator.pop(c);
              load();
            } catch (e) { setD(() { saving = false; formError = '$e'; }); }
          }, child: Text(saving ? '…' : 'Enregistrer')),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dansLaCible = items.where((i) {
      final actuel = (i['actuel'] as num?)?.toDouble() ?? 0;
      final cible = (i['cible'] as num?)?.toDouble() ?? 0;
      return i['sensInverse'] == true ? actuel <= cible : actuel >= cible;
    }).length;
    final categories = items.map((i) => i['categorie']).where((c) => c != null && c != '').cast<String>().toSet().toList();
    final filteredItems = categorieFilter == null ? items : items.where((i) => i['categorie'] == categorieFilter).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Indicateurs qualité')),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _addOrEdit(), icon: const Icon(Icons.add), label: const Text('Indicateur')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(padding: const EdgeInsets.all(12), children: [
                Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Indice global de performance qualité', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(indiceGlobal['indice'] != null ? '${indiceGlobal['indice']}/100' : '—', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 32)),
                    TextButton(onPressed: () => setState(() => showPonderation = !showPonderation), child: Text(showPonderation ? 'Masquer' : 'Pondérations')),
                  ]),
                  if (showPonderation) ...List.from(indiceGlobal['detail'] ?? []).map((d) {
                    final ctrl = TextEditingController(text: '${d['poids'] ?? 1}');
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        Expanded(child: Text(d['nom'] ?? '', style: const TextStyle(fontSize: 12))),
                        SizedBox(width: 60, child: TextField(controller: ctrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(isDense: true), onSubmitted: (v) => _savePonderation(d['key'], v))),
                      ]),
                    );
                  }),
                ]))),
                const SizedBox(height: 16),
                KpiBar([
                  KpiStat('Indicateurs suivis', '${items.length}', color: QhseColors.blue, icon: Icons.insights_outlined),
                  KpiStat('Dans la cible', '$dansLaCible', color: QhseColors.green, icon: Icons.check_circle_outline),
                  KpiStat('Hors cible', '${items.length - dansLaCible}', color: QhseColors.red, icon: Icons.error_outline),
                ]),
                const SizedBox(height: 16),
                const Text('Bibliothèque automatique', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text('Mois en cours vs mois précédent — calculée depuis les contrôles, NC, actions, réclamations, fournisseurs et audits déjà enregistrés.', style: TextStyle(color: QhseColors.textSecondary, fontSize: 11)),
                const SizedBox(height: 8),
                ...autoItems.map((a) {
                  final valeur = (a['valeur'] as num?)?.toDouble();
                  final precedente = (a['valeurPrecedente'] as num?)?.toDouble();
                  final st = indicateurStatus(valeur, null, a['sensInverse'] == true, null, null);
                  final delta = (valeur != null && precedente != null) ? (((valeur - precedente) * 10).round() / 10) : null;
                  final deltaGood = delta == null ? null : (a['sensInverse'] == true ? delta <= 0 : delta >= 0);
                  return Card(child: ListTile(
                    title: Text(a['nom'] ?? ''),
                    subtitle: Text('${a['categorie'] ?? ''} · ${a['formule'] ?? ''}', style: const TextStyle(fontSize: 11)),
                    trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(valeur != null ? '$valeur${a['unite'] ?? ''}' : '—', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: st['color'] as Color? ?? QhseColors.textPrimary)),
                      if (delta != null) Text('${delta > 0 ? '▲' : delta < 0 ? '▼' : '='}${delta.abs()}${a['unite'] ?? ''}', style: TextStyle(fontSize: 11, color: deltaGood == true ? QhseColors.green : QhseColors.red)),
                    ]),
                  ));
                }),
                const SizedBox(height: 16),
                const Text('Indicateurs manuels', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 8),
                if (categories.length > 1)
                  SizedBox(
                    height: 36,
                    child: ListView(scrollDirection: Axis.horizontal, children: [
                      Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: const Text('Toutes'), selected: categorieFilter == null, onSelected: (_) => setState(() => categorieFilter = null))),
                      ...categories.map((cat) => Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: Text(cat), selected: categorieFilter == cat, onSelected: (_) => setState(() => categorieFilter = cat)))),
                    ]),
                  ),
                if (filteredItems.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text('Aucun indicateur enregistré', style: TextStyle(color: QhseColors.textSecondary))),
                ...filteredItems.map((i) {
                  final actuel = (i['actuel'] as num?)?.toDouble();
                  final cible = (i['cible'] as num?)?.toDouble();
                  final st = indicateurStatus(actuel, cible, i['sensInverse'] == true, (i['seuilVert'] as num?)?.toDouble(), (i['seuilOrange'] as num?)?.toDouble());
                  final mesures = List.from(i['mesures'] ?? []);
                  return Card(child: ListTile(
                    title: Text(i['indicateur'] ?? ''),
                    subtitle: Text('${actuel ?? '—'}${i['unite'] ?? ''} / ${cible ?? '—'}${i['unite'] ?? ''}${mesures.length > 1 ? ' · ${mesures.length} mesures' : ''}'),
                    leading: st['color'] != null ? Icon(Icons.circle, size: 12, color: st['color'] as Color) : null,
                    onTap: () => _showDetail(i),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(icon: const Icon(Icons.add_chart, size: 20), onPressed: () => _addMesure(i), tooltip: 'Ajouter une mesure'),
                      IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () => _addOrEdit(record: i)),
                    ]),
                  ));
                }),
              ]),
            ),
    );
  }
}
