import 'package:flutter/material.dart';
import '../services/api.dart';
import '../services/sync_queue.dart';
import '../main.dart';
import '../theme.dart';
import 'attachment_helpers.dart';

const _auditStatusLabels = {
  'DRAFT': 'Brouillon', 'PLANNED': 'Planifié', 'TO_PREPARE': 'À préparer', 'PREPARING': 'Préparation en cours',
  'READY': 'Prêt', 'IN_PROGRESS': 'En cours', 'COMPLETED': 'Réalisé', 'REPORT_PENDING': 'Rapport à finaliser',
  'VALIDATION_PENDING': 'En attente de validation', 'VALIDATED': 'Validé', 'CLOSED': 'Clôturé',
  'POSTPONED': 'Reporté', 'CANCELLED': 'Annulé',
};
const _classificationLabels = {
  'CONFORME': 'Conformité', 'POINT_FORT': 'Point fort / bonne pratique', 'PISTE_AMELIORATION': "Piste d'amélioration",
  'OBSERVATION': 'Observation', 'NC_MINEURE': 'Non-conformité mineure', 'NC_MAJEURE': 'Non-conformité majeure',
};
const _resultatLabels = {
  'NON_EVALUE': 'Non évalué', 'CONFORME': 'Conforme', 'NON_CONFORME': 'Non conforme',
  'PARTIELLEMENT_CONFORME': 'Partiellement conforme', 'NON_APPLICABLE': 'Non applicable', 'OBSERVATION': 'Observation',
  'PISTE_AMELIORATION': "Piste d'amélioration", 'BONNE_PRATIQUE': 'Bonne pratique', 'A_VERIFIER': 'À vérifier',
};

// --- Écran principal : tableau de bord + registre des audits ---
// Le paramétrage (types, référentiels, check-lists, programme, auditeurs,
// analyses) reste géré depuis le web ; cet écran couvre le cœur du travail
// terrain : consulter, réaliser et documenter un audit déjà programmé.
class AuditsPage extends StatefulWidget {
  const AuditsPage({super.key});
  @override
  State<AuditsPage> createState() => _AuditsPageState();
}

class _AuditsPageState extends State<AuditsPage> {
  final api = Api();
  List items = [];
  Map dashboard = {};
  bool loading = true;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      items = List.from(await api.get('/business/audits'));
      dashboard = Map.from(await api.get('/business/audit-dashboard'));
    } catch (_) {}
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext c) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(title: const Text('Audits QHSE'), bottom: const TabBar(tabs: [Tab(text: "Vue d'ensemble"), Tab(text: 'Registre')])),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const AuditFormPage())).then((_) => load()),
        icon: const Icon(Icons.add),
        label: const Text('Planifier'),
      ),
      body: loading ? const Center(child: CircularProgressIndicator()) : TabBarView(children: [_buildApercu(c), _buildRegistre(c)]),
    ),
  );

  Widget _buildApercu(BuildContext c) => RefreshIndicator(
    onRefresh: load,
    child: ListView(padding: const EdgeInsets.all(12), children: [
      KpiBar([
        KpiStat('Au programme', '${dashboard['total'] ?? items.length}', color: QhseColors.blue, icon: Icons.assignment_turned_in_outlined),
        KpiStat('En cours', '${dashboard['enCours'] ?? 0}', color: QhseColors.blue, icon: Icons.schedule),
        KpiStat('Réalisés', '${dashboard['realises'] ?? 0}', color: QhseColors.green, icon: Icons.check_circle_outline),
        KpiStat('En retard', '${dashboard['enRetard'] ?? 0}', color: (dashboard['enRetard'] ?? 0) > 0 ? QhseColors.red : QhseColors.green, icon: Icons.warning_amber_outlined),
      ]),
      const SizedBox(height: 8),
      KpiBar([
        KpiStat('Taux de conformité', '${dashboard['tauxConformite'] ?? '—'}%', color: QhseColors.green, icon: Icons.shield_outlined),
        KpiStat('Score moyen', '${dashboard['scoreMoyen'] ?? '—'}', color: QhseColors.blue, icon: Icons.assessment_outlined),
        KpiStat('NC majeures', '${dashboard['ncMajeures'] ?? 0}', color: (dashboard['ncMajeures'] ?? 0) > 0 ? QhseColors.red : QhseColors.green, icon: Icons.error_outline),
        KpiStat('Constats ouverts', '${dashboard['constatsOuverts'] ?? 0}', color: (dashboard['constatsOuverts'] ?? 0) > 0 ? QhseColors.amber : QhseColors.green, icon: Icons.fact_check_outlined),
      ]),
    ]),
  );

  Widget _buildRegistre(BuildContext c) => RefreshIndicator(
    onRefresh: load,
    child: items.isEmpty
        ? ListView(children: const [Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Aucun audit planifié')))])
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final a = items[i];
              return Card(child: ListTile(
                leading: const Icon(Icons.assignment_turned_in, size: 32),
                title: Text('${a['code']} — ${a['title']}'),
                subtitle: Text('${_auditStatusLabels[a['status']] ?? a['status']} · ${_date(a['auditDate'])}${a['type'] != null ? ' · ${a['type']['label']}' : ''}'),
                trailing: a['score'] != null ? Text('${a['score']}%', style: const TextStyle(fontWeight: FontWeight.bold)) : null,
                onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => AuditDetailPage(auditId: a['id']))).then((_) => load()),
              ));
            },
          ),
  );

  String _date(dynamic v) => v == null ? '' : v.toString().substring(0, 10);
}

// --- Détail d'un audit : check-list, constats, signatures, actions ---
class AuditDetailPage extends StatefulWidget {
  final String auditId;
  const AuditDetailPage({super.key, required this.auditId});
  @override
  State<AuditDetailPage> createState() => _AuditDetailPageState();
}

class _AuditDetailPageState extends State<AuditDetailPage> {
  final api = Api();
  Map? audit;
  bool loading = true;
  String? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() => loading = true);
    try { audit = Map.from(await api.get('/business/audits/${widget.auditId}')); }
    catch (e) { error = '$e'; }
    setState(() => loading = false);
  }

  Future<void> saveResponse(String itemId, Map patch) async {
    try { await api.post('/business/audits/${widget.auditId}/responses/$itemId', patch); load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  @override
  Widget build(BuildContext c) {
    if (loading) return Scaffold(appBar: AppBar(title: const Text('Audit')), body: const Center(child: CircularProgressIndicator()));
    if (error != null || audit == null) return Scaffold(appBar: AppBar(title: const Text('Audit')), body: Center(child: Text(error ?? 'Introuvable')));
    final a = audit!;
    final checklist = a['checklist'];
    final responses = List.from(a['responses'] ?? []);
    final findings = List.from(a['auditFindings'] ?? []);
    final signatures = List.from(a['signatures'] ?? []);

    return Scaffold(
      appBar: AppBar(title: Text(a['title'] ?? ''), actions: [
        IconButton(icon: const Icon(Icons.camera_alt_outlined), onPressed: () => captureAndLinkPhoto(context, api, 'AUDIT', a['id'])),
        IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => AuditFormPage(record: a))).then((_) => load())),
      ]),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Text('${_auditStatusLabels[a['status']] ?? a['status']} · ${a['auditDate'].toString().substring(0, 10)}', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)),
          if (a['independenceWarning'] == true)
            Container(margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: QhseColors.amber.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: Text("⚠ Vérifier l'indépendance de l'auditeur — il pilote ou supplée le processus audité.", style: TextStyle(color: QhseColors.amber, fontSize: 12))),
          if (a['scoreObtenu'] != null || a['tauxConformite'] != null) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _scoreCard('Score', a['scoreObtenu'] != null ? '${a['scoreObtenu']} / ${a['scoreMax']}' : '—')),
              const SizedBox(width: 8),
              Expanded(child: _scoreCard('Taux de conformité', a['tauxConformite'] != null ? '${a['tauxConformite']}%' : '—')),
            ]),
          ],

          if (checklist != null) ...[
            const SizedBox(height: 20),
            Text('Check-list — ${checklist['title']} (${(checklist['items'] as List).length} questions)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            ...List.from(checklist['items']).map((it) {
              final resp = responses.firstWhere((r) => r['checklistItemId'] == it['id'], orElse: () => null);
              return Card(child: Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${it['numero'] != null ? '${it['numero']}. ' : ''}${it['question']}', style: const TextStyle(fontSize: 13)),
                if (it['critereAttendu'] != null) Text('Critère attendu : ${it['critereAttendu']}', style: TextStyle(fontSize: 11, color: QhseColors.textSecondary)),
                const SizedBox(height: 6),
                DropdownButton<String>(
                  value: resp?['resultat'] ?? 'NON_EVALUE', isDense: true, isExpanded: true,
                  items: _resultatLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 12)))).toList(),
                  onChanged: (v) => saveResponse(it['id'], {'resultat': v, 'score': resp?['score'], 'commentaire': resp?['commentaire']}),
                ),
              ])));
            }),
          ],

          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Constats (${findings.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            TextButton.icon(onPressed: () => showAddFindingDialog(context, api, auditId: a['id'], onSaved: load), icon: const Icon(Icons.add, size: 16), label: const Text('Constat')),
          ]),
          if (findings.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Aucun constat enregistré', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
          else
            ...findings.map((f) => Card(child: Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(f['description'] ?? '', style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('${_classificationLabels[f['classification']] ?? f['classification'] ?? 'Standard'}${f['criticite'] != null ? ' · ${f['criticite']}' : ''}${f['nonConformityId'] != null ? ' · NC générée' : ''}${f['riskId'] != null ? ' · Risque généré' : ''}', style: TextStyle(fontSize: 11, color: QhseColors.textSecondary)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, children: [
                    if (f['nonConformityId'] == null) _actionChip(context, 'NC', QhseColors.red, () async { await api.post('/business/audit-findings/${f['id']}/generate-nc', {}); load(); }),
                    if (f['riskId'] == null) _actionChip(context, 'Risque', QhseColors.amber, () async { await api.post('/business/audit-findings/${f['id']}/generate-risk', {}); load(); }),
                    _actionChip(context, 'Action', QhseColors.blue, () async { await api.post('/business/audit-findings/${f['id']}/generate-action', {}); load(); }),
                  ]),
                ])))),

          const SizedBox(height: 20),
          Text('Signatures', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          if (signatures.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Aucune signature demandée', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
          else
            ...signatures.map((s) => Card(child: ListTile(
                  dense: true,
                  title: Text(s['role'] ?? ''),
                  subtitle: s['statut'] == 'SIGNE'
                      ? Text('Signé le ${s['signedAt'].toString().substring(0, 10)}', style: TextStyle(color: QhseColors.green, fontSize: 11))
                      : Text('En attente', style: TextStyle(color: QhseColors.textSecondary, fontSize: 11)),
                ))),
        ]),
      ),
    );
  }

  Widget _scoreCard(String label, String value) => Card(child: Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, color: QhseColors.textSecondary)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ])));

  Widget _actionChip(BuildContext c, String label, Color color, VoidCallback onTap) => ActionChip(
        label: Text(label, style: TextStyle(fontSize: 11, color: color)),
        backgroundColor: color.withOpacity(0.15),
        onPressed: () async { onTap(); },
      );
}

Future<void> showAddFindingDialog(BuildContext context, Api api, {required String auditId, required VoidCallback onSaved}) async {
  final description = TextEditingController();
  String classification = '';
  String criticite = '';
  bool critical = false;
  bool saving = false;
  String? error;
  await showDialog(context: context, builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
    title: const Text('Nouveau constat'),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
      DropdownButtonFormField<String>(
        value: classification.isEmpty ? null : classification, isExpanded: true, decoration: const InputDecoration(labelText: 'Classification'),
        items: _classificationLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
        onChanged: (v) => setD(() => classification = v ?? ''),
      ),
      DropdownButtonFormField<String>(
        value: criticite.isEmpty ? null : criticite, isExpanded: true, decoration: const InputDecoration(labelText: 'Criticité'),
        items: const [DropdownMenuItem(value: 'FAIBLE', child: Text('Faible')), DropdownMenuItem(value: 'MODEREE', child: Text('Modérée')), DropdownMenuItem(value: 'ELEVEE', child: Text('Élevée')), DropdownMenuItem(value: 'CRITIQUE', child: Text('Critique'))],
        onChanged: (v) => setD(() => criticite = v ?? ''),
      ),
      CheckboxListTile(contentPadding: EdgeInsets.zero, value: critical, title: const Text('Constat critique', style: TextStyle(fontSize: 13)), onChanged: (v) => setD(() => critical = v ?? false)),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
    ])),
    actions: [
      TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
      FilledButton(onPressed: saving ? null : () async {
        if (description.text.trim().isEmpty) { setD(() => error = 'La description est obligatoire'); return; }
        setD(() => saving = true);
        try {
          await api.post('/business/audits/$auditId/findings', {'description': description.text.trim(), 'classification': classification.isEmpty ? null : classification, 'criticite': criticite.isEmpty ? null : criticite, 'critical': critical});
          if (context.mounted) Navigator.pop(c);
          onSaved();
        } catch (e) { setD(() { saving = false; error = '$e'; }); }
      }, child: Text(saving ? '…' : 'Ajouter')),
    ],
  )));
}

// --- Formulaire de planification / modification ---
class AuditFormPage extends StatefulWidget {
  final Map? record;
  const AuditFormPage({super.key, this.record});
  @override
  State<AuditFormPage> createState() => _AuditFormPageState();
}

class _AuditFormPageState extends State<AuditFormPage> {
  final api = Api();
  bool get editing => widget.record != null;
  List types = [], referentials = [], workUnits = [], processus = [], users = [], checklists = [];
  final title = TextEditingController();
  final reference = TextEditingController();
  final objectif = TextEditingController();
  DateTime auditDate = DateTime.now().add(const Duration(days: 7));
  String? typeId, referentialId, workUnitId, processusId, auditorId, responsableAuditeId, checklistId;
  String status = 'PLANNED';
  bool busy = false, loadingLists = true;
  String? error;

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    if (r != null) {
      title.text = r['title'] ?? '';
      reference.text = r['reference'] ?? '';
      objectif.text = r['objectif'] ?? '';
      auditDate = DateTime.tryParse(r['auditDate'] ?? '') ?? auditDate;
      typeId = r['typeId']; referentialId = r['referentialId']; workUnitId = r['workUnitId'];
      processusId = r['processusId']; auditorId = r['auditorId']; responsableAuditeId = r['responsableAuditeId'];
      checklistId = r['checklistId']; status = r['status'] ?? 'PLANNED';
    }
    loadLists();
  }

  Future<void> loadLists() async {
    try {
      types = List.from(await api.get('/business/audit-types'));
      referentials = List.from(await api.get('/business/audit-referentials'));
      workUnits = List.from(await api.get('/business/work-units'));
      processus = List.from(await api.get('/business/processus'));
      users = List.from(await api.get('/users'));
      checklists = List.from(await api.get('/business/audit-checklists'));
    } catch (_) {}
    setState(() => loadingLists = false);
  }

  Future<void> pickDate() async {
    final d = await showDatePicker(context: context, initialDate: auditDate, firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 730)));
    if (d != null) setState(() => auditDate = d);
  }

  Future<void> submit() async {
    if (title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le titre est obligatoire')));
      return;
    }
    setState(() { busy = true; error = null; });
    final payload = {
      'title': title.text.trim(), 'reference': reference.text.trim().isEmpty ? null : reference.text.trim(),
      'objectif': objectif.text.trim().isEmpty ? null : objectif.text.trim(),
      'auditDate': auditDate.toIso8601String(), 'status': status,
      'typeId': typeId, 'referentialId': referentialId, 'workUnitId': workUnitId, 'processusId': processusId,
      'auditorId': auditorId, 'responsableAuditeId': responsableAuditeId, 'checklistId': checklistId,
    };
    try {
      if (editing) {
        await api.patch('/business/audits/${widget.record!['id']}', payload);
      } else {
        await api.post('/business/audits', {'code': genCode('AUD'), ...payload});
      }
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (e.networkError && !editing) {
        await SyncQueue.enqueue('audit', 'CREATE', {'code': genCode('AUD'), ...payload});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pas de réseau : audit enregistré hors-ligne, il sera synchronisé automatiquement.'), duration: Duration(seconds: 4)));
          Navigator.pop(context);
        }
      } else {
        setState(() { busy = false; error = '$e'; });
        return;
      }
    } catch (e) {
      setState(() { busy = false; error = '$e'; });
      return;
    }
    setState(() => busy = false);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text(editing ? "Modifier l'audit" : 'Planifier un audit')),
    body: loadingLists
        ? const Center(child: CircularProgressIndicator())
        : ListView(padding: const EdgeInsets.all(16), children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Titre')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: typeId, isExpanded: true, decoration: const InputDecoration(labelText: "Type d'audit"),
              items: [const DropdownMenuItem<String>(value: null, child: Text('—')), ...types.map<DropdownMenuItem<String>>((t) => DropdownMenuItem<String>(value: t['id'] as String, child: Text(t['label'] ?? '')))],
              onChanged: (v) => setState(() => typeId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: referentialId, isExpanded: true, decoration: const InputDecoration(labelText: 'Référentiel'),
              items: [const DropdownMenuItem<String>(value: null, child: Text('—')), ...referentials.map<DropdownMenuItem<String>>((r) => DropdownMenuItem<String>(value: r['id'] as String, child: Text(r['label'] ?? '')))],
              onChanged: (v) => setState(() => referentialId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: checklistId, isExpanded: true, decoration: const InputDecoration(labelText: 'Check-list appliquée'),
              items: [const DropdownMenuItem<String>(value: null, child: Text('—')), ...checklists.map<DropdownMenuItem<String>>((cl) => DropdownMenuItem<String>(value: cl['id'] as String, child: Text(cl['title'] ?? '')))],
              onChanged: (v) => setState(() => checklistId = v),
            ),
            const SizedBox(height: 12),
            TextField(controller: reference, decoration: const InputDecoration(labelText: 'Référence')),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: pickDate, icon: const Icon(Icons.event), label: Text('Date : ${auditDate.toIso8601String().substring(0, 10)}')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: workUnitId, isExpanded: true, decoration: const InputDecoration(labelText: 'Unité de travail / zone'),
              items: [const DropdownMenuItem<String>(value: null, child: Text('—')), ...workUnits.map<DropdownMenuItem<String>>((w) => DropdownMenuItem<String>(value: w['id'] as String, child: Text(w['name'] ?? '')))],
              onChanged: (v) => setState(() => workUnitId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: processusId, isExpanded: true, decoration: const InputDecoration(labelText: 'Processus'),
              items: [const DropdownMenuItem<String>(value: null, child: Text('—')), ...processus.map<DropdownMenuItem<String>>((p) => DropdownMenuItem<String>(value: p['id'] as String, child: Text(p['nom'] ?? '')))],
              onChanged: (v) => setState(() => processusId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: auditorId, isExpanded: true, decoration: const InputDecoration(labelText: 'Auditeur'),
              items: [const DropdownMenuItem<String>(value: null, child: Text('—')), ...users.map<DropdownMenuItem<String>>((u) => DropdownMenuItem<String>(value: u['id'] as String, child: Text('${u['firstName']} ${u['lastName']}')))],
              onChanged: (v) => setState(() => auditorId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: responsableAuditeId, isExpanded: true, decoration: const InputDecoration(labelText: 'Responsable audité'),
              items: [const DropdownMenuItem<String>(value: null, child: Text('—')), ...users.map<DropdownMenuItem<String>>((u) => DropdownMenuItem<String>(value: u['id'] as String, child: Text('${u['firstName']} ${u['lastName']}')))],
              onChanged: (v) => setState(() => responsableAuditeId = v),
            ),
            const SizedBox(height: 12),
            TextField(controller: objectif, decoration: const InputDecoration(labelText: 'Objectif')),
            if (editing) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: status, isExpanded: true, decoration: const InputDecoration(labelText: 'Statut'),
                items: _auditStatusLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                onChanged: (v) => setState(() => status = v ?? 'PLANNED'),
              ),
            ],
            if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : submit, child: Text(busy ? 'Envoi...' : editing ? 'Enregistrer' : 'Planifier'))),
          ]),
  );
}
