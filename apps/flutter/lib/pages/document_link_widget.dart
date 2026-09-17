import 'package:flutter/material.dart';
import '../services/api.dart';
import '../theme.dart';

// Statuts du cycle de vie documentaire (GED) — mêmes libellés/couleurs que
// document_detail_page.dart (dupliqué volontairement : privé à chaque
// fichier en Dart, pas de conflit de nom possible entre libraries).
const _docStatusLabels = {
  'DRAFT': 'Brouillon',
  'REVIEW': 'En vérification',
  'APPROVED': 'En attente de publication',
  'ACTIVE': 'En vigueur',
  'SUPERSEDED': 'Obsolète — NE PAS UTILISER',
  'ARCHIVED': 'Archivé',
};

Color _docStatusColor(String? s) => {
      'DRAFT': QhseColors.blue,
      'REVIEW': QhseColors.amber,
      'APPROVED': QhseColors.amber,
      'ACTIVE': QhseColors.green,
      'SUPERSEDED': QhseColors.red,
      'ARCHIVED': QhseColors.textSecondary,
    }[s] ??
    QhseColors.textSecondary;

/// Petit badge de statut documentaire, réutilisé partout où un document
/// est référencé (bibliothèque, à traiter, liens génériques).
class DocumentStatusChip extends StatelessWidget {
  final String? status;
  const DocumentStatusChip({super.key, required this.status});
  @override
  Widget build(BuildContext context) {
    final color = _docStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
      child: Text(_docStatusLabels[status] ?? status ?? '—', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

/// Section réutilisable "Documents associés" — équivalent GED du widget
/// CapaLinksSection (capa_link_widget.dart), même pattern d'appel API et
/// mêmes principes : un document quelconque peut être rattaché à n'importe
/// quel module (sourceModule/sourceEntityId) via la matrice de liaison
/// générique DocumentLink, sans FK dédiée par module.
class DocumentLinksSection extends StatefulWidget {
  final String sourceModule;
  final String sourceEntityId;
  const DocumentLinksSection({super.key, required this.sourceModule, required this.sourceEntityId});
  @override
  State<DocumentLinksSection> createState() => _DocumentLinksSectionState();
}

class _DocumentLinksSectionState extends State<DocumentLinksSection> {
  final api = Api();
  List links = [];
  bool loading = true, associating = false;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      links = List.from(await api.get('/documents/for-source?sourceModule=${widget.sourceModule}&sourceEntityId=${widget.sourceEntityId}'));
    } catch (_) {}
    setState(() => loading = false);
  }

  // Dialog de recherche/sélection parmi tous les documents — filtrage
  // simple côté client (pas besoin de rappeler l'API de recherche serveur
  // ici, la liste des documents reste de taille raisonnable).
  Future<void> associate() async {
    setState(() => associating = true);
    List all = [];
    try { all = List.from(await api.get('/documents')); } catch (_) {}
    setState(() => associating = false);
    if (!mounted) return;
    final linkedIds = links.map((l) => (l['document'] ?? {})['id']).toSet();
    final search = TextEditingController();
    List filtered = all;
    final picked = await showDialog<Map>(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
        title: const Text('Associer un document'),
        content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: search,
            decoration: const InputDecoration(labelText: 'Rechercher (code, titre)', prefixIcon: Icon(Icons.search)),
            onChanged: (v) => setD(() {
              final q = v.trim().toLowerCase();
              filtered = q.isEmpty ? all : all.where((d) => '${d['code']} ${d['title']}'.toLowerCase().contains(q)).toList();
            }),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 320,
            child: filtered.isEmpty
                ? const Center(child: Text('Aucun document'))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final d = filtered[i];
                      final already = linkedIds.contains(d['id']);
                      return ListTile(
                        dense: true,
                        title: Text('${d['code']} — ${d['title']}', style: const TextStyle(fontSize: 13)),
                        subtitle: DocumentStatusChip(status: d['status']),
                        trailing: already ? const Icon(Icons.check, size: 16) : null,
                        enabled: !already,
                        onTap: already ? null : () => Navigator.pop(c, d),
                      );
                    },
                  ),
          ),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Fermer'))],
      )),
    );
    if (picked == null) return;
    try {
      await api.post('/documents/${picked['id']}/links', {'sourceModule': widget.sourceModule, 'sourceEntityId': widget.sourceEntityId});
      load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> requestRevision(Map doc) async {
    final motif = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Demander une révision — ${doc['code'] ?? ''}'),
        content: TextField(controller: motif, maxLines: 3, decoration: const InputDecoration(labelText: 'Motif de la demande')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Envoyer')),
        ],
      ),
    );
    if (ok != true || motif.text.trim().isEmpty) return;
    try {
      await api.post('/documents/${doc['id']}/request-revision', {
        'sourceModule': widget.sourceModule, 'sourceEntityId': widget.sourceEntityId, 'motif': motif.text.trim(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demande de révision envoyée')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Documents associés (${links.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        TextButton.icon(onPressed: associating ? null : associate, icon: const Icon(Icons.add, size: 16), label: Text(associating ? '…' : 'Associer un document')),
      ]),
      if (loading)
        const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator())
      else if (links.isEmpty)
        Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('Aucun document associé', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
      else
        ...links.map((l) {
          final doc = l['document'] ?? {};
          return Card(child: ListTile(
            dense: true,
            title: Text('${doc['code'] ?? '—'} — ${doc['title'] ?? ''}'),
            subtitle: Text('${l['relationType'] ?? 'ASSOCIE'}', style: const TextStyle(fontSize: 11)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              DocumentStatusChip(status: doc['status']),
              IconButton(icon: const Icon(Icons.rule_folder_outlined, size: 18), tooltip: 'Demander une révision', onPressed: () => requestRevision(doc)),
            ]),
          ));
        }),
    ]),
  );
}
