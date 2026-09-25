import 'package:flutter/material.dart';
import '../services/api.dart';
import '../theme.dart';
import '../i18n/i18n.dart';
import 'capa_link_widget.dart';
import 'safety_talk_form_page.dart';
import 'safety_talk_page.dart';

Map<String, String> get _feedbackTypeLabels => {
  'DANGER': t('safetyTalkDetail.typeDanger'),
  'SITUATION_DANGEREUSE': t('safetyTalkDetail.typeSituationDangereuse'),
  'COMPORTEMENT_RISQUE': t('safetyTalkDetail.typeComportementRisque'),
  'EQUIPEMENT_DEFECTUEUX': t('safetyTalkDetail.typeEquipementDefectueux'),
  'EPI_MANQUANT': t('safetyTalkDetail.typeEpiManquant'),
  'EPC_DEFAILLANT': t('safetyTalkDetail.typeEpcDefaillant'),
  'ORGANISATION': t('safetyTalkDetail.typeOrganisation'),
  'ANOMALIE': t('safetyTalkDetail.typeAnomalie'),
  'PRESQUE_ACCIDENT': t('safetyTalkDetail.typePresqueAccident'),
  'NC': t('safetyTalkDetail.typeNc'),
  'AMELIORATION': t('safetyTalkDetail.typeAmelioration'),
};

Map<String, String> get _transformTargetLabels => {
  'ACTION': t('safetyTalkDetail.cibleAction'),
  'NON_CONFORMITY': t('safetyTalkDetail.cibleNonConformite'),
  'SAFETY_EVENT': t('safetyTalkDetail.cibleSituationDangereuse'),
};

/// Page détail d'une fiche de quart d'heure sécurité : bandeau de statut,
/// fiche complète, workflow (approve/deliver/schedule/postpone/cancel),
/// émargement, remontées terrain (avec transformation — point le plus
/// important du cahier des charges), quiz et actions CAPA associées.
class SafetyTalkDetailPage extends StatefulWidget {
  final String safetyTalkId;
  const SafetyTalkDetailPage({super.key, required this.safetyTalkId});
  @override
  State<SafetyTalkDetailPage> createState() => _SafetyTalkDetailPageState();
}

class _SafetyTalkDetailPageState extends State<SafetyTalkDetailPage> {
  final api = Api();
  Map? talk;
  List participants = [], feedbacks = [], employees = [], users = [], workUnits = [];
  Map quizStats = {};
  bool loading = true, busy = false;
  String? error;
  int capaRefreshKey = 0;

  @override
  void initState() { super.initState(); loadAll(); }

  // L'API n'expose pas de GET /safety-talks/:id dédié : la fiche est
  // retrouvée dans la liste générale (contrat backend vérifié, non modifiable).
  Future<void> loadAll() async {
    setState(() => loading = true);
    try {
      final list = List.from(await api.get('/safety-talks'));
      final found = list.firstWhere((x) => x['id'] == widget.safetyTalkId, orElse: () => null);
      talk = found != null ? Map.from(found) : {};
    } catch (e) { error = '$e'; }
    await Future.wait([loadParticipants(), loadFeedbacks(), loadQuizStats(), loadLists()]);
    setState(() => loading = false);
  }

  Future<void> loadParticipants() async {
    try { participants = List.from(await api.get('/safety-talks/${widget.safetyTalkId}/participants')); } catch (_) {}
  }

  Future<void> loadFeedbacks() async {
    try { feedbacks = List.from(await api.get('/safety-talks/${widget.safetyTalkId}/feedbacks')); } catch (_) {}
  }

  Future<void> loadQuizStats() async {
    try { quizStats = Map.from(await api.get('/safety-talks/${widget.safetyTalkId}/quiz-stats')); } catch (_) {}
  }

  Future<void> loadLists() async {
    try { employees = List.from(await api.get('/epi/employees')); } catch (_) {}
    try { users = List.from(await api.get('/users')); } catch (_) {}
    try { workUnits = List.from(await api.get('/business/work-units')); } catch (_) {}
  }

  String workUnitName(String? id) {
    if (id == null) return '—';
    final w = workUnits.firstWhere((x) => x['id'] == id, orElse: () => null);
    return w == null ? id : '${w['name']}';
  }

  String userName(String? id) {
    if (id == null) return '—';
    final u = users.firstWhere((x) => x['id'] == id, orElse: () => null);
    return u == null ? id : '${u['firstName']} ${u['lastName']}';
  }

  String employeeName(String? id) {
    if (id == null) return '—';
    final e = employees.firstWhere((x) => x['id'] == id, orElse: () => null);
    return e == null ? id : '${e['firstName']} ${e['lastName']}';
  }

  Future<void> doAction(String path, Map body) async {
    setState(() => busy = true);
    try { await api.post(path, body); await loadAll(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
    setState(() => busy = false);
  }

  Future<void> approve() => doAction('/safety-talks/${widget.safetyTalkId}/approve', {});
  Future<void> deliver() => doAction('/safety-talks/${widget.safetyTalkId}/deliver', {});
  Future<void> cancel() => doAction('/safety-talks/${widget.safetyTalkId}/cancel', {});

  Future<DateTime?> pickDateTime({DateTime? initial}) async {
    final d = await showDatePicker(context: context, initialDate: initial ?? DateTime.now(), firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime.now().add(const Duration(days: 730)));
    if (d == null) return null;
    if (!mounted) return null;
    final tod = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial ?? DateTime.now()));
    return DateTime(d.year, d.month, d.day, tod?.hour ?? 8, tod?.minute ?? 0);
  }

  Future<void> schedule() async {
    final current = talk?['scheduledAt'] != null ? DateTime.tryParse('${talk!['scheduledAt']}') : null;
    final dt = await pickDateTime(initial: current);
    if (dt == null) return;
    await doAction('/safety-talks/${widget.safetyTalkId}/schedule', {'scheduledAt': dt.toIso8601String()});
  }

  Future<void> postpone() async {
    final current = talk?['scheduledAt'] != null ? DateTime.tryParse('${talk!['scheduledAt']}') : null;
    final dt = await pickDateTime(initial: current);
    if (dt == null) return;
    await doAction('/safety-talks/${widget.safetyTalkId}/postpone', {'scheduledAt': dt.toIso8601String()});
  }

  Future<void> editForm() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => SafetyTalkFormPage(safetyTalk: talk)));
    if (result != null) loadAll();
  }

  // --- Émargement ---
  Future<void> addParticipant() async {
    String? employeeId;
    bool present = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
        title: Text(t('safetyTalkDetail.dialogAjouterParticipant')),
        content: SizedBox(width: 380, child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            isExpanded: true, decoration: InputDecoration(labelText: t('safetyTalkDetail.champEmploye')), value: employeeId,
            items: employees.map<DropdownMenuItem<String>>((e) => DropdownMenuItem(value: e['id'] as String, child: Text('${e['firstName']} ${e['lastName']}'))).toList(),
            onChanged: (v) => setD(() => employeeId = v),
          ),
          CheckboxListTile(value: present, title: Text(t('safetyTalkDetail.present')), onChanged: (v) => setD(() => present = v ?? true)),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t('safetyTalkDetail.annuler'))),
          FilledButton(onPressed: employeeId == null ? null : () => Navigator.pop(c, true), child: Text(t('safetyTalkDetail.ajouter'))),
        ],
      )),
    );
    if (ok != true || employeeId == null) return;
    try {
      await api.post('/safety-talks/${widget.safetyTalkId}/participants', {'employeeId': employeeId, 'present': present});
      await loadParticipants();
      if (mounted) setState(() {});
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  Future<void> bulkAddParticipants() async {
    final selected = <String>{};
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
        title: Text(t('safetyTalkDetail.dialogAjouterPlusieurs')),
        content: SizedBox(width: 420, height: 360, child: employees.isEmpty
            ? Center(child: Text(t('safetyTalkDetail.aucunEmploye')))
            : ListView(children: employees.map<Widget>((e) => CheckboxListTile(
                dense: true,
                value: selected.contains(e['id']),
                title: Text('${e['firstName']} ${e['lastName']}', style: const TextStyle(fontSize: 13)),
                onChanged: (v) => setD(() { if (v == true) selected.add(e['id']); else selected.remove(e['id']); }),
              )).toList())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t('safetyTalkDetail.annuler'))),
          FilledButton(onPressed: selected.isEmpty ? null : () => Navigator.pop(c, true), child: Text(t('safetyTalkDetail.ajouter'))),
        ],
      )),
    );
    if (ok != true || selected.isEmpty) return;
    try {
      await api.post('/safety-talks/${widget.safetyTalkId}/participants/bulk', {'employeeIds': selected.toList()});
      await loadParticipants();
      if (mounted) setState(() {});
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  Future<void> removeParticipant(String participantId) async {
    try {
      await api.delete('/safety-talks/participants/$participantId');
      await loadParticipants();
      if (mounted) setState(() {});
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  // --- Remontées terrain ---
  Future<void> addFeedback() async {
    final description = TextEditingController();
    final localisation = TextEditingController();
    final commentaire = TextEditingController();
    final mesureImmediate = TextEditingController();
    String type = 'SITUATION_DANGEREUSE';
    String? criticite;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
        title: Text(t('safetyTalkDetail.dialogNouvelleRemontee')),
        content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: description, maxLines: 3, decoration: InputDecoration(labelText: t('safetyTalkDetail.champDescriptionObligatoire'))),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            isExpanded: true, decoration: InputDecoration(labelText: t('safetyTalkDetail.champType')), value: type,
            items: _feedbackTypeLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (v) => setD(() => type = v ?? type),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            isExpanded: true, decoration: InputDecoration(labelText: t('safetyTalkDetail.champCriticite')), value: criticite,
            items: [const DropdownMenuItem<String>(value: null, child: Text('—')), ...prioriteLabels.entries.map((e) => DropdownMenuItem<String>(value: e.key, child: Text(e.value)))],
            onChanged: (v) => setD(() => criticite = v),
          ),
          const SizedBox(height: 10),
          TextField(controller: localisation, decoration: InputDecoration(labelText: t('safetyTalkDetail.champLocalisation'))),
          const SizedBox(height: 10),
          TextField(controller: mesureImmediate, maxLines: 2, decoration: InputDecoration(labelText: t('safetyTalkDetail.champMesureImmediate'))),
          const SizedBox(height: 10),
          TextField(controller: commentaire, maxLines: 2, decoration: InputDecoration(labelText: t('safetyTalkDetail.champCommentaire'))),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t('safetyTalkDetail.annuler'))),
          FilledButton(onPressed: description.text.trim().isEmpty ? null : () => Navigator.pop(c, true), child: Text(t('safetyTalkDetail.enregistrer'))),
        ],
      )),
    );
    if (ok != true) return;
    if (description.text.trim().isEmpty) return;
    final payload = {
      'description': description.text.trim(), 'type': type,
      if (criticite != null) 'criticite': criticite,
      if (localisation.text.trim().isNotEmpty) 'localisation': localisation.text.trim(),
      if (mesureImmediate.text.trim().isNotEmpty) 'mesureImmediate': mesureImmediate.text.trim(),
      if (commentaire.text.trim().isNotEmpty) 'commentaire': commentaire.text.trim(),
    };
    try {
      await api.post('/safety-talks/${widget.safetyTalkId}/feedbacks', payload);
      await loadFeedbacks();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  // Transformation d'une remontée terrain — le point le plus important du
  // cahier des charges : 3 choix, toujours sur décision humaine explicite.
  Future<void> transformFeedback(Map feedback) async {
    final target = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t('safetyTalkDetail.dialogTransformerRemontee')),
        content: Column(mainAxisSize: MainAxisSize.min, children: _transformTargetLabels.entries.map((e) => ListTile(
              leading: Icon(e.key == 'ACTION' ? Icons.playlist_add_check : e.key == 'NON_CONFORMITY' ? Icons.report_gmailerrorred : Icons.warning_amber_outlined),
              title: Text(e.value),
              onTap: () => Navigator.pop(c, e.key),
            )).toList()),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(t('safetyTalkDetail.annuler')))],
      ),
    );
    if (target == null) return;
    try {
      await api.post('/safety-talks/feedbacks/${feedback['id']}/transform', {'targetModule': target});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('safetyTalkDetail.remonteeTransformee', {'target': _transformTargetLabels[target] ?? ''}))));
      await loadFeedbacks();
      setState(() => capaRefreshKey++); // force le rechargement des CAPA liées si une action a été créée
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  // --- Quiz ---
  Future<void> submitQuiz() async {
    String? participantId;
    final score = TextEditingController();
    final total = TextEditingController(text: '10');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
        title: Text(t('safetyTalkDetail.dialogResultatQuiz')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            isExpanded: true, decoration: InputDecoration(labelText: t('safetyTalkDetail.champParticipantOptionnel')), value: participantId,
            items: [DropdownMenuItem<String>(value: null, child: Text(t('safetyTalkDetail.anonyme'))), ...participants.map<DropdownMenuItem<String>>((p) => DropdownMenuItem<String>(value: p['id'] as String, child: Text(employeeName(p['employeeId']))))],
            onChanged: (v) => setD(() => participantId = v),
          ),
          TextField(controller: score, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('safetyTalkDetail.champScoreObtenu'))),
          TextField(controller: total, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('safetyTalkDetail.champTotalPoints'))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t('safetyTalkDetail.annuler'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(t('safetyTalkDetail.enregistrer'))),
        ],
      )),
    );
    if (ok != true) return;
    final s = int.tryParse(score.text.trim()) ?? 0;
    final totalVal = int.tryParse(total.text.trim()) ?? 0;
    if (totalVal <= 0) return;
    try {
      await api.post('/safety-talks/${widget.safetyTalkId}/quiz', {if (participantId != null) 'participantId': participantId, 'score': s, 'total': totalVal});
      await loadQuizStats();
      if (mounted) setState(() {});
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  Widget _metaRow(String label, dynamic value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 150, child: Text(label, style: TextStyle(color: QhseColors.textSecondary, fontSize: 12))),
      Expanded(child: Text(value == null || '$value'.trim().isEmpty ? '—' : '$value', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
    ]),
  );

  Widget _textBlock(String label, dynamic value) {
    if (value == null || '$value'.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: QhseColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text('$value', style: const TextStyle(fontSize: 13)),
      ]),
    );
  }

  List<Widget> _workflowButtons(String? status) {
    final buttons = <Widget>[];
    // Api.canManage (RBAC, finding #1) : le backend exige ADMINISTRATEUR/
    // RESPONSABLE_QHSE sur /safety-talks/:id/approve.
    if ((status == 'DRAFT' || status == 'REPORTE') && Api.canManage) {
      buttons.add(FilledButton.icon(onPressed: busy ? null : approve, icon: const Icon(Icons.check, size: 16), label: Text(t('safetyTalkDetail.btnValider'))));
    }
    if (status == 'APPROVED') {
      buttons.add(FilledButton.icon(onPressed: busy ? null : deliver, icon: const Icon(Icons.campaign, size: 16), label: Text(t('safetyTalkDetail.btnMarquerAnimee'))));
    }
    if (status != 'DELIVERED' && status != 'ANNULE') {
      buttons.add(OutlinedButton.icon(onPressed: busy ? null : schedule, icon: const Icon(Icons.event, size: 16), label: Text(t('safetyTalkDetail.btnPlanifier'))));
      buttons.add(OutlinedButton.icon(onPressed: busy ? null : postpone, icon: const Icon(Icons.schedule, size: 16), label: Text(status == 'REPORTE' ? t('safetyTalkDetail.btnReprogrammer') : t('safetyTalkDetail.btnReporter'))));
      buttons.add(OutlinedButton.icon(onPressed: busy ? null : cancel, icon: const Icon(Icons.cancel_outlined, size: 16), label: Text(t('safetyTalkDetail.annuler'))));
    }
    if (status != 'DELIVERED') {
      buttons.add(OutlinedButton.icon(onPressed: busy ? null : editForm, icon: const Icon(Icons.edit, size: 16), label: Text(t('safetyTalkDetail.btnModifier'))));
    }
    return buttons;
  }

  @override
  Widget build(BuildContext c) {
    if (loading) return Scaffold(appBar: AppBar(title: Text(t('safetyTalkDetail.titre'))), body: const Center(child: CircularProgressIndicator()));
    if (talk == null || talk!.isEmpty) return Scaffold(appBar: AppBar(title: Text(t('safetyTalkDetail.titre'))), body: Center(child: Text(error ?? t('safetyTalkDetail.introuvable'))));
    final tk = talk!;
    final status = tk['status'] as String?;
    final sColor = statusColor(status);
    final quiz = tk['quiz'];
    final quizQuestionsList = (quiz is Map && quiz['questions'] is List) ? List.from(quiz['questions']) : [];

    return Scaffold(
      appBar: AppBar(title: Text('${tk['title'] ?? ''}')),
      body: RefreshIndicator(
        onRefresh: loadAll,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: sColor.withOpacity(0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: sColor.withOpacity(0.3))),
            child: Row(children: [
              Icon(Icons.info_outline, color: sColor),
              const SizedBox(width: 8),
              Expanded(child: Text(statusLabels[status] ?? status ?? '—', style: TextStyle(color: sColor, fontWeight: FontWeight.bold))),
              prioriteChip(tk['priorite']),
            ]),
          ),
          const SizedBox(height: 12),
          _metaRow(t('safetyTalkDetail.metaSemaine'), t('safetyTalkDetail.metaSemaineValeur', {'debut': fmtDate(tk['weekStart']), 'fin': fmtDate(tk['weekEnd'])})),
          _metaRow(t('safetyTalkDetail.metaOrigine'), tk['origineType'] == 'AUTO_RECOMMANDE' ? '${t('safetyTalkDetail.origineAuto')}${tk['origineModules'] != null ? ' (${tk['origineModules']})' : ''}' : t('safetyTalkDetail.origineManuelle')),
          if (tk['origineRaison'] != null) _metaRow(t('safetyTalkDetail.metaMotif'), tk['origineRaison']),
          _metaRow(t('safetyTalkDetail.metaSiteServiceZoneEquipe'), [tk['siteId'], tk['service'], tk['zone'], tk['equipe']].where((x) => x != null && '$x'.isNotEmpty).join(' / ')),
          _metaRow(t('safetyTalkDetail.metaUniteTravail'), workUnitName(tk['workUnitId'])),
          _metaRow(t('safetyTalkDetail.metaResponsableAnimation'), userName(tk['responsableAnimationId'])),
          _metaRow(t('safetyTalkDetail.metaPlanifieeLe'), tk['scheduledAt'] != null ? '${tk['scheduledAt']}'.replaceFirst('T', ' ').substring(0, 16) : '—'),
          _metaRow(t('safetyTalkDetail.metaDuree'), tk['duree'] != null ? '${tk['duree']} min' : '—'),
          _metaRow(t('safetyTalkDetail.metaFrequence'), tk['frequence']),
          _metaRow(t('safetyTalkDetail.metaRealiseeLe'), tk['realisedAt'] != null ? fmtDate(tk['realisedAt']) : '—'),

          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: _workflowButtons(status)),

          const SizedBox(height: 20),
          Text(t('safetyTalkDetail.ficheContenu'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          _textBlock(t('safetyTalkDetail.champResume'), tk['summary']),
          _textBlock(t('safetyTalkDetail.champObjectif'), tk['objectif']),
          _textBlock(t('safetyTalkDetail.champContexte'), tk['contexte']),
          _textBlock(t('safetyTalkDetail.champRisquesConcernes'), tk['risquesConcernes']),
          _textBlock(t('safetyTalkDetail.champPersonnesExposees'), tk['personnesExposees']),
          _textBlock(t('safetyTalkDetail.champMessagePrincipal'), tk['messagePrincipal']),
          _textBlock(t('safetyTalkDetail.champPointsEssentiels'), tk['pointsEssentiels']),
          _textBlock(t('safetyTalkDetail.champBonnesPratiques'), tk['bonnesPratiques']),
          _textBlock(t('safetyTalkDetail.champMauvaisesPratiques'), tk['mauvaisesPratiques']),
          _textBlock(t('safetyTalkDetail.champQuestionsAPoser'), tk['questions']),
          _textBlock(t('safetyTalkDetail.champExemplesTerrain'), tk['exemplesTerrain']),
          _textBlock(t('safetyTalkDetail.champMesuresPrevention'), tk['mesuresPrevention']),
          _textBlock(t('safetyTalkDetail.champConduiteATenir'), tk['conduiteATenir']),
          _textBlock(t('safetyTalkDetail.champConclusion'), tk['conclusion']),
          _textBlock(t('safetyTalkDetail.champEngagementAttendu'), tk['engagementAttendu']),
          if (quizQuestionsList.isNotEmpty) ...[
            Text(t('safetyTalkDetail.quizLabel'), style: TextStyle(color: QhseColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            ...quizQuestionsList.map((q) => Padding(padding: const EdgeInsets.only(bottom: 2), child: Text('• $q', style: const TextStyle(fontSize: 13)))),
            const SizedBox(height: 12),
          ],

          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(t('safetyTalkDetail.emargement', {'count': '${participants.length}'}), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Wrap(spacing: 6, children: [
              TextButton.icon(onPressed: addParticipant, icon: const Icon(Icons.person_add_alt, size: 16), label: Text(t('safetyTalkDetail.ajouter'))),
              TextButton.icon(onPressed: bulkAddParticipants, icon: const Icon(Icons.group_add, size: 16), label: Text(t('safetyTalkDetail.ajoutGroupe'))),
            ]),
          ]),
          if (participants.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(t('safetyTalkDetail.aucunParticipant'), style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
          else
            ...participants.map((p) => Card(child: ListTile(
                  dense: true,
                  leading: Icon(p['present'] == true ? Icons.check_circle : Icons.cancel, color: p['present'] == true ? QhseColors.green : QhseColors.red, size: 20),
                  title: Text(employeeName(p['employeeId'])),
                  subtitle: p['motifAbsence'] != null ? Text('${p['motifAbsence']}', style: const TextStyle(fontSize: 11)) : null,
                  trailing: IconButton(icon: const Icon(Icons.delete_outline, size: 18), onPressed: () => removeParticipant(p['id'])),
                ))),

          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(t('safetyTalkDetail.remonteesTerrain', {'count': '${feedbacks.length}'}), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            TextButton.icon(onPressed: addFeedback, icon: const Icon(Icons.add_comment_outlined, size: 16), label: Text(t('safetyTalkDetail.ajouter'))),
          ]),
          if (feedbacks.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(t('safetyTalkDetail.aucuneRemontee'), style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
          else
            ...feedbacks.map((f) {
              final transformed = f['status'] == 'TRANSFORME';
              return Card(child: Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(_feedbackTypeLabels[f['type']] ?? '${f['type']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                  if (f['criticite'] != null) prioriteChip(f['criticite']),
                ]),
                const SizedBox(height: 4),
                Text('${f['description']}', style: const TextStyle(fontSize: 12)),
                if (f['localisation'] != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(t('safetyTalkDetail.localisationPrefixe', {'value': '${f['localisation']}'}), style: TextStyle(color: QhseColors.textSecondary, fontSize: 11))),
                if (f['mesureImmediate'] != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(t('safetyTalkDetail.mesureImmediatePrefixe', {'value': '${f['mesureImmediate']}'}), style: TextStyle(color: QhseColors.textSecondary, fontSize: 11))),
                const SizedBox(height: 8),
                if (transformed)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: QhseColors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                    child: Text(t('safetyTalkDetail.transformeeEn', {'target': _transformTargetLabels[f['transformedIntoModule']] ?? '${f['transformedIntoModule']}'}), style: TextStyle(color: QhseColors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                  )
                else
                  FilledButton.icon(onPressed: () => transformFeedback(f), icon: const Icon(Icons.transform, size: 15), label: Text(t('safetyTalkDetail.btnTransformer'))),
              ])));
            }),

          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(t('safetyTalkDetail.quizFinSeance'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            TextButton.icon(onPressed: submitQuiz, icon: const Icon(Icons.quiz_outlined, size: 16), label: Text(t('safetyTalkDetail.saisirResultat'))),
          ]),
          Row(children: [
            _quizStat(t('safetyTalkDetail.quizParticipants'), '${quizStats['participants'] ?? 0}'),
            const SizedBox(width: 16),
            _quizStat(t('safetyTalkDetail.quizScoreMoyen'), '${quizStats['scoreMoyen'] ?? 0}%'),
            const SizedBox(width: 16),
            _quizStat(t('safetyTalkDetail.quizTauxReussite'), '${quizStats['tauxReussite'] ?? 0}%'),
          ]),

          const SizedBox(height: 20),
          CapaLinksSection(
            key: ValueKey('capa-${widget.safetyTalkId}-$capaRefreshKey'),
            sourceModule: 'SAFETY_TALK',
            sourceEntityId: widget.safetyTalkId,
            prefill: {'title': t('safetyTalkDetail.suiviPrefixe', {'title': '${tk['title'] ?? ''}'}), 'source': t('safetyTalkDetail.titre')},
          ),
        ]),
      ),
    );
  }

  Widget _quizStat(String label, String value) => Expanded(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: QhseColors.textSecondary, fontSize: 11)),
      Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    ]),
  );
}
