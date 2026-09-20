import 'package:flutter/material.dart';
import '../services/api.dart';
import '../theme.dart';
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

const regApplicabiliteLabels = {'OUI': 'Applicable', 'NON': 'Non applicable', 'PARTIELLEMENT': 'Partiellement applicable', 'A_ANALYSER': 'À analyser'};
const regStatutConformiteLabels = {'CONFORME': 'Conforme', 'PARTIEL': 'Partiellement conforme', 'NON_CONFORME': 'Non conforme'};
const regStatutFileLabels = {
  'NOUVEAU': 'Nouveau', 'A_ANALYSER': 'À analyser', 'APPLICABILITE_A_DETERMINER': 'Applicabilité à déterminer',
  'EVALUATION_A_REALISER': 'Évaluation à réaliser', 'VERIFICATION': 'Vérification', 'ACTIONS_NECESSAIRES': 'Actions nécessaires', 'CLOTURE': 'Clôturé',
};
const regEvidenceStatutLabels = {'VALIDE': 'Valide', 'EXPIRE_BIENTOT': 'Expire bientôt', 'A_RENOUVELER': 'À renouveler', 'EXPIRE': 'Expiré'};
const regCriticiteLabels = {'CRITIQUE': 'Critique', 'HAUTE': 'Haute', 'MOYENNE': 'Moyenne', 'FAIBLE': 'Faible'};

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
          title: const Text('Veille réglementaire'),
          bottom: const TabBar(isScrollable: true, tabs: [
            Tab(text: 'Tableau de bord'), Tab(text: 'Textes'), Tab(text: 'Exigences'), Tab(text: 'Alertes'),
            Tab(text: 'Réévaluations'), Tab(text: 'Rapports'), Tab(text: 'Domaines'), Tab(text: 'Catalogue simple (ancien)'),
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
    if (error != null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!), TextButton(onPressed: load, child: const Text('Réessayer'))]));
    if (dash == null) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(padding: const EdgeInsets.all(12), children: [
        Row(children: [
          regKpi('Exigences totales', '${dash!['total'] ?? 0}', QhseColors.blue),
          const SizedBox(width: 8),
          regKpi('Applicables', '${dash!['applicables'] ?? 0}', QhseColors.blue),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          regKpi('Taux de conformité', dash!['tauxConformite'] != null ? '${dash!['tauxConformite']}%' : '—', QhseColors.green),
          const SizedBox(width: 8),
          regKpi('À analyser', '${dash!['aAnalyser'] ?? 0}', QhseColors.amber),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          regKpi('Conformes', '${dash!['conformes'] ?? 0}', QhseColors.green),
          const SizedBox(width: 8),
          regKpi('Partielles', '${dash!['partielles'] ?? 0}', QhseColors.amber),
          const SizedBox(width: 8),
          regKpi('Non conformes', '${dash!['nonConformes'] ?? 0}', QhseColors.red),
        ]),
        regSectionTitle('Non encore évaluées'),
        Text('${dash!['nonEvaluees'] ?? 0} exigence(s) applicable(s) sans évaluation enregistrée.'),
        regSectionTitle('Méthode de calcul'),
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
        icon: const Icon(Icons.add), label: const Text('Nouveau texte'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!), TextButton(onPressed: load, child: const Text('Réessayer'))]))
              : RefreshIndicator(onRefresh: load, child: items.isEmpty
                  ? ListView(children: [regEmpty('Aucun texte réglementaire enregistré')])
                  : ListView.builder(padding: const EdgeInsets.all(12), itemCount: items.length, itemBuilder: (_, i) {
                      final t = items[i];
                      return Card(child: ListTile(
                        title: Text(t['titre'] ?? ''),
                        subtitle: Text('${t['reference'] ?? t['typeTexte'] ?? '—'} • ${t['domain']?['label'] ?? 'Sans domaine'}'),
                        trailing: regChip(t['statut'] == 'EN_VIGUEUR' ? 'En vigueur' : (t['statut'] == 'ABROGE' ? 'Abrogé' : 'Modifié'), t['statut'] == 'ABROGE' ? QhseColors.red : (t['statut'] == 'MODIFIE' ? QhseColors.amber : QhseColors.green)),
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
    if (titre.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le titre est obligatoire'))); return; }
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
    appBar: AppBar(title: Text(editing ? 'Modifier le texte' : 'Nouveau texte réglementaire')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      TextField(controller: reference, decoration: const InputDecoration(labelText: 'Référence (ex. Loi n°...)', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: titre, decoration: const InputDecoration(labelText: 'Titre *', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: typeTexte, decoration: const InputDecoration(labelText: 'Type de texte (loi, décret, norme...)', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: domains.any((d) => d['id'] == domainId) ? domainId : null,
        decoration: const InputDecoration(labelText: 'Domaine', border: OutlineInputBorder()),
        items: [const DropdownMenuItem(value: null, child: Text('—')), ...domains.map((d) => DropdownMenuItem(value: d['id'] as String, child: Text(d['label'])))],
        onChanged: (v) => setState(() => domainId = v),
      ),
      const SizedBox(height: 12),
      TextField(controller: sousDomaine, decoration: const InputDecoration(labelText: 'Sous-domaine', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: pays, decoration: const InputDecoration(labelText: 'Pays', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: autoriteEmettrice, decoration: const InputDecoration(labelText: 'Autorité émettrice', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: () => pickDate(false), icon: const Icon(Icons.event), label: Text(datePublication == null ? 'Publication' : regFmtDate(datePublication!.toIso8601String())))),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton.icon(onPressed: () => pickDate(true), icon: const Icon(Icons.gavel), label: Text(dateEntreeVigueur == null ? 'Entrée en vigueur' : regFmtDate(dateEntreeVigueur!.toIso8601String())))),
      ]),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: statut,
        decoration: const InputDecoration(labelText: 'Statut', border: OutlineInputBorder()),
        items: const [DropdownMenuItem(value: 'EN_VIGUEUR', child: Text('En vigueur')), DropdownMenuItem(value: 'MODIFIE', child: Text('Modifié')), DropdownMenuItem(value: 'ABROGE', child: Text('Abrogé'))],
        onChanged: (v) => setState(() => statut = v ?? statut),
      ),
      const SizedBox(height: 12),
      TextField(controller: sourceOfficielle, decoration: const InputDecoration(labelText: 'Source officielle', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: lienSource, decoration: const InputDecoration(labelText: 'Lien vers la source', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: objet, maxLines: 2, decoration: const InputDecoration(labelText: 'Objet', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: resume, maxLines: 3, decoration: const InputDecoration(labelText: 'Résumé', border: OutlineInputBorder())),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
      const SizedBox(height: 20),
      FilledButton(onPressed: busy ? null : submit, child: busy ? const CircularProgressIndicator() : const Text('Enregistrer')),
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
    if (error != null) return Scaffold(body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!), TextButton(onPressed: load, child: const Text('Réessayer'))])));
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
        icon: const Icon(Icons.add), label: const Text('Nouvelle exigence'),
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            regChip('Analyse d\'impact : à analyser', QhseColors.blue),
            if (text['reference'] != null) regChip(text['reference'], QhseColors.textSecondary),
          ]),
          const SizedBox(height: 4),
          Text('Jamais de conclusion automatique : l\'impact doit être analysé par un humain à partir des éléments ci-dessous.', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: QhseColors.textSecondary)),
          const SizedBox(height: 12),
          Row(children: [
            regKpi('Exigences impactées', '${analysis!['exigencesImpactees'] ?? 0}', QhseColors.blue),
            const SizedBox(width: 8),
            regKpi('Sites impactés', '${(analysis!['sitesImpactes'] as List).length}', QhseColors.blue),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            regKpi('NC ouvertes', '${(analysis!['nonConformitesOuvertes'] as List).length}', QhseColors.red),
            const SizedBox(width: 8),
            regKpi('Actions ouvertes', '${(analysis!['actionsOuvertes'] as List).length}', QhseColors.amber),
          ]),
          regSectionTitle('Risques liés (${(analysis!['risquesImpactes'] as List).length})'),
          ...(analysis!['risquesImpactes'] as List).map((r) => ListTile(dense: true, leading: const Icon(Icons.warning_amber), title: Text('${r['code']} — ${r['hazard']}'))),
          if ((analysis!['risquesImpactes'] as List).isEmpty) regEmpty('Aucun risque lié'),
          regSectionTitle('Documents liés (${(analysis!['documentsImpactes'] as List).length})'),
          ...(analysis!['documentsImpactes'] as List).map((d) => ListTile(dense: true, leading: const Icon(Icons.description), title: Text(d['title'] ?? d['name'] ?? ''))),
          if ((analysis!['documentsImpactes'] as List).isEmpty) regEmpty('Aucun document lié'),
          regSectionTitle('Exigences issues de ce texte (${requirements.length})'),
          if (requirements.isEmpty) regEmpty('Aucune exigence enregistrée pour ce texte')
          else ...requirements.map((r) => Card(child: ListTile(
            title: Text(r['libelle'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Row(children: [
              regChip(regApplicabiliteLabels[r['applicabilite']] ?? r['applicabilite'] ?? '', regApplicabiliteColor(r['applicabilite'])),
              const SizedBox(width: 6),
              if (r['statutConformite'] != null) regChip(regStatutConformiteLabels[r['statutConformite']] ?? r['statutConformite'], regConformiteColor(r['statutConformite'])),
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
        icon: const Icon(Icons.add), label: const Text('Nouvelle exigence'),
      ),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: Row(children: [
          Expanded(child: DropdownButtonFormField<String>(
            value: applicabilite, isExpanded: true,
            decoration: const InputDecoration(labelText: 'Applicabilité', border: OutlineInputBorder(), isDense: true),
            items: [const DropdownMenuItem(value: 'TOUS', child: Text('Toutes')), ...regApplicabiliteLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))],
            onChanged: (v) { applicabilite = v ?? 'TOUS'; load(); },
          )),
          const SizedBox(width: 8),
          Expanded(child: DropdownButtonFormField<String>(
            value: statutConformite, isExpanded: true,
            decoration: const InputDecoration(labelText: 'Conformité', border: OutlineInputBorder(), isDense: true),
            items: [const DropdownMenuItem(value: 'TOUS', child: Text('Toutes')), ...regStatutConformiteLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))],
            onChanged: (v) { statutConformite = v ?? 'TOUS'; load(); },
          )),
        ])),
        Expanded(child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!), TextButton(onPressed: load, child: const Text('Réessayer'))]))
                : RefreshIndicator(onRefresh: load, child: items.isEmpty
                    ? ListView(children: [regEmpty('Aucune exigence pour ce filtre')])
                    : ListView.builder(padding: const EdgeInsets.all(12), itemCount: items.length, itemBuilder: (_, i) {
                        final r = items[i];
                        return Card(child: ListTile(
                          title: Text(r['libelle'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${r['text']?['titre'] ?? ''} ${r['site'] != null ? '• ${r['site']['name']}' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                            regChip(regApplicabiliteLabels[r['applicabilite']] ?? r['applicabilite'] ?? '', regApplicabiliteColor(r['applicabilite'])),
                            if (r['statutConformite'] != null) Padding(padding: const EdgeInsets.only(top: 4), child: regChip(regStatutConformiteLabels[r['statutConformite']] ?? r['statutConformite'], regConformiteColor(r['statutConformite']))),
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
    if (libelle.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le libellé est obligatoire'))); return; }
    if (textId == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le texte source est obligatoire'))); return; }
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
    appBar: AppBar(title: Text(editing ? "Modifier l'exigence" : 'Nouvelle exigence')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      TextField(controller: libelle, maxLines: 3, decoration: const InputDecoration(labelText: "Libellé de l'exigence *", border: OutlineInputBorder())),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: texts.any((t) => t['id'] == textId) ? textId : null, isExpanded: true,
        decoration: const InputDecoration(labelText: 'Texte source *', border: OutlineInputBorder()),
        items: texts.map<DropdownMenuItem<String>>((t) => DropdownMenuItem(value: t['id'] as String, child: Text(t['titre'], overflow: TextOverflow.ellipsis))).toList(),
        onChanged: widget.textId != null ? null : (v) => setState(() => textId = v),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: domains.any((d) => d['id'] == domainId) ? domainId : null,
        decoration: const InputDecoration(labelText: 'Domaine', border: OutlineInputBorder()),
        items: [const DropdownMenuItem(value: null, child: Text('—')), ...domains.map((d) => DropdownMenuItem(value: d['id'] as String, child: Text(d['label'])))],
        onChanged: (v) => setState(() => domainId = v),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: criticite,
        decoration: const InputDecoration(labelText: 'Criticité', border: OutlineInputBorder()),
        items: [const DropdownMenuItem(value: null, child: Text('—')), ...regCriticiteLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))],
        onChanged: (v) => setState(() => criticite = v),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: sites.any((s) => s['id'] == siteId) ? siteId : null,
        decoration: const InputDecoration(labelText: 'Site', border: OutlineInputBorder()),
        items: [const DropdownMenuItem(value: null, child: Text('—')), ...sites.map((s) => DropdownMenuItem(value: s['id'] as String, child: Text(s['name'])))],
        onChanged: (v) => setState(() => siteId = v),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: workUnits.any((w) => w['id'] == workUnitId) ? workUnitId : null,
        decoration: const InputDecoration(labelText: 'Service / unité', border: OutlineInputBorder()),
        items: [const DropdownMenuItem(value: null, child: Text('—')), ...workUnits.map((w) => DropdownMenuItem(value: w['id'] as String, child: Text(w['name'])))],
        onChanged: (v) => setState(() => workUnitId = v),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: users.any((u) => u['id'] == responsableId) ? responsableId : null,
        decoration: const InputDecoration(labelText: 'Responsable', border: OutlineInputBorder()),
        items: [const DropdownMenuItem(value: null, child: Text('—')), ...users.map((u) => DropdownMenuItem(value: u['id'] as String, child: Text(regUserName(u))))],
        onChanged: (v) => setState(() => responsableId = v),
      ),
      const SizedBox(height: 12),
      TextField(controller: frequence, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Fréquence de réévaluation (mois)', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: preuveAttendue, decoration: const InputDecoration(labelText: 'Preuve de conformité attendue', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: commentaire, maxLines: 2, decoration: const InputDecoration(labelText: 'Commentaire', border: OutlineInputBorder())),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
      const SizedBox(height: 20),
      FilledButton(onPressed: busy ? null : submit, child: busy ? const CircularProgressIndicator() : const Text('Enregistrer')),
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Non-conformité créée.')));
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
      title: const Text('Confirmer la suppression'), content: Text('Supprimer la preuve « $label » ?'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer'))],
    ));
    if (ok != true) return;
    try { await api.delete('/business/regulatory-evidences/$id'); load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  @override
  Widget build(BuildContext c) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (error != null) return Scaffold(body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!), TextButton(onPressed: load, child: const Text('Réessayer'))])));
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
            regChip(regApplicabiliteLabels[r['applicabilite']] ?? r['applicabilite'] ?? '', regApplicabiliteColor(r['applicabilite'])),
            if (r['statutConformite'] != null) regChip(regStatutConformiteLabels[r['statutConformite']] ?? r['statutConformite'], regConformiteColor(r['statutConformite'])),
            regChip(regStatutFileLabels[r['statutFile']] ?? r['statutFile'] ?? '', QhseColors.blue),
            if (r['criticite'] != null) regChip(regCriticiteLabels[r['criticite']] ?? r['criticite'], QhseColors.amber),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton(onPressed: () async { final ok = await Navigator.push<bool>(c, MaterialPageRoute(builder: (_) => RegulatoryApplicabiliteFormPage(requirement: r))); if (ok == true) load(); }, child: const Text('Statuer applicabilité')),
            OutlinedButton(onPressed: () async { final ok = await Navigator.push<bool>(c, MaterialPageRoute(builder: (_) => RegulatoryEvaluationFormPage(requirementId: r['id']))); if (ok == true) load(); }, child: const Text('Nouvelle évaluation')),
            OutlinedButton(onPressed: () async { final ok = await Navigator.push<bool>(c, MaterialPageRoute(builder: (_) => RegulatoryEvidenceFormPage(requirementId: r['id']))); if (ok == true) load(); }, child: const Text('Ajouter une preuve')),
            OutlinedButton(onPressed: () async { final ok = await Navigator.push<bool>(c, MaterialPageRoute(builder: (_) => RegulatoryLinkRiskFormPage(requirementId: r['id']))); if (ok == true) load(); }, child: const Text('Lier un risque')),
            OutlinedButton(onPressed: () async { final ok = await Navigator.push<bool>(c, MaterialPageRoute(builder: (_) => RegulatoryGenerateActionFormPage(requirement: r))); if (ok == true) load(); }, child: const Text('Créer une action CAPA')),
            if (requirementRisks.isNotEmpty) OutlinedButton(onPressed: () async { final ok = await Navigator.push<bool>(c, MaterialPageRoute(builder: (_) => RegulatoryReevalFormPage(requirement: r))); if (ok == true) load(); }, child: const Text('Demander réévaluation du risque')),
            FilledButton(onPressed: busy ? null : generateNc, style: FilledButton.styleFrom(backgroundColor: QhseColors.red), child: const Text('Créer une NC')),
          ]),
          if (r['justificatifApplicabilite'] != null && '${r['justificatifApplicabilite']}'.isNotEmpty) ...[
            regSectionTitle('Justification de l\'applicabilité'),
            Text(r['justificatifApplicabilite']),
          ],
          regSectionTitle('Preuve attendue'),
          Text(r['preuveAttendue'] ?? '—'),
          regSectionTitle('Preuves de conformité (${evidences.length})'),
          if (evidences.isEmpty) regEmpty('Aucune preuve enregistrée')
          else ...evidences.map((e) => Card(child: ListTile(
            title: Text(e['nom'] ?? e['type'] ?? 'Preuve'),
            subtitle: Text('Expire le ${regFmtDate(e['dateExpiration'])} • ${regUserName(e['responsable'])}'),
            trailing: regChip(regEvidenceStatutLabels[e['statut']] ?? e['statut'] ?? '', regEvidenceColor(e['statut'])),
            onTap: () async {
              final choice = await showDialog<String>(context: c, builder: (_) => SimpleDialog(children: [
                SimpleDialogOption(onPressed: () => Navigator.pop(c, 'edit'), child: const Text('Modifier')),
                SimpleDialogOption(onPressed: () => Navigator.pop(c, 'delete'), child: const Text('Supprimer')),
              ]));
              if (choice == 'edit') { final ok = await Navigator.push<bool>(c, MaterialPageRoute(builder: (_) => RegulatoryEvidenceFormPage(requirementId: r['id'], record: e))); if (ok == true) load(); }
              else if (choice == 'delete') deleteEvidence(e['id'], e['nom'] ?? 'preuve');
            },
          ))),
          regSectionTitle('Historique des évaluations (${evaluations.length})'),
          if (evaluations.isEmpty) regEmpty('Aucune évaluation enregistrée')
          else ...evaluations.map((ev) => Card(child: ListTile(
            leading: Icon(Icons.fact_check, color: regConformiteColor(ev['statut'] == 'NON_CONFORME' ? 'NON_CONFORME' : (ev['statut'] == 'PARTIEL' ? 'PARTIEL' : 'CONFORME'))),
            title: Text(regStatutConformiteLabels[ev['statut']] ?? ev['statut'] ?? ''),
            subtitle: Text('${regFmtDate(ev['dateControle'])}${ev['constat'] != null ? ' — ${ev['constat']}' : ''}'),
          ))),
          regSectionTitle('Risques liés (${requirementRisks.length})'),
          if (requirementRisks.isEmpty) regEmpty('Aucun risque lié')
          else ...requirementRisks.map((rr) => Card(child: ListTile(
            title: Text('${rr['risk']['code']} — ${rr['risk']['hazard']}'),
            trailing: IconButton(icon: const Icon(Icons.link_off), onPressed: () => unlinkRisk(rr['id'])),
          ))),
          regSectionTitle('Documents liés (${requirementDocuments.length})'),
          if (requirementDocuments.isEmpty) regEmpty('Aucun document lié')
          else ...requirementDocuments.map((rd) => Card(child: ListTile(
            title: Text(rd['document']?['title'] ?? rd['document']?['name'] ?? ''),
            trailing: IconButton(icon: const Icon(Icons.link_off), onPressed: () => unlinkDocument(rd['id'])),
          ))),
          regSectionTitle('Non-conformités liées (${nonConformities.length})'),
          if (nonConformities.isEmpty) regEmpty('Aucune non-conformité liée')
          else ...nonConformities.map((n) => Card(child: ListTile(leading: const Icon(Icons.report, color: Colors.red), title: Text(n['title'] ?? ''), subtitle: Text('${n['code']} • ${n['status']}')))),
          regSectionTitle('Actions liées (${actions.length})'),
          if (actions.isEmpty) regEmpty('Aucune action liée')
          else ...actions.map((a) => Card(child: ListTile(leading: const Icon(Icons.task_alt), title: Text(a['title'] ?? ''), subtitle: Text('${a['code']} • ${a['status']}${a['dueDate'] != null ? ' • échéance ${regFmtDate(a['dueDate'])}' : ''}')))),
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
      setState(() => error = 'Une justification est obligatoire pour une exigence non applicable ou partiellement applicable.');
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
    appBar: AppBar(title: const Text('Statuer sur l\'applicabilité')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      DropdownButtonFormField<String>(
        value: applicabilite,
        decoration: const InputDecoration(labelText: 'Applicabilité', border: OutlineInputBorder()),
        items: regApplicabiliteLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
        onChanged: (v) => setState(() => applicabilite = v ?? applicabilite),
      ),
      const SizedBox(height: 12),
      TextField(controller: justificatif, maxLines: 4, decoration: InputDecoration(
        labelText: requiresJustification ? 'Justification *' : 'Justification',
        hintText: 'Jamais de conclusion automatique : expliquez le raisonnement.',
        border: const OutlineInputBorder(),
      )),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
      const SizedBox(height: 20),
      FilledButton(onPressed: busy ? null : submit, child: busy ? const CircularProgressIndicator() : const Text('Valider')),
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
    appBar: AppBar(title: const Text('Nouvelle évaluation de conformité')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      DropdownButtonFormField<String>(
        value: statut,
        decoration: const InputDecoration(labelText: 'Statut', border: OutlineInputBorder()),
        items: regStatutConformiteLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
        onChanged: (v) => setState(() => statut = v ?? statut),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: pickDate, icon: const Icon(Icons.event), label: Text('Date du contrôle : ${regFmtDate(dateControle.toIso8601String())}')),
      const SizedBox(height: 12),
      TextField(controller: constat, maxLines: 2, decoration: const InputDecoration(labelText: 'Constat', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: preuveExaminee, decoration: const InputDecoration(labelText: 'Preuve examinée', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: personneInterrogee, decoration: const InputDecoration(labelText: 'Personne interrogée', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: observation, maxLines: 2, decoration: const InputDecoration(labelText: 'Observation', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: commentaire, maxLines: 2, decoration: const InputDecoration(labelText: 'Commentaire', border: OutlineInputBorder())),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
      const SizedBox(height: 20),
      FilledButton(onPressed: busy ? null : submit, child: busy ? const CircularProgressIndicator() : const Text('Enregistrer l\'évaluation')),
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
    appBar: AppBar(title: Text(editing ? 'Modifier la preuve' : 'Nouvelle preuve de conformité')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      TextField(controller: type, decoration: const InputDecoration(labelText: 'Type (certificat, registre, permis...)', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: nom, decoration: const InputDecoration(labelText: 'Nom / référence', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: () => pickDate(false), icon: const Icon(Icons.event), label: Text(dateEmission == null ? 'Émission' : regFmtDate(dateEmission!.toIso8601String())))),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton.icon(onPressed: () => pickDate(true), icon: const Icon(Icons.event_busy), label: Text(dateExpiration == null ? 'Expiration' : regFmtDate(dateExpiration!.toIso8601String())))),
      ]),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: users.any((u) => u['id'] == responsableId) ? responsableId : null,
        decoration: const InputDecoration(labelText: 'Responsable', border: OutlineInputBorder()),
        items: [const DropdownMenuItem(value: null, child: Text('—')), ...users.map((u) => DropdownMenuItem(value: u['id'] as String, child: Text(regUserName(u))))],
        onChanged: (v) => setState(() => responsableId = v),
      ),
      const SizedBox(height: 12),
      TextField(controller: commentaire, maxLines: 2, decoration: const InputDecoration(labelText: 'Commentaire', border: OutlineInputBorder())),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
      const SizedBox(height: 20),
      FilledButton(onPressed: busy ? null : submit, child: busy ? const CircularProgressIndicator() : const Text('Enregistrer')),
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
    if (riskId == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choisissez un risque'))); return; }
    setState(() { busy = true; error = null; });
    try {
      await api.post('/business/regulatory-requirements/${widget.requirementId}/link-risk', {'riskId': riskId, 'note': note.text.trim().isEmpty ? null : note.text.trim()});
      if (mounted) Navigator.pop(context, true);
    } catch (e) { setState(() { busy = false; error = '$e'; }); }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Lier un risque existant')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      DropdownButtonFormField<String>(
        value: riskId, isExpanded: true,
        decoration: const InputDecoration(labelText: 'Risque', border: OutlineInputBorder()),
        items: risks.map<DropdownMenuItem<String>>((r) => DropdownMenuItem(value: r['id'] as String, child: Text('${r['code']} — ${r['hazard']}', overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (v) => setState(() => riskId = v),
      ),
      const SizedBox(height: 12),
      TextField(controller: note, decoration: const InputDecoration(labelText: 'Note', border: OutlineInputBorder())),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
      const SizedBox(height: 20),
      FilledButton(onPressed: busy ? null : submit, child: busy ? const CircularProgressIndicator() : const Text('Lier')),
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
      'title': title.text.trim().isEmpty ? 'Action réglementaire — ${widget.requirement['libelle']}'.substring(0, 60.clamp(0, 'Action réglementaire — ${widget.requirement['libelle']}'.length)) : title.text.trim(),
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
    appBar: AppBar(title: const Text('Créer une action CAPA')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      TextField(controller: title, decoration: InputDecoration(labelText: 'Titre', hintText: 'Action réglementaire — ${widget.requirement['libelle']}', border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: description, maxLines: 2, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: users.any((u) => u['id'] == responsibleId) ? responsibleId : null,
        decoration: const InputDecoration(labelText: 'Responsable', border: OutlineInputBorder()),
        items: [const DropdownMenuItem(value: null, child: Text('—')), ...users.map((u) => DropdownMenuItem(value: u['id'] as String, child: Text(regUserName(u))))],
        onChanged: (v) => setState(() => responsibleId = v),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: pickDate, icon: const Icon(Icons.event), label: Text(dueDate == null ? 'Échéance' : regFmtDate(dueDate!.toIso8601String()))),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
      const SizedBox(height: 20),
      FilledButton(onPressed: busy ? null : submit, child: busy ? const CircularProgressIndicator() : const Text('Créer l\'action')),
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
    if (riskId == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choisissez le risque concerné'))); return; }
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
    appBar: AppBar(title: const Text('Demander une réévaluation du risque')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Text('Jamais une modification directe de la cotation : cette demande crée une tâche à traiter.', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: QhseColors.textSecondary)),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: riskId, isExpanded: true,
        decoration: const InputDecoration(labelText: 'Risque concerné', border: OutlineInputBorder()),
        items: risks.map<DropdownMenuItem<String>>((rr) => DropdownMenuItem(value: rr['riskId'] as String, child: Text('${rr['risk']['code']} — ${rr['risk']['hazard']}', overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (v) => setState(() => riskId = v),
      ),
      const SizedBox(height: 12),
      TextField(controller: raison, maxLines: 3, decoration: const InputDecoration(labelText: 'Raison de la réévaluation', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: users.any((u) => u['id'] == responsableId) ? responsableId : null,
        decoration: const InputDecoration(labelText: 'Responsable', border: OutlineInputBorder()),
        items: [const DropdownMenuItem(value: null, child: Text('—')), ...users.map((u) => DropdownMenuItem(value: u['id'] as String, child: Text(regUserName(u))))],
        onChanged: (v) => setState(() => responsableId = v),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: pickDate, icon: const Icon(Icons.event), label: Text(dateLimite == null ? 'Date limite' : regFmtDate(dateLimite!.toIso8601String()))),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
      const SizedBox(height: 20),
      FilledButton(onPressed: busy ? null : submit, child: busy ? const CircularProgressIndicator() : const Text('Envoyer la demande')),
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

const _regAlertThresholds = [
  ['alerteJ90', '90 jours'], ['alerteJ60', '60 jours'], ['alerteJ30', '30 jours'],
  ['alerteJ15', '15 jours'], ['alerteJ7', '7 jours'],
];

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
    if (error != null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!), TextButton(onPressed: load, child: const Text('Réessayer'))]));
    final echeancesEvaluation = List.from(alerts!['echeancesEvaluation'] ?? []);
    final echeancesPreuves = List.from(alerts!['echeancesPreuves'] ?? []);
    final nouvellesExigences = List.from(alerts!['nouvellesExigences'] ?? []);
    final actionsEnRetard = List.from(alerts!['actionsEnRetard'] ?? []);
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(padding: const EdgeInsets.all(12), children: [
        regSectionTitle("Seuils d'alerte"),
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Wrap(spacing: 12, runSpacing: 4, children: [
          for (final t in _regAlertThresholds)
            FilterChip(
              label: Text(t[1], style: const TextStyle(fontSize: 12)),
              selected: settings?[t[0]] == true,
              onSelected: (_) => _toggleSetting(t[0]),
            ),
        ]))),
        regSectionTitle('Échéances d\'évaluation (${echeancesEvaluation.length})'),
        if (echeancesEvaluation.isEmpty) regEmpty('Aucune échéance dans les seuils configurés')
        else ...echeancesEvaluation.map((a) => Card(child: ListTile(
          leading: Icon(Icons.event_busy, color: regAlertNiveauColor(a['niveau'])),
          title: Text('${a['code']} — ${a['libelle']}', maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${a['texte']} • ${a['jours'] < 0 ? '${-a['jours']} j de retard' : 'dans ${a['jours']} j'} • ${regUserName(a['responsable'])}'),
          onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => RegulatoryRequirementDetailPage(requirementId: a['requirementId']))),
        ))),
        regSectionTitle('Preuves arrivant à expiration (${echeancesPreuves.length})'),
        if (echeancesPreuves.isEmpty) regEmpty('Aucune preuve à surveiller')
        else ...echeancesPreuves.map((a) => Card(child: ListTile(
          leading: Icon(Icons.description, color: regAlertNiveauColor(a['niveau'])),
          title: Text('${a['nom'] ?? 'Preuve'} — ${a['code']}', maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${a['libelle']} • ${a['jours'] < 0 ? '${-a['jours']} j de retard' : 'dans ${a['jours']} j'}'),
          onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => RegulatoryRequirementDetailPage(requirementId: a['requirementId']))),
        ))),
        regSectionTitle('Nouvelles exigences à analyser (${nouvellesExigences.length})'),
        if (nouvellesExigences.isEmpty) regEmpty('Aucune nouvelle exigence en attente')
        else ...nouvellesExigences.map((r) => Card(child: ListTile(
          leading: const Icon(Icons.fiber_new),
          title: Text(r['libelle'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(r['text']?['titre'] ?? ''),
          onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => RegulatoryRequirementDetailPage(requirementId: r['id']))),
        ))),
        regSectionTitle('Actions réglementaires en retard (${actionsEnRetard.length})'),
        if (actionsEnRetard.isEmpty) regEmpty('Aucune action en retard')
        else ...actionsEnRetard.map((a) => Card(child: ListTile(leading: const Icon(Icons.warning, color: Colors.red), title: Text(a['title'] ?? ''), subtitle: Text('${a['code']} • échéance ${regFmtDate(a['dueDate'])} • ${regUserName(a['responsible'])}')))),
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

  static const statuts = {'A_PLANIFIER': 'À planifier', 'PLANIFIEE': 'Planifiée', 'REALISEE': 'Réalisée', 'ANNULEE': 'Annulée'};

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
    if (error != null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!), TextButton(onPressed: load, child: const Text('Réessayer'))]));
    return RefreshIndicator(
      onRefresh: load,
      child: items.isEmpty
          ? ListView(children: [regEmpty('Aucune demande de réévaluation en cours')])
          : ListView.builder(padding: const EdgeInsets.all(12), itemCount: items.length, itemBuilder: (_, i) {
              final d = items[i];
              return Card(child: ListTile(
                title: Text('${d['risk']?['code'] ?? ''} — ${d['risk']?['hazard'] ?? ''}'),
                subtitle: Text('${d['requirement']?['code'] ?? ''} • ${d['raison'] ?? 'Sans raison précisée'}${d['dateLimite'] != null ? ' • limite ${regFmtDate(d['dateLimite'])}' : ''}'),
                trailing: DropdownButton<String>(
                  value: d['statut'],
                  items: statuts.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
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
    if (error != null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!), TextButton(onPressed: load, child: const Text('Réessayer'))]));
    final global = regComplianceRate(items);
    final byDomain = regGroupCompliance(items, (r) => r['domainId'] as String?, (l) => l.first['domain']?['label'] ?? 'Sans domaine');
    final bySite = regGroupCompliance(items, (r) => r['siteId'] as String?, (l) => l.first['site']?['name'] ?? 'Sans site');
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(padding: const EdgeInsets.all(12), children: [
        Row(children: [
          regKpi('Exigences', '${global['total']}', QhseColors.blue),
          const SizedBox(width: 8),
          regKpi('Applicables', '${global['applicables']}', QhseColors.blue),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          regKpi('Évaluées', '${global['evaluees']}', QhseColors.amber),
          const SizedBox(width: 8),
          regKpi('Taux de conformité', global['taux'] != null ? '${global['taux']}%' : '—', QhseColors.green),
        ]),
        regSectionTitle('Taux de conformité par domaine'),
        if (byDomain.isEmpty) regEmpty('Aucune donnée')
        else ...byDomain.map((g) => ListTile(dense: true, title: Text(g['label']), trailing: Text(g['taux'] != null ? '${g['taux']}% (${g['conformes']}/${g['evaluees']})' : '—'))),
        regSectionTitle('Taux de conformité par site'),
        if (bySite.isEmpty) regEmpty('Aucune donnée')
        else ...bySite.map((g) => ListTile(dense: true, title: Text(g['label']), trailing: Text(g['taux'] != null ? '${g['taux']}% (${g['conformes']}/${g['evaluees']})' : '—'))),
        regSectionTitle('Matrice de traçabilité (${items.length} exigences)'),
        Text('Export Excel/CSV disponible sur le tableau de bord web (Rapports).', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: QhseColors.textSecondary)),
        const SizedBox(height: 8),
        ...items.map((r) => Card(child: ListTile(
          dense: true,
          title: Text('${r['code']} — ${r['libelle']}', maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${r['domain']?['label'] ?? '—'} • ${r['site']?['name'] ?? '—'}'),
          trailing: regChip(regApplicabiliteLabels[r['applicabilite']] ?? r['applicabilite'] ?? '', regApplicabiliteColor(r['applicabilite'])),
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
      floatingActionButton: FloatingActionButton.extended(onPressed: () => openForm(), icon: const Icon(Icons.add), label: const Text('Nouveau domaine')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!), TextButton(onPressed: load, child: const Text('Réessayer'))]))
              : RefreshIndicator(onRefresh: load, child: items.isEmpty
                  ? ListView(children: [regEmpty('Aucun domaine défini')])
                  : ListView.builder(padding: const EdgeInsets.all(12), itemCount: items.length, itemBuilder: (_, i) {
                      final d = items[i];
                      return Card(child: ListTile(
                        title: Text('${d['code']} — ${d['label']}'),
                        trailing: regChip(d['actif'] == true ? 'Actif' : 'Inactif', d['actif'] == true ? QhseColors.green : QhseColors.textSecondary),
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
    if (code.text.trim().isEmpty || label.text.trim().isEmpty) { setState(() => error = 'Code et libellé sont obligatoires'); return; }
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
    title: Text(editing ? 'Modifier le domaine' : 'Nouveau domaine'),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: code, decoration: const InputDecoration(labelText: 'Code')),
      const SizedBox(height: 8),
      TextField(controller: label, decoration: const InputDecoration(labelText: 'Libellé')),
      const SizedBox(height: 8),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Actif'), value: actif, onChanged: (v) => setState(() => actif = v)),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12))),
    ]),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
      FilledButton(onPressed: busy ? null : submit, child: const Text('Enregistrer')),
    ],
  );
}
