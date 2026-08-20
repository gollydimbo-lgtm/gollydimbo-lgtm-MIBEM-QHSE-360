import 'package:flutter/material.dart';
import '../services/api.dart';
import '../services/sync_queue.dart';
import '../main.dart';
import 'attachment_helpers.dart';

const _types = {
  'ACCIDENT': ('Accident', Icons.local_hospital, Colors.red),
  'INCIDENT': ('Incident', Icons.report_problem, Colors.deepOrange),
  'PRESQU_ACCIDENT': ('Presqu\'accident', Icons.warning_amber, Colors.orange),
  'SITUATION_DANGEREUSE': ('Situation dangereuse', Icons.dangerous, Colors.amber),
};

class SafetyEventsPage extends StatefulWidget {
  const SafetyEventsPage({super.key});
  @override
  State<SafetyEventsPage> createState() => _SafetyEventsPageState();
}

class _SafetyEventsPageState extends State<SafetyEventsPage> {
  final api = Api();
  List events = [];
  bool loading = true;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try { events = List.from(await api.get('/business/safety-events')); } catch (_) {}
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Accidents & situations dangereuses')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const NewSafetyEventPage())).then((_) => load()),
      icon: const Icon(Icons.add),
      label: const Text('Déclarer'),
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: load,
            child: events.isEmpty
                ? ListView(children: const [Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Aucun événement déclaré')))])
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: events.length,
                    itemBuilder: (_, i) {
                      final e = events[i];
                      final meta = _types[e['type']] ?? ('${e['type']}', Icons.info, Colors.grey);
                      return Card(
                        child: ListTile(
                          leading: Icon(meta.$2, color: meta.$3, size: 32),
                          title: Text('${e['title']}'),
                          subtitle: Text('${meta.$1} • ${_date(e['occurredAt'])}'),
                          trailing: severityChip(e['severity'] ?? 1, prefix: ''),
                        ),
                      );
                    },
                  ),
          ),
  );

  String _date(dynamic v) => v == null ? '' : v.toString().substring(0, 16).replaceFirst('T', ' ');
}

class NewSafetyEventPage extends StatefulWidget {
  const NewSafetyEventPage({super.key});
  @override
  State<NewSafetyEventPage> createState() => _NewSafetyEventPageState();
}

class _NewSafetyEventPageState extends State<NewSafetyEventPage> {
  final api = Api();
  final title = TextEditingController();
  final description = TextEditingController();
  String type = 'ACCIDENT';
  int severity = 2;
  double? lat, lon;
  bool busy = false;
  String? createdId;

  Future<void> gps() async {
    final p = await captureGps(context);
    if (p != null) setState(() { lat = p.latitude; lon = p.longitude; });
  }

  Future<void> submit() async {
    if (title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le titre est obligatoire')));
      return;
    }
    setState(() => busy = true);
    var desc = description.text;
    if (lat != null) desc = '$desc\n[GPS ${lat!.toStringAsFixed(5)}, ${lon!.toStringAsFixed(5)}]'.trim();
    final payload = {
      'type': type,
      'title': title.text.trim(),
      'description': desc.isEmpty ? null : desc,
      'occurredAt': DateTime.now().toIso8601String(),
      'severity': severity,
    };
    try {
      final r = await api.post('/business/safety-events', payload);
      setState(() => createdId = r['id']);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Déclaration enregistrée')));
    } on ApiException catch (e) {
      if (e.networkError) {
        await SyncQueue.enqueue('safetyEvent', 'CREATE', payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pas de réseau : déclaration enregistrée hors-ligne, elle sera synchronisée automatiquement.'), duration: Duration(seconds: 4)));
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

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Nouvelle déclaration')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          value: type,
          decoration: const InputDecoration(labelText: 'Type d\'événement'),
          items: _types.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value.$1))).toList(),
          onChanged: createdId == null ? (v) => setState(() => type = v!) : null,
        ),
        const SizedBox(height: 12),
        TextField(controller: title, enabled: createdId == null, decoration: const InputDecoration(labelText: 'Titre / résumé')),
        const SizedBox(height: 12),
        TextField(controller: description, enabled: createdId == null, maxLines: 4, decoration: const InputDecoration(labelText: 'Description, circonstances, témoins...')),
        const SizedBox(height: 12),
        Text('Sévérité : $severity', style: const TextStyle(fontWeight: FontWeight.bold)),
        Slider(value: severity.toDouble(), min: 1, max: 5, divisions: 4, label: '$severity', onChanged: createdId == null ? (v) => setState(() => severity = v.round()) : null),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: createdId == null ? gps : null,
          icon: const Icon(Icons.gps_fixed),
          label: Text(lat == null ? 'Capturer la position GPS' : 'GPS ${lat!.toStringAsFixed(5)}, ${lon!.toStringAsFixed(5)}'),
        ),
        const SizedBox(height: 20),
        if (createdId == null)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy ? null : submit,
              icon: const Icon(Icons.send),
              label: Text(busy ? 'Envoi...' : 'Envoyer la déclaration'),
            ),
          )
        else ...[
          const Text('✅ Déclaration enregistrée. Vous pouvez joindre une ou plusieurs photos.', style: TextStyle(color: Colors.green)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => captureAndLinkPhoto(context, api, 'SAFETY_EVENT', createdId!),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Ajouter une photo'),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Terminer')),
        ],
      ],
    ),
  );
}
