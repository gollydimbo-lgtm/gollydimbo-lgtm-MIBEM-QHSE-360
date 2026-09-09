# Gestion QHSE 360 — Application définitive, connectée à votre API

**Cette version se connecte réellement à votre API MIBEM QHSE 360**
(`qhse-api`, celle qui tourne dans Docker) — ce n'est plus une
démonstration pour les pages qui ont une table correspondante en base.

## 1. Avant de lancer l'application

Votre serveur doit tourner :
```bash
docker compose up -d
```
(dans le dossier `MIBEM-QHSE-360`, comme d'habitude)

## 2. Installer et lancer

```bash
npm install
npm run dev
```
Ouvrez l'adresse affichée (`http://localhost:5173`). Un écran de
connexion apparaît en premier — utilisez vos identifiants habituels
(`admin@qhse.local` / votre mot de passe). L'adresse du serveur par
défaut est `http://localhost:3000/api/v4` ; changez-la dans l'écran de
connexion si votre API tourne ailleurs.

## 3. Ce qui est réellement connecté à votre base

| Page | Source | Statut |
|---|---|---|
| Tableau de bord | `/dashboard` | ✅ Réel |
| Accidents & incidents | `/business/safety-events` | ✅ Réel |
| EPI, formations, permis | `/epi/dashboard`, `/epi/renewals` | ✅ Réel |
| Environnement | `/business/environment` | ✅ Réel |
| Registre des risques | `/business/risks` | ✅ Réel |
| Audits | `/business/audits` | ✅ Réel |
| Non-conformités | `/business/non-conformities` | ✅ Réel |
| Actions CAPA | `/business/actions` | ✅ Réel |
| Documentation | `/documents` | ✅ Réel |
| Rapports | combine les endpoints ci-dessus | ✅ Réel |
| Processus & indicateurs, Réclamations clients, Fournisseurs | — | 🟡 Démo (pas de table) |
| Hygiène au travail | — | 🟡 Démo (pas de table) |
| Veille réglementaire, Objectifs QHSE | — | 🟡 Démo (pas de table) |

Chaque page affiche un petit badge en haut : **vert** = données réelles
de votre base, **ambre** = démonstration, module pas encore connecté.

## 4. Simplifications honnêtes à connaître

- **TF/TG** (taux de fréquence/gravité) ne sont plus affichés sur la page
  Accidents : ils nécessitent le nombre d'heures travaillées, qui n'est
  enregistré nulle part dans votre base actuelle.
- **Risques** : le champ « Responsable » n'existe pas sur le modèle
  actuel — dites-le-moi si vous voulez que je l'ajoute (migration
  additive, comme toujours).
- **Audits** : pas de notion de « type » (Interne/Externe/Fournisseur)
  actuellement, seulement une « Référence » libre.
- Certaines fonctions de calcul (formules TF/TG, historique 12 mois,
  indice composite complet) restent dans le code, prêtes à être
  réactivées si vous étendez le schéma correspondant plus tard — elles
  ne sont juste plus appelées pour l'instant.

## 5. Construire la version définitive à héberger

```bash
npm run build
```
Crée `dist/` — voir les options d'hébergement dans la version précédente
de ce README (Netlify/Vercel par glisser-déposer, ou GitHub Pages).

## Prochaine étape possible

Créer les tables manquantes (réclamations, fournisseurs, hygiène, veille
réglementaire, objectifs) pour que les dernières pages en démonstration
deviennent réelles elles aussi — migration Prisma additive, exactement
sur le principe déjà utilisé pour la classification GED en 5 groupes.

