import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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
String _csvEscape(String v) => v.contains(',') || v.contains('"') || v.contains('\n') ? '"${v.replaceAll('"', '""')}"' : v;

class ProcessusDetailPage extends StatefulWidget {
  final Map p;
  const ProcessusDetailPage({super.key, required this.p});
  @override
  State<ProcessusDetailPage> createState() => _ProcessusDetailPageState();
}

class _ProcessusDetailPageState extends State<ProcessusDetailPage> {
  final api = Api();
  late Map p;
  List activities = [];
  List exigences = [];
  bool loadingSub = true;
  bool exporting = false;

  @override
  void initState() { super.initState(); p = widget.p; loadSub(); }

  Future<void> loadSub() async {
    setState(() => loadingSub = true);
    try {
      activities = List.from(await api.get('/business/processus/${p['id']}/activities'));
      exigences = List.from(await api.get('/business/processus/${p['id']}/exigences'));
    } catch (_) {}
    setState(() => loadingSub = false);
  }

  // --- SIPOC : listes simples S/I/O/C, chaque catégorie enregistrée
  // directement sur le processus (champ JSON), sans écran dédié séparé.
  Future<void> _editSipocList(String field, String label) async {
    List current = List<String>.from(p[field] ?? []);
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
        title: Text(label),
        content: SizedBox(
          width: 320,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Wrap(spacing: 6, runSpacing: 6, children: current.map((item) => Chip(label: Text('$item'), onDeleted: () => setD(() => current.remove(item)))).toList()),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Ajouter…'), onSubmitted: (v) { if (v.trim().isNotEmpty) setD(() { current.add(v.trim()); controller.clear(); }); })),
              IconButton(icon: const Icon(Icons.add), onPressed: () { if (controller.text.trim().isNotEmpty) setD(() { current.add(controller.text.trim()); controller.clear(); }); }),
            ]),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          FilledButton(onPressed: () async {
            try {
              await api.patch('/business/processus/${p['id']}', {field: current});
              setState(() => p[field] = current);
              if (context.mounted) Navigator.pop(c);
            } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
          }, child: const Text('Enregistrer')),
        ],
      )),
    );
  }

  // --- Activités ---
  Future<void> _addOrEditActivity({Map? record}) async {
    final name = TextEditingController(text: record?['name'] ?? '');
    final description = TextEditingController(text: record?['description'] ?? '');
    String? formError;
    bool saving = false;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
        title: Text(record == null ? 'Nouvelle activité' : 'Modifier l\'activité'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Nom')),
          TextField(controller: description, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
          if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
        ]),
        actions: [
          if (record != null) TextButton(
            onPressed: () async {
              try { await api.delete('/business/processus-activities/${record['id']}'); if (context.mounted) Navigator.pop(c); loadSub(); }
              catch (e) { setD(() => formError = '$e'); }
            },
            child: const Text('Supprimer', style: TextStyle(color: QhseColors.red)),
          ),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          FilledButton(onPressed: saving ? null : () async {
            setD(() => saving = true);
            try {
              if (record != null) await api.patch('/business/processus-activities/${record['id']}', {'name': name.text, 'description': description.text});
              else await api.post('/business/processus-activities', {'processusId': p['id'], 'name': name.text, 'description': description.text, 'order': activities.length});
              if (context.mounted) Navigator.pop(c);
              loadSub();
            } catch (e) { setD(() { saving = false; formError = '$e'; }); }
          }, child: Text(saving ? '…' : 'Enregistrer')),
        ],
      )),
    );
  }

  Future<void> _addRaci(Map activity) async {
    final roleLabel = TextEditingController();
    String raci = 'R';
    String? formError;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
        title: Text('RACI — ${activity['name']}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: roleLabel, decoration: const InputDecoration(labelText: 'Rôle ou service (ex. Achats)')),
          DropdownButtonFormField<String>(
            value: raci,
            items: const [DropdownMenuItem(value: 'R', child: Text('R — Responsible')), DropdownMenuItem(value: 'A', child: Text('A — Accountable')), DropdownMenuItem(value: 'C', child: Text('C — Consulted')), DropdownMenuItem(value: 'I', child: Text('I — Informed'))],
            onChanged: (v) => setD(() => raci = v ?? 'R'),
            decoration: const InputDecoration(labelText: 'RACI'),
          ),
          if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          FilledButton(onPressed: () async {
            try {
              await api.post('/business/processus-activities/${activity['id']}/raci', {'roleLabel': roleLabel.text, 'raci': raci});
              if (context.mounted) Navigator.pop(c);
              loadSub();
            } catch (e) { setD(() => formError = '$e'); }
          }, child: const Text('Ajouter')),
        ],
      )),
    );
  }

  Future<void> _deleteRaci(String id) async {
    try { await api.delete('/business/processus-raci/$id'); loadSub(); } catch (_) {}
  }

  // --- Exigences ---
  Future<void> _addOrEditExigence({Map? record}) async {
    final exigence = TextEditingController(text: record?['exigence'] ?? '');
    final origine = TextEditingController(text: record?['origine'] ?? '');
    String statut = record?['statutConformite'] ?? 'CONFORME';
    String? formError;
    bool saving = false;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
        title: Text(record == null ? 'Nouvelle exigence' : 'Modifier l\'exigence'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: exigence, decoration: const InputDecoration(labelText: 'Exigence'), maxLines: 2),
          TextField(controller: origine, decoration: const InputDecoration(labelText: 'Origine (ISO 9001, client...)')),
          DropdownButtonFormField<String>(
            value: statut,
            items: const [DropdownMenuItem(value: 'CONFORME', child: Text('Conforme')), DropdownMenuItem(value: 'NON_CONFORME', child: Text('Non conforme')), DropdownMenuItem(value: 'A_VERIFIER', child: Text('À vérifier'))],
            onChanged: (v) => setD(() => statut = v ?? 'CONFORME'),
            decoration: const InputDecoration(labelText: 'Statut'),
          ),
          if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
        ]),
        actions: [
          if (record != null) TextButton(
            onPressed: () async {
              try { await api.delete('/business/processus-exigences/${record['id']}'); if (context.mounted) Navigator.pop(c); loadSub(); }
              catch (e) { setD(() => formError = '$e'); }
            },
            child: const Text('Supprimer', style: TextStyle(color: QhseColors.red)),
          ),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          FilledButton(onPressed: saving ? null : () async {
            setD(() => saving = true);
            try {
              if (record != null) await api.patch('/business/processus-exigences/${record['id']}', {'exigence': exigence.text, 'origine': origine.text, 'statutConformite': statut});
              else await api.post('/business/processus-exigences', {'processusId': p['id'], 'exigence': exigence.text, 'origine': origine.text, 'statutConformite': statut});
              if (context.mounted) Navigator.pop(c);
              loadSub();
            } catch (e) { setD(() { saving = false; formError = '$e'; }); }
          }, child: Text(saving ? '…' : 'Enregistrer')),
        ],
      )),
    );
  }

  // --- Export CSV du rapport individuel ---
  Future<void> exportCsv() async {
    setState(() => exporting = true);
    try {
      final buffer = StringBuffer();
      buffer.writeln('Rapport processus — ${p['nom']}');
      buffer.writeln('');
      buffer.writeln('IDENTIFICATION');
      buffer.writeln('Code,${_csvEscape('${p['code']}')}');
      buffer.writeln('Type,${_csvEscape(kProcessTypeLabels[p['type']] ?? '${p['type']}')}');
      buffer.writeln('Criticité,${_csvEscape(p['criticite'] != null ? kCriticiteLabels[p['criticite']] ?? '' : '—')}');
      buffer.writeln('Pilote,${_csvEscape(p['pilote'] != null ? '${p['pilote']['firstName']} ${p['pilote']['lastName']}' : '—')}');
      buffer.writeln('Score de maîtrise,${computeMaturityScore(p)}/100');
      buffer.writeln('Complétude,${computeCompleteness(p)}%');
      buffer.writeln('');
      buffer.writeln('ACTIVITÉS');
      buffer.writeln('Nom,Description,Responsable');
      for (final a in activities) { buffer.writeln([a['name'], a['description'] ?? '', a['responsible'] != null ? '${a['responsible']['firstName']} ${a['responsible']['lastName']}' : ''].map((v) => _csvEscape('$v')).join(',')); }
      buffer.writeln('');
      buffer.writeln('EXIGENCES');
      buffer.writeln('Exigence,Origine,Statut');
      for (final ex in exigences) { buffer.writeln([ex['exigence'], ex['origine'] ?? '', ex['statutConformite']].map((v) => _csvEscape('$v')).join(',')); }
      final dir = await getTemporaryDirectory();
      final fileName = 'Processus_${p['code']}_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes([0xEF, 0xBB, 0xBF, ...buffer.toString().codeUnits]);
      await Share.shareXFiles([XFile(file.path)], text: 'Rapport processus — ${p['nom']}');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    setState(() => exporting = false);
  }

  @override
  Widget build(BuildContext context) {
    final score = computeMaturityScore(p);
    final lvl = maturityLevel(score);
    final alerts = processusAlerts(p);
    return Scaffold(
      appBar: AppBar(title: Text(p['nom'] ?? ''), actions: [IconButton(icon: exporting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.ios_share), onPressed: exporting ? null : exportCsv, tooltip: 'Exporter le rapport')]),
      body: RefreshIndicator(
        onRefresh: loadSub,
        child: ListView(padding: const EdgeInsets.all(16), children: [
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

          const SizedBox(height: 16),
          const Text('Alertes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          if (alerts.isEmpty) const Text('Aucune alerte', style: TextStyle(color: QhseColors.green))
          else ...alerts.map((a) => Card(child: ListTile(leading: const Icon(Icons.warning_amber_outlined, color: QhseColors.amber), title: Text(a)))),

          const SizedBox(height: 20),
          const Text('SIPOC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          ...[['suppliers', 'Fournisseurs (S)'], ['inputs', 'Entrées (I)'], ['outputs', 'Sorties (O)'], ['customers', 'Clients (C)']].map((f) => Card(child: ListTile(
                title: Text(f[1]),
                subtitle: Text(List<String>.from(p[f[0]] ?? []).join(', ').isEmpty ? 'Aucun' : List<String>.from(p[f[0]] ?? []).join(', ')),
                trailing: const Icon(Icons.edit_outlined, size: 18),
                onTap: () => _editSipocList(f[0], f[1]),
              ))),

          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Activités', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            TextButton(onPressed: () => _addOrEditActivity(), child: const Text('+ Activité')),
          ]),
          if (loadingSub) const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()))
          else if (activities.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Aucune activité enregistrée', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
          else ...activities.map((a) => Card(child: ExpansionTile(
                title: Text(a['name'] ?? ''),
                subtitle: (a['description'] ?? '').toString().isNotEmpty ? Text(a['description']) : null,
                children: [
                  ...List.from(a['racis'] ?? []).map((r) => ListTile(
                        dense: true,
                        title: Text(r['user'] != null ? '${r['user']['firstName']} ${r['user']['lastName']}' : (r['roleLabel'] ?? '—')),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(r['raci'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                          IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => _deleteRaci(r['id'])),
                        ]),
                      )),
                  ButtonBar(children: [
                    TextButton(onPressed: () => _addRaci(a), child: const Text('+ RACI')),
                    TextButton(onPressed: () => _addOrEditActivity(record: a), child: const Text('Modifier')),
                  ]),
                ],
              ))),

          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Exigences', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            TextButton(onPressed: () => _addOrEditExigence(), child: const Text('+ Exigence')),
          ]),
          if (!loadingSub && exigences.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Aucune exigence enregistrée', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12))),
          ...exigences.map((ex) => Card(child: ListTile(
                title: Text(ex['exigence'] ?? ''),
                subtitle: Text('${ex['origine'] ?? 'Origine non précisée'} · ${ex['statutConformite']}'),
                onTap: () => _addOrEditExigence(record: ex),
              ))),
          const SizedBox(height: 24),
        ]),
      ),
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
  List links = [];
  bool loading = true;
  int tabIndex = 0;
  bool linkMode = false;
  String? linkSourceId;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      items = List.from(await api.get('/business/processus'));
      links = List.from(await api.get('/business/processus-links'));
    } catch (_) {}
    setState(() => loading = false);
  }

  Future<void> createLink(String sourceId, String targetId) async {
    try { await api.post('/business/processus-links', {'sourceId': sourceId, 'targetId': targetId}); links = List.from(await api.get('/business/processus-links')); setState(() {}); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  Future<void> deleteLink(String id) async {
    try { await api.delete('/business/processus-links/$id'); links = List.from(await api.get('/business/processus-links')); setState(() {}); }
    catch (_) {}
  }

  void onTapProcessusCard(Map p, BuildContext c) {
    if (!linkMode) { Navigator.push(c, MaterialPageRoute(builder: (_) => ProcessusDetailPage(p: p))); return; }
    if (linkSourceId == null) { setState(() => linkSourceId = p['id']); return; }
    if (linkSourceId != p['id']) createLink(linkSourceId!, p['id']);
    setState(() => linkSourceId = null);
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
                // Cartographie — regroupée par type ; le glisser-déposer
                // n'a pas de sens sur un écran tactile étroit, mais créer
                // un lien en touchant la source puis la cible fonctionne
                // bien sur mobile.
                RefreshIndicator(
                  onRefresh: load,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Expanded(child: Text(linkMode ? (linkSourceId == null ? 'Touchez le processus source…' : 'Touchez le processus cible…') : 'Cartographie', style: const TextStyle(fontWeight: FontWeight.bold))),
                        TextButton(
                          onPressed: () => setState(() { linkMode = !linkMode; linkSourceId = null; }),
                          child: Text(linkMode ? 'Annuler' : '+ Lien'),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      ...kProcessTypeLabels.keys.expand((t) {
                        final group = items.where((p) => (p['type'] ?? 'OPERATIONNEL') == t).toList();
                        if (group.isEmpty) return <Widget>[];
                        return [
                          Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(kProcessTypeLabels[t]!, style: TextStyle(fontWeight: FontWeight.bold, color: QhseColors.textSecondary))),
                          ...group.map((p) => Card(
                                color: linkSourceId == p['id'] ? QhseColors.blue.withOpacity(0.15) : null,
                                child: ListTile(
                                  title: Text(p['nom'] ?? ''),
                                  subtitle: Text(p['pilote'] != null ? '${p['pilote']['firstName']} ${p['pilote']['lastName']}' : 'Sans pilote'),
                                  leading: p['criticite'] != null ? Icon(Icons.circle, size: 12, color: criticiteColor(p['criticite'])) : null,
                                  onTap: () => onTapProcessusCard(p, c),
                                ),
                              )),
                        ];
                      }),
                      if (links.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text('Liens entre processus', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        ...links.map((l) {
                          final source = items.firstWhere((p) => p['id'] == l['sourceId'], orElse: () => {'nom': '?'});
                          final target = items.firstWhere((p) => p['id'] == l['targetId'], orElse: () => {'nom': '?'});
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.arrow_forward, size: 16, color: QhseColors.blue),
                            title: Text('${source['nom']} → ${target['nom']}', style: const TextStyle(fontSize: 13)),
                            trailing: IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => deleteLink(l['id'])),
                          );
                        }),
                      ],
                    ],
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
