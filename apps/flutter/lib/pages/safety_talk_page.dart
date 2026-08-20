import 'package:flutter/material.dart';
import '../services/api.dart';

const _statusLabels = {'DRAFT': 'Brouillon', 'APPROVED': 'Validé', 'DELIVERED': 'Animé'};
const _statusColors = {'DRAFT': Colors.grey, 'APPROVED': Colors.orange, 'DELIVERED': Colors.green};

class SafetyTalkPage extends StatefulWidget {
  const SafetyTalkPage({super.key});
  @override
  State<SafetyTalkPage> createState() => _SafetyTalkPageState();
}

class _SafetyTalkPageState extends State<SafetyTalkPage> {
  final api = Api();
  List talks = [];
  bool loading = true;
  bool generating = false;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() => loading = true);
    try { talks = List.from(await api.get('/safety-talks')); } catch (_) {}
    setState(() => loading = false);
  }

  Future<void> generate() async {
    setState(() => generating = true);
    try {
      await api.post('/safety-talks/generate', {});
      await load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    setState(() => generating = false);
  }

  Future<void> approve(String id) async {
    try { await api.post('/safety-talks/$id/approve', {}); load(); } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  Future<void> deliver(String id) async {
    try { await api.post('/safety-talks/$id/deliver', {}); load(); } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Quart d\'heure sécurité')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: generating ? null : generate,
      icon: generating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.auto_awesome),
      label: Text(generating ? 'Génération...' : 'Générer le thème de la semaine'),
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: load,
            child: talks.isEmpty
                ? ListView(children: const [
                    Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('Aucun quart d\'heure sécurité généré.\nUtilisez le bouton ci-dessous pour créer celui de la semaine, à partir des accidents, incidents et non-conformités critiques réels des 7 derniers jours.', textAlign: TextAlign.center)),
                    ),
                  ])
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                    itemCount: talks.length,
                    itemBuilder: (_, i) {
                      final t = talks[i];
                      final color = _statusColors[t['status']] ?? Colors.grey;
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(child: Text('${t['title']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                              Chip(label: Text(_statusLabels[t['status']] ?? t['status']), backgroundColor: color.withOpacity(0.15), labelStyle: TextStyle(color: color)),
                            ]),
                            const SizedBox(height: 4),
                            Text('Semaine du ${_date(t['weekStart'])}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            const SizedBox(height: 8),
                            Text('${t['summary']}'),
                            const SizedBox(height: 10),
                            Row(children: [
                              if (t['status'] == 'DRAFT') TextButton.icon(onPressed: () => approve(t['id']), icon: const Icon(Icons.check), label: const Text('Valider')),
                              if (t['status'] == 'APPROVED') TextButton.icon(onPressed: () => deliver(t['id']), icon: const Icon(Icons.campaign), label: const Text('Marquer comme animé')),
                            ]),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
  );

  String _date(dynamic v) => v == null ? '' : v.toString().substring(0, 10);
}
