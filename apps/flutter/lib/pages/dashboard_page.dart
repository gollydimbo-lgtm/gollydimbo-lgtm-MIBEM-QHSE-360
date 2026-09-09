import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api.dart';
import '../theme.dart';

/// Tableau de bord — reproduit exactement la disposition du tableau de bord
/// web (Gestion QHSE 360) : mêmes cartes KPI, même graphique de tendance,
/// même indice composite, mêmes 3 panneaux de répartition. Branché sur les
/// mêmes routes réelles, pas de données fictives.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final api = Api();
  Map<String, dynamic>? data;
  List audits = [];
  List actions = [];
  List nonConformities = [];
  bool loading = true;
  String? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final r = await api.get('/dashboard');
      data = Map<String, dynamic>.from(r);
      audits = List.from(await api.get('/business/audits'));
      actions = List.from(await api.get('/business/actions'));
      nonConformities = List.from(await api.get('/business/non-conformities'));
    } catch (e) {
      error = 'Impossible de charger le tableau de bord';
    }
    setState(() => loading = false);
  }

  // --- Mêmes formules que le tableau de bord web, à l'identique ---
  bool _isOverdue(dynamic dueDate, dynamic status) {
    if (status == 'CLOSED' || dueDate == null) return false;
    final d = DateTime.tryParse('$dueDate');
    return d != null && d.isBefore(DateTime.now());
  }

  Map<String, int> _capaStats() {
    final total = actions.length;
    final terminees = actions.where((a) => a['status'] == 'CLOSED').length;
    final enRetard = actions.where((a) => _isOverdue(a['dueDate'], a['status'])).length;
    final enCours = total - terminees - enRetard;
    return {'total': total, 'terminees': terminees, 'enCours': enCours, 'enRetard': enRetard};
  }

  List<MapEntry<String, int>> _ncBySource() {
    final counts = <String, int>{};
    for (final n in nonConformities) {
      final source = (n['source'] ?? '').toString().trim();
      final key = source.isEmpty ? 'Source non renseignée' : source;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final entries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return entries;
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
    final trends = Map<String, dynamic>.from(data?['trends'] ?? {});
    final ncSeries = List.from(trends['nonConformitesParSemaine'] ?? []);
    final eventSeries = List.from(trends['evenementsSecuriteParSemaine'] ?? []);
    final severityBreakdown = List.from(counters['safetyEventsBySeverity'] ?? []);

    final auditsPlanifies = audits.where((a) => a['status'] == 'PLANNED').length;
    final auditsTotal = audits.length;
    final capa = _capaStats();
    final ncBySource = _ncBySource();

    final tauxConformite = indicators['qualite']?['tauxConformite'];
    int? composite;
    if (tauxConformite != null) {
      final actionsOverdue = (counters['actionsOverdue'] ?? 0) as num;
      final risksHigh = (counters['risksHigh'] ?? 0) as num;
      composite = (((tauxConformite as num) * 0.5) +
              (100 - actionsOverdue * 8).clamp(0, 100) * 0.3 +
              (100 - risksHigh * 10).clamp(0, 100) * 0.2)
          .round();
    }

    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Tableau de bord QHSE', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: QhseColors.textPrimary)),
          const SizedBox(height: 4),
          Text('Pilotez la conformité, en temps réel.', style: TextStyle(fontSize: 12, color: QhseColors.textSecondary)),
          const SizedBox(height: 16),

          // Les 5 mêmes cartes KPI que le web, dans le même ordre.
          Wrap(spacing: 10, runSpacing: 10, children: [
            _kpi('NC ouvertes', counters['nonConformitiesOpen'], "${counters['nonConformitiesCritical'] ?? 0} critique(s)", QhseColors.red, Icons.report_gmailerrorred),
            _kpi('Actions en retard', counters['actionsOverdue'], "${counters['actionsOpen'] ?? 0} ouverte(s) au total", QhseColors.red, Icons.schedule),
            _kpi('Événements sécurité', counters['safetyEvents30d'], '30 derniers jours', QhseColors.amber, Icons.warning_amber_rounded),
            _kpi('Audits', '${auditsTotal - auditsPlanifies} / $auditsTotal', "$auditsPlanifies planifié(s)", QhseColors.blue, Icons.fact_check_outlined),
            _kpi('Taux de conformité', tauxConformite != null ? '$tauxConformite%' : '—', '30 derniers jours', QhseColors.green, Icons.verified_outlined),
          ]),
          const SizedBox(height: 20),

          // Même rangée que le web : graphique de tendance + indice composite.
          _panel(
            title: 'Évolution des non-conformités & événements sécurité',
            subtitle: '8 dernières semaines',
            child: SizedBox(
              height: 200,
              child: (ncSeries.isEmpty && eventSeries.isEmpty)
                  ? Center(child: Text('Pas encore assez de données', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
                  : _TrendLineChart(ncSeries: ncSeries, eventSeries: eventSeries),
            ),
          ),
          const SizedBox(height: 16),
          _panel(
            title: composite != null ? 'Indice composite (estimation) : $composite%' : 'Indice composite',
            subtitle: 'Qualité 50% · Actions à jour 30% · Risques maîtrisés 20%',
            child: SizedBox(
              height: 140,
              child: Center(
                child: composite != null
                    ? Text('$composite%', style: TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: composite >= 80 ? QhseColors.green : composite >= 60 ? QhseColors.amber : QhseColors.red))
                    : Text('Pas assez de contrôles qualité soumis sur 30 jours pour calculer un taux de conformité.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: QhseColors.textSecondary)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Même rangée que le web : NC par source / sévérité / statut CAPA.
          _panel(
            title: 'Non-conformités par source',
            child: SizedBox(
              height: 180,
              child: ncBySource.isEmpty
                  ? Center(child: Text('Aucune non-conformité enregistrée', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
                  : _LabeledDonut(entries: ncBySource, colors: [QhseColors.red, QhseColors.amber, QhseColors.blue, QhseColors.green, const Color(0xFF8B5CF6), QhseColors.textSecondary]),
            ),
          ),
          const SizedBox(height: 16),
          _panel(
            title: 'Répartition des événements sécurité par sévérité',
            child: SizedBox(
              height: 180,
              child: severityBreakdown.isEmpty
                  ? Center(child: Text('Aucun événement sur 30 jours', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
                  : _SeverityDonut(data: severityBreakdown),
            ),
          ),
          const SizedBox(height: 16),
          _panel(
            title: 'Statut des actions correctives',
            child: SizedBox(
              height: 180,
              child: _LabeledDonut(
                entries: [
                  MapEntry('Terminées', capa['terminees']!),
                  MapEntry('En cours', capa['enCours']!),
                  MapEntry('En retard', capa['enRetard']!),
                ],
                colors: const [QhseColors.green, QhseColors.blue, QhseColors.red],
              ),
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
          Text(title, style: TextStyle(color: QhseColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          if (subtitle != null) Text(subtitle, style: TextStyle(color: QhseColors.textSecondary, fontSize: 11)),
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
          Text('${value ?? 0}', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: QhseColors.textPrimary)),
          const SizedBox(height: 2),
          Text(objectif, style: TextStyle(fontSize: 10, color: QhseColors.textSecondary)),
        ]),
      );
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
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: QhseColors.border, strokeWidth: 1)),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 26, getTitlesWidget: (v, m) => Text(v.toInt().toString(), style: TextStyle(fontSize: 9, color: QhseColors.textSecondary)))),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, interval: 1, getTitlesWidget: (v, m) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_weekLabel(labelSeries, v.toInt()), style: TextStyle(fontSize: 9, color: QhseColors.textSecondary)),
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
                Text('Sévérité ${s['severity']}', style: TextStyle(fontSize: 10, color: QhseColors.textSecondary)),
              ]),
            ),
        ],
      ),
    ]);
  }
}

/// Anneau générique avec légende, réutilisé pour "Non-conformités par
/// source" et "Statut des actions correctives" — même principe que les
/// donuts du tableau de bord web (DonutChart), version Flutter.
class _LabeledDonut extends StatelessWidget {
  final List<MapEntry<String, int>> entries;
  final List<Color> colors;
  const _LabeledDonut({required this.entries, required this.colors});

  @override
  Widget build(BuildContext context) {
    final filtered = entries.where((e) => e.value > 0).toList();
    if (filtered.isEmpty) {
      return Center(child: Text('Aucune donnée', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)));
    }
    return Row(children: [
      Expanded(
        child: PieChart(
          PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 34,
            sections: [
              for (int i = 0; i < filtered.length; i++)
                PieChartSectionData(
                  value: filtered[i].value.toDouble(),
                  color: colors[i % colors.length],
                  radius: 34,
                  title: '${filtered[i].value}',
                  titleStyle: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < filtered.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: colors[i % colors.length], shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Expanded(child: Text(filtered[i].key, style: TextStyle(fontSize: 10, color: QhseColors.textSecondary), overflow: TextOverflow.ellipsis)),
                ]),
              ),
          ],
        ),
      ),
    ]);
  }
}
