# QHSE Platform V4 — branchement PostgreSQL + API + Contrôle Qualité

## 1. Démarrage recommandé avec Docker

Depuis la racine :

```bash
docker compose up -d --build
```

Le service PostgreSQL est disponible sur `localhost:5432` et l'API sur `http://localhost:3000/api/v4`.

Le conteneur API applique automatiquement les migrations Prisma avant de démarrer.

## 2. Initialiser les données de référence

Dans le conteneur API :

```bash
docker exec qhse-api npx prisma db seed
```

Compte de démonstration :

- email : `admin@qhse.local`
- mot de passe : `Admin12345!`

Changez ce mot de passe avant toute utilisation réelle.

## 3. Vérifier PostgreSQL

```bash
curl http://localhost:3000/api/v4/health
```

Réponse attendue :

```json
{"status":"ok","database":"up"}
```

## 4. Migration Prisma

En développement local :

```bash
cd apps/api
cp .env.example .env
npm install
npx prisma generate
npx prisma migrate deploy
npx prisma db seed
```

La migration initiale est dans `apps/api/prisma/migrations/0001_v4_core/migration.sql`.

## 5. Test API de bout en bout

Une fois l'API lancée :

```bash
cd apps/api
npm run test:api
```

Le smoke test vérifie :

1. santé API + connexion PostgreSQL ;
2. authentification ;
3. création d'un modèle de contrôle ;
4. création d'un contrôle qualité ;
5. saisie des résultats ;
6. soumission du contrôle ;
7. création automatique d'une non-conformité lorsqu'un point critique est non conforme.

## 6. Module Contrôle Qualité

Endpoints :

- `GET /api/v4/quality/templates`
- `POST /api/v4/quality/templates`
- `GET /api/v4/quality/controls`
- `GET /api/v4/quality/controls/:id`
- `POST /api/v4/quality/controls`
- `POST /api/v4/quality/controls/:id/results`
- `POST /api/v4/quality/controls/:id/submit`

Le modèle comprend maintenant :

- templates de contrôle ;
- points de contrôle typés ;
- valeurs numériques / texte / booléennes / choix ;
- caractère obligatoire ;
- criticité ;
- limites min/max ;
- résultats ;
- validation du contrôle ;
- génération automatique d'une non-conformité.

## 7. Règles EPI conservées

Annuel : chaussures, tenue, lunettes, casque.

Journalier : gants, cache-nez, charlotte.

Les mouvements, stocks, distributions, attributions individuelles et renouvellements restent centralisés.
