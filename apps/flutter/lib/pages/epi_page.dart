import 'package:flutter/material.dart';
import '../services/api.dart';
import '../theme.dart';
import '../i18n/i18n.dart';
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

  static List<String> get _tabs => [
    t('epiPageFlt.tabStockEpi'), t('epiPageFlt.tabBibliothequeEpc'), t('epiPageFlt.tabCategories'), t('epiPageFlt.tabAttribution'),
    t('epiPageFlt.tabInspections'), t('epiPageFlt.tabMaintenanceEpc'), t('epiPageFlt.tabMatricePosteRisque'), t('epiPageFlt.tabPersonnel'), t('epiPageFlt.tabRenouvellements'),
  ];

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
      error = t('epiPageFlt.erreurChargement');
    }
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext c) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(t('epiPageFlt.titre'))),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: load, child: Text(t('epiPageFlt.reessayer'))),
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
      KpiStat(t('epiPageFlt.kpiEpiSuivis'), '${stock.length}', color: QhseColors.blue, icon: Icons.inventory_2_outlined),
      KpiStat(t('epiPageFlt.kpiEnRupture'), '$enRupture', color: enRupture > 0 ? QhseColors.red : QhseColors.green, icon: Icons.warning_amber_outlined),
      KpiStat(t('epiPageFlt.kpiRenouvellements'), '${renewals.length}', color: QhseColors.amber, icon: Icons.event_repeat),
      KpiStat(t('epiPageFlt.kpiEffectifDuJour'), '${headcount ?? '—'}', color: QhseColors.blue, icon: Icons.groups_outlined),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(t('epiPageFlt.titre')),
        bottom: TabBar(controller: _tabController, isScrollable: true, tabs: _tabs.map((tab) => Tab(text: tab)).toList()),
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
                TabBar(tabs: [Tab(text: t('epiPageFlt.categoriesEpi')), Tab(text: t('epiPageFlt.categoriesEpc'))]),
                const Expanded(child: TabBarView(children: [
                  CategoryListTab(endpoint: '/epi/epi-categories', label: 'EPI'),
                  CategoryListTab(endpoint: '/epi/epc-categories', label: 'EPC'),
                ])),
              ]),
            ),
            const AttributionTab(),
            const InspectionsTab(),
            const EpcMaintenanceTab(),
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
              ? t('epiPageFlt.stockRestantDistribues', {'stock': '$stock', 'distribues': '${e['dailyDistributed'] ?? 0}'})
              : t('epiPageFlt.stockRestant', {'stock': '$stock'}),
        ),
        trailing: low ? Chip(label: Text(t('epiPageFlt.stockBas')), backgroundColor: const Color(0xFFFFCDD2)) : null,
      ),
    );
  }

  String _date(dynamic v) => v == null ? '' : v.toString().substring(0, 10);
}
