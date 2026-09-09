import 'package:flutter/material.dart';
import '../services/api.dart';
import '../theme.dart';
import 'epi_epc_pages.dart';

class EpiPage extends StatefulWidget {
  const EpiPage({super.key});
  @override
  State<EpiPage> createState() => _EpiPageState();
}

class _EpiPageState extends State<EpiPage> with SingleTickerProviderStateMixin {
  final api = Api();
  Map<String, dynamic>? dashboard;
  List renewals = [];
  bool loading = true;
  String? error;
  late final TabController _tabController;

  static const _tabs = ['Stock EPI', 'Bibliothèque EPC', 'Catégories', 'Attribution', 'Inspections', 'Matrice Poste/Risque', 'Personnel', 'Renouvellements'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    load();
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

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
        appBar: AppBar(title: const Text('Gestion EPI/EPC')),
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
      appBar: AppBar(
        title: const Text('Gestion EPI/EPC'),
        bottom: TabBar(controller: _tabController, isScrollable: true, tabs: _tabs.map((t) => Tab(text: t)).toList()),
      ),
      body: Column(children: [
        Padding(padding: const EdgeInsets.only(top: 12), child: KpiBar(kpis)),
        Expanded(
          child: TabBarView(controller: _tabController, children: [
            const EpiLibraryTab(),
            const EpcLibraryTab(),
            DefaultTabController(
              length: 2,
              child: Column(children: [
                const TabBar(tabs: [Tab(text: 'Catégories EPI'), Tab(text: 'Catégories EPC')]),
                const Expanded(child: TabBarView(children: [
                  CategoryListTab(endpoint: '/epi/epi-categories', label: 'EPI'),
                  CategoryListTab(endpoint: '/epi/epc-categories', label: 'EPC'),
                ])),
              ]),
            ),
            const AttributionTab(),
            const InspectionsTab(),
            const MatrixTab(),
            const EmployeeTab(),
            const RenewalBucketsTab(),
          ]),
        ),
      ]),
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
