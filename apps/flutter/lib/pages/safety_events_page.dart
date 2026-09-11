import 'package:flutter/material.dart';
import '../services/api.dart';
import '../services/sync_queue.dart';
import '../theme.dart';
import 'attachment_helpers.dart';

const _types = {
  'ACCIDENT': ('Accident', Icons.local_hospital, Colors.red),
  'INCIDENT': ('Incident', Icons.report_problem, Colors.deepOrange),
  'PRESQU_ACCIDENT': ('Presqu\'accident', Icons.warning_amber, Colors.orange),
  'SITUATION_DANGEREUSE': ('Situation dangereuse', Icons.dangerous, Colors.amber),
};
const Map<String, String> kStatutLabels = {
  'DECLARE': 'Déclaré', 'SECURISE': 'Sécurisé', 'INVESTIGATION': 'En investigation', 'ANALYSE_CAUSES': 'Analyse des causes',
  'ACTIONS_DEFINIES': 'Actions définies', 'ACTIONS_EN_COURS': 'Actions en cours', 'VERIFICATION': "Vérification d'efficacité",
  'VALIDE': 'Validé', 'CLOTURE': 'Clôturé',
};
Color _niveauColor(String? n) => {'CRITIQUE': QhseColors.red, 'URGENT': QhseColors.red, 'ATTENTION': QhseColors.amber}[n] ?? QhseColors.textSecondary;

// --- Écran principal : tableau de bord + registre ---
class SafetyEventsPage extends StatefulWidget {
  const SafetyEventsPage({super.key});
  @override
  State<SafetyEventsPage> createState() => _SafetyEventsPageState();
}

class _SafetyEventsPageState extends State<SafetyEventsPage> {
  final api = Api();
  List events = [];
  Map stats = {'volume': {}, 'pareto': [], 'parMecanisme': [], 'parZone': []};
  List alertes = [];
  Map recidives = {'parCauseRacine': [], 'parZone': [], 'parMecanisme': []};
  bool loading = true;
  int tabIndex = 0;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      events = List.from(await api.get('/business/safety-events'));
      stats = Map.from(await api.get('/business/safety-events-stats'));
      alertes = List.from(await api.get('/business/safety-events-alertes'));
      recidives = Map.from(await api.get('/business/safety-events-recidives'));
    } catch (_) {}
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext c) {
    final volume = Map.from(stats['volume'] ?? {});
    final pareto = List.from(stats['pareto'] ?? []);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Accidents & incidents'),
          bottom: TabBar(onTap: (i) => setState(() => tabIndex = i), tabs: const [Tab(text: 'Tableau de bord'), Tab(text: 'Registre')]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const NewSafetyEventPage())).then((_) => load()),
          icon: const Icon(Icons.add),
          label: const Text('Déclarer'),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : IndexedStack(index: tabIndex, children: [
                RefreshIndicator(
                  onRefresh: load,
                  child: ListView(padding: const EdgeInsets.all(12), children: [
                    KpiBar([
                      KpiStat('Événements', '${volume['total'] ?? 0}', color: QhseColors.blue, icon: Icons.report_outlined),
                      KpiStat('Accidents', '${volume['accidents'] ?? 0}', color: QhseColors.red, icon: Icons.local_hospital_outlined),
                      KpiStat('Avec arrêt', '${volume['avecArret'] ?? 0}', color: QhseColors.amber, icon: Icons.timer_off_outlined),
                      KpiStat('Graves (≥4)', '${volume['graves'] ?? 0}', color: QhseColors.red, icon: Icons.warning_amber_outlined),
                    ]),
                    const SizedBox(height: 16),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Alertes automatiques', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('${alertes.length}', style: TextStyle(color: QhseColors.textSecondary)),
                    ]),
                    const SizedBox(height: 6),
                    if (alertes.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Aucune alerte — tout est sous contrôle', style: TextStyle(color: QhseColors.green)))
                    else ...alertes.map((a) => Card(child: ListTile(
                          title: Text(a['title'] ?? ''),
                          subtitle: Text(List.from(a['motifs'] ?? []).map((m) => m['label']).join(' · '), style: const TextStyle(fontSize: 11)),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: _niveauColor(a['niveau']).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                            child: Text(a['niveau'] ?? '', style: TextStyle(color: _niveauColor(a['niveau']), fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                          onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => SafetyEventDetailPage(eventId: a['id']))).then((_) => load()),
                        ))),
                    const SizedBox(height: 16),
                    if (List.from(recidives['parCauseRacine'] ?? []).isNotEmpty || List.from(recidives['parZone'] ?? []).isNotEmpty) ...[
                      const Text('Risque de récidive détecté', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 6),
                      ...List.from(recidives['parCauseRacine'] ?? []).map((r) => Card(child: ListTile(dense: true, title: Text(r['critere'] ?? ''), subtitle: const Text('Cause racine récurrente', style: TextStyle(fontSize: 11)), trailing: Text('${r['nombre']}×', style: TextStyle(color: QhseColors.amber, fontWeight: FontWeight.bold))))),
                      const SizedBox(height: 16),
                    ],
                    const Text('Pareto des causes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 6),
                    if (pareto.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Aucune cause racine renseignée', style: TextStyle(color: QhseColors.textSecondary)))
                    else ...pareto.map((p) => Card(child: ListTile(
                          title: Text(p['name'] ?? ''),
                          trailing: Text('${p['value']} (${p['pct']}%, cumul ${p['cumulPct']}%)', style: const TextStyle(fontSize: 11)),
                        ))),
                  ]),
                ),
                RefreshIndicator(
                  onRefresh: load,
                  child: events.isEmpty
                      ? ListView(children: const [Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Aucun événement déclaré')))])
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: events.length,
                          itemBuilder: (_, i) {
                            final e = events[i];
                            final meta = _types[e['type']] ?? ('${e['type']}', Icons.info, Colors.grey);
                            return Card(
                              child: ListTile(
                                leading: Icon(meta.$2, color: meta.$3, size: 32),
                                title: Text('${e['title']}'),
                                subtitle: Text('${meta.$1} • ${_date(e['occurredAt'])} • ${kStatutLabels[e['statut']] ?? 'Déclaré'}'),
                                trailing: severityChip(e['severity'] ?? 1, prefix: ''),
                                onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => SafetyEventDetailPage(eventId: e['id']))).then((_) => load()),
                              ),
                            );
                          },
                        ),
                ),
              ]),
      ),
    );
  }

  String _date(dynamic v) => v == null ? '' : v.toString().substring(0, 16).replaceFirst('T', ' ');
}

// --- Déclaration terrain rapide : GPS + hors-ligne + photo, inchangés ---
class NewSafetyEventPage extends StatefulWidget {
  const NewSafetyEventPage({super.key});
  @override
  State<NewSafetyEventPage> createState() => _NewSafetyEventPageState();
}

class _NewSafetyEventPageState extends State<NewSafetyEventPage> {
  final api = Api();
  final title = TextEditingController();
  final description = TextEditingController();
  final zone = TextEditingController();
  String type = 'ACCIDENT';
  String? typePersonnel;
  int severity = 2;
  double? lat, lon;
  bool busy = false;
  String? createdId;

  Future<void> gps() async {
    final p = await captureGps(context);
    if (p != null) setState(() { lat = p.latitude; lon = p.longitude; });
  }

  Future<void> submit() async {
    if (title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le titre est obligatoire')));
      return;
    }
    setState(() => busy = true);
    var desc = description.text;
    if (lat != null) desc = '$desc\n[GPS ${lat!.toStringAsFixed(5)}, ${lon!.toStringAsFixed(5)}]'.trim();
    final payload = {
      'type': type,
      'title': title.text.trim(),
      'description': desc.isEmpty ? null : desc,
      'occurredAt': DateTime.now().toIso8601String(),
      'severity': severity,
      'zone': zone.text.trim().isEmpty ? null : zone.text.trim(),
      'typePersonnel': typePersonnel,
    };
    try {
      final r = await api.post('/business/safety-events', payload);
      setState(() => createdId = r['id']);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Déclaration enregistrée')));
    } on ApiException catch (e) {
      if (e.networkError) {
        await SyncQueue.enqueue('safetyEvent', 'CREATE', payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pas de réseau : déclaration enregistrée hors-ligne, elle sera synchronisée automatiquement.'), duration: Duration(seconds: 4)));
          Navigator.pop(context);
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    setState(() => busy = false);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Nouvelle déclaration')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          value: type,
          decoration: const InputDecoration(labelText: 'Type d\'événement'),
          items: _types.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value.$1))).toList(),
          onChanged: createdId == null ? (v) => setState(() => type = v!) : null,
        ),
        const SizedBox(height: 12),
        TextField(controller: title, enabled: createdId == null, decoration: const InputDecoration(labelText: 'Titre / résumé')),
        const SizedBox(height: 12),
        TextField(controller: description, enabled: createdId == null, maxLines: 4, decoration: const InputDecoration(labelText: 'Description, circonstances, témoins...')),
        const SizedBox(height: 12),
        TextField(controller: zone, enabled: createdId == null, decoration: const InputDecoration(labelText: 'Zone / atelier (optionnel)')),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: typePersonnel, isExpanded: true,
          decoration: const InputDecoration(labelText: 'Type de personnel concerné (optionnel)'),
          items: const [
            DropdownMenuItem(value: 'SALARIE', child: Text('Salarié')), DropdownMenuItem(value: 'INTERIMAIRE', child: Text('Intérimaire')),
            DropdownMenuItem(value: 'SOUS_TRAITANT', child: Text('Sous-traitant')), DropdownMenuItem(value: 'VISITEUR', child: Text('Visiteur')), DropdownMenuItem(value: 'AUTRE', child: Text('Autre')),
          ],
          onChanged: createdId == null ? (v) => setState(() => typePersonnel = v) : null,
        ),
        const SizedBox(height: 12),
        Text('Sévérité : $severity', style: const TextStyle(fontWeight: FontWeight.bold)),
        Slider(value: severity.toDouble(), min: 1, max: 5, divisions: 4, label: '$severity', onChanged: createdId == null ? (v) => setState(() => severity = v.round()) : null),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: createdId == null ? gps : null,
          icon: const Icon(Icons.gps_fixed),
          label: Text(lat == null ? 'Capturer la position GPS' : 'GPS ${lat!.toStringAsFixed(5)}, ${lon!.toStringAsFixed(5)}'),
        ),
        const SizedBox(height: 20),
        if (createdId == null)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy ? null : submit,
              icon: const Icon(Icons.send),
              label: Text(busy ? 'Envoi...' : 'Envoyer la déclaration'),
            ),
          )
        else ...[
          const Text('✅ Déclaration enregistrée. Vous pouvez joindre une ou plusieurs photos.', style: TextStyle(color: Colors.green)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => captureAndLinkPhoto(context, api, 'SAFETY_EVENT', createdId!),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Ajouter une photo'),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Terminer')),
        ],
      ],
    ),
  );
}

// --- Fiche détaillée : statut, enquête, causes 5M, plan d'actions ---
class SafetyEventDetailPage extends StatefulWidget {
  final String eventId;
  const SafetyEventDetailPage({super.key, required this.eventId});
  @override
  State<SafetyEventDetailPage> createState() => _SafetyEventDetailPageState();
}

class _SafetyEventDetailPageState extends State<SafetyEventDetailPage> {
  final api = Api();
  Map? ev;
  bool loading = true;
  bool saving = false;
  List users = [];
  final form = <String, dynamic>{};

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      ev = Map.from(await api.get('/business/safety-events/${widget.eventId}'));
      users = List.from(await api.get('/users'));
      form['statut'] = ev!['statut'] ?? 'DECLARE';
      form['enqueteurId'] = ev!['enqueteurId'];
      form['methodeAnalyse'] = ev!['methodeAnalyse'];
      form['causeHumaine'] = ev!['causeHumaine'];
      form['causeMethode'] = ev!['causeMethode'];
      form['causeMachine'] = ev!['causeMachine'];
      form['causeMatiere'] = ev!['causeMatiere'];
      form['causeMilieu'] = ev!['causeMilieu'];
      form['causeManagement'] = ev!['causeManagement'];
      form['causeRacine'] = ev!['causeRacine'];
    } catch (_) {}
    setState(() => loading = false);
  }

  Future<void> save() async {
    setState(() => saving = true);
    try {
      await api.patch('/business/safety-events/${widget.eventId}', form);
      await load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enregistré')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    setState(() => saving = false);
  }

  Future<void> addAction() async {
    final t = TextEditingController(text: "Action — ${ev?['title']}");
    String? formError;
    bool s = false;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
        title: const Text('Nouvelle action'),
        content: TextField(controller: t, decoration: const InputDecoration(labelText: 'Titre')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          FilledButton(onPressed: s ? null : () async {
            setD(() => s = true);
            try {
              await api.post('/business/actions', {'code': 'ACT-${DateTime.now().millisecondsSinceEpoch}', 'title': t.text, 'priority': 2, 'status': 'OPEN', 'safetyEventId': widget.eventId});
              if (context.mounted) Navigator.pop(c);
              load();
            } catch (e) { setD(() { s = false; formError = '$e'; }); }
          }, child: Text(s ? '…' : 'Créer')),
        ],
      )),
    );
  }

  Widget _causeField(String key, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(initialValue: form[key], decoration: InputDecoration(labelText: label), onChanged: (v) => form[key] = v),
      );

  @override
  Widget build(BuildContext context) {
    if (loading || ev == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final meta = _types[ev!['type']] ?? ('${ev!['type']}', Icons.info, Colors.grey);
    return Scaffold(
      appBar: AppBar(title: Text(ev!['title'] ?? '')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: ListTile(
          leading: Icon(meta.$2, color: meta.$3, size: 32),
          title: Text('${meta.$1} • ${(ev!['occurredAt'] ?? '').toString().substring(0, 10)}'),
          subtitle: Text('Sévérité ${ev!['severity']}${ev!['zone'] != null ? ' • ${ev!['zone']}' : ''}'),
        )),
        const SizedBox(height: 16),

        DropdownButtonFormField<String>(
          value: form['statut'], isExpanded: true,
          decoration: const InputDecoration(labelText: 'Statut'),
          items: kStatutLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
          onChanged: (v) => setState(() => form['statut'] = v),
        ),
        const SizedBox(height: 16),

        const Text('Enquête', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: form['enqueteurId'], isExpanded: true,
          decoration: const InputDecoration(labelText: 'Enquêteur'),
          items: users.map<DropdownMenuItem<String>>((u) => DropdownMenuItem(value: u['id'] as String, child: Text('${u['firstName']} ${u['lastName']}'))).toList(),
          onChanged: (v) => setState(() => form['enqueteurId'] = v),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: form['methodeAnalyse'], isExpanded: true,
          decoration: const InputDecoration(labelText: "Méthode d'analyse"),
          items: const [
            DropdownMenuItem(value: '5_POURQUOI', child: Text('5 Pourquoi')), DropdownMenuItem(value: 'ARBRE_CAUSES', child: Text('Arbre des causes')),
            DropdownMenuItem(value: 'ISHIKAWA', child: Text('Ishikawa (5M)')), DropdownMenuItem(value: 'AUTRE', child: Text('Autre')),
          ],
          onChanged: (v) => setState(() => form['methodeAnalyse'] = v),
        ),
        const SizedBox(height: 16),

        const Text('Analyse des causes — jamais limitée à « erreur humaine »', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        _causeField('causeHumaine', 'Facteurs humains'),
        _causeField('causeMethode', 'Méthodes'),
        _causeField('causeMachine', 'Machines/équipements'),
        _causeField('causeMatiere', 'Matières/produits'),
        _causeField('causeMilieu', 'Milieu/environnement'),
        _causeField('causeManagement', 'Management/organisation'),
        _causeField('causeRacine', 'Cause racine retenue'),

        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Plan d\'actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          TextButton(onPressed: addAction, child: const Text('+ Action')),
        ]),
        if (List.from(ev!['actions'] ?? []).isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Aucune action liée', style: TextStyle(color: QhseColors.textSecondary)))
        else ...List.from(ev!['actions'] ?? []).map((a) => Card(child: ListTile(dense: true, title: Text(a['title'] ?? ''), trailing: Text(a['status'] ?? '', style: const TextStyle(fontSize: 11))))),

        const SizedBox(height: 20),
        FilledButton(onPressed: saving ? null : save, child: Text(saving ? 'Enregistrement…' : 'Enregistrer')),
      ]),
    );
  }
}
