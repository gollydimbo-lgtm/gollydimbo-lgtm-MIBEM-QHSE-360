import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api.dart';
import '../services/sync_queue.dart';
import '../theme.dart';
import 'attachment_helpers.dart';
import 'capa_link_widget.dart';
import '../i18n/i18n.dart';

const _docStatusKeys = {
  'DRAFT': 'statusDraft',
  'REVIEW': 'statusReview',
  'APPROVED': 'statusApproved',
  'ACTIVE': 'statusActive',
  'SUPERSEDED': 'statusSuperseded',
  'ARCHIVED': 'statusArchived',
};
String _docStatusLabel(String? k) => k == null ? '—' : t('docDetail.${_docStatusKeys[k] ?? 'statusDraft'}');

const _docCriticiteKeys = {'NON_CRITIQUE': 'critNonCritique', 'CRITIQUE': 'critCritique'};
String _docCriticiteLabel(String? k) => k == null ? '—' : t('docDetail.${_docCriticiteKeys[k] ?? 'critNonCritique'}');

const _docFrequenceKeys = {
  'MENSUELLE': 'freqMensuelle', 'TRIMESTRIELLE': 'freqTrimestrielle', 'SEMESTRIELLE': 'freqSemestrielle',
  'ANNUELLE': 'freqAnnuelle', 'BIENNALE': 'freqBiennale', 'PERSONNALISEE': 'freqPersonnalisee',
};
String _docFrequenceLabel(String? k) => k == null ? '—' : t('docDetail.${_docFrequenceKeys[k] ?? 'freqAnnuelle'}');

Color _docStatusColor(String? s) => {
      'DRAFT': QhseColors.blue,
      'REVIEW': QhseColors.amber,
      'APPROVED': QhseColors.amber,
      'ACTIVE': QhseColors.green,
      'SUPERSEDED': QhseColors.red,
      'ARCHIVED': QhseColors.textSecondary,
    }[s] ??
    QhseColors.textSecondary;

String _mimeFromName(String name) {
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  switch (ext) {
    case 'pdf': return 'application/pdf';
    case 'doc': return 'application/msword';
    case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    case 'xls': return 'application/vnd.ms-excel';
    case 'xlsx': return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    case 'png': return 'image/png';
    case 'jpg': case 'jpeg': return 'image/jpeg';
    default: return 'application/octet-stream';
  }
}

// --- Détail d'un document : bandeau de statut, métadonnées, circuit de
// validation (submit/verify/approve/archive/reopen), historique des
// approbations, diffusion + accusés de lecture, nouvelle version, QR code,
// et Actions CAPA associées (le document peut être source d'une CAPA).
class DocumentDetailPage extends StatefulWidget {
  final String documentId;
  const DocumentDetailPage({super.key, required this.documentId});
  @override
  State<DocumentDetailPage> createState() => _DocumentDetailPageState();
}

class _DocumentDetailPageState extends State<DocumentDetailPage> {
  final api = Api();
  Map? doc;
  bool loading = true, busy = false;
  String? error;
  List users = [];

  @override
  void initState() { super.initState(); load(); loadUsers(); }

  Future<void> load() async {
    setState(() => loading = true);
    try { doc = Map.from(await api.get('/documents/${widget.documentId}')); }
    catch (e) { error = '$e'; }
    setState(() => loading = false);
  }

  Future<void> loadUsers() async {
    try { users = List.from(await api.get('/users')); } catch (_) {}
    if (mounted) setState(() {});
  }

  String userName(String? id) {
    if (id == null) return '—';
    final u = users.firstWhere((x) => x['id'] == id, orElse: () => null);
    return u == null ? '—' : '${u['firstName']} ${u['lastName']}';
  }

  Future<String?> askComment(String title) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl, maxLines: 3, decoration: InputDecoration(labelText: t('docDetail.commentaireOptionnel'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t('docDetail.annuler'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(t('docDetail.confirmer'))),
        ],
      ),
    );
    if (ok != true) return null;
    return ctrl.text.trim().isEmpty ? null : ctrl.text.trim();
  }

  Future<void> doAction(String path, Map body) async {
    setState(() => busy = true);
    try { await api.post(path, body); await load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
    setState(() => busy = false);
  }

  Future<void> submit() => doAction('/documents/${widget.documentId}/submit', {});

  Future<void> verify(String decision) async {
    final comment = await askComment(decision == 'APPROUVE' ? t('docDetail.validerVerification') : t('docDetail.demanderModification'));
    await doAction('/documents/${widget.documentId}/verify', {'decision': decision, if (comment != null) 'comment': comment});
  }

  Future<void> approve(String decision) async {
    final comment = await askComment(decision == 'APPROUVE' ? t('docDetail.approuverEtPublier') : t('docDetail.refuser'));
    await doAction('/documents/${widget.documentId}/approve', {'decision': decision, if (comment != null) 'comment': comment});
  }

  Future<void> archive() => doAction('/documents/${widget.documentId}/archive', {});
  Future<void> reopen() => doAction('/documents/${widget.documentId}/reopen', {});

  Future<void> regenerateQr() => doAction('/documents/${widget.documentId}/regenerate-qr', {});

  Future<void> newVersion() async {
    final r = await FilePicker.platform.pickFiles(withData: true);
    if (r == null || r.files.single.bytes == null) return;
    final name = r.files.single.name;
    final bytes = r.files.single.bytes!;
    final motif = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t('docDetail.nouvelleVersionTitle')),
        content: TextField(controller: motif, decoration: InputDecoration(labelText: t('docDetail.motifModificationOptionnel'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t('docDetail.annuler'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(t('docDetail.envoyer'))),
        ],
      ),
    );
    if (ok != true) return;
    await doAction('/documents/${widget.documentId}/versions', {
      'fileName': name, 'mimeType': _mimeFromName(name), 'base64': base64Encode(bytes),
      if (motif.text.trim().isNotEmpty) 'motifModification': motif.text.trim(),
    });
  }

  Future<void> diffuse() async {
    if (users.isEmpty) { try { users = List.from(await api.get('/users')); } catch (_) {} }
    final selected = <String>{};
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
        title: Text(t('docDetail.diffuserDocumentTitle')),
        content: SizedBox(width: 420, height: 360, child: users.isEmpty
            ? Center(child: Text(t('docDetail.aucunUtilisateur')))
            : ListView(children: users.map<Widget>((u) => CheckboxListTile(
                dense: true,
                value: selected.contains(u['id']),
                title: Text('${u['firstName']} ${u['lastName']}', style: const TextStyle(fontSize: 13)),
                onChanged: (v) => setD(() { if (v == true) selected.add(u['id']); else selected.remove(u['id']); }),
              )).toList())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t('docDetail.annuler'))),
          FilledButton(onPressed: selected.isEmpty ? null : () => Navigator.pop(c, true), child: Text(t('docDetail.diffuser'))),
        ],
      )),
    );
    if (ok != true || selected.isEmpty) return;
    final accuseRequis = doc?['diffusionAccuseRequis'] == true;
    await doAction('/documents/${widget.documentId}/diffuse', {
      'recipients': selected.map((id) => {'userId': id, 'accuseRequis': accuseRequis}).toList(),
    });
  }

  Future<void> accuse(String recipientId) async {
    try { await api.post('/documents/diffusion-recipients/$recipientId/accuse', {}); load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  List<Widget> _actionButtons(String? status) {
    switch (status) {
      case 'DRAFT':
        return [FilledButton.icon(onPressed: busy ? null : submit, icon: const Icon(Icons.send, size: 16), label: Text(t('docDetail.soumettrePourVerification')))];
      case 'REVIEW':
        return [
          FilledButton.icon(onPressed: busy ? null : () => verify('APPROUVE'), icon: const Icon(Icons.check, size: 16), label: Text(t('docDetail.verifieConforme'))),
          OutlinedButton.icon(onPressed: busy ? null : () => verify('DEMANDE_MODIFICATION'), icon: const Icon(Icons.edit_note, size: 16), label: Text(t('docDetail.demanderModification'))),
        ];
      case 'APPROVED':
        return [
          FilledButton.icon(onPressed: busy ? null : () => approve('APPROUVE'), icon: const Icon(Icons.verified_outlined, size: 16), label: Text(t('docDetail.approuverEtPublier'))),
          OutlinedButton.icon(onPressed: busy ? null : () => approve('REFUSE'), icon: const Icon(Icons.close, size: 16), label: Text(t('docDetail.refuser'))),
        ];
      case 'ACTIVE':
        return [OutlinedButton.icon(onPressed: busy ? null : archive, icon: const Icon(Icons.archive_outlined, size: 16), label: Text(t('docDetail.archiver')))];
      case 'ARCHIVED':
        return [OutlinedButton.icon(onPressed: busy ? null : reopen, icon: const Icon(Icons.unarchive_outlined, size: 16), label: Text(t('docDetail.reactiver')))];
      default:
        return [];
    }
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
    if (loading) return Scaffold(appBar: AppBar(title: Text(t('docDetail.pageTitleFallback'))), body: const Center(child: CircularProgressIndicator()));
    if (error != null || doc == null) return Scaffold(appBar: AppBar(title: Text(t('docDetail.pageTitleFallback'))), body: Center(child: Text(error ?? t('docDetail.introuvable'))));
    final d = doc!;
    final status = d['status'] as String?;
    final approvals = List.from(d['approvals'] ?? []);
    final diffusions = List.from(d['diffusions'] ?? []);
    final links = List.from(d['links'] ?? []);
    final statusColor = _docStatusColor(status);
    final notUsable = status == 'SUPERSEDED' || status == 'ARCHIVED';

    return Scaffold(
      appBar: AppBar(title: Text('${d['code'] ?? ''}')),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: statusColor.withOpacity(0.3))),
            child: Row(children: [
              Icon(notUsable ? Icons.block : Icons.info_outline, color: statusColor),
              const SizedBox(width: 8),
              Expanded(child: Text(_docStatusLabel(status), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold))),
            ]),
          ),
          const SizedBox(height: 12),
          Text('${d['title']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          if (d['description'] != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${d['description']}')),
          const SizedBox(height: 12),
          _metaRow(t('docDetail.metaType'), d['documentType']),
          _metaRow(t('docDetail.metaCategorie'), d['category']),
          _metaRow(t('docDetail.metaDomaineService'), [d['domaine'], d['service']].where((x) => x != null && '$x'.isNotEmpty).join(' / ')),
          _metaRow(t('docDetail.metaSite'), d['siteId']),
          _metaRow(t('docDetail.metaVersionCourante'), 'v${d['currentVersion']}'),
          _metaRow(t('docDetail.metaCriticite'), _docCriticiteLabel(d['criticite'])),
          _metaRow(t('docDetail.metaFrequenceRevision'), _docFrequenceLabel(d['frequenceRevision'])),
          _metaRow(t('docDetail.metaResponsable'), userName(d['responsibleId'])),
          _metaRow(t('docDetail.metaVerificateur'), userName(d['verificateurId'])),
          _metaRow(t('docDetail.metaApprobateur'), userName(d['approbateurId'])),
          _metaRow(t('docDetail.metaEntreeVigueur'), d['dateEntreeVigueur'] != null ? '${d['dateEntreeVigueur']}'.substring(0, 10) : '—'),
          _metaRow(t('docDetail.metaProchaineRevision'), d['nextReviewAt'] != null ? '${d['nextReviewAt']}'.substring(0, 10) : '—'),
          if (d['external'] == true) _metaRow(t('docDetail.metaOrganismeSource'), d['sourceOrganisme']),

          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: _actionButtons(status)),

          const SizedBox(height: 20),
          Text(t('docDetail.historiqueApprobationsTitle'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          if (approvals.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(t('docDetail.aucuneDecision'), style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
          else
            ...approvals.map((a) => Card(child: ListTile(
                  dense: true,
                  title: Text('${a['role'] ?? ''} — ${a['decision'] ?? ''}'),
                  subtitle: Text('${a['comment'] ?? ''}${a['createdAt'] != null ? ' · ${'${a['createdAt']}'.substring(0, 10)}' : ''}'),
                ))),

          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(t('docDetail.diffusionTitle'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            TextButton.icon(onPressed: busy ? null : diffuse, icon: const Icon(Icons.send, size: 16), label: Text(t('docDetail.diffuser'))),
          ]),
          if (diffusions.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(t('docDetail.aucuneDiffusion'), style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
          else
            ...diffusions.map((diff) {
              final recipients = List.from(diff['recipients'] ?? []);
              return Card(child: Padding(padding: const EdgeInsets.all(8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t('docDetail.diffusionVersionDate', {'version': '${diff['version']}', 'date': diff['createdAt'] != null ? '${diff['createdAt']}'.substring(0, 10) : '—'}), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ...recipients.map((r) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [
                      Expanded(child: Text('${r['label'] ?? userName(r['userId'])}', style: const TextStyle(fontSize: 12))),
                      Text(r['statutLecture'] == 'LU' ? t('docDetail.lu') : t('docDetail.nonLu'), style: TextStyle(fontSize: 11, color: r['statutLecture'] == 'LU' ? QhseColors.green : QhseColors.amber)),
                      if (r['statutLecture'] != 'LU') IconButton(icon: const Icon(Icons.check_circle_outline, size: 18), tooltip: t('docDetail.marquerLu'), onPressed: () => accuse(r['id'])),
                    ]))),
              ])));
            }),

          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(t('docDetail.fichierTitle'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            TextButton.icon(onPressed: busy ? null : newVersion, icon: const Icon(Icons.upload_file, size: 16), label: Text(t('docDetail.nouvelleVersionTitle'))),
          ]),
          Text(t('docDetail.nouvelleVersionNote'), style: TextStyle(color: QhseColors.textSecondary, fontSize: 11)),

          const SizedBox(height: 20),
          Text(t('docDetail.qrCodeTitle'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          Row(children: [
            Expanded(child: Text('${d['qrToken'] ?? '—'}', style: TextStyle(fontSize: 12, color: QhseColors.textSecondary), overflow: TextOverflow.ellipsis)),
            IconButton(icon: const Icon(Icons.copy, size: 18), tooltip: t('docDetail.copier'), onPressed: () {
              Clipboard.setData(ClipboardData(text: '${d['qrToken'] ?? ''}'));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('docDetail.jetonQrCopie'))));
            }),
            IconButton(icon: const Icon(Icons.refresh, size: 18), tooltip: t('docDetail.regenerer'), onPressed: busy ? null : regenerateQr),
          ]),

          if (links.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(t('docDetail.utilisePar'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ...links.map((l) => Card(child: ListTile(dense: true, title: Text('${l['sourceModule']}'), subtitle: Text('${l['relationType'] ?? t('docDetail.associe')}')))),
          ],

          const SizedBox(height: 20),
          CapaLinksSection(sourceModule: 'DOCUMENT', sourceEntityId: d['id'], prefill: {'title': t('docDetail.reviserPrefix', {'title': '${d['title'] ?? ''}'}), 'source': t('docDetail.sourceDocumentationGed')}),
        ]),
      ),
    );
  }
}

// --- Formulaire de création d'un document ---
class DocumentFormPage extends StatefulWidget {
  const DocumentFormPage({super.key});
  @override
  State<DocumentFormPage> createState() => _DocumentFormPageState();
}

class _DocumentFormPageState extends State<DocumentFormPage> {
  final api = Api();
  List types = [], categories = [], workUnits = [], users = [], groups = [];
  final title = TextEditingController();
  final description = TextEditingController();
  final category = TextEditingController();
  final documentType = TextEditingController();
  final domaine = TextEditingController();
  final service = TextEditingController();
  final activite = TextEditingController();
  final siteId = TextEditingController();
  final motifCreation = TextEditingController();
  final referencesReglementaires = TextEditingController();
  final referencesNormatives = TextEditingController();
  final motsCles = TextEditingController();
  final sourceOrganisme = TextEditingController();
  String? documentGroup, workUnitId, responsibleId, verificateurId, approbateurId;
  String frequenceRevision = 'ANNUELLE', criticite = 'NON_CRITIQUE';
  DateTime? dateEntreeVigueur;
  bool external = false, diffusionAccuseRequis = false, busy = false, loadingLists = true;
  String? error;
  String? pickedFileName;
  Uint8List? pickedFileBytes;

  @override
  void initState() { super.initState(); loadLists(); }

  Future<void> loadLists() async {
    try {
      types = List.from(await api.get('/documents/types'));
      categories = List.from(await api.get('/documents/categories'));
      workUnits = List.from(await api.get('/business/work-units'));
      users = List.from(await api.get('/users'));
      groups = List.from(await api.get('/documents/groups'));
    } catch (_) {}
    setState(() => loadingLists = false);
  }

  Future<void> pickDate() async {
    final d = await showDatePicker(context: context, initialDate: dateEntreeVigueur ?? DateTime.now(), firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 3650)));
    if (d != null) setState(() => dateEntreeVigueur = d);
  }

  Future<void> pickFile() async {
    final r = await FilePicker.platform.pickFiles(withData: true);
    if (r == null || r.files.single.bytes == null) return;
    setState(() { pickedFileName = r.files.single.name; pickedFileBytes = r.files.single.bytes; });
  }

  Future<void> submit() async {
    if (title.text.trim().isEmpty || category.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('docDetail.titreCategorieObligatoires'))));
      return;
    }
    setState(() { busy = true; error = null; });
    final payload = {
      'code': genCode('DOC'), 'title': title.text.trim(), 'category': category.text.trim(),
      'documentGroup': documentGroup,
      'description': description.text.trim().isEmpty ? null : description.text.trim(),
      'documentType': documentType.text.trim().isEmpty ? null : documentType.text.trim(),
      'domaine': domaine.text.trim().isEmpty ? null : domaine.text.trim(),
      'service': service.text.trim().isEmpty ? null : service.text.trim(),
      'activite': activite.text.trim().isEmpty ? null : activite.text.trim(),
      'siteId': siteId.text.trim().isEmpty ? null : siteId.text.trim(),
      'workUnitId': workUnitId, 'responsibleId': responsibleId, 'verificateurId': verificateurId, 'approbateurId': approbateurId,
      'dateEntreeVigueur': dateEntreeVigueur?.toIso8601String(), 'frequenceRevision': frequenceRevision, 'criticite': criticite,
      'motifCreation': motifCreation.text.trim().isEmpty ? null : motifCreation.text.trim(),
      'referencesReglementaires': referencesReglementaires.text.trim().isEmpty ? null : referencesReglementaires.text.trim(),
      'referencesNormatives': referencesNormatives.text.trim().isEmpty ? null : referencesNormatives.text.trim(),
      'motsCles': motsCles.text.trim().isEmpty ? null : motsCles.text.trim(),
      'external': external,
      'sourceOrganisme': external && sourceOrganisme.text.trim().isNotEmpty ? sourceOrganisme.text.trim() : null,
      'diffusionAccuseRequis': diffusionAccuseRequis,
      if (pickedFileName != null && pickedFileBytes != null) ...{
        'fileName': pickedFileName, 'mimeType': _mimeFromName(pickedFileName!), 'base64': base64Encode(pickedFileBytes!),
      },
    };
    try {
      await api.post('/documents', payload);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (e.networkError) {
        await SyncQueue.enqueue('document', 'CREATE', payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('docDetail.documentHorsLigne')), duration: const Duration(seconds: 4)));
          Navigator.pop(context, true);
        }
      } else {
        setState(() { busy = false; error = '$e'; });
        return;
      }
    } catch (e) {
      setState(() { busy = false; error = '$e'; });
      return;
    }
    setState(() => busy = false);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text(t('docDetail.nouveauDocumentTitle'))),
    body: loadingLists
        ? const Center(child: CircularProgressIndicator())
        : ListView(padding: const EdgeInsets.all(16), children: [
            TextField(controller: title, decoration: InputDecoration(labelText: t('docDetail.titre'))),
            const SizedBox(height: 12),
            TextField(controller: description, maxLines: 3, decoration: InputDecoration(labelText: t('docDetail.description'))),
            const SizedBox(height: 12),
            TextField(controller: category, decoration: InputDecoration(labelText: t('docDetail.categorie'))),
            if (categories.isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 6), child: Wrap(spacing: 6, children: categories.map<Widget>((cat) => ActionChip(
                    label: Text('${cat['name']}', style: const TextStyle(fontSize: 11)),
                    onPressed: () => setState(() => category.text = '${cat['name']}'),
                  )).toList())),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: documentGroup, isExpanded: true, decoration: InputDecoration(labelText: t('docDetail.groupeDocumentaire')),
              items: [const DropdownMenuItem<String>(value: null, child: Text('—')), ...groups.map<DropdownMenuItem<String>>((g) => DropdownMenuItem<String>(value: '$g', child: Text('$g')))],
              onChanged: (v) => setState(() => documentGroup = v),
            ),
            const SizedBox(height: 12),
            TextField(controller: documentType, decoration: InputDecoration(labelText: t('docDetail.typeDeDocument'))),
            if (types.isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 6), child: Wrap(spacing: 6, children: types.map<Widget>((t) => ActionChip(
                    label: Text('${t['name']}', style: const TextStyle(fontSize: 11)),
                    onPressed: () => setState(() => documentType.text = '${t['name']}'),
                  )).toList())),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: domaine, decoration: InputDecoration(labelText: t('docDetail.domaine')))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: service, decoration: InputDecoration(labelText: t('docDetail.service')))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: activite, decoration: InputDecoration(labelText: t('docDetail.activite')))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: siteId, decoration: InputDecoration(labelText: t('docDetail.site')))),
            ]),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: workUnitId, isExpanded: true, decoration: InputDecoration(labelText: t('docDetail.uniteDeTravail')),
              items: [const DropdownMenuItem<String>(value: null, child: Text('—')), ...workUnits.map<DropdownMenuItem<String>>((w) => DropdownMenuItem<String>(value: w['id'] as String, child: Text(w['name'] ?? '')))],
              onChanged: (v) => setState(() => workUnitId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: responsibleId, isExpanded: true, decoration: InputDecoration(labelText: t('docDetail.responsable')),
              items: [const DropdownMenuItem<String>(value: null, child: Text('—')), ...users.map<DropdownMenuItem<String>>((u) => DropdownMenuItem<String>(value: u['id'] as String, child: Text('${u['firstName']} ${u['lastName']}')))],
              onChanged: (v) => setState(() => responsibleId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: verificateurId, isExpanded: true, decoration: InputDecoration(labelText: t('docDetail.verificateur')),
              items: [const DropdownMenuItem<String>(value: null, child: Text('—')), ...users.map<DropdownMenuItem<String>>((u) => DropdownMenuItem<String>(value: u['id'] as String, child: Text('${u['firstName']} ${u['lastName']}')))],
              onChanged: (v) => setState(() => verificateurId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: approbateurId, isExpanded: true, decoration: InputDecoration(labelText: t('docDetail.approbateur')),
              items: [const DropdownMenuItem<String>(value: null, child: Text('—')), ...users.map<DropdownMenuItem<String>>((u) => DropdownMenuItem<String>(value: u['id'] as String, child: Text('${u['firstName']} ${u['lastName']}')))],
              onChanged: (v) => setState(() => approbateurId = v),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: pickDate, icon: const Icon(Icons.event), label: Text(dateEntreeVigueur != null ? t('docDetail.entreeVigueurDate', {'date': dateEntreeVigueur!.toIso8601String().substring(0, 10)}) : t('docDetail.dateEntreeVigueur'))),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: frequenceRevision, isExpanded: true, decoration: InputDecoration(labelText: t('docDetail.frequenceRevision')),
              items: _docFrequenceKeys.keys.map((k) => DropdownMenuItem(value: k, child: Text(_docFrequenceLabel(k)))).toList(),
              onChanged: (v) => setState(() => frequenceRevision = v ?? 'ANNUELLE'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: criticite, isExpanded: true, decoration: InputDecoration(labelText: t('docDetail.criticite')),
              items: _docCriticiteKeys.keys.map((k) => DropdownMenuItem(value: k, child: Text(_docCriticiteLabel(k)))).toList(),
              onChanged: (v) => setState(() => criticite = v ?? 'NON_CRITIQUE'),
            ),
            const SizedBox(height: 12),
            TextField(controller: motifCreation, maxLines: 2, decoration: InputDecoration(labelText: t('docDetail.motifCreation'))),
            const SizedBox(height: 12),
            TextField(controller: referencesReglementaires, maxLines: 2, decoration: InputDecoration(labelText: t('docDetail.referencesReglementaires'))),
            const SizedBox(height: 12),
            TextField(controller: referencesNormatives, maxLines: 2, decoration: InputDecoration(labelText: t('docDetail.referencesNormatives'))),
            const SizedBox(height: 12),
            TextField(controller: motsCles, decoration: InputDecoration(labelText: t('docDetail.motsCles'))),
            const SizedBox(height: 4),
            CheckboxListTile(contentPadding: EdgeInsets.zero, value: external, title: Text(t('docDetail.documentExterne'), style: const TextStyle(fontSize: 13)), onChanged: (v) => setState(() => external = v ?? false)),
            if (external) TextField(controller: sourceOrganisme, decoration: InputDecoration(labelText: t('docDetail.organismeSource'))),
            CheckboxListTile(contentPadding: EdgeInsets.zero, value: diffusionAccuseRequis, title: Text(t('docDetail.accuseRequisDiffusion'), style: const TextStyle(fontSize: 13)), onChanged: (v) => setState(() => diffusionAccuseRequis = v ?? false)),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: pickFile, icon: const Icon(Icons.attach_file), label: Text(pickedFileName ?? t('docDetail.joindreFichierOptionnel'))),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : submit, child: Text(busy ? t('docDetail.envoiEnCours') : t('docDetail.enregistrer')))),
          ]),
  );
}
