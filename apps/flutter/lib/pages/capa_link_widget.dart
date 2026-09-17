import 'package:flutter/material.dart';
import '../services/api.dart';
import '../services/sync_queue.dart';
import '../theme.dart';
import 'actions_page.dart';
import 'attachment_helpers.dart';

const _capaTypeLabels = {'CURATIVE': 'Curative / immédiate', 'CORRECTIVE': 'Corrective', 'PREVENTIVE': 'Préventive', 'AMELIORATION': 'Amélioration'};
const _capaPriorityLabels = {1: 'Urgente', 2: 'Haute', 3: 'Moyenne', 4: 'Faible'};

// Retour de statut vers le module source (point 10 du cahier des charges) —
// le module d'origine doit refléter automatiquement où en est sa CAPA,
// jamais rester sur un statut technique brut ('OPEN', 'CLOSED'...).
(String, Color) _capaStatutRetour(Map? action) {
  if (action == null) return ('—', QhseColors.textSecondary);
  final status = action['status'];
  final eff = action['effectivenessResult'];
  if (status == 'CLOSED') return ('CAPA clôturée', QhseColors.green);
  if (eff == 'INEFFICACE') return ('CAPA inefficace — nouvelle action nécessaire', QhseColors.red);
  if (eff == 'EFFICACE') return ('CAPA efficace', QhseColors.green);
  if (['COMPLETED', 'EFFECTIVENESS_CHECK', 'VALIDATED'].contains(status)) return ('Action réalisée — efficacité à vérifier', QhseColors.amber);
  if (['CANCELLED', 'REJECTED'].contains(status)) return ('CAPA annulée', QhseColors.textSecondary);
  if (['DRAFT', 'TO_ANALYZE', 'PLANNED', 'ASSIGNED'].contains(status)) return ('CAPA ouverte', QhseColors.blue);
  return ('Traitement en cours', QhseColors.blue);
}

class CapaStatutChip extends StatelessWidget {
  final Map? action;
  const CapaStatutChip({super.key, required this.action});
  @override
  Widget build(BuildContext context) {
    final (label, color) = _capaStatutRetour(action);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

// Section réutilisable "Actions CAPA associées" — un seul widget pour tous
// les modules plutôt qu'une implémentation par module, avec détection de
// doublon avant création (même logique que le panneau web CapaLinksPanel)
// et écran de confirmation + pièces jointes proposées avant ouverture du
// formulaire éditable (même logique que CapaConfirmModal côté web).
class CapaLinksSection extends StatefulWidget {
  final String sourceModule;
  final String sourceEntityId;
  final Map<String, dynamic> prefill;
  const CapaLinksSection({super.key, required this.sourceModule, required this.sourceEntityId, this.prefill = const {}});
  @override
  State<CapaLinksSection> createState() => _CapaLinksSectionState();
}

class _CapaLinksSectionState extends State<CapaLinksSection> {
  final api = Api();
  List links = [];
  bool loading = true, checking = false;
  List? duplicates;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() => loading = true);
    try { links = List.from(await api.get('/business/capa-links/by-source?sourceModule=${widget.sourceModule}&sourceEntityId=${widget.sourceEntityId}')); }
    catch (_) {}
    setState(() => loading = false);
  }

  Future<void> checkAndOpen() async {
    setState(() => checking = true);
    try {
      final dup = List.from(await api.get('/business/capa-links/duplicates?sourceModule=${widget.sourceModule}&sourceEntityId=${widget.sourceEntityId}'));
      if (dup.isNotEmpty) { setState(() => duplicates = dup); } else { showConfirm(); }
    } catch (_) { showConfirm(); }
    setState(() => checking = false);
  }

  void openForm(Map<String, dynamic> mergedPrefill, List<String> selectedAttachmentIds) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CapaFormPage(
      sourceModule: widget.sourceModule, sourceEntityId: widget.sourceEntityId,
      prefillData: mergedPrefill, selectedAttachmentIds: selectedAttachmentIds,
    ))).then((_) => load());
  }

  // Écran de confirmation — le mapping calculé côté serveur est présenté
  // avant toute création, avec les pièces jointes déjà disponibles depuis
  // la source à cocher/décocher, jamais dupliquées physiquement.
  Future<void> showConfirm() async {
    Map? p;
    try { p = Map.from(await api.get('/business/capa-links/prefill?sourceModule=${widget.sourceModule}&sourceEntityId=${widget.sourceEntityId}')); } catch (_) {}
    if (!mounted) return;
    if (p == null) { openForm(widget.prefill, []); return; }
    final attachments = List.from(p['attachments'] ?? []);
    List<String> selected = attachments.map<String>((a) => '${a['id']}').toList();
    await showDialog(context: context, builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
      title: const Text('Créer une CAPA à partir de cette donnée ?'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        _confirmRow('Module source', widget.sourceModule),
        _confirmRow('Type proposé', _capaTypeLabels[p!['actionType']] ?? '${p['actionType'] ?? '—'}'),
        _confirmRow('Priorité proposée', _capaPriorityLabels[p['priority']] ?? '—'),
        _confirmRow('Criticité', '${p['criticite'] ?? '—'}'),
        _confirmRow('Échéance proposée', p['dueDate'] != null ? '${p['dueDate']}'.substring(0, 10) : '—'),
        if (attachments.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('Pièces jointes disponibles depuis la source', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ...attachments.map((a) => CheckboxListTile(
                dense: true, contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading,
                value: selected.contains('${a['id']}'), title: Text('${a['nom']}', style: const TextStyle(fontSize: 12)),
                onChanged: (v) => setD(() { final id = '${a['id']}'; if (v == true) { if (!selected.contains(id)) selected.add(id); } else { selected.remove(id); } }),
              )),
        ],
        const SizedBox(height: 10),
        Text("Informations récupérées automatiquement depuis la source — modifiables à l'étape suivante.", style: TextStyle(color: QhseColors.textSecondary, fontSize: 11)),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
        FilledButton(onPressed: () {
          Navigator.pop(c);
          openForm({
            ...widget.prefill,
            'title': widget.prefill['title'] ?? p!['title'],
            'description': p!['description'], 'actionType': p['actionType'], 'criticite': p['criticite'],
            'priority': p['priority'], 'workUnitId': p['workUnitId'], 'responsibleId': p['responsibleId'], 'dueDate': p['dueDate'],
          }, selected);
        }, child: const Text('Créer la CAPA')),
      ],
    )));
  }

  Widget _confirmRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      );

  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Actions CAPA associées (${links.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        TextButton.icon(onPressed: checking ? null : checkAndOpen, icon: const Icon(Icons.add, size: 16), label: Text(checking ? '…' : 'Créer une CAPA')),
      ]),
      if (duplicates != null && duplicates!.isNotEmpty)
        Container(
          padding: const EdgeInsets.all(8),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(color: QhseColors.amber.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Une action similaire existe déjà : ${duplicates!.map((d) => d['code']).join(', ')}', style: TextStyle(color: QhseColors.amber, fontSize: 12)),
            Row(children: [
              TextButton(onPressed: () => setState(() => duplicates = null), child: const Text('Annuler')),
              TextButton(onPressed: () { setState(() => duplicates = null); showConfirm(); }, child: const Text('Créer quand même')),
            ]),
          ]),
        ),
      if (loading)
        const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator())
      else if (links.isEmpty)
        Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('Aucune CAPA associée', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
      else
        ...links.map((l) => Card(child: ListTile(
              dense: true,
              title: Text('${l['action']['code']} — ${l['action']['title']}'),
              trailing: CapaStatutChip(action: l['action']),
            ))),
    ]),
  );
}

// CAPA commune (point 12 du cahier des charges) — une seule action créée
// à partir de plusieurs sources sélectionnées (ex. NC-001, NC-005, NC-008
// toutes liées à la même cause racine), reliées via la matrice CapaLink
// plutôt qu'une FK unique, sans ressaisie : le titre/description restent
// éditables librement avant l'enregistrement.
class CapaCommonFormPage extends StatefulWidget {
  final List<Map<String, String>> sources; // {sourceModule, sourceEntityId, label}
  const CapaCommonFormPage({super.key, required this.sources});
  @override
  State<CapaCommonFormPage> createState() => _CapaCommonFormPageState();
}

class _CapaCommonFormPageState extends State<CapaCommonFormPage> {
  final api = Api();
  List workUnits = [], users = [];
  final title = TextEditingController();
  final description = TextEditingController();
  DateTime? dueDate;
  String? actionType, criticite, workUnitId, responsibleId;
  int priority = 2;
  bool busy = false, loadingLists = true;
  String? error;

  @override
  void initState() {
    super.initState();
    title.text = 'CAPA commune — ${widget.sources.length} source${widget.sources.length > 1 ? 's' : ''}';
    loadLists();
  }

  Future<void> loadLists() async {
    try {
      workUnits = List.from(await api.get('/business/work-units'));
      users = List.from(await api.get('/users'));
    } catch (_) {}
    setState(() => loadingLists = false);
  }

  Future<void> pickDate() async {
    final d = await showDatePicker(context: context, initialDate: dueDate ?? DateTime.now(), firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 730)));
    if (d != null) setState(() => dueDate = d);
  }

  Future<void> submit() async {
    if (title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le titre est obligatoire')));
      return;
    }
    setState(() { busy = true; error = null; });
    final payload = {
      'code': genCode('ACT'), 'title': title.text.trim(),
      'description': description.text.trim().isEmpty ? null : description.text.trim(),
      'actionType': actionType, 'criticite': criticite, 'priority': priority,
      'dueDate': dueDate?.toIso8601String(), 'workUnitId': workUnitId, 'responsibleId': responsibleId,
      'sources': widget.sources.map((s) => {'sourceModule': s['sourceModule'], 'sourceEntityId': s['sourceEntityId']}).toList(),
    };
    try {
      await api.post('/business/capa-links/create-common', payload);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (e.networkError) {
        await SyncQueue.enqueue('capaCreateCommon', 'CREATE', payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pas de réseau : CAPA commune enregistrée hors-ligne, elle sera synchronisée automatiquement.'), duration: Duration(seconds: 4)));
          Navigator.pop(context, true);
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
    appBar: AppBar(title: Text('CAPA commune (${widget.sources.length} source${widget.sources.length > 1 ? 's' : ''})')),
    body: loadingLists
        ? const Center(child: CircularProgressIndicator())
        : ListView(padding: const EdgeInsets.all(16), children: [
            Container(
              margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: QhseColors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Sources sélectionnées', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 4),
                ...widget.sources.map((s) => Text('• ${s['label']}', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12))),
              ]),
            ),
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Titre de la CAPA commune')),
            const SizedBox(height: 12),
            TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: actionType, isExpanded: true, decoration: const InputDecoration(labelText: "Type d'action"),
              items: [const DropdownMenuItem<String>(value: null, child: Text('—')), ..._capaTypeLabels.entries.map((e) => DropdownMenuItem<String>(value: e.key, child: Text(e.value)))],
              onChanged: (v) => setState(() => actionType = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: criticite, isExpanded: true, decoration: const InputDecoration(labelText: 'Criticité'),
              items: const [DropdownMenuItem<String>(value: null, child: Text('—')), DropdownMenuItem(value: 'NON_CRITIQUE', child: Text('Non critique')), DropdownMenuItem(value: 'MINEURE', child: Text('Mineure')), DropdownMenuItem(value: 'MAJEURE', child: Text('Majeure')), DropdownMenuItem(value: 'CRITIQUE', child: Text('Critique'))],
              onChanged: (v) => setState(() => criticite = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: priority, decoration: const InputDecoration(labelText: 'Priorité'),
              items: const [DropdownMenuItem(value: 1, child: Text('Urgente')), DropdownMenuItem(value: 2, child: Text('Haute')), DropdownMenuItem(value: 3, child: Text('Moyenne')), DropdownMenuItem(value: 4, child: Text('Faible'))],
              onChanged: (v) => setState(() => priority = v ?? 2),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: responsibleId, isExpanded: true, decoration: const InputDecoration(labelText: 'Responsable'),
              items: [const DropdownMenuItem<String>(value: null, child: Text('—')), ...users.map<DropdownMenuItem<String>>((u) => DropdownMenuItem<String>(value: u['id'] as String, child: Text('${u['firstName']} ${u['lastName']}')))],
              onChanged: (v) => setState(() => responsibleId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: workUnitId, isExpanded: true, decoration: const InputDecoration(labelText: 'Unité de travail / service'),
              items: [const DropdownMenuItem<String>(value: null, child: Text('—')), ...workUnits.map<DropdownMenuItem<String>>((w) => DropdownMenuItem<String>(value: w['id'] as String, child: Text(w['name'] ?? '')))],
              onChanged: (v) => setState(() => workUnitId = v),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: pickDate, icon: const Icon(Icons.event), label: Text(dueDate != null ? 'Échéance : ${dueDate!.toIso8601String().substring(0, 10)}' : 'Échéance')),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : submit, child: Text(busy ? 'Envoi...' : 'Créer la CAPA commune'))),
          ]),
  );
}
