import 'package:flutter/material.dart';
import '../services/api.dart';
import '../theme.dart';
import 'haccp_page.dart';
import 'haccp_ccp_detail_page.dart';
import '../i18n/i18n.dart';

const _hazardTypeKeys = {
  'BIOLOGIQUE': 'hazardBiologique',
  'CHIMIQUE': 'hazardChimique',
  'PHYSIQUE': 'hazardPhysique',
  'ALLERGENE': 'hazardAllergene',
};
String _hazardTypeLabel(String? k) => k == null ? '—' : t('haccpStudy.${_hazardTypeKeys[k] ?? 'hazardBiologique'}');

/// Fiche complète d'une étude HACCP : informations générales, équipe,
/// diagramme de flux (étapes réordonnables), analyse des dangers par étape
/// et liste des CCP/CP — la configuration se fait ici, typiquement au
/// bureau (à distinguer de la saisie terrain quotidienne du module).
class HaccpStudyDetailPage extends StatefulWidget {
  final String studyId;
  const HaccpStudyDetailPage({super.key, required this.studyId});
  @override
  State<HaccpStudyDetailPage> createState() => _HaccpStudyDetailPageState();
}

class _HaccpStudyDetailPageState extends State<HaccpStudyDetailPage> {
  final api = Api();
  Map? study;
  List users = [], employees = [];
  bool loading = true, busy = false;
  String? error;

  @override
  void initState() { super.initState(); loadAll(); }

  Future<void> loadAll() async {
    setState(() => loading = true);
    try { study = Map.from(await api.get('/haccp/studies/${widget.studyId}')); }
    catch (e) { error = '$e'; }
    await Future.wait([loadUsers(), loadEmployees()]);
    setState(() => loading = false);
  }

  Future<void> loadUsers() async { try { users = List.from(await api.get('/users')); } catch (_) {} }
  Future<void> loadEmployees() async { try { employees = List.from(await api.get('/epi/employees')); } catch (_) {} }

  String userName(String? id) {
    if (id == null) return '—';
    final u = users.firstWhere((x) => x['id'] == id, orElse: () => null);
    return u == null ? '—' : '${u['firstName']} ${u['lastName']}';
  }

  String employeeName(String? id) {
    if (id == null) return '—';
    final e = employees.firstWhere((x) => x['id'] == id, orElse: () => null);
    return e == null ? '—' : '${e['firstName']} ${e['lastName']}';
  }

  Future<void> doAction(Future<dynamic> Function() action) async {
    setState(() => busy = true);
    try { await action(); await loadAll(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
    setState(() => busy = false);
  }

  // --- Workflow de validation ---
  Future<void> validate() => doAction(() => api.post('/haccp/studies/${widget.studyId}/validate', {}));

  Future<void> revise() async {
    final declencheur = TextEditingController();
    final description = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (dc) => AlertDialog(
      title: Text(t('haccpStudy.nouvelleRevisionTitle')),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: declencheur, decoration: InputDecoration(labelText: t('haccpStudy.declencheur'))),
        const SizedBox(height: 10),
        TextField(controller: description, maxLines: 3, decoration: InputDecoration(labelText: t('haccpStudy.description'))),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dc, false), child: Text(t('haccpStudy.annuler'))),
        FilledButton(onPressed: declencheur.text.trim().isEmpty ? null : () => Navigator.pop(dc, true), child: Text(t('haccpStudy.enregistrer'))),
      ],
    ));
    if (ok != true || declencheur.text.trim().isEmpty) return;
    await doAction(() => api.post('/haccp/studies/${widget.studyId}/revise', {
      'declencheur': declencheur.text.trim(),
      if (description.text.trim().isNotEmpty) 'description': description.text.trim(),
    }));
  }

  // --- Informations générales ---
  Future<void> editStudy() async {
    final s = study!;
    final name = TextEditingController(text: s['name'] ?? '');
    final code = TextEditingController(text: s['code'] ?? '');
    final produit = TextEditingController(text: s['produit'] ?? '');
    final categorieProduit = TextEditingController(text: s['categorieProduit'] ?? '');
    final descriptionProduit = TextEditingController(text: s['descriptionProduit'] ?? '');
    final destination = TextEditingController(text: s['destination'] ?? '');
    final consommateurCible = TextEditingController(text: s['consommateurCible'] ?? '');
    final conditionsStockage = TextEditingController(text: s['conditionsStockage'] ?? '');
    final dureeConservation = TextEditingController(text: s['dureeConservation'] ?? '');
    final modeDistribution = TextEditingController(text: s['modeDistribution'] ?? '');
    final activite = TextEditingController(text: s['activite'] ?? '');
    final atelier = TextEditingController(text: s['atelier'] ?? '');
    final ligne = TextEditingController(text: s['ligne'] ?? '');
    String? responsableId = s['responsableId'];
    final ok = await showDialog<bool>(
      context: context,
      builder: (dc) => StatefulBuilder(builder: (dc, setD) => AlertDialog(
        title: Text(t('haccpStudy.modifierEtudeTitle')),
        content: SizedBox(width: 460, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: name, decoration: InputDecoration(labelText: t('haccpStudy.nom'))),
          const SizedBox(height: 10),
          TextField(controller: code, decoration: InputDecoration(labelText: t('haccpStudy.code'))),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: activite, decoration: InputDecoration(labelText: t('haccpStudy.activite')))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: atelier, decoration: InputDecoration(labelText: t('haccpStudy.atelier')))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: ligne, decoration: InputDecoration(labelText: t('haccpStudy.ligne')))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: produit, decoration: InputDecoration(labelText: t('haccpStudy.produit')))),
          ]),
          const SizedBox(height: 10),
          TextField(controller: categorieProduit, decoration: InputDecoration(labelText: t('haccpStudy.categorieProduit'))),
          const SizedBox(height: 10),
          TextField(controller: descriptionProduit, maxLines: 2, decoration: InputDecoration(labelText: t('haccpStudy.descriptionProduit'))),
          const SizedBox(height: 10),
          TextField(controller: destination, decoration: InputDecoration(labelText: t('haccpStudy.destination'))),
          const SizedBox(height: 10),
          TextField(controller: consommateurCible, decoration: InputDecoration(labelText: t('haccpStudy.consommateurCible'))),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: conditionsStockage, decoration: InputDecoration(labelText: t('haccpStudy.conditionsStockage')))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: dureeConservation, decoration: InputDecoration(labelText: t('haccpStudy.dureeConservation')))),
          ]),
          const SizedBox(height: 10),
          TextField(controller: modeDistribution, decoration: InputDecoration(labelText: t('haccpStudy.modeDistribution'))),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            isExpanded: true, decoration: InputDecoration(labelText: t('haccpStudy.responsable')), value: responsableId,
            items: [const DropdownMenuItem<String>(value: null, child: Text('—')), ...users.map<DropdownMenuItem<String>>((u) => DropdownMenuItem<String>(value: u['id'] as String, child: Text('${u['firstName']} ${u['lastName']}')))],
            onChanged: (v) => setD(() => responsableId = v),
          ),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dc, false), child: Text(t('haccpStudy.annuler'))),
          FilledButton(onPressed: name.text.trim().isEmpty ? null : () => Navigator.pop(dc, true), child: Text(t('haccpStudy.enregistrer'))),
        ],
      )),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    await doAction(() => api.patch('/haccp/studies/${widget.studyId}', {
      'name': name.text.trim(), 'code': code.text.trim().isEmpty ? null : code.text.trim(),
      'produit': produit.text.trim().isEmpty ? null : produit.text.trim(),
      'categorieProduit': categorieProduit.text.trim().isEmpty ? null : categorieProduit.text.trim(),
      'descriptionProduit': descriptionProduit.text.trim().isEmpty ? null : descriptionProduit.text.trim(),
      'destination': destination.text.trim().isEmpty ? null : destination.text.trim(),
      'consommateurCible': consommateurCible.text.trim().isEmpty ? null : consommateurCible.text.trim(),
      'conditionsStockage': conditionsStockage.text.trim().isEmpty ? null : conditionsStockage.text.trim(),
      'dureeConservation': dureeConservation.text.trim().isEmpty ? null : dureeConservation.text.trim(),
      'modeDistribution': modeDistribution.text.trim().isEmpty ? null : modeDistribution.text.trim(),
      'activite': activite.text.trim().isEmpty ? null : activite.text.trim(),
      'atelier': atelier.text.trim().isEmpty ? null : atelier.text.trim(),
      'ligne': ligne.text.trim().isEmpty ? null : ligne.text.trim(),
      'responsableId': responsableId,
    }));
  }

  Future<void> deleteStudy() async {
    final ok = await showDialog<bool>(context: context, builder: (dc) => AlertDialog(
      title: Text(t('haccpStudy.supprimerEtudeTitle')),
      content: Text(t('haccpStudy.supprimerEtudeContent')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dc, false), child: Text(t('haccpStudy.annuler'))),
        FilledButton(onPressed: () => Navigator.pop(dc, true), child: Text(t('haccpStudy.supprimer'))),
      ],
    ));
    if (ok != true) return;
    try { await api.delete('/haccp/studies/${widget.studyId}'); if (mounted) Navigator.pop(context, true); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  // --- Équipe ---
  Future<void> addTeamMember() async {
    String? employeeId;
    final fonction = TextEditingController();
    final roleEtude = TextEditingController();
    bool formationHaccp = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dc) => StatefulBuilder(builder: (dc, setD) => AlertDialog(
        title: Text(t('haccpStudy.ajouterMembreTitle')),
        content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            isExpanded: true, decoration: InputDecoration(labelText: t('haccpStudy.employe')), value: employeeId,
            items: employees.map<DropdownMenuItem<String>>((e) => DropdownMenuItem(value: e['id'] as String, child: Text('${e['firstName']} ${e['lastName']}'))).toList(),
            onChanged: (v) => setD(() => employeeId = v),
          ),
          const SizedBox(height: 10),
          TextField(controller: fonction, decoration: InputDecoration(labelText: t('haccpStudy.fonction'))),
          const SizedBox(height: 10),
          TextField(controller: roleEtude, decoration: InputDecoration(labelText: t('haccpStudy.roleEtude'))),
          CheckboxListTile(contentPadding: EdgeInsets.zero, value: formationHaccp, title: Text(t('haccpStudy.formeHaccp'), style: const TextStyle(fontSize: 13)), onChanged: (v) => setD(() => formationHaccp = v ?? false)),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dc, false), child: Text(t('haccpStudy.annuler'))),
          FilledButton(onPressed: employeeId == null ? null : () => Navigator.pop(dc, true), child: Text(t('haccpStudy.ajouter'))),
        ],
      )),
    );
    if (ok != true || employeeId == null) return;
    await doAction(() => api.post('/haccp/studies/${widget.studyId}/team', {
      'employeeId': employeeId, 'fonction': fonction.text.trim().isEmpty ? null : fonction.text.trim(),
      'roleEtude': roleEtude.text.trim().isEmpty ? null : roleEtude.text.trim(), 'formationHaccp': formationHaccp,
    }));
  }

  Future<void> removeTeamMember(String memberId) => doAction(() => api.delete('/haccp/team/$memberId'));

  // --- Diagramme de flux (étapes) ---
  Future<void> addStep() async {
    final nom = TextEditingController();
    final description = TextEditingController();
    final zone = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (dc) => AlertDialog(
      title: Text(t('haccpStudy.ajouterEtapeTitle')),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nom, decoration: InputDecoration(labelText: t('haccpStudy.nomEtape'))),
        const SizedBox(height: 10),
        TextField(controller: description, maxLines: 2, decoration: InputDecoration(labelText: t('haccpStudy.description'))),
        const SizedBox(height: 10),
        TextField(controller: zone, decoration: InputDecoration(labelText: t('haccpStudy.zone'))),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dc, false), child: Text(t('haccpStudy.annuler'))),
        FilledButton(onPressed: nom.text.trim().isEmpty ? null : () => Navigator.pop(dc, true), child: Text(t('haccpStudy.ajouter'))),
      ],
    ));
    if (ok != true || nom.text.trim().isEmpty) return;
    final steps = List.from(study?['steps'] ?? []);
    await doAction(() => api.post('/haccp/studies/${widget.studyId}/steps', {
      'numero': steps.length + 1, 'nom': nom.text.trim(),
      'description': description.text.trim().isEmpty ? null : description.text.trim(),
      'zone': zone.text.trim().isEmpty ? null : zone.text.trim(),
    }));
  }

  Future<void> deleteStep(String stepId) => doAction(() => api.delete('/haccp/steps/$stepId'));

  Future<void> moveStep(int index, int delta) async {
    final steps = List.from(study?['steps'] ?? []);
    final target = index + delta;
    if (target < 0 || target >= steps.length) return;
    final ids = steps.map((s) => s['id'] as String).toList();
    final tmp = ids[index]; ids[index] = ids[target]; ids[target] = tmp;
    await doAction(() => api.post('/haccp/studies/${widget.studyId}/steps/reorder', {'ids': ids}));
  }

  // --- Analyse des dangers ---
  Future<void> addHazard(String stepId) async {
    final libelle = TextEditingController();
    final justification = TextEditingController();
    final mesuresExistantes = TextEditingController();
    String type = _hazardTypeKeys.keys.first;
    int gravite = 3, probabilite = 3;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dc) => StatefulBuilder(builder: (dc, setD) => AlertDialog(
        title: Text(t('haccpStudy.identifierDangerTitle')),
        content: SizedBox(width: 400, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            isExpanded: true, decoration: InputDecoration(labelText: t('haccpStudy.type')), value: type,
            items: _hazardTypeKeys.keys.map((k) => DropdownMenuItem(value: k, child: Text(_hazardTypeLabel(k)))).toList(),
            onChanged: (v) => setD(() => type = v ?? type),
          ),
          const SizedBox(height: 10),
          TextField(controller: libelle, decoration: InputDecoration(labelText: t('haccpStudy.dangerIdentifie'))),
          const SizedBox(height: 10),
          TextField(controller: justification, maxLines: 2, decoration: InputDecoration(labelText: t('haccpStudy.justification'))),
          const SizedBox(height: 10),
          TextField(controller: mesuresExistantes, maxLines: 2, decoration: InputDecoration(labelText: t('haccpStudy.mesuresExistantes'))),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: DropdownButtonFormField<int>(
              decoration: InputDecoration(labelText: t('haccpStudy.gravite')), value: gravite,
              items: List.generate(5, (i) => i + 1).map((v) => DropdownMenuItem(value: v, child: Text('$v'))).toList(),
              onChanged: (v) => setD(() => gravite = v ?? gravite),
            )),
            const SizedBox(width: 10),
            Expanded(child: DropdownButtonFormField<int>(
              decoration: InputDecoration(labelText: t('haccpStudy.probabilite')), value: probabilite,
              items: List.generate(5, (i) => i + 1).map((v) => DropdownMenuItem(value: v, child: Text('$v'))).toList(),
              onChanged: (v) => setD(() => probabilite = v ?? probabilite),
            )),
          ]),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dc, false), child: Text(t('haccpStudy.annuler'))),
          FilledButton(onPressed: libelle.text.trim().isEmpty ? null : () => Navigator.pop(dc, true), child: Text(t('haccpStudy.enregistrer'))),
        ],
      )),
    );
    if (ok != true || libelle.text.trim().isEmpty) return;
    await doAction(() => api.post('/haccp/steps/$stepId/hazards', {
      'type': type, 'libelle': libelle.text.trim(),
      'justification': justification.text.trim().isEmpty ? null : justification.text.trim(),
      'mesuresExistantes': mesuresExistantes.text.trim().isEmpty ? null : mesuresExistantes.text.trim(),
      'gravite': gravite, 'probabilite': probabilite,
    }));
  }

  Future<void> deleteHazard(String hazardId) => doAction(() => api.delete('/haccp/hazards/$hazardId'));

  // --- CCP / CP ---
  Future<void> addCcp(String hazardId) async {
    String type = 'CCP';
    final dangerMaitrise = TextEditingController();
    final limiteCritique = TextEditingController();
    final parametre = TextEditingController();
    final unite = TextEditingController();
    final frequence = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dc) => StatefulBuilder(builder: (dc, setD) => AlertDialog(
        title: Text(t('haccpStudy.creerPointMaitriseTitle')),
        content: SizedBox(width: 400, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            decoration: InputDecoration(labelText: t('haccpStudy.type')), value: type,
            items: [DropdownMenuItem(value: 'CCP', child: Text(t('haccpStudy.ccpPointCritique'))), DropdownMenuItem(value: 'CP', child: Text(t('haccpStudy.cpPointVigilance')))],
            onChanged: (v) => setD(() => type = v ?? type),
          ),
          const SizedBox(height: 10),
          TextField(controller: dangerMaitrise, decoration: InputDecoration(labelText: t('haccpStudy.dangerMaitrise'))),
          const SizedBox(height: 10),
          TextField(controller: parametre, decoration: InputDecoration(labelText: t('haccpStudy.parametreSurveille'))),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: limiteCritique, decoration: InputDecoration(labelText: t('haccpStudy.limiteCritique')))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: unite, decoration: InputDecoration(labelText: t('haccpStudy.unite')))),
          ]),
          const SizedBox(height: 10),
          TextField(controller: frequence, decoration: InputDecoration(labelText: t('haccpStudy.frequenceSurveillance'))),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dc, false), child: Text(t('haccpStudy.annuler'))),
          FilledButton(onPressed: () => Navigator.pop(dc, true), child: Text(t('haccpStudy.creer'))),
        ],
      )),
    );
    if (ok != true) return;
    await doAction(() => api.post('/haccp/hazards/$hazardId/ccps', {
      'type': type, 'dangerMaitrise': dangerMaitrise.text.trim().isEmpty ? null : dangerMaitrise.text.trim(),
      'limiteCritique': limiteCritique.text.trim().isEmpty ? null : limiteCritique.text.trim(),
      'parametre': parametre.text.trim().isEmpty ? null : parametre.text.trim(),
      'unite': unite.text.trim().isEmpty ? null : unite.text.trim(),
      'frequence': frequence.text.trim().isEmpty ? null : frequence.text.trim(),
    }));
  }

  Widget _metaRow(String label, dynamic value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 150, child: Text(label, style: TextStyle(color: QhseColors.textSecondary, fontSize: 12))),
      Expanded(child: Text(value == null || '$value'.trim().isEmpty ? '—' : '$value', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
    ]),
  );

  List<Widget> _workflowButtons(String? status) {
    final buttons = <Widget>[
      OutlinedButton.icon(onPressed: busy ? null : editStudy, icon: const Icon(Icons.edit, size: 16), label: Text(t('haccpStudy.modifier'))),
    ];
    // Boutons soumis à Api.canManage (RBAC, finding #1) : le backend exige
    // ADMINISTRATEUR/RESPONSABLE_QHSE sur /validate et sur la suppression.
    if ((status == 'BROUILLON' || status == 'EN_VALIDATION') && Api.canManage) {
      buttons.add(FilledButton.icon(onPressed: busy ? null : validate, icon: const Icon(Icons.check, size: 16), label: Text(status == 'BROUILLON' ? t('haccpStudy.soumettrePourValidation') : t('haccpStudy.valider'))));
    }
    buttons.add(OutlinedButton.icon(onPressed: busy ? null : revise, icon: const Icon(Icons.history_edu, size: 16), label: Text(t('haccpStudy.nouvelleRevision'))));
    if (Api.canManage) {
      buttons.add(TextButton.icon(onPressed: busy ? null : deleteStudy, icon: Icon(Icons.delete_outline, size: 16, color: QhseColors.red), label: Text(t('haccpStudy.supprimer'), style: TextStyle(color: QhseColors.red))));
    }
    return buttons;
  }

  @override
  Widget build(BuildContext c) {
    if (loading) return Scaffold(appBar: AppBar(title: Text(t('haccpStudy.pageTitleFallback'))), body: const Center(child: CircularProgressIndicator()));
    if (study == null) return Scaffold(appBar: AppBar(title: Text(t('haccpStudy.pageTitleFallback'))), body: Center(child: Text(error ?? t('haccpStudy.introuvable'))));
    final s = study!;
    final status = s['status'] as String?;
    final sColor = haccpStudyStatusColor(status);
    final team = List.from(s['team'] ?? []);
    final steps = List.from(s['steps'] ?? []);
    final revisions = List.from(s['revisions'] ?? []);

    return Scaffold(
      appBar: AppBar(title: Text('${s['code'] ?? ''} — ${s['name'] ?? ''}')),
      body: RefreshIndicator(
        onRefresh: loadAll,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: sColor.withOpacity(0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: sColor.withOpacity(0.3))),
            child: Row(children: [
              Icon(Icons.info_outline, color: sColor),
              const SizedBox(width: 8),
              Expanded(child: Text(haccpStudyStatusLabels[status] ?? status ?? '—', style: TextStyle(color: sColor, fontWeight: FontWeight.bold))),
              Text('v${s['version'] ?? '1.0'}', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 12),
          _metaRow(t('haccpStudy.metaProduit'), s['produit']),
          _metaRow(t('haccpStudy.metaCategorieProduit'), s['categorieProduit']),
          _metaRow(t('haccpStudy.metaActiviteAtelierLigne'), [s['activite'], s['atelier'], s['ligne']].where((x) => x != null && '$x'.isNotEmpty).join(' / ')),
          _metaRow(t('haccpStudy.metaDestination'), s['destination']),
          _metaRow(t('haccpStudy.metaConsommateurCible'), s['consommateurCible']),
          _metaRow(t('haccpStudy.metaConditionsStockage'), s['conditionsStockage']),
          _metaRow(t('haccpStudy.metaDureeConservation'), s['dureeConservation']),
          _metaRow(t('haccpStudy.metaResponsable'), userName(s['responsableId'])),
          _metaRow(t('haccpStudy.metaProchaineRevision'), s['prochaineRevision'] != null ? haccpFmtDate(s['prochaineRevision']) : '—'),

          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: _workflowButtons(status)),

          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(t('haccpStudy.equipeTitle', {'count': '${team.length}'}), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            TextButton.icon(onPressed: addTeamMember, icon: const Icon(Icons.person_add_alt, size: 16), label: Text(t('haccpStudy.ajouter'))),
          ]),
          if (team.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(t('haccpStudy.aucunMembre'), style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
          else
            ...team.map((m) => Card(child: ListTile(
                  dense: true,
                  leading: Icon(m['formationHaccp'] == true ? Icons.verified_user_outlined : Icons.person_outline, color: m['formationHaccp'] == true ? QhseColors.green : QhseColors.textSecondary),
                  title: Text(m['employee'] != null ? '${m['employee']['firstName']} ${m['employee']['lastName']}' : employeeName(m['employeeId'])),
                  subtitle: Text([m['fonction'], m['roleEtude']].where((x) => x != null && '$x'.isNotEmpty).join(' · ')),
                  trailing: IconButton(icon: const Icon(Icons.delete_outline, size: 18), onPressed: () => removeTeamMember(m['id'])),
                ))),

          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(t('haccpStudy.diagrammeFluxTitle', {'count': '${steps.length}'}), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            TextButton.icon(onPressed: addStep, icon: const Icon(Icons.add, size: 16), label: Text(t('haccpStudy.ajouterEtape'))),
          ]),
          if (steps.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(t('haccpStudy.aucuneEtape'), style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
          else
            ...steps.asMap().entries.map((entry) {
              final i = entry.key;
              final step = entry.value;
              final hazards = List.from(step['hazards'] ?? []);
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      CircleAvatar(radius: 12, backgroundColor: QhseColors.blue.withOpacity(0.15), child: Text('${i + 1}', style: TextStyle(color: QhseColors.blue, fontSize: 11, fontWeight: FontWeight.bold))),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${step['nom']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                      IconButton(icon: const Icon(Icons.arrow_upward, size: 18), onPressed: i == 0 ? null : () => moveStep(i, -1)),
                      IconButton(icon: const Icon(Icons.arrow_downward, size: 18), onPressed: i == steps.length - 1 ? null : () => moveStep(i, 1)),
                      IconButton(icon: const Icon(Icons.delete_outline, size: 18), onPressed: () => deleteStep(step['id'])),
                    ]),
                    if (step['description'] != null) Padding(padding: const EdgeInsets.only(left: 32, top: 2), child: Text('${step['description']}', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12))),
                    if (step['zone'] != null) Padding(padding: const EdgeInsets.only(left: 32, top: 2), child: Text(t('haccpStudy.zonePrefix', {'zone': '${step['zone']}'}), style: TextStyle(color: QhseColors.textSecondary, fontSize: 12))),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 32),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text(t('haccpStudy.dangersTitle', {'count': '${hazards.length}'}), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        TextButton.icon(onPressed: () => addHazard(step['id']), icon: const Icon(Icons.add, size: 14), label: Text(t('haccpStudy.ajouter'), style: const TextStyle(fontSize: 12))),
                      ]),
                    ),
                    ...hazards.map<Widget>((hz) {
                      final ccps = List.from(hz['ccps'] ?? []);
                      return Padding(
                        padding: const EdgeInsets.only(left: 32, top: 4),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: QhseColors.cardAlt, borderRadius: BorderRadius.circular(8)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(child: Text('${_hazardTypeLabel(hz['type'])} — ${hz['libelle']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              if (hz['niveauRisque'] != null) haccpChip(haccpNiveauRisqueLabels[hz['niveauRisque']] ?? '${hz['niveauRisque']}', haccpNiveauRisqueColor(hz['niveauRisque'])),
                              IconButton(icon: const Icon(Icons.delete_outline, size: 16), onPressed: () => deleteHazard(hz['id'])),
                            ]),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text(t('haccpStudy.ccpCpTitle', {'count': '${ccps.length}'}), style: TextStyle(color: QhseColors.textSecondary, fontSize: 11)),
                              TextButton(onPressed: () => addCcp(hz['id']), child: Text(t('haccpStudy.pointDeMaitrise'), style: const TextStyle(fontSize: 11))),
                            ]),
                            ...ccps.map<Widget>((ccp) => ListTile(
                                  dense: true, contentPadding: EdgeInsets.zero, minLeadingWidth: 0,
                                  leading: haccpChip(ccp['type'] ?? 'CCP', ccp['type'] == 'CCP' ? QhseColors.red : QhseColors.blue),
                                  title: Text('${ccp['reference']} — ${ccp['dangerMaitrise'] ?? ccp['parametre'] ?? ''}', style: const TextStyle(fontSize: 12)),
                                  trailing: const Icon(Icons.chevron_right, size: 18),
                                  onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => HaccpCcpDetailPage(studyId: widget.studyId, ccpId: ccp['id']))).then((_) => loadAll()),
                                )),
                          ]),
                        ),
                      );
                    }),
                  ]),
                ),
              );
            }),

          if (revisions.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(t('haccpStudy.historiqueRevisionsTitle', {'count': '${revisions.length}'}), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ...revisions.map((r) => Card(child: ListTile(
                  dense: true,
                  title: Text('v${r['version']} — ${r['declencheur']}'),
                  subtitle: Text('${haccpFmtDate(r['date'])}${r['description'] != null ? ' · ${r['description']}' : ''}'),
                ))),
          ],
        ]),
      ),
    );
  }
}
