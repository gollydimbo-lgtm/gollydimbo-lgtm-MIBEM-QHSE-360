import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../shared/widgets/metric_card.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  DashboardOverview? _overview;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiClient>();
      final json = await api.get('/api/dashboard/overview');
      setState(() => _overview = DashboardOverview.fromJson(json));
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _overview;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Tableau de bord QHSE', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Connexion API impossible : $_error'),
              ),
            ),
          if (d != null)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                MetricCard('Contrôles', '${d.controls}'),
                MetricCard(
                  'Conformité',
                  '${d.complianceRate.toStringAsFixed(1)} %',
                  valueColor: d.complianceRate >= 95 ? Colors.green : Colors.orange,
                ),
                MetricCard('NC ouvertes', '${d.openNonConformities}',
                    valueColor: d.openNonConformities > 0 ? Colors.orange : Colors.green),
                MetricCard('NC critiques', '${d.criticalNonConformities}',
                    valueColor: d.criticalNonConformities > 0 ? Colors.red : Colors.green),
                MetricCard('Actions', '${d.actions}'),
                MetricCard('Actions en retard', '${d.overdueActions}',
                    valueColor: d.overdueActions > 0 ? Colors.red : Colors.green),
                if (d.pendingSync > 0)
                  MetricCard('En attente de sync', '${d.pendingSync}', valueColor: Colors.blueGrey),
              ],
            ),
        ],
      ),
    );
  }
}
