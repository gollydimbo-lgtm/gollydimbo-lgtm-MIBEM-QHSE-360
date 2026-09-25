import 'package:flutter/material.dart';
import '../services/api.dart';
import '../theme.dart';
import 'load_error_view.dart';
import '../services/sync_queue.dart';
import '../i18n/i18n.dart';

Map<String, dynamic> indicateurStatus(double? actuel, double? cible, bool sensInverse, double? seuilVert, double? seuilOrange) {
  if (actuel == null) return {'color': null, 'label': '—'};
  if (seuilVert != null && seuilOrange != null) {
    final good = sensInverse ? actuel <= seuilVert : actuel >= seuilVert;
    final warn = sensInverse ? actuel <= seuilOrange : actuel >= seuilOrange;
    if (good) return {'color': QhseColors.green, 'label': t('indicateurs.conforme')};
    if (warn) return {'color': QhseColors.amber, 'label': t('indicateurs.aSurveiller')};
    return {'color': QhseColors.red, 'label': t('indicateurs.nonConforme')};
  }
  if (cible == null) return {'color': null, 'label': '—'};
  final ratio = sensInverse ? (cible == 0 ? (actuel == 0 ? 1.0 : 0.0) : cible / (actuel <= 0 ? 0.0001 : actuel)) : (cible == 0 ? 1.0 : actuel / cible);
  if (ratio >= 1) return {'color': QhseColors.green, 'label': t('indicateurs.conforme')};
  if (ratio >= 0.7) return {'color': QhseColors.amber, 'label': t('indicateurs.aSurveiller')};
  return {'color': QhseColors.red, 'label': t('indicateurs.nonConforme')};
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
  Object? error;
  bool showPonderation = false;
  String? categorieFilter;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      items = List.from(await api.get('/business/indicateurs-qualite'));
      autoItems = List.from(await api.get('/business/indicateurs-auto-compare'));
      indiceGlobal = Map.from(await api.get('/business/indice-global-qualite'));
    } catch (e) { error = e; }
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
        title: Text(t('indicateurs.nouvelleMesure', {'nom': '${ind['indicateur']}'})),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: valeur, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: t('indicateurs.valeur'))),
          TextField(controller: commentaire, decoration: InputDecoration(labelText: t('indicateurs.commentaireOptionnel'))),
          if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(t('indicateurs.annuler'))),
          FilledButton(onPressed: saving ? null : () async {
            setD(() => saving = true);
            final payload = {'valeur': double.tryParse(valeur.text) ?? 0, 'commentaire': commentaire.text.isEmpty ? null : commentaire.text};
            try {
              await api.post('/business/indicateurs-qualite/${ind['id']}/mesures', payload);
              if (context.mounted) Navigator.pop(c);
              load();
            } on ApiException catch (e) {
              if (e.networkError) {
                await SyncQueue.enqueue('indicateurMesure', 'CREATE', {'indicateurId': ind['id'], ...payload});
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('indicateurs.mesureHorsLigne')), duration: const Duration(seconds: 4)));
                  Navigator.pop(c);
                }
                load();
              } else {
                setD(() { saving = false; formError = '$e'; });
              }
            } catch (e) { setD(() { saving = false; formError = '$e'; }); }
          }, child: Text(saving ? '…' : t('indicateurs.enregistrer'))),
        ],
      )),
    );
  }

  Future<void> _createAction(Map ind) async {
    final actuel = (ind['actuel'] as num?) ?? 0;
    final cible = (ind['cible'] as num?) ?? 0;
    final ecart = ((actuel - cible) * 100).round() / 100;
    final title = TextEditingController(text: t('indicateurs.corrigerEcart', {'nom': '${ind['indicateur']}'}));
    final description = TextEditingController(text: t('indicateurs.valeurActuelleDesc', {'actuel': '$actuel', 'cible': '$cible', 'ecart': '${ecart > 0 ? '+' : ''}$ecart', 'unite': '${ind['unite'] ?? ''}'}));
    String? formError;
    bool saving = false;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
        title: Text(t('indicateurs.creerActionCorrective')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: title, decoration: InputDecoration(labelText: t('indicateurs.titre'))),
          TextField(controller: description, decoration: InputDecoration(labelText: t('indicateurs.description')), maxLines: 3),
          if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(t('indicateurs.annuler'))),
          FilledButton(onPressed: saving ? null : () async {
            setD(() => saving = true);
            try {
              await api.post('/business/actions', {'code': 'ACT-${DateTime.now().millisecondsSinceEpoch}', 'title': title.text, 'description': description.text, 'priority': 2, 'status': 'OPEN'});
              if (context.mounted) Navigator.pop(c);
            } catch (e) { setD(() { saving = false; formError = '$e'; }); }
          }, child: Text(saving ? '…' : t('indicateurs.creer'))),
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
                Column(children: [Text(t('indicateurs.actuel'), style: TextStyle(fontSize: 11, color: QhseColors.textSecondary)), Text('$actuel${ind['unite'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
                Column(children: [Text(t('indicateurs.cible'), style: TextStyle(fontSize: 11, color: QhseColors.textSecondary)), Text('$cible${ind['unite'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
                Column(children: [Text(t('indicateurs.ecart'), style: TextStyle(fontSize: 11, color: QhseColors.textSecondary)), Text('${ecart > 0 ? '+' : ''}$ecart${ind['unite'] ?? ''}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: atteint ? QhseColors.green : QhseColors.red))]),
              ]),
              if (ind['categorie'] != null || ind['formule'] != null) Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text('${ind['categorie'] != null ? t('indicateurs.categorieDetail', {'cat': '${ind['categorie']}'}) : ''}${ind['formule'] != null ? t('indicateurs.formuleDetail', {'formule': '${ind['formule']}'}) : ''}', style: TextStyle(fontSize: 12, color: QhseColors.textSecondary)),
              ),
              if (!atteint) Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () { Navigator.pop(c); _createAction(ind); }, child: Text(t('indicateurs.creerActionCorrective')))),
              ),
              const Divider(),
              Text(t('indicateurs.historiqueMesures'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              if (mesures.isEmpty) Text(t('indicateurs.aucuneMesure'), style: TextStyle(color: QhseColors.textSecondary, fontSize: 12))
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
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(t('indicateurs.fermer')))],
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
        title: Text(record == null ? t('indicateurs.nouvelIndicateur') : t('indicateurs.modifierIndicateur')),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: indicateur, decoration: InputDecoration(labelText: t('indicateurs.indicateur'))),
            TextField(controller: categorie, decoration: InputDecoration(labelText: t('indicateurs.categorieOptionnel'))),
            TextField(controller: formule, decoration: InputDecoration(labelText: t('indicateurs.formuleOptionnel'))),
            Row(children: [
              Expanded(child: TextField(controller: actuel, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: t('indicateurs.actuel')))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: cible, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: t('indicateurs.cible')))),
            ]),
            TextField(controller: unite, decoration: InputDecoration(labelText: t('indicateurs.unite'))),
            Row(children: [
              Expanded(child: TextField(controller: seuilVert, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: t('indicateurs.seuilVert')))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: seuilOrange, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: t('indicateurs.seuilOrange')))),
            ]),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading,
              title: Text(t('indicateurs.sensInverse'), style: const TextStyle(fontSize: 12)),
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
            child: Text(t('indicateurs.supprimer'), style: const TextStyle(color: QhseColors.red)),
          ),
          TextButton(onPressed: () => Navigator.pop(c), child: Text(t('indicateurs.annuler'))),
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
          }, child: Text(saving ? '…' : t('indicateurs.enregistrer'))),
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
      appBar: AppBar(title: Text(t('indicateurs.pageTitle'))),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _addOrEdit(), icon: const Icon(Icons.add), label: Text(t('indicateurs.fabIndicateur'))),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? LoadErrorView(error: error, onRetry: load)
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(padding: const EdgeInsets.all(12), children: [
                Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t('indicateurs.indiceGlobalTitle'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(indiceGlobal['indice'] != null ? '${indiceGlobal['indice']}/100' : '—', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 32)),
                    TextButton(onPressed: () => setState(() => showPonderation = !showPonderation), child: Text(showPonderation ? t('indicateurs.masquer') : t('indicateurs.ponderations'))),
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
                  KpiStat(t('indicateurs.kpiIndicateursSuivis'), '${items.length}', color: QhseColors.blue, icon: Icons.insights_outlined),
                  KpiStat(t('indicateurs.kpiDansLaCible'), '$dansLaCible', color: QhseColors.green, icon: Icons.check_circle_outline),
                  KpiStat(t('indicateurs.kpiHorsCible'), '${items.length - dansLaCible}', color: QhseColors.red, icon: Icons.error_outline),
                ]),
                const SizedBox(height: 16),
                Text(t('indicateurs.bibliothequeAutoTitle'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(t('indicateurs.bibliothequeAutoSubtitle'), style: TextStyle(color: QhseColors.textSecondary, fontSize: 11)),
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
                Text(t('indicateurs.indicateursManuelsTitle'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 8),
                if (categories.length > 1)
                  SizedBox(
                    height: 36,
                    child: ListView(scrollDirection: Axis.horizontal, children: [
                      Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: Text(t('indicateurs.toutes')), selected: categorieFilter == null, onSelected: (_) => setState(() => categorieFilter = null))),
                      ...categories.map((cat) => Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: Text(cat), selected: categorieFilter == cat, onSelected: (_) => setState(() => categorieFilter = cat)))),
                    ]),
                  ),
                if (filteredItems.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(t('indicateurs.aucunIndicateur'), style: TextStyle(color: QhseColors.textSecondary))),
                ...filteredItems.map((i) {
                  final actuel = (i['actuel'] as num?)?.toDouble();
                  final cible = (i['cible'] as num?)?.toDouble();
                  final st = indicateurStatus(actuel, cible, i['sensInverse'] == true, (i['seuilVert'] as num?)?.toDouble(), (i['seuilOrange'] as num?)?.toDouble());
                  final mesures = List.from(i['mesures'] ?? []);
                  return Card(child: ListTile(
                    title: Text(i['indicateur'] ?? ''),
                    subtitle: Text('${actuel ?? '—'}${i['unite'] ?? ''} / ${cible ?? '—'}${i['unite'] ?? ''}${mesures.length > 1 ? t('indicateurs.mesuresCount', {'count': '${mesures.length}'}) : ''}'),
                    leading: st['color'] != null ? Icon(Icons.circle, size: 12, color: st['color'] as Color) : null,
                    onTap: () => _showDetail(i),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(icon: const Icon(Icons.add_chart, size: 20), onPressed: () => _addMesure(i), tooltip: t('indicateurs.ajouterMesure')),
                      IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () => _addOrEdit(record: i)),
                    ]),
                  ));
                }),
              ]),
            ),
    );
  }
}
