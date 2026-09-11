import 'package:flutter/material.dart';
import '../services/api.dart';
import '../theme.dart';

const Map<String, String> kProcessTypeLabels = {
  'STRATEGIQUE': 'Stratégique', 'OPERATIONNEL': 'Opérationnel', 'SUPPORT': 'Support', 'AUTRE': 'Autre',
};
const Map<String, String> kCriticiteLabels = {
  'FAIBLE': 'Faible', 'MOYEN': 'Moyen', 'IMPORTANT': 'Important', 'CRITIQUE': 'Critique',
};

Color criticiteColor(String? c) => {'FAIBLE': QhseColors.green, 'MOYEN': QhseColors.blue, 'IMPORTANT': QhseColors.amber, 'CRITIQUE': QhseColors.red}[c] ?? QhseColors.textSecondary;

// --- Calcul du score de maîtrise et des alertes — même logique que le web ---
List objectifsHorsCible(Map p) {
  final now = DateTime.now();
  return List.from(p['objectifsQhse'] ?? []).where((o) {
    if (o['echeance'] == null) return false;
    final ech = DateTime.tryParse(o['echeance']);
    return ech != null && ech.isBefore(now) && (o['actuel'] ?? 0) < (o['cible'] ?? 0);
  }).toList();
}
List formationsExpirees(Map p) {
  final now = DateTime.now();
  return List.from(p['trainings'] ?? []).where((t) {
    if (t['expiryAt'] == null) return false;
    final d = DateTime.tryParse(t['expiryAt']);
    return d != null && d.isBefore(now);
  }).toList();
}
List documentsEnRetard(Map p) {
  final now = DateTime.now();
  return List.from(p['documents'] ?? []).where((d) {
    if (d['nextReviewAt'] == null) return false;
    final dt = DateTime.tryParse(d['nextReviewAt']);
    return dt != null && dt.isBefore(now);
  }).toList();
}
List auditsEnRetard(Map p) {
  final now = DateTime.now();
  return List.from(p['audits'] ?? []).where((a) {
    if (a['status'] != 'PLANNED') return false;
    final d = DateTime.tryParse(a['auditDate'] ?? '');
    return d != null && d.isBefore(now);
  }).toList();
}
int computeMaturityScore(Map p) {
  int score = 60;
  if (p['piloteId'] == null) score -= 15;
  if (p['criticite'] == 'CRITIQUE') score -= 10;
  final nc = (p['_count']?['nonConformities'] ?? 0) as int;
  final act = (p['_count']?['actions'] ?? 0) as int;
  final risk = (p['_count']?['risks'] ?? 0) as int;
  score -= (nc * 5).clamp(0, 20) as int;
  score -= (act * 3).clamp(0, 15) as int;
  score -= (risk * 2).clamp(0, 10) as int;
  score -= (objectifsHorsCible(p).length * 5).clamp(0, 15) as int;
  score -= (formationsExpirees(p).length * 5).clamp(0, 10) as int;
  score -= (documentsEnRetard(p).length * 5).clamp(0, 10) as int;
  score -= (auditsEnRetard(p).length * 5).clamp(0, 10) as int;
  if (List.from(p['audits'] ?? []).isNotEmpty) score += 10;
  if (List.from(p['objectifsQhse'] ?? []).isNotEmpty) score += 5;
  if (List.from(p['documents'] ?? []).isNotEmpty) score += 5;
  return score.clamp(0, 100);
}
Map<String, String> maturityLevel(int score) {
  if (score >= 80) return {'label': 'Maîtrisé', 'emoji': '🟢'};
  if (score >= 60) return {'label': 'À surveiller', 'emoji': '🟡'};
  if (score >= 40) return {'label': 'À améliorer', 'emoji': '🟠'};
  return {'label': 'Critique', 'emoji': '🔴'};
}
int computeCompleteness(Map p) {
  final checks = [
    p['piloteId'] != null, (p['finalite'] ?? '').toString().isNotEmpty, p['criticite'] != null,
    List.from(p['activities'] ?? []).isNotEmpty, List.from(p['exigences'] ?? []).isNotEmpty,
    ((p['_count']?['risks'] ?? 0) as int) > 0, List.from(p['objectifsQhse'] ?? []).isNotEmpty, (p['kpi'] ?? '').toString().isNotEmpty,
  ];
  return (checks.where((c) => c).length / checks.length * 100).round();
}
List<String> processusAlerts(Map p) {
  final alerts = <String>[];
  if (p['piloteId'] == null) alerts.add('Sans pilote');
  if ((p['kpi'] ?? '').toString().isEmpty) alerts.add('Sans indicateur');
  if (((p['_count']?['risks'] ?? 0) as int) == 0) alerts.add('Sans analyse de risques');
  if (List.from(p['objectifsQhse'] ?? []).isEmpty) alerts.add('Sans objectif');
  final hc = objectifsHorsCible(p).length; if (hc > 0) alerts.add('$hc objectif(s) hors cible');
  final fe = formationsExpirees(p).length; if (fe > 0) alerts.add('$fe formation(s) expirée(s)');
  final dr = documentsEnRetard(p).length; if (dr > 0) alerts.add('$dr document(s) en retard');
  final ar = auditsEnRetard(p).length; if (ar > 0) alerts.add('$ar audit(s) en retard');
  return alerts;
}

// --- Création / modification d'un processus ---
Future<void> showProcessusDialog(BuildContext context, Api api, {Map? record, required VoidCallback onSaved}) async {
  final nom = TextEditingController(text: record?['nom'] ?? '');
  final finalite = TextEditingController(text: record?['finalite'] ?? '');
  final objectifs = TextEditingController(text: record?['objectifs'] ?? '');
  final kpi = TextEditingController(text: record?['kpi'] ?? '');
  String type = record?['type'] ?? 'OPERATIONNEL';
  String? criticite = record?['criticite'];
  String? piloteId = record?['piloteId'];
  List users = [];
  String? formError;
  bool saving = false;
  try { users = List.from(await api.get('/users')); } catch (_) {}
  await showDialog(
    context: context,
    builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
      title: Text(record == null ? 'Nouveau processus' : 'Modifier le processus'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nom, decoration: const InputDecoration(labelText: 'Nom du processus')),
          DropdownButtonFormField<String>(
            value: type, isExpanded: true,
            items: kProcessTypeLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (v) => setD(() => type = v ?? 'OPERATIONNEL'),
            decoration: const InputDecoration(labelText: 'Type'),
          ),
          DropdownButtonFormField<String>(
            value: criticite, isExpanded: true,
            items: kCriticiteLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (v) => setD(() => criticite = v),
            decoration: const InputDecoration(labelText: 'Criticité (optionnel)'),
          ),
          DropdownButtonFormField<String>(
            value: piloteId, isExpanded: true,
            items: users.map<DropdownMenuItem<String>>((u) => DropdownMenuItem(value: u['id'] as String, child: Text('${u['firstName']} ${u['lastName']}'))).toList(),
            onChanged: (v) => setD(() => piloteId = v),
            decoration: const InputDecoration(labelText: 'Pilote (optionnel)'),
          ),
          TextField(controller: finalite, decoration: const InputDecoration(labelText: 'Finalité (optionnel)'), maxLines: 2),
          TextField(controller: objectifs, decoration: const InputDecoration(labelText: 'Objectifs')),
          TextField(controller: kpi, decoration: const InputDecoration(labelText: 'KPI')),
          if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
        ]),
      ),
      actions: [
        if (record != null) TextButton(
          onPressed: () async {
            try { await api.delete('/business/processus/${record['id']}'); if (context.mounted) Navigator.pop(c); onSaved(); }
            catch (e) { setD(() => formError = '$e'); }
          },
          child: const Text('Supprimer', style: TextStyle(color: QhseColors.red)),
        ),
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
        FilledButton(
          onPressed: saving ? null : () async {
            setD(() => saving = true);
            final payload = {'nom': nom.text, 'type': type, 'criticite': criticite, 'piloteId': piloteId, 'finalite': finalite.text, 'objectifs': objectifs.text, 'kpi': kpi.text};
            try {
              if (record != null) await api.patch('/business/processus/${record['id']}', payload);
              else await api.post('/business/processus', {'code': 'PROC-${DateTime.now().millisecondsSinceEpoch}', ...payload});
              if (context.mounted) Navigator.pop(c);
              onSaved();
            } catch (e) { setD(() { saving = false; formError = '$e'; }); }
          },
          child: Text(saving ? 'Enregistrement…' : 'Enregistrer'),
        ),
      ],
    )),
  );
}

// --- Détail (lecture) d'un processus ---
class ProcessusDetailPage extends StatelessWidget {
  final Map p;
  const ProcessusDetailPage({super.key, required this.p});

  @override
  Widget build(BuildContext context) {
    final score = computeMaturityScore(p);
    final lvl = maturityLevel(score);
    final alerts = processusAlerts(p);
    return Scaffold(
      appBar: AppBar(title: Text(p['nom'] ?? '')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${lvl['emoji']} ${lvl['label']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('Score : $score/100', style: TextStyle(color: QhseColors.textSecondary)),
          ]),
          const SizedBox(height: 4),
          Text('Complétude : ${computeCompleteness(p)}%', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)),
        ]))),
        const SizedBox(height: 10),
        Card(child: ListTile(title: const Text('Type'), trailing: Text(kProcessTypeLabels[p['type']] ?? p['type'] ?? '—'))),
        Card(child: ListTile(title: const Text('Criticité'), trailing: Text(p['criticite'] != null ? kCriticiteLabels[p['criticite']] ?? p['criticite'] : '—', style: TextStyle(color: criticiteColor(p['criticite']))))),
        Card(child: ListTile(title: const Text('Pilote'), trailing: Text(p['pilote'] != null ? '${p['pilote']['firstName']} ${p['pilote']['lastName']}' : 'Sans pilote'))),
        if ((p['finalite'] ?? '').toString().isNotEmpty) Card(child: ListTile(title: const Text('Finalité'), subtitle: Text(p['finalite']))),
        Card(child: ListTile(title: const Text('NC ouvertes'), trailing: Text('${p['_count']?['nonConformities'] ?? 0}'))),
        Card(child: ListTile(title: const Text('Actions ouvertes'), trailing: Text('${p['_count']?['actions'] ?? 0}'))),
        const SizedBox(height: 10),
        Text('Alertes', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        if (alerts.isEmpty) const Text('Aucune alerte', style: TextStyle(color: QhseColors.green))
        else ...alerts.map((a) => Card(child: ListTile(leading: const Icon(Icons.warning_amber_outlined, color: QhseColors.amber), title: Text(a)))),
        const SizedBox(height: 12),
        Text('Le détail complet (SIPOC, activités, RACI, exigences, rapport Excel) reste géré depuis le tableau de bord web pour le moment.', style: TextStyle(color: QhseColors.textSecondary, fontSize: 11)),
      ]),
    );
  }
}

// --- Écran principal, à onglets ---
class ProcessusHome extends StatefulWidget {
  const ProcessusHome({super.key});
  @override
  State<ProcessusHome> createState() => _ProcessusHomeState();
}

class _ProcessusHomeState extends State<ProcessusHome> {
  final api = Api();
  List items = [];
  bool loading = true;
  int tabIndex = 0;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() => loading = true);
    try { items = List.from(await api.get('/business/processus')); } catch (_) {}
    setState(() => loading = false);
  }

  List<KpiStat> get kpis {
    final critiques = items.where((p) => p['criticite'] == 'CRITIQUE').length;
    final sansPilote = items.where((p) => p['piloteId'] == null).length;
    final avecNc = items.where((p) => ((p['_count']?['nonConformities'] ?? 0) as int) > 0).length;
    return [
      KpiStat('Processus cartographiés', '${items.length}', color: QhseColors.blue, icon: Icons.account_tree_outlined),
      KpiStat('Stratégiques', '${items.where((p) => p['type'] == 'STRATEGIQUE').length}', color: QhseColors.blue, icon: Icons.flag_outlined),
      KpiStat('Opérationnels', '${items.where((p) => p['type'] == 'OPERATIONNEL').length}', color: QhseColors.green, icon: Icons.settings_outlined),
      KpiStat('Supports', '${items.where((p) => p['type'] == 'SUPPORT').length}', color: QhseColors.amber, icon: Icons.build_outlined),
      KpiStat('Critiques', '$critiques', color: critiques > 0 ? QhseColors.red : QhseColors.green, icon: Icons.warning_amber_outlined),
      KpiStat('Sans pilote', '$sansPilote', color: sansPilote > 0 ? QhseColors.red : QhseColors.green, icon: Icons.person_off_outlined),
      KpiStat('Avec NC ouvertes', '$avecNc', color: avecNc > 0 ? QhseColors.red : QhseColors.green, icon: Icons.error_outline),
    ];
  }

  @override
  Widget build(BuildContext c) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Processus'),
          bottom: TabBar(onTap: (i) => setState(() => tabIndex = i), tabs: const [Tab(text: 'Tableau de bord'), Tab(text: 'Cartographie'), Tab(text: 'Registre')]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => showProcessusDialog(context, api, onSaved: load),
          icon: const Icon(Icons.add), label: const Text('Processus'),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : IndexedStack(index: tabIndex, children: [
                // Tableau de bord
                RefreshIndicator(
                  onRefresh: load,
                  child: ListView(padding: const EdgeInsets.only(top: 12, bottom: 12), children: [
                    KpiBar(kpis),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Priorités QHSE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 6),
                        ...(() {
                          final withAlerts = items.where((p) => processusAlerts(p).isNotEmpty).toList()
                            ..sort((a, b) => processusAlerts(b).length.compareTo(processusAlerts(a).length));
                          if (withAlerts.isEmpty) return [const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Aucune alerte pour le moment', style: TextStyle(color: QhseColors.green)))];
                          return withAlerts.take(8).map<Widget>((p) => Card(child: ListTile(
                                title: Text(p['nom'] ?? ''),
                                subtitle: Text(processusAlerts(p).join(' · '), style: const TextStyle(fontSize: 11)),
                                onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => ProcessusDetailPage(p: p))),
                              ))).toList();
                        })(),
                      ]),
                    ),
                  ]),
                ),
                // Cartographie — regroupée par type ; le glisser-déposer et les
                // liens dessinés restent gérés côté web pour l'instant.
                RefreshIndicator(
                  onRefresh: load,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: kProcessTypeLabels.keys.expand((t) {
                      final group = items.where((p) => (p['type'] ?? 'OPERATIONNEL') == t).toList();
                      if (group.isEmpty) return <Widget>[];
                      return [
                        Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(kProcessTypeLabels[t]!, style: TextStyle(fontWeight: FontWeight.bold, color: QhseColors.textSecondary))),
                        ...group.map((p) => Card(child: ListTile(
                              title: Text(p['nom'] ?? ''),
                              subtitle: Text(p['pilote'] != null ? '${p['pilote']['firstName']} ${p['pilote']['lastName']}' : 'Sans pilote'),
                              leading: p['criticite'] != null ? Icon(Icons.circle, size: 12, color: criticiteColor(p['criticite'])) : null,
                              onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => ProcessusDetailPage(p: p))),
                            ))),
                      ];
                    }).toList(),
                  ),
                ),
                // Registre
                RefreshIndicator(
                  onRefresh: load,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: items.isEmpty
                        ? const [Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Aucun processus enregistré')))]
                        : items.map((p) {
                            final score = computeMaturityScore(p);
                            final lvl = maturityLevel(score);
                            return Card(child: ListTile(
                              title: Text(p['nom'] ?? ''),
                              subtitle: Text('${kProcessTypeLabels[p['type']] ?? p['type']} • ${p['pilote'] != null ? '${p['pilote']['firstName']} ${p['pilote']['lastName']}' : 'Sans pilote'}'),
                              trailing: Text('${lvl['emoji']} ${lvl['label']}', style: const TextStyle(fontSize: 12)),
                              onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => ProcessusDetailPage(p: p))),
                              onLongPress: () => showProcessusDialog(context, api, record: p, onSaved: load),
                            ));
                          }).toList(),
                  ),
                ),
              ]),
      ),
    );
  }
}
