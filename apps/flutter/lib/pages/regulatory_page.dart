import 'package:flutter/material.dart';
import '../services/api.dart';
import '../theme.dart';
import '../i18n/i18n.dart';
import 'referentiel_pages.dart' show RegulatoryLegacyCataloguePage;

// ============================================================================
// VEILLE RÉGLEMENTAIRE — parité complète avec le tableau de bord web :
// Textes → Exigences → Applicabilité → Évaluation → Preuves → NC/CAPA →
// Risques, plus alertes/échéances, réévaluations des risques, rapports
// (taux de conformité, matrice de traçabilité) et référentiel des domaines.
// Mêmes principes que côté web : jamais de conclusion automatique
// (justification obligatoire si applicabilité non-OUI, analyse d'impact
// toujours "à analyser", réévaluation de risque = tâche à traiter, jamais
// une note modifiée directement).
// ============================================================================

const regApplicabiliteValues = ['OUI', 'NON', 'PARTIELLEMENT', 'A_ANALYSER'];
String regApplicabiliteLabel(String? k) => k == null ? '—' : (regApplicabiliteValues.contains(k) ? t('regulatory.applicabilite.$k') : k);
const regStatutConformiteValues = ['CONFORME', 'PARTIEL', 'NON_CONFORME'];
String regStatutConformiteLabel(String? k) => k == null ? '—' : (regStatutConformiteValues.contains(k) ? t('regulatory.statutConformite.$k') : k);
const regStatutFileValues = ['NOUVEAU', 'A_ANALYSER', 'APPLICABILITE_A_DETERMINER', 'EVALUATION_A_REALISER', 'VERIFICATION', 'ACTIONS_NECESSAIRES', 'CLOTURE'];
String regStatutFileLabel(String? k) => k == null ? '—' : (regStatutFileValues.contains(k) ? t('regulatory.statutFile.$k') : k);
const regEvidenceStatutValues = ['VALIDE', 'EXPIRE_BIENTOT', 'A_RENOUVELER', 'EXPIRE'];
String regEvidenceStatutLabel(String? k) => k == null ? '—' : (regEvidenceStatutValues.contains(k) ? t('regulatory.evidenceStatut.$k') : k);
const regCriticiteValues = ['CRITIQUE', 'HAUTE', 'MOYENNE', 'FAIBLE'];
String regCriticiteLabel(String? k) => k == null ? '—' : (regCriticiteValues.contains(k) ? t('regulatory.criticite.$k') : k);

Color regApplicabiliteColor(String? v) => {'OUI': QhseColors.green, 'NON': QhseColors.textSecondary, 'PARTIELLEMENT': QhseColors.amber, 'A_ANALYSER': QhseColors.blue}[v] ?? QhseColors.textSecondary;
Color regConformiteColor(String? v) => {'CONFORME': QhseColors.green, 'PARTIEL': QhseColors.amber, 'NON_CONFORME': QhseColors.red}[v] ?? QhseColors.textSecondary;
Color regEvidenceColor(String? v) => {'VALIDE': QhseColors.green, 'EXPIRE_BIENTOT': QhseColors.amber, 'A_RENOUVELER': QhseColors.amber, 'EXPIRE': QhseColors.red}[v] ?? QhseColors.textSecondary;
Color regAlertNiveauColor(String? v) => {'CRITIQUE': QhseColors.red, 'ECHEANCE_PROCHE': QhseColors.amber, 'ATTENTION': QhseColors.amber, 'INFORMATION': QhseColors.blue}[v] ?? QhseColors.textSecondary;

String regFmtDate(dynamic v) => v == null ? '—' : DateTime.parse(v).toIso8601String().substring(0, 10);
String regUserName(dynamic u) => u == null ? '—' : '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim();

Widget regChip(String label, Color color) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(999)),
  child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
);

Widget regKpi(String label, String value, Color color) => Expanded(
  child: Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: TextStyle(fontSize: 11, color: QhseColors.textSecondary)),
    const SizedBox(height: 4),
    Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
  ]))),
);

Widget regSectionTitle(String t) => Padding(padding: const EdgeInsets.only(top: 12, bottom: 6), child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold)));
Widget regEmpty(String t) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(t, style: TextStyle(color: QhseColors.textSecondary, fontSize: 13)));

class RegulatoryPage extends StatelessWidget {
  const RegulatoryPage({super.key});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 8,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('regulatory.appBarTitle')),
          bottom: TabBar(isScrollable: true, tabs: [
            Tab(text: t('regulatory.tab.dashboard')), Tab(text: t('regulatory.tab.textes')), Tab(text: t('regulatory.tab.exigences')), Tab(text: t('regulatory.tab.alertes')),
            Tab(text: t('regulatory.tab.reevaluations')), Tab(text: t('regulatory.tab.rapports')), Tab(text: t('regulatory.tab.domaines')), Tab(text: t('regulatory.tab.catalogueLegacy')),
          ]),
        ),
        body: const TabBarView(children: [
          RegulatoryDashboardTab(), RegulatoryTextsTab(), RegulatoryRequirementsTab(), RegulatoryAlertsTab(),
          RegulatoryReevaluationsTab(), RegulatoryReportsTab(), RegulatoryDomainsTab(), RegulatoryLegacyCataloguePage(),
        ]),
      ),
    );
  }
}

class RegulatoryDashboardTab extends StatefulWidget {
  const RegulatoryDashboardTab({super.key});
  @override
  State<RegulatoryDashboardTab> createState() => _RegulatoryDashboardTabState();
}

class _RegulatoryDashboardTabState extends State<RegulatoryDashboardTab> {
  final api = Api();
  Map? dash;
  String? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() => error = null);
    try { dash = Map.from(await api.get('/business/regulatory-requirements-dashboard')); }
    catch (e) { error = '$e'; }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext c) {
    if (error != null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!), TextButton(onPressed: load, child: Text(t('regulatory.retry')))]));
    if (dash == null) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(padding: const EdgeInsets.all(12), children: [
        Row(children: [
          regKpi(t('regulatory.kpi.exigencesTotales'), '${dash!['total'] ?? 0}', QhseColors.blue),
          const SizedBox(width: 8),
          regKpi(t('regulatory.kpi.applicables'), '${dash!['applicables'] ?? 0}', QhseColors.blue),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          regKpi(t('regulatory.kpi.tauxConformite'), dash!['tauxConformite'] != null ? '${dash!['tauxConformite']}%' : '—', QhseColors.green),
          const SizedBox(width: 8),
          regKpi(t('regulatory.kpi.aAnalyser'), '${dash!['aAnalyser'] ?? 0}', QhseColors.amber),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          regKpi(t('regulatory.kpi.conformes'), '${dash!['conformes'] ?? 0}', QhseColors.green),
          const SizedBox(width: 8),
          regKpi(t('regulatory.kpi.partielles'), '${dash!['partielles'] ?? 0}', QhseColors.amber),
          const SizedBox(width: 8),
          regKpi(t('regulatory.kpi.nonConformes'), '${dash!['nonConformes'] ?? 0}', QhseColors.red),
        ]),
        regSectionTitle(t('regulatory.dashboard.nonEvalueesTitle')),
        Text(t('regulatory.dashboard.nonEvalueesText', {'count': '${dash!['nonEvaluees'] ?? 0}'})),
        regSectionTitle(t('regulatory.dashboard.methodeCalculTitle')),
        Text(dash!['methodeCalcul'] ?? '', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// TEXTES RÉGLEMENTAIRES
// ---------------------------------------------------------------------------

class RegulatoryTextsTab extends StatefulWidget {
  const RegulatoryTextsTab({super.key});
  @override
  State<RegulatoryTextsTab> createState() => _RegulatoryTextsTabState();
}

class _RegulatoryTextsTabState extends State<RegulatoryTextsTab> {
  final api = Api();
  List items = [];
  bool loading = true;
  String? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try { items = List.from(await api.get('/business/regulatory-texts')); }
    catch (e) { error = '$e'; }
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final saved = await Navigator.push<bool>(c, MaterialPageRoute(builder: (_) => const RegulatoryTextFormPage()));
          if (saved == true) load();
        },
        icon: const Icon(Icons.add), label: Text(t('regulatory.newTexte')),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!), TextButton(onPressed: load, child: Text(t('regulatory.retry')))]))
              : RefreshIndicator(onRefresh: load, child: items.isEmpty
                  ? ListView(children: [regEmpty(t('regulatory.texts.empty'))])
                  : ListView.builder(padding: const EdgeInsets.all(12), itemCount: items.length, itemBuilder: (_, i) {
                      final t = items[i];
                      return Card(child: ListTile(
                        title: Text(t['titre'] ?? ''),
                        subtitle: Text('${t['reference'] ?? t['typeTexte'] ?? '—'} • ${t['domain']?['label'] ?? t('regulatory.sansDomaine')}'),
                        trailing: regChip(t['statut'] == 'EN_VIGUEUR' ? t('regulatory.textStatut.EN_VIGUEUR') : (t['statut'] == 'ABROGE' ? t('regulatory.textStatut.ABROGE') : t('regulatory.textStatut.MODIFIE')), t['statut'] == 'ABROGE' ? QhseColors.red : (t['statut'] == 'MODIFIE' ? QhseColors.amber : QhseColors.green)),
                        onTap: () async {
                          await Navigator.push(c, MaterialPageRoute(builder: (_) => RegulatoryTextDetailPage(textId: t['id'])));
                          load();
                        },
                      ));
                    })),
    );
  }
}

class RegulatoryTextFormPage extends StatefulWidget {
  final Map? record;
  const RegulatoryTextFormPage({super.key, this.record});
  @override
  State<RegulatoryTextFormPage> createState() => _RegulatoryTextFormPageState();
}

class _RegulatoryTextFormPageState extends State<RegulatoryTextFormPage> {
  final api = Api();
  late final reference = TextEditingController(text: widget.record?['reference'] ?? '');
  late final titre = TextEditingController(text: widget.record?['titre'] ?? '');
  late final typeTexte = TextEditingController(text: widget.record?['typeTexte'] ?? '');
  late final sousDomaine = TextEditingController(text: widget.record?['sousDomaine'] ?? '');
  late final pays = TextEditingController(text: widget.record?['pays'] ?? "Côte d'Ivoire");
  late final autoriteEmettrice = TextEditingController(text: widget.record?['autoriteEmettrice'] ?? '');
  late final sourceOfficielle = TextEditingController(text: widget.record?['sourceOfficielle'] ?? '');
  late final lienSource = TextEditingController(text: widget.record?['lienSource'] ?? '');
  late final objet = TextEditingController(text: widget.record?['objet'] ?? '');
  late final resume = TextEditingController(text: widget.record?['resume'] ?? '');
  String statut = 'EN_VIGUEUR';
  List domains = [];
  String? domainId;
  DateTime? datePublication;
  DateTime? dateEntreeVigueur;
  bool busy = false;
  String? error;

  bool get editing => widget.record != null;

  @override
  void initState() {
    super.initState();
    statut = widget.record?['statut'] ?? 'EN_VIGUEUR';
    domainId = widget.record?['domainId'];
    if (widget.record?['datePublication'] != null) datePublication = DateTime.parse(widget.record!['datePublication']);
    if (widget.record?['dateEntreeVigueur'] != null) dateEntreeVigueur = DateTime.parse(widget.record!['dateEntreeVigueur']);
    api.get('/business/regulatory-domains').then((v) { if (mounted) setState(() => domains = List.from(v)); }).catchError((_) {});
  }

  Future<void> pickDate(bool entree) async {
    final d = await showDatePicker(context: context, initialDate: (entree ? dateEntreeVigueur : datePublication) ?? DateTime.now(), firstDate: DateTime(1960), lastDate: DateTime.now().add(const Duration(days: 3650)));
    if (d == null) return;
    setState(() { if (entree) dateEntreeVigueur = d; else datePublication = d; });
  }

  Future<void> submit() async {
    if (titre.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('regulatory.textForm.titreRequired')))); return; }
    setState(() { busy = true; error = null; });
    final payload = {
      'reference': reference.text.trim().isEmpty ? null : reference.text.trim(), 'titre': titre.text.trim(),
      'typeTexte': typeTexte.text.trim().isEmpty ? null : typeTexte.text.trim(), 'domainId': domainId,
      'sousDomaine': sousDomaine.text.trim().isEmpty ? null : sousDomaine.text.trim(), 'pays': pays.text.trim().isEmpty ? null : pays.text.trim(),
      'autoriteEmettrice': autoriteEmettrice.text.trim().isEmpty ? null : autoriteEmettrice.text.trim(),
      'datePublication': datePublication?.toIso8601String(), 'dateEntreeVigueur': dateEntreeVigueur?.toIso8601String(),
      'statut': statut, 'sourceOfficielle': sourceOfficielle.text.trim().isEmpty ? null : sourceOfficielle.text.trim(),
      'lienSource': lienSource.text.trim().isEmpty ? null : lienSource.text.trim(),
      'objet': objet.text.trim().isEmpty ? null : objet.text.trim(), 'resume': resume.text.trim().isEmpty ? null : resume.text.trim(),
    };
    try {
      if (editing) await api.patch('/business/regulatory-texts/${widget.record!['id']}', payload);
      else await api.post('/business/regulatory-texts', payload);
      if (mounted) Navigator.pop(context, true);
    } catch (e) { setState(() { busy = false; error = '$e'; }); }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text(editing ? t('regulatory.textForm.editTitle') : t('regulatory.textForm.createTitle'))),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      TextField(controller: reference, decoration: InputDecoration(labelText: t('regulatory.textForm.reference'), border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: titre, decoration: InputDecoration(labelText: t('regulatory.textForm.titre'), border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: typeTexte, decoration: InputDecoration(labelText: t('regulatory.textForm.typeTexte'), border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: domains.any((d) => d['id'] == domainId) ? domainId : null,
        decoration: InputDecoration(labelText: t('regulatory.field.domaine'), border: const OutlineInputBorder()),
        items: [const DropdownMenuItem(value: null, child: Text('—')), ...domains.map((d) => DropdownMenuItem(value: d['id'] as String, child: Text(d['label'])))],
        onChanged: (v) => setState(() => domainId = v),
      ),
      const SizedBox(height: 12),
      TextField(controller: sousDomaine, decoration: InputDecoration(labelText: t('regulatory.textForm.sousDomaine'), border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: pays, decoration: InputDecoration(labelText: t('regulatory.textForm.pays'), border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: autoriteEmettrice, decoration: InputDecoration(labelText: t('regulatory.textForm.autoriteEmettrice'), border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: () => pickDate(false), icon: const Icon(Icons.event), label: Text(datePublication == null ? t('regulatory.textForm.publication') : regFmtDate(datePublication!.toIso8601String())))),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton.icon(onPressed: () => pickDate(true), icon: const Icon(Icons.gavel), label: Text(dateEntreeVigueur == null ? t('regulatory.textForm.entreeVigueur') : regFmtDate(dateEntreeVigueur!.toIso8601String())))),
      ]),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: statut,
        decoration: InputDecoration(labelText: t('regulatory.field.statut'), border: const OutlineInputBorder()),
        items: [DropdownMenuItem(value: 'EN_VIGUEUR', child: Text(t('regulatory.textStatut.EN_VIGUEUR'))), DropdownMenuItem(value: 'MODIFIE', child: Text(t('regulatory.textStatut.MODIFIE'))), DropdownMenuItem(value: 'ABROGE', child: Text(t('regulatory.textStatut.ABROGE')))],
        onChanged: (v) => setState(() => statut = v ?? statut),
      ),
      const SizedBox(height: 12),
      TextField(controller: sourceOfficielle, decoration: InputDecoration(labelText: t('regulatory.textForm.sourceOfficielle'), border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: lienSource, decoration: InputDecoration(labelText: t('regulatory.textForm.lienSource'), border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: objet, maxLines: 2, decoration: InputDecoration(labelText: t('regulatory.textForm.objet'), border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: resume, maxLines: 3, decoration: InputDecoration(labelText: t('regulatory.textForm.resume'), border: const OutlineInputBorder())),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
      const SizedBox(height: 20),
      FilledButton(onPressed: busy ? null : submit, child: busy ? const CircularProgressIndicator() : Text(t('regulatory.save'))),
    ]),
  );
}

class RegulatoryTextDetailPage extends StatefulWidget {
  final String textId;
  const RegulatoryTextDetailPage({super.key, required this.textId});
  @override
  State<RegulatoryTextDetailPage> createState() => _RegulatoryTextDetailPageState();
}

class _RegulatoryTextDetailPageState extends State<RegulatoryTextDetailPage> {
  final api = Api();
  Map? analysis;
  bool loading = true;
  String? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try { analysis = Map.from(await api.get('/business/regulatory-texts/${widget.textId}/impact-analysis')); }
    catch (e) { error = '$e'; }
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext c) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (error != null) return Scaffold(body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!), TextButton(onPressed: load, child: Text(t('regulatory.retry')))])));
    final text = Map.from(analysis!['text']);
    final requirements = List.from(text['requirements'] ?? []);
    return Scaffold(
      appBar: AppBar(title: Text(text['titre'] ?? ''), actions: [
        IconButton(icon: const Icon(Icons.edit), onPressed: () async {
          final saved = await Navigator.push<bool>(c, MaterialPageRoute(builder: (_) => RegulatoryTextFormPage(record: text)));
          if (saved == true) load();
        }),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final saved = await Navigator.push<bool>(c, MaterialPageRoute(builder: (_) => RegulatoryRequirementFormPage(textId: widget.textId)));
          if (saved == true) load();
        },
        icon: const Icon(Icons.add), label: Text(t('regulatory.newExigence')),
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            regChip(t('regulatory.detail.impactAnalysisChip'), QhseColors.blue),
            if (text['reference'] != null) regChip(text['reference'], QhseColors.textSecondary),
          ]),
          const SizedBox(height: 4),
          Text(t('regulatory.detail.neverAutoConclusion'), style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: QhseColors.textSecondary)),
          const SizedBox(height: 12),
          Row(children: [
            regKpi(t('regulatory.kpi.exigencesImpactees'), '${analysis!['exigencesImpactees'] ?? 0}', QhseColors.blue),
            const SizedBox(width: 8),
            regKpi(t('regulatory.kpi.sitesImpactes'), '${(analysis!['sitesImpactes'] as List).length}', QhseColors.blue),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            regKpi(t('regulatory.kpi.ncOuvertes'), '${(analysis!['nonConformitesOuvertes'] as List).length}', QhseColors.red),
            const SizedBox(width: 8),
            regKpi(t('regulatory.kpi.actionsOuvertes'), '${(analysis!['actionsOuvertes'] as List).length}', QhseColors.amber),
          ]),
          regSectionTitle(t('regulatory.section.risquesLies', {'count': '${(analysis!['risquesImpactes'] as List).length}'})),
          ...(analysis!['risquesImpactes'] as List).map((r) => ListTile(dense: true, leading: const Icon(Icons.warning_amber), title: Text('${r['code']} — ${r['hazard']}'))),
          if ((analysis!['risquesImpactes'] as List).isEmpty) regEmpty(t('regulatory.empty.risques')),
          regSectionTitle(t('regulatory.section.documentsLies', {'count': '${(analysis!['documentsImpactes'] as List).length}'})),
          ...(analysis!['documentsImpactes'] as List).map((d) => ListTile(dense: true, leading: const Icon(Icons.description), title: Text(d['title'] ?? d['name'] ?? ''))),
          if ((analysis!['documentsImpactes'] as List).isEmpty) regEmpty(t('regulatory.empty.documents')),
          regSectionTitle(t('regulatory.textDetail.exigencesSection', {'count': '${requirements.length}'})),
          if (requirements.isEmpty) regEmpty(t('regulatory.textDetail.exigencesEmpty'))
          else ...requirements.map((r) => Card(child: ListTile(
            title: Text(r['libelle'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Row(children: [
              regChip(regApplicabiliteLabel(r['applicabilite']?.toString()), regApplicabiliteColor(r['applicabilite'])),
              const SizedBox(width: 6),
              if (r['statutConformite'] != null) regChip(regStatutConformiteLabel(r['statutConformite']?.toString()), regConformiteColor(r['statutConformite'])),
            ]),
            onTap: () async {
              await Navigator.push(c, MaterialPageRoute(builder: (_) => RegulatoryRequirementDetailPage(requirementId: r['id'])));
              load();
            },
          ))),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// EXIGENCES — matrice réglementaire dynamique
// ---------------------------------------------------------------------------

class RegulatoryRequirementsTab extends StatefulWidget {
  const RegulatoryRequirementsTab({super.key});
  @override
  State<RegulatoryRequirementsTab> createState() => _RegulatoryRequirementsTabState();
}

class _RegulatoryRequirementsTabState extends State<RegulatoryRequirementsTab> {
  final api = Api();
  List items = [];
  bool loading = true;
  String? error;
  String applicabilite = 'TOUS';
  String statutConformite = 'TOUS';

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    final params = <String>[];
    if (applicabilite != 'TOUS') params.add('applicabilite=$applicabilite');
    if (statutConformite != 'TOUS') params.add('statutConformite=$statutConformite');
    final qs = params.isEmpty ? '' : '?${params.join('&')}';
    try { items = List.from(await api.get('/business/regulatory-requirements$qs')); }
    catch (e) { error = '$e'; }
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final saved = await Navigator.push<bool>(c, MaterialPageRoute(builder: (_) => const RegulatoryRequirementFormPage()));
          if (saved == true) load();
        },
        icon: const Icon(Icons.add), label: Text(t('regulatory.newExigence')),
      ),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: Row(children: [
          Expanded(child: DropdownButtonFormField<String>(
            value: applicabilite, isExpanded: true,
            decoration: InputDecoration(labelText: t('regulatory.filter.applicabilite'), border: const OutlineInputBorder(), isDense: true),
            items: [DropdownMenuItem(value: 'TOUS', child: Text(t('regulatory.filter.toutes'))), ...regApplicabiliteValues.map((k) => DropdownMenuItem(value: k, child: Text(regApplicabiliteLabel(k))))],
            onChanged: (v) { applicabilite = v ?? 'TOUS'; load(); },
          )),
          const SizedBox(width: 8),
          Expanded(child: DropdownButtonFormField<String>(
            value: statutConformite, isExpanded: true,
            decoration: InputDecoration(labelText: t('regulatory.filter.conformite'), border: const OutlineInputBorder(), isDense: true),
            items: [DropdownMenuItem(value: 'TOUS', child: Text(t('regulatory.filter.toutes'))), ...regStatutConformiteValues.map((k) => DropdownMenuItem(value: k, child: Text(regStatutConformiteLabel(k))))],
            onChanged: (v) { statutConformite = v ?? 'TOUS'; load(); },
          )),
        ])),
        Expanded(child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!), TextButton(onPressed: load, child: Text(t('regulatory.retry')))]))
                : RefreshIndicator(onRefresh: load, child: items.isEmpty
                    ? ListView(children: [regEmpty(t('regulatory.requirements.emptyFiltered'))])
                    : ListView.builder(padding: const EdgeInsets.all(12), itemCount: items.length, itemBuilder: (_, i) {
                        final r = items[i];
                        return Card(child: ListTile(
                          title: Text(r['libelle'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${r['text']?['titre'] ?? ''} ${r['site'] != null ? '• ${r['site']['name']}' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                            regChip(regApplicabiliteLabel(r['applicabilite']?.toString()), regApplicabiliteColor(r['applicabilite'])),
                            if (r['statutConformite'] != null) Padding(padding: const EdgeInsets.only(top: 4), child: regChip(regStatutConformiteLabel(r['statutConformite']?.toString()), regConformiteColor(r['statutConformite']))),
                          ]),
                          onTap: () async {
                            await Navigator.push(c, MaterialPageRoute(builder: (_) => RegulatoryRequirementDetailPage(requirementId: r['id'])));
                            load();
                          },
                        ));
                      }))),
      ]),
    );
  }
}

class RegulatoryRequirementFormPage extends StatefulWidget {
  final Map? record;
  final String? textId;
  const RegulatoryRequirementFormPage({super.key, this.record, this.textId});
  @override
  State<RegulatoryRequirementFormPage> createState() => _RegulatoryRequirementFormPageState();
}

class _RegulatoryRequirementFormPageState extends State<RegulatoryRequirementFormPage> {
  final api = Api();
  late final libelle = TextEditingController(text: widget.record?['libelle'] ?? '');
  late final preuveAttendue = TextEditingController(text: widget.record?['preuveAttendue'] ?? '');
  late final commentaire = TextEditingController(text: widget.record?['commentaire'] ?? '');
  late final frequence = TextEditingController(text: widget.record?['frequenceEvaluationMois']?.toString() ?? '');
  List texts = [];
  List domains = [];
  List sites = [];
  List workUnits = [];
  List users = [];
  String? textId;
  String? domainId;
  String? siteId;
  String? workUnitId;
  String? responsableId;
  String? criticite;
  bool busy = false;
  String? error;

  bool get editing => widget.record != null;

  @override
  void initState() {
    super.initState();
    textId = widget.record?['textId'] ?? widget.textId;
    domainId = widget.record?['domainId'];
    siteId = widget.record?['siteId'];
    workUnitId = widget.record?['workUnitId'];
    responsableId = widget.record?['responsableId'];
    criticite = widget.record?['criticite'];
    Future.wait([
      api.get('/business/regulatory-texts'), api.get('/business/regulatory-domains'),
      api.get('/quality/catalog/sites'), api.get('/business/work-units'), api.get('/users'),
    ]).then((r) { if (mounted) setState(() { texts = List.from(r[0]); domains = List.from(r[1]); sites = List.from(r[2]); workUnits = List.from(r[3]); users = List.from(r[4]); }); }).catchError((_) {});
  }

  Future<void> submit() async {
    if (libelle.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('regulatory.reqForm.libelleRequired')))); return; }
    if (textId == null) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('regulatory.reqForm.texteSourceRequired')))); return; }
    setState(() { busy = true; error = null; });
    final payload = {
      'textId': textId, 'libelle': libelle.text.trim(), 'domainId': domainId, 'siteId': siteId, 'workUnitId': workUnitId,
      'responsableId': responsableId, 'criticite': criticite, 'preuveAttendue': preuveAttendue.text.trim().isEmpty ? null : preuveAttendue.text.trim(),
      'frequenceEvaluationMois': frequence.text.trim().isEmpty ? null : int.tryParse(frequence.text.trim()),
      'commentaire': commentaire.text.trim().isEmpty ? null : commentaire.text.trim(),
    };
    try {
      if (editing) await api.patch('/business/regulatory-requirements/${widget.record!['id']}', payload);
      else await api.post('/business/regulatory-requirements', payload);
      if (mounted) Navigator.pop(context, true);
    } catch (e) { setState(() { busy = false; error = '$e'; }); }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text(editing ? t('regulatory.reqForm.editTitle') : t('regulatory.newExigence'))),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      TextField(controller: libelle, maxLines: 3, decoration: InputDecoration(labelText: t('regulatory.reqForm.libelle'), border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: texts.any((t) => t['id'] == textId) ? textId : null, isExpanded: true,
        decoration: InputDecoration(labelText: t('regulatory.reqForm.texteSource'), border: const OutlineInputBorder()),
        items: texts.map<DropdownMenuItem<String>>((t) => DropdownMenuItem(value: t['id'] as String, child: Text(t['titre'], overflow: TextOverflow.ellipsis))).toList(),
        onChanged: widget.textId != null ? null : (v) => setState(() => textId = v),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: domains.any((d) => d['id'] == domainId) ? domainId : null,
        decoration: InputDecoration(labelText: t('regulatory.field.domaine'), border: const OutlineInputBorder()),
        items: [const DropdownMenuItem(value: null, child: Text('—')), ...domains.map((d) => DropdownMenuItem(value: d['id'] as String, child: Text(d['label'])))],
        onChanged: (v) => setState(() => domainId = v),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: criticite,
        decoration: InputDecoration(labelText: t('regulatory.field.criticite'), border: const OutlineInputBorder()),
        items: [const DropdownMenuItem(value: null, child: Text('—')), ...regCriticiteValues.map((k) => DropdownMenuItem(value: k, child: Text(regCriticiteLabel(k))))],
        onChanged: (v) => setState(() => criticite = v),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: sites.any((s) => s['id'] == siteId) ? siteId : null,
        decoration: InputDecoration(labelText: t('regulatory.field.site'), border: const OutlineInputBorder()),
        items: [const DropdownMenuItem(value: null, child: Text('—')), ...sites.map((s) => DropdownMenuItem(value: s['id'] as String, child: Text(s['name'])))],
        onChanged: (v) => setState(() => siteId = v),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: workUnits.any((w) => w['id'] == workUnitId) ? workUnitId : null,
        decoration: InputDecoration(labelText: t('regulatory.field.serviceUnite'), border: const OutlineInputBorder()),
        items: [const DropdownMenuItem(value: null, child: Text('—')), ...workUnits.map((w) => DropdownMenuItem(value: w['id'] as String, child: Text(w['name'])))],
        onChanged: (v) => setState(() => workUnitId = v),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: users.any((u) => u['id'] == responsableId) ? responsableId : null,
        decoration: InputDecoration(labelText: t('regulatory.field.responsable'), border: const OutlineInputBorder()),
        items: [const DropdownMenuItem(value: null, child: Text('—')), ...users.map((u) => DropdownMenuItem(value: u['id'] as String, child: Text(regUserName(u))))],
        onChanged: (v) => setState(() => responsableId = v),
      ),
      const SizedBox(height: 12),
      TextField(controller: frequence, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('regulatory.reqForm.frequenceReeval'), border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: preuveAttendue, decoration: InputDecoration(labelText: t('regulatory.reqForm.preuveAttendue'), border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: commentaire, maxLines: 2, decoration: InputDecoration(labelText: t('regulatory.field.commentaire'), border: const OutlineInputBorder())),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
      const SizedBox(height: 20),
      FilledButton(onPressed: busy ? null : submit, child: busy ? const CircularProgressIndicator() : Text(t('regulatory.save'))),
    ]),
  );
}

class RegulatoryRequirementDetailPage extends StatefulWidget {
  final String requirementId;
  const RegulatoryRequirementDetailPage({super.key, required this.requirementId});
  @override
  State<RegulatoryRequirementDetailPage> createState() => _RegulatoryRequirementDetailPageState();
}

class _RegulatoryRequirementDetailPageState extends State<RegulatoryRequirementDetailPage> {
  final api = Api();
  Map? req;
  bool loading = true;
  bool busy = false;
  String? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try { req = Map.from(await api.get('/business/regulatory-requirements/${widget.requirementId}')); }
    catch (e) { error = '$e'; }
    setState(() => loading = false);
  }

  Future<void> generateNc() async {
    setState(() => busy = true);
    try {
      await api.post('/business/regulatory-requirements/${widget.requirementId}/generate-nc', {});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('regulatory.detail.ncCreatedMsg'))));
      await load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    setState(() => busy = false);
  }

  Future<void> unlinkRisk(String linkId) async {
    try { await api.delete('/business/regulatory-requirement-risks/$linkId'); load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  Future<void> unlinkDocument(String linkId) async {
    try { await api.delete('/business/regulatory-requirement-documents/$linkId'); load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  Future<void> deleteEvidence(String id, String label) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: Text(t('regulatory.confirmDeleteTitle')), content: Text(t('regulatory.detail.deletePreuveConfirm', {'label': label})),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t('regulatory.cancel'))), TextButton(onPressed: () => Navigator.pop(context, true), child: Text(t('regulatory.delete')))],
    ));
    if (ok != true) return;
    try { await api.delete('/business/regulatory-evidences/$id'); load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  @override
  Widget build(BuildContext c) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (error != null) return Scaffold(body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!), TextButton(onPressed: load, child: Text(t('regulatory.retry')))])));
    final r = req!;
    final evidences = List.from(r['evidences'] ?? []);
    final evaluations = List.from(r['evaluations'] ?? []);
    final nonConformities = List.from(r['nonConformities'] ?? []);
    final actions = List.from(r['actions'] ?? []);
    final requirementRisks = List.from(r['requirementRisks'] ?? []);
    final requirementDocuments = List.from(r['requirementDocuments'] ?? []);
    return Scaffold(
      appBar: AppBar(title: Text(r['code'] ?? ''), actions: [
        IconButton(icon: const Icon(Icons.edit), onPressed: () async {
          final saved = await Navigator.push<bool>(c, MaterialPageRoute(builder: (_) => RegulatoryRequirementFormPage(record: r)));
          if (saved == true) load();
        }),
      ]),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Text(r['libelle'] ?? '', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('${r['text']?['titre'] ?? ''}${r['domain'] != null ? ' • ${r['domain']['label']}' : ''}${r['site'] != null ? ' • ${r['site']['name']}' : ''}', style: TextStyle(fontSize: 12, color: QhseColors.textSecondary)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            regChip(regApplicabiliteLabel(r['applicabilite']?.toString()), regApplicabiliteColor(r['applicabilite'])),
            if (r['statutConformite'] != null) regChip(regStatutConformiteLabel(r['statutConformite']?.toString()), regConformiteColor(r['statutConformite'])),
            regChip(regStatutFileLabel(r['statutFile']?.toString()), QhseColors.blue),
            if (r['criticite'] != null) regChip(regCriticiteLabel(r['criticite']?.toString()), QhseColors.amber),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton(onPressed: () async { final ok = await Navigator.push<bool>(c, MaterialPageRoute(builder: (_) => RegulatoryApplicabiliteFormPage(requirement: r))); if (ok == true) load(); }, child: Text(t('regulatory.detail.statuerApplicabiliteBtn'))),
            OutlinedButton(onPressed: () async { final ok = await Navigator.push<bool>(c, MaterialPageRoute(builder: (_) => RegulatoryEvaluationFormPage(requirementId: r['id']))); if (ok == true) load(); }, child: Text(t('regulatory.detail.nouvelleEvaluationBtn'))),
            OutlinedButton(onPressed: () async { final ok = await Navigator.push<bool>(c, MaterialPageRoute(builder: (_) => RegulatoryEvidenceFormPage(requirementId: r['id']))); if (ok == true) load(); }, child: Text(t('regulatory.detail.ajouterPreuveBtn'))),
            OutlinedButton(onPressed: () async { final ok = await Navigator.push<bool>(c, MaterialPageRoute(builder: (_) => RegulatoryLinkRiskFormPage(requirementId: r['id']))); if (ok == true) load(); }, child: Text(t('regulatory.detail.lierRisqueBtn'))),
            OutlinedButton(onPressed: () async { final ok = await Navigator.push<bool>(c, MaterialPageRoute(builder: (_) => RegulatoryGenerateActionFormPage(requirement: r))); if (ok == true) load(); }, child: Text(t('regulatory.detail.creerActionBtn'))),
            if (requirementRisks.isNotEmpty) OutlinedButton(onPressed: () async { final ok = await Navigator.push<bool>(c, MaterialPageRoute(builder: (_) => RegulatoryReevalFormPage(requirement: r))); if (ok == true) load(); }, child: Text(t('regulatory.detail.demanderReevalBtn'))),
            FilledButton(onPressed: busy ? null : generateNc, style: FilledButton.styleFrom(backgroundColor: QhseColors.red), child: Text(t('regulatory.detail.creerNcBtn'))),
          ]),
          if (r['justificatifApplicabilite'] != null && '${r['justificatifApplicabilite']}'.isNotEmpty) ...[
            regSectionTitle(t('regulatory.detail.justificationTitle')),
            Text(r['justificatifApplicabilite']),
          ],
          regSectionTitle(t('regulatory.detail.preuveAttendueTitle')),
          Text(r['preuveAttendue'] ?? '—'),
          regSectionTitle(t('regulatory.detail.preuvesSection', {'count': '${evidences.length}'})),
          if (evidences.isEmpty) regEmpty(t('regulatory.empty.preuves'))
          else ...evidences.map((e) => Card(child: ListTile(
            title: Text(e['nom'] ?? e['type'] ?? t('regulatory.alerts.preuveDefault')),
            subtitle: Text(t('regulatory.detail.expireLine', {'date': regFmtDate(e['dateExpiration']), 'responsable': regUserName(e['responsable'])})),
            trailing: regChip(regEvidenceStatutLabel(e['statut']?.toString()), regEvidenceColor(e['statut'])),
            onTap: () async {
              final choice = await showDialog<String>(context: c, builder: (_) => SimpleDialog(children: [
                SimpleDialogOption(onPressed: () => Navigator.pop(c, 'edit'), child: Text(t('regulatory.edit'))),
                SimpleDialogOption(onPressed: () => Navigator.pop(c, 'delete'), child: Text(t('regulatory.delete'))),
              ]));
              if (choice == 'edit') { final ok = await Navigator.push<bool>(c, MaterialPageRoute(builder: (_) => RegulatoryEvidenceFormPage(requirementId: r['id'], record: e))); if (ok == true) load(); }
              else if (choice == 'delete') deleteEvidence(e['id'], e['nom'] ?? t('regulatory.alerts.preuveDefault'));
            },
          ))),
          regSectionTitle(t('regulatory.detail.evaluationsSection', {'count': '${evaluations.length}'})),
          if (evaluations.isEmpty) regEmpty(t('regulatory.empty.evaluations'))
          else ...evaluations.map((ev) => Card(child: ListTile(
            leading: Icon(Icons.fact_check, color: regConformiteColor(ev['statut'] == 'NON_CONFORME' ? 'NON_CONFORME' : (ev['statut'] == 'PARTIEL' ? 'PARTIEL' : 'CONFORME'))),
            title: Text(regStatutConformiteLabel(ev['statut']?.toString())),
            subtitle: Text('${regFmtDate(ev['dateControle'])}${ev['constat'] != null ? ' — ${ev['constat']}' : ''}'),
          ))),
          regSectionTitle(t('regulatory.section.risquesLies', {'count': '${requirementRisks.length}'})),
          if (requirementRisks.isEmpty) regEmpty(t('regulatory.empty.risques'))
          else ...requirementRisks.map((rr) => Card(child: ListTile(
            title: Text('${rr['risk']['code']} — ${rr['risk']['hazard']}'),
            trailing: IconButton(icon: const Icon(Icons.link_off), onPressed: () => unlinkRisk(rr['id'])),
          ))),
          regSectionTitle(t('regulatory.section.documentsLies', {'count': '${requirementDocuments.length}'})),
          if (requirementDocuments.isEmpty) regEmpty(t('regulatory.empty.documents'))
          else ...requirementDocuments.map((rd) => Card(child: ListTile(
            title: Text(rd['document']?['title'] ?? rd['document']?['name'] ?? ''),
            trailing: IconButton(icon: const Icon(Icons.link_off), onPressed: () => unlinkDocument(rd['id'])),
          ))),
          regSectionTitle(t('regulatory.detail.ncSection', {'count': '${nonConformities.length}'})),
          if (nonConformities.isEmpty) regEmpty(t('regulatory.empty.nc'))
          else ...nonConformities.map((n) => Card(child: ListTile(leading: const Icon(Icons.report, color: Colors.red), title: Text(n['title'] ?? ''), subtitle: Text('${n['code']} • ${n['status']}')))),
          regSectionTitle(t('regulatory.detail.actionsSection', {'count': '${actions.length}'})),
          if (actions.isEmpty) regEmpty(t('regulatory.empty.actions'))
          else ...actions.map((a) => Card(child: ListTile(leading: const Icon(Icons.task_alt), title: Text(a['title'] ?? ''), subtitle: Text('${a['code']} • ${a['status']}${a['dueDate'] != null ? ' • ${t('regulatory.echeanceInline', {'date': regFmtDate(a['dueDate'])})}' : ''}')))),
        ]),
      ),
    );
  }
}

class RegulatoryApplicabiliteFormPage extends StatefulWidget {
  final Map requirement;
  const RegulatoryApplicabiliteFormPage({super.key, required this.requirement});
  @override
  State<RegulatoryApplicabiliteFormPage> createState() => _RegulatoryApplicabiliteFormPageState();
}

class _RegulatoryApplicabiliteFormPageState extends State<RegulatoryApplicabiliteFormPage> {
  final api = Api();
  late String applicabilite = widget.requirement['applicabilite'] ?? 'A_ANALYSER';
  late final justificatif = TextEditingController(text: widget.requirement['justificatifApplicabilite'] ?? '');
  bool busy = false;
  String? error;

  bool get requiresJustification => applicabilite == 'NON' || applicabilite == 'PARTIELLEMENT';

  Future<void> submit() async {
    if (requiresJustification && justificatif.text.trim().isEmpty) {
      setState(() => error = t('regulatory.applicForm.justificationRequiredMsg'));
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      await api.post('/business/regulatory-requirements/${widget.requirement['id']}/applicability', {'applicabilite': applicabilite, 'justificatif': justificatif.text.trim().isEmpty ? null : justificatif.text.trim()});
      if (mounted) Navigator.pop(context, true);
    } catch (e) { setState(() { busy = false; error = '$e'; }); }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text(t('regulatory.applicForm.title'))),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      DropdownButtonFormField<String>(
        value: applicabilite,
        decoration: InputDecoration(labelText: t('regulatory.filter.applicabilite'), border: const OutlineInputBorder()),
        items: regApplicabiliteValues.map((k) => DropdownMenuItem(value: k, child: Text(regApplicabiliteLabel(k)))).toList(),
        onChanged: (v) => setState(() => applicabilite = v ?? applicabilite),
      ),
      const SizedBox(height: 12),
      TextField(controller: justificatif, maxLines: 4, decoration: InputDecoration(
        labelText: requiresJustification ? t('regulatory.applicForm.justificationRequired') : t('regulatory.applicForm.justification'),
        hintText: t('regulatory.applicForm.justificationHint'),
        border: const OutlineInputBorder(),
      )),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
      const SizedBox(height: 20),
      FilledButton(onPressed: busy ? null : submit, child: busy ? const CircularProgressIndicator() : Text(t('regulatory.valider'))),
    ]),
  );
}

class RegulatoryEvaluationFormPage extends StatefulWidget {
  final String requirementId;
  const RegulatoryEvaluationFormPage({super.key, required this.requirementId});
  @override
  State<RegulatoryEvaluationFormPage> createState() => _RegulatoryEvaluationFormPageState();
}

class _RegulatoryEvaluationFormPageState extends State<RegulatoryEvaluationFormPage> {
  final api = Api();
  String statut = 'CONFORME';
  DateTime dateControle = DateTime.now();
  final constat = TextEditingController();
  final preuveExaminee = TextEditingController();
  final personneInterrogee = TextEditingController();
  final observation = TextEditingController();
  final commentaire = TextEditingController();
  bool busy = false;
  String? error;

  Future<void> pickDate() async {
    final d = await showDatePicker(context: context, initialDate: dateControle, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 30)));
    if (d != null) setState(() => dateControle = d);
  }

  Future<void> submit() async {
    setState(() { busy = true; error = null; });
    final payload = {
      'statut': statut, 'dateControle': dateControle.toIso8601String(),
      'constat': constat.text.trim().isEmpty ? null : constat.text.trim(),
      'preuveExaminee': preuveExaminee.text.trim().isEmpty ? null : preuveExaminee.text.trim(),
      'personneInterrogee': personneInterrogee.text.trim().isEmpty ? null : personneInterrogee.text.trim(),
      'observation': observation.text.trim().isEmpty ? null : observation.text.trim(),
      'commentaire': commentaire.text.trim().isEmpty ? null : commentaire.text.trim(),
    };
    try {
      await api.post('/business/regulatory-requirements/${widget.requirementId}/evaluations', payload);
      if (mounted) Navigator.pop(context, true);
    } catch (e) { setState(() { busy = false; error = '$e'; }); }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text(t('regulatory.evalForm.title'))),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      DropdownButtonFormField<String>(
        value: statut,
        decoration: InputDecoration(labelText: t('regulatory.field.statut'), border: const OutlineInputBorder()),
        items: regStatutConformiteValues.map((k) => DropdownMenuItem(value: k, child: Text(regStatutConformiteLabel(k)))).toList(),
        onChanged: (v) => setState(() => statut = v ?? statut),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: pickDate, icon: const Icon(Icons.event), label: Text(t('regulatory.evalForm.dateControle', {'date': regFmtDate(dateControle.toIso8601String())}))),
      const SizedBox(height: 12),
      TextField(controller: constat, maxLines: 2, decoration: InputDecoration(labelText: t('regulatory.evalForm.constat'), border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: preuveExaminee, decoration: InputDecoration(labelText: t('regulatory.evalForm.preuveExaminee'), border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: personneInterrogee, decoration: InputDecoration(labelText: t('regulatory.evalForm.personneInterrogee'), border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: observation, maxLines: 2, decoration: InputDecoration(labelText: t('regulatory.evalForm.observation'), border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: commentaire, maxLines: 2, decoration: InputDecoration(labelText: t('regulatory.field.commentaire'), border: const OutlineInputBorder())),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
      const SizedBox(height: 20),
      FilledButton(onPressed: busy ? null : submit, child: busy ? const CircularProgressIndicator() : Text(t('regulatory.evalForm.submitBtn'))),
    ]),
  );
}

class RegulatoryEvidenceFormPage extends StatefulWidget {
  final String requirementId;
  final Map? record;
  const RegulatoryEvidenceFormPage({super.key, required this.requirementId, this.record});
  @override
  State<RegulatoryEvidenceFormPage> createState() => _RegulatoryEvidenceFormPageState();
}

class _RegulatoryEvidenceFormPageState extends State<RegulatoryEvidenceFormPage> {
  final api = Api();
  late final type = TextEditingController(text: widget.record?['type'] ?? '');
  late final nom = TextEditingController(text: widget.record?['nom'] ?? '');
  late final commentaire = TextEditingController(text: widget.record?['commentaire'] ?? '');
  List users = [];
  String? responsableId;
  DateTime? dateEmission;
  DateTime? dateExpiration;
  bool busy = false;
  String? error;

  bool get editing => widget.record != null;

  @override
  void initState() {
    super.initState();
    responsableId = widget.record?['responsableId'];
    if (widget.record?['dateEmission'] != null) dateEmission = DateTime.parse(widget.record!['dateEmission']);
    if (widget.record?['dateExpiration'] != null) dateExpiration = DateTime.parse(widget.record!['dateExpiration']);
    api.get('/users').then((v) { if (mounted) setState(() => users = List.from(v)); }).catchError((_) {});
  }

  Future<void> pickDate(bool expiration) async {
    final d = await showDatePicker(context: context, initialDate: (expiration ? dateExpiration : dateEmission) ?? DateTime.now(), firstDate: DateTime(2015), lastDate: DateTime.now().add(const Duration(days: 3650)));
    if (d == null) return;
    setState(() { if (expiration) dateExpiration = d; else dateEmission = d; });
  }

  Future<void> submit() async {
    setState(() { busy = true; error = null; });
    final payload = {
      'type': type.text.trim().isEmpty ? null : type.text.trim(), 'nom': nom.text.trim().isEmpty ? null : nom.text.trim(),
      'dateEmission': dateEmission?.toIso8601String(), 'dateExpiration': dateExpiration?.toIso8601String(),
      'responsableId': responsableId, 'commentaire': commentaire.text.trim().isEmpty ? null : commentaire.text.trim(),
    };
    try {
      if (editing) await api.patch('/business/regulatory-evidences/${widget.record!['id']}', payload);
      else await api.post('/business/regulatory-requirements/${widget.requirementId}/evidences', payload);
      if (mounted) Navigator.pop(context, true);
    } catch (e) { setState(() { busy = false; error = '$e'; }); }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text(editing ? t('regulatory.evidenceForm.editTitle') : t('regulatory.evidenceForm.createTitle'))),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      TextField(controller: type, decoration: InputDecoration(labelText: t('regulatory.evidenceForm.type'), border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: nom, decoration: InputDecoration(labelText: t('regulatory.evidenceForm.nom'), border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: () => pickDate(false), icon: const Icon(Icons.event), label: Text(dateEmission == null ? t('regulatory.evidenceForm.emission') : regFmtDate(dateEmission!.toIso8601String())))),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton.icon(onPressed: () => pickDate(true), icon: const Icon(Icons.event_busy), label: Text(dateExpiration == null ? t('regulatory.evidenceForm.expiration') : regFmtDate(dateExpiration!.toIso8601String())))),
      ]),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: users.any((u) => u['id'] == responsableId) ? responsableId : null,
        decoration: InputDecoration(labelText: t('regulatory.field.responsable'), border: const OutlineInputBorder()),
        items: [const DropdownMenuItem(value: null, child: Text('—')), ...users.map((u) => DropdownMenuItem(value: u['id'] as String, child: Text(regUserName(u))))],
        onChanged: (v) => setState(() => responsableId = v),
      ),
      const SizedBox(height: 12),
      TextField(controller: commentaire, maxLines: 2, decoration: InputDecoration(labelText: t('regulatory.field.commentaire'), border: const OutlineInputBorder())),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
      const SizedBox(height: 20),
      FilledButton(onPressed: busy ? null : submit, child: busy ? const CircularProgressIndicator() : Text(t('regulatory.save'))),
    ]),
  );
}

class RegulatoryLinkRiskFormPage extends StatefulWidget {
  final String requirementId;
  const RegulatoryLinkRiskFormPage({super.key, required this.requirementId});
  @override
  State<RegulatoryLinkRiskFormPage> createState() => _RegulatoryLinkRiskFormPageState();
}

class _RegulatoryLinkRiskFormPageState extends State<RegulatoryLinkRiskFormPage> {
  final api = Api();
  final note = TextEditingController();
  List risks = [];
  String? riskId;
  bool busy = false;
  String? error;

  @override
  void initState() { super.initState(); api.get('/business/risks').then((v) { if (mounted) setState(() => risks = List.from(v)); }).catchError((_) {}); }

  Future<void> submit() async {
    if (riskId == null) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('regulatory.linkRiskForm.chooseRisk')))); return; }
    setState(() { busy = true; error = null; });
    try {
      await api.post('/business/regulatory-requirements/${widget.requirementId}/link-risk', {'riskId': riskId, 'note': note.text.trim().isEmpty ? null : note.text.trim()});
      if (mounted) Navigator.pop(context, true);
    } catch (e) { setState(() { busy = false; error = '$e'; }); }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text(t('regulatory.linkRiskForm.title'))),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      DropdownButtonFormField<String>(
        value: riskId, isExpanded: true,
        decoration: InputDecoration(labelText: t('regulatory.field.risque'), border: const OutlineInputBorder()),
        items: risks.map<DropdownMenuItem<String>>((r) => DropdownMenuItem(value: r['id'] as String, child: Text('${r['code']} — ${r['hazard']}', overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (v) => setState(() => riskId = v),
      ),
      const SizedBox(height: 12),
      TextField(controller: note, decoration: InputDecoration(labelText: t('regulatory.linkRiskForm.note'), border: const OutlineInputBorder())),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
      const SizedBox(height: 20),
      FilledButton(onPressed: busy ? null : submit, child: busy ? const CircularProgressIndicator() : Text(t('regulatory.lier'))),
    ]),
  );
}

class RegulatoryGenerateActionFormPage extends StatefulWidget {
  final Map requirement;
  const RegulatoryGenerateActionFormPage({super.key, required this.requirement});
  @override
  State<RegulatoryGenerateActionFormPage> createState() => _RegulatoryGenerateActionFormPageState();
}

class _RegulatoryGenerateActionFormPageState extends State<RegulatoryGenerateActionFormPage> {
  final api = Api();
  late final title = TextEditingController();
  final description = TextEditingController();
  List users = [];
  late String? responsibleId = widget.requirement['responsableId'];
  DateTime? dueDate;
  int priority = 2;
  bool busy = false;
  String? error;

  @override
  void initState() { super.initState(); api.get('/users').then((v) { if (mounted) setState(() => users = List.from(v)); }).catchError((_) {}); }

  Future<void> pickDate() async {
    final d = await showDatePicker(context: context, initialDate: dueDate ?? DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 3650)));
    if (d != null) setState(() => dueDate = d);
  }

  Future<void> submit() async {
    setState(() { busy = true; error = null; });
    final payload = {
      'title': title.text.trim().isEmpty ? t('regulatory.actionForm.titreHint', {'libelle': '${widget.requirement['libelle']}'}).substring(0, 60.clamp(0, t('regulatory.actionForm.titreHint', {'libelle': '${widget.requirement['libelle']}'}).length)) : title.text.trim(),
      'description': description.text.trim().isEmpty ? null : description.text.trim(),
      'priority': priority, 'actionType': 'CORRECTIVE', 'responsibleId': responsibleId, 'dueDate': dueDate?.toIso8601String(),
    };
    try {
      await api.post('/business/regulatory-requirements/${widget.requirement['id']}/generate-action', payload);
      if (mounted) Navigator.pop(context, true);
    } catch (e) { setState(() { busy = false; error = '$e'; }); }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text(t('regulatory.detail.creerActionBtn'))),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      TextField(controller: title, decoration: InputDecoration(labelText: t('regulatory.field.titre'), hintText: t('regulatory.actionForm.titreHint', {'libelle': '${widget.requirement['libelle']}'}), border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: description, maxLines: 2, decoration: InputDecoration(labelText: t('regulatory.field.description'), border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: users.any((u) => u['id'] == responsibleId) ? responsibleId : null,
        decoration: InputDecoration(labelText: t('regulatory.field.responsable'), border: const OutlineInputBorder()),
        items: [const DropdownMenuItem(value: null, child: Text('—')), ...users.map((u) => DropdownMenuItem(value: u['id'] as String, child: Text(regUserName(u))))],
        onChanged: (v) => setState(() => responsibleId = v),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: pickDate, icon: const Icon(Icons.event), label: Text(dueDate == null ? t('regulatory.field.echeance') : regFmtDate(dueDate!.toIso8601String()))),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
      const SizedBox(height: 20),
      FilledButton(onPressed: busy ? null : submit, child: busy ? const CircularProgressIndicator() : Text(t('regulatory.actionForm.submitBtn'))),
    ]),
  );
}

class RegulatoryReevalFormPage extends StatefulWidget {
  final Map requirement;
  const RegulatoryReevalFormPage({super.key, required this.requirement});
  @override
  State<RegulatoryReevalFormPage> createState() => _RegulatoryReevalFormPageState();
}

class _RegulatoryReevalFormPageState extends State<RegulatoryReevalFormPage> {
  final api = Api();
  final raison = TextEditingController();
  List users = [];
  String? riskId;
  String? responsableId;
  DateTime? dateLimite;
  bool busy = false;
  String? error;

  List get risks => List.from(widget.requirement['requirementRisks'] ?? []);

  @override
  void initState() {
    super.initState();
    if (risks.isNotEmpty) riskId = risks.first['riskId'];
    responsableId = widget.requirement['responsableId'];
    api.get('/users').then((v) { if (mounted) setState(() => users = List.from(v)); }).catchError((_) {});
  }

  Future<void> pickDate() async {
    final d = await showDatePicker(context: context, initialDate: dateLimite ?? DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 3650)));
    if (d != null) setState(() => dateLimite = d);
  }

  Future<void> submit() async {
    if (riskId == null) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('regulatory.reevalForm.chooseRisk')))); return; }
    setState(() { busy = true; error = null; });
    try {
      await api.post('/business/regulatory-requirements/${widget.requirement['id']}/request-risk-reevaluation', {
        'riskId': riskId, 'raison': raison.text.trim().isEmpty ? null : raison.text.trim(), 'responsableId': responsableId, 'dateLimite': dateLimite?.toIso8601String(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) { setState(() { busy = false; error = '$e'; }); }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text(t('regulatory.reevalForm.title'))),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Text(t('regulatory.reevalForm.hint'), style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: QhseColors.textSecondary)),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: riskId, isExpanded: true,
        decoration: InputDecoration(labelText: t('regulatory.reevalForm.risqueConcerne'), border: const OutlineInputBorder()),
        items: risks.map<DropdownMenuItem<String>>((rr) => DropdownMenuItem(value: rr['riskId'] as String, child: Text('${rr['risk']['code']} — ${rr['risk']['hazard']}', overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (v) => setState(() => riskId = v),
      ),
      const SizedBox(height: 12),
      TextField(controller: raison, maxLines: 3, decoration: InputDecoration(labelText: t('regulatory.reevalForm.raison'), border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: users.any((u) => u['id'] == responsableId) ? responsableId : null,
        decoration: InputDecoration(labelText: t('regulatory.field.responsable'), border: const OutlineInputBorder()),
        items: [const DropdownMenuItem(value: null, child: Text('—')), ...users.map((u) => DropdownMenuItem(value: u['id'] as String, child: Text(regUserName(u))))],
        onChanged: (v) => setState(() => responsableId = v),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: pickDate, icon: const Icon(Icons.event), label: Text(dateLimite == null ? t('regulatory.reevalForm.dateLimite') : regFmtDate(dateLimite!.toIso8601String()))),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
      const SizedBox(height: 20),
      FilledButton(onPressed: busy ? null : submit, child: busy ? const CircularProgressIndicator() : Text(t('regulatory.reevalForm.submitBtn'))),
    ]),
  );
}

// ---------------------------------------------------------------------------
// ALERTES & ÉCHÉANCES
// ---------------------------------------------------------------------------

class RegulatoryAlertsTab extends StatefulWidget {
  const RegulatoryAlertsTab({super.key});
  @override
  State<RegulatoryAlertsTab> createState() => _RegulatoryAlertsTabState();
}

const _regAlertThresholdKeys = ['alerteJ90', 'alerteJ60', 'alerteJ30', 'alerteJ15', 'alerteJ7'];
String _regAlertThresholdLabel(String k) {
  switch (k) {
    case 'alerteJ90': return t('regulatory.alerts.threshold90');
    case 'alerteJ60': return t('regulatory.alerts.threshold60');
    case 'alerteJ30': return t('regulatory.alerts.threshold30');
    case 'alerteJ15': return t('regulatory.alerts.threshold15');
    case 'alerteJ7': return t('regulatory.alerts.threshold7');
    default: return k;
  }
}

class _RegulatoryAlertsTabState extends State<RegulatoryAlertsTab> {
  final api = Api();
  Map? alerts;
  Map? settings;
  bool loading = true;
  String? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      alerts = Map.from(await api.get('/business/regulatory-alerts'));
      settings = Map.from(await api.get('/business/regulatory-settings'));
    }
    catch (e) { error = '$e'; }
    setState(() => loading = false);
  }

  Future<void> _toggleSetting(String key) async {
    if (settings == null) return;
    try {
      await api.patch('/business/regulatory-settings', {key: !(settings![key] == true)});
      settings = Map.from(await api.get('/business/regulatory-settings'));
      if (mounted) setState(() {});
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  @override
  Widget build(BuildContext c) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!), TextButton(onPressed: load, child: Text(t('regulatory.retry')))]));
    final echeancesEvaluation = List.from(alerts!['echeancesEvaluation'] ?? []);
    final echeancesPreuves = List.from(alerts!['echeancesPreuves'] ?? []);
    final nouvellesExigences = List.from(alerts!['nouvellesExigences'] ?? []);
    final actionsEnRetard = List.from(alerts!['actionsEnRetard'] ?? []);
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(padding: const EdgeInsets.all(12), children: [
        regSectionTitle(t('regulatory.alerts.thresholdsTitle')),
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Wrap(spacing: 12, runSpacing: 4, children: [
          for (final k in _regAlertThresholdKeys)
            FilterChip(
              label: Text(_regAlertThresholdLabel(k), style: const TextStyle(fontSize: 12)),
              selected: settings?[k] == true,
              onSelected: (_) => _toggleSetting(k),
            ),
        ]))),
        regSectionTitle(t('regulatory.alerts.echeancesEvalSection', {'count': '${echeancesEvaluation.length}'})),
        if (echeancesEvaluation.isEmpty) regEmpty(t('regulatory.alerts.echeancesEvalEmpty'))
        else ...echeancesEvaluation.map((a) => Card(child: ListTile(
          leading: Icon(Icons.event_busy, color: regAlertNiveauColor(a['niveau'])),
          title: Text('${a['code']} — ${a['libelle']}', maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${a['texte']} • ${a['jours'] < 0 ? t('regulatory.alerts.retardJours', {'value': '${-a['jours']}'}) : t('regulatory.alerts.dansJours', {'value': '${a['jours']}'})} • ${regUserName(a['responsable'])}'),
          onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => RegulatoryRequirementDetailPage(requirementId: a['requirementId']))),
        ))),
        regSectionTitle(t('regulatory.alerts.echeancesPreuvesSection', {'count': '${echeancesPreuves.length}'})),
        if (echeancesPreuves.isEmpty) regEmpty(t('regulatory.alerts.echeancesPreuvesEmpty'))
        else ...echeancesPreuves.map((a) => Card(child: ListTile(
          leading: Icon(Icons.description, color: regAlertNiveauColor(a['niveau'])),
          title: Text('${a['nom'] ?? t('regulatory.alerts.preuveDefault')} — ${a['code']}', maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${a['libelle']} • ${a['jours'] < 0 ? t('regulatory.alerts.retardJours', {'value': '${-a['jours']}'}) : t('regulatory.alerts.dansJours', {'value': '${a['jours']}'})}'),
          onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => RegulatoryRequirementDetailPage(requirementId: a['requirementId']))),
        ))),
        regSectionTitle(t('regulatory.alerts.nouvellesExigencesSection', {'count': '${nouvellesExigences.length}'})),
        if (nouvellesExigences.isEmpty) regEmpty(t('regulatory.alerts.nouvellesExigencesEmpty'))
        else ...nouvellesExigences.map((r) => Card(child: ListTile(
          leading: const Icon(Icons.fiber_new),
          title: Text(r['libelle'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(r['text']?['titre'] ?? ''),
          onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => RegulatoryRequirementDetailPage(requirementId: r['id']))),
        ))),
        regSectionTitle(t('regulatory.alerts.actionsRetardSection', {'count': '${actionsEnRetard.length}'})),
        if (actionsEnRetard.isEmpty) regEmpty(t('regulatory.alerts.actionsRetardEmpty'))
        else ...actionsEnRetard.map((a) => Card(child: ListTile(leading: const Icon(Icons.warning, color: Colors.red), title: Text(a['title'] ?? ''), subtitle: Text('${a['code']} • ${t('regulatory.echeanceInline', {'date': regFmtDate(a['dueDate'])})} • ${regUserName(a['responsible'])}')))),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// RÉÉVALUATIONS DES RISQUES
// ---------------------------------------------------------------------------

class RegulatoryReevaluationsTab extends StatefulWidget {
  const RegulatoryReevaluationsTab({super.key});
  @override
  State<RegulatoryReevaluationsTab> createState() => _RegulatoryReevaluationsTabState();
}

class _RegulatoryReevaluationsTabState extends State<RegulatoryReevaluationsTab> {
  final api = Api();
  List items = [];
  bool loading = true;
  String? error;

  static const statutsValues = ['A_PLANIFIER', 'PLANIFIEE', 'REALISEE', 'ANNULEE'];
  static String statutLabel(String? k) => k == null ? '—' : (statutsValues.contains(k) ? t('regulatory.reevalStatut.$k') : k);

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try { items = List.from(await api.get('/business/regulatory-risk-reevaluations')); }
    catch (e) { error = '$e'; }
    setState(() => loading = false);
  }

  Future<void> updateStatut(String id, String statut) async {
    try { await api.patch('/business/regulatory-risk-reevaluations/$id', {'statut': statut}); load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  @override
  Widget build(BuildContext c) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!), TextButton(onPressed: load, child: Text(t('regulatory.retry')))]));
    return RefreshIndicator(
      onRefresh: load,
      child: items.isEmpty
          ? ListView(children: [regEmpty(t('regulatory.reevaluations.empty'))])
          : ListView.builder(padding: const EdgeInsets.all(12), itemCount: items.length, itemBuilder: (_, i) {
              final d = items[i];
              return Card(child: ListTile(
                title: Text('${d['risk']?['code'] ?? ''} — ${d['risk']?['hazard'] ?? ''}'),
                subtitle: Text('${d['requirement']?['code'] ?? ''} • ${d['raison'] ?? t('regulatory.reevaluations.sansRaison')}${d['dateLimite'] != null ? ' • ${t('regulatory.reevaluations.limiteInline', {'date': regFmtDate(d['dateLimite'])})}' : ''}'),
                trailing: DropdownButton<String>(
                  value: d['statut'],
                  items: statutsValues.map((k) => DropdownMenuItem(value: k, child: Text(statutLabel(k)))).toList(),
                  onChanged: (v) { if (v != null) updateStatut(d['id'], v); },
                ),
                onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => RegulatoryRequirementDetailPage(requirementId: d['requirementId']))),
              ));
            }),
    );
  }
}

// ---------------------------------------------------------------------------
// RAPPORTS — même logique d'agrégation côté client que le tableau de bord
// web (aucune donnée dupliquée, aucun nouvel endpoint) : taux de conformité
// par domaine/site à partir de la liste complète des exigences.
// ---------------------------------------------------------------------------

Map<String, dynamic> regComplianceRate(List list) {
  final applicables = list.where((r) => r['applicabilite'] == 'OUI' || r['applicabilite'] == 'PARTIELLEMENT').toList();
  final evaluees = applicables.where((r) => r['statutConformite'] != null).toList();
  final conformes = evaluees.where((r) => r['statutConformite'] == 'CONFORME').toList();
  final taux = evaluees.isEmpty ? null : (conformes.length / evaluees.length * 1000).round() / 10;
  return {'total': list.length, 'applicables': applicables.length, 'evaluees': evaluees.length, 'conformes': conformes.length, 'taux': taux};
}

List<Map<String, dynamic>> regGroupCompliance(List list, String? Function(Map) keyFn, String Function(List) labelFn) {
  final groups = <String, List>{};
  for (final r in list) { final key = keyFn(r) ?? '__none__'; (groups[key] ??= []).add(r); }
  return groups.entries.map((e) => {'label': labelFn(e.value), ...regComplianceRate(e.value)}).toList();
}

class RegulatoryReportsTab extends StatefulWidget {
  const RegulatoryReportsTab({super.key});
  @override
  State<RegulatoryReportsTab> createState() => _RegulatoryReportsTabState();
}

class _RegulatoryReportsTabState extends State<RegulatoryReportsTab> {
  final api = Api();
  List items = [];
  bool loading = true;
  String? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try { items = List.from(await api.get('/business/regulatory-requirements')); }
    catch (e) { error = '$e'; }
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext c) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!), TextButton(onPressed: load, child: Text(t('regulatory.retry')))]));
    final global = regComplianceRate(items);
    final byDomain = regGroupCompliance(items, (r) => r['domainId'] as String?, (l) => l.first['domain']?['label'] ?? t('regulatory.sansDomaine'));
    final bySite = regGroupCompliance(items, (r) => r['siteId'] as String?, (l) => l.first['site']?['name'] ?? t('regulatory.sansSite'));
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(padding: const EdgeInsets.all(12), children: [
        Row(children: [
          regKpi(t('regulatory.kpi.exigences'), '${global['total']}', QhseColors.blue),
          const SizedBox(width: 8),
          regKpi(t('regulatory.kpi.applicables'), '${global['applicables']}', QhseColors.blue),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          regKpi(t('regulatory.kpi.evaluees'), '${global['evaluees']}', QhseColors.amber),
          const SizedBox(width: 8),
          regKpi(t('regulatory.kpi.tauxConformite'), global['taux'] != null ? '${global['taux']}%' : '—', QhseColors.green),
        ]),
        regSectionTitle(t('regulatory.reports.byDomainTitle')),
        if (byDomain.isEmpty) regEmpty(t('regulatory.noData'))
        else ...byDomain.map((g) => ListTile(dense: true, title: Text(g['label']), trailing: Text(g['taux'] != null ? '${g['taux']}% (${g['conformes']}/${g['evaluees']})' : '—'))),
        regSectionTitle(t('regulatory.reports.bySiteTitle')),
        if (bySite.isEmpty) regEmpty(t('regulatory.noData'))
        else ...bySite.map((g) => ListTile(dense: true, title: Text(g['label']), trailing: Text(g['taux'] != null ? '${g['taux']}% (${g['conformes']}/${g['evaluees']})' : '—'))),
        regSectionTitle(t('regulatory.reports.matriceTitle', {'count': '${items.length}'})),
        Text(t('regulatory.reports.exportHint'), style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: QhseColors.textSecondary)),
        const SizedBox(height: 8),
        ...items.map((r) => Card(child: ListTile(
          dense: true,
          title: Text('${r['code']} — ${r['libelle']}', maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${r['domain']?['label'] ?? '—'} • ${r['site']?['name'] ?? '—'}'),
          trailing: regChip(regApplicabiliteLabel(r['applicabilite']?.toString()), regApplicabiliteColor(r['applicabilite'])),
          onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => RegulatoryRequirementDetailPage(requirementId: r['id']))),
        ))),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// DOMAINES RÉGLEMENTAIRES
// ---------------------------------------------------------------------------

class RegulatoryDomainsTab extends StatefulWidget {
  const RegulatoryDomainsTab({super.key});
  @override
  State<RegulatoryDomainsTab> createState() => _RegulatoryDomainsTabState();
}

class _RegulatoryDomainsTabState extends State<RegulatoryDomainsTab> {
  final api = Api();
  List items = [];
  bool loading = true;
  String? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try { items = List.from(await api.get('/business/regulatory-domains')); }
    catch (e) { error = '$e'; }
    setState(() => loading = false);
  }

  Future<void> openForm({Map? record}) async {
    final saved = await showDialog<bool>(context: context, builder: (_) => RegulatoryDomainDialog(record: record));
    if (saved == true) load();
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(onPressed: () => openForm(), icon: const Icon(Icons.add), label: Text(t('regulatory.domains.newBtn'))),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!), TextButton(onPressed: load, child: Text(t('regulatory.retry')))]))
              : RefreshIndicator(onRefresh: load, child: items.isEmpty
                  ? ListView(children: [regEmpty(t('regulatory.domains.empty'))])
                  : ListView.builder(padding: const EdgeInsets.all(12), itemCount: items.length, itemBuilder: (_, i) {
                      final d = items[i];
                      return Card(child: ListTile(
                        title: Text('${d['code']} — ${d['label']}'),
                        trailing: regChip(d['actif'] == true ? t('regulatory.domains.actif') : t('regulatory.domains.inactif'), d['actif'] == true ? QhseColors.green : QhseColors.textSecondary),
                        onTap: () => openForm(record: d),
                      ));
                    })),
    );
  }
}

class RegulatoryDomainDialog extends StatefulWidget {
  final Map? record;
  const RegulatoryDomainDialog({super.key, this.record});
  @override
  State<RegulatoryDomainDialog> createState() => _RegulatoryDomainDialogState();
}

class _RegulatoryDomainDialogState extends State<RegulatoryDomainDialog> {
  final api = Api();
  late final code = TextEditingController(text: widget.record?['code'] ?? '');
  late final label = TextEditingController(text: widget.record?['label'] ?? '');
  late bool actif = widget.record?['actif'] ?? true;
  bool busy = false;
  String? error;

  bool get editing => widget.record != null;

  Future<void> submit() async {
    if (code.text.trim().isEmpty || label.text.trim().isEmpty) { setState(() => error = t('regulatory.domains.validationMsg')); return; }
    setState(() { busy = true; error = null; });
    final payload = {'code': code.text.trim(), 'label': label.text.trim(), 'actif': actif};
    try {
      if (editing) await api.patch('/business/regulatory-domains/${widget.record!['id']}', payload);
      else await api.post('/business/regulatory-domains', payload);
      if (mounted) Navigator.pop(context, true);
    } catch (e) { setState(() { busy = false; error = '$e'; }); }
  }

  @override
  Widget build(BuildContext c) => AlertDialog(
    title: Text(editing ? t('regulatory.domains.editTitle') : t('regulatory.domains.newBtn')),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: code, decoration: InputDecoration(labelText: t('regulatory.field.code'))),
      const SizedBox(height: 8),
      TextField(controller: label, decoration: InputDecoration(labelText: t('regulatory.field.libelle'))),
      const SizedBox(height: 8),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(t('regulatory.domains.actif')), value: actif, onChanged: (v) => setState(() => actif = v)),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12))),
    ]),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t('regulatory.cancel'))),
      FilledButton(onPressed: busy ? null : submit, child: Text(t('regulatory.save'))),
    ],
  );
}
