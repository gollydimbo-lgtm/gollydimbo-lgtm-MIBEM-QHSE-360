# Contrôle Qualité MIBEM V4

## Workflow
1. Choisir site, ligne, machine, produit, format, quart et lot.
2. Capturer GPS au démarrage.
3. Charger le modèle de contrôle et ses paramètres.
4. Saisir chaque résultat (booléen, numérique, texte, choix, photo).
5. Ajouter photos comme preuves.
6. Signer le contrôle.
7. Soumettre.
8. Le serveur vérifie les points obligatoires et les limites numériques.
9. Tout résultat non conforme génère automatiquement une Non-conformité et une Action corrective initiale.
10. Le contrôle passe à COMPLIANT ou NON_COMPLIANT.

## Données MIBEM prévues
- Produits : Vin Bouchet, Liqueur, PET, Vin en brique.
- Quarts : matin, soir, nuit.
- Catalogue lignes/machines extensible depuis l'API.
- Lots et formats saisis à chaque contrôle.

## API principales
- GET /api/v4/quality/catalogs
- GET /api/v4/quality/templates
- POST /api/v4/quality/controls
- GET /api/v4/quality/controls
- GET /api/v4/quality/controls/:id
- POST /api/v4/quality/controls/:id/results
- POST /api/v4/attachments/base64
- POST /api/v4/quality/controls/:id/attachments
- POST /api/v4/quality/controls/:id/signatures
- POST /api/v4/quality/controls/:id/submit
