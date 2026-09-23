import 'package:flutter/material.dart';
import '../services/api.dart';
import '../theme.dart';
import '../services/sync_queue.dart';
import 'safety_talk_page.dart';

/// Formulaire de création / édition manuelle d'une fiche complète de quart
/// d'heure sécurité. Si [safetyTalk] est fourni, le formulaire est en mode
/// édition (PATCH), sinon en mode création (POST). La bibliothèque de
/// thèmes (GET /safety-talks/library) est accessible depuis ce formulaire
/// pour préremplir les champs de contenu.
class SafetyTalkFormPage extends StatefulWidget {
  final Map? safetyTalk;
  const SafetyTalkFormPage({super.key, this.safetyTalk});
  @override
  State<SafetyTalkFormPage> createState() => _SafetyTalkFormPageState();
}

class _SafetyTalkFormPageState extends State<SafetyTalkFormPage> {
  final api = Api();
  bool get editing => widget.safetyTalk != null;

  final title = TextEditingController();
  final summary = TextEditingController();
  final theme = TextEditingController();
  final objectif = TextEditingController();
  final contexte = TextEditingController();
  final risquesConcernes = TextEditingController();
  final personnesExposees = TextEditingController();
  final messagePrincipal = TextEditingController();
  final pointsEssentiels = TextEditingController();
  final bonnesPratiques = TextEditingController();
  final mauvaisesPratiques = TextEditingController();
  final questions = TextEditingController();
  final exemplesTerrain = TextEditingController();
  final mesuresPrevention = TextEditingController();
  final conduiteATenir = TextEditingController();
  final conclusion = TextEditingController();
  final engagementAttendu = TextEditingController();
  final quizQuestions = TextEditingController();
  final siteId = TextEditingController();
  final service = TextEditingController();
  final zone = TextEditingController();
  final equipe = TextEditingController();
  final frequence = TextEditingController();
  final duree = TextEditingController();

  String priorite = 'MOYENNE';
  String? workUnitId, responsableAnimationId;
  DateTime? weekStart, scheduledAt;
  List workUnits = [], users = [];
  bool loadingLists = true, busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    final s = widget.safetyTalk;
    if (s != null) {
      title.text = '${s['title'] ?? ''}';
      summary.text = '${s['summary'] ?? ''}';
      theme.text = s['theme'] ?? '';
      objectif.text = s['objectif'] ?? '';
      contexte.text = s['contexte'] ?? '';
      risquesConcernes.text = s['risquesConcernes'] ?? '';
      personnesExposees.text = s['personnesExposees'] ?? '';
      messagePrincipal.text = s['messagePrincipal'] ?? '';
      pointsEssentiels.text = s['pointsEssentiels'] ?? '';
      bonnesPratiques.text = s['bonnesPratiques'] ?? '';
      mauvaisesPratiques.text = s['mauvaisesPratiques'] ?? '';
      questions.text = s['questions'] ?? '';
      exemplesTerrain.text = s['exemplesTerrain'] ?? '';
      mesuresPrevention.text = s['mesuresPrevention'] ?? '';
      conduiteATenir.text = s['conduiteATenir'] ?? '';
      conclusion.text = s['conclusion'] ?? '';
      engagementAttendu.text = s['engagementAttendu'] ?? '';
      final q = s['quiz'];
      if (q is Map && q['questions'] is List) quizQuestions.text = (q['questions'] as List).join('\n');
      siteId.text = s['siteId'] ?? '';
      service.text = s['service'] ?? '';
      zone.text = s['zone'] ?? '';
      equipe.text = s['equipe'] ?? '';
      frequence.text = s['frequence'] ?? '';
      duree.text = s['duree'] != null ? '${s['duree']}' : '';
      priorite = s['priorite'] ?? 'MOYENNE';
      workUnitId = s['workUnitId'];
      responsableAnimationId = s['responsableAnimationId'];
      if (s['weekStart'] != null) weekStart = DateTime.tryParse('${s['weekStart']}');
      if (s['scheduledAt'] != null) scheduledAt = DateTime.tryParse('${s['scheduledAt']}');
    }
    loadLists();
  }

  Future<void> loadLists() async {
    try {
      workUnits = List.from(await api.get('/business/work-units'));
      users = List.from(await api.get('/users'));
    } catch (_) {}
    setState(() => loadingLists = false);
  }

  Future<void> pickWeekStart() async {
    final d = await showDatePicker(context: context, initialDate: weekStart ?? DateTime.now(), firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (d != null) setState(() => weekStart = d);
  }

  Future<void> pickScheduledAt() async {
    final d = await showDatePicker(context: context, initialDate: scheduledAt ?? DateTime.now(), firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime.now().add(const Duration(days: 730)));
    if (d == null) return;
    if (!mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(scheduledAt ?? DateTime.now()));
    setState(() => scheduledAt = DateTime(d.year, d.month, d.day, t?.hour ?? 8, t?.minute ?? 0));
  }

  Future<void> pickFromLibrary() async {
    List categories = [];
    try { categories = List.from(await api.get('/safety-talks/library')); } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      return;
    }
    if (!mounted) return;
    final chosen = await showDialog<Map>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Bibliothèque de thèmes'),
        content: SizedBox(
          width: 460, height: 480,
          child: ListView(children: categories.map<Widget>((cat) => ExpansionTile(
                title: Text('${cat['categorie']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                children: List<Widget>.from((cat['themes'] as List).map((t) => ListTile(
                      dense: true,
                      title: Text('${t['titre']}', style: const TextStyle(fontSize: 13)),
                      onTap: () => Navigator.pop(c, Map.from(t)),
                    ))),
              )).toList()),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler'))],
      ),
    );
    if (chosen == null) return;
    setState(() {
      theme.text = chosen['titre'] ?? '';
      title.text = chosen['titre'] ?? '';
      objectif.text = chosen['objectif'] ?? '';
      pointsEssentiels.text = chosen['pointsEssentiels'] ?? '';
      bonnesPratiques.text = chosen['bonnesPratiques'] ?? '';
      mauvaisesPratiques.text = chosen['mauvaisesPratiques'] ?? '';
      questions.text = chosen['questions'] ?? '';
      if (summary.text.trim().isEmpty) summary.text = chosen['objectif'] ?? '';
    });
  }

  String? _n(TextEditingController ctl) => ctl.text.trim().isEmpty ? null : ctl.text.trim();

  Future<void> submit() async {
    if (title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le titre est obligatoire')));
      return;
    }
    setState(() { busy = true; error = null; });
    final quizList = quizQuestions.text.split('\n').map((q) => q.trim()).where((q) => q.isNotEmpty).toList();
    final payload = <String, dynamic>{
      'title': title.text.trim(),
      'summary': summary.text.trim().isEmpty ? (_n(pointsEssentiels) ?? _n(objectif) ?? title.text.trim()) : summary.text.trim(),
      'theme': _n(theme), 'objectif': _n(objectif), 'contexte': _n(contexte),
      'risquesConcernes': _n(risquesConcernes), 'personnesExposees': _n(personnesExposees),
      'messagePrincipal': _n(messagePrincipal), 'pointsEssentiels': _n(pointsEssentiels),
      'bonnesPratiques': _n(bonnesPratiques), 'mauvaisesPratiques': _n(mauvaisesPratiques), 'questions': _n(questions),
      'exemplesTerrain': _n(exemplesTerrain), 'mesuresPrevention': _n(mesuresPrevention), 'conduiteATenir': _n(conduiteATenir),
      'conclusion': _n(conclusion), 'engagementAttendu': _n(engagementAttendu),
      if (quizList.isNotEmpty) 'quiz': {'questions': quizList},
      'priorite': priorite,
      'siteId': _n(siteId), 'service': _n(service), 'zone': _n(zone), 'equipe': _n(equipe),
      'workUnitId': workUnitId, 'responsableAnimationId': responsableAnimationId,
      if (weekStart != null) 'weekStart': weekStart!.toIso8601String(),
      if (scheduledAt != null) 'scheduledAt': scheduledAt!.toIso8601String(),
      'duree': duree.text.trim().isEmpty ? null : int.tryParse(duree.text.trim()),
      'frequence': _n(frequence),
    };
    try {
      final result = editing
          ? await api.patch('/safety-talks/${widget.safetyTalk!['id']}', payload)
          : await api.post('/safety-talks', payload);
      if (mounted) Navigator.pop(context, result);
    } on ApiException catch (e) {
      if (e.networkError && !editing) {
        await SyncQueue.enqueue('safetyTalk', 'CREATE', payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pas de réseau : causerie enregistrée hors-ligne, elle sera synchronisée automatiquement.'), duration: Duration(seconds: 4)));
          Navigator.pop(context);
        }
        return;
      }
      setState(() { busy = false; error = '$e'; });
      return;
    } catch (e) {
      setState(() { busy = false; error = '$e'; });
      return;
    }
  }

  Widget _field(TextEditingController ctl, String label, {int maxLines = 1}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(controller: ctl, maxLines: maxLines, decoration: InputDecoration(labelText: label)),
  );

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(
      title: Text(editing ? 'Modifier la fiche' : 'Nouvelle fiche'),
      actions: [IconButton(icon: const Icon(Icons.auto_stories), tooltip: 'Bibliothèque de thèmes', onPressed: pickFromLibrary)],
    ),
    body: loadingLists
        ? const Center(child: CircularProgressIndicator())
        : ListView(padding: const EdgeInsets.all(16), children: [
            OutlinedButton.icon(onPressed: pickFromLibrary, icon: const Icon(Icons.auto_stories), label: const Text('Choisir un thème dans la bibliothèque')),
            const SizedBox(height: 16),
            const Text('Identification', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            _field(title, 'Titre *'),
            _field(theme, 'Thème'),
            _field(summary, 'Résumé', maxLines: 3),
            OutlinedButton.icon(onPressed: pickWeekStart, icon: const Icon(Icons.calendar_today, size: 16), label: Text(weekStart != null ? 'Semaine du ${weekStart!.toIso8601String().substring(0, 10)}' : 'Semaine (défaut : semaine en cours)')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: priorite, isExpanded: true, decoration: const InputDecoration(labelText: 'Priorité'),
              items: prioriteLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
              onChanged: (v) => setState(() => priorite = v ?? 'MOYENNE'),
            ),
            const SizedBox(height: 20),
            const Text('Contenu de la séance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            _field(objectif, 'Objectif', maxLines: 2),
            _field(contexte, 'Contexte', maxLines: 3),
            _field(risquesConcernes, 'Risques concernés', maxLines: 2),
            _field(personnesExposees, 'Personnes exposées', maxLines: 2),
            _field(messagePrincipal, 'Message principal', maxLines: 2),
            _field(pointsEssentiels, 'Points essentiels', maxLines: 4),
            _field(bonnesPratiques, 'Bonnes pratiques', maxLines: 4),
            _field(mauvaisesPratiques, 'Mauvaises pratiques', maxLines: 4),
            _field(questions, 'Questions à poser', maxLines: 3),
            _field(exemplesTerrain, 'Exemples terrain', maxLines: 3),
            _field(mesuresPrevention, 'Mesures de prévention', maxLines: 3),
            _field(conduiteATenir, 'Conduite à tenir', maxLines: 3),
            _field(conclusion, 'Conclusion', maxLines: 2),
            _field(engagementAttendu, 'Engagement attendu', maxLines: 2),
            _field(quizQuestions, 'Quiz — une question par ligne', maxLines: 4),
            const SizedBox(height: 20),
            const Text('Organisation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _field(siteId, 'Site')),
              const SizedBox(width: 8),
              Expanded(child: _field(service, 'Service')),
            ]),
            Row(children: [
              Expanded(child: _field(zone, 'Zone')),
              const SizedBox(width: 8),
              Expanded(child: _field(equipe, 'Équipe')),
            ]),
            DropdownButtonFormField<String>(
              value: workUnitId, isExpanded: true, decoration: const InputDecoration(labelText: 'Unité de travail'),
              items: [const DropdownMenuItem<String>(value: null, child: Text('—')), ...workUnits.map<DropdownMenuItem<String>>((w) => DropdownMenuItem<String>(value: w['id'] as String, child: Text(w['name'] ?? '')))],
              onChanged: (v) => setState(() => workUnitId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: responsableAnimationId, isExpanded: true, decoration: const InputDecoration(labelText: 'Responsable animation'),
              items: [const DropdownMenuItem<String>(value: null, child: Text('—')), ...users.map<DropdownMenuItem<String>>((u) => DropdownMenuItem<String>(value: u['id'] as String, child: Text('${u['firstName']} ${u['lastName']}')))],
              onChanged: (v) => setState(() => responsableAnimationId = v),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: pickScheduledAt, icon: const Icon(Icons.event), label: Text(scheduledAt != null ? 'Planifiée : ${scheduledAt!.toIso8601String().substring(0, 16).replaceFirst('T', ' ')}' : 'Date/heure planifiée')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _field(duree, 'Durée (minutes)')),
              const SizedBox(width: 8),
              Expanded(child: _field(frequence, 'Fréquence (ex : Hebdomadaire)')),
            ]),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(error!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : submit, child: Text(busy ? 'Envoi...' : 'Enregistrer'))),
          ]),
  );
}
