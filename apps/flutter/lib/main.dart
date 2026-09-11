import "dart:typed_data";
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:file_picker/file_picker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api.dart';
import 'services/sync_queue.dart';
import 'pages/login_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/epi_page.dart';
import 'pages/settings_page.dart';
import 'pages/users_page.dart';
import 'pages/referentiel_pages.dart';
import 'pages/processus_pages.dart';
import 'pages/rapports_page.dart';
import 'pages/other_modules_page.dart';
import 'pages/ged_page.dart';
import 'pages/safety_events_page.dart';
import 'pages/risks_page.dart';
import 'pages/audits_page.dart';
import 'pages/non_conformities_page.dart';
import 'pages/quality_pages.dart';
import 'pages/actions_page.dart';
import 'pages/safety_talk_page.dart';
import 'theme.dart';

// Clé de navigation globale : permet à Api.onUnauthorized (statique, sans
// BuildContext) de rediriger vers l'écran de connexion en cas de session expirée.
final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final savedDark = prefs.getBool('dark_mode');
  if (savedDark != null) { isDarkMode.value = savedDark; QhseColors.apply(savedDark); }
  Api.onUnauthorized = () {
    Api().logout();
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  };
  runApp(const QhseApp());
}

class QhseApp extends StatelessWidget{const QhseApp({super.key});@override Widget build(BuildContext c)=>ValueListenableBuilder<bool>(valueListenable:isDarkMode,builder:(context,dark,_){QhseColors.apply(dark);final theme=buildQhseTheme();return MaterialApp(navigatorKey:navigatorKey,title:'Gestion QHSE 360',debugShowCheckedModeBanner:false,theme:theme,darkTheme:theme,themeMode:dark?ThemeMode.dark:ThemeMode.light,home:const AuthGate());});}

// Vérifie au démarrage si une session est déjà ouverte (jeton stocké localement)
// et redirige vers le tableau de bord ou l'écran de connexion.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}
class _AuthGateState extends State<AuthGate> {
  final api = Api();
  bool? loggedIn;
  @override
  void initState() { super.initState(); check(); }
  Future<void> check() async { final t = await api.token(); setState(() => loggedIn = t != null); }
  @override
  Widget build(BuildContext c) {
    if (loggedIn == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return loggedIn! ? const HomeShell() : const LoginPage();
  }
}

// Coquille principale : tableau de bord de supervision + accès aux applications terrain,
// toutes branchées sur le même Core V4 / la même base de données.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}
class _HomeShellState extends State<HomeShell> {
  final api = Api();
  Map<String, dynamic>? user;

  @override
  void initState() {
    super.initState();
    api.currentUser().then((u) => setState(() => user = u));
    refreshPendingCount();
    _connSub = Connectivity().onConnectivityChanged.listen((result) {
      final hasNetwork = result.any((r) => r != ConnectivityResult.none);
      if (hasNetwork) syncNow(silent: true);
    });
  }

  @override
  void dispose() { _connSub?.cancel(); super.dispose(); }

  StreamSubscription<List<ConnectivityResult>>? _connSub;
  int pendingSync = 0;
  bool syncing = false;

  Future<void> refreshPendingCount() async {
    final n = await SyncQueue.pendingCount();
    if (mounted) setState(() => pendingSync = n);
  }

  Future<void> syncNow({bool silent = false}) async {
    if (syncing) return;
    setState(() => syncing = true);
    final r = await SyncQueue.flush(api);
    await refreshPendingCount();
    setState(() => syncing = false);
    if (!silent && mounted) {
      final msg = r['synced']! > 0
          ? '${r['synced']} élément(s) synchronisé(s)${r['remaining']! > 0 ? ', ${r['remaining']} en attente' : ''}'
          : (r['remaining']! > 0 ? 'Toujours hors-ligne : ${r['remaining']} élément(s) en attente' : 'Rien à synchroniser');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> logout() async {
    await api.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginPage()), (r) => false);
    }
  }

  // Même regroupement que le tableau de bord web (Gestion QHSE 360) : les
  // modules déjà réels côté app renvoient vers leur écran existant ; ceux qui
  // n'ont pas encore d'équivalent (même statut que côté web, voir
  // ROADMAP-CONSOLIDATION.md) ouvrent une page "Bientôt disponible" honnête
  // plutôt que de cacher leur absence.
  List<_NavGroup> get navGroups => [
    _NavGroup('PILOTAGE', [_NavItem('Tableau de bord', Icons.dashboard_outlined, null)]),
    _NavGroup('QUALITÉ (ISO 9001:2015)', [
      _NavItem('Contrôles qualité', Icons.fact_check_outlined, const QualityHome()),
      _NavItem('Processus', Icons.assignment_outlined, const ProcessusHome()),
      _NavItem('Indicateurs qualité', Icons.insights_outlined, const IndicateursQualitePage()),
      _NavItem('Réclamations clients', Icons.notifications_outlined, const ReclamationsPage()),
      _NavItem('Fournisseurs', Icons.science_outlined, const FournisseursPage()),
    ]),
    _NavGroup('SÉCURITÉ (ISO 45001:2018)', [
      _NavItem('Accidents & incidents', Icons.warning_amber_outlined, const SafetyEventsPage()),
      _NavItem('Gestion EPI/EPC', Icons.health_and_safety_outlined, const EpiPage()),
      _NavItem('Hygiène au travail', Icons.favorite_outline, const VisitesMedicalesPage()),
    ]),
    _NavGroup('ENVIRONNEMENT (ISO 14001:2026)', [_NavItem('Environnement', Icons.eco_outlined, const EnvironmentPage())]),
    _NavGroup('RISQUES & AUDITS', [
      _NavItem('Registre des risques', Icons.report_problem_outlined, const RisksPage()),
      _NavItem('Audits', Icons.assignment_turned_in_outlined, const AuditsPage()),
      _NavItem('Non-conformités', Icons.error_outline, const NonConformitiesPage()),
      _NavItem('Actions CAPA', Icons.build_outlined, const ActionsPage()),
    ]),
    _NavGroup('SYSTÈME', [
      _NavItem('Documentation (GED)', Icons.folder_open_outlined, const GedPage()),
      _NavItem("Quart d'heure sécurité", Icons.shield_outlined, const SafetyTalkPage()),
      _NavItem('HACCP', Icons.restaurant_menu_outlined, const HaccpPage()),
      _NavItem('Équipements', Icons.precision_manufacturing_outlined, const EquipmentPage()),
      _NavItem('Veille réglementaire', Icons.search_outlined, const VeilleReglementairePage()),
      _NavItem('Objectifs QHSE', Icons.flag_outlined, const ObjectifsQhsePage()),
      _NavItem('Rapports', Icons.description_outlined, const RapportsPage()),
      _NavItem('Utilisateurs', Icons.people_outline, const UsersPage()),
    ]),
  ];

  void openItem(_NavItem item) {
    if (item.page == null) return; // Tableau de bord = déjà affiché
    Navigator.push(context, MaterialPageRoute(builder: (_) => item.page!));
  }

  Widget _syncAction() => Stack(clipBehavior: Clip.none, children: [
        IconButton(
          icon: syncing
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(pendingSync > 0 ? Icons.cloud_off : Icons.cloud_done_outlined),
          tooltip: pendingSync > 0 ? '$pendingSync élément(s) en attente de synchronisation' : 'Tout est synchronisé',
          onPressed: () => syncNow(),
        ),
        if (pendingSync > 0)
          Positioned(
            right: 6, top: 6,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text('$pendingSync', style: const TextStyle(color: Colors.white, fontSize: 10), textAlign: TextAlign.center),
            ),
          ),
      ]);

  Widget _sidebarContent(BuildContext c, {required bool inDrawer}) => Container(
        width: 260,
        color: QhseColors.bg,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: QhseColors.blue, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.shield, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Gestion QHSE 360', style: TextStyle(color: QhseColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('Qualité · Sécurité · Hygiène · Environnement', style: TextStyle(color: QhseColors.textSecondary, fontSize: 10)),
                    ]),
                  ),
                ]),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    for (final group in navGroups) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
                        child: Text(group.label, style: TextStyle(color: QhseColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.4)),
                      ),
                      for (final item in group.items)
                        ListTile(
                          dense: true,
                          leading: Icon(item.icon, size: 18, color: item.page == null ? QhseColors.blue : QhseColors.textSecondary),
                          title: Text(item.label, style: TextStyle(fontSize: 13, color: item.page == null ? QhseColors.blue : QhseColors.textPrimary)),
                          selected: item.page == null,
                          selectedTileColor: QhseColors.blue.withOpacity(0.12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          onTap: () { if (inDrawer) Navigator.pop(c); openItem(item); },
                        ),
                    ],
                  ],
                ),
              ),
              Divider(color: QhseColors.border, height: 1),
              ListTile(
                leading: Icon(Icons.settings_outlined, size: 18, color: QhseColors.textSecondary),
                title: Text('Réglages', style: TextStyle(fontSize: 13, color: QhseColors.textPrimary)),
                onTap: () { if (inDrawer) Navigator.pop(c); Navigator.push(c, MaterialPageRoute(builder: (_) => const SettingsPage())); },
              ),
              ListTile(
                leading: Icon(Icons.logout, size: 18, color: QhseColors.textSecondary),
                title: Text('Déconnexion', style: TextStyle(fontSize: 13, color: QhseColors.textPrimary)),
                onTap: logout,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext c) {
    final wide = MediaQuery.of(c).size.width >= 900;
    final appBar = AppBar(
      title: const Text('Tableau de bord'),
      actions: [
        if (user != null)
          Padding(padding: const EdgeInsets.only(right: 8), child: Center(child: Text('${user!['firstName'] ?? ''}', style: const TextStyle(fontSize: 13)))),
        ValueListenableBuilder<bool>(
          valueListenable: isDarkMode,
          builder: (context, dark, _) => IconButton(
            icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            tooltip: dark ? 'Passer en mode clair' : 'Passer en mode sombre',
            onPressed: () async {
              isDarkMode.value = !isDarkMode.value;
              final p = await SharedPreferences.getInstance();
              await p.setBool('dark_mode', isDarkMode.value);
            },
          ),
        ),
        _syncAction(),
      ],
    );
    if (wide) {
      return Scaffold(
        body: Row(children: [
          _sidebarContent(c, inDrawer: false),
          VerticalDivider(width: 1, color: QhseColors.border),
          Expanded(child: Scaffold(appBar: appBar, body: const DashboardPage())),
        ]),
      );
    }
    return Scaffold(
      appBar: appBar,
      drawer: Drawer(child: _sidebarContent(c, inDrawer: true)),
      body: const DashboardPage(),
    );
  }
}

class _NavGroup { final String label; final List<_NavItem> items; _NavGroup(this.label, this.items); }
class _NavItem { final String label; final IconData icon; final Widget? page; _NavItem(this.label, this.icon, this.page); }

// Page honnête pour les modules qui n'ont pas encore de table dédiée côté
// API (voir ROADMAP-CONSOLIDATION.md) — jamais d'écran vide silencieux.
class ComingSoonPage extends StatelessWidget {
  final String title;
  const ComingSoonPage({super.key, required this.title});
  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.hourglass_empty, size: 48, color: QhseColors.textSecondary),
              const SizedBox(height: 16),
              Text('$title n\'est pas encore connecté', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: QhseColors.textPrimary), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('Ce module nécessite une nouvelle table dans la base — il sera activé lors d\'une prochaine mise à jour.', style: TextStyle(fontSize: 13, color: QhseColors.textSecondary), textAlign: TextAlign.center),
            ]),
          ),
        ),
      );
}

