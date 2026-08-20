import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/auth_service.dart';
import 'dashboard/dashboard_page.dart';
import 'control_capture/control_capture_page.dart';
import 'non_conformities/non_conformities_page.dart';
import 'actions/actions_page.dart';
import 'risks/risks_page.dart';
import 'safety_events/safety_events_page.dart';
import 'settings/server_setup_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  // Liste de constructeurs (pas d'instances figées) : chaque changement
  // d'onglet crée une NOUVELLE instance de la page, ce qui relance son
  // chargement de données depuis l'API. Avant, avec IndexedStack, les pages
  // restaient vivantes en permanence et gardaient leurs données figées au
  // premier chargement — un contrôle créé pendant la session n'apparaissait
  // jamais dans l'onglet NC tant qu'on ne relançait pas complètement l'app.
  static const List<Widget Function()> _pageBuilders = [
    _buildDashboard,
    _buildControlCapture,
    _buildNonConformities,
    _buildActions,
  ];

  static Widget _buildDashboard() => const DashboardPage();
  static Widget _buildControlCapture() => const ControlCapturePage();
  static Widget _buildNonConformities() => const NonConformitiesPage();
  static Widget _buildActions() => const ActionsPage();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('MIBEM QHSE 360'),
        actions: [
          if (auth.user != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(child: Text(auth.user!.employeeFullName)),
            ),
          IconButton(
            icon: const Icon(Icons.dns_outlined),
            tooltip: 'Paramètres serveur',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ServerSetupPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Déconnexion',
            onPressed: () => context.read<AuthService>().logout(),
          ),
        ],
      ),
      // Key(_index) force Flutter à considérer chaque onglet comme un widget
      // différent à chaque sélection, donc à recréer sa State (et donc son
      // initState -> chargement API) plutôt que de réutiliser l'ancienne.
      body: KeyedSubtree(
        key: ValueKey(_index),
        child: _pageBuilders[_index](),
      ),
      // Modules secondaires (utilisés moins souvent au quotidien que les 4
      // onglets principaux) accessibles via le menu latéral plutôt que
      // d'ajouter sans cesse des onglets à la barre du bas.
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF0B3A67)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text('MIBEM QHSE 360', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  if (auth.user != null)
                    Text(auth.user!.employeeFullName, style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dangerous_outlined),
              title: const Text('Risques'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RisksPage()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.health_and_safety_outlined),
              title: const Text('Événements sécurité'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SafetyEventsPage()));
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.add_task_outlined), selectedIcon: Icon(Icons.add_task), label: 'Contrôle'),
          NavigationDestination(icon: Icon(Icons.report_problem_outlined), selectedIcon: Icon(Icons.report_problem), label: 'NC'),
          NavigationDestination(icon: Icon(Icons.checklist_outlined), selectedIcon: Icon(Icons.checklist), label: 'Actions'),
        ],
      ),
    );
  }
}
