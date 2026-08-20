import 'package:flutter/material.dart';
import '../services/api.dart';
import '../main.dart';
import 'attachment_helpers.dart';

const _auditStatusLabels = {'PLANNED': 'Planifié', 'IN_PROGRESS': 'En cours', 'DONE': 'Terminé'};

class AuditsPage extends StatefulWidget {
  const AuditsPage({super.key});
  @override
  State<AuditsPage> createState() => _AuditsPageState();
}

class _AuditsPageState extends State<AuditsPage> {
  final api = Api();
  List items = [];
  bool loading = true;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try { items = List.from(await api.get('/business/audits')); } catch (_) {}
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Audits QHSE')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const NewAuditPage())).then((_) => load()),
      icon: const Icon(Icons.add),
      label: const Text('Planifier un audit'),
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: load,
            child: items.isEmpty
                ? ListView(children: const [Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Aucun audit planifié')))])
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final a = items[i];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.assignment_turned_in, size: 32),
                          title: Text('${a['code']} — ${a['title']}'),
                          subtitle: Text('${_auditStatusLabels[a['status']] ?? a['status']} • ${_date(a['auditDate'])}'),
                          onTap: () => captureAndLinkPhoto(context, api, 'AUDIT', a['id']),
                        ),
                      );
                    },
                  ),
          ),
  );

  String _date(dynamic v) => v == null ? '' : v.toString().substring(0, 10);
}

class NewAuditPage extends StatefulWidget {
  const NewAuditPage({super.key});
  @override
  State<NewAuditPage> createState() => _NewAuditPageState();
}

class _NewAuditPageState extends State<NewAuditPage> {
  final api = Api();
  final title = TextEditingController();
  final reference = TextEditingController();
  DateTime auditDate = DateTime.now().add(const Duration(days: 7));
  bool busy = false;

  Future<void> pickDate() async {
    final d = await showDatePicker(context: context, initialDate: auditDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 730)));
    if (d != null) setState(() => auditDate = d);
  }

  Future<void> submit() async {
    if (title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le titre est obligatoire')));
      return;
    }
    setState(() => busy = true);
    try {
      await api.post('/business/audits', {
        'code': genCode('AUD'),
        'title': title.text.trim(),
        'reference': reference.text.trim().isEmpty ? null : reference.text.trim(),
        'auditDate': auditDate.toIso8601String(),
        'status': 'PLANNED',
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    setState(() => busy = false);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Planifier un audit')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(controller: title, decoration: const InputDecoration(labelText: 'Titre / périmètre de l\'audit')),
        const SizedBox(height: 12),
        TextField(controller: reference, decoration: const InputDecoration(labelText: 'Référentiel (ISO, interne...)')),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: pickDate, icon: const Icon(Icons.event), label: Text('Date : ${auditDate.toIso8601String().substring(0, 10)}')),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : submit, child: Text(busy ? 'Envoi...' : 'Planifier'))),
      ],
    ),
  );
}
