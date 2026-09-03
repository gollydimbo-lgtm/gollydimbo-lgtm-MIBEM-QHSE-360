import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api.dart';
import '../theme.dart';

/// Tableau de bord — reprend le langage visuel du dashboard web (dark
/// premium, code couleur QHSE strict) mais branché sur les vraies données
/// de l'API (/dashboard), pas des données fictives.
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
  void initState() { super.initState(); load(); }

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
          Text(error!, style: const TextStyle(color: QhseColors.red)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: load, child: const Text('Réessayer')),
        ]),
      );
    }

    final counters = Map<String, dynamic>.from(data?['overview']?['counters'] ?? {});
    final indicators = Map<String, dynamic>.from(data?['overview']?['indicators'] ?? {});
    final alerts = List.from(data?['alerts'] ?? []);
    final trends = Map<String, dynamic>.from(data?['trends'] ?? {});
    final ncSeries = List.from(trends['nonConformitesParSemaine'] ?? []);
    final eventSeries = List.from(trends['evenementsSecuriteParSemaine'] ?? []);
    final severityBreakdown = List.from(counters['safetyEventsBySeverity'] ?? []);

    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Tableau de bord QHSE', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: QhseColors.textPrimary)),
          const SizedBox(height: 4),
          const Text('Pilotez la conformité, en temps réel.', style: TextStyle(fontSize: 12, color: QhseColors.textSecondary)),
          const SizedBox(height: 16),

          Wrap(spacing: 10, runSpacing: 10, children: [
            _kpi('NC ouvertes', counters['nonConformitiesOpen'], 'Objectif : 0', QhseColors.red, Icons.report_gmailerrorred),
            _kpi('Actions en retard', counters['actionsOverdue'], 'Objectif : 0', QhseColors.red, Icons.schedule),
            _kpi('Événements sécurité', counters['safetyEvents30d'], '30 derniers jours', QhseColors.amber, Icons.warning_amber_rounded),
            _kpi('Risques élevés', counters['risksHigh'], 'Score ≥ 9', QhseColors.red, Icons.dangerous_outlined),
            _kpi('Audits planifiés', counters['auditsPlanned'], '${counters['auditsUpcoming7d'] ?? 0} sous 7 jours', QhseColors.blue, Icons.fact_check_outlined),
            _kpi('Documents à valider', counters['documentsPendingApproval'], 'GED', QhseColors.blue, Icons.folder_outlined),
          ]),
          const SizedBox(height: 20),

          _panel(
            title: 'Évolution des non-conformités & événements sécurité',
            subtitle: '8 dernières semaines',
            child: SizedBox(
              height: 200,
              child: (ncSeries.isEmpty && eventSeries.isEmpty)
                  ? const Center(child: Text('Pas encore assez de données', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
                  : _TrendLineChart(ncSeries: ncSeries, eventSeries: eventSeries),
            ),
          ),
          const SizedBox(height: 16),

          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: _panel(
                title: 'Répartition des événements sécurité',
                subtitle: 'Par sévérité (30j)',
                child: SizedBox(
                  height: 180,
                  child: severityBreakdown.isEmpty
                      ? const Center(child: Text('Aucun événement', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
                      : _SeverityDonut(data: severityBreakdown),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _panel(
                title: 'Indicateurs QHSE',
                subtitle: 'Vue synthétique',
                child: Column(children: [
                  _indicatorBar('Qualité', 'Conformité 30j', indicators['qualite']?['tauxConformite'], '%', QhseColors.green),
                  const SizedBox(height: 10),
                  _indicatorBar('Sécurité', 'Événements 30j', indicators['securite']?['evenements30j'], '', QhseColors.amber),
                  const SizedBox(height: 10),
                  _indicatorBar('Environnement', 'Relevés 30j', indicators['environnement']?['releves30j'], '', QhseColors.blue),
                  const SizedBox(height: 10),
                  _indicatorBar('RH', 'EPI à renouveler', indicators['rh']?['epiARenouvelerSous30j'], '', QhseColors.red),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 16),

          _panel(
            title: 'Actions prioritaires',
            child: alerts.isEmpty
                ? const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Aucune alerte en cours 🎉', style: TextStyle(color: QhseColors.textSecondary)))
                : Column(
                    children: alerts.map<Widget>((a) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: QhseColors.cardAlt, borderRadius: BorderRadius.circular(10), border: Border.all(color: QhseColors.border)),
                          child: Row(children: [
                            Text(a['icon'] ?? '🔵', style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('${a['title'] ?? ''}', style: const TextStyle(color: QhseColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                                Text('${a['domain'] ?? ''} • ${a['detail'] ?? ''}', style: const TextStyle(color: QhseColors.textSecondary, fontSize: 11)),
                              ]),
                            ),
                            if (a['code'] != null) Text('${a['code']}', style: const TextStyle(fontSize: 11, color: QhseColors.textSecondary)),
                          ]),
                        )).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _panel({required String title, String? subtitle, required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: QhseColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: QhseColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: QhseColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          if (subtitle != null) Text(subtitle, style: const TextStyle(color: QhseColors.textSecondary, fontSize: 11)),
          const SizedBox(height: 10),
          child,
        ]),
      );

  Widget _kpi(String label, dynamic value, String objectif, Color color, IconData icon) => Container(
        width: 155,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.25))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(label.toUpperCase(), style: TextStyle(fontSize: 10, letterSpacing: 0.3, color: color, fontWeight: FontWeight.w600)),
            Icon(icon, size: 15, color: color),
          ]),
          const SizedBox(height: 6),
          Text('${value ?? 0}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: QhseColors.textPrimary)),
          const SizedBox(height: 2),
          Text(objectif, style: const TextStyle(fontSize: 10, color: QhseColors.textSecondary)),
        ]),
      );

  Widget _indicatorBar(String title, String label, dynamic value, String suffix, Color color) {
    final display = value == null ? '-' : '$value$suffix';
    final numeric = (value is num) ? value.toDouble() : 0.0;
    final pct = suffix == '%' ? (numeric / 100).clamp(0.0, 1.0) : (numeric / 30).clamp(0.0, 1.0);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(title, style: const TextStyle(fontSize: 12, color: QhseColors.textPrimary, fontWeight: FontWeight.w500)),
        Text(display, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(value: pct, minHeight: 5, backgroundColor: QhseColors.border, valueColor: AlwaysStoppedAnimation(color)),
      ),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 10, color: QhseColors.textSecondary)),
    ]);
  }
}

/// Courbe NC / événements sécurité sur 8 semaines (fl_chart LineChart).
class _TrendLineChart extends StatelessWidget {
  final List ncSeries;
  final List eventSeries;
  const _TrendLineChart({required this.ncSeries, required this.eventSeries});

  List<FlSpot> _toSpots(List series) => [
        for (int i = 0; i < series.length; i++) FlSpot(i.toDouble(), ((series[i]['count'] ?? 0) as num).toDouble()),
      ];

  String _weekLabel(List series, int index) {
    if (index < 0 || index >= series.length) return '';
    final raw = '${series[index]['weekStart'] ?? ''}';
    if (raw.length < 10) return raw;
    return '${raw.substring(8, 10)}/${raw.substring(5, 7)}';
  }

  @override
  Widget build(BuildContext context) {
    final ncSpots = _toSpots(ncSeries);
    final eventSpots = _toSpots(eventSeries);
    final labelSeries = ncSeries.isNotEmpty ? ncSeries : eventSeries;
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: QhseColors.border, strokeWidth: 1)),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 26, getTitlesWidget: (v, m) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 9, color: QhseColors.textSecondary)))),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, interval: 1, getTitlesWidget: (v, m) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_weekLabel(labelSeries, v.toInt()), style: const TextStyle(fontSize: 9, color: QhseColors.textSecondary)),
              ))),
        ),
        lineBarsData: [
          if (ncSpots.isNotEmpty)
            LineChartBarData(spots: ncSpots, isCurved: true, color: QhseColors.red, barWidth: 2, dotData: const FlDotData(show: true), belowBarData: BarAreaData(show: true, color: QhseColors.red.withOpacity(0.08))),
          if (eventSpots.isNotEmpty)
            LineChartBarData(spots: eventSpots, isCurved: true, color: QhseColors.amber, barWidth: 2, dotData: const FlDotData(show: true), belowBarData: BarAreaData(show: true, color: QhseColors.amber.withOpacity(0.08))),
        ],
      ),
    );
  }
}

/// Répartition des événements sécurité par sévérité, en anneau (fl_chart PieChart).
class _SeverityDonut extends StatelessWidget {
  final List data;
  const _SeverityDonut({required this.data});

  Color _colorFor(int severity) {
    if (severity >= 4) return QhseColors.red;
    if (severity == 3) return QhseColors.amber;
    return QhseColors.blue;
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: PieChart(
          PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 34,
            sections: [
              for (final s in data)
                PieChartSectionData(
                  value: ((s['count'] ?? 0) as num).toDouble(),
                  color: _colorFor((s['severity'] ?? 1) as int),
                  radius: 34,
                  title: '${s['count']}',
                  titleStyle: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(width: 8),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final s in data)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: _colorFor((s['severity'] ?? 1) as int), shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text('Sévérité ${s['severity']}', style: const TextStyle(fontSize: 10, color: QhseColors.textSecondary)),
              ]),
            ),
        ],
      ),
    ]);
  }
}
