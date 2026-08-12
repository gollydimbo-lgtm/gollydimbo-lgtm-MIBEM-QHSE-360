# MIBEM QHSE 360 — V2

Flux central : **Contrôle terrain → Résultats → NC automatique → Action corrective automatique → Dashboard**

## Nouveautés V2 (backend)

- **Authentification JWT** (access + refresh token) avec rôles `CONTROLEUR`, `RESPONSABLE_LIGNE`, `QHSE_MANAGER`, `ADMIN`.
- **Checklist dynamique** : les points de contrôle sont typés (`BOOLEEN`, `NUMERIQUE`, `TEXTE`, `CHOIX_MULTIPLE`, `PHOTO`), avec bornes min/max, unité, caractère critique. Un template peut être rattaché à une ou plusieurs lignes de production.
- **NC + Action automatiques** : dès qu'un résultat est `NON_CONFORME`, la sévérité est déduite du caractère critique du point de contrôle (sauf si forcée dans le payload), et une action corrective est créée avec la priorité correspondante.
- **Statuts pilotés par machine à états** : les transitions NC (`OUVERTE → EN_ANALYSE → ACTION_EN_COURS → A_VERIFIER → CLOTUREE`, ou `REJETEE`) et Action (`OUVERTE → EN_COURS → TERMINEE → A_VERIFIER → CLOTUREE`) sont validées côté serveur — impossible de clôturer une NC tant qu'une action liée n'est pas terminée.
- **Actions en retard automatiques** : un job planifié (toutes les heures) bascule en `EN_RETARD` toute action dont l'échéance est dépassée.
- **Photos + géolocalisation** : upload multipart avec GPS, rattachable à un contrôle, un résultat, une NC ou une action.
- **Base prête pour le mode hors ligne** : chaque `Control`/`Attachment` porte un `clientLocalId` (UUID généré côté mobile) + `syncStatus`. L'endpoint `POST /api/controls/sync` accepte un lot et est **idempotent** : rejouer un envoi déjà traité ne duplique jamais les NC/actions.
- **Dashboard enrichi** : taux de conformité, NC critiques/ouvertes, actions en retard, contrôles en attente de synchronisation, **Pareto des NC par catégorie**, **tendance de conformité** dans le temps.
- **Validation stricte** de tous les payloads avec `zod`.

## Prérequis

- Docker Desktop + Docker Compose
- Node.js 20+ si lancement hors Docker
- Flutter 3.24+ pour l'application mobile (V2 Flutter à venir dans un lot suivant)

## Démarrage

```bash
cd backend
cp .env.example .env   # puis changer JWT_ACCESS_SECRET / JWT_REFRESH_SECRET
docker compose up --build
```

C'est tout — au premier démarrage, le conteneur `api` applique automatiquement
le schéma de base de données puis exécute le seed (compte de démo inclus).
Compte de quelques dizaines de secondes le temps que Postgres soit prêt et
que le schéma soit créé ; suis les logs (`docker compose logs -f api`) si tu
veux voir la progression.

API : http://localhost:3000
Swagger : http://localhost:3000/docs
Health : http://localhost:3000/health

Compte de démonstration créé par le seed :
`controleur@mibem.local` / `Mibem@2026` (rôle QHSE_MANAGER)

## Authentification

```bash
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"controleur@mibem.local","password":"Mibem@2026"}'
```

Réponse : `{ accessToken, refreshToken, user }`.
Toutes les routes `/api/*` (sauf `/api/auth/*`) exigent l'en-tête :
`Authorization: Bearer <accessToken>`

## Récupérer la checklist dynamique d'une ligne

```bash
curl http://localhost:3000/api/control-templates/line/<productionLineId> \
  -H "Authorization: Bearer <token>"
```

## Créer un contrôle (NC + action auto si NON_CONFORME)

```bash
curl -X POST http://localhost:3000/api/controls \
  -H "Content-Type: application/json" -H "Authorization: Bearer <token>" \
  -d '{
    "controllerId":"00000000-0000-0000-0000-000000000001",
    "productionLineId":"00000000-0000-0000-0000-000000000101",
    "latitude": 5.336,
    "longitude": -4.027,
    "results":[
      {
        "controlPointId":"00000000-0000-0000-0000-000000000401",
        "result":"NON_CONFORME",
        "observation":"Bouchon mal positionné"
      }
    ]
  }'
```

## Synchronisation offline (lot, idempotent)

```bash
curl -X POST http://localhost:3000/api/controls/sync \
  -H "Content-Type: application/json" -H "Authorization: Bearer <token>" \
  -d '{"controls":[{ "...": "un ou plusieurs contrôles avec clientLocalId" }]}'
```

## Transitions de statut

```bash
curl -X PATCH http://localhost:3000/api/non-conformities/<id>/status \
  -H "Content-Type: application/json" -H "Authorization: Bearer <token>" \
  -d '{"toStatus":"EN_ANALYSE","comment":"Analyse en cours par le responsable ligne"}'

curl -X PATCH http://localhost:3000/api/actions/<id>/status \
  -H "Content-Type: application/json" -H "Authorization: Bearer <token>" \
  -d '{"toStatus":"CLOTUREE","effectiveness":"Vérifié efficace sur 3 lots suivants"}'
```

## Upload d'une photo terrain

```bash
curl -X POST http://localhost:3000/api/attachments \
  -H "Authorization: Bearer <token>" \
  -F "file=@photo.jpg" \
  -F 'meta={"ownerType":"NON_CONFORMITY","ownerId":"<ncId>","latitude":5.336,"longitude":-4.027}'
```

## Dashboard

```bash
curl http://localhost:3000/api/dashboard/overview   -H "Authorization: Bearer <token>"
curl http://localhost:3000/api/dashboard/pareto      -H "Authorization: Bearer <token>"
curl http://localhost:3000/api/dashboard/trend?days=30 -H "Authorization: Bearer <token>"
```

## Architecture backend

```
backend/src/
  lib/            prisma client, JWT/hash, générateur de références
  middleware/     authenticate (JWT), requireRole
  validation/     schémas zod par endpoint
  services/       ingestControl (NC/action auto), machines à états NC/Action
  jobs/           job planifié actions en retard
  routes/         auth, control-templates, controls, non-conformities, actions, attachments, dashboard
  main.ts         assemblage Express
```

## Application Flutter V2 (nouveau)

Structure : `flutter_app/lib/`
```
core/            auth_service.dart (session + refresh), api_client.dart (Bearer + retry 401), models.dart
features/
  auth/          écran de connexion
  dashboard/     indicateurs + Pareto (à brancher) + tendance
  control_capture/  formulaire dynamique généré depuis la checklist du backend
  non_conformities/ liste + transitions de statut (boutons générés selon l'état courant)
  actions/          liste + transitions de statut (clôture avec commentaire d'efficacité requis)
  home_shell.dart   navigation par onglets
shared/widgets/  MetricCard, StatusChip, palettes de couleur par statut/sévérité
```

Le projet ne contient que `lib/` et `pubspec.yaml` — les dossiers de plateforme
(`android/`, `ios/`, `windows/`, `web/`) ne sont pas générés dans cette
livraison. Pour les créer :

```bash
cd flutter_app
flutter create . --platforms=android,windows,web
flutter pub get
flutter run --dart-define=API_BASE_URL=http://<adresse-de-ton-backend>:3000
```

Par défaut `API_BASE_URL` vaut `http://localhost:3000` — utile uniquement en
émulateur/desktop sur la même machine que le backend. Sur un appareil Android
physique, remplace par l'IP locale du poste qui héberge l'API (ex.
`http://192.168.1.50:3000`).

**Important** : le formulaire de saisie de contrôle appelle
`GET /api/reference-data`, `GET /api/control-templates/line/:id` et
`POST /api/controls` — tous protégés par JWT. Connecte-toi d'abord avec le
compte de démo créé par le seed.

**Ce qui n'est pas encore fait côté Flutter** (lot suivant) : capture photo
réelle avec upload vers `/api/attachments`, géolocalisation du contrôle,
persistance locale (SQLite/Drift) et file de synchronisation vers
`/api/controls/sync` pour le mode hors ligne. Le bouton "Prendre une photo"
sur les points de type `PHOTO` est actuellement un espace réservé UI.

## Roadmap (lots suivants)

1. ~~Flutter V2 — saisie de contrôle générée dynamiquement, auth, NC/Actions~~ ✅
2. **Couche offline Flutter** — base locale (Drift/SQLite), file de synchronisation vers `/api/controls/sync`, capture photo + GPS (`geolocator`, `camera`/`image_picker`).
3. **Dashboard visuel** — graphiques Pareto et tendance de conformité (déjà exposés par l'API `/api/dashboard/pareto` et `/api/dashboard/trend`, restent à représenter graphiquement dans l'app).

## Héberger le backend gratuitement depuis ton PC, accessible sur internet

**Ce qui est déjà garanti** : il n'existe aucune page d'inscription publique
dans l'API — les comptes utilisateurs ne peuvent être créés que par toi
(via le script de seed, ou une future page d'administration). Ce critère est
respecté par construction.

**Solution retenue : Cloudflare Tunnel** — gratuit, pas de compte payant,
pas de configuration de routeur/box internet (pas de "port forwarding"),
donne une adresse en **HTTPS** (donc plus besoin d'autoriser le HTTP en
clair pour parler à l'app Android).

### Principe

```
[Ton PC Windows]                    [Internet]
  Backend (Docker, port 3000)
        │
   cloudflared (petit programme)  ──▶  https://xxxxx.trycloudflare.com
        │                                     │
   (tunnel sortant, rien à ouvrir       Utilisée dans l'app comme
    sur ton routeur)                    adresse du serveur
```

### Mise en place

1. **Backend lancé** : `docker compose up -d` dans `backend/` (voir section Démarrage plus haut). Vérifie que `http://localhost:3000/health` répond bien dans ton navigateur.
2. **Installer cloudflared** : télécharge l'exécutable Windows depuis `https://github.com/cloudflare/cloudflared/releases/latest` (fichier `cloudflared-windows-amd64.exe`), renomme-le `cloudflared.exe`, place-le par exemple dans `C:\cloudflared\`.
3. **Lancer le tunnel** : ouvre une invite de commandes dans ce dossier et tape :
   ```
   cloudflared.exe tunnel --url http://localhost:3000
   ```
   Une adresse apparaît, du type `https://mot-aleatoire.trycloudflare.com`. C'est l'adresse à donner à l'app (écran "Adresse du serveur" au premier lancement, ou bouton paramètres ensuite).
4. **Laisser tourner** : cette fenêtre doit rester ouverte tant que tu veux que le service soit accessible. Pour qu'elle démarre automatiquement avec Windows : crée un raccourci vers `cloudflared.exe tunnel --url http://localhost:3000` et place-le dans le dossier Démarrage de Windows (`Win + R` → tape `shell:startup` → colle le raccourci).

### Limite à connaître

Cette adresse gratuite **change à chaque redémarrage** de `cloudflared`
(donc à chaque redémarrage de ton PC). Ce n'est pas grave : grâce à l'écran
de paramètres ajouté dans l'app, il suffit d'ouvrir l'app → bouton
"Paramètres serveur" → coller la nouvelle adresse. Aucune reconstruction de
l'app n'est nécessaire.

Si un jour tu veux une adresse fixe qui ne change jamais (plus pratique à
grande échelle), l'option est un **tunnel nommé Cloudflare** avec un nom de
domaine à toi (coût ~8-12 €/an pour le domaine seul, le tunnel reste
gratuit). Dis-moi si tu veux qu'on mette ça en place plus tard.

## Écran "Adresse du serveur" dans l'app Flutter

Au tout premier lancement (avant même l'écran de connexion), l'app demande
l'adresse du serveur et la mémorise. Elle est modifiable ensuite :
- Depuis l'écran de connexion : petit bouton "Serveur : ..." en bas.
- Une fois connecté : icône ⚙️ (paramètres serveur) dans la barre du haut.
Changer d'adresse déconnecte automatiquement la session en cours (propre,
pas de mélange entre deux serveurs).

Le workflow `.github/workflows/build-apps.yml` gère tout, sans rien installer
en local :

1. **Job `scaffold`** — au premier run, si `flutter_app/android` et
   `flutter_app/windows` n'existent pas encore, il les génère avec
   `flutter create`, applique deux correctifs indispensables, puis committe
   le résultat dans le dépôt (commit marqué `[skip ci]` pour ne pas
   redéclencher le workflow en boucle) :
   - **HTTP en clair autorisé sur Android** — depuis Android 9, `http://`
     (non chiffré) est bloqué par défaut ; comme ton backend tourne en HTTP
     simple sur le réseau MIBEM, ce correctif est nécessaire pour que l'app
     puisse le joindre.
   - **Nom de l'application** — "MIBEM QHSE 360" au lieu du nom technique
     `mibem_qhse_360` généré par défaut.
   Aux runs suivants, ces dossiers existent déjà : ce job ne fait rien
   (quelques secondes) et passe directement aux builds.

2. **Jobs `build-android` / `build-windows`** — compilent et publient
   l'APK et le zip Windows comme artefacts du run.

### Réglage préalable obligatoire (une seule fois, dans GitHub)

Le job `scaffold` doit pouvoir pousser un commit dans ton dépôt. Par défaut,
GitHub restreint parfois cette permission :

`Settings du dépôt → Actions → General → Workflow permissions` →
sélectionne **"Read and write permissions"** → Save.

Sans ce réglage, le job `scaffold` échouera à l'étape "Committer les
dossiers générés" avec une erreur 403.

### Utilisation

1. Committe et pousse ce projet (avec `.github/workflows/build-apps.yml`) sur GitHub.
2. *(Optionnel)* `Settings → Secrets and variables → Actions → Variables` → ajoute `API_BASE_URL` avec l'adresse de ton backend accessible depuis les appareils qui utiliseront l'app (ex. `http://192.168.1.50:3000`). Sans cette variable, l'app est buildée avec `http://localhost:3000` par défaut.
3. `Actions → Build MIBEM QHSE 360 (Android + Windows) → Run workflow` — ou pousse simplement un commit touchant `flutter_app/`.
4. À la fin du run (deux builds en parallèle, quelques minutes), récupère dans l'onglet **Actions du run** :
   - `mibem-qhse-360-android` → contient `app-release.apk`, à copier sur le téléphone (autoriser "sources inconnues" à l'installation).
   - `mibem-qhse-360-windows` → contient un zip avec l'exécutable **et ses DLL** ; décompresser entièrement avant de lancer l'exe (l'exe seul ne fonctionne pas isolé du reste du dossier).

### Icône de l'application (optionnel)

Le scaffold auto ne génère pas d'icône personnalisée. Si tu veux un logo
MIBEM sur l'app : ajoute `flutter_launcher_icons` en dev dependency dans
`pubspec.yaml`, dépose un `assets/icon.png` (1024×1024) et une étape
`flutter pub run flutter_launcher_icons` dans le job `scaffold` avant le
commit. Dis-moi si tu veux que je l'intègre — j'aurai besoin du logo.

### Signature Android pour une distribution hors Play Store

Le build `--release` du workflow est signé avec la clé de debug Flutter par
défaut — suffisant pour un usage interne MIBEM avec installation manuelle
(Android affichera juste un avertissement "source inconnue" à
l'installation, normal). Pour une signature propre si l'app devait un jour
être distribuée plus largement : génère une clé avec `keytool`, stocke-la
en secret GitHub (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`,
etc.), et ajoute une étape dans `build-android` qui la restaure et configure
`android/app/build.gradle` avant le build. Dis-moi si tu veux que je
l'ajoute.

## Note environnement de génération

Ce projet a été préparé sans exécution de `prisma migrate`/`prisma generate` en environnement isolé (accès réseau restreint aux binaires Prisma). Exécute ces commandes dans ton propre environnement (Docker ou local) pour générer le client et la première migration — voir section Démarrage.
