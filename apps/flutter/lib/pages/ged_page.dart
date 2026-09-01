import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api.dart';

const _groupOrder = [
  'STRATEGIE_CONTEXTE',
  'RISQUES_SECURITE_CONFORMITE',
  'SUPPORTS_MAITRISE_DOCUMENTAIRE',
  'OPERATIONS_MAITRISE_TERRAIN',
  'EVALUATION_CONTROLE_AMELIORATION',
];

const _groupLabels = {
  'STRATEGIE_CONTEXTE': '1. Stratégie et Contexte',
  'RISQUES_SECURITE_CONFORMITE': '2. Risques, Sécurité et Conformité',
  'SUPPORTS_MAITRISE_DOCUMENTAIRE': '3. Supports et Maîtrise Documentaire',
  'OPERATIONS_MAITRISE_TERRAIN': '4. Opérations et Maîtrise Terrain',
  'EVALUATION_CONTROLE_AMELIORATION': '5. Évaluation, Contrôle et Amélioration',
};

const _groupIcons = {
  'STRATEGIE_CONTEXTE': Icons.flag_outlined,
  'RISQUES_SECURITE_CONFORMITE': Icons.warning_amber_outlined,
  'SUPPORTS_MAITRISE_DOCUMENTAIRE': Icons.folder_copy_outlined,
  'OPERATIONS_MAITRISE_TERRAIN': Icons.precision_manufacturing_outlined,
  'EVALUATION_CONTROLE_AMELIORATION': Icons.insights_outlined,
};

class GedPage extends StatefulWidget {
  const GedPage({super.key});
  @override
  State<GedPage> createState() => _GedPageState();
}

class _GedPageState extends State<GedPage> {
  final api = Api();
  List documents = [];
  bool loading = true;
  String? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      documents = List.from(await api.get('/documents'));
    } catch (e) {
      error = 'Impossible de charger le référentiel documentaire';
    }
    setState(() => loading = false);
  }

  Map<String?, List> groupedDocuments() {
    final map = <String?, List>{};
    for (final d in documents) {
      final g = d['documentGroup'] as String?;
      map.putIfAbsent(g, () => []).add(d);
    }
    return map;
  }

  Future<void> openLatestVersion(Map doc) async {
    final versions = List.from(doc['versions'] ?? []);
    if (versions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucun fichier associé à ce document')));
      return;
    }
    versions.sort((a, b) => (b['version'] as int).compareTo(a['version'] as int));
    final latest = versions.first;
    final storagePath = '${latest['storagePath']}';
    final fileName = storagePath.split(RegExp(r'[\\/]')).last;

    final apiUrl = await Api.currentBaseUrl(); // ex: http://10.0.2.2:3000/api/v4
    final serverRoot = apiUrl.replaceFirst(RegExp(r'/api/v4/?$'), '');
    final fileUrl = Uri.parse('$serverRoot/uploads/$fileName');

    final ok = await launchUrl(fileUrl, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Impossible d\'ouvrir le fichier : $fileUrl')));
    }
  }

  @override
  Widget build(BuildContext c) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Référentiel documentaire (GED)')),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: load, child: const Text('Réessayer')),
          ]),
        ),
      );
    }

    final grouped = groupedDocuments();
    final knownGroups = _groupOrder.where((g) => grouped.containsKey(g)).toList();
    final unclassified = grouped[null] ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Référentiel documentaire (GED)')),
      body: documents.isEmpty
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.folder_off_outlined, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                const Text('Aucun document dans le GED pour le moment'),
              ]),
            )
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  for (final g in knownGroups) _groupSection(_groupLabels[g]!, _groupIcons[g]!, grouped[g]!),
                  if (unclassified.isNotEmpty) _groupSection('Non classés', Icons.help_outline, unclassified),
                ],
              ),
            ),
    );
  }

  Widget _groupSection(String label, IconData icon, List docs) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ExpansionTile(
          leading: Icon(icon, color: Colors.indigo),
          title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('${docs.length} document(s)'),
          initiallyExpanded: true,
          children: docs.map<Widget>((d) {
            final versions = List.from(d['versions'] ?? []);
            final ext = versions.isNotEmpty ? '${versions.last['fileName']}'.split('.').last.toUpperCase() : '';
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: ext == 'XLSX' ? Colors.green.shade100 : Colors.blue.shade100,
                child: Text(ext.isEmpty ? '?' : ext.substring(0, ext.length > 3 ? 3 : ext.length), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              title: Text('${d['title']}'),
              subtitle: Text('${d['code']} • v${d['currentVersion']} • ${d['status']}'),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => openLatestVersion(d),
            );
          }).toList(),
        ),
      );
}
