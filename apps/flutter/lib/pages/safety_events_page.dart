import 'package:flutter/material.dart';
import '../services/api.dart';
import '../services/sync_queue.dart';
import '../main.dart';
import '../theme.dart';
import 'attachment_helpers.dart';

const _types = {
  'ACCIDENT': ('Accident', Icons.local_hospital, Colors.red),
  'INCIDENT': ('Incident', Icons.report_problem, Colors.deepOrange),
  'PRESQU_ACCIDENT': ('Presqu\'accident', Icons.warning_amber, Colors.orange),
  'SITUATION_DANGEREUSE': ('Situation dangereuse', Icons.dangerous, Colors.amber),
};

class SafetyEventsPage extends StatefulWidget {
  const SafetyEventsPage({super.key});
  @override
  State<SafetyEventsPage> createState() => _SafetyEventsPageState();
}

class _SafetyEventsPageState extends State<SafetyEventsPage> {
  final api = Api();
  List events = [];
  List workedHours = [];
  bool loading = true;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      events = List.from(await api.get('/business/safety-events'));
      workedHours = List.from(await api.get('/business/worked-hours'));
    } catch (_) {}
    setState(() => loading = false);
  }

  Future<void> delete(Map e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Supprimer définitivement « ${e['title']} » ? Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Supprimer', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.delete('/business/safety-events/${e['id']}');
      load();
    } catch (err) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$err')));
    }
  }

  Future<void> _openWorkedHoursDialog(BuildContext context) async {
    final hours = TextEditingController();
    final site = TextEditingController();
    DateTime periodStart = DateTime(DateTime.now().year, 1, 1);
    DateTime periodEnd = DateTime.now();
    String? formError;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
        title: const Text('Heures travaillées'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              title: Text('Début : ${periodStart.day}/${periodStart.month}/${periodStart.year}'),
              trailing: const Icon(Icons.edit_calendar),
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: periodStart, firstDate: DateTime(2020), lastDate: DateTime(2035));
                if (d != null) setD(() => periodStart = d);
              },
            ),
            ListTile(
              title: Text('Fin : ${periodEnd.day}/${periodEnd.month}/${periodEnd.year}'),
              trailing: const Icon(Icons.edit_calendar),
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: periodEnd, firstDate: DateTime(2020), lastDate: DateTime(2035));
                if (d != null) setD(() => periodEnd = d);
              },
            ),
            TextField(controller: hours, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Heures travaillées (total)')),
            TextField(controller: site, decoration: const InputDecoration(labelText: 'Site (optionnel)')),
            if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              try {
                await api.post('/business/worked-hours', {
                  'code': 'HT-${DateTime.now().millisecondsSinceEpoch}',
                  'periodStart': periodStart.toIso8601String(), 'periodEnd': periodEnd.toIso8601String(),
                  'hours': double.tryParse(hours.text) ?? 0, 'site': site.text.trim().isEmpty ? null : site.text.trim(),
                });
                if (context.mounted) Navigator.pop(c);
                load();
              } catch (e) {
                setD(() => formError = '$e');
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      )),
    );
  }

  List<KpiStat> get kpis {
    final moyenne = events.isEmpty ? 0.0 : events.fold<num>(0, (s, e) => s + ((e['severity'] ?? 1) as num)) / events.length;
    final typesDistincts = events.map((e) => e['type']).toSet().length;
    final yearStart = DateTime(DateTime.now().year, 1, 1);
    final eventsThisYear = events.where((e) => DateTime.parse(e['occurredAt']).isAfter(yearStart)).toList();
    final hoursThisYear = workedHours.where((h) => DateTime.parse(h['periodEnd']).isAfter(yearStart));
    final totalHours = hoursThisYear.fold<num>(0, (s, h) => s + ((h['hours'] ?? 0) as num));
    final accidentsAvecArret = eventsThisYear.where((e) => e['withLostTime'] == true).length;
    final joursPerdus = eventsThisYear.fold<num>(0, (s, e) => s + (e['withLostTime'] == true ? ((e['lostDays'] ?? 0) as num) : 0));
    final tf = totalHours > 0 ? (accidentsAvecArret * 1000000 / totalHours) : null;
    final tg = totalHours > 0 ? (joursPerdus * 1000 / totalHours) : null;
    return [
      KpiStat('Événements', '${events.length}', color: QhseColors.blue, icon: Icons.warning_amber_outlined),
      KpiStat('Sévérité moyenne', moyenne.toStringAsFixed(1), color: QhseColors.amber, icon: Icons.trending_up),
      KpiStat('Taux de Fréquence', tf == null ? '—' : tf.toStringAsFixed(1), color: QhseColors.red, icon: Icons.speed),
      KpiStat('Taux de Gravité', tg == null ? '—' : tg.toStringAsFixed(2), color: QhseColors.red, icon: Icons.trending_down),
    ];
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Accidents & situations dangereuses'), actions: [
      IconButton(icon: const Icon(Icons.schedule), tooltip: 'Heures travaillées', onPressed: () => _openWorkedHoursDialog(c)),
    ]),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const NewSafetyEventPage())).then((_) => load()),
      icon: const Icon(Icons.add),
      label: const Text('Déclarer'),
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: load,
            child: Column(children: [
              Padding(padding: const EdgeInsets.only(top: 12), child: KpiBar(kpis)),
              Expanded(
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
                              subtitle: Text('${meta.$1} • ${_date(e['occurredAt'])}'),
                              trailing: severityChip(e['severity'] ?? 1, prefix: ''),
                              onLongPress: () => delete(e),
                            ),
                          );
                        },
                      ),
              ),
            ]),
          ),
  );

  String _date(dynamic v) => v == null ? '' : v.toString().substring(0, 16).replaceFirst('T', ' ');
}

class NewSafetyEventPage extends StatefulWidget {
  const NewSafetyEventPage({super.key});
  @override
  State<NewSafetyEventPage> createState() => _NewSafetyEventPageState();
}

class _NewSafetyEventPageState extends State<NewSafetyEventPage> {
  final api = Api();
  final title = TextEditingController();
  final description = TextEditingController();
  String type = 'ACCIDENT';
  int severity = 2;
  bool withLostTime = false;
  int lostDays = 0;
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
      'withLostTime': withLostTime,
      'lostDays': withLostTime ? lostDays : null,
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
        Text('Sévérité : $severity', style: const TextStyle(fontWeight: FontWeight.bold)),
        Slider(value: severity.toDouble(), min: 1, max: 5, divisions: 4, label: '$severity', onChanged: createdId == null ? (v) => setState(() => severity = v.round()) : null),
        const SizedBox(height: 8),
        CheckboxListTile(
          value: withLostTime,
          title: const Text('Accident avec arrêt de travail'),
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: createdId == null ? (v) => setState(() => withLostTime = v ?? false) : null,
        ),
        if (withLostTime)
          TextFormField(
            initialValue: '$lostDays',
            enabled: createdId == null,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Nombre de journées perdues'),
            onChanged: (v) => lostDays = int.tryParse(v) ?? 0,
          ),
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
