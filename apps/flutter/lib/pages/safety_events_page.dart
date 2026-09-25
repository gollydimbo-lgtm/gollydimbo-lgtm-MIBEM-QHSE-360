import 'package:flutter/material.dart';
import '../services/api.dart';
import '../services/sync_queue.dart';
import '../theme.dart';
import '../i18n/i18n.dart';
import 'attachment_helpers.dart';
import 'capa_link_widget.dart';
import 'attachments_widget.dart';
import 'load_error_view.dart';
import 'validation_history_widgets.dart';

Map<String, (String, IconData, Color)> _types() => {
  'ACCIDENT': (t('safetyEventsPage.types.accident'), Icons.local_hospital, Colors.red),
  'INCIDENT': (t('safetyEventsPage.types.incident'), Icons.report_problem, Colors.deepOrange),
  'PRESQU_ACCIDENT': (t('safetyEventsPage.types.presquAccident'), Icons.warning_amber, Colors.orange),
  'SITUATION_DANGEREUSE': (t('safetyEventsPage.types.situationDangereuse'), Icons.dangerous, Colors.amber),
};
Map<String, String> _statutLabels() => {
  'DECLARE': t('safetyEventsPage.statuts.declare'), 'SECURISE': t('safetyEventsPage.statuts.securise'), 'INVESTIGATION': t('safetyEventsPage.statuts.investigation'), 'ANALYSE_CAUSES': t('safetyEventsPage.statuts.analyseCauses'),
  'ACTIONS_DEFINIES': t('safetyEventsPage.statuts.actionsDefinies'), 'ACTIONS_EN_COURS': t('safetyEventsPage.statuts.actionsEnCours'), 'VERIFICATION': t('safetyEventsPage.statuts.verification'),
  'VALIDE': t('safetyEventsPage.statuts.valide'), 'CLOTURE': t('safetyEventsPage.statuts.cloture'),
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
  List workedHours = [];
  bool loading = true;
  Object? error;
  int tabIndex = 0;
  // Recherche harmonisée (audit priorité 7, finding #18).
  String search = '';

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      events = List.from(await api.get('/business/safety-events'));
      stats = Map.from(await api.get('/business/safety-events-stats'));
      alertes = List.from(await api.get('/business/safety-events-alertes'));
      recidives = Map.from(await api.get('/business/safety-events-recidives'));
      workedHours = List.from(await api.get('/business/worked-hours'));
    } catch (e) { error = e; }
    setState(() => loading = false);
  }

  Future<void> _showWorkedHoursDialog({Map? record}) async {
    final editing = record != null;
    DateTime periodStart = record != null ? DateTime.parse(record['periodStart']) : DateTime(DateTime.now().year, 1, 1);
    DateTime periodEnd = record != null ? DateTime.parse(record['periodEnd']) : DateTime.now();
    final hoursCtrl = TextEditingController(text: record?['hours']?.toString() ?? '');
    final siteCtrl = TextEditingController(text: record?['site'] ?? '');
    String? error;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dc) => StatefulBuilder(builder: (dc, setD) => AlertDialog(
        title: Text(editing ? t('safetyEventsPage.heures.titreModifier') : t('safetyEventsPage.heures.titreNouveau')),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () async { final d = await showDatePicker(context: dc, initialDate: periodStart, firstDate: DateTime(2000), lastDate: DateTime(2100)); if (d != null) setD(() => periodStart = d); },
              child: Text(t('safetyEventsPage.heures.debut', {'date': periodStart.toIso8601String().substring(0, 10)}), style: const TextStyle(fontSize: 12)),
            )),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton(
              onPressed: () async { final d = await showDatePicker(context: dc, initialDate: periodEnd, firstDate: DateTime(2000), lastDate: DateTime(2100)); if (d != null) setD(() => periodEnd = d); },
              child: Text(t('safetyEventsPage.heures.fin', {'date': periodEnd.toIso8601String().substring(0, 10)}), style: const TextStyle(fontSize: 12)),
            )),
          ]),
          const SizedBox(height: 8),
          TextField(controller: hoursCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: t('safetyEventsPage.heures.heuresLabel'))),
          TextField(controller: siteCtrl, decoration: InputDecoration(labelText: t('safetyEventsPage.heures.siteLabel'))),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: TextStyle(color: QhseColors.red, fontSize: 12))),
        ])),
        actions: [
          if (editing) TextButton(
            onPressed: () async {
              try { await api.delete('/business/worked-hours/${record['id']}'); if (dc.mounted) Navigator.pop(dc, true); }
              catch (e) { setD(() => error = '$e'); }
            },
            child: Text(t('safetyEventsPage.supprimer'), style: TextStyle(color: QhseColors.red)),
          ),
          TextButton(onPressed: () => Navigator.pop(dc, false), child: Text(t('safetyEventsPage.annuler'))),
          FilledButton(
            onPressed: () async {
              final hours = double.tryParse(hoursCtrl.text.replaceAll(',', '.'));
              if (hours == null) { setD(() => error = t('safetyEventsPage.heures.invalides')); return; }
              try {
                final payload = {'periodStart': periodStart.toIso8601String(), 'periodEnd': periodEnd.toIso8601String(), 'hours': hours, 'site': siteCtrl.text.trim()};
                if (editing) { await api.patch('/business/worked-hours/${record['id']}', payload); }
                else { await api.post('/business/worked-hours', {'code': 'HT-${DateTime.now().millisecondsSinceEpoch}', ...payload}); }
                if (dc.mounted) Navigator.pop(dc, true);
              } catch (e) { setD(() => error = '$e'); }
            },
            child: Text(t('safetyEventsPage.enregistrer')),
          ),
        ],
      )),
    );
    if (ok == true) load();
  }

  @override
  Widget build(BuildContext c) {
    final volume = Map.from(stats['volume'] ?? {});
    final pareto = List.from(stats['pareto'] ?? []);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('safetyEventsPage.title')),
          bottom: TabBar(onTap: (i) => setState(() => tabIndex = i), tabs: [Tab(text: t('safetyEventsPage.tabDashboard')), Tab(text: t('safetyEventsPage.tabRegistre')), Tab(text: t('safetyEventsPage.tabHeures'))]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const NewSafetyEventPage())).then((_) => load()),
          icon: const Icon(Icons.add),
          label: Text(t('safetyEventsPage.declarer')),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? LoadErrorView(error: error, onRetry: load)
            : IndexedStack(index: tabIndex, children: [
                RefreshIndicator(
                  onRefresh: load,
                  child: ListView(padding: const EdgeInsets.all(12), children: [
                    KpiBar([
                      KpiStat(t('safetyEventsPage.kpi.evenements'), '${volume['total'] ?? 0}', color: QhseColors.blue, icon: Icons.report_outlined),
                      KpiStat(t('safetyEventsPage.kpi.accidents'), '${volume['accidents'] ?? 0}', color: QhseColors.red, icon: Icons.local_hospital_outlined),
                      KpiStat(t('safetyEventsPage.kpi.avecArret'), '${volume['avecArret'] ?? 0}', color: QhseColors.amber, icon: Icons.timer_off_outlined),
                      KpiStat(t('safetyEventsPage.kpi.graves'), '${volume['graves'] ?? 0}', color: QhseColors.red, icon: Icons.warning_amber_outlined),
                    ]),
                    const SizedBox(height: 16),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(t('safetyEventsPage.alertesTitle'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('${alertes.length}', style: TextStyle(color: QhseColors.textSecondary)),
                    ]),
                    const SizedBox(height: 6),
                    if (alertes.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(t('safetyEventsPage.aucuneAlerte'), style: TextStyle(color: QhseColors.green)))
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
                      Text(t('safetyEventsPage.recidiveTitle'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 6),
                      ...List.from(recidives['parCauseRacine'] ?? []).map((r) => Card(child: ListTile(dense: true, title: Text(r['critere'] ?? ''), subtitle: Text(t('safetyEventsPage.causeRecurrente'), style: const TextStyle(fontSize: 11)), trailing: Text('${r['nombre']}×', style: TextStyle(color: QhseColors.amber, fontWeight: FontWeight.bold))))),
                      const SizedBox(height: 16),
                    ],
                    Text(t('safetyEventsPage.paretoTitle'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 6),
                    if (pareto.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(t('safetyEventsPage.aucuneCauseRacine'), style: TextStyle(color: QhseColors.textSecondary)))
                    else ...pareto.map((p) => Card(child: ListTile(
                          title: Text(p['name'] ?? ''),
                          trailing: Text('${p['value']} (${p['pct']}%, cumul ${p['cumulPct']}%)', style: const TextStyle(fontSize: 11)),
                        ))),
                  ]),
                ),
                RefreshIndicator(
                  onRefresh: load,
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        decoration: InputDecoration(prefixIcon: const Icon(Icons.search, size: 18), hintText: t('safetyEventsPage.searchHint'), isDense: true, border: const OutlineInputBorder()),
                        onChanged: (v) => setState(() => search = v),
                      ),
                    ),
                    Expanded(child: Builder(builder: (_) {
                      final filtered = search.trim().isEmpty
                          ? events
                          : events.where((e) {
                              final meta = _types()[e['type']] ?? ('${e['type']}', Icons.info, Colors.grey);
                              return ('${e['title'] ?? ''} ${meta.$1} ${_statutLabels()[e['statut']] ?? ''}').toLowerCase().contains(search.trim().toLowerCase());
                            }).toList();
                      return filtered.isEmpty
                          ? ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(search.trim().isEmpty ? t('safetyEventsPage.aucunEvenement') : t('safetyEventsPage.aucunResultat'))))])
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: filtered.length,
                              itemBuilder: (_, i) {
                                final e = filtered[i];
                                final meta = _types()[e['type']] ?? ('${e['type']}', Icons.info, Colors.grey);
                                return Card(
                                  child: ListTile(
                                    leading: Icon(meta.$2, color: meta.$3, size: 32),
                                    title: Text('${e['title']}'),
                                    subtitle: Text('${meta.$1} • ${_date(e['occurredAt'])} • ${_statutLabels()[e['statut']] ?? t('safetyEventsPage.statuts.declare')}'),
                                    trailing: severityChip(e['severity'] ?? 1, prefix: ''),
                                    onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => SafetyEventDetailPage(eventId: e['id']))).then((_) => load()),
                                  ),
                                );
                              },
                            );
                    })),
                  ]),
                ),
                RefreshIndicator(
                  onRefresh: load,
                  child: workedHours.isEmpty
                      ? ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(t('safetyEventsPage.aucunePeriode'))))])
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: workedHours.length,
                          itemBuilder: (_, i) {
                            final h = workedHours[i];
                            return Card(child: ListTile(
                              leading: const Icon(Icons.schedule),
                              title: Text('${_date(h['periodStart'])} → ${_date(h['periodEnd'])}'),
                              subtitle: Text('${h['hours']} h${(h['site'] ?? '').toString().isNotEmpty ? ' · ${h['site']}' : ''}'),
                              onTap: () => _showWorkedHoursDialog(record: h),
                            ));
                          },
                        ),
                ),
              ]),
        bottomNavigationBar: tabIndex == 2 ? SafeArea(child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(onPressed: () => _showWorkedHoursDialog(), icon: const Icon(Icons.add), label: Text(t('safetyEventsPage.nouvellePeriode'))),
        )) : null,
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
  // Point 35 — lien optionnel vers le personnel (personne concernée + témoins),
  // en plus de la description libre déjà demandée ci-dessus.
  List employees = [];
  String? employeeId;
  List<String> temoinIds = [];

  @override
  void initState() {
    super.initState();
    api.get('/epi/employees').then((r) { if (mounted) setState(() => employees = List.from(r)); }).catchError((_) {});
  }

  Future<void> gps() async {
    final p = await captureGps(context);
    if (p != null) setState(() { lat = p.latitude; lon = p.longitude; });
  }

  Future<void> submit() async {
    if (title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('safetyEventsPage.titreObligatoire'))));
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
      'employeeId': employeeId,
      'temoinIds': temoinIds,
    };
    try {
      final r = await api.post('/business/safety-events', payload);
      setState(() => createdId = r['id']);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('safetyEventsPage.declarationEnregistree'))));
    } on ApiException catch (e) {
      if (e.networkError) {
        await SyncQueue.enqueue('safetyEvent', 'CREATE', payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('safetyEventsPage.horsLigneMessage')), duration: const Duration(seconds: 4)));
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
    appBar: AppBar(title: Text(t('safetyEventsPage.nouvelleDeclarationTitle'))),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          value: type,
          decoration: InputDecoration(labelText: t('safetyEventsPage.typeLabel')),
          items: _types().entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value.$1))).toList(),
          onChanged: createdId == null ? (v) => setState(() => type = v!) : null,
        ),
        const SizedBox(height: 12),
        TextField(controller: title, enabled: createdId == null, decoration: InputDecoration(labelText: t('safetyEventsPage.titreLabel'))),
        const SizedBox(height: 12),
        TextField(controller: description, enabled: createdId == null, maxLines: 4, decoration: InputDecoration(labelText: t('safetyEventsPage.descriptionLabel'))),
        const SizedBox(height: 12),
        TextField(controller: zone, enabled: createdId == null, decoration: InputDecoration(labelText: t('safetyEventsPage.zoneLabel'))),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: typePersonnel, isExpanded: true,
          decoration: InputDecoration(labelText: t('safetyEventsPage.typePersonnelLabel')),
          items: [
            DropdownMenuItem(value: 'SALARIE', child: Text(t('safetyEventsPage.personnel.salarie'))), DropdownMenuItem(value: 'INTERIMAIRE', child: Text(t('safetyEventsPage.personnel.interimaire'))),
            DropdownMenuItem(value: 'SOUS_TRAITANT', child: Text(t('safetyEventsPage.personnel.sousTraitant'))), DropdownMenuItem(value: 'VISITEUR', child: Text(t('safetyEventsPage.personnel.visiteur'))), DropdownMenuItem(value: 'AUTRE', child: Text(t('safetyEventsPage.personnel.autre'))),
          ],
          onChanged: createdId == null ? (v) => setState(() => typePersonnel = v) : null,
        ),
        const SizedBox(height: 12),
        if (employees.isNotEmpty) ...[
          DropdownButtonFormField<String>(
            value: employeeId, isExpanded: true,
            decoration: InputDecoration(labelText: t('safetyEventsPage.employeLabel')),
            items: employees.map<DropdownMenuItem<String>>((e) => DropdownMenuItem(value: e['id'] as String, child: Text('${e['firstName']} ${e['lastName']}'))).toList(),
            onChanged: createdId == null ? (v) => setState(() => employeeId = v) : null,
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: InputDecoration(labelText: t('safetyEventsPage.temoinsLabel'), border: const OutlineInputBorder()),
            child: Wrap(spacing: 6, runSpacing: 4, children: employees.map<Widget>((e) {
              final id = e['id'] as String;
              final selected = temoinIds.contains(id);
              return FilterChip(
                label: Text('${e['firstName']} ${e['lastName']}', style: const TextStyle(fontSize: 11)),
                selected: selected,
                onSelected: createdId == null ? (v) => setState(() => v ? temoinIds.add(id) : temoinIds.remove(id)) : null,
              );
            }).toList()),
          ),
        ],
        const SizedBox(height: 12),
        Text(t('safetyEventsPage.severiteValeur', {'value': '$severity'}), style: const TextStyle(fontWeight: FontWeight.bold)),
        Slider(value: severity.toDouble(), min: 1, max: 5, divisions: 4, label: '$severity', onChanged: createdId == null ? (v) => setState(() => severity = v.round()) : null),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: createdId == null ? gps : null,
          icon: const Icon(Icons.gps_fixed),
          label: Text(lat == null ? t('safetyEventsPage.capturerGps') : 'GPS ${lat!.toStringAsFixed(5)}, ${lon!.toStringAsFixed(5)}'),
        ),
        const SizedBox(height: 20),
        if (createdId == null)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy ? null : submit,
              icon: const Icon(Icons.send),
              label: Text(busy ? t('safetyEventsPage.envoiEnCours') : t('safetyEventsPage.envoyerDeclaration')),
            ),
          )
        else ...[
          Text('✅ ${t('safetyEventsPage.declarationEnregistreeMsg')}', style: const TextStyle(color: Colors.green)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => captureAndLinkPhoto(context, api, 'SAFETY_EVENT', createdId!),
            icon: const Icon(Icons.camera_alt),
            label: Text(t('safetyEventsPage.ajouterPhoto')),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => Navigator.pop(context), child: Text(t('safetyEventsPage.terminer'))),
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('safetyEventsPage.enregistreMsg'))));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    setState(() => saving = false);
  }

  Future<void> addAction() async {
    final actionTitleCtrl = TextEditingController(text: '${t('safetyEventsPage.actionPrefix')} ${ev?['title']}');
    String? formError;
    bool s = false;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
        title: Text(t('safetyEventsPage.nouvelleActionTitle')),
        content: TextField(controller: actionTitleCtrl, decoration: InputDecoration(labelText: t('safetyEventsPage.actionTitreLabel'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(t('safetyEventsPage.annuler'))),
          FilledButton(onPressed: s ? null : () async {
            setD(() => s = true);
            try {
              await api.post('/business/actions', {'code': 'ACT-${DateTime.now().millisecondsSinceEpoch}', 'title': actionTitleCtrl.text, 'priority': 2, 'status': 'OPEN', 'safetyEventId': widget.eventId});
              if (context.mounted) Navigator.pop(c);
              load();
            } catch (e) { setD(() { s = false; formError = '$e'; }); }
          }, child: Text(s ? '…' : t('safetyEventsPage.creer'))),
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
    final meta = _types()[ev!['type']] ?? ('${ev!['type']}', Icons.info, Colors.grey);
    return Scaffold(
      appBar: AppBar(title: Text(ev!['title'] ?? '')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: ListTile(
          leading: Icon(meta.$2, color: meta.$3, size: 32),
          title: Text('${meta.$1} • ${(ev!['occurredAt'] ?? '').toString().substring(0, 10)}'),
          subtitle: Text('${t('safetyEventsPage.severiteValeur', {'value': '${ev!['severity']}'})}${ev!['zone'] != null ? ' • ${ev!['zone']}' : ''}'),
        )),
        const SizedBox(height: 16),

        DropdownButtonFormField<String>(
          value: form['statut'], isExpanded: true,
          decoration: InputDecoration(labelText: t('safetyEventsPage.statutLabel')),
          items: _statutLabels().entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
          onChanged: (v) => setState(() => form['statut'] = v),
        ),
        const SizedBox(height: 16),

        Text(t('safetyEventsPage.enqueteTitle'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: form['enqueteurId'], isExpanded: true,
          decoration: InputDecoration(labelText: t('safetyEventsPage.enqueteurLabel')),
          items: users.map<DropdownMenuItem<String>>((u) => DropdownMenuItem(value: u['id'] as String, child: Text('${u['firstName']} ${u['lastName']}'))).toList(),
          onChanged: (v) => setState(() => form['enqueteurId'] = v),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: form['methodeAnalyse'], isExpanded: true,
          decoration: InputDecoration(labelText: t('safetyEventsPage.methodeAnalyseLabel')),
          items: [
            DropdownMenuItem(value: '5_POURQUOI', child: Text(t('safetyEventsPage.methode.cinqPourquoi'))), DropdownMenuItem(value: 'ARBRE_CAUSES', child: Text(t('safetyEventsPage.methode.arbreCauses'))),
            DropdownMenuItem(value: 'ISHIKAWA', child: Text(t('safetyEventsPage.methode.ishikawa'))), DropdownMenuItem(value: 'AUTRE', child: Text(t('safetyEventsPage.methode.autre'))),
          ],
          onChanged: (v) => setState(() => form['methodeAnalyse'] = v),
        ),
        const SizedBox(height: 16),

        Text(t('safetyEventsPage.analyseCausesTitle'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        _causeField('causeHumaine', t('safetyEventsPage.cause.humains')),
        _causeField('causeMethode', t('safetyEventsPage.cause.methodes')),
        _causeField('causeMachine', t('safetyEventsPage.cause.machines')),
        _causeField('causeMatiere', t('safetyEventsPage.cause.matieres')),
        _causeField('causeMilieu', t('safetyEventsPage.cause.milieu')),
        _causeField('causeManagement', t('safetyEventsPage.cause.management')),
        _causeField('causeRacine', t('safetyEventsPage.cause.racine')),

        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(t('safetyEventsPage.planActionsTitle'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          TextButton(onPressed: addAction, child: Text(t('safetyEventsPage.ajouterActionBtn'))),
        ]),
        if (List.from(ev!['actions'] ?? []).isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(t('safetyEventsPage.aucuneActionLiee'), style: TextStyle(color: QhseColors.textSecondary)))
        else ...List.from(ev!['actions'] ?? []).map((a) => Card(child: ListTile(dense: true, title: Text(a['title'] ?? ''), trailing: Text(a['status'] ?? '', style: const TextStyle(fontSize: 11))))),

        const SizedBox(height: 20),
        CapaLinksSection(sourceModule: 'SAFETY_EVENT', sourceEntityId: widget.eventId, prefill: {'title': '${t('safetyEventsPage.actionPrefix')} ${ev!['title'] ?? ''}', 'source': 'SAFETY_EVENT'}),
        const SizedBox(height: 12),
        HistorySection(module: 'SAFETY_EVENT', entityId: widget.eventId),

        const SizedBox(height: 20),
        AttachmentsSection(ownerType: 'SAFETY_EVENT', ownerId: widget.eventId),

        const SizedBox(height: 12),
        FilledButton(onPressed: saving ? null : save, child: Text(saving ? t('safetyEventsPage.enregistrementEnCours') : t('safetyEventsPage.enregistrer'))),
      ]),
    );
  }
}
