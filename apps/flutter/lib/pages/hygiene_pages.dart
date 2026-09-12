// ==========================================================
// MODULE HYGIÈNE AU TRAVAIL — PHASE 1 (Flutter)
// Suit le même schéma que safety_events_page.dart / reclamations_pages.dart :
// showXxxDialog() -> XxxHome (StatefulWidget, onglets) -> XxxDetailPage
// Adapter ApiService / QhseColors / SyncQueue aux classes déjà existantes.
// ==========================================================

import 'package:flutter/material.dart';
import 'api_service.dart'; // service HTTP existant
import 'qhse_theme.dart'; // QhseColors existant

const kNiveauColor = {
  'FAIBLE': Colors.green,
  'MODERE': Colors.amber,
  'ELEVE': Colors.orange,
  'CRITIQUE': Colors.red,
};

const kZonesCorporelles = [
  'DOS', 'EPAULES', 'COU', 'POIGNETS', 'MAINS', 'COUDES', 'GENOUX', 'JAMBES', 'PIEDS', 'AUTRE'
];

const kRolesAccesMedical = ['ADMIN', 'RESPONSABLE_QHSE', 'RH', 'MEDECIN_TRAVAIL'];

// ---------- DIALOGUE : ÉVALUER UN RISQUE SANITAIRE ----------
Future<void> showHygieneRisqueDialog(BuildContext context, {Map<String, dynamic>? initial}) async {
  final danger = TextEditingController(text: initial?['danger'] ?? '');
  final situationDangereuse = TextEditingController(text: initial?['situationDangereuse'] ?? '');
  final poste = TextEditingController(text: initial?['poste'] ?? '');
  String categorie = initial?['categorie'] ?? 'PHYSIQUE';
  double gravite = (initial?['gravite'] ?? 1).toDouble();
  double probabilite = (initial?['probabilite'] ?? 1).toDouble();

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      final criticite = (gravite * probabilite).round();
      final niveau = criticite <= 4 ? 'FAIBLE' : criticite <= 9 ? 'MODERE' : criticite <= 15 ? 'ELEVE' : 'CRITIQUE';
      return AlertDialog(
        title: const Text('Évaluer un risque sanitaire'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: categorie,
              items: const ['PHYSIQUE', 'CHIMIQUE', 'BIOLOGIQUE', 'CONDITIONS_TRAVAIL']
                  .map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => categorie = v!),
              decoration: const InputDecoration(labelText: 'Catégorie'),
            ),
            TextField(controller: danger, decoration: const InputDecoration(labelText: 'Danger')),
            TextField(controller: situationDangereuse, decoration: const InputDecoration(labelText: 'Situation dangereuse')),
            TextField(controller: poste, decoration: const InputDecoration(labelText: 'Poste / Zone')),
            Row(children: [
              Expanded(child: Column(children: [
                const Text('Gravité'),
                Slider(value: gravite, min: 1, max: 5, divisions: 4, label: '${gravite.round()}',
                    onChanged: (v) => setState(() => gravite = v)),
              ])),
              Expanded(child: Column(children: [
                const Text('Probabilité'),
                Slider(value: probabilite, min: 1, max: 5, divisions: 4, label: '${probabilite.round()}',
                    onChanged: (v) => setState(() => probabilite = v)),
              ])),
            ]),
            Text('Criticité : $criticite — $niveau', style: TextStyle(color: kNiveauColor[niveau], fontWeight: FontWeight.bold)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              await ApiService.post('/hygiene/risques', {
                'categorie': categorie,
                'danger': danger.text,
                'situationDangereuse': situationDangereuse.text,
                'poste': poste.text,
                'gravite': gravite.round(),
                'probabilite': probabilite.round(),
                'sousType': categorie,
              });
              Navigator.pop(ctx);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      );
    }),
  );
}

// ---------- DIALOGUE : ANALYSER UN POSTE (ERGONOMIE) ----------
Future<void> showErgonomieDialog(BuildContext context) async {
  final poste = TextEditingController();
  final service = TextEditingController();
  final Map<String, double> facteurs = {
    'Postures contraignantes': 0, 'Manutention / port de charges': 0, 'Travail répétitif': 0,
    'Hauteur du plan de travail': 0, 'Écran / informatique': 0, 'Vibrations': 0, 'Confort thermique': 0,
  };

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      final total = facteurs.values.fold(0.0, (a, b) => a + b);
      final score = (total / (facteurs.length * 10) * 100).round();
      final niveau = score >= 75 ? 'CRITIQUE' : score >= 50 ? 'ELEVE' : score >= 25 ? 'MODERE' : 'FAIBLE';
      return AlertDialog(
        title: const Text('Analyser un poste'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: poste, decoration: const InputDecoration(labelText: 'Poste')),
            TextField(controller: service, decoration: const InputDecoration(labelText: 'Service')),
            ...facteurs.keys.map((k) => Column(children: [
              Text(k), Slider(value: facteurs[k]!, min: 0, max: 10, divisions: 10,
                  label: '${facteurs[k]!.round()}', onChanged: (v) => setState(() => facteurs[k] = v)),
            ])),
            Text('Score de risque : $score/100 — $niveau', style: TextStyle(color: kNiveauColor[niveau], fontWeight: FontWeight.bold)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              await ApiService.post('/hygiene/ergonomie', {
                'poste': poste.text,
                'service': service.text,
                'facteurs': {'items': facteurs.entries.map((e) => {'label': e.key, 'points': e.value}).toList()},
              });
              Navigator.pop(ctx);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      );
    }),
  );
}

// ---------- DIALOGUE : SIGNALER UN TMS ----------
Future<void> showTMSDialog(BuildContext context) async {
  final poste = TextEditingController();
  String zone = kZonesCorporelles.first;
  String type = 'SITUATION_A_RISQUE';

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) => AlertDialog(
      title: const Text('Signaler un TMS'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: poste, decoration: const InputDecoration(labelText: 'Poste')),
        DropdownButtonFormField<String>(
          value: zone,
          items: kZonesCorporelles.map((z) => DropdownMenuItem(value: z, child: Text(z))).toList(),
          onChanged: (v) => setState(() => zone = v!),
          decoration: const InputDecoration(labelText: 'Zone corporelle'),
        ),
        DropdownButtonFormField<String>(
          value: type,
          items: const [
            DropdownMenuItem(value: 'SITUATION_A_RISQUE', child: Text('Situation à risque')),
            DropdownMenuItem(value: 'CAS_DECLARE', child: Text('Cas déclaré')),
          ],
          onChanged: (v) => setState(() => type = v!),
          decoration: const InputDecoration(labelText: 'Type de signalement'),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: () async {
            await ApiService.post('/hygiene/tms', {'poste': poste.text, 'zoneCorporelle': zone, 'typeSignalement': type});
            Navigator.pop(ctx);
          },
          child: const Text('Enregistrer'),
        ),
      ],
    )),
  );
}

// ---------- PAGE PRINCIPALE : TABLEAU DE BORD + ONGLETS ----------
class HygieneHome extends StatefulWidget {
  final String userRole;
  const HygieneHome({super.key, required this.userRole});

  @override
  State<HygieneHome> createState() => _HygieneHomeState();
}

class _HygieneHomeState extends State<HygieneHome> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? dashboard;
  List<dynamic> risques = [];
  List<dynamic> ergonomie = [];
  List<dynamic> tms = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _refresh();
  }

  Future<void> _refresh() async {
    dashboard = await ApiService.get('/hygiene/dashboard');
    risques = await ApiService.get('/hygiene/risques');
    ergonomie = await ApiService.get('/hygiene/ergonomie');
    tms = await ApiService.get('/hygiene/tms');
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hygiène au travail'),
        bottom: TabBar(controller: _tabController, isScrollable: true, tabs: const [
          Tab(text: 'Tableau de bord'), Tab(text: 'Risques'), Tab(text: 'Ergonomie'), Tab(text: 'TMS'),
        ]),
      ),
      body: TabBarView(controller: _tabController, children: [
        _buildDashboard(),
        _buildRisquesList(),
        _buildErgonomieList(),
        _buildTMSList(),
      ]),
      floatingActionButton: PopupMenuButton<String>(
        icon: const Icon(Icons.add),
        onSelected: (v) async {
          if (v == 'risque') await showHygieneRisqueDialog(context);
          if (v == 'ergonomie') await showErgonomieDialog(context);
          if (v == 'tms') await showTMSDialog(context);
          _refresh();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'risque', child: Text('Évaluer un risque')),
          PopupMenuItem(value: 'ergonomie', child: Text('Analyser un poste')),
          PopupMenuItem(value: 'tms', child: Text('Signaler un TMS')),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    if (dashboard == null) return const Center(child: CircularProgressIndicator());
    final d = dashboard!;
    Widget kpi(String label, dynamic value, {bool danger = false}) => Card(
      color: danger ? Colors.red.shade50 : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Text('$value', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(label, textAlign: TextAlign.center),
        ]),
      ),
    );
    return RefreshIndicator(
      onRefresh: _refresh,
      child: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(12),
        children: [
          kpi('Risques identifiés', d['risquesTotal']),
          kpi('Risques critiques', d['risquesCritiques'], danger: true),
          kpi('Salariés exposés', d['salariesExposes']),
          kpi('Postes évalués (ergonomie)', d['postesErgonomieAnalyses']),
          kpi('Postes ergonomie critique', d['postesErgonomieCritiques'], danger: true),
          kpi('Situations TMS', d['tmsSituations']),
          kpi('Taux de suivi médical', '${d['suiviMedical']['tauxSuiviMedical']}%'),
          kpi('Visites médicales échues', d['suiviMedical']['visitesEchues'], danger: true),
        ],
      ),
    );
  }

  Widget _buildRisquesList() => ListView.builder(
    itemCount: risques.length,
    itemBuilder: (_, i) {
      final r = risques[i];
      return ListTile(
        title: Text(r['danger'] ?? ''),
        subtitle: Text('${r['categorie']} — ${r['reference']}'),
        trailing: Chip(
          label: Text(r['niveauRisque'] ?? ''),
          backgroundColor: (kNiveauColor[r['niveauRisque']] ?? Colors.grey).withOpacity(0.2),
        ),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HygieneRisqueDetailPage(risque: r))),
      );
    },
  );

  Widget _buildErgonomieList() => ListView.builder(
    itemCount: ergonomie.length,
    itemBuilder: (_, i) {
      final e = ergonomie[i];
      return ListTile(
        title: Text(e['poste'] ?? ''),
        subtitle: Text(e['service'] ?? ''),
        trailing: Chip(
          label: Text('${e['scoreValeur']}/100'),
          backgroundColor: (kNiveauColor[e['scoreErgonomique']] ?? Colors.grey).withOpacity(0.2),
        ),
      );
    },
  );

  Widget _buildTMSList() => ListView.builder(
    itemCount: tms.length,
    itemBuilder: (_, i) {
      final t = tms[i];
      return ListTile(
        title: Text('${t['poste']} — ${t['zoneCorporelle']}'),
        subtitle: Text(t['typeSignalement'] ?? ''),
        trailing: Text(t['statut'] ?? ''),
      );
    },
  );
}

// ---------- FICHE DÉTAIL RISQUE ----------
class HygieneRisqueDetailPage extends StatelessWidget {
  final Map<String, dynamic> risque;
  const HygieneRisqueDetailPage({super.key, required this.risque});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(risque['reference'] ?? '')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(risque['danger'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Chip(label: Text(risque['niveauRisque'] ?? ''), backgroundColor: (kNiveauColor[risque['niveauRisque']] ?? Colors.grey).withOpacity(0.2)),
        const SizedBox(height: 8),
        Text('Catégorie : ${risque['categorie']} / ${risque['sousType']}'),
        Text('Situation dangereuse : ${risque['situationDangereuse'] ?? ''}'),
        Text('Personnel exposé : ${risque['personnelExposeCount']}'),
        Text('Criticité : ${risque['criticite']} (gravité ${risque['gravite']} × probabilité ${risque['probabilite']})'),
        const Divider(),
        Text('Mesures existantes : ${risque['mesuresExistantes'] ?? ''}'),
        Text('Mesures à prévoir : ${risque['mesuresSupplementaires'] ?? ''}'),
      ]),
    );
  }
}
