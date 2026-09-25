import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/api.dart';
import '../theme.dart';
import '../i18n/i18n.dart';

// ---------------------------------------------------------------------------
// Constantes portées depuis apps/web (RAPPORT_DOMAINES, RAPPORT_FAMILLE_LABELS)
// ---------------------------------------------------------------------------

const List<String> rapportDomaineValues = ['QUALITE', 'SECURITE', 'ENVIRONNEMENT'];

String rapportDomaineLabel(String v) => t('rapports.domaine.$v');

const List<String> rapportFamilleValues = [
  'NC',
  'CAPA',
  'AUDIT',
  'RISQUE',
  'INCIDENT',
  'FORMATION',
  'DECHET',
  'CONSOMMATION',
  'REGLEMENTAIRE',
];

String rapportFamilleLabel(String famille) => rapportFamilleValues.contains(famille)
    ? t('rapports.famille.$famille')
    : famille;

const List<String> rapportStatutValues = ['BROUILLON', 'EN_REVUE', 'VALIDE', 'DISTRIBUE'];

String rapportStatutLabel(String? statut) =>
    statut != null && rapportStatutValues.contains(statut)
        ? t('rapports.statut.$statut')
        : (statut ?? '');

Color rapportStatutColor(String? statut) {
  switch (statut) {
    case 'VALIDE':
      return QhseColors.green;
    case 'DISTRIBUE':
      return QhseColors.blue;
    case 'EN_REVUE':
      return QhseColors.amber;
    default:
      return QhseColors.textSecondary;
  }
}

String rapportGetSection(String famille) {
  const map = {
    'NC': 'QUALITE',
    'CAPA': 'QUALITE',
    'AUDIT': 'QUALITE',
    'RISQUE': 'SECURITE',
    'INCIDENT': 'SECURITE',
    'FORMATION': 'SECURITE',
    'DECHET': 'ENVIRONNEMENT',
    'CONSOMMATION': 'ENVIRONNEMENT',
    'REGLEMENTAIRE': 'ENVIRONNEMENT',
  };
  return map[famille] ?? 'QUALITE';
}

String fileUrlFor(String baseUrl, String path) {
  if (path.startsWith('http')) return path;
  final origin = baseUrl.replaceAll(RegExp(r'/api/v4/?$'), '');
  return '$origin$path';
}

// ---------------------------------------------------------------------------
// Page racine : 2 onglets (Rapports QHSE / Export rapide)
// ---------------------------------------------------------------------------

class RapportsPage extends StatelessWidget {
  const RapportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('rapports.appBarTitle')),
          bottom: TabBar(tabs: [
            Tab(text: t('rapports.tabQhse')),
            Tab(text: t('rapports.tabExport')),
            Tab(text: t('rapports.tabIdentity')),
          ]),
        ),
        body: const TabBarView(children: [
          _RapportsQhseTab(),
          _ExportRapideTab(),
          _CompanyIdentityTab(),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Onglet "Rapports QHSE" : liste + création
// ---------------------------------------------------------------------------

class _RapportsQhseTab extends StatefulWidget {
  const _RapportsQhseTab();

  @override
  State<_RapportsQhseTab> createState() => _RapportsQhseTabState();
}

class _RapportsQhseTabState extends State<_RapportsQhseTab> {
  final api = Api();
  List rapports = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await api.get('/business/rapports');
      setState(() {
        rapports = List.from(data);
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> openCreation() async {
    final created = await showDialog(
      context: context,
      builder: (_) => const _RapportCreationDialog(),
    );
    if (created == true) {
      load();
    }
  }

  Future<void> openDetail(Map r) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RapportDetailPage(rapportId: r['id'].toString()),
    ));
    load();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return Center(child: Text(t('rapports.error', {'error': '$error'})));
    }
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: openCreation,
        icon: const Icon(Icons.add),
        label: Text(t('rapports.newReport')),
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: rapports.isEmpty
            ? ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(child: Text(t('rapports.emptyState'))),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: rapports.length,
                itemBuilder: (context, i) {
                  final r = rapports[i];
                  final statut = r['statut']?.toString();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(r['titre']?.toString() ?? t('rapports.untitledReport')),
                      subtitle: Text(
                        '${r['mode'] ?? ''} · ${r['from'] ?? ''} → ${r['to'] ?? ''}',
                      ),
                      trailing: Chip(
                        label: Text(
                          rapportStatutLabel(statut),
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        backgroundColor: rapportStatutColor(statut),
                      ),
                      onTap: () => openDetail(r),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Boîte de dialogue de création (RapportCreationForm)
// ---------------------------------------------------------------------------

class _RapportCreationDialog extends StatefulWidget {
  const _RapportCreationDialog();

  @override
  State<_RapportCreationDialog> createState() => _RapportCreationDialogState();
}

class _RapportCreationDialogState extends State<_RapportCreationDialog> {
  final api = Api();
  final titreCtrl = TextEditingController();
  DateTime? from;
  DateTime? to;
  String mode = 'COMPLET';
  String? domaineThematique;
  String confidentialite = 'INTERNE';
  bool saving = false;
  String? error;

  Future<void> pickDate(bool isFrom) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          from = picked;
        } else {
          to = picked;
        }
      });
    }
  }

  Future<void> create() async {
    if (titreCtrl.text.trim().isEmpty || from == null || to == null) {
      setState(() => error = t('rapports.dialog.validationRequired'));
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final body = {
        'titre': titreCtrl.text.trim(),
        'from': from!.toIso8601String().substring(0, 10),
        'to': to!.toIso8601String().substring(0, 10),
        'mode': mode,
        'confidentialite': confidentialite,
        if (mode == 'THEMATIQUE' && domaineThematique != null)
          'domaineThematique': domaineThematique,
      };
      await api.post('/business/rapports', body);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        error = e.toString();
        saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(t('rapports.dialog.newReportTitle')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: titreCtrl,
              decoration: InputDecoration(labelText: t('rapports.dialog.titreField')),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => pickDate(true),
                    child: Text(from == null
                        ? t('rapports.dialog.dateDebut')
                        : from!.toIso8601String().substring(0, 10)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => pickDate(false),
                    child: Text(to == null
                        ? t('rapports.dialog.dateFin')
                        : to!.toIso8601String().substring(0, 10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: mode,
              decoration: InputDecoration(labelText: t('rapports.dialog.mode')),
              items: [
                DropdownMenuItem(value: 'COMPLET', child: Text(t('rapports.dialog.modeComplet'))),
                DropdownMenuItem(value: 'SYNTHESE', child: Text(t('rapports.dialog.modeSynthese'))),
                DropdownMenuItem(value: 'THEMATIQUE', child: Text(t('rapports.dialog.modeThematique'))),
              ],
              onChanged: (v) => setState(() => mode = v ?? 'COMPLET'),
            ),
            if (mode == 'THEMATIQUE') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: domaineThematique,
                decoration: InputDecoration(labelText: t('rapports.dialog.domaine')),
                items: rapportDomaineValues
                    .map((v) => DropdownMenuItem(
                          value: v,
                          child: Text(rapportDomaineLabel(v)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => domaineThematique = v),
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: confidentialite,
              decoration: InputDecoration(labelText: t('rapports.dialog.confidentialite')),
              items: [
                DropdownMenuItem(value: 'PUBLIC', child: Text(t('rapports.dialog.confidentialitePublic'))),
                DropdownMenuItem(value: 'INTERNE', child: Text(t('rapports.dialog.confidentialiteInterne'))),
                DropdownMenuItem(value: 'CONFIDENTIEL', child: Text(t('rapports.dialog.confidentialiteConfidentiel'))),
              ],
              onChanged: (v) => setState(() => confidentialite = v ?? 'INTERNE'),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.of(context).pop(false),
          child: Text(t('rapports.dialog.cancel')),
        ),
        FilledButton(
          onPressed: saving ? null : create,
          child: saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(t('rapports.dialog.create')),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Page détail / édition (RapportEditorPanel)
// ---------------------------------------------------------------------------

class RapportDetailPage extends StatefulWidget {
  final String rapportId;
  const RapportDetailPage({super.key, required this.rapportId});

  @override
  State<RapportDetailPage> createState() => _RapportDetailPageState();
}

class _RapportDetailPageState extends State<RapportDetailPage> {
  final api = Api();
  Map? rapport;
  bool loading = true;
  bool saving = false;
  String? error;
  final resumeCtrl = TextEditingController();
  final Map<String, TextEditingController> sectionCtrls = {};

  bool get verrouille =>
      rapport != null &&
      (rapport!['statut'] == 'VALIDE' || rapport!['statut'] == 'DISTRIBUE');

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    resumeCtrl.dispose();
    for (final c in sectionCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await api.get('/business/rapports/${widget.rapportId}');
      setState(() {
        rapport = Map.from(data);
        resumeCtrl.text = rapport!['resumeExecutif']?.toString() ?? '';
        final sections = rapport!['sections'];
        if (sections is Map) {
          sections.forEach((k, v) {
            sectionCtrls[k] = TextEditingController(text: v?.toString() ?? '');
          });
        }
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> save() async {
    setState(() => saving = true);
    try {
      final sections = <String, String>{};
      sectionCtrls.forEach((k, c) => sections[k] = c.text);
      await api.patch('/business/rapports/${widget.rapportId}', {
        'resumeExecutif': resumeCtrl.text,
        'sections': sections,
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t('rapports.detail.saved'))));
      }
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t('rapports.error', {'error': '$e'}))));
      }
    } finally {
      setState(() => saving = false);
    }
  }

  Future<void> valider() async {
    final ctrl = TextEditingController();
    final nom = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t('rapports.detail.validerTitle')),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(labelText: t('rapports.detail.validateurField')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t('rapports.dialog.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
            child: Text(t('rapports.detail.valider')),
          ),
        ],
      ),
    );
    if (nom == null || nom.isEmpty) return;
    try {
      await api.post('/business/rapports/${widget.rapportId}/valider', {'validePar': nom});
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t('rapports.error', {'error': '$e'}))));
      }
    }
  }

  Future<void> distribuer() async {
    final emailCtrl = TextEditingController();
    final parCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t('rapports.detail.distribuerTitle')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailCtrl,
              decoration: InputDecoration(labelText: t('rapports.detail.emailDestinataires')),
            ),
            TextField(
              controller: parCtrl,
              decoration: InputDecoration(labelText: t('rapports.detail.distribuePar')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t('rapports.dialog.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t('rapports.detail.distribuer')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.post('/business/rapports/${widget.rapportId}/distribuer', {
        'email': emailCtrl.text.trim(),
        'distribuePar': parCtrl.text.trim(),
      });
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t('rapports.error', {'error': '$e'}))));
      }
    }
  }

  Future<void> nouvelleVersion() async {
    try {
      final res = await api.post('/business/rapports/${widget.rapportId}/revision', {});
      if (mounted && res is Map && res['id'] != null) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => RapportDetailPage(rapportId: res['id'].toString()),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t('rapports.error', {'error': '$e'}))));
      }
    }
  }

  Future<void> telechargerPdf() async {
    try {
      final res = await api.post('/business/rapports/${widget.rapportId}/pdf', {});
      if (res is Map && res['url'] != null) {
        final base = await Api.currentBaseUrl();
        final url = fileUrlFor(base, res['url'].toString());
        final uri = Uri.parse(url);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t('rapports.error', {'error': '$e'}))));
      }
    }
  }

  Future<void> archiverGed() async {
    try {
      await api.post('/business/rapports/${widget.rapportId}/archiver-ged', {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('rapports.detail.archivedInGed'))),
        );
      }
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t('rapports.error', {'error': '$e'}))));
      }
    }
  }

  Widget buildDomainSection(String famille, dynamic content) {
    final ctrl = sectionCtrls.putIfAbsent(
      famille,
      () => TextEditingController(text: content?.toString() ?? ''),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rapportFamilleLabel(famille),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            maxLines: 6,
            enabled: !verrouille,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (error != null || rapport == null) {
      return Scaffold(body: Center(child: Text(t('rapports.error', {'error': '$error'}))));
    }
    final r = rapport!;
    final statut = r['statut']?.toString();
    final sections = r['sections'] is Map ? Map.from(r['sections']) : {};

    return Scaffold(
      appBar: AppBar(
        title: Text(r['titre']?.toString() ?? t('rapports.detail.defaultTitle')),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Chip(
                label: Text(
                  rapportStatutLabel(statut),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                backgroundColor: rapportStatutColor(statut),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('rapports.detail.periode', {'from': '${r['from'] ?? ''}', 'to': '${r['to'] ?? ''}'})),
                  Text(t('rapports.detail.mode', {'mode': '${r['mode'] ?? ''}'})),
                  if (r['domaineThematique'] != null)
                    Text(t('rapports.detail.domaine', {'domaine': '${r['domaineThematique']}'})),
                  Text(t('rapports.detail.confidentialite', {'confidentialite': '${r['confidentialite'] ?? ''}'})),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(t('rapports.detail.resumeExecutif'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          TextField(
            controller: resumeCtrl,
            maxLines: 5,
            enabled: !verrouille,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 20),
          Text(t('rapports.detail.sectionsThematiques'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ...sections.entries.map((e) => buildDomainSection(e.key, e.value)),
          if (r['journalDistribution'] is List &&
              (r['journalDistribution'] as List).isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(t('rapports.detail.journalDistribution'), style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            ...List.from(r['journalDistribution']).map((j) => Text(
                  t('rapports.detail.journalEntry', {
                    'date': '${j['date'] ?? ''}',
                    'email': '${j['email'] ?? ''}',
                    'par': '${j['distribuePar'] ?? ''}',
                  }),
                )),
          ],
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!verrouille)
                FilledButton.icon(
                  onPressed: saving ? null : save,
                  icon: const Icon(Icons.save),
                  label: Text(t('rapports.detail.enregistrer')),
                ),
              if (statut == 'BROUILLON' || statut == 'EN_REVUE')
                OutlinedButton.icon(
                  onPressed: valider,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(t('rapports.detail.valider')),
                ),
              if (statut == 'VALIDE')
                OutlinedButton.icon(
                  onPressed: distribuer,
                  icon: const Icon(Icons.send),
                  label: Text(t('rapports.detail.distribuer')),
                ),
              OutlinedButton.icon(
                onPressed: telechargerPdf,
                icon: const Icon(Icons.picture_as_pdf),
                label: Text(t('rapports.detail.telechargerPdf')),
              ),
              if (statut == 'VALIDE' || statut == 'DISTRIBUE')
                OutlinedButton.icon(
                  onPressed: archiverGed,
                  icon: const Icon(Icons.archive_outlined),
                  label: Text(t('rapports.detail.archiverGed')),
                ),
              if (verrouille)
                OutlinedButton.icon(
                  onPressed: nouvelleVersion,
                  icon: const Icon(Icons.difference_outlined),
                  label: Text(t('rapports.detail.nouvelleVersion')),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Onglet "Export rapide" (ancienne fonctionnalité CSV, conservée)
// ---------------------------------------------------------------------------

class _ReportSpec {
  final String id;
  final String titre;
  final String endpoint;
  final List<String> colonnes;
  const _ReportSpec({
    required this.id,
    required this.titre,
    required this.endpoint,
    required this.colonnes,
  });
}

String reportSpecLabel(String id) => t('rapports.export.spec.$id');

const List<_ReportSpec> _reports = [
  _ReportSpec(
    id: 'nc',
    titre: 'Non-conformités',
    endpoint: '/business/non-conformites',
    colonnes: ['id', 'titre', 'statut', 'processus', 'dateCreation'],
  ),
  _ReportSpec(
    id: 'capa',
    titre: 'Actions correctives/préventives',
    endpoint: '/business/actions',
    colonnes: ['id', 'titre', 'statut', 'responsable', 'echeance'],
  ),
  _ReportSpec(
    id: 'audits',
    titre: 'Audits',
    endpoint: '/business/audits',
    colonnes: ['id', 'titre', 'type', 'statut', 'date'],
  ),
  _ReportSpec(
    id: 'risques',
    titre: 'Risques',
    endpoint: '/business/risks',
    colonnes: ['id', 'titre', 'niveau', 'statut'],
  ),
  _ReportSpec(
    id: 'incidents',
    titre: 'Incidents/Accidents',
    endpoint: '/business/safety-events',
    colonnes: ['id', 'type', 'gravite', 'date'],
  ),
  _ReportSpec(
    id: 'formations',
    titre: 'Formations',
    endpoint: '/business/trainings',
    colonnes: ['id', 'titre', 'date', 'statut'],
  ),
];

class _ExportRapideTab extends StatefulWidget {
  const _ExportRapideTab();

  @override
  State<_ExportRapideTab> createState() => _ExportRapideTabState();
}

class _ExportRapideTabState extends State<_ExportRapideTab> {
  final api = Api();
  bool generating = false;
  String? generatingId;

  Future<void> _generate(_ReportSpec spec) async {
    setState(() {
      generating = true;
      generatingId = spec.id;
    });
    try {
      final data = await api.get(spec.endpoint);
      final list = List.from(data);
      final buffer = StringBuffer();
      buffer.write('﻿');
      buffer.writeln(spec.colonnes.join(';'));
      for (final item in list) {
        final row = spec.colonnes.map((c) {
          final v = item is Map ? item[c] : null;
          final s = (v ?? '').toString().replaceAll('"', '""');
          return '"$s"';
        }).join(';');
        buffer.writeln(row);
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${spec.id}_export.csv');
      await file.writeAsString(buffer.toString());
      await Share.shareXFiles([XFile(file.path)], text: reportSpecLabel(spec.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t('rapports.error', {'error': '$e'}))));
      }
    } finally {
      if (mounted) {
        setState(() {
          generating = false;
          generatingId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _reports.length,
      itemBuilder: (context, i) {
        final spec = _reports[i];
        final isLoading = generating && generatingId == spec.id;
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            title: Text(reportSpecLabel(spec.id)),
            subtitle: Text(t('rapports.export.csvLocal')),
            trailing: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    icon: const Icon(Icons.download),
                    onPressed: generating ? null : () => _generate(spec),
                  ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Onglet "Identité entreprise" (RapportsIdentitePanel) — réutilisée sur la
// page de garde et l'en-tête des rapports générés (PDF/GED).
// ---------------------------------------------------------------------------

class _CompanyIdentityTab extends StatefulWidget {
  const _CompanyIdentityTab();

  @override
  State<_CompanyIdentityTab> createState() => _CompanyIdentityTabState();
}

class _CompanyIdentityTabState extends State<_CompanyIdentityTab> {
  final api = Api();
  Map? identity;
  bool loading = true;
  bool saving = false;
  String? error;

  final nomOfficielCtrl = TextEditingController();
  final nomCommercialCtrl = TextEditingController();
  final sigleCtrl = TextEditingController();
  final sloganCtrl = TextEditingController();
  final adresseCtrl = TextEditingController();
  final paysCtrl = TextEditingController();
  final telephoneCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final siteInternetCtrl = TextEditingController();
  String? logoUrl;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    nomOfficielCtrl.dispose();
    nomCommercialCtrl.dispose();
    sigleCtrl.dispose();
    sloganCtrl.dispose();
    adresseCtrl.dispose();
    paysCtrl.dispose();
    telephoneCtrl.dispose();
    emailCtrl.dispose();
    siteInternetCtrl.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await api.get('/business/company-identity');
      identity = Map.from(data);
      nomOfficielCtrl.text = identity!['nomOfficiel']?.toString() ?? '';
      nomCommercialCtrl.text = identity!['nomCommercial']?.toString() ?? '';
      sigleCtrl.text = identity!['sigle']?.toString() ?? '';
      sloganCtrl.text = identity!['slogan']?.toString() ?? '';
      adresseCtrl.text = identity!['adresse']?.toString() ?? '';
      paysCtrl.text = identity!['pays']?.toString() ?? '';
      telephoneCtrl.text = identity!['telephone']?.toString() ?? '';
      emailCtrl.text = identity!['email']?.toString() ?? '';
      siteInternetCtrl.text = identity!['siteInternet']?.toString() ?? '';
      logoUrl = identity!['logoUrl']?.toString();
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> pickLogo() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final ext = picked.name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
      final b64 = base64Encode(bytes);
      setState(() => logoUrl = 'data:image/$ext;base64,$b64');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('rapports.identity.logoError', {'error': '$e'}))));
    }
  }

  Future<void> save() async {
    setState(() => saving = true);
    try {
      await api.patch('/business/company-identity', {
        'nomOfficiel': nomOfficielCtrl.text.trim(),
        'nomCommercial': nomCommercialCtrl.text.trim(),
        'sigle': sigleCtrl.text.trim(),
        'slogan': sloganCtrl.text.trim(),
        'adresse': adresseCtrl.text.trim(),
        'pays': paysCtrl.text.trim(),
        'telephone': telephoneCtrl.text.trim(),
        'email': emailCtrl.text.trim(),
        'siteInternet': siteInternetCtrl.text.trim(),
        if (logoUrl != null) 'logoUrl': logoUrl,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('rapports.identity.saved'))));
      }
      await load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('rapports.error', {'error': '$e'}))));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget _field(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return Center(child: Text(t('rapports.error', {'error': '$error'})));
    ImageProvider? preview;
    if (logoUrl != null && logoUrl!.startsWith('data:')) {
      try {
        final b64 = logoUrl!.split(',').last;
        preview = MemoryImage(base64Decode(b64));
      } catch (_) {}
    } else if (logoUrl != null && logoUrl!.isNotEmpty) {
      preview = NetworkImage(logoUrl!);
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          t('rapports.identity.title'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(
          t('rapports.identity.subtitle'),
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        _field(t('rapports.identity.nomOfficiel'), nomOfficielCtrl),
        _field(t('rapports.identity.nomCommercial'), nomCommercialCtrl),
        _field(t('rapports.identity.sigle'), sigleCtrl),
        _field(t('rapports.identity.slogan'), sloganCtrl),
        _field(t('rapports.identity.adresse'), adresseCtrl),
        _field(t('rapports.identity.pays'), paysCtrl),
        _field(t('rapports.identity.telephone'), telephoneCtrl),
        _field(t('rapports.identity.email'), emailCtrl),
        _field(t('rapports.identity.siteInternet'), siteInternetCtrl),
        Text(t('rapports.identity.logo'), style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(children: [
          if (preview != null)
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
              child: Image(image: preview, fit: BoxFit.contain),
            ),
          if (preview != null) const SizedBox(width: 12),
          OutlinedButton.icon(onPressed: pickLogo, icon: const Icon(Icons.image_outlined), label: Text(t('rapports.identity.chooseLogo'))),
        ]),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: saving ? null : save,
          child: saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(t('rapports.detail.enregistrer')),
        ),
      ],
    );
  }
}
