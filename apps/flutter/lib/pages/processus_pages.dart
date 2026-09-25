import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api.dart';
import '../theme.dart';
import 'load_error_view.dart';
import '../services/sync_queue.dart';
import '../i18n/i18n.dart';

const Map<String, String> kProcessTypeKeys = {
  'STRATEGIQUE': 'typeStrategique', 'OPERATIONNEL': 'typeOperationnel', 'SUPPORT': 'typeSupport', 'AUTRE': 'typeAutre',
};
String kProcessTypeLabel(String? v) => v == null ? '—' : t('processus.${kProcessTypeKeys[v] ?? 'typeAutre'}');
const Map<String, String> kCriticiteKeys = {
  'FAIBLE': 'critFaible', 'MOYEN': 'critMoyen', 'IMPORTANT': 'critImportant', 'CRITIQUE': 'critCritique',
};
String kCriticiteLabel(String? v) => v == null ? '—' : t('processus.${kCriticiteKeys[v] ?? 'critFaible'}');

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
  if (score >= 80) return {'label': t('processus.maturiteMaitrise'), 'emoji': '🟢'};
  if (score >= 60) return {'label': t('processus.maturiteASurveiller'), 'emoji': '🟡'};
  if (score >= 40) return {'label': t('processus.maturiteAAmeliorer'), 'emoji': '🟠'};
  return {'label': t('processus.maturiteCritique'), 'emoji': '🔴'};
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
  if (p['piloteId'] == null) alerts.add(t('processus.alerteSansPilote'));
  if ((p['kpi'] ?? '').toString().isEmpty) alerts.add(t('processus.alerteSansIndicateur'));
  if (((p['_count']?['risks'] ?? 0) as int) == 0) alerts.add(t('processus.alerteSansAnalyseRisques'));
  if (List.from(p['objectifsQhse'] ?? []).isEmpty) alerts.add(t('processus.alerteSansObjectif'));
  final hc = objectifsHorsCible(p).length; if (hc > 0) alerts.add(t('processus.alerteObjectifsHorsCible', {'count': '$hc'}));
  final fe = formationsExpirees(p).length; if (fe > 0) alerts.add(t('processus.alerteFormationsExpirees', {'count': '$fe'}));
  final dr = documentsEnRetard(p).length; if (dr > 0) alerts.add(t('processus.alerteDocumentsEnRetard', {'count': '$dr'}));
  final ar = auditsEnRetard(p).length; if (ar > 0) alerts.add(t('processus.alerteAuditsEnRetard', {'count': '$ar'}));
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
      title: Text(record == null ? t('processus.nouveauProcessusTitle') : t('processus.modifierProcessusTitle')),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nom, decoration: InputDecoration(labelText: t('processus.nomDuProcessus'))),
          DropdownButtonFormField<String>(
            value: type, isExpanded: true,
            items: kProcessTypeKeys.keys.map((k) => DropdownMenuItem(value: k, child: Text(kProcessTypeLabel(k)))).toList(),
            onChanged: (v) => setD(() => type = v ?? 'OPERATIONNEL'),
            decoration: InputDecoration(labelText: t('processus.type')),
          ),
          DropdownButtonFormField<String>(
            value: criticite, isExpanded: true,
            items: kCriticiteKeys.keys.map((k) => DropdownMenuItem(value: k, child: Text(kCriticiteLabel(k)))).toList(),
            onChanged: (v) => setD(() => criticite = v),
            decoration: InputDecoration(labelText: t('processus.criticiteOptionnel')),
          ),
          DropdownButtonFormField<String>(
            value: piloteId, isExpanded: true,
            items: users.map<DropdownMenuItem<String>>((u) => DropdownMenuItem(value: u['id'] as String, child: Text('${u['firstName']} ${u['lastName']}'))).toList(),
            onChanged: (v) => setD(() => piloteId = v),
            decoration: InputDecoration(labelText: t('processus.piloteOptionnel')),
          ),
          TextField(controller: finalite, decoration: InputDecoration(labelText: t('processus.finaliteOptionnel')), maxLines: 2),
          TextField(controller: objectifs, decoration: InputDecoration(labelText: t('processus.objectifs'))),
          TextField(controller: kpi, decoration: InputDecoration(labelText: t('processus.kpi'))),
          if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
        ]),
      ),
      actions: [
        if (record != null) TextButton(
          onPressed: () async {
            try { await api.delete('/business/processus/${record['id']}'); if (context.mounted) Navigator.pop(c); onSaved(); }
            catch (e) { setD(() => formError = '$e'); }
          },
          child: Text(t('processus.supprimer'), style: const TextStyle(color: QhseColors.red)),
        ),
        TextButton(onPressed: () => Navigator.pop(c), child: Text(t('processus.annuler'))),
        FilledButton(
          onPressed: saving ? null : () async {
            setD(() => saving = true);
            final payload = {'nom': nom.text, 'type': type, 'criticite': criticite, 'piloteId': piloteId, 'finalite': finalite.text, 'objectifs': objectifs.text, 'kpi': kpi.text};
            final createPayload = {'code': 'PROC-${DateTime.now().millisecondsSinceEpoch}', ...payload};
            try {
              if (record != null) await api.patch('/business/processus/${record['id']}', payload);
              else await api.post('/business/processus', createPayload);
              if (context.mounted) Navigator.pop(c);
              onSaved();
            } on ApiException catch (e) {
              if (e.networkError && record == null) {
                await SyncQueue.enqueue('processus', 'CREATE', createPayload);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('processus.processusHorsLigne')), duration: const Duration(seconds: 4)));
                  Navigator.pop(c);
                }
                onSaved();
              } else {
                setD(() { saving = false; formError = '$e'; });
              }
            } catch (e) { setD(() { saving = false; formError = '$e'; }); }
          },
          child: Text(saving ? t('processus.enregistrementEnCours') : t('processus.enregistrer')),
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
              Expanded(child: TextField(controller: controller, decoration: InputDecoration(hintText: t('processus.ajouterPlaceholder')), onSubmitted: (v) { if (v.trim().isNotEmpty) setD(() { current.add(v.trim()); controller.clear(); }); })),
              IconButton(icon: const Icon(Icons.add), onPressed: () { if (controller.text.trim().isNotEmpty) setD(() { current.add(controller.text.trim()); controller.clear(); }); }),
            ]),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(t('processus.annuler'))),
          FilledButton(onPressed: () async {
            try {
              await api.patch('/business/processus/${p['id']}', {field: current});
              setState(() => p[field] = current);
              if (context.mounted) Navigator.pop(c);
            } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
          }, child: Text(t('processus.enregistrer'))),
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
        title: Text(record == null ? t('processus.nouvelleActiviteTitle') : t('processus.modifierActiviteTitle')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: InputDecoration(labelText: t('processus.nom'))),
          TextField(controller: description, decoration: InputDecoration(labelText: t('processus.description')), maxLines: 2),
          if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
        ]),
        actions: [
          if (record != null) TextButton(
            onPressed: () async {
              try { await api.delete('/business/processus-activities/${record['id']}'); if (context.mounted) Navigator.pop(c); loadSub(); }
              catch (e) { setD(() => formError = '$e'); }
            },
            child: Text(t('processus.supprimer'), style: const TextStyle(color: QhseColors.red)),
          ),
          TextButton(onPressed: () => Navigator.pop(c), child: Text(t('processus.annuler'))),
          FilledButton(onPressed: saving ? null : () async {
            setD(() => saving = true);
            try {
              if (record != null) await api.patch('/business/processus-activities/${record['id']}', {'name': name.text, 'description': description.text});
              else await api.post('/business/processus-activities', {'processusId': p['id'], 'name': name.text, 'description': description.text, 'order': activities.length});
              if (context.mounted) Navigator.pop(c);
              loadSub();
            } catch (e) { setD(() { saving = false; formError = '$e'; }); }
          }, child: Text(saving ? t('processus.enCours') : t('processus.enregistrer'))),
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
        title: Text(t('processus.raciPrefix', {'name': '${activity['name']}'})),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: roleLabel, decoration: InputDecoration(labelText: t('processus.roleOuServiceExemple'))),
          DropdownButtonFormField<String>(
            value: raci,
            items: [DropdownMenuItem(value: 'R', child: Text(t('processus.raciResponsible'))), DropdownMenuItem(value: 'A', child: Text(t('processus.raciAccountable'))), DropdownMenuItem(value: 'C', child: Text(t('processus.raciConsulted'))), DropdownMenuItem(value: 'I', child: Text(t('processus.raciInformed')))],
            onChanged: (v) => setD(() => raci = v ?? 'R'),
            decoration: InputDecoration(labelText: t('processus.raci')),
          ),
          if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(t('processus.annuler'))),
          FilledButton(onPressed: () async {
            try {
              await api.post('/business/processus-activities/${activity['id']}/raci', {'roleLabel': roleLabel.text, 'raci': raci});
              if (context.mounted) Navigator.pop(c);
              loadSub();
            } catch (e) { setD(() => formError = '$e'); }
          }, child: Text(t('processus.ajouter'))),
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
        title: Text(record == null ? t('processus.nouvelleExigenceTitle') : t('processus.modifierExigenceTitle')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: exigence, decoration: InputDecoration(labelText: t('processus.exigence')), maxLines: 2),
          TextField(controller: origine, decoration: InputDecoration(labelText: t('processus.origineExemple'))),
          DropdownButtonFormField<String>(
            value: statut,
            items: [DropdownMenuItem(value: 'CONFORME', child: Text(t('processus.statutConforme'))), DropdownMenuItem(value: 'NON_CONFORME', child: Text(t('processus.statutNonConforme'))), DropdownMenuItem(value: 'A_VERIFIER', child: Text(t('processus.statutAVerifier')))],
            onChanged: (v) => setD(() => statut = v ?? 'CONFORME'),
            decoration: InputDecoration(labelText: t('processus.statut')),
          ),
          if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
        ]),
        actions: [
          if (record != null) TextButton(
            onPressed: () async {
              try { await api.delete('/business/processus-exigences/${record['id']}'); if (context.mounted) Navigator.pop(c); loadSub(); }
              catch (e) { setD(() => formError = '$e'); }
            },
            child: Text(t('processus.supprimer'), style: const TextStyle(color: QhseColors.red)),
          ),
          TextButton(onPressed: () => Navigator.pop(c), child: Text(t('processus.annuler'))),
          FilledButton(onPressed: saving ? null : () async {
            setD(() => saving = true);
            try {
              if (record != null) await api.patch('/business/processus-exigences/${record['id']}', {'exigence': exigence.text, 'origine': origine.text, 'statutConformite': statut});
              else await api.post('/business/processus-exigences', {'processusId': p['id'], 'exigence': exigence.text, 'origine': origine.text, 'statutConformite': statut});
              if (context.mounted) Navigator.pop(c);
              loadSub();
            } catch (e) { setD(() { saving = false; formError = '$e'; }); }
          }, child: Text(saving ? t('processus.enCours') : t('processus.enregistrer'))),
        ],
      )),
    );
  }

  // --- Export CSV du rapport individuel ---
  Future<void> exportCsv() async {
    setState(() => exporting = true);
    try {
      final buffer = StringBuffer();
      buffer.writeln(t('processus.csvRapportTitre', {'nom': '${p['nom']}'}));
      buffer.writeln('');
      buffer.writeln(t('processus.csvIdentification'));
      buffer.writeln('${t('processus.csvCode')},${_csvEscape('${p['code']}')}');
      buffer.writeln('${t('processus.csvType')},${_csvEscape(kProcessTypeLabel(p['type']))}');
      buffer.writeln('${t('processus.csvCriticite')},${_csvEscape(p['criticite'] != null ? kCriticiteLabel(p['criticite']) : '—')}');
      buffer.writeln('${t('processus.csvPilote')},${_csvEscape(p['pilote'] != null ? '${p['pilote']['firstName']} ${p['pilote']['lastName']}' : '—')}');
      buffer.writeln('${t('processus.csvScoreMaitrise')},${computeMaturityScore(p)}/100');
      buffer.writeln('${t('processus.csvCompletude')},${computeCompleteness(p)}%');
      buffer.writeln('');
      buffer.writeln(t('processus.csvActivites'));
      buffer.writeln(t('processus.csvActivitesColonnes'));
      for (final a in activities) { buffer.writeln([a['name'], a['description'] ?? '', a['responsible'] != null ? '${a['responsible']['firstName']} ${a['responsible']['lastName']}' : ''].map((v) => _csvEscape('$v')).join(',')); }
      buffer.writeln('');
      buffer.writeln(t('processus.csvExigences'));
      buffer.writeln(t('processus.csvExigencesColonnes'));
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
      appBar: AppBar(title: Text(p['nom'] ?? ''), actions: [IconButton(icon: exporting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.ios_share), onPressed: exporting ? null : exportCsv, tooltip: t('processus.exporterRapport'))]),
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
          Card(child: ListTile(title: Text(t('processus.type')), trailing: Text(kProcessTypeLabel(p['type'])))),
          Card(child: ListTile(title: Text(t('processus.csvCriticite')), trailing: Text(p['criticite'] != null ? kCriticiteLabel(p['criticite']) : '—', style: TextStyle(color: criticiteColor(p['criticite']))))),
          Card(child: ListTile(title: Text(t('processus.pilote')), trailing: Text(p['pilote'] != null ? '${p['pilote']['firstName']} ${p['pilote']['lastName']}' : t('processus.alerteSansPilote')))),
          if ((p['finalite'] ?? '').toString().isNotEmpty) Card(child: ListTile(title: Text(t('processus.finalite')), subtitle: Text(p['finalite']))),
          Card(child: ListTile(title: Text(t('processus.ncOuvertes')), trailing: Text('${p['_count']?['nonConformities'] ?? 0}'))),
          Card(child: ListTile(title: Text(t('processus.actionsOuvertes')), trailing: Text('${p['_count']?['actions'] ?? 0}'))),

          const SizedBox(height: 16),
          Text(t('processus.alertesTitle'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          if (alerts.isEmpty) Text(t('processus.aucuneAlerte'), style: const TextStyle(color: QhseColors.green))
          else ...alerts.map((a) => Card(child: ListTile(leading: const Icon(Icons.warning_amber_outlined, color: QhseColors.amber), title: Text(a)))),

          const SizedBox(height: 20),
          Text(t('processus.sipocTitle'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          ...[['suppliers', t('processus.sipocFournisseurs')], ['inputs', t('processus.sipocEntrees')], ['outputs', t('processus.sipocSorties')], ['customers', t('processus.sipocClients')]].map((f) => Card(child: ListTile(
                title: Text(f[1]),
                subtitle: Text(List<String>.from(p[f[0]] ?? []).join(', ').isEmpty ? t('processus.aucun') : List<String>.from(p[f[0]] ?? []).join(', ')),
                trailing: const Icon(Icons.edit_outlined, size: 18),
                onTap: () => _editSipocList(f[0], f[1]),
              ))),

          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(t('processus.activitesTitle'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            TextButton(onPressed: () => _addOrEditActivity(), child: Text(t('processus.ajouterActivite'))),
          ]),
          if (loadingSub) const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()))
          else if (activities.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(t('processus.aucuneActivite'), style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
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
                    TextButton(onPressed: () => _addRaci(a), child: Text(t('processus.ajouterRaci'))),
                    TextButton(onPressed: () => _addOrEditActivity(record: a), child: Text(t('processus.modifier'))),
                  ]),
                ],
              ))),

          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(t('processus.exigencesTitle'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            TextButton(onPressed: () => _addOrEditExigence(), child: Text(t('processus.ajouterExigence'))),
          ]),
          if (!loadingSub && exigences.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(t('processus.aucuneExigence'), style: TextStyle(color: QhseColors.textSecondary, fontSize: 12))),
          ...exigences.map((ex) => Card(child: ListTile(
                title: Text(ex['exigence'] ?? ''),
                subtitle: Text('${ex['origine'] ?? t('processus.origineNonPrecisee')} · ${ex['statutConformite']}'),
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
  Object? error;
  int tabIndex = 0;
  bool linkMode = false;
  String? linkSourceId;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      items = List.from(await api.get('/business/processus'));
      links = List.from(await api.get('/business/processus-links'));
    } catch (e) { error = e; }
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
      KpiStat(t('processus.kpiProcessusCartographies'), '${items.length}', color: QhseColors.blue, icon: Icons.account_tree_outlined),
      KpiStat(t('processus.kpiStrategiques'), '${items.where((p) => p['type'] == 'STRATEGIQUE').length}', color: QhseColors.blue, icon: Icons.flag_outlined),
      KpiStat(t('processus.kpiOperationnels'), '${items.where((p) => p['type'] == 'OPERATIONNEL').length}', color: QhseColors.green, icon: Icons.settings_outlined),
      KpiStat(t('processus.kpiSupports'), '${items.where((p) => p['type'] == 'SUPPORT').length}', color: QhseColors.amber, icon: Icons.build_outlined),
      KpiStat(t('processus.kpiCritiques'), '$critiques', color: critiques > 0 ? QhseColors.red : QhseColors.green, icon: Icons.warning_amber_outlined),
      KpiStat(t('processus.kpiSansPilote'), '$sansPilote', color: sansPilote > 0 ? QhseColors.red : QhseColors.green, icon: Icons.person_off_outlined),
      KpiStat(t('processus.kpiAvecNcOuvertes'), '$avecNc', color: avecNc > 0 ? QhseColors.red : QhseColors.green, icon: Icons.error_outline),
    ];
  }

  @override
  Widget build(BuildContext c) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('processus.pageTitle')),
          bottom: TabBar(onTap: (i) => setState(() => tabIndex = i), tabs: [Tab(text: t('processus.tabTableauDeBord')), Tab(text: t('processus.tabCartographie')), Tab(text: t('processus.tabRegistre'))]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => showProcessusDialog(context, api, onSaved: load),
          icon: const Icon(Icons.add), label: Text(t('processus.fabProcessus')),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? LoadErrorView(error: error, onRetry: load)
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
                        Text(t('processus.prioritesQhseTitle'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 6),
                        ...(() {
                          final withAlerts = items.where((p) => processusAlerts(p).isNotEmpty).toList()
                            ..sort((a, b) => processusAlerts(b).length.compareTo(processusAlerts(a).length));
                          if (withAlerts.isEmpty) return [Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(t('processus.aucuneAlertePourLeMoment'), style: const TextStyle(color: QhseColors.green)))];
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
                        Expanded(child: Text(linkMode ? (linkSourceId == null ? t('processus.touchezSource') : t('processus.touchezCible')) : t('processus.cartographieTitle'), style: const TextStyle(fontWeight: FontWeight.bold))),
                        TextButton(
                          onPressed: () => setState(() { linkMode = !linkMode; linkSourceId = null; }),
                          child: Text(linkMode ? t('processus.annuler') : t('processus.ajouterLien')),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      ...kProcessTypeKeys.keys.expand((procType) {
                        final group = items.where((p) => (p['type'] ?? 'OPERATIONNEL') == procType).toList();
                        if (group.isEmpty) return <Widget>[];
                        return [
                          Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(kProcessTypeLabel(procType), style: TextStyle(fontWeight: FontWeight.bold, color: QhseColors.textSecondary))),
                          ...group.map((p) => Card(
                                color: linkSourceId == p['id'] ? QhseColors.blue.withOpacity(0.15) : null,
                                child: ListTile(
                                  title: Text(p['nom'] ?? ''),
                                  subtitle: Text(p['pilote'] != null ? '${p['pilote']['firstName']} ${p['pilote']['lastName']}' : t('processus.alerteSansPilote')),
                                  leading: p['criticite'] != null ? Icon(Icons.circle, size: 12, color: criticiteColor(p['criticite'])) : null,
                                  onTap: () => onTapProcessusCard(p, c),
                                ),
                              )),
                        ];
                      }),
                      if (links.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(t('processus.liensEntreProcessus'), style: const TextStyle(fontWeight: FontWeight.bold)),
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
                        ? [Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(t('processus.aucunProcessusEnregistre'))))]
                        : items.map((p) {
                            final score = computeMaturityScore(p);
                            final lvl = maturityLevel(score);
                            return Card(child: ListTile(
                              title: Text(p['nom'] ?? ''),
                              subtitle: Text('${kProcessTypeLabel(p['type'])} • ${p['pilote'] != null ? '${p['pilote']['firstName']} ${p['pilote']['lastName']}' : t('processus.alerteSansPilote')}'),
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
