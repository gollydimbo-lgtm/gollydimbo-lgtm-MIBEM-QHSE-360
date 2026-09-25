import 'package:flutter/material.dart';
import '../services/api.dart';
import '../theme.dart';
import '../i18n/i18n.dart';
import 'capa_link_widget.dart';
import 'haccp_monitoring_form_page.dart';
import 'haccp_page.dart';
import 'non_conformities_page.dart';

/// Fiche complète d'un CCP/CP : caractéristiques de maîtrise, historique de
/// surveillance et, pour chaque relevé non conforme, la non-conformité
/// générée automatiquement ainsi que l'accès à la création d'une Action
/// CAPA (CapaLinksSection, sourceModule='HACCP_CCP') — le préremplissage
/// backend (capaPrefillFromSource) attend l'id du RELEVÉ de surveillance en
/// sourceEntityId, pas l'id du CCP, d'où une section par relevé plutôt
/// qu'une section unique pour toute la fiche.
///
/// Il n'existe pas de `GET /haccp/ccps/:id` dédié (contrat backend vérifié,
/// non modifiable) : le CCP est retrouvé dans `GET /haccp/studies/:id/ccps`,
/// même pattern que SafetyTalkDetailPage pour les fiches sans route dédiée.
class HaccpCcpDetailPage extends StatefulWidget {
  final String studyId;
  final String ccpId;
  const HaccpCcpDetailPage({super.key, required this.studyId, required this.ccpId});
  @override
  State<HaccpCcpDetailPage> createState() => _HaccpCcpDetailPageState();
}

class _HaccpCcpDetailPageState extends State<HaccpCcpDetailPage> {
  final api = Api();
  Map? ccp;
  List monitoring = [];
  List users = [];
  bool loading = true, busy = false;
  String? error;

  @override
  void initState() { super.initState(); loadAll(); }

  Future<void> loadAll() async {
    setState(() => loading = true);
    try {
      final list = List.from(await api.get('/haccp/studies/${widget.studyId}/ccps'));
      final found = list.firstWhere((x) => x['id'] == widget.ccpId, orElse: () => null);
      ccp = found != null ? Map.from(found) : null;
      if (ccp == null) error = t('haccpCcpDetail.ccpIntrouvable');
    } catch (e) { error = '$e'; }
    await Future.wait([loadMonitoring(), loadUsers()]);
    setState(() => loading = false);
  }

  Future<void> loadMonitoring() async {
    try { monitoring = List.from(await api.get('/haccp/ccps/${widget.ccpId}/monitoring')); } catch (_) {}
  }

  Future<void> loadUsers() async { try { users = List.from(await api.get('/users')); } catch (_) {} }

  String userName(String? id) {
    if (id == null) return '—';
    final u = users.firstWhere((x) => x['id'] == id, orElse: () => null);
    return u == null ? '—' : '${u['firstName']} ${u['lastName']}';
  }

  Future<void> newRecord() async {
    if (ccp == null) return;
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => HaccpMonitoringFormPage(ccp: ccp!)));
    if (result != null) loadAll();
  }

  Future<void> editCcp() async {
    final k = ccp!;
    final dangerMaitrise = TextEditingController(text: k['dangerMaitrise'] ?? '');
    final causeDanger = TextEditingController(text: k['causeDanger'] ?? '');
    final mesureMaitrise = TextEditingController(text: k['mesureMaitrise'] ?? '');
    final limiteCritique = TextEditingController(text: k['limiteCritique'] ?? '');
    final critereAcceptation = TextEditingController(text: k['critereAcceptation'] ?? '');
    final parametre = TextEditingController(text: k['parametre'] ?? '');
    final unite = TextEditingController(text: k['unite'] ?? '');
    final methode = TextEditingController(text: k['methode'] ?? '');
    final instrument = TextEditingController(text: k['instrument'] ?? '');
    final frequence = TextEditingController(text: k['frequence'] ?? '');
    final enregistrementAssocie = TextEditingController(text: k['enregistrementAssocie'] ?? '');
    final actionImmediate = TextEditingController(text: k['actionImmediate'] ?? '');
    String? responsableId = k['responsableId'];
    bool active = k['active'] ?? true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dc) => StatefulBuilder(builder: (dc, setD) => AlertDialog(
        title: Text(t('haccpCcpDetail.modifierTitre', {'reference': '${k['reference']}'})),
        content: SizedBox(width: 440, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: dangerMaitrise, decoration: InputDecoration(labelText: t('haccpCcpDetail.dangerMaitrise'))),
          const SizedBox(height: 10),
          TextField(controller: causeDanger, maxLines: 2, decoration: InputDecoration(labelText: t('haccpCcpDetail.causeDanger'))),
          const SizedBox(height: 10),
          TextField(controller: mesureMaitrise, maxLines: 2, decoration: InputDecoration(labelText: t('haccpCcpDetail.mesureMaitrise'))),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: limiteCritique, decoration: InputDecoration(labelText: t('haccpCcpDetail.limiteCritique')))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: unite, decoration: InputDecoration(labelText: t('haccpCcpDetail.unite')))),
          ]),
          const SizedBox(height: 10),
          TextField(controller: critereAcceptation, decoration: InputDecoration(labelText: t('haccpCcpDetail.critereAcceptation'))),
          const SizedBox(height: 10),
          TextField(controller: parametre, decoration: InputDecoration(labelText: t('haccpCcpDetail.parametreSurveille'))),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: methode, decoration: InputDecoration(labelText: t('haccpCcpDetail.methode')))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: instrument, decoration: InputDecoration(labelText: t('haccpCcpDetail.instrument')))),
          ]),
          const SizedBox(height: 10),
          TextField(controller: frequence, decoration: InputDecoration(labelText: t('haccpCcpDetail.frequenceDeSurveillance'))),
          const SizedBox(height: 10),
          TextField(controller: enregistrementAssocie, decoration: InputDecoration(labelText: t('haccpCcpDetail.enregistrementAssocie'))),
          const SizedBox(height: 10),
          TextField(controller: actionImmediate, maxLines: 2, decoration: InputDecoration(labelText: t('haccpCcpDetail.actionImmediateEnCasEcart'))),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            isExpanded: true, decoration: InputDecoration(labelText: t('haccpCcpDetail.responsable')), value: responsableId,
            items: [const DropdownMenuItem<String>(value: null, child: Text('—')), ...users.map<DropdownMenuItem<String>>((u) => DropdownMenuItem<String>(value: u['id'] as String, child: Text('${u['firstName']} ${u['lastName']}')))],
            onChanged: (v) => setD(() => responsableId = v),
          ),
          CheckboxListTile(contentPadding: EdgeInsets.zero, value: active, title: Text(t('haccpCcpDetail.pointActif'), style: const TextStyle(fontSize: 13)), onChanged: (v) => setD(() => active = v ?? true)),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dc, false), child: Text(t('haccpCcpDetail.annuler'))),
          FilledButton(onPressed: () => Navigator.pop(dc, true), child: Text(t('haccpCcpDetail.enregistrer'))),
        ],
      )),
    );
    if (ok != true) return;
    setState(() => busy = true);
    try {
      await api.patch('/haccp/ccps/${widget.ccpId}', {
        'dangerMaitrise': dangerMaitrise.text.trim().isEmpty ? null : dangerMaitrise.text.trim(),
        'causeDanger': causeDanger.text.trim().isEmpty ? null : causeDanger.text.trim(),
        'mesureMaitrise': mesureMaitrise.text.trim().isEmpty ? null : mesureMaitrise.text.trim(),
        'limiteCritique': limiteCritique.text.trim().isEmpty ? null : limiteCritique.text.trim(),
        'critereAcceptation': critereAcceptation.text.trim().isEmpty ? null : critereAcceptation.text.trim(),
        'parametre': parametre.text.trim().isEmpty ? null : parametre.text.trim(),
        'unite': unite.text.trim().isEmpty ? null : unite.text.trim(),
        'methode': methode.text.trim().isEmpty ? null : methode.text.trim(),
        'instrument': instrument.text.trim().isEmpty ? null : instrument.text.trim(),
        'frequence': frequence.text.trim().isEmpty ? null : frequence.text.trim(),
        'enregistrementAssocie': enregistrementAssocie.text.trim().isEmpty ? null : enregistrementAssocie.text.trim(),
        'actionImmediate': actionImmediate.text.trim().isEmpty ? null : actionImmediate.text.trim(),
        'responsableId': responsableId, 'active': active,
      });
      await loadAll();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
    setState(() => busy = false);
  }

  Future<void> deleteCcp() async {
    final ok = await showDialog<bool>(context: context, builder: (dc) => AlertDialog(
      title: Text(t('haccpCcpDetail.supprimerTitre', {'reference': '${ccp?['reference']}'})),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dc, false), child: Text(t('haccpCcpDetail.annuler'))),
        FilledButton(onPressed: () => Navigator.pop(dc, true), child: Text(t('haccpCcpDetail.supprimer'))),
      ],
    ));
    if (ok != true) return;
    try { await api.delete('/haccp/ccps/${widget.ccpId}'); if (mounted) Navigator.pop(context, true); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  Widget _metaRow(String label, dynamic value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 150, child: Text(label, style: TextStyle(color: QhseColors.textSecondary, fontSize: 12))),
      Expanded(child: Text(value == null || '$value'.trim().isEmpty ? '—' : '$value', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
    ]),
  );

  @override
  Widget build(BuildContext c) {
    if (loading) return Scaffold(appBar: AppBar(title: Text(t('haccpCcpDetail.pointDeMaitrise'))), body: const Center(child: CircularProgressIndicator()));
    if (ccp == null) return Scaffold(appBar: AppBar(title: Text(t('haccpCcpDetail.pointDeMaitrise'))), body: Center(child: Text(error ?? t('haccpCcpDetail.introuvable'))));
    final k = ccp!;
    final typeColor = k['type'] == 'CCP' ? QhseColors.red : QhseColors.blue;

    return Scaffold(
      appBar: AppBar(title: Text('${k['reference']}')),
      body: RefreshIndicator(
        onRefresh: loadAll,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: typeColor.withOpacity(0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: typeColor.withOpacity(0.3))),
            child: Row(children: [
              Icon(k['type'] == 'CCP' ? Icons.gpp_maybe_outlined : Icons.shield_outlined, color: typeColor),
              const SizedBox(width: 8),
              Expanded(child: Text(k['type'] == 'CCP' ? t('haccpCcpDetail.pointCritiqueDeMaitrise') : t('haccpCcpDetail.pointDeVigilance'), style: TextStyle(color: typeColor, fontWeight: FontWeight.bold))),
              haccpChip(k['active'] == true ? t('haccpCcpDetail.actif') : t('haccpCcpDetail.inactif'), k['active'] == true ? QhseColors.green : QhseColors.textSecondary),
            ]),
          ),
          const SizedBox(height: 12),
          _metaRow(t('haccpCcpDetail.dangerMaitrise'), k['dangerMaitrise']),
          _metaRow(t('haccpCcpDetail.causeDanger'), k['causeDanger']),
          _metaRow(t('haccpCcpDetail.mesureMaitrise'), k['mesureMaitrise']),
          _metaRow(t('haccpCcpDetail.limiteCritique'), k['limiteCritique'] != null ? '${k['limiteCritique']}${k['unite'] != null ? ' ${k['unite']}' : ''}' : null),
          _metaRow(t('haccpCcpDetail.critereAcceptation'), k['critereAcceptation']),
          _metaRow(t('haccpCcpDetail.parametreSurveille'), k['parametre']),
          _metaRow(t('haccpCcpDetail.methodeInstrument'), [k['methode'], k['instrument']].where((x) => x != null && '$x'.isNotEmpty).join(' · ')),
          _metaRow(t('haccpCcpDetail.frequenceDeSurveillance'), k['frequence']),
          _metaRow(t('haccpCcpDetail.responsable'), userName(k['responsableId'])),
          _metaRow(t('haccpCcpDetail.enregistrementAssocie'), k['enregistrementAssocie']),
          _metaRow(t('haccpCcpDetail.actionImmediate'), k['actionImmediate']),

          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(onPressed: busy ? null : editCcp, icon: const Icon(Icons.edit, size: 16), label: Text(t('haccpCcpDetail.modifier'))),
            TextButton.icon(onPressed: busy ? null : deleteCcp, icon: Icon(Icons.delete_outline, size: 16, color: QhseColors.red), label: Text(t('haccpCcpDetail.supprimer'), style: TextStyle(color: QhseColors.red))),
          ]),

          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(t('haccpCcpDetail.historiqueDeSurveillance', {'count': '${monitoring.length}'}), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            FilledButton.icon(onPressed: newRecord, icon: const Icon(Icons.add, size: 16), label: Text(t('haccpCcpDetail.nouveauReleve'))),
          ]),
          const SizedBox(height: 8),
          if (monitoring.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(t('haccpCcpDetail.aucunReleveEnregistre'), style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
          else
            ...monitoring.map((m) {
              final nonConforme = m['statut'] == 'NON_CONFORME';
              final tile = Card(child: ListTile(
                leading: Icon(
                  nonConforme ? Icons.report_gmailerrorred : m['conforme'] == true ? Icons.check_circle_outline : Icons.schedule,
                  color: haccpMonitoringStatutColor(m['statut']),
                ),
                title: Text(m['valeur'] != null ? '${m['valeur']}${k['unite'] ?? ''}' : (m['valeurTexte'] ?? '—')),
                subtitle: Text('${haccpFmtDateTime(m['dateRealisee'] ?? m['datePrevue'])}${m['lotNumero'] != null ? ' · ' + t('haccpCcpDetail.lot', {'numero': '${m['lotNumero']}'}) : ''}'),
                trailing: haccpChip(haccpMonitoringStatutLabels[m['statut']] ?? '${m['statut']}', haccpMonitoringStatutColor(m['statut'])),
              ));
              if (!nonConforme) return tile;
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                tile,
                Container(
                  margin: const EdgeInsets.only(bottom: 10, top: -4),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: QhseColors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.error_outline, color: QhseColors.red, size: 18),
                      const SizedBox(width: 6),
                      Expanded(child: Text(t('haccpCcpDetail.ncCreeeAutomatiquement'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      if (m['nonConformityId'] != null)
                        TextButton(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => NonConformityDetailPage(ncId: m['nonConformityId']))), child: Text(t('haccpCcpDetail.voir'), style: const TextStyle(fontSize: 12))),
                    ]),
                    const SizedBox(height: 6),
                    CapaLinksSection(
                      key: ValueKey('capa-haccp-${m['id']}'),
                      sourceModule: 'HACCP_CCP',
                      sourceEntityId: m['id'],
                      prefill: {'title': t('haccpCcpDetail.traiterEcartCcp', {'reference': '${k['reference']}'})},
                    ),
                  ]),
                ),
              ]);
            }),
        ]),
      ),
    );
  }
}
