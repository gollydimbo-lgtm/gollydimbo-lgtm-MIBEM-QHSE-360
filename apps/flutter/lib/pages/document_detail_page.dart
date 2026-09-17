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

const _docStatusLabels = {
  'DRAFT': 'Brouillon',
  'REVIEW': 'En vérification',
  'APPROVED': 'En attente de publication',
  'ACTIVE': 'En vigueur',
  'SUPERSEDED': 'Obsolète — NE PAS UTILISER',
  'ARCHIVED': 'Archivé',
};

const _docCriticiteLabels = {'NON_CRITIQUE': 'Non critique', 'CRITIQUE': 'Critique'};

const _docFrequenceLabels = {
  'MENSUELLE': 'Mensuelle', 'TRIMESTRIELLE': 'Trimestrielle', 'SEMESTRIELLE': 'Semestrielle',
  'ANNUELLE': 'Annuelle', 'BIENNALE': 'Biennale', 'PERSONNALISEE': 'Personnalisée',
};

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
        content: TextField(controller: ctrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Commentaire (optionnel)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Confirmer')),
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
    final comment = await askComment(decision == 'APPROUVE' ? 'Valider la vérification' : 'Demander une modification');
    await doAction('/documents/${widget.documentId}/verify', {'decision': decision, if (comment != null) 'comment': comment});
  }

  Future<void> approve(String decision) async {
    final comment = await askComment(decision == 'APPROUVE' ? 'Approuver et publier' : 'Refuser');
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
        title: const Text('Nouvelle version'),
        content: TextField(controller: motif, decoration: const InputDecoration(labelText: 'Motif de modification (optionnel)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Envoyer')),
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
        title: const Text('Diffuser ce document'),
        content: SizedBox(width: 420, height: 360, child: users.isEmpty
            ? const Center(child: Text('Aucun utilisateur'))
            : ListView(children: users.map<Widget>((u) => CheckboxListTile(
                dense: true,
                value: selected.contains(u['id']),
                title: Text('${u['firstName']} ${u['lastName']}', style: const TextStyle(fontSize: 13)),
                onChanged: (v) => setD(() { if (v == true) selected.add(u['id']); else selected.remove(u['id']); }),
              )).toList())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          FilledButton(onPressed: selected.isEmpty ? null : () => Navigator.pop(c, true), child: const Text('Diffuser')),
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
        return [FilledButton.icon(onPressed: busy ? null : submit, icon: const Icon(Icons.send, size: 16), label: const Text('Soumettre pour vérification'))];
      case 'REVIEW':
        return [
          FilledButton.icon(onPressed: busy ? null : () => verify('APPROUVE'), icon: const Icon(Icons.check, size: 16), label: const Text('Vérifié — conforme')),
          OutlinedButton.icon(onPressed: busy ? null : () => verify('DEMANDE_MODIFICATION'), icon: const Icon(Icons.edit_note, size: 16), label: const Text('Demander une modification')),
        ];
      case 'APPROVED':
        return [
          FilledButton.icon(onPressed: busy ? null : () => approve('APPROUVE'), icon: const Icon(Icons.verified_outlined, size: 16), label: const Text('Approuver et publier')),
          OutlinedButton.icon(onPressed: busy ? null : () => approve('REFUSE'), icon: const Icon(Icons.close, size: 16), label: const Text('Refuser')),
        ];
      case 'ACTIVE':
        return [OutlinedButton.icon(onPressed: busy ? null : archive, icon: const Icon(Icons.archive_outlined, size: 16), label: const Text('Archiver'))];
      case 'ARCHIVED':
        return [OutlinedButton.icon(onPressed: busy ? null : reopen, icon: const Icon(Icons.unarchive_outlined, size: 16), label: const Text('Réactiver (retour en brouillon)'))];
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
    if (loading) return Scaffold(appBar: AppBar(title: const Text('Document')), body: const Center(child: CircularProgressIndicator()));
    if (error != null || doc == null) return Scaffold(appBar: AppBar(title: const Text('Document')), body: Center(child: Text(error ?? 'Introuvable')));
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
              Expanded(child: Text(_docStatusLabels[status] ?? status ?? '—', style: TextStyle(color: statusColor, fontWeight: FontWeight.bold))),
            ]),
          ),
          const SizedBox(height: 12),
          Text('${d['title']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          if (d['description'] != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${d['description']}')),
          const SizedBox(height: 12),
          _metaRow('Type', d['documentType']),
          _metaRow('Catégorie', d['category']),
          _metaRow('Domaine / Service', [d['domaine'], d['service']].where((x) => x != null && '$x'.isNotEmpty).join(' / ')),
          _metaRow('Site', d['siteId']),
          _metaRow('Version courante', 'v${d['currentVersion']}'),
          _metaRow('Criticité', _docCriticiteLabels[d['criticite']] ?? d['criticite']),
          _metaRow('Fréquence de révision', _docFrequenceLabels[d['frequenceRevision']] ?? d['frequenceRevision']),
          _metaRow('Responsable', userName(d['responsibleId'])),
          _metaRow('Vérificateur', userName(d['verificateurId'])),
          _metaRow('Approbateur', userName(d['approbateurId'])),
          _metaRow('Entrée en vigueur', d['dateEntreeVigueur'] != null ? '${d['dateEntreeVigueur']}'.substring(0, 10) : '—'),
          _metaRow('Prochaine révision', d['nextReviewAt'] != null ? '${d['nextReviewAt']}'.substring(0, 10) : '—'),
          if (d['external'] == true) _metaRow('Organisme source (externe)', d['sourceOrganisme']),

          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: _actionButtons(status)),

          const SizedBox(height: 20),
          const Text('Historique des approbations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          if (approvals.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('Aucune décision enregistrée', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
          else
            ...approvals.map((a) => Card(child: ListTile(
                  dense: true,
                  title: Text('${a['role'] ?? ''} — ${a['decision'] ?? ''}'),
                  subtitle: Text('${a['comment'] ?? ''}${a['createdAt'] != null ? ' · ${'${a['createdAt']}'.substring(0, 10)}' : ''}'),
                ))),

          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Diffusion', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            TextButton.icon(onPressed: busy ? null : diffuse, icon: const Icon(Icons.send, size: 16), label: const Text('Diffuser')),
          ]),
          if (diffusions.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('Aucune diffusion', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
          else
            ...diffusions.map((diff) {
              final recipients = List.from(diff['recipients'] ?? []);
              return Card(child: Padding(padding: const EdgeInsets.all(8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Diffusion v${diff['version']} — ${diff['createdAt'] != null ? '${diff['createdAt']}'.substring(0, 10) : '—'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ...recipients.map((r) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [
                      Expanded(child: Text('${r['label'] ?? userName(r['userId'])}', style: const TextStyle(fontSize: 12))),
                      Text(r['statutLecture'] == 'LU' ? 'Lu' : 'Non lu', style: TextStyle(fontSize: 11, color: r['statutLecture'] == 'LU' ? QhseColors.green : QhseColors.amber)),
                      if (r['statutLecture'] != 'LU') IconButton(icon: const Icon(Icons.check_circle_outline, size: 18), tooltip: 'Marquer lu', onPressed: () => accuse(r['id'])),
                    ]))),
              ])));
            }),

          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Fichier', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            TextButton.icon(onPressed: busy ? null : newVersion, icon: const Icon(Icons.upload_file, size: 16), label: const Text('Nouvelle version')),
          ]),
          Text('Toute nouvelle version repasse le document en brouillon (nouveau circuit de validation).', style: TextStyle(color: QhseColors.textSecondary, fontSize: 11)),

          const SizedBox(height: 20),
          const Text('QR code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          Row(children: [
            Expanded(child: Text('${d['qrToken'] ?? '—'}', style: TextStyle(fontSize: 12, color: QhseColors.textSecondary), overflow: TextOverflow.ellipsis)),
            IconButton(icon: const Icon(Icons.copy, size: 18), tooltip: 'Copier', onPressed: () {
              Clipboard.setData(ClipboardData(text: '${d['qrToken'] ?? ''}'));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Jeton QR copié')));
            }),
            IconButton(icon: const Icon(Icons.refresh, size: 18), tooltip: 'Régénérer', onPressed: busy ? null : regenerateQr),
          ]),

          if (links.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Utilisé par', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ...links.map((l) => Card(child: ListTile(dense: true, title: Text('${l['sourceModule']}'), subtitle: Text('${l['relationType'] ?? 'ASSOCIE'}')))),
          ],

          const SizedBox(height: 20),
          CapaLinksSection(sourceModule: 'DOCUMENT', sourceEntityId: d['id'], prefill: {'title': 'Réviser — ${d['title'] ?? ''}', 'source': 'Documentation GED'}),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le titre et la catégorie sont obligatoires')));
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pas de réseau : document enregistré hors-ligne, il sera synchronisé automatiquement.'), duration: Duration(seconds: 4)));
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
    appBar: AppBar(title: const Text('Nouveau document')),
    body: loadingLists
        ? const Center(child: CircularProgressIndicator())
        : ListView(padding: const EdgeInsets.all(16), children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Titre *')),
            const SizedBox(height: 12),
            TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
            const SizedBox(height: 12),
            TextField(controller: category, decoration: const InputDecoration(labelText: 'Catégorie *')),
            if (categories.isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 6), child: Wrap(spacing: 6, children: categories.map<Widget>((cat) => ActionChip(
                    label: Text('${cat['name']}', style: const TextStyle(fontSize: 11)),
                    onPressed: () => setState(() => category.text = '${cat['name']}'),
                  )).toList())),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: documentGroup, isExpanded: true, decoration: const InputDecoration(labelText: 'Groupe documentaire'),
              items: [const DropdownMenuItem<String>(value: null, child: Text('—')), ...groups.map<DropdownMenuItem<String>>((g) => DropdownMenuItem<String>(value: '$g', child: Text('$g')))],
              onChanged: (v) => setState(() => documentGroup = v),
            ),
            const SizedBox(height: 12),
            TextField(controller: documentType, decoration: const InputDecoration(labelText: 'Type de document')),
            if (types.isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 6), child: Wrap(spacing: 6, children: types.map<Widget>((t) => ActionChip(
                    label: Text('${t['name']}', style: const TextStyle(fontSize: 11)),
                    onPressed: () => setState(() => documentType.text = '${t['name']}'),
                  )).toList())),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: domaine, decoration: const InputDecoration(labelText: 'Domaine'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: service, decoration: const InputDecoration(labelText: 'Service'))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: activite, decoration: const InputDecoration(labelText: 'Activité'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: siteId, decoration: const InputDecoration(labelText: 'Site'))),
            ]),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: workUnitId, isExpanded: true, decoration: const InputDecoration(labelText: 'Unité de travail'),
              items: [const DropdownMenuItem<String>(value: null, child: Text('—')), ...workUnits.map<DropdownMenuItem<String>>((w) => DropdownMenuItem<String>(value: w['id'] as String, child: Text(w['name'] ?? '')))],
              onChanged: (v) => setState(() => workUnitId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: responsibleId, isExpanded: true, decoration: const InputDecoration(labelText: 'Responsable'),
              items: [const DropdownMenuItem<String>(value: null, child: Text('—')), ...users.map<DropdownMenuItem<String>>((u) => DropdownMenuItem<String>(value: u['id'] as String, child: Text('${u['firstName']} ${u['lastName']}')))],
              onChanged: (v) => setState(() => responsibleId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: verificateurId, isExpanded: true, decoration: const InputDecoration(labelText: 'Vérificateur'),
              items: [const DropdownMenuItem<String>(value: null, child: Text('—')), ...users.map<DropdownMenuItem<String>>((u) => DropdownMenuItem<String>(value: u['id'] as String, child: Text('${u['firstName']} ${u['lastName']}')))],
              onChanged: (v) => setState(() => verificateurId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: approbateurId, isExpanded: true, decoration: const InputDecoration(labelText: 'Approbateur'),
              items: [const DropdownMenuItem<String>(value: null, child: Text('—')), ...users.map<DropdownMenuItem<String>>((u) => DropdownMenuItem<String>(value: u['id'] as String, child: Text('${u['firstName']} ${u['lastName']}')))],
              onChanged: (v) => setState(() => approbateurId = v),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: pickDate, icon: const Icon(Icons.event), label: Text(dateEntreeVigueur != null ? "Entrée en vigueur : ${dateEntreeVigueur!.toIso8601String().substring(0, 10)}" : "Date d'entrée en vigueur")),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: frequenceRevision, isExpanded: true, decoration: const InputDecoration(labelText: 'Fréquence de révision'),
              items: _docFrequenceLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
              onChanged: (v) => setState(() => frequenceRevision = v ?? 'ANNUELLE'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: criticite, isExpanded: true, decoration: const InputDecoration(labelText: 'Criticité'),
              items: _docCriticiteLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
              onChanged: (v) => setState(() => criticite = v ?? 'NON_CRITIQUE'),
            ),
            const SizedBox(height: 12),
            TextField(controller: motifCreation, maxLines: 2, decoration: const InputDecoration(labelText: 'Motif de création')),
            const SizedBox(height: 12),
            TextField(controller: referencesReglementaires, maxLines: 2, decoration: const InputDecoration(labelText: 'Références réglementaires')),
            const SizedBox(height: 12),
            TextField(controller: referencesNormatives, maxLines: 2, decoration: const InputDecoration(labelText: 'Références normatives')),
            const SizedBox(height: 12),
            TextField(controller: motsCles, decoration: const InputDecoration(labelText: 'Mots-clés')),
            const SizedBox(height: 4),
            CheckboxListTile(contentPadding: EdgeInsets.zero, value: external, title: const Text('Document externe', style: TextStyle(fontSize: 13)), onChanged: (v) => setState(() => external = v ?? false)),
            if (external) TextField(controller: sourceOrganisme, decoration: const InputDecoration(labelText: 'Organisme source')),
            CheckboxListTile(contentPadding: EdgeInsets.zero, value: diffusionAccuseRequis, title: const Text('Accusé de lecture requis à la diffusion', style: TextStyle(fontSize: 13)), onChanged: (v) => setState(() => diffusionAccuseRequis = v ?? false)),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: pickFile, icon: const Icon(Icons.attach_file), label: Text(pickedFileName ?? 'Joindre un fichier (optionnel)')),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : submit, child: Text(busy ? 'Envoi...' : 'Enregistrer'))),
          ]),
  );
}
