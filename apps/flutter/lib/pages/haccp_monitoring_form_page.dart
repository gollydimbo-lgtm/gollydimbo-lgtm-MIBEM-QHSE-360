import 'package:flutter/material.dart';
import '../services/api.dart';
import '../services/sync_queue.dart';
import '../theme.dart';
import '../i18n/i18n.dart';
import 'capa_link_widget.dart';
import 'haccp_page.dart';
import 'non_conformities_page.dart';

/// Écran de saisie terrain d'un relevé de surveillance CCP — LE geste
/// quotidien le plus important du module HACCP : un opérateur/contrôleur
/// enregistre une mesure (température, pH, poids...) sur le point critique,
/// potentiellement sans réseau. Fonctionne en création (relevé ad hoc, sans
/// [existing]) ou en complétion d'un relevé déjà planifié (contrôle du jour
/// ou en retard, avec [existing] rempli — alors toujours une mise à jour).
///
/// Un résultat `conforme: false` déclenche côté serveur la création
/// automatique d'une Non-conformité (voir HaccpService.declencherNonConformite,
/// backend final, non modifiable) — mais UNIQUEMENT en ligne : la file
/// d'attente hors-ligne (SyncQueue → /sync/push → ENTITY_CREATE/UPDATE
/// 'haccpMonitoring') fait un create/update Prisma direct qui ne rejoue pas
/// ce moteur métier (voir commentaire dans sync.controller.ts). En saisie
/// hors-ligne, on ne peut donc pas garantir la création de la NC : l'app en
/// informe clairement l'agent terrain au lieu de laisser croire à une
/// création automatique qui n'aura pas lieu.
class HaccpMonitoringFormPage extends StatefulWidget {
  final Map ccp;
  final Map? existing;
  const HaccpMonitoringFormPage({super.key, required this.ccp, this.existing});
  @override
  State<HaccpMonitoringFormPage> createState() => _HaccpMonitoringFormPageState();
}

class _HaccpMonitoringFormPageState extends State<HaccpMonitoringFormPage> {
  final api = Api();
  final valeur = TextEditingController();
  final valeurTexte = TextEditingController();
  final lotNumero = TextEditingController();
  final commentaire = TextEditingController();
  final signature = TextEditingController();
  List users = [];
  String? responsableId;
  DateTime dateRealisee = DateTime.now();
  bool busy = false, loadingLists = true, savedOffline = false;
  Map? savedRecord; // relevé retourné par le serveur après enregistrement en ligne

  bool get editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      if (e['valeur'] != null) valeur.text = '${e['valeur']}';
      valeurTexte.text = e['valeurTexte'] ?? '';
      lotNumero.text = e['lotNumero'] ?? '';
      commentaire.text = e['commentaire'] ?? '';
      signature.text = e['signature'] ?? '';
      responsableId = e['responsableId'];
    } else {
      responsableId = widget.ccp['responsableId'];
    }
    loadLists();
  }

  Future<void> loadLists() async {
    try { users = List.from(await api.get('/users')); } catch (_) {}
    setState(() => loadingLists = false);
  }

  Future<void> pickDateRealisee() async {
    final d = await showDatePicker(context: context, initialDate: dateRealisee, firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime.now().add(const Duration(days: 1)));
    if (d == null) return;
    if (!mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(dateRealisee));
    setState(() => dateRealisee = DateTime(d.year, d.month, d.day, time?.hour ?? dateRealisee.hour, time?.minute ?? dateRealisee.minute));
  }

  Map<String, dynamic> _basePayload(bool conforme) {
    final v = double.tryParse(valeur.text.trim().replaceAll(',', '.'));
    return {
      'conforme': conforme,
      // Le statut est calculé ici et pas seulement laissé au serveur : en
      // hors-ligne, le create/update Prisma brut ne le recalcule pas lui-même.
      'statut': conforme ? 'CONFORME' : 'NON_CONFORME',
      if (v != null) 'valeur': v,
      if (valeurTexte.text.trim().isNotEmpty) 'valeurTexte': valeurTexte.text.trim(),
      if (lotNumero.text.trim().isNotEmpty) 'lotNumero': lotNumero.text.trim(),
      if (commentaire.text.trim().isNotEmpty) 'commentaire': commentaire.text.trim(),
      if (signature.text.trim().isNotEmpty) 'signature': signature.text.trim(),
      if (responsableId != null) 'responsableId': responsableId,
      'dateRealisee': dateRealisee.toIso8601String(),
      if (editing && widget.existing!['datePrevue'] != null) 'datePrevue': widget.existing!['datePrevue'],
    };
  }

  Future<void> save(bool conforme) async {
    setState(() => busy = true);
    final payload = _basePayload(conforme);
    try {
      Map result;
      if (editing) {
        result = Map.from(await api.patch('/haccp/monitoring/${widget.existing!['id']}', payload));
      } else {
        result = Map.from(await api.post('/haccp/ccps/${widget.ccp['id']}/monitoring', payload));
      }
      setState(() { savedRecord = result; busy = false; });
    } on ApiException catch (e) {
      if (e.networkError) {
        if (editing) {
          await SyncQueue.enqueue('haccpMonitoring', 'UPDATE', payload, entityId: widget.existing!['id'] as String);
        } else {
          await SyncQueue.enqueue('haccpMonitoring', 'CREATE', {
            ...payload,
            'ccpId': widget.ccp['id'],
            'studyId': widget.ccp['studyId'],
          });
        }
        setState(() { savedOffline = true; busy = false; });
      } else {
        setState(() => busy = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } catch (e) {
      setState(() => busy = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Widget _confirmationView() {
    final r = savedRecord;
    final conforme = r != null ? r['conforme'] == true : null;
    // Saisie hors-ligne : ni le résultat exact ni une éventuelle NC ne sont
    // connus ici, seulement l'intention saisie par l'agent.
    if (savedOffline) {
      return _resultScaffold(
        color: QhseColors.amber,
        icon: Icons.cloud_off,
        title: t('haccpMonitoringForm.releveEnregistreHorsLigne'),
        message: t('haccpMonitoringForm.messageHorsLigne'),
        children: const [],
      );
    }
    if (r == null) return const SizedBox.shrink();
    final ncId = r['nonConformityId'];
    return _resultScaffold(
      color: conforme == true ? QhseColors.green : QhseColors.red,
      icon: conforme == true ? Icons.check_circle_outline : Icons.report_gmailerrorred,
      title: conforme == true ? t('haccpMonitoringForm.releveConformeEnregistre') : t('haccpMonitoringForm.releveNonConformeEnregistre'),
      message: conforme == true ? t('haccpMonitoringForm.aucuneActionRequise') : t('haccpMonitoringForm.ncCreeeAutomatiquement'),
      children: [
        if (conforme == false && ncId != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: QhseColors.red.withOpacity(0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: QhseColors.red.withOpacity(0.3))),
            child: Row(children: [
              Icon(Icons.error_outline, color: QhseColors.red),
              const SizedBox(width: 8),
              Expanded(child: Text(t('haccpMonitoringForm.ncCreeeAutomatiquementCourt'), style: const TextStyle(fontWeight: FontWeight.bold))),
              TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NonConformityDetailPage(ncId: ncId))), child: Text(t('haccpMonitoringForm.voir'))),
            ]),
          ),
          const SizedBox(height: 16),
          CapaLinksSection(
            sourceModule: 'HACCP_CCP',
            sourceEntityId: r['id'],
            prefill: {'title': t('haccpMonitoringForm.traiterEcartCcp', {'reference': '${widget.ccp['reference'] ?? ''}'})},
          ),
        ],
      ],
    );
  }

  Widget _resultScaffold({required Color color, required IconData icon, required String title, required String message, required List<Widget> children}) => Scaffold(
    appBar: AppBar(title: Text(t('haccpMonitoringForm.releveDeSurveillance'))),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, color: color), const SizedBox(width: 8), Expanded(child: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)))]),
          const SizedBox(height: 6),
          Text(message, style: const TextStyle(fontSize: 13)),
        ]),
      ),
      ...children,
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(t('haccpMonitoringForm.terminer')))),
    ]),
  );

  @override
  Widget build(BuildContext c) {
    if (savedRecord != null || savedOffline) return _confirmationView();
    final ccp = widget.ccp;
    return Scaffold(
      appBar: AppBar(title: Text(t('haccpMonitoringForm.releveTitre', {'reference': '${ccp['reference'] ?? ''}'}))),
      body: loadingLists
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: QhseColors.blue.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    haccpChip(ccp['type'] ?? 'CCP', QhseColors.blue),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${ccp['dangerMaitrise'] ?? ccp['parametre'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold))),
                  ]),
                  if (ccp['limiteCritique'] != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(t('haccpMonitoringForm.limiteCritique', {'valeur': '${ccp['limiteCritique']}'}), style: const TextStyle(fontSize: 13))),
                  if (ccp['critereAcceptation'] != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(t('haccpMonitoringForm.critereAcceptation', {'valeur': '${ccp['critereAcceptation']}'}), style: TextStyle(color: QhseColors.textSecondary, fontSize: 12))),
                  if (ccp['methode'] != null || ccp['instrument'] != null)
                    Padding(padding: const EdgeInsets.only(top: 2), child: Text([ccp['methode'], ccp['instrument']].where((x) => x != null).join(' · '), style: TextStyle(color: QhseColors.textSecondary, fontSize: 12))),
                ]),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: valeur, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: InputDecoration(labelText: t('haccpMonitoringForm.valeurMesuree'), suffixText: ccp['unite']),
              ),
              const SizedBox(height: 12),
              TextField(controller: valeurTexte, decoration: InputDecoration(labelText: t('haccpMonitoringForm.valeurQualitative'))),
              const SizedBox(height: 12),
              TextField(controller: lotNumero, decoration: InputDecoration(labelText: t('haccpMonitoringForm.numeroDeLot'))),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true, decoration: InputDecoration(labelText: t('haccpMonitoringForm.controleur')), value: responsableId,
                items: [const DropdownMenuItem<String>(value: null, child: Text('—')), ...users.map<DropdownMenuItem<String>>((u) => DropdownMenuItem<String>(value: u['id'] as String, child: Text('${u['firstName']} ${u['lastName']}')))],
                onChanged: (v) => setState(() => responsableId = v),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(onPressed: pickDateRealisee, icon: const Icon(Icons.event, size: 16), label: Text(t('haccpMonitoringForm.realiseLe', {'date': haccpFmtDateTime(dateRealisee.toIso8601String())}))),
              const SizedBox(height: 12),
              TextField(controller: signature, decoration: InputDecoration(labelText: t('haccpMonitoringForm.signature'))),
              const SizedBox(height: 12),
              TextField(controller: commentaire, maxLines: 3, decoration: InputDecoration(labelText: t('haccpMonitoringForm.commentaire'))),
              const SizedBox(height: 24),
              Text(t('haccpMonitoringForm.resultat'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: FilledButton.icon(
                  onPressed: busy ? null : () => save(true),
                  style: FilledButton.styleFrom(backgroundColor: QhseColors.green),
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(t('haccpMonitoringForm.conforme')),
                )),
                const SizedBox(width: 10),
                Expanded(child: FilledButton.icon(
                  onPressed: busy ? null : () => save(false),
                  style: FilledButton.styleFrom(backgroundColor: QhseColors.red),
                  icon: const Icon(Icons.report_gmailerrorred),
                  label: Text(t('haccpMonitoringForm.nonConforme')),
                )),
              ]),
              const SizedBox(height: 6),
              Text(t('haccpMonitoringForm.noteConversionNc'), style: TextStyle(color: QhseColors.textSecondary, fontSize: 11)),
              if (busy) const Padding(padding: EdgeInsets.only(top: 16), child: Center(child: CircularProgressIndicator())),
            ]),
    );
  }
}
