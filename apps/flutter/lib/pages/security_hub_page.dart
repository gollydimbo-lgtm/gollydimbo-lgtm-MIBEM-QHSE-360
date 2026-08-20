import 'package:flutter/material.dart';
import 'safety_events_page.dart';
import 'non_conformities_page.dart';
import 'actions_page.dart';
import 'risks_page.dart';
import 'audits_page.dart';
import 'safety_talk_page.dart';

class SecurityHubPage extends StatelessWidget {
  const SecurityHubPage({super.key});

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('HSE & Sécurité')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _tile(c, Icons.local_hospital, 'Accidents & situations dangereuses', 'Accidents, incidents, presqu\'accidents, GPS et photos', const SafetyEventsPage()),
        _tile(c, Icons.report, 'Non-conformités', 'Déclaration, suivi, actions correctives liées', const NonConformitiesPage()),
        _tile(c, Icons.checklist, 'Actions correctives', 'Vue transverse toutes NC, échéances et retards', const ActionsPage()),
        _tile(c, Icons.warning, 'Risques (DUERP)', 'Matrice gravité × probabilité × maîtrise', const RisksPage()),
        _tile(c, Icons.assignment_turned_in, 'Audits QHSE', 'Programme, planification, constats', const AuditsPage()),
        _tile(c, Icons.shield, 'Quart d\'heure sécurité', 'Thème hebdomadaire généré automatiquement, à partir des événements réels', const SafetyTalkPage()),
      ],
    ),
  );

  Widget _tile(BuildContext c, IconData icon, String title, String subtitle, Widget page) => Card(
        child: ListTile(
          leading: Icon(icon, size: 32),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => page)),
        ),
      );
}
