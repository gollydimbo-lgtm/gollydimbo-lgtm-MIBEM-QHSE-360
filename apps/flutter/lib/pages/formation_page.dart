import 'package:flutter/material.dart';
import '../services/api.dart';
import '../theme.dart';
import 'attachment_helpers.dart';

// ============================================================================
// FORMATION & COMPÉTENCES — Phase 1 (parité avec FormationPage côté web) :
// distinction INDUCTION / FORMATION, plan de formation, registre des
// habilitations avec statut calculé côté serveur selon les seuils
// d'alerte configurés. La gestion détaillée des participants/évaluations
// d'une session reste pour l'instant réservée au web (voir App.jsx) ;
// le mobile consulte et crée/modifie les fiches.
// ============================================================================

const trainingTypeLabels = {'INDUCTION': 'Induction', 'FORMATION': 'Formation'};
const trainingStatusLabels = {
  'DRAFT': 'Brouillon', 'PLANNED': 'Planifiée', 'PROGRAMMED': 'Programmée', 'IN_PROGRESS': 'En cours',
  'REALISEE': 'Réalisée', 'REPORTEE': 'Reportée', 'ANNULEE': 'Annulée', 'CLOTUREE': 'Clôturée',
};
String trainingStatusLabel(Map t) {
  final status = t['status'];
  final scheduledAt = t['scheduledAt'] != null ? DateTime.parse(t['scheduledAt']) : null;
  if (status != 'REALISEE' && status != 'CLOTUREE' && status != 'ANNULEE' && scheduledAt != null && scheduledAt.isBefore(DateTime.now())) return 'En retard';
  return trainingStatusLabels[status] ?? status ?? '—';
}
Color trainingStatusColor(Map t) {
  final status = t['status'];
  if (status == 'REALISEE' || status == 'CLOTUREE') return QhseColors.green;
  if (status == 'ANNULEE') return QhseColors.textSecondary;
  if (status == 'REPORTEE') return QhseColors.amber;
  final scheduledAt = t['scheduledAt'] != null ? DateTime.parse(t['scheduledAt']) : null;
  if (scheduledAt != null && scheduledAt.isBefore(DateTime.now())) return QhseColors.red;
  return QhseColors.blue;
}
const habilitationStatutLabels = {
  'VALIDE': 'Valide', 'EXPIRE_BIENTOT': 'Expire bientôt', 'A_RENOUVELER': 'À renouveler',
  'EXPIREE': 'Expirée', 'SUSPENDUE': 'Suspendue', 'EN_ATTENTE': 'En attente de renouvellement',
};
Color habilitationStatutColor(String? s) => {
      'VALIDE': QhseColors.green, 'EXPIRE_BIENTOT': QhseColors.amber, 'A_RENOUVELER': QhseColors.amber,
      'EXPIREE': QhseColors.red, 'SUSPENDUE': QhseColors.textSecondary, 'EN_ATTENTE': QhseColors.blue,
    }[s] ?? QhseColors.textSecondary;

class FormationPage extends StatefulWidget {
  const FormationPage({super.key});
  @override
  State<FormationPage> createState() => _FormationPageState();
}

class _FormationPageState extends State<FormationPage> {
  final api = Api();
  List trainings = [], habilitations = [], employees = [];
  Map dashboard = {};
  bool loading = true;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      trainings = List.from(await api.get('/business/trainings'));
      habilitations = List.from(await api.get('/business/habilitations'));
      employees = List.from(await api.get('/epi/employees'));
      dashboard = Map.from(await api.get('/business/formation-dashboard'));
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext c) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Formation & Compétences'),
        bottom: const TabBar(tabs: [Tab(text: 'Plan de formation'), Tab(text: 'Habilitations')]),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [_buildKpis(c), Expanded(child: TabBarView(children: [_buildPlan(c), _buildHabilitations(c)]))]),
      floatingActionButton: Builder(builder: (bc) {
        final tabIndex = DefaultTabController.of(bc).index;
        return FloatingActionButton.extended(
          onPressed: () async {
            if (DefaultTabController.of(bc).index == 0) {
              await Navigator.push(c, MaterialPageRoute(builder: (_) => const TrainingFormPage()));
            } else {
              await Navigator.push(c, MaterialPageRoute(builder: (_) => TrainingFormPage(employees: employees, habilitation: true)));
            }
            load();
          },
          icon: const Icon(Icons.add),
          label: Text(tabIndex == 0 ? 'Formation' : 'Habilitation'),
        );
      }),
    ),
  );

  Widget _kpiCard(String label, String value, Color color) => Container(
    margin: const EdgeInsets.only(right: 8),
    padding: const EdgeInsets.all(12),
    width: 150,
    decoration: BoxDecoration(color: QhseColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: QhseColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 11, color: QhseColors.textSecondary)),
    ]),
  );

  Widget _buildKpis(BuildContext c) {
    final plan = Map.from(dashboard['plan'] ?? {});
    final hab = Map.from(dashboard['habilitations'] ?? {});
    final tauxRealisation = plan['tauxRealisation'];
    return SizedBox(
      height: 90,
      child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(12), children: [
        _kpiCard('Prévues', '${plan['prevues'] ?? 0}', QhseColors.blue),
        _kpiCard('Taux réalisation', tauxRealisation != null ? '$tauxRealisation%' : '—', QhseColors.green),
        _kpiCard('En retard', '${plan['enRetard'] ?? 0}', (plan['enRetard'] ?? 0) > 0 ? QhseColors.red : QhseColors.green),
        _kpiCard('Habilitations valides', '${hab['valides'] ?? 0}', QhseColors.green),
        _kpiCard('Expirent bientôt', '${hab['expirantBientot'] ?? 0}', (hab['expirantBientot'] ?? 0) > 0 ? QhseColors.amber : QhseColors.green),
        _kpiCard('Expirées', '${hab['expirees'] ?? 0}', (hab['expirees'] ?? 0) > 0 ? QhseColors.red : QhseColors.green),
      ]),
    );
  }

  Widget _buildPlan(BuildContext c) => RefreshIndicator(
    onRefresh: load,
    child: trainings.isEmpty
        ? ListView(children: const [Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Aucune formation enregistrée')))])
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: trainings.length,
            itemBuilder: (_, i) {
              final t = trainings[i];
              final color = trainingStatusColor(t);
              return Card(child: ListTile(
                leading: CircleAvatar(backgroundColor: color.withOpacity(0.15), child: Icon(t['type'] == 'INDUCTION' ? Icons.badge_outlined : Icons.school_outlined, color: color)),
                title: Text('${t['title']}'),
                subtitle: Text('${trainingTypeLabels[t['type']] ?? t['type']} · ${t['scheduledAt'] != null ? DateTime.parse(t['scheduledAt']).toIso8601String().substring(0, 10) : '—'}${t['obligatoire'] == true ? ' · obligatoire' : ''}'),
                trailing: Chip(label: Text(trainingStatusLabel(t), style: TextStyle(color: color, fontSize: 11)), backgroundColor: color.withOpacity(0.15)),
                onTap: () async {
                  await Navigator.push(c, MaterialPageRoute(builder: (_) => TrainingFormPage(record: t)));
                  load();
                },
              ));
            },
          ),
  );

  Widget _buildHabilitations(BuildContext c) => RefreshIndicator(
    onRefresh: load,
    child: habilitations.isEmpty
        ? ListView(children: const [Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Aucune habilitation enregistrée')))])
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: habilitations.length,
            itemBuilder: (_, i) {
              final h = habilitations[i];
              final color = habilitationStatutColor(h['statut']);
              final emp = h['employee'];
              return Card(child: ListTile(
                leading: CircleAvatar(backgroundColor: color.withOpacity(0.15), child: Icon(Icons.verified_outlined, color: color)),
                title: Text('${h['intitule']}'),
                subtitle: Text('${emp != null ? '${emp['firstName']} ${emp['lastName']}' : '—'} · expire le ${h['dateExpiration'] != null ? DateTime.parse(h['dateExpiration']).toIso8601String().substring(0, 10) : '—'}'),
                trailing: Chip(label: Text(habilitationStatutLabels[h['statut']] ?? h['statut'] ?? '—', style: TextStyle(color: color, fontSize: 11)), backgroundColor: color.withOpacity(0.15)),
                onTap: () async {
                  await Navigator.push(c, MaterialPageRoute(builder: (_) => TrainingFormPage(employees: employees, habilitation: true, record: h)));
                  load();
                },
              ));
            },
          ),
  );
}

/// Formulaire unique pour Formation/Induction ET Habilitation — le
/// paramètre [habilitation] bascule le jeu de champs affiché, pour éviter
/// deux écrans quasi identiques (principe de non-duplication du cahier des
/// charges).
class TrainingFormPage extends StatefulWidget {
  final Map? record;
  final bool habilitation;
  final List? employees;
  const TrainingFormPage({super.key, this.record, this.habilitation = false, this.employees});
  @override
  State<TrainingFormPage> createState() => _TrainingFormPageState();
}

class _TrainingFormPageState extends State<TrainingFormPage> {
  final api = Api();
  final _formKey = GlobalKey<FormState>();
  late Map form;
  List employees = [];
  bool saving = false;
  bool loadingEmployees = false;

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    if (widget.habilitation) {
      form = {
        'employeeId': r?['employeeId'], 'intitule': r?['intitule'] ?? '', 'organisme': r?['organisme'] ?? '',
        'numeroDocument': r?['numeroDocument'] ?? '', 'dateObtention': r?['dateObtention'], 'dateExpiration': r?['dateExpiration'],
        'notes': r?['notes'] ?? '',
      };
    } else {
      form = {
        'title': r?['title'] ?? '', 'type': r?['type'] ?? 'FORMATION', 'domaine': r?['domaine'] ?? '',
        'publicCible': r?['publicCible'] ?? '', 'objectif': r?['objectif'] ?? '', 'trainer': r?['trainer'] ?? '',
        'organisme': r?['organisme'] ?? '', 'interneExterne': r?['interneExterne'] ?? 'INTERNE',
        'competenceVisee': r?['competenceVisee'] ?? '', 'scheduledAt': r?['scheduledAt'],
        'durationHours': r?['durationHours']?.toString() ?? '', 'status': r?['status'] ?? 'PLANNED',
        'obligatoire': r?['obligatoire'] ?? false, 'coutPrevu': r?['coutPrevu']?.toString() ?? '',
        'budgetAlloue': r?['budgetAlloue']?.toString() ?? '', 'service': r?['service'] ?? '',
      };
    }
    if (widget.employees != null) {
      employees = widget.employees!;
    } else if (widget.habilitation) {
      _loadEmployees();
    }
  }

  Future<void> _loadEmployees() async {
    setState(() => loadingEmployees = true);
    try { employees = List.from(await api.get('/epi/employees')); } catch (_) {}
    if (mounted) setState(() => loadingEmployees = false);
  }

  Future<void> _pickDate(String field) async {
    final initial = form[field] != null ? DateTime.tryParse(form[field]) ?? DateTime.now() : DateTime.now();
    final picked = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2015), lastDate: DateTime(2100));
    if (picked != null) setState(() => form[field] = picked.toIso8601String());
  }

  Future<void> save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      final editing = widget.record != null;
      if (widget.habilitation) {
        final payload = {
          'employeeId': form['employeeId'], 'intitule': form['intitule'], 'organisme': _n(form['organisme']),
          'numeroDocument': _n(form['numeroDocument']), 'dateObtention': form['dateObtention'], 'dateExpiration': form['dateExpiration'],
          'notes': _n(form['notes']),
        };
        if (editing) {
          await api.patch('/business/habilitations/${widget.record!['id']}', payload);
        } else {
          await api.post('/business/habilitations', {'code': genCode('HAB'), ...payload});
        }
      } else {
        final payload = {
          'title': form['title'], 'type': form['type'], 'domaine': _n(form['domaine']), 'publicCible': _n(form['publicCible']),
          'objectif': _n(form['objectif']), 'trainer': _n(form['trainer']), 'organisme': _n(form['organisme']),
          'interneExterne': form['interneExterne'], 'competenceVisee': _n(form['competenceVisee']),
          'scheduledAt': form['scheduledAt'], 'durationHours': form['durationHours'] == '' ? null : double.tryParse(form['durationHours']),
          'status': form['status'], 'obligatoire': form['obligatoire'],
          'coutPrevu': form['coutPrevu'] == '' ? null : double.tryParse(form['coutPrevu']),
          'budgetAlloue': form['budgetAlloue'] == '' ? null : double.tryParse(form['budgetAlloue']),
          'service': _n(form['service']),
        };
        if (editing) {
          await api.patch('/business/trainings/${widget.record!['id']}', payload);
        } else {
          await api.post('/business/trainings', {'code': genCode(form['type'] == 'INDUCTION' ? 'IND' : 'FOR'), ...payload});
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
    if (mounted) setState(() => saving = false);
  }

  String? _n(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();

  Future<void> _delete() async {
    if (widget.record == null) return;
    final confirm = await showDialog<bool>(context: context, builder: (dc) => AlertDialog(
      title: const Text('Supprimer ?'),
      content: Text('Confirmer la suppression de "${widget.record!['title'] ?? widget.record!['intitule']}" ?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dc, false), child: const Text('Annuler')),
        TextButton(onPressed: () => Navigator.pop(dc, true), child: const Text('Supprimer', style: TextStyle(color: Colors.red))),
      ],
    ));
    if (confirm != true) return;
    try {
      final path = widget.habilitation ? '/business/habilitations/${widget.record!['id']}' : '/business/trainings/${widget.record!['id']}';
      await api.delete(path);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  InputDecoration _dec(String label) => InputDecoration(labelText: label, border: const OutlineInputBorder());

  @override
  Widget build(BuildContext c) {
    final editing = widget.record != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.habilitation
            ? (editing ? "Modifier l'habilitation" : 'Nouvelle habilitation')
            : (editing ? 'Modifier la formation' : 'Nouvelle formation / induction')),
        actions: [if (editing) IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline))],
      ),
      body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: widget.habilitation ? _habilitationFields(c) : _trainingFields(c)),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(onPressed: saving ? null : save, child: Text(saving ? 'Enregistrement…' : 'Enregistrer')),
      ),
    );
  }

  List<Widget> _habilitationFields(BuildContext c) => [
    loadingEmployees
        ? const Center(child: CircularProgressIndicator())
        : DropdownButtonFormField<String>(
            decoration: _dec('Collaborateur'), value: form['employeeId'],
            items: employees.map<DropdownMenuItem<String>>((e) => DropdownMenuItem(value: e['id'] as String, child: Text('${e['firstName']} ${e['lastName']}'))).toList(),
            onChanged: (v) => setState(() => form['employeeId'] = v),
            validator: (v) => v == null ? 'Requis' : null,
          ),
    const SizedBox(height: 12),
    TextFormField(initialValue: form['intitule'], decoration: _dec('Intitulé'), validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null, onChanged: (v) => form['intitule'] = v),
    const SizedBox(height: 12),
    TextFormField(initialValue: form['organisme'], decoration: _dec('Organisme (optionnel)'), onChanged: (v) => form['organisme'] = v),
    const SizedBox(height: 12),
    TextFormField(initialValue: form['numeroDocument'], decoration: _dec('N° de document (optionnel)'), onChanged: (v) => form['numeroDocument'] = v),
    const SizedBox(height: 12),
    ListTile(contentPadding: EdgeInsets.zero, title: const Text("Date d'obtention"), subtitle: Text(form['dateObtention'] != null ? DateTime.parse(form['dateObtention']).toIso8601String().substring(0, 10) : '—'), trailing: const Icon(Icons.calendar_today, size: 18), onTap: () => _pickDate('dateObtention')),
    ListTile(contentPadding: EdgeInsets.zero, title: const Text("Date d'expiration"), subtitle: Text(form['dateExpiration'] != null ? DateTime.parse(form['dateExpiration']).toIso8601String().substring(0, 10) : '—'), trailing: const Icon(Icons.calendar_today, size: 18), onTap: () => _pickDate('dateExpiration')),
    const SizedBox(height: 12),
    TextFormField(initialValue: form['notes'], decoration: _dec('Notes (optionnel)'), maxLines: 2, onChanged: (v) => form['notes'] = v),
  ];

  List<Widget> _trainingFields(BuildContext c) => [
    TextFormField(initialValue: form['title'], decoration: _dec('Intitulé'), validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null, onChanged: (v) => form['title'] = v),
    const SizedBox(height: 12),
    DropdownButtonFormField<String>(
      decoration: _dec('Type'), value: form['type'],
      items: const [DropdownMenuItem(value: 'FORMATION', child: Text('Formation')), DropdownMenuItem(value: 'INDUCTION', child: Text('Induction (accueil sécurité)'))],
      onChanged: (v) => setState(() => form['type'] = v),
    ),
    const SizedBox(height: 12),
    TextFormField(initialValue: form['domaine'], decoration: _dec('Domaine (optionnel)'), onChanged: (v) => form['domaine'] = v),
    const SizedBox(height: 12),
    TextFormField(initialValue: form['publicCible'], decoration: _dec('Public cible (optionnel)'), onChanged: (v) => form['publicCible'] = v),
    const SizedBox(height: 12),
    TextFormField(initialValue: form['service'], decoration: _dec('Service concerné (optionnel)'), onChanged: (v) => form['service'] = v),
    const SizedBox(height: 12),
    TextFormField(initialValue: form['objectif'], decoration: _dec('Objectif (optionnel)'), maxLines: 2, onChanged: (v) => form['objectif'] = v),
    const SizedBox(height: 12),
    TextFormField(initialValue: form['trainer'], decoration: _dec('Formateur (optionnel)'), onChanged: (v) => form['trainer'] = v),
    const SizedBox(height: 12),
    DropdownButtonFormField<String>(
      decoration: _dec('Interne / externe'), value: form['interneExterne'],
      items: const [DropdownMenuItem(value: 'INTERNE', child: Text('Interne')), DropdownMenuItem(value: 'EXTERNE', child: Text('Externe'))],
      onChanged: (v) => setState(() => form['interneExterne'] = v),
    ),
    const SizedBox(height: 12),
    TextFormField(initialValue: form['organisme'], decoration: _dec('Organisme (optionnel)'), onChanged: (v) => form['organisme'] = v),
    const SizedBox(height: 12),
    TextFormField(initialValue: form['competenceVisee'], decoration: _dec('Compétence visée (optionnel)'), onChanged: (v) => form['competenceVisee'] = v),
    const SizedBox(height: 12),
    ListTile(contentPadding: EdgeInsets.zero, title: const Text('Date prévue'), subtitle: Text(form['scheduledAt'] != null ? DateTime.parse(form['scheduledAt']).toIso8601String().substring(0, 10) : 'Choisir…'), trailing: const Icon(Icons.calendar_today, size: 18), onTap: () => _pickDate('scheduledAt')),
    const SizedBox(height: 12),
    TextFormField(initialValue: form['durationHours'], decoration: _dec('Durée en heures (optionnel)'), keyboardType: TextInputType.number, onChanged: (v) => form['durationHours'] = v),
    const SizedBox(height: 12),
    DropdownButtonFormField<String>(
      decoration: _dec('Statut'), value: form['status'],
      items: trainingStatusLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
      onChanged: (v) => setState(() => form['status'] = v),
    ),
    const SizedBox(height: 12),
    TextFormField(initialValue: form['coutPrevu'], decoration: _dec('Coût prévu (optionnel)'), keyboardType: TextInputType.number, onChanged: (v) => form['coutPrevu'] = v),
    const SizedBox(height: 12),
    TextFormField(initialValue: form['budgetAlloue'], decoration: _dec('Budget alloué (optionnel)'), keyboardType: TextInputType.number, onChanged: (v) => form['budgetAlloue'] = v),
    const SizedBox(height: 12),
    SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Formation obligatoire'), value: form['obligatoire'] == true, onChanged: (v) => setState(() => form['obligatoire'] = v)),
  ];
}
</content>
