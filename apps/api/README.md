# QHSE Platform V4 — Core exécutable

Socle backend NestJS + Prisma + PostgreSQL pour la plateforme QHSE multi-applications.

## Inclus dans cette version
- PostgreSQL + Prisma V4
- Auth JWT / utilisateurs / rôles / permissions
- AuditLog
- GED de base et versions documentaires
- Attachments (modèle de données)
- Synchronisation offline/online (`/api/v4/sync/push`)
- Gestion EPI avec règles annuelles/journalières
- Stock EPI et renouvellements
- Générateur de Quart d'heure sécurité hebdomadaire
- Base SafetyEvent / NonConformity alimentant le QHS

## Lancer

Pré-requis : Docker, Node.js 20+.

1. Copier `apps/api/.env.example` en `apps/api/.env`.
2. `docker compose up -d db`
3. `cd apps/api`
4. `npm install`
5. `npx prisma generate`
6. `npx prisma migrate dev --name init`
7. `npm run prisma:seed`
8. `npm run start:dev`

API : `http://localhost:3000/api/v4`

Compte initial : `admin@qhse.local` / `Admin12345!` — à changer immédiatement.

## Endpoints de démonstration
- `POST /auth/login`
- `GET /users`
- `GET /epi/dashboard`
- `GET /epi/renewals?days=30`
- `GET /documents`
- `POST /documents`
- `GET /audit-logs`
- `POST /sync/push`
- `GET /sync/pending`
- `POST /safety-talks/generate`
- `GET /safety-talks`

## Règles EPI
Annuel : chaussures de sécurité, tenue de travail, lunettes, casque.
Journalier : gants, cache-nez, charlotte. La distribution journalière cible l'effectif présent enregistré dans `DailyHeadcount`, sinon l'effectif actif.

## Suite
Le socle doit ensuite recevoir les modules métier complets (contrôle qualité, NC/actions, accidents, risques, HACCP, audits, environnement, formations, équipements) puis les clients Flutter Android/Windows/Web.
