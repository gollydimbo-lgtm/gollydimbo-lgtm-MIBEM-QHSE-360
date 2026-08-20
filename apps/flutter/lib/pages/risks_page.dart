import 'package:flutter/material.dart';
import '../services/api.dart';
import '../services/sync_queue.dart';
import '../main.dart';
import 'attachment_helpers.dart';

class RisksPage extends StatefulWidget {
  const RisksPage({super.key});
  @override
  State<RisksPage> createState() => _RisksPageState();
}

class _RisksPageState extends State<RisksPage> {
  final api = Api();
  List items = [];
  bool loading = true;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try { items = List.from(await api.get('/business/risks')); } catch (_) {}
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Risques (DUERP)')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const NewRiskPage())).then((_) => load()),
      icon: const Icon(Icons.add),
      label: const Text('Nouveau risque'),
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: load,
            child: items.isEmpty
                ? ListView(children: const [Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Aucun risque enregistré')))])
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final r = items[i];
                      final score = (r['score'] ?? 0) as num;
                      final color = score >= 12 ? Colors.red : (score >= 6 ? Colors.orange : Colors.green);
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(backgroundColor: color, child: Text('$score', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          title: Text('${r['code']} — ${r['hazard']}'),
                          subtitle: Text('${r['activity'] ?? ''} • G${r['severity']}×P${r['probability']}×M${r['control']}'),
                          onTap: () => captureAndLinkPhoto(context, api, 'RISK', r['id']),
                        ),
                      );
                    },
                  ),
          ),
  );
}

class NewRiskPage extends StatefulWidget {
  const NewRiskPage({super.key});
  @override
  State<NewRiskPage> createState() => _NewRiskPageState();
}

class _NewRiskPageState extends State<NewRiskPage> {
  final api = Api();
  final hazard = TextEditingController();
  final activity = TextEditingController();
  final measures = TextEditingController();
  int severity = 2, probability = 2, control = 2;
  bool busy = false;

  int get score => severity * probability * control;

  Future<void> submit() async {
    if (hazard.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le danger est obligatoire')));
      return;
    }
    setState(() => busy = true);
    final payload = {
      'code': genCode('RISK'),
      'hazard': hazard.text.trim(),
      'activity': activity.text.trim().isEmpty ? null : activity.text.trim(),
      'severity': severity,
      'probability': probability,
      'control': control,
      'score': score,
      'measures': measures.text.trim().isEmpty ? null : measures.text.trim(),
    };
    try {
      await api.post('/business/risks', payload);
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (e.networkError) {
        await SyncQueue.enqueue('risk', 'CREATE', payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pas de réseau : risque enregistré hors-ligne, il sera synchronisé automatiquement.'), duration: Duration(seconds: 4)));
          Navigator.pop(context);
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    setState(() => busy = false);
  }

  Widget _slider(String label, int value, ValueChanged<int> onChanged) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label : $value / 5', style: const TextStyle(fontWeight: FontWeight.bold)),
          Slider(value: value.toDouble(), min: 1, max: 5, divisions: 4, label: '$value', onChanged: (v) => onChanged(v.round())),
        ],
      );

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Nouveau risque')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(controller: hazard, decoration: const InputDecoration(labelText: 'Danger identifié')),
        const SizedBox(height: 12),
        TextField(controller: activity, decoration: const InputDecoration(labelText: 'Activité / poste concerné')),
        const SizedBox(height: 12),
        _slider('Gravité', severity, (v) => setState(() => severity = v)),
        _slider('Probabilité', probability, (v) => setState(() => probability = v)),
        _slider('Maîtrise actuelle', control, (v) => setState(() => control = v)),
        const SizedBox(height: 8),
        Text('Score de criticité : $score', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: score >= 12 ? Colors.red : (score >= 6 ? Colors.orange : Colors.green))),
        const SizedBox(height: 12),
        TextField(controller: measures, maxLines: 3, decoration: const InputDecoration(labelText: 'Mesures de prévention envisagées')),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : submit, child: Text(busy ? 'Envoi...' : 'Enregistrer'))),
      ],
    ),
  );
}
