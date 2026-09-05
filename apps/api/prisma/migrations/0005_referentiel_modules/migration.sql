-- Additif uniquement : crée 7 nouvelles tables. Aucune table existante
-- n'est modifiée, aucune donnée ne peut être perdue par cette migration.

CREATE TABLE "Processus" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "code" TEXT NOT NULL,
  "nom" TEXT NOT NULL,
  "proprietaire" TEXT,
  "objectifs" TEXT,
  "kpi" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE UNIQUE INDEX "Processus_code_key" ON "Processus"("code");

CREATE TABLE "IndicateurQualite" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "code" TEXT NOT NULL,
  "indicateur" TEXT NOT NULL,
  "actuel" DOUBLE PRECISION NOT NULL,
  "cible" DOUBLE PRECISION NOT NULL,
  "unite" TEXT,
  "sensInverse" BOOLEAN NOT NULL DEFAULT false,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL
);
CREATE UNIQUE INDEX "IndicateurQualite_code_key" ON "IndicateurQualite"("code");

CREATE TABLE "Reclamation" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "code" TEXT NOT NULL,
  "client" TEXT NOT NULL,
  "motif" TEXT NOT NULL,
  "description" TEXT,
  "date" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "gravite" TEXT NOT NULL DEFAULT 'Faible',
  "statut" TEXT NOT NULL DEFAULT 'OPEN',
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL
);
CREATE UNIQUE INDEX "Reclamation_code_key" ON "Reclamation"("code");

CREATE TABLE "Fournisseur" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "code" TEXT NOT NULL,
  "nom" TEXT NOT NULL,
  "categorie" TEXT,
  "scoreQualite" INTEGER,
  "derniereEvaluation" TIMESTAMP(3),
  "statut" TEXT NOT NULL DEFAULT 'HOMOLOGUE',
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL
);
CREATE UNIQUE INDEX "Fournisseur_code_key" ON "Fournisseur"("code");

CREATE TABLE "VisiteMedicale" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "code" TEXT NOT NULL,
  "employeNom" TEXT NOT NULL,
  "poste" TEXT,
  "aptitude" TEXT,
  "statut" TEXT NOT NULL DEFAULT 'A_VENIR',
  "prochaineVisite" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL
);
CREATE UNIQUE INDEX "VisiteMedicale_code_key" ON "VisiteMedicale"("code");

CREATE TABLE "VeilleReglementaire" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "code" TEXT NOT NULL,
  "texte" TEXT NOT NULL,
  "domaine" TEXT,
  "dateApplication" TIMESTAMP(3),
  "statut" TEXT NOT NULL DEFAULT 'A_TRAITER',
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL
);
CREATE UNIQUE INDEX "VeilleReglementaire_code_key" ON "VeilleReglementaire"("code");

CREATE TABLE "ObjectifQhse" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "code" TEXT NOT NULL,
  "titre" TEXT NOT NULL,
  "pilier" TEXT,
  "cible" DOUBLE PRECISION NOT NULL,
  "actuel" DOUBLE PRECISION NOT NULL DEFAULT 0,
  "unite" TEXT,
  "echeance" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL
);
CREATE UNIQUE INDEX "ObjectifQhse_code_key" ON "ObjectifQhse"("code");
