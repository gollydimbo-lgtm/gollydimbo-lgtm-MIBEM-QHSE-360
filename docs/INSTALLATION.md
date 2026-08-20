# Installation MIBEM QHSE 360 — Procédure détaillée

Ce guide part de l'archive `qhse-platform-v4-COMPLET.tar.gz` (l'état
consolidé de tout ce qui a été construit dans cette conversation) et vous
emmène jusqu'à une plateforme qui tourne réellement : API + base de
données + application mobile/Windows connectées.

Comptez environ **30 minutes** pour l'API seule (partie 1 à 4), et selon
l'option choisie **quelques minutes à 15 minutes** de plus pour le client
Flutter (partie 5).

---

## 0. Ce dont vous avez besoin

| Outil | Pourquoi | Où l'obtenir |
|---|---|---|
| **Docker Desktop** (ou Docker + Docker Compose) | Fait tourner PostgreSQL + l'API sans rien installer d'autre | https://www.docker.com/products/docker-desktop |
| **Un compte GitHub** avec ce dépôt | Pour que GitHub Actions compile l'app mobile (vous n'avez pas de SDK Flutter local) | déjà en place : `gollydimbo-lgtm` |
| Un client HTTP (navigateur, Postman, ou juste `curl`) | Pour vérifier que l'API répond | déjà sur votre machine |

Vous **n'avez pas besoin** d'installer Node.js, PostgreSQL ni Flutter en
local pour suivre ce guide — Docker s'occupe de l'API, GitHub Actions
s'occupe du mobile. Si vous préférez tout faire en local, la section
« Alternative sans Docker » en bas de ce document l'explique aussi.

---

## 1. Reconstituer le projet

1. Décompressez `qhse-platform-v4-COMPLET.tar.gz` dans un dossier vide,
   par exemple `C:\MIBEM-QHSE-360\` ou `~/mibem-qhse-360/`.
2. Vous devez obtenir cette structure :

```
mibem-qhse-360/
├── .github/workflows/         (compilation automatique Android/Windows)
├── apps/
│   ├── api/                   (backend NestJS + Prisma)
│   └── flutter/                (application mobile/Windows)
└── docker-compose.yml
```

3. Si vous gérez ce projet avec Git (recommandé), initialisez le dépôt et
   poussez-le vers votre GitHub existant (`gollydimbo-lgtm`) :

```bash
cd mibem-qhse-360
git init
git add .
git commit -m "MIBEM QHSE 360 - version consolidée"
git branch -M main
git remote add origin https://github.com/gollydimbo-lgtm/<votre-depot>.git
git push -u origin main
```

Pousser sur `main` déclenchera automatiquement la compilation Android puis
Windows (voir partie 5) — vous pouvez faire cette étape maintenant et
laisser GitHub travailler en arrière-plan pendant que vous installez l'API.

---

## 2. Démarrer la base de données et l'API (avec Docker)

Dans le dossier du projet :

```bash
docker compose up -d --build
```

Cette commande :
- télécharge et démarre **PostgreSQL 16** (port 5432, utilisateur `qhse`,
  base `qhse`)
- construit l'image de l'**API NestJS** et la démarre (port 3000)
- applique automatiquement les migrations Prisma au démarrage du
  conteneur (`prisma migrate deploy` est dans la commande de lancement du
  Dockerfile)

Vérifiez que tout tourne :

```bash
docker compose ps
```

Vous devez voir deux conteneurs `qhse-postgres` et `qhse-api` avec un
statut `Up` / `healthy`. Premier démarrage : comptez 1 à 2 minutes le
temps que l'image se construise.

**En cas de problème**, consultez les logs :
```bash
docker compose logs -f api
```

---

## 3. Charger les données de démarrage (comptes, catalogues, EPI...)

Les migrations créent les tables mais pas les données. Exécutez le seed
**à l'intérieur du conteneur API** :

```bash
docker compose exec api npx prisma db seed
```

Cela crée notamment :
- un **compte administrateur** : `admin@qhse.local` / `Admin12345!`
  (avec tous les rôles et permissions)
- les **7 EPI** de votre référentiel (chaussures, tenue, lunettes, casque
  en annuel ; gants, cache-nez, charlotte en journalier)
- un site (`MIBEM-01`), une ligne (`LIGNE-01`), 2 machines, 3 produits
  (Vin Bouchet, Liqueur, PET), 3 quarts (matin/soir/nuit), et un template
  de contrôle qualité de base

⚠️ **Changez le mot de passe administrateur** dès que possible en
production (partie 7).

---

## 4. Vérifier que l'API fonctionne réellement

### 4.1 Test de santé

```bash
curl http://localhost:3000/api/v4/health
```
Réponse attendue :
```json
{"status":"ok","database":"up","timestamp":"..."}
```

### 4.2 Connexion

```bash
curl -X POST http://localhost:3000/api/v4/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@qhse.local","password":"Admin12345!"}'
```
Vous devez recevoir un `accessToken` (JWT) et un objet `user`. Gardez ce
jeton pour les appels suivants (remplacez `$TOKEN` ci-dessous).

### 4.3 Tableau de bord

```bash
curl http://localhost:3000/api/v4/dashboard \
  -H "Authorization: Bearer $TOKEN"
```
Vous devez recevoir `overview`, `trends` et `alerts` — vide au début
puisqu'aucune donnée métier n'a encore été créée, c'est normal.

### 4.4 Test automatisé complet (recommandé)

Un script de bout-en-bout existe déjà dans le projet
(`apps/api/test/api-smoke.ts`) : il se connecte, crée un contrôle qualité,
soumet un résultat non conforme, et vérifie qu'une non-conformité **et**
une action corrective ont bien été générées automatiquement. C'est le
meilleur moyen de confirmer que toute la chaîne fonctionne d'un coup :

```bash
docker compose exec api npm run test:api
```

Sortie attendue :
```
API SMOKE TEST: PASS — Quality control → result → NC → action
```

Si cette ligne s'affiche, **toute la chaîne backend fonctionne** :
authentification, contrôle qualité, génération automatique de NC et
d'action corrective, base de données.

---

## 5. Installer l'application mobile/Windows

Vous n'avez pas de SDK Flutter local : la compilation se fait via GitHub
Actions, qui génère les dossiers natifs manquants et produit l'APK et
l'exécutable Windows.

### 5.1 Déclencher la compilation

Si vous avez déjà poussé sur `main` à l'étape 1, c'est déjà en cours.
Sinon, ou pour relancer manuellement :

1. Allez sur votre dépôt GitHub → onglet **Actions**
2. Sélectionnez le workflow **Build Android APK**
3. Cliquez **Run workflow** (bouton en haut à droite)
4. Optionnel : renseignez l'URL de votre API si vous voulez qu'elle soit
   pré-configurée dans l'app (sinon vous la configurerez à la main, voir
   5.3) — laissez vide si votre serveur n'est pas encore accessible
   publiquement
5. Une fois le build Android terminé (~5 minutes), le workflow
   **Build Windows** se déclenche automatiquement à la suite

### 5.2 Récupérer les fichiers compilés

Onglet **Actions** → cliquez sur le run terminé → section **Artifacts**
en bas de page : téléchargez `qhse-mobile-android` (contient l'APK) et
`qhse-mobile-windows` (contient le .exe zippé).

Vous les trouverez aussi regroupés sur une **Release** nommée
`mobile-latest` (menu **Releases** du dépôt), pratique pour les partager
à vos équipes terrain sans repasser par Actions à chaque fois.

### 5.3 Installer et connecter l'app

**Windows** : dézippez `qhse-mobile-windows.zip`, lancez l'exécutable
(`qhse_mobile.exe` ou équivalent).

**Android** : transférez l'APK sur le téléphone, activez « Sources
inconnues » si demandé, installez.

Au premier lancement, l'app affiche l'écran de connexion. **Avant de vous
connecter**, cliquez sur l'icône ⚙️ **Réglages** en haut à droite :

- Si vous testez sur le **même PC** que Docker, avec l'**émulateur
  Android** : laissez `http://10.0.2.2:3000/api/v4` (valeur par défaut)
- Si vous testez sur un **téléphone physique** sur le même réseau Wi-Fi
  que votre PC : remplacez par l'adresse IP locale de votre PC, par
  exemple `http://192.168.1.20:3000/api/v4` (trouvez votre IP avec
  `ipconfig` sous Windows ou `ip addr` sous Linux/Mac)
- Si l'API est hébergée sur un serveur accessible publiquement : mettez
  son URL complète, par exemple `https://qhse.mibem.com/api/v4`

Cliquez **Tester la connexion** — vous devez voir « Serveur joignable ».
Puis **Enregistrer**, revenez à l'écran de connexion, saisissez
`admin@qhse.local` / `Admin12345!`.

Vous arrivez directement sur le **tableau de bord**, avec la navigation en
bas : Dashboard / Qualité / EPI / Sécurité / Modules.

---

## 6. Premier tour du propriétaire — scénario de test complet

Pour voir la chaîne complète fonctionner de bout en bout dans l'app :

1. **Contrôle Qualité** → « Nouveau contrôle » → choisissez la ligne
   `LIGNE-01`, la machine, le produit, remplissez le lot → cochez le point
   « Étiquetage conforme » comme **non conforme** → soumettez.
   → Une non-conformité et une action corrective sont créées
   automatiquement (visible immédiatement dans l'onglet **Sécurité →
   Non-conformités**, et dans le **Dashboard** qui se met à jour).

2. **Sécurité → Accidents & situations dangereuses** → « Déclarer » →
   choisissez « Situation dangereuse », remplissez, capturez le GPS si
   l'app y est autorisée → envoyez → ajoutez une photo.

3. **Sécurité → Non-conformités** → ouvrez celle créée à l'étape 1 →
   observez les **suggestions du moteur de recommandations** apparaître
   automatiquement → cliquez sur le « + » d'une suggestion → acceptez ou
   modifiez le texte → une action corrective réelle est créée.

4. **Sécurité → Quart d'heure sécurité** → « Générer le thème de la
   semaine » → le thème est construit à partir des événements que vous
   venez de créer.

5. **Modules → EPI** → observez le stock, l'effectif du jour, les
   renouvellements.

6. **Réglages → couper le Wi-Fi** de votre téléphone → retournez déclarer
   un nouvel accident → vous verrez le message « Pas de réseau :
   déclaration enregistrée hors-ligne » → réactivez le Wi-Fi → l'icône ☁️
   en haut de l'app se synchronise automatiquement (ou appuyez dessus pour
   forcer).

7. Revenez au **Dashboard** : tous les compteurs (NC ouvertes, actions,
   événements sécurité, alertes) reflètent maintenant les données réelles
   que vous venez de créer.

---

## 7. Recommandations avant tout usage réel sur le terrain

- **Changez le mot de passe administrateur** et créez un compte par
  personne (ne partagez pas `admin@qhse.local` avec toute l'équipe) —
  l'endpoint `POST /api/v4/users` permet de créer des comptes
  (nécessite d'être connecté en administrateur).
- **Changez les secrets** `JWT_SECRET` et `REFRESH_SECRET` dans
  `docker-compose.yml` avant tout déploiement au-delà d'un test local.
- Si l'API doit être accessible depuis l'extérieur de votre réseau local
  (agents terrain hors site), il faudra l'exposer via un nom de domaine
  avec HTTPS (par exemple avec un reverse proxy comme Caddy/nginx, ou un
  tunnel comme Cloudflare Tunnel — déjà mentionné dans vos notes de
  session précédentes pour l'autre projet).

---

## Alternative sans Docker (si vous préférez tout en local)

Si vous avez déjà Node.js 22 et PostgreSQL installés :

```bash
cd apps/api
npm install
cp .env.example .env
# éditez .env si votre PostgreSQL local a des identifiants différents
npx prisma generate
npx prisma migrate deploy
npx prisma db seed
npm run start:dev
```

L'API démarre sur `http://localhost:3000/api/v4`, identique à la version
Docker.

---

## Dépannage rapide

| Symptôme | Cause probable | Solution |
|---|---|---|
| `docker compose up` échoue sur le port 5432 | PostgreSQL déjà installé et lancé en local sur votre machine | Arrêtez le service local, ou changez le port dans `docker-compose.yml` (`"5433:5432"`) |
| L'app Flutter affiche « Serveur injoignable » | Mauvaise adresse dans Réglages, ou pare-feu bloquant le port 3000 | Vérifiez l'IP avec `ipconfig`/`ip addr`, testez `curl http://<IP>:3000/api/v4/health` depuis un autre appareil du réseau |
| `prisma db seed` échoue avec une erreur de connexion | L'API/la base n'a pas fini de démarrer | Attendez que `docker compose ps` affiche `healthy`, réessayez |
| Le workflow GitHub Actions échoue au build Android | Erreur de compilation Dart quelque part | Consultez les logs du run dans l'onglet Actions ; le point le plus probable est l'écran `QualityHome`/`ControlPage` préexistant, signalé comme dense et non vérifié par mes soins dans les patchs précédents |
