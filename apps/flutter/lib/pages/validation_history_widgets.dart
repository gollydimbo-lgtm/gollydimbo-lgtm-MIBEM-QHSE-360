import 'package:flutter/material.dart';
import '../services/api.dart';
import '../theme.dart';
import '../i18n/i18n.dart';

// Finding #23 — même logique que le panneau web ValidationWorkflowPanel :
// workflow optionnel et non régressif (validationStatus par défaut
// 'APPROUVEE'), jamais un blocage tant que personne ne clique
// "Soumettre pour validation".
class ValidationWorkflowSection extends StatefulWidget {
  final Map item;
  final String endpointBase; // ex. '/business/non-conformities/<id>'
  final VoidCallback onChanged;
  const ValidationWorkflowSection({super.key, required this.item, required this.endpointBase, required this.onChanged});

  @override
  State<ValidationWorkflowSection> createState() => _ValidationWorkflowSectionState();
}

class _ValidationWorkflowSectionState extends State<ValidationWorkflowSection> {
  final api = Api();
  bool busy = false;
  final commentaireCtrl = TextEditingController();

  static Map<String, String> get labels => {
    'APPROUVEE': t('validationHistory.statutApprouvee'), 'SOUMISE': t('validationHistory.statutSoumise'), 'REJETEE': t('validationHistory.statutRejetee'), 'VALIDEE': t('validationHistory.statutValidee'),
  };
  static const Map<String, Color> colors = {
    'APPROUVEE': QhseColors.green, 'SOUMISE': QhseColors.amber, 'REJETEE': QhseColors.red, 'VALIDEE': QhseColors.green,
  };

  Future<void> run(String action, [Map<String, dynamic>? body]) async {
    setState(() => busy = true);
    try {
      await api.post('${widget.endpointBase}/$action-validation', body ?? {});
      widget.onChanged();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.item['validationStatus'] ?? 'APPROUVEE';
    final color = colors[status] ?? QhseColors.textSecondary;
    return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(t('validationHistory.validation'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const Spacer(),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(999)), child: Text(labels[status] ?? status, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600))),
      ]),
      if (status != 'SOUMISE') ...[
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerRight, child: OutlinedButton(onPressed: busy ? null : () => run('soumettre'), child: Text(busy ? '…' : t('validationHistory.soumettrePourValidation')))),
      ],
      if (status == 'SOUMISE') ...[
        const SizedBox(height: 8),
        TextField(controller: commentaireCtrl, decoration: InputDecoration(labelText: t('validationHistory.commentaireOptionnel'), isDense: true)),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(onPressed: busy ? null : () => run('rejeter', {'commentaire': commentaireCtrl.text.trim().isEmpty ? null : commentaireCtrl.text.trim()}), child: Text(t('validationHistory.rejeter'), style: TextStyle(color: QhseColors.red))),
          const SizedBox(width: 8),
          FilledButton(onPressed: busy ? null : () => run('approuver', {'commentaire': commentaireCtrl.text.trim().isEmpty ? null : commentaireCtrl.text.trim()}), child: Text(t('validationHistory.approuver'))),
        ]),
      ],
    ])));
  }
}

// Finding #24 — historique des modifications, même source que le web
// (GET /audit-logs?module=X&entityId=Y), pas de duplication de données.
class HistorySection extends StatefulWidget {
  final String module;
  final String entityId;
  const HistorySection({super.key, required this.module, required this.entityId});

  @override
  State<HistorySection> createState() => _HistorySectionState();
}

class _HistorySectionState extends State<HistorySection> {
  final api = Api();
  List entries = [];
  bool loading = true;
  Object? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try { entries = List.from(await api.get('/audit-logs?module=${widget.module}&entityId=${widget.entityId}')); }
    catch (e) { error = e; }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t('validationHistory.historique'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      const SizedBox(height: 8),
      if (loading) const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
      else if (error != null) Text(t('validationHistory.historiqueIndisponible'), style: TextStyle(color: QhseColors.textSecondary, fontSize: 12))
      else if (entries.isEmpty) Text(t('validationHistory.aucuneModification'), style: TextStyle(color: QhseColors.textSecondary, fontSize: 12))
      else ...entries.map((e) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text('${e['action'] ?? ''} — ${e['userId'] ?? t('validationHistory.systeme')}', style: const TextStyle(fontSize: 12))),
            Text(e['createdAt'] != null ? DateTime.parse(e['createdAt']).toLocal().toString().substring(0, 16) : '—', style: TextStyle(color: QhseColors.textSecondary, fontSize: 11)),
          ]))),
    ])));
  }
}
