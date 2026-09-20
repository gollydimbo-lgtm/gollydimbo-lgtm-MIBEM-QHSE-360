import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api.dart';
import '../theme.dart';

/// Correspondance rôle réel -> vue par défaut du pilotage, identique à
/// celle du tableau de bord web (App.jsx / PilotagePage), pour que les deux
/// interfaces se comportent pareil pour un même compte.
const Map<String, String> _kPilotageRoleToVue = {
  'ADMINISTRATEUR': 'direction', 'CONSULTATION': 'direction',
  'RESPONSABLE_QHSE': 'qhse', 'ASSISTANT_QHSE': 'qhse', 'CONTROLEUR_QUALITE': 'qhse', 'AUDITEUR': 'qhse',
  'CHEF_PRODUCTION': 'terrain', 'OPERATEUR': 'terrain',
};

/// Tableau de bord — reproduit le tableau de bord web (Gestion QHSE 360) :
/// mêmes cartes KPI, alertes prioritaires unifiées, score composite réel
/// avec fiabilité des données, Pareto sécurité et non-conformités
/// récurrentes, et la même vue par rôle (Direction / Responsable QHSE /
/// Contrôleur Terrain). Branché sur les mêmes routes réelles (GET
/// /dashboard renvoie déjà overview + trends + alerts + score + analyses),
/// aucune donnée fictive.
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
  String vue = 'qhse';

  @override
  void initState() {
    super.initState();
    load();
    _loadVue();
  }

  // Choix de vue mémorisé localement ; à défaut, calculé depuis le rôle réel
  // de l'utilisateur connecté (même logique que le web).
  Future<void> _loadVue() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('qhse_pilotage_vue');
    if (saved != null) {
      if (mounted) setState(() => vue = saved);
      return;
    }
    try {
      final user = await api.currentUser();
      // user['roles'] est une liste de noms de rôle (chaînes), telle que
      // renvoyée par /auth/login et /auth/refresh — pas une liste d'objets.
      final roleNames = ((user?['roles'] as List?) ?? [])
          .map((r) => r?.toString())
          .whereType<String>();
      for (final r in roleNames) {
        final mapped = _kPilotageRoleToVue[r];
        if (mapped != null) {
          if (mounted) setState(() => vue = mapped);
          return;
        }
      }
    } catch (_) {
      // Défaut 'qhse' conservé si le profil n'est pas disponible.
    }
  }

  Future<void> _setVue(String v) async {
    setState(() => vue = v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('qhse_pilotage_vue', v);
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
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

  String _fmtDate(dynamic raw) {
    final d = DateTime.tryParse('$raw');
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Color _alertColor(String? level) {
    switch (level) {
      case 'CRITICAL': return QhseColors.red;
      case 'WARNING': return QhseColors.amber;
      case 'INFO': return QhseColors.blue;
      case 'SUCCESS': return QhseColors.green;
      default: return QhseColors.textSecondary;
    }
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
    final alertes = List.from(data?['alerts'] ?? []);
    final score = Map<String, dynamic>.from(data?['score'] ?? {});
    final scoreDomaines = Map<String, dynamic>.from(score['domaines'] ?? {});
    final analyses = Map<String, dynamic>.from(data?['analyses'] ?? {});
    final ncAnalyses = Map<String, dynamic>.from(analyses['nonConformites'] ?? {});
    final securiteAnalyses = Map<String, dynamic>.from(analyses['securite'] ?? {});
    final processusProblematiques = List.from(ncAnalyses['processusLesPlusProblematiques'] ?? []);
    final recurrences = List.from(ncAnalyses['recurrences'] ?? []);
    final paretoSecurite = List.from(securiteAnalyses['pareto'] ?? []);

    final auditsPlanifies = audits.where((a) => a['status'] == 'PLANNED').length;
    final auditsTotal = audits.length;
    final capa = _capaStats();
    final ncBySource = _ncBySource();
    final tauxConformite = indicators['qualite']?['tauxConformite'];

    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Tableau de bord QHSE', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: QhseColors.textPrimary)),
          const SizedBox(height: 4),
          Text('Pilotez la conformité, en temps réel.', style: TextStyle(fontSize: 12, color: QhseColors.textSecondary)),
          const SizedBox(height: 12),

          _vueSelector(),
          const SizedBox(height: 16),

          // Les 5 mêmes cartes KPI que le web, dans le même ordre.
          Wrap(spacing: 10, runSpacing: 10, children: [
            _kpi('NC ouvertes', counters['nonConformitiesOpen'], "${counters['nonConformitiesCritical'] ?? 0} critique(s)", QhseColors.red, Icons.report_gmailerrorred),
            _kpi('Actions en retard', counters['actionsOverdue'], "${counters['actionsOpen'] ?? 0} ouverte(s) au total", QhseColors.red, Icons.schedule),
            _kpi('Événements sécurité', counters['safetyEvents30d'], '30 derniers jours', QhseColors.amber, Icons.warning_amber_rounded),
            _kpi('Audits', '${auditsTotal - auditsPlanifies} / $auditsTotal', "$auditsPlanifies planifié(s)", QhseColors.blue, Icons.fact_check_outlined),
            _kpi('Taux de conformité', tauxConformite != null ? '$tauxConformite%' : '—', '30 derniers jours', QhseColors.green, Icons.verified_outlined),
          ]),

          // Deuxième rangée de KPI, masquée en vue Direction (vue une minute).
          if (vue != 'direction') ...[
            const SizedBox(height: 10),
            Wrap(spacing: 10, runSpacing: 10, children: [
              _kpi('Risques élevés', counters['risksHigh'], "${counters['risksTotal'] ?? 0} risque(s) suivi(s)", QhseColors.red, Icons.dangerous_outlined),
              _kpi('Documents en attente', counters['documentsPendingApproval'], 'validation GED', QhseColors.blue, Icons.description_outlined),
              _kpi('Formations expirant', counters['trainingsExpiringSoon'], 'sous 30 jours', QhseColors.amber, Icons.school_outlined),
              _kpi('EPI à renouveler', counters['epiRenewalsDue30d'], 'sous 30 jours', QhseColors.amber, Icons.shield_outlined),
              _kpi('Équipements en retard', counters['equipmentOverdueInspection'], 'inspection dépassée', QhseColors.red, Icons.build_outlined),
            ]),
          ],
          const SizedBox(height: 20),

          // Centre d'alertes unifié : ce que le Responsable QHSE devrait
          // regarder en premier, tous domaines confondus, déjà trié par
          // priorité côté API.
          _panel(
            title: 'Alertes prioritaires',
            subtitle: 'Toutes les échéances et anomalies critiques, triées par priorité',
            child: _alertsList(alertes),
          ),
          const SizedBox(height: 16),

          // Pareto & récurrences : moteurs déjà existants côté API
          // (safetyEventsStats, ncSyntheseDirection), analyses de fond
          // réservées à la vue Responsable QHSE.
          if (vue == 'qhse') ...[
            _panel(
              title: 'Pareto des causes racines — sécurité',
              subtitle: "Causes qui concentrent le plus d'événements de sécurité",
              child: _paretoList(paretoSecurite),
            ),
            const SizedBox(height: 16),
            _panel(
              title: 'Non-conformités récurrentes',
              subtitle: 'Mêmes anomalies qui reviennent — à instruire en Ishikawa / 5 Pourquoi',
              child: _recurrencesList(recurrences),
            ),
            const SizedBox(height: 16),
            _panel(
              title: 'Processus les plus problématiques',
              subtitle: 'Nombre de non-conformités par processus',
              child: processusProblematiques.isEmpty
                  ? Center(child: Text('Aucun processus renseigné sur les non-conformités', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
                  : _HorizontalBars(
                      entries: processusProblematiques.map<MapEntry<String, int>>((p) => MapEntry('${p['processus'] ?? ''}', ((p['nombre'] ?? 0) as num).toInt())).toList(),
                      color: QhseColors.red,
                    ),
            ),
            const SizedBox(height: 16),
          ],

          // Tendance & score composite : utiles à Direction (vue une
          // minute) et au Responsable QHSE ; pas au Contrôleur Terrain.
          if (vue != 'terrain') ...[
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
              title: score['global'] != null ? 'Score composite QHSE : ${score['global']}%' : 'Score composite QHSE',
              subtitle: _scoreConfianceLabel(score['confiance']),
              child: _scoreBreakdown(score['global'], scoreDomaines),
            ),
            const SizedBox(height: 16),
          ],

          // Répartitions détaillées : réservées à la vue Responsable QHSE.
          if (vue == 'qhse') ...[
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
        ],
      ),
    );
  }

  String _scoreConfianceLabel(dynamic confiance) {
    switch (confiance) {
      case 'ELEVEE': return 'Fiabilité élevée — tous les domaines ont assez de données';
      case 'MOYENNE': return 'Fiabilité moyenne — certains domaines manquent de données';
      case 'FAIBLE': return 'Fiabilité faible — trop peu de données pour se fier à ce score';
      default: return '';
    }
  }

  Widget _vueSelector() {
    const options = [['direction', 'Direction'], ['qhse', 'Responsable QHSE'], ['terrain', 'Contrôleur Terrain']];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: QhseColors.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: QhseColors.border)),
      child: Row(children: [
        for (final o in options)
          Expanded(
            child: GestureDetector(
              onTap: () => _setVue(o[0]),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(color: vue == o[0] ? QhseColors.blue : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                child: Text(o[1], textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: vue == o[0] ? Colors.white : QhseColors.textSecondary)),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _alertsList(List alertes) {
    if (alertes.isEmpty) {
      return Center(child: Text('Aucune alerte en cours.', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)));
    }
    final shown = alertes.take(vue == 'direction' ? 5 : 10).toList();
    return Column(children: [
      for (final raw in shown) Builder(builder: (_) {
        final a = Map<String, dynamic>.from(raw);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${a['icon'] ?? ''}', style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('${(a['domain'] ?? '').toString().replaceAll('_', ' ')}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: _alertColor(a['level'] as String?))),
                  if (a['code'] != null) ...[const SizedBox(width: 6), Text('${a['code']}', style: TextStyle(fontSize: 10, color: QhseColors.textSecondary))],
                ]),
                Text('${a['title'] ?? ''}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: QhseColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${a['detail'] ?? ''}${a['dueDate'] != null ? ' · échéance ${_fmtDate(a['dueDate'])}' : ''}', style: TextStyle(fontSize: 11, color: QhseColors.textSecondary)),
              ]),
            ),
          ]),
        );
      }),
    ]);
  }

  Widget _recurrencesList(List recurrences) {
    if (recurrences.isEmpty) {
      return Center(child: Text('Aucune récurrence détectée', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)));
    }
    return Column(children: [
      for (final raw in recurrences) Builder(builder: (_) {
        final r = Map<String, dynamic>.from(raw);
        final faite = r['analyseCausaleFaite'] == true;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Text('${r['titre'] ?? ''}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: QhseColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis)),
              Text('${r['occurrences']}×', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: QhseColors.red)),
            ]),
            const SizedBox(height: 2),
            Text('${r['processus'] ?? ''} · ${_fmtDate(r['premiereOccurrence'])} → ${_fmtDate(r['derniereOccurrence'])}', style: TextStyle(fontSize: 11, color: QhseColors.textSecondary)),
            Text(faite ? '✓ cause racine identifiée' : '⚠ analyse causale manquante', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: faite ? QhseColors.green : QhseColors.amber)),
          ]),
        );
      }),
    ]);
  }

  Widget _paretoList(List pareto) {
    if (pareto.isEmpty) {
      return Center(child: Text('Aucune cause racine renseignée sur les événements sécurité', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)));
    }
    final total = pareto.fold<num>(0, (s, p) => s + ((p['value'] ?? 0) as num));
    num cumul = 0;
    return Column(children: [
      for (final raw in pareto) Builder(builder: (_) {
        final p = Map<String, dynamic>.from(raw);
        final value = (p['value'] ?? 0) as num;
        cumul += value;
        final cumulPct = total > 0 ? (cumul / total * 100) : 0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Text('${p['name'] ?? ''}', style: TextStyle(fontSize: 12, color: QhseColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis)),
              Text('$value', style: TextStyle(fontSize: 11, color: QhseColors.textSecondary)),
            ]),
            const SizedBox(height: 3),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: total > 0 ? value / total : 0, minHeight: 6, backgroundColor: QhseColors.border, color: QhseColors.red),
            ),
            Align(alignment: Alignment.centerRight, child: Text('cumul ${cumulPct.toStringAsFixed(0)}%', style: TextStyle(fontSize: 9, color: QhseColors.textSecondary))),
          ]),
        );
      }),
    ]);
  }

  Widget _scoreBreakdown(dynamic global, Map<String, dynamic> domaines) {
    const labels = {'qualite': 'Qualité', 'securite': 'Sécurité', 'risques': 'Risques', 'actions': 'Actions correctives'};
    final g = global is num ? global.round() : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Center(
        child: Text(
          g != null ? '$g%' : '—',
          style: TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: g == null ? QhseColors.textSecondary : g >= 80 ? QhseColors.green : g >= 60 ? QhseColors.amber : QhseColors.red),
        ),
      ),
      const SizedBox(height: 10),
      for (final entry in domaines.entries) Builder(builder: (_) {
        final d = Map<String, dynamic>.from(entry.value ?? {});
        final hasScore = d['score'] != null;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 88, child: Text(labels[entry.key] ?? entry.key, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: QhseColors.textPrimary))),
            Expanded(
              child: Text(
                hasScore ? "${d['score']}% · ${d['detail'] ?? ''}" : "Données insuffisantes · ${d['detail'] ?? ''}",
                style: TextStyle(fontSize: 10, color: hasScore ? QhseColors.textSecondary : QhseColors.amber),
              ),
            ),
          ]),
        );
      }),
    ]);
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

/// Barres horizontales génériques avec légende — version Flutter du
/// HorizontalBars du tableau de bord web, utilisée ici pour "Processus les
/// plus problématiques".
class _HorizontalBars extends StatelessWidget {
  final List<MapEntry<String, int>> entries;
  final Color color;
  const _HorizontalBars({required this.entries, required this.color});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(child: Text('Aucune donnée', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)));
    }
    final max = entries.map((e) => e.value).fold<int>(1, (a, b) => a > b ? a : b);
    return Column(children: [
      for (final e in entries)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Text(e.key, style: TextStyle(fontSize: 11, color: QhseColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis)),
              Text('${e.value}', style: TextStyle(fontSize: 11, color: QhseColors.textPrimary)),
            ]),
            const SizedBox(height: 3),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: e.value / max, minHeight: 6, backgroundColor: QhseColors.border, color: color),
            ),
          ]),
        ),
    ]);
  }
}
