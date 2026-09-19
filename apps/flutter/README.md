# QHSE MIBEM Flutter V4

Client unique Android / Windows (Web non supporté depuis l'ajout de la
gestion d'erreurs réseau bas niveau — voir « Limites » plus bas).

## ⚠️ Dossiers natifs générés automatiquement

Ce dépôt ne contient que `lib/` et `pubspec.yaml`. Les dossiers `android/`
et `windows/` sont **générés par le SDK Flutter réel via GitHub Actions**
(`.github/scripts/ensure-flutter-platforms.sh`), pas écrits à la main —
c'est le seul moyen fiable de produire ces centaines de fichiers de
scaffolding (Gradle, CMake, runner C++...). Si vous avez un SDK Flutter en
local, vous pouvez aussi lancer vous-même :

```bash
cd apps/flutter
flutter create --platforms=android,windows --org=com.mibem --project-name=qhse_mobile .
```

Cette commande ne touche pas à `lib/` ni `pubspec.yaml` existants — elle
ne fait qu'ajouter les dossiers natifs manquants.

## Adresse du serveur QHSE

L'URL de l'API n'est plus codée en dur. Elle se configure de trois façons,
par ordre de priorité croissante :

1. Valeur par défaut de compilation : `http://10.0.2.2:3000/api/v4`
   (alias standard de `localhost` de votre PC depuis un émulateur Android)
2. `--dart-define=API_BASE_URL=...` au moment du build (utilisé par les
   workflows CI, variable de dépôt `QHSE_API_BASE_URL`)
3. **Écran Réglages** dans l'app (accessible depuis l'écran de connexion et
   depuis le tableau de bord) — l'agent terrain saisit l'adresse réelle du
   serveur (ex. `http://192.168.1.20:3000/api/v4`) et peut tester la
   connexion (`GET /health`) avant de l'enregistrer. C'est la méthode à
   utiliser sur un téléphone Android physique.

## Modules

- **Connexion** — JWT, session persistée localement, déconnexion
  automatique si le serveur répond 401 (jeton expiré)
- **Tableau de bord** — KPI, indicateurs Qualité/Sécurité/Environnement/RH,
  alertes prioritaires (`GET /dashboard`)
- **Contrôle qualité** — catalogue site/ligne/machine/produit/format/quart,
  lot, GPS, checklist dynamique, résultats, photos, signature, soumission
  avec génération automatique NC + action corrective
- **EPI** — effectif du jour, stock et distribution journalière/annuelle,
  renouvellements à venir
- **HSE & Sécurité** (hub) :
  - Accidents / Incidents / Presqu'accidents / Situations dangereuses
  - Non-conformités + actions correctives liées
  - Actions correctives (vue transverse, retards)
  - Risques (DUERP), matrice gravité×probabilité×maîtrise
  - Audits QHSE
  - Quart d'heure sécurité (stub, à développer)
- **Équipements** — registre consultable hors-ligne (mise en cache locale),
  identification par scan de QR code (caméra, Android/iOS uniquement —
  non disponible sur Windows), fiche détaillée (identification, plans de
  maintenance, contrôles, étalonnages, NC liées) et déclaration de contrôles
  réglementaires sur le terrain, synchronisée automatiquement au retour du
  réseau via la même file d'attente que les autres déclarations terrain
- **Veille réglementaire** — parité complète avec le tableau de bord web :
  Textes réglementaires (fiche complète + analyse d'impact "à analyser",
  jamais de conclusion automatique), Exigences (matrice dynamique, filtres
  domaine/site/applicabilité/conformité), statuer sur l'applicabilité
  (justification obligatoire si non applicable/partielle), évaluations de
  conformité, preuves de conformité (avec dates d'expiration), liaison aux
  risques et documents GED, génération de NC/actions CAPA, demandes de
  réévaluation de risque (tâche à traiter, jamais une note modifiée
  directement), alertes et échéances, rapports (taux de conformité par
  domaine/site, matrice de traçabilité), référentiel des domaines, et
  l'ancien catalogue simple conservé en sous-onglet pour compatibilité
- **Réglages** — adresse du serveur QHSE

## Lancement local (si vous disposez du SDK Flutter)

```bash
flutter pub get
flutter run -d windows
flutter run -d <android-device>
```

## Compilation via GitHub Actions (recommandé — aucun SDK local requis)

Les workflows `.github/workflows/build-apk.yml` et `build-windows.yml` :
1. Installent le SDK Flutter dans le runner
2. Génèrent `android/` et `windows/` s'ils sont absents, et patchent les
   permissions Android nécessaires (Internet, Caméra, GPS)
3. Compilent en mode release
4. Publient les artefacts sur une release GitHub `mobile-latest`
   (Android en premier, puis Windows déclenché à la suite via
   `workflow_run`, tous deux attachés à la même release)

Déclenchement manuel possible depuis l'onglet Actions de GitHub
(`workflow_dispatch`), avec une URL d'API optionnelle en paramètre.

## Limites connues

- **Web non supporté** : le service API utilise désormais `dart:io`
  (détection fine des erreurs réseau : timeout, serveur injoignable...),
  ce qui casse la compilation `flutter run -d chrome`. Si le web redevient
  nécessaire, il faudra un import conditionnel (`dart:io` vs `dart:html`)
  — dites-le moi et je l'ajoute.
- Le GPS des déclarations HSE terrain (accidents, NC, risques) est stocké
  en texte dans la description faute de colonnes dédiées en base — voir
  le README du patch précédent pour la migration à faire si vous voulez
  des coordonnées exploitables.
