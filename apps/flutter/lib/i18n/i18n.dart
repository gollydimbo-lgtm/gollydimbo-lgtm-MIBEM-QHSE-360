import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Finding #39 — même choix que côté web (apps/web/src/i18n/I18nContext.jsx) :
// dictionnaire plat par langue, adressé par clé pointée, sans dépendance
// externe (pas de flutter_localizations/ARB pour cette première étape).
// Persisté avec le même mécanisme que isDarkMode (SharedPreferences).
final ValueNotifier<String> appLang = ValueNotifier<String>('fr');

const String _prefsKey = 'app_lang';

Future<void> loadSavedLang() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString(_prefsKey);
  if (saved != null && _dictionaries.containsKey(saved)) appLang.value = saved;
}

Future<void> setAppLang(String lang) async {
  appLang.value = lang;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_prefsKey, lang);
}

const Map<String, Map<String, String>> _dictionaries = {
  'fr': {
    'nav.groups.pilotage': 'PILOTAGE',
    'nav.groups.qualite': 'QUALITÉ (ISO 9001:2015)',
    'nav.groups.securite': 'SÉCURITÉ (ISO 45001:2018)',
    'nav.groups.environnement': 'ENVIRONNEMENT (ISO 14001:2015)',
    'nav.groups.risques': 'RISQUES & AUDITS',
    'nav.groups.systeme': 'SYSTÈME',
    'nav.items.pilotage': 'Tableau de bord',
    'nav.items.qualite-controles': 'Contrôles qualité',
    'nav.items.qualite-processus': 'Processus',
    'nav.items.qualite-indicateurs': 'Indicateurs qualité',
    'nav.items.qualite-reclamations': 'Réclamations clients',
    'nav.items.qualite-fournisseurs': 'Fournisseurs',
    'nav.items.securite-accidents': 'Accidents & incidents',
    'nav.items.securite-epi': 'Gestion EPI/EPC',
    'nav.items.securite-hygiene': 'Hygiène au travail',
    'nav.items.environnement': 'Environnement',
    'nav.items.risques': 'Registre des risques',
    'nav.items.audits': 'Audits',
    'nav.items.non-conformites': 'Non-conformités',
    'nav.items.capa': 'Actions CAPA',
    'nav.items.documentation': 'Documentation (GED)',
    'nav.items.quart-heure-securite': "Quart d'heure sécurité",
    'nav.items.formation': 'Formation & Compétences',
    'nav.items.haccp': 'HACCP',
    'nav.items.equipements': 'Équipements',
    'nav.items.veille': 'Veille réglementaire',
    'nav.items.objectifs': 'Objectifs QHSE',
    'nav.items.rapports': 'Rapports',
    'nav.items.utilisateurs': 'Utilisateurs',
    'shell.appTitle': 'Gestion QHSE 360',
    'shell.appSubtitle': 'Qualité · Sécurité · Hygiène · Environnement',
    'shell.settings': 'Réglages',
    'shell.logout': 'Déconnexion',
    'shell.lightMode': 'Passer en mode clair',
    'shell.darkMode': 'Passer en mode sombre',
    'shell.notifications': 'Notifications',
    'shell.syncPending': '{{count}} élément(s) en attente de synchronisation',
    'shell.syncDone': 'Tout est synchronisé',
    'shell.language': 'Langue',
  },
  'en': {
    'nav.groups.pilotage': 'DASHBOARD',
    'nav.groups.qualite': 'QUALITY (ISO 9001:2015)',
    'nav.groups.securite': 'SAFETY (ISO 45001:2018)',
    'nav.groups.environnement': 'ENVIRONMENT (ISO 14001:2015)',
    'nav.groups.risques': 'RISKS & AUDITS',
    'nav.groups.systeme': 'SYSTEM',
    'nav.items.pilotage': 'Dashboard',
    'nav.items.qualite-controles': 'Quality controls',
    'nav.items.qualite-processus': 'Processes',
    'nav.items.qualite-indicateurs': 'Quality indicators',
    'nav.items.qualite-reclamations': 'Customer complaints',
    'nav.items.qualite-fournisseurs': 'Suppliers',
    'nav.items.securite-accidents': 'Accidents & incidents',
    'nav.items.securite-epi': 'PPE/CPE management',
    'nav.items.securite-hygiene': 'Occupational hygiene',
    'nav.items.environnement': 'Environment',
    'nav.items.risques': 'Risk register',
    'nav.items.audits': 'Audits',
    'nav.items.non-conformites': 'Non-conformities',
    'nav.items.capa': 'CAPA actions',
    'nav.items.documentation': 'Documentation (EDM)',
    'nav.items.quart-heure-securite': 'Safety briefing',
    'nav.items.formation': 'Training & Skills',
    'nav.items.haccp': 'HACCP',
    'nav.items.equipements': 'Equipment',
    'nav.items.veille': 'Regulatory watch',
    'nav.items.objectifs': 'QHSE objectives',
    'nav.items.rapports': 'Reports',
    'nav.items.utilisateurs': 'Users',
    'shell.appTitle': 'QHSE 360 Management',
    'shell.appSubtitle': 'Quality · Safety · Health · Environment',
    'shell.settings': 'Settings',
    'shell.logout': 'Log out',
    'shell.lightMode': 'Switch to light mode',
    'shell.darkMode': 'Switch to dark mode',
    'shell.notifications': 'Notifications',
    'shell.syncPending': '{{count}} item(s) pending sync',
    'shell.syncDone': 'Everything is synced',
    'shell.language': 'Language',
  },
};

String t(String key, [Map<String, String>? params]) {
  final lang = appLang.value;
  var value = _dictionaries[lang]?[key] ?? _dictionaries['fr']?[key] ?? key;
  if (params != null) {
    params.forEach((k, v) => value = value.replaceAll('{{$k}}', v));
  }
  return value;
}
