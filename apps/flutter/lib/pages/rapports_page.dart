import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api.dart';
import '../theme.dart';

class _ReportSpec {
  final String label;
  final String endpoint;
  final List<String> columns;
  final List<String> Function(Map item) rowOf;
  const _ReportSpec(this.label, this.endpoint, this.columns, this.rowOf);
}

final _reports = <_ReportSpec>[
  _ReportSpec('Non-conformités', '/business/non-conformities', ['Code', 'Titre', 'Source', 'Sévérité', 'Statut', 'Date'],
      (i) => ['${i['code']}', '${i['title']}', '${i['source'] ?? ''}', '${i['severity']}', '${i['status']}', '${i['occurredAt'] ?? ''}']),
  _ReportSpec('Registre des risques', '/business/risks', ['Code', 'Danger', 'Probabilité', 'Gravité', 'Score', 'Statut'],
      (i) => ['${i['code']}', '${i['hazard']}', '${i['probability']}', '${i['severity']}', '${i['score']}', '${i['status'] ?? ''}']),
  _ReportSpec('Actions correctives', '/business/actions', ['Code', 'Action', 'Priorité', 'Échéance', 'Statut'],
      (i) => ['${i['code']}', '${i['title']}', '${i['priority']}', '${i['dueDate'] ?? ''}', '${i['status']}']),
  _ReportSpec('Accidents & incidents', '/business/safety-events', ['Type', 'Titre', 'Sévérité', 'Date'],
      (i) => ['${i['type']}', '${i['title']}', '${i['severity']}', '${i['occurredAt'] ?? ''}']),
  _ReportSpec('Audits', '/business/audits', ['Code', 'Titre', 'Date', 'Statut', 'Score'],
      (i) => ['${i['code']}', '${i['title']}', '${i['auditDate'] ?? ''}', '${i['status']}', '${i['score'] ?? ''}']),
  _ReportSpec('Environnement', '/business/environment', ['Type', 'Valeur', 'Unité', 'Site', 'Date'],
      (i) => ['${i['type']}', '${i['value'] ?? ''}', '${i['unit'] ?? ''}', '${i['site'] ?? ''}', '${i['recordedAt'] ?? ''}']),
];

class RapportsPage extends StatefulWidget {
  const RapportsPage({super.key});
  @override
  State<RapportsPage> createState() => _RapportsPageState();
}

class _RapportsPageState extends State<RapportsPage> {
  final api = Api();
  String? generating;
  final List<String> history = [];

  String _csvEscape(String v) => v.contains(',') || v.contains('"') || v.contains('\n') ? '"${v.replaceAll('"', '""')}"' : v;

  Future<void> _generate(_ReportSpec spec) async {
    setState(() => generating = spec.label);
    try {
      final items = List.from(await api.get(spec.endpoint));
      final buffer = StringBuffer();
      buffer.writeln(spec.columns.map(_csvEscape).join(','));
      for (final item in items) {
        buffer.writeln(spec.rowOf(item as Map).map(_csvEscape).join(','));
      }
      final dir = await getTemporaryDirectory();
      final fileName = '${spec.label.replaceAll(' ', '_').replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '')}_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File('${dir.path}/$fileName');
      // BOM UTF-8 pour qu'Excel affiche correctement les accents à l'ouverture.
      await file.writeAsBytes([0xEF, 0xBB, 0xBF, ...buffer.toString().codeUnits]);
      await Share.shareXFiles([XFile(file.path)], text: 'Rapport QHSE — ${spec.label}');
      setState(() => history.insert(0, '${spec.label} — ${items.length} ligne(s) — ${DateTime.now().toString().substring(0, 16)}'));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    setState(() => generating = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rapports')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Text('Génère un export CSV réel (ouvrable dans Excel) à partir des données actuelles, et propose de le partager ou de l\'enregistrer.', style: TextStyle(fontSize: 12, color: QhseColors.textSecondary)),
          const SizedBox(height: 12),
          ..._reports.map((r) => Card(
                child: ListTile(
                  leading: const Icon(Icons.description_outlined, color: QhseColors.blue),
                  title: Text(r.label),
                  trailing: generating == r.label
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : FilledButton(onPressed: () => _generate(r), child: const Text('Générer')),
                ),
              )),
          if (history.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Derniers rapports générés', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 6),
            ...history.map((h) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(h, style: const TextStyle(fontSize: 12, color: QhseColors.textSecondary)))),
          ],
        ],
      ),
    );
  }
}
