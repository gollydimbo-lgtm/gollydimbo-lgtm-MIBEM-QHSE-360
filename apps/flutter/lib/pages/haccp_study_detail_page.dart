import 'package:flutter/material.dart';
import '../services/api.dart';
import '../theme.dart';
import 'haccp_page.dart';
import 'haccp_ccp_detail_page.dart';

const _hazardTypeLabels = {
  'BIOLOGIQUE': 'Biologique',
  'CHIMIQUE': 'Chimique',
  'PHYSIQUE': 'Physique',
  'ALLERGENE': 'Allergène',
};

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
      title: const Text('Nouvelle révision du plan HACCP'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: declencheur, decoration: const InputDecoration(labelText: 'Déclencheur *')),
        const SizedBox(height: 10),
        TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dc, false), child: const Text('Annuler')),
        FilledButton(onPressed: declencheur.text.trim().isEmpty ? null : () => Navigator.pop(dc, true), child: const Text('Enregistrer')),
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
        title: const Text('Modifier l\'étude'),
        content: SizedBox(width: 460, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Nom *')),
          const SizedBox(height: 10),
          TextField(controller: code, decoration: const InputDecoration(labelText: 'Code')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: activite, decoration: const InputDecoration(labelText: 'Activité'))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: atelier, decoration: const InputDecoration(labelText: 'Atelier'))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: ligne, decoration: const InputDecoration(labelText: 'Ligne'))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: produit, decoration: const InputDecoration(labelText: 'Produit'))),
          ]),
          const SizedBox(height: 10),
          TextField(controller: categorieProduit, decoration: const InputDecoration(labelText: 'Catégorie de produit')),
          const SizedBox(height: 10),
          TextField(controller: descriptionProduit, maxLines: 2, decoration: const InputDecoration(labelText: 'Description du produit')),
          const SizedBox(height: 10),
          TextField(controller: destination, decoration: const InputDecoration(labelText: 'Destination')),
          const SizedBox(height: 10),
          TextField(controller: consommateurCible, decoration: const InputDecoration(labelText: 'Consommateur cible')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: conditionsStockage, decoration: const InputDecoration(labelText: 'Conditions de stockage'))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: dureeConservation, decoration: const InputDecoration(labelText: 'Durée de conservation'))),
          ]),
          const SizedBox(height: 10),
          TextField(controller: modeDistribution, decoration: const InputDecoration(labelText: 'Mode de distribution')),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            isExpanded: true, decoration: const InputDecoration(labelText: 'Responsable'), value: responsableId,
            items: [const DropdownMenuItem<String>(value: null, child: Text('—')), ...users.map<DropdownMenuItem<String>>((u) => DropdownMenuItem<String>(value: u['id'] as String, child: Text('${u['firstName']} ${u['lastName']}')))],
            onChanged: (v) => setD(() => responsableId = v),
          ),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dc, false), child: const Text('Annuler')),
          FilledButton(onPressed: name.text.trim().isEmpty ? null : () => Navigator.pop(dc, true), child: const Text('Enregistrer')),
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
      title: const Text('Supprimer cette étude ?'),
      content: const Text('Cette action supprime aussi l\'équipe, le diagramme de flux, les dangers et les CCP associés.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dc, false), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(dc, true), child: const Text('Supprimer')),
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
        title: const Text('Ajouter un membre à l\'équipe HACCP'),
        content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            isExpanded: true, decoration: const InputDecoration(labelText: 'Employé *'), value: employeeId,
            items: employees.map<DropdownMenuItem<String>>((e) => DropdownMenuItem(value: e['id'] as String, child: Text('${e['firstName']} ${e['lastName']}'))).toList(),
            onChanged: (v) => setD(() => employeeId = v),
          ),
          const SizedBox(height: 10),
          TextField(controller: fonction, decoration: const InputDecoration(labelText: 'Fonction')),
          const SizedBox(height: 10),
          TextField(controller: roleEtude, decoration: const InputDecoration(labelText: 'Rôle dans l\'étude')),
          CheckboxListTile(contentPadding: EdgeInsets.zero, value: formationHaccp, title: const Text('Formé HACCP', style: TextStyle(fontSize: 13)), onChanged: (v) => setD(() => formationHaccp = v ?? false)),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dc, false), child: const Text('Annuler')),
          FilledButton(onPressed: employeeId == null ? null : () => Navigator.pop(dc, true), child: const Text('Ajouter')),
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
      title: const Text('Ajouter une étape'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nom, decoration: const InputDecoration(labelText: 'Nom de l\'étape *')),
        const SizedBox(height: 10),
        TextField(controller: description, maxLines: 2, decoration: const InputDecoration(labelText: 'Description')),
        const SizedBox(height: 10),
        TextField(controller: zone, decoration: const InputDecoration(labelText: 'Zone')),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dc, false), child: const Text('Annuler')),
        FilledButton(onPressed: nom.text.trim().isEmpty ? null : () => Navigator.pop(dc, true), child: const Text('Ajouter')),
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
    String type = _hazardTypeLabels.keys.first;
    int gravite = 3, probabilite = 3;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dc) => StatefulBuilder(builder: (dc, setD) => AlertDialog(
        title: const Text('Identifier un danger'),
        content: SizedBox(width: 400, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            isExpanded: true, decoration: const InputDecoration(labelText: 'Type'), value: type,
            items: _hazardTypeLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (v) => setD(() => type = v ?? type),
          ),
          const SizedBox(height: 10),
          TextField(controller: libelle, decoration: const InputDecoration(labelText: 'Danger identifié *')),
          const SizedBox(height: 10),
          TextField(controller: justification, maxLines: 2, decoration: const InputDecoration(labelText: 'Justification')),
          const SizedBox(height: 10),
          TextField(controller: mesuresExistantes, maxLines: 2, decoration: const InputDecoration(labelText: 'Mesures de maîtrise existantes')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: DropdownButtonFormField<int>(
              decoration: const InputDecoration(labelText: 'Gravité (1-5)'), value: gravite,
              items: List.generate(5, (i) => i + 1).map((v) => DropdownMenuItem(value: v, child: Text('$v'))).toList(),
              onChanged: (v) => setD(() => gravite = v ?? gravite),
            )),
            const SizedBox(width: 10),
            Expanded(child: DropdownButtonFormField<int>(
              decoration: const InputDecoration(labelText: 'Probabilité (1-5)'), value: probabilite,
              items: List.generate(5, (i) => i + 1).map((v) => DropdownMenuItem(value: v, child: Text('$v'))).toList(),
              onChanged: (v) => setD(() => probabilite = v ?? probabilite),
            )),
          ]),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dc, false), child: const Text('Annuler')),
          FilledButton(onPressed: libelle.text.trim().isEmpty ? null : () => Navigator.pop(dc, true), child: const Text('Enregistrer')),
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
        title: const Text('Créer un point de maîtrise'),
        content: SizedBox(width: 400, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Type'), value: type,
            items: const [DropdownMenuItem(value: 'CCP', child: Text('CCP — point critique')), DropdownMenuItem(value: 'CP', child: Text('CP — point de vigilance'))],
            onChanged: (v) => setD(() => type = v ?? type),
          ),
          const SizedBox(height: 10),
          TextField(controller: dangerMaitrise, decoration: const InputDecoration(labelText: 'Danger maîtrisé')),
          const SizedBox(height: 10),
          TextField(controller: parametre, decoration: const InputDecoration(labelText: 'Paramètre surveillé')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: limiteCritique, decoration: const InputDecoration(labelText: 'Limite critique'))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: unite, decoration: const InputDecoration(labelText: 'Unité'))),
          ]),
          const SizedBox(height: 10),
          TextField(controller: frequence, decoration: const InputDecoration(labelText: 'Fréquence de surveillance')),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dc, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(dc, true), child: const Text('Créer')),
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
      OutlinedButton.icon(onPressed: busy ? null : editStudy, icon: const Icon(Icons.edit, size: 16), label: const Text('Modifier')),
    ];
    if (status == 'BROUILLON' || status == 'EN_VALIDATION') {
      buttons.add(FilledButton.icon(onPressed: busy ? null : validate, icon: const Icon(Icons.check, size: 16), label: Text(status == 'BROUILLON' ? 'Soumettre pour validation' : 'Valider')));
    }
    buttons.add(OutlinedButton.icon(onPressed: busy ? null : revise, icon: const Icon(Icons.history_edu, size: 16), label: const Text('Nouvelle révision')));
    buttons.add(TextButton.icon(onPressed: busy ? null : deleteStudy, icon: Icon(Icons.delete_outline, size: 16, color: QhseColors.red), label: Text('Supprimer', style: TextStyle(color: QhseColors.red))));
    return buttons;
  }

  @override
  Widget build(BuildContext c) {
    if (loading) return Scaffold(appBar: AppBar(title: const Text('Étude HACCP')), body: const Center(child: CircularProgressIndicator()));
    if (study == null) return Scaffold(appBar: AppBar(title: const Text('Étude HACCP')), body: Center(child: Text(error ?? 'Introuvable')));
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
          _metaRow('Produit', s['produit']),
          _metaRow('Catégorie de produit', s['categorieProduit']),
          _metaRow('Activité / atelier / ligne', [s['activite'], s['atelier'], s['ligne']].where((x) => x != null && '$x'.isNotEmpty).join(' / ')),
          _metaRow('Destination', s['destination']),
          _metaRow('Consommateur cible', s['consommateurCible']),
          _metaRow('Conditions de stockage', s['conditionsStockage']),
          _metaRow('Durée de conservation', s['dureeConservation']),
          _metaRow('Responsable', userName(s['responsableId'])),
          _metaRow('Prochaine révision', s['prochaineRevision'] != null ? haccpFmtDate(s['prochaineRevision']) : '—'),

          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: _workflowButtons(status)),

          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Équipe HACCP (${team.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            TextButton.icon(onPressed: addTeamMember, icon: const Icon(Icons.person_add_alt, size: 16), label: const Text('Ajouter')),
          ]),
          if (team.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('Aucun membre', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
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
            Text('Diagramme de flux (${steps.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            TextButton.icon(onPressed: addStep, icon: const Icon(Icons.add, size: 16), label: const Text('Ajouter une étape')),
          ]),
          if (steps.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('Aucune étape', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
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
                    if (step['zone'] != null) Padding(padding: const EdgeInsets.only(left: 32, top: 2), child: Text('Zone : ${step['zone']}', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12))),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 32),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Dangers (${hazards.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        TextButton.icon(onPressed: () => addHazard(step['id']), icon: const Icon(Icons.add, size: 14), label: const Text('Ajouter', style: TextStyle(fontSize: 12))),
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
                              Expanded(child: Text('${_hazardTypeLabels[hz['type']] ?? hz['type']} — ${hz['libelle']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              if (hz['niveauRisque'] != null) haccpChip(haccpNiveauRisqueLabels[hz['niveauRisque']] ?? '${hz['niveauRisque']}', haccpNiveauRisqueColor(hz['niveauRisque'])),
                              IconButton(icon: const Icon(Icons.delete_outline, size: 16), onPressed: () => deleteHazard(hz['id'])),
                            ]),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text('CCP/CP (${ccps.length})', style: TextStyle(color: QhseColors.textSecondary, fontSize: 11)),
                              TextButton(onPressed: () => addCcp(hz['id']), child: const Text('+ point de maîtrise', style: TextStyle(fontSize: 11))),
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
            Text('Historique des révisions (${revisions.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
