import 'package:flutter/material.dart';
import '../services/api.dart';
import '../theme.dart';
import 'actions_page.dart';

// Section réutilisable "Actions CAPA associées" — un seul widget pour tous
// les modules plutôt qu'une implémentation par module, avec détection de
// doublon avant création (même logique que le panneau web CapaLinksPanel).
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
      if (dup.isNotEmpty) { setState(() => duplicates = dup); } else { openForm(); }
    } catch (_) { openForm(); }
    setState(() => checking = false);
  }

  void openForm() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CapaFormPage(
      sourceModule: widget.sourceModule, sourceEntityId: widget.sourceEntityId, prefillData: widget.prefill,
    ))).then((_) => load());
  }

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
              TextButton(onPressed: () { setState(() => duplicates = null); openForm(); }, child: const Text('Créer quand même')),
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
              trailing: Text('${l['action']['status']}', style: const TextStyle(fontSize: 11)),
            ))),
    ]),
  );
}
