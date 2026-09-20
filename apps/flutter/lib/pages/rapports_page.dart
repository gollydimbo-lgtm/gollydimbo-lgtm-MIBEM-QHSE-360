import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import '../services/api.dart';
import '../theme.dart';

// ---------------------------------------------------------------------------
// Constantes portées depuis apps/web (RAPPORT_DOMAINES, RAPPORT_FAMILLE_LABELS)
// ---------------------------------------------------------------------------

const List<Map<String, String>> rapportDomaines = [
  {'value': 'QUALITE', 'label': 'Qualité'},
  {'value': 'SECURITE', 'label': 'Sécurité'},
  {'value': 'ENVIRONNEMENT', 'label': 'Environnement'},
];

const Map<String, String> rapportFamilleLabels = {
  'NC': 'Non-conformités',
  'CAPA': 'Actions correctives/préventives',
  'AUDIT': 'Audits',
  'RISQUE': 'Risques',
  'INCIDENT': 'Incidents/Accidents',
  'FORMATION': 'Formations',
  'DECHET': 'Déchets',
  'CONSOMMATION': 'Consommations',
  'REGLEMENTAIRE': 'Conformité réglementaire',
};

const Map<String, String> rapportStatutLabels = {
  'BROUILLON': 'Brouillon',
  'EN_REVUE': 'En revue',
  'VALIDE': 'Validé',
  'DISTRIBUE': 'Distribué',
};

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
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Rapports'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Rapports QHSE'),
            Tab(text: 'Export rapide'),
          ]),
        ),
        body: const TabBarView(children: [
          _RapportsQhseTab(),
          _ExportRapideTab(),
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
      return Center(child: Text('Erreur : $error'));
    }
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: openCreation,
        icon: const Icon(Icons.add),
        label: const Text('Nouveau rapport'),
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: rapports.isEmpty
            ? ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('Aucun rapport pour le moment.')),
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
                      title: Text(r['titre']?.toString() ?? 'Rapport sans titre'),
                      subtitle: Text(
                        '${r['mode'] ?? ''} · ${r['from'] ?? ''} → ${r['to'] ?? ''}',
                      ),
                      trailing: Chip(
                        label: Text(
                          rapportStatutLabels[statut] ?? statut ?? '',
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
      setState(() => error = 'Titre, date de début et date de fin sont requis.');
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
      title: const Text('Nouveau rapport'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: titreCtrl,
              decoration: const InputDecoration(labelText: 'Titre'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => pickDate(true),
                    child: Text(from == null
                        ? 'Date début'
                        : from!.toIso8601String().substring(0, 10)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => pickDate(false),
                    child: Text(to == null
                        ? 'Date fin'
                        : to!.toIso8601String().substring(0, 10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: mode,
              decoration: const InputDecoration(labelText: 'Mode'),
              items: const [
                DropdownMenuItem(value: 'COMPLET', child: Text('Complet')),
                DropdownMenuItem(value: 'SYNTHESE', child: Text('Synthèse')),
                DropdownMenuItem(value: 'THEMATIQUE', child: Text('Thématique')),
              ],
              onChanged: (v) => setState(() => mode = v ?? 'COMPLET'),
            ),
            if (mode == 'THEMATIQUE') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: domaineThematique,
                decoration: const InputDecoration(labelText: 'Domaine'),
                items: rapportDomaines
                    .map((d) => DropdownMenuItem(
                          value: d['value'],
                          child: Text(d['label']!),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => domaineThematique = v),
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: confidentialite,
              decoration: const InputDecoration(labelText: 'Confidentialité'),
              items: const [
                DropdownMenuItem(value: 'PUBLIC', child: Text('Public')),
                DropdownMenuItem(value: 'INTERNE', child: Text('Interne')),
                DropdownMenuItem(value: 'CONFIDENTIEL', child: Text('Confidentiel')),
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
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: saving ? null : create,
          child: saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Créer'),
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
            .showSnackBar(const SnackBar(content: Text('Rapport enregistré.')));
      }
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
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
        title: const Text('Valider le rapport'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Nom du validateur'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
            child: const Text('Valider'),
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
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  Future<void> distribuer() async {
    final emailCtrl = TextEditingController();
    final parCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Distribuer le rapport'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: 'Email(s) destinataire(s)'),
            ),
            TextField(
              controller: parCtrl,
              decoration: const InputDecoration(labelText: 'Distribué par'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Distribuer'),
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
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
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
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
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
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  Future<void> archiverGed() async {
    try {
      await api.post('/business/rapports/${widget.rapportId}/archiver-ged', {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rapport archivé dans la GED.')),
        );
      }
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
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
            rapportFamilleLabels[famille] ?? famille,
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
      return Scaffold(body: Center(child: Text('Erreur : $error')));
    }
    final r = rapport!;
    final statut = r['statut']?.toString();
    final sections = r['sections'] is Map ? Map.from(r['sections']) : {};

    return Scaffold(
      appBar: AppBar(
        title: Text(r['titre']?.toString() ?? 'Rapport'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Chip(
                label: Text(
                  rapportStatutLabels[statut] ?? statut ?? '',
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
                  Text('Période : ${r['from'] ?? ''} → ${r['to'] ?? ''}'),
                  Text('Mode : ${r['mode'] ?? ''}'),
                  if (r['domaineThematique'] != null)
                    Text('Domaine : ${r['domaineThematique']}'),
                  Text('Confidentialité : ${r['confidentialite'] ?? ''}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Résumé exécutif', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          TextField(
            controller: resumeCtrl,
            maxLines: 5,
            enabled: !verrouille,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 20),
          const Text('Sections thématiques', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ...sections.entries.map((e) => buildDomainSection(e.key, e.value)),
          if (r['journalDistribution'] is List &&
              (r['journalDistribution'] as List).isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Journal de distribution', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            ...List.from(r['journalDistribution']).map((j) => Text(
                  '${j['date'] ?? ''} · ${j['email'] ?? ''} · par ${j['distribuePar'] ?? ''}',
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
                  label: const Text('Enregistrer'),
                ),
              if (statut == 'BROUILLON' || statut == 'EN_REVUE')
                OutlinedButton.icon(
                  onPressed: valider,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Valider'),
                ),
              if (statut == 'VALIDE')
                OutlinedButton.icon(
                  onPressed: distribuer,
                  icon: const Icon(Icons.send),
                  label: const Text('Distribuer'),
                ),
              OutlinedButton.icon(
                onPressed: telechargerPdf,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Télécharger PDF'),
              ),
              if (statut == 'VALIDE' || statut == 'DISTRIBUE')
                OutlinedButton.icon(
                  onPressed: archiverGed,
                  icon: const Icon(Icons.archive_outlined),
                  label: const Text('Archiver GED'),
                ),
              if (verrouille)
                OutlinedButton.icon(
                  onPressed: nouvelleVersion,
                  icon: const Icon(Icons.difference_outlined),
                  label: const Text('Nouvelle version'),
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
      await Share.shareXFiles([XFile(file.path)], text: spec.titre);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
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
            title: Text(spec.titre),
            subtitle: const Text('Export CSV local'),
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
