import 'package:flutter/material.dart';
import '../services/api.dart';
import '../services/sync_queue.dart';
import '../main.dart';
import 'attachment_helpers.dart';

const _ncStatuses = ['OPEN', 'IN_PROGRESS', 'CLOSED'];
const _ncStatusLabels = {'OPEN': 'Ouverte', 'IN_PROGRESS': 'En cours', 'CLOSED': 'Clôturée'};

class NonConformitiesPage extends StatefulWidget {
  const NonConformitiesPage({super.key});
  @override
  State<NonConformitiesPage> createState() => _NonConformitiesPageState();
}

class _NonConformitiesPageState extends State<NonConformitiesPage> {
  final api = Api();
  List items = [];
  bool loading = true;
  String? filter;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final q = filter != null ? '?status=$filter' : '';
      items = List.from(await api.get('/business/non-conformities$q'));
    } catch (_) {}
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Non-conformités')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const NewNonConformityPage())).then((_) => load()),
      icon: const Icon(Icons.add),
      label: const Text('Déclarer une NC'),
    ),
    body: Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(spacing: 8, children: [
          ChoiceChip(label: const Text('Toutes'), selected: filter == null, onSelected: (_) { filter = null; load(); }),
          for (final s in _ncStatuses)
            ChoiceChip(label: Text(_ncStatusLabels[s]!), selected: filter == s, onSelected: (_) { filter = s; load(); }),
        ]),
      ),
      Expanded(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: load,
                child: items.isEmpty
                    ? ListView(children: const [Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Aucune non-conformité')))])
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: items.length,
                        itemBuilder: (_, i) {
                          final n = items[i];
                          final actions = List.from(n['actions'] ?? []);
                          return Card(
                            child: ListTile(
                              title: Text('${n['code']} — ${n['title']}'),
                              subtitle: Text('${_ncStatusLabels[n['status']] ?? n['status']} • ${actions.length} action(s)'),
                              trailing: severityChip(n['severity'] ?? 1, prefix: ''),
                              onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => NonConformityDetailPage(nc: n))).then((_) => load()),
                            ),
                          );
                        },
                      ),
              ),
      ),
    ]),
  );
}

class NewNonConformityPage extends StatefulWidget {
  const NewNonConformityPage({super.key});
  @override
  State<NewNonConformityPage> createState() => _NewNonConformityPageState();
}

class _NewNonConformityPageState extends State<NewNonConformityPage> {
  final api = Api();
  final title = TextEditingController();
  final description = TextEditingController();
  final source = TextEditingController(text: 'Terrain');
  int severity = 2;
  bool busy = false;

  Future<void> submit() async {
    if (title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le titre est obligatoire')));
      return;
    }
    setState(() => busy = true);
    final payload = {
      'code': genCode('NC'),
      'title': title.text.trim(),
      'description': description.text.trim().isEmpty ? null : description.text.trim(),
      'severity': severity,
      'source': source.text.trim(),
      'occurredAt': DateTime.now().toIso8601String(),
    };
    try {
      await api.post('/business/non-conformities', payload);
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (e.networkError) {
        await SyncQueue.enqueue('nonConformity', 'CREATE', payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pas de réseau : NC enregistrée hors-ligne, elle sera synchronisée automatiquement.'), duration: Duration(seconds: 4)));
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
    appBar: AppBar(title: const Text('Nouvelle non-conformité')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(controller: title, decoration: const InputDecoration(labelText: 'Titre')),
        const SizedBox(height: 12),
        TextField(controller: description, maxLines: 4, decoration: const InputDecoration(labelText: 'Description')),
        const SizedBox(height: 12),
        TextField(controller: source, decoration: const InputDecoration(labelText: 'Origine (terrain, audit, client...)')),
        const SizedBox(height: 12),
        Text('Sévérité : $severity', style: const TextStyle(fontWeight: FontWeight.bold)),
        Slider(value: severity.toDouble(), min: 1, max: 5, divisions: 4, label: '$severity', onChanged: (v) => setState(() => severity = v.round())),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : submit, child: Text(busy ? 'Envoi...' : 'Enregistrer'))),
      ],
    ),
  );
}

class NonConformityDetailPage extends StatefulWidget {
  final Map nc;
  const NonConformityDetailPage({super.key, required this.nc});
  @override
  State<NonConformityDetailPage> createState() => _NonConformityDetailPageState();
}

class _NonConformityDetailPageState extends State<NonConformityDetailPage> {
  final api = Api();
  late Map nc = widget.nc;
  bool busy = false;
  List<dynamic> suggestions = [];
  bool loadingSuggestions = true;

  @override
  void initState() {
    super.initState();
    loadSuggestions();
  }

  Future<void> loadSuggestions() async {
    try {
      final r = await api.post('/recommendations/suggest', {'title': nc['title'], 'description': nc['description']});
      suggestions = List.from(r['suggestions'] ?? []);
    } catch (_) {}
    setState(() => loadingSuggestions = false);
  }

  Future<void> patchStatus(String status) async {
    setState(() => busy = true);
    try {
      await api.patch('/business/non-conformities/${nc['id']}', {'status': status});
      setState(() => nc = {...nc, 'status': status});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    setState(() => busy = false);
  }

  Future<void> createAction(String initialTitle) async {
    final t = TextEditingController(text: initialTitle);
    final r = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nouvelle action corrective'),
        content: TextField(controller: t, maxLines: 2, decoration: const InputDecoration(labelText: 'Titre de l\'action (modifiable)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Refuser')),
          FilledButton(onPressed: () => Navigator.pop(context, t.text), child: const Text('Accepter')),
        ],
      ),
    );
    if (r == null || r.trim().isEmpty) return;
    try {
      final due = DateTime.now().add(const Duration(days: 7));
      final a = await api.post('/business/actions', {
        'code': genCode('ACT'),
        'title': r.trim(),
        'status': 'OPEN',
        'priority': 2,
        'dueDate': due.toIso8601String(),
        'nonConformityId': nc['id'],
      });
      setState(() { final acts = List.from(nc['actions'] ?? [])..add(a); nc = {...nc, 'actions': acts}; });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> addAction() => createAction('');

  @override
  Widget build(BuildContext c) {
    final actions = List.from(nc['actions'] ?? []);
    return Scaffold(
      appBar: AppBar(title: Text('${nc['code']}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('${nc['title']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (nc['description'] != null) Text('${nc['description']}'),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            for (final s in _ncStatuses)
              ChoiceChip(label: Text(_ncStatusLabels[s]!), selected: nc['status'] == s, onSelected: busy ? null : (_) => patchStatus(s)),
          ]),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => captureAndLinkPhoto(context, api, 'NON_CONFORMITY', nc['id']),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Ajouter une photo'),
          ),
          const SizedBox(height: 20),
          if (!loadingSuggestions && suggestions.isNotEmpty) ...[
            const Text('Suggestions du moteur de recommandations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('Proposées automatiquement à partir du type de non-conformité. La décision reste humaine : acceptez, modifiez, refusez ou ajoutez librement.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            ...suggestions.map((s) => Card(
                  color: Colors.indigo.withOpacity(0.04),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${s['category']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      ...List.from(s['actions'] ?? []).map((a) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(children: [
                              const Icon(Icons.arrow_right, size: 18),
                              Expanded(child: Text('$a', style: const TextStyle(fontSize: 13))),
                              IconButton(icon: const Icon(Icons.add_circle_outline, size: 20), tooltip: 'Accepter / modifier', onPressed: () => createAction('$a')),
                            ]),
                          )),
                    ]),
                  ),
                )),
            const SizedBox(height: 20),
          ],
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Actions correctives', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            TextButton.icon(onPressed: addAction, icon: const Icon(Icons.add), label: const Text('Ajouter')),
          ]),
          if (actions.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Aucune action pour l\'instant')),
          ...actions.map((a) => Card(child: ListTile(title: Text('${a['title']}'), subtitle: Text('${a['status']}')))),
        ],
      ),
    );
  }
}
