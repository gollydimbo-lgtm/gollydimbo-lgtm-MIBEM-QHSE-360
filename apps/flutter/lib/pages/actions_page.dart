import 'package:flutter/material.dart';
import '../services/api.dart';
import '../main.dart';
import '../theme.dart';

const _statuses = ['OPEN', 'IN_PROGRESS', 'CLOSED'];
const _labels = {'OPEN': 'Ouverte', 'IN_PROGRESS': 'En cours', 'CLOSED': 'Clôturée'};

class ActionsPage extends StatefulWidget {
  const ActionsPage({super.key});
  @override
  State<ActionsPage> createState() => _ActionsPageState();
}

class _ActionsPageState extends State<ActionsPage> {
  final api = Api();
  List items = [];
  bool loading = true;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() => loading = true);
    try { items = List.from(await api.get('/business/actions')); } catch (_) {}
    setState(() => loading = false);
  }

  Future<void> nextStatus(Map a) async {
    final i = _statuses.indexOf(a['status']);
    final next = _statuses[(i + 1).clamp(0, _statuses.length - 1)];
    if (next == a['status']) return;
    try {
      await api.patch('/business/actions/${a['id']}', {'status': next, if (next == 'CLOSED') 'completedAt': DateTime.now().toIso8601String()});
      load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  List<KpiStat> kpis(DateTime now) {
    final termine = items.where((a) => a['status'] == 'CLOSED').length;
    final enRetard = items.where((a) {
      final due = a['dueDate'] != null ? DateTime.tryParse(a['dueDate']) : null;
      return due != null && a['status'] != 'CLOSED' && due.isBefore(now);
    }).length;
    return [
      KpiStat('Actions totales', '${items.length}', color: QhseColors.blue, icon: Icons.build_outlined),
      KpiStat('Terminées', '$termine', color: QhseColors.green, icon: Icons.check_circle_outline),
      KpiStat('En retard', '$enRetard', color: QhseColors.red, icon: Icons.warning_amber_outlined),
    ];
  }

  @override
  Widget build(BuildContext c) {
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('Actions correctives')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: Column(children: [
                Padding(padding: const EdgeInsets.only(top: 12), child: KpiBar(kpis(now))),
                Expanded(
                  child: items.isEmpty
                      ? ListView(children: const [Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Aucune action')))])
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: items.length,
                          itemBuilder: (_, i) {
                            final a = items[i];
                            final due = a['dueDate'] != null ? DateTime.tryParse(a['dueDate']) : null;
                            final overdue = due != null && a['status'] != 'CLOSED' && due.isBefore(now);
                            return Card(
                              child: ListTile(
                                leading: Icon(
                                  a['status'] == 'CLOSED' ? Icons.check_circle : (overdue ? Icons.error : Icons.pending_actions),
                                  color: a['status'] == 'CLOSED' ? Colors.green : (overdue ? Colors.red : Colors.orange),
                                ),
                                title: Text('${a['code']} — ${a['title']}'),
                                subtitle: Text('${_labels[a['status']] ?? a['status']}${due != null ? ' • échéance ${due.toIso8601String().substring(0, 10)}' : ''}${overdue ? ' ⚠️ en retard' : ''}'),
                                trailing: a['status'] != 'CLOSED'
                                    ? TextButton(onPressed: () => nextStatus(a), child: Text(a['status'] == 'OPEN' ? 'Démarrer' : 'Clôturer'))
                                    : null,
                              ),
                            );
                          },
                        ),
                ),
              ]),
            ),
    );
  }
}
