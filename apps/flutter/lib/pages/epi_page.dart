import 'package:flutter/material.dart';
import '../services/api.dart';
import '../main.dart';
import '../theme.dart';

class EpiPage extends StatefulWidget {
  const EpiPage({super.key});
  @override
  State<EpiPage> createState() => _EpiPageState();
}

class _EpiPageState extends State<EpiPage> {
  final api = Api();
  Map<String, dynamic>? dashboard;
  List renewals = [];
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
      final d = await api.get('/epi/dashboard');
      final r = await api.get('/epi/renewals?days=30');
      dashboard = Map<String, dynamic>.from(d);
      renewals = List.from(r);
    } catch (e) {
      error = 'Impossible de charger les données EPI';
    }
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext c) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gestion EPI')),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: load, child: const Text('Réessayer')),
          ]),
        ),
      );
    }

    final stock = List.from(dashboard?['stock'] ?? []);
    final headcount = dashboard?['effectiveHeadcount'];
    final daily = stock.where((e) => e['frequency'] == 'DAILY').toList();
    final annual = stock.where((e) => e['frequency'] == 'ANNUAL').toList();
    final enRupture = stock.where((e) => ((e['stock'] ?? 0) as num) <= ((e['minStock'] ?? 0) as num)).length;
    final kpis = [
      KpiStat('EPI suivis', '${stock.length}', color: QhseColors.blue, icon: Icons.inventory_2_outlined),
      KpiStat('En rupture', '$enRupture', color: enRupture > 0 ? QhseColors.red : QhseColors.green, icon: Icons.warning_amber_outlined),
      KpiStat('Renouvellements', '${renewals.length}', color: QhseColors.amber, icon: Icons.event_repeat),
      KpiStat('Effectif du jour', '${headcount ?? '—'}', color: QhseColors.blue, icon: Icons.groups_outlined),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Gestion EPI')),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.only(top: 12, bottom: 12),
          children: [
            KpiBar(kpis),
            const SizedBox(height: 16),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('EPI journaliers (gants, cache-nez, charlotte…)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 6),
            ...daily.map((e) => _epiCard(e)),
            if (daily.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Aucun EPI journalier configuré')),
            const SizedBox(height: 16),
            const Text('EPI annuels (chaussures, tenue, lunettes, casque…)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 6),
            ...annual.map((e) => _epiCard(e)),
            if (annual.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Aucun EPI annuel configuré')),
            const SizedBox(height: 20),
            const Text('Renouvellements à prévoir (30 jours)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 6),
            if (renewals.isEmpty)
              const Padding(padding: EdgeInsets.all(8), child: Text('Aucun renouvellement à prévoir 👍')),
            ...renewals.map((r) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.event_repeat, color: Colors.orange),
                    title: Text('${r['employee']?['firstName'] ?? ''} ${r['employee']?['lastName'] ?? ''}'),
                    subtitle: Text('${r['epi']?['name'] ?? ''} • échéance ${_date(r['renewalAt'])}'),
                  ),
                )),
            ])),
          ],
        ),
      ),
    );
  }

  Widget _epiCard(dynamic e) {
    final stock = (e['stock'] ?? 0) as num;
    final minStock = (e['minStock'] ?? 0) as num;
    final low = stock <= minStock;
    return Card(
      child: ListTile(
        leading: Icon(Icons.inventory_2, color: low ? Colors.red : Colors.green),
        title: Text('${e['name']}'),
        subtitle: Text(
          e['frequency'] == 'DAILY'
              ? 'Stock restant : $stock • distribués aujourd\'hui : ${e['dailyDistributed'] ?? 0}'
              : 'Stock restant : $stock',
        ),
        trailing: low ? const Chip(label: Text('Stock bas'), backgroundColor: Color(0xFFFFCDD2)) : null,
      ),
    );
  }

  String _date(dynamic v) => v == null ? '' : v.toString().substring(0, 10);
}
