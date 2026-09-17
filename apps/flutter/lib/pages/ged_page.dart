import 'package:flutter/material.dart';
import '../services/api.dart';
import '../theme.dart';
import 'document_detail_page.dart';
import 'document_link_widget.dart';

const _libStatusLabels = {
  'DRAFT': 'Brouillon', 'REVIEW': 'En vérification', 'APPROVED': 'Approuvé',
  'ACTIVE': 'En vigueur', 'SUPERSEDED': 'Obsolète', 'ARCHIVED': 'Archivé',
};

const _toTreatSections = [
  ('aApprouver', 'À approuver', Icons.verified_outlined),
  ('aVerifier', 'À vérifier', Icons.fact_check_outlined),
  ('aReviser', 'À réviser', Icons.event_repeat),
  ('enRetard', 'En retard', Icons.timer_off_outlined),
  ('aDiffuser', 'À diffuser', Icons.send_outlined),
  ('accuseManquant', 'Accusé manquant', Icons.mark_email_unread_outlined),
  ('obsoletes', 'Obsolètes', Icons.block),
  ('sansResponsable', 'Sans responsable', Icons.person_off_outlined),
];

/// Page principale du référentiel documentaire (GED) — reconstruite en page
/// à onglets pour rester en parité fonctionnelle avec la version web :
/// vue d'ensemble (KPI), bibliothèque, éléments à traiter, matrice
/// documentaire. Le nom de classe est conservé (référencé depuis main.dart).
class GedPage extends StatefulWidget {
  const GedPage({super.key});
  @override
  State<GedPage> createState() => _GedPageState();
}

class _GedPageState extends State<GedPage> {
  @override
  Widget build(BuildContext c) => DefaultTabController(
    length: 4,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Documentation (GED)'),
        bottom: const TabBar(isScrollable: true, tabs: [
          Tab(text: "Vue d'ensemble"), Tab(text: 'Bibliothèque'), Tab(text: 'À traiter'), Tab(text: 'Matrice'),
        ]),
      ),
      body: const TabBarView(children: [_GedOverviewTab(), _GedLibraryTab(), _GedToTreatTab(), _GedMatrixTab()]),
    ),
  );
}

// --- Onglet 1 : Vue d'ensemble (KPI du GED) ---
class _GedOverviewTab extends StatefulWidget {
  const _GedOverviewTab();
  @override
  State<_GedOverviewTab> createState() => _GedOverviewTabState();
}

class _GedOverviewTabState extends State<_GedOverviewTab> {
  final api = Api();
  Map dash = {};
  bool loading = true;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() => loading = true);
    try { dash = Map.from(await api.get('/documents/dashboard')); } catch (_) {}
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext c) {
    if (loading) return const Center(child: CircularProgressIndicator());
    int n(String k) => dash[k] is num ? (dash[k] as num).toInt() : 0;
    final repartition = List.from(dash['repartitionParStatut'] ?? []);
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(padding: const EdgeInsets.symmetric(vertical: 12), children: [
        KpiBar([
          KpiStat('Total', '${n('total')}', color: QhseColors.blue, icon: Icons.folder_outlined),
          KpiStat('Actifs', '${n('actifs')}', color: QhseColors.green, icon: Icons.check_circle_outline),
          KpiStat('Brouillons', '${n('brouillons')}', color: QhseColors.blue, icon: Icons.edit_note),
          KpiStat('En vérification', '${n('enVerification')}', color: QhseColors.amber, icon: Icons.fact_check_outlined),
          KpiStat('En approbation', '${n('enApprobation')}', color: QhseColors.amber, icon: Icons.verified_outlined),
          KpiStat('Obsolètes', '${n('obsoletes')}', color: QhseColors.red, icon: Icons.block),
          KpiStat('Archivés', '${n('archives')}', color: QhseColors.textSecondary, icon: Icons.archive_outlined),
          KpiStat('À réviser ≤ 90j', '${n('aReviserProchainement')}', color: QhseColors.amber, icon: Icons.event_repeat),
          KpiStat('En retard de révision', '${n('enRetardRevision')}', color: n('enRetardRevision') > 0 ? QhseColors.red : QhseColors.green, icon: Icons.timer_off_outlined),
          KpiStat('Sans responsable', '${n('sansResponsable')}', color: QhseColors.amber, icon: Icons.person_off_outlined),
          KpiStat('Critiques', '${n('critiques')}', color: QhseColors.red, icon: Icons.priority_high),
          KpiStat('Réglementaires', '${n('reglementaires')}', color: QhseColors.blue, icon: Icons.gavel_outlined),
          KpiStat('Diffusion en attente', '${n('diffusionEnAttente')}', color: QhseColors.amber, icon: Icons.send_outlined),
          KpiStat('Accusé manquant', '${n('accuseManquant')}', color: QhseColors.amber, icon: Icons.mark_email_unread_outlined),
          KpiStat('Taux à jour', '${dash['tauxAJour'] ?? '—'}%', color: QhseColors.green, icon: Icons.trending_up),
        ]),
        const SizedBox(height: 16),
        if (repartition.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Répartition par statut', style: TextStyle(fontWeight: FontWeight.bold, color: QhseColors.textPrimary)),
              const SizedBox(height: 8),
              ...repartition.map((r) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('${r['label']}', style: TextStyle(color: QhseColors.textSecondary, fontSize: 13)),
                    Text('${r['value']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ]))),
            ]))),
          ),
      ]),
    );
  }
}

// --- Onglet 2 : Bibliothèque (registre + recherche + filtre statut) ---
class _GedLibraryTab extends StatefulWidget {
  const _GedLibraryTab();
  @override
  State<_GedLibraryTab> createState() => _GedLibraryTabState();
}

class _GedLibraryTabState extends State<_GedLibraryTab> {
  final api = Api();
  List documents = [];
  bool loading = true;
  String? statusFilter;
  final search = TextEditingController();

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() => loading = true);
    final params = <String>[];
    if (statusFilter != null) params.add('status=$statusFilter');
    if (search.text.trim().isNotEmpty) params.add('q=${Uri.encodeQueryComponent(search.text.trim())}');
    final q = params.isEmpty ? '' : '?${params.join('&')}';
    try { documents = List.from(await api.get('/documents$q')); } catch (_) {}
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    body: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: TextField(
          controller: search,
          decoration: const InputDecoration(labelText: 'Rechercher (code, titre, mots-clés)', prefixIcon: Icon(Icons.search)),
          onSubmitted: (_) => load(),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Wrap(spacing: 8, children: [
          ChoiceChip(label: const Text('Tous'), selected: statusFilter == null, onSelected: (_) { statusFilter = null; load(); }),
          for (final s in _libStatusLabels.keys)
            ChoiceChip(label: Text(_libStatusLabels[s]!), selected: statusFilter == s, onSelected: (_) { statusFilter = s; load(); }),
        ]),
      ),
      Expanded(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: load,
                child: documents.isEmpty
                    ? ListView(children: const [Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Aucun document')))])
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: documents.length,
                        itemBuilder: (_, i) {
                          final d = documents[i];
                          return Card(child: ListTile(
                            title: Text('${d['code']} — ${d['title']}'),
                            subtitle: Text('${_libStatusLabels[d['status']] ?? d['status']} · v${d['currentVersion']}${d['criticite'] == 'CRITIQUE' ? ' · Critique' : ''}'),
                            trailing: DocumentStatusChip(status: d['status']),
                            onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => DocumentDetailPage(documentId: d['id']))).then((_) => load()),
                          ));
                        },
                      ),
              ),
      ),
    ]),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const DocumentFormPage())).then((_) => load()),
      icon: const Icon(Icons.add),
      label: const Text('Ajouter un document'),
    ),
  );
}

// --- Onglet 3 : À traiter (une section par catégorie d'action) ---
class _GedToTreatTab extends StatefulWidget {
  const _GedToTreatTab();
  @override
  State<_GedToTreatTab> createState() => _GedToTreatTabState();
}

class _GedToTreatTabState extends State<_GedToTreatTab> {
  final api = Api();
  Map data = {};
  bool loading = true;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() => loading = true);
    try { data = Map.from(await api.get('/documents/a-traiter')); } catch (_) {}
    setState(() => loading = false);
  }

  void open(BuildContext c, String id) {
    Navigator.push(c, MaterialPageRoute(builder: (_) => DocumentDetailPage(documentId: id))).then((_) => load());
  }

  @override
  Widget build(BuildContext c) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(padding: const EdgeInsets.all(12), children: [
        for (final s in _toTreatSections) _section(c, s.$2, s.$3, List.from(data[s.$1] ?? [])),
      ]),
    );
  }

  Widget _section(BuildContext c, String label, IconData icon, List items) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ExpansionTile(
      leading: Icon(icon, color: QhseColors.blue),
      title: Text('$label (${items.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
      children: items.isEmpty
          ? [Padding(padding: const EdgeInsets.all(12), child: Text('Rien à signaler', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))]
          : items.map<Widget>((it) => ListTile(
                dense: true,
                title: Text('${it['code']} — ${it['title']}', style: const TextStyle(fontSize: 13)),
                subtitle: it['nextReviewAt'] != null ? Text('Révision : ${'${it['nextReviewAt']}'.substring(0, 10)}', style: const TextStyle(fontSize: 11)) : null,
                trailing: DocumentStatusChip(status: it['status']),
                onTap: () => open(c, it['id']),
              )).toList(),
    ),
  );
}

// --- Onglet 4 : Matrice documentaire (tableau natif, pas d'export Excel) ---
class _GedMatrixTab extends StatefulWidget {
  const _GedMatrixTab();
  @override
  State<_GedMatrixTab> createState() => _GedMatrixTabState();
}

class _GedMatrixTabState extends State<_GedMatrixTab> {
  final api = Api();
  List rows = [];
  bool loading = true;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() => loading = true);
    try { rows = List.from(await api.get('/documents/matrice')); } catch (_) {}
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext c) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (rows.isEmpty) {
      return RefreshIndicator(onRefresh: load, child: ListView(children: const [Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Aucune donnée')))]));
    }
    return RefreshIndicator(
      onRefresh: load,
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Code')), DataColumn(label: Text('Titre')), DataColumn(label: Text('Version')),
              DataColumn(label: Text('Type')), DataColumn(label: Text('Processus')), DataColumn(label: Text('Responsable')),
              DataColumn(label: Text('Statut')), DataColumn(label: Text('Approbation')), DataColumn(label: Text('Entrée en vigueur')),
              DataColumn(label: Text('Prochaine révision')), DataColumn(label: Text('Criticité')), DataColumn(label: Text('Diffusion')),
              DataColumn(label: Text('Accusé lecture')), DataColumn(label: Text('État')),
            ],
            rows: rows.map((r) => DataRow(cells: [
              DataCell(Text('${r['code'] ?? ''}')), DataCell(Text('${r['title'] ?? ''}')), DataCell(Text('${r['version'] ?? ''}')),
              DataCell(Text('${r['documentType'] ?? ''}')), DataCell(Text('${r['processus'] ?? ''}')), DataCell(Text('${r['responsable'] ?? ''}')),
              DataCell(Text('${r['statut'] ?? ''}')), DataCell(Text('${r['approbation'] ?? ''}')),
              DataCell(Text(r['dateEntreeVigueur'] != null ? '${r['dateEntreeVigueur']}'.substring(0, 10) : '')),
              DataCell(Text(r['nextReviewAt'] != null ? '${r['nextReviewAt']}'.substring(0, 10) : '')),
              DataCell(Text('${r['criticite'] ?? ''}')), DataCell(Text('${r['diffusion'] ?? ''}')), DataCell(Text('${r['accuseLecture'] ?? ''}')),
              DataCell(Text('${r['etat'] ?? ''}')),
            ])).toList(),
          ),
        ),
      ),
    );
  }
}
