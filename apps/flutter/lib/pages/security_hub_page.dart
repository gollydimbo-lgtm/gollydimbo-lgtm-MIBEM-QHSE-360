import 'package:flutter/material.dart';
import '../i18n/i18n.dart';
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
    appBar: AppBar(title: Text(t('securityHub.titre'))),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _tile(c, Icons.local_hospital, t('securityHub.accidentsTitre'), t('securityHub.accidentsSousTitre'), const SafetyEventsPage()),
        _tile(c, Icons.report, t('securityHub.ncTitre'), t('securityHub.ncSousTitre'), const NonConformitiesPage()),
        _tile(c, Icons.checklist, t('securityHub.actionsTitre'), t('securityHub.actionsSousTitre'), const ActionsPage()),
        _tile(c, Icons.warning, t('securityHub.risquesTitre'), t('securityHub.risquesSousTitre'), const RisksPage()),
        _tile(c, Icons.assignment_turned_in, t('securityHub.auditsTitre'), t('securityHub.auditsSousTitre'), const AuditsPage()),
        _tile(c, Icons.shield, t('securityHub.quartHeureTitre'), t('securityHub.quartHeureSousTitre'), const SafetyTalkPage()),
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
