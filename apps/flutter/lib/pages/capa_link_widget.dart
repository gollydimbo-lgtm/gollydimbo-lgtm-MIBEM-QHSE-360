import 'package:flutter/material.dart';
import '../services/api.dart';
import '../theme.dart';
import 'actions_page.dart';

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
