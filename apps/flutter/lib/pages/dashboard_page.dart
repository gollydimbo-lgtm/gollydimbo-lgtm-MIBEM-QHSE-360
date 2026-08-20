import 'package:flutter/material.dart';
import '../services/api.dart';
import '../main.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final api = Api();
  Map<String, dynamic>? data;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final r = await api.get('/dashboard');
      data = Map<String, dynamic>.from(r);
    } catch (e) {
      error = 'Impossible de charger le tableau de bord';
    }
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext c) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: load, child: const Text('Réessayer')),
        ]),
      );
    }

    final counters = Map<String, dynamic>.from(data?['overview']?['counters'] ?? {});
    final indicators = Map<String, dynamic>.from(data?['overview']?['indicators'] ?? {});
    final alerts = List.from(data?['alerts'] ?? []);

    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Text('Tableau de bord QHSE', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: [
            _kpi('NC ouvertes', counters['nonConformitiesOpen'], Colors.red),
            _kpi('Actions en retard', counters['actionsOverdue'], Colors.deepOrange),
            _kpi('Événements sécurité (30j)', counters['safetyEvents30d'], Colors.orange),
            _kpi('Risques élevés', counters['risksHigh'], Colors.purple),
            _kpi('Audits planifiés', counters['auditsPlanned'], Colors.blue),
            _kpi('Documents à valider', counters['documentsPendingApproval'], Colors.teal),
          ]),
          const SizedBox(height: 20),
          const Text('Indicateurs QHSE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _indicatorCard('Qualité', 'Conformité 30j', indicators['qualite']?['tauxConformite'], '%')),
            const SizedBox(width: 8),
            Expanded(child: _indicatorCard('Sécurité', 'Événements 30j', indicators['securite']?['evenements30j'], '')),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _indicatorCard('Environnement', 'Relevés 30j', indicators['environnement']?['releves30j'], '')),
            const SizedBox(width: 8),
            Expanded(child: _indicatorCard('RH', 'EPI à renouveler', indicators['rh']?['epiARenouvelerSous30j'], '')),
          ]),
          const SizedBox(height: 20),
          const Text('Actions prioritaires', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          if (alerts.isEmpty)
            const Padding(padding: EdgeInsets.all(8), child: Text('Aucune alerte en cours 🎉')),
          ...alerts.map((a) => Card(
                child: ListTile(
                  leading: Text(a['icon'] ?? '🔵', style: const TextStyle(fontSize: 22)),
                  title: Text('${a['title'] ?? ''}'),
                  subtitle: Text('${a['domain'] ?? ''} • ${a['detail'] ?? ''}'),
                  trailing: a['code'] != null ? Text('${a['code']}', style: const TextStyle(fontSize: 12, color: Colors.grey)) : null,
                ),
              )),
        ],
      ),
    );
  }

  Widget _kpi(String label, dynamic value, Color color) => SizedBox(
        width: 160,
        child: Card(
          color: color.withOpacity(0.08),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${value ?? 0}', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 12)),
            ]),
          ),
        ),
      );

  Widget _indicatorCard(String title, String label, dynamic value, String suffix) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('${value ?? '-'}$suffix', style: const TextStyle(fontSize: 20)),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
        ),
      );
}
