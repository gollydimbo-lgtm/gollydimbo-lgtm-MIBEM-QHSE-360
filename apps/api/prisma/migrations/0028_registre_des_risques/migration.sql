-- Additif uniquement. Aucune colonne ni table existante n'est modifiée ou
-- supprimée, aucune donnée ne peut être perdue par cette migration.
-- Phase 1 du module Registre des risques : moteur d'évaluation étendu,
-- unités de travail, catégories, mesures, historique et paramétrage.

-- Risk : enrichissement (le champ "score" existant est conservé tel quel
-- pour compatibilité avec le dashboard actuel ; "grossScore"/"grossLevel"
-- sont les nouveaux champs calculés par le moteur du Registre des risques).
ALTER TABLE "Risk" ADD COLUMN "workUnitId" TEXT;
ALTER TABLE "Risk" ADD COLUMN "categoryId" TEXT;
ALTER TABLE "Risk" ADD COLUMN "hazardousSituation" TEXT;
ALTER TABLE "Risk" ADD COLUMN "hazardousEvent" TEXT;
ALTER TABLE "Risk" ADD COLUMN "potentialDamage" TEXT;
ALTER TABLE "Risk" ADD COLUMN "exposedPersons" TEXT;
ALTER TABLE "Risk" ADD COLUMN "exposedPersonCount" INTEGER;
ALTER TABLE "Risk" ADD COLUMN "method" TEXT NOT NULL DEFAULT 'GP';
ALTER TABLE "Risk" ADD COLUMN "exposure" INTEGER NOT NULL DEFAULT 1;
ALTER TABLE "Risk" ADD COLUMN "grossScore" INTEGER;
ALTER TABLE "Risk" ADD COLUMN "grossLevel" TEXT;
ALTER TABLE "Risk" ADD COLUMN "residualSeverity" INTEGER;
ALTER TABLE "Risk" ADD COLUMN "residualProbability" INTEGER;
ALTER TABLE "Risk" ADD COLUMN "residualExposure" INTEGER;
ALTER TABLE "Risk" ADD COLUMN "residualScore" INTEGER;
ALTER TABLE "Risk" ADD COLUMN "residualLevel" TEXT;
ALTER TABLE "Risk" ADD COLUMN "controlStatus" TEXT NOT NULL DEFAULT 'NON_MAITRISE';
ALTER TABLE "Risk" ADD COLUMN "nextReviewDate" TIMESTAMP(3);
ALTER TABLE "Risk" ADD COLUMN "reviewPeriodDays" INTEGER NOT NULL DEFAULT 365;
ALTER TABLE "Risk" ADD COLUMN "archivedAt" TIMESTAMP(3);
ALTER TABLE "Risk" ADD COLUMN IF NOT EXISTS "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE "Risk" ADD COLUMN IF NOT EXISTS "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;
CREATE INDEX "Risk_status_score_idx" ON "Risk"("status","score");

-- Unité de travail
CREATE TABLE "WorkUnit" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "code" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "siteId" TEXT,
  "department" TEXT,
  "service" TEXT,
  "active" BOOLEAN NOT NULL DEFAULT true,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE UNIQUE INDEX "WorkUnit_code_key" ON "WorkUnit"("code");
ALTER TABLE "WorkUnit" ADD CONSTRAINT "WorkUnit_siteId_fkey" FOREIGN KEY ("siteId") REFERENCES "Site"("id") ON DELETE SET NULL;

-- Bibliothèque de catégories de risques (configurable)
CREATE TABLE "RiskCategory" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "code" TEXT NOT NULL,
  "label" TEXT NOT NULL,
  "order" INTEGER NOT NULL DEFAULT 0,
  "active" BOOLEAN NOT NULL DEFAULT true
);
CREATE UNIQUE INDEX "RiskCategory_code_key" ON "RiskCategory"("code");

ALTER TABLE "Risk" ADD CONSTRAINT "Risk_workUnitId_fkey" FOREIGN KEY ("workUnitId") REFERENCES "WorkUnit"("id") ON DELETE SET NULL;
ALTER TABLE "Risk" ADD CONSTRAINT "Risk_categoryId_fkey" FOREIGN KEY ("categoryId") REFERENCES "RiskCategory"("id") ON DELETE SET NULL;

-- Mesures de prévention existantes, classées par type (hiérarchie de prévention)
CREATE TABLE "RiskMeasure" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "riskId" TEXT NOT NULL,
  "description" TEXT NOT NULL,
  "type" TEXT NOT NULL,
  "responsableId" TEXT,
  "datePrise" TIMESTAMP(3),
  "efficacite" INTEGER NOT NULL DEFAULT 1,
  "justificatif" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);
ALTER TABLE "RiskMeasure" ADD CONSTRAINT "RiskMeasure_riskId_fkey" FOREIGN KEY ("riskId") REFERENCES "Risk"("id") ON DELETE CASCADE;
ALTER TABLE "RiskMeasure" ADD CONSTRAINT "RiskMeasure_responsableId_fkey" FOREIGN KEY ("responsableId") REFERENCES "User"("id") ON DELETE SET NULL;

-- Historique des évaluations successives (courbe brut -> résiduel -> réévaluation)
CREATE TABLE "RiskEvaluation" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "riskId" TEXT NOT NULL,
  "evaluatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "severity" INTEGER NOT NULL,
  "probability" INTEGER NOT NULL,
  "exposure" INTEGER NOT NULL DEFAULT 1,
  "grossScore" INTEGER NOT NULL,
  "grossLevel" TEXT NOT NULL,
  "residualSeverity" INTEGER,
  "residualProbability" INTEGER,
  "residualExposure" INTEGER,
  "residualScore" INTEGER,
  "residualLevel" TEXT,
  "note" TEXT,
  "evaluatedById" TEXT
);
ALTER TABLE "RiskEvaluation" ADD CONSTRAINT "RiskEvaluation_riskId_fkey" FOREIGN KEY ("riskId") REFERENCES "Risk"("id") ON DELETE CASCADE;
ALTER TABLE "RiskEvaluation" ADD CONSTRAINT "RiskEvaluation_evaluatedById_fkey" FOREIGN KEY ("evaluatedById") REFERENCES "User"("id") ON DELETE SET NULL;

-- Paramétrage (ligne unique) : méthode, seuils, périodicité
CREATE TABLE "RiskSettings" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "method" TEXT NOT NULL DEFAULT 'GP',
  "seuilModere" INTEGER NOT NULL DEFAULT 5,
  "seuilEleve" INTEGER NOT NULL DEFAULT 10,
  "seuilCritique" INTEGER NOT NULL DEFAULT 15,
  "seuilActionRequise" INTEGER NOT NULL DEFAULT 10,
  "reviewPeriodDays" INTEGER NOT NULL DEFAULT 365,
  "updatedAt" TIMESTAMP(3) NOT NULL
);

-- Le plan d'actions du Registre des risques réutilise le module Actions
-- déjà existant — un seul champ ajouté, aucune duplication (même principe
-- que pour l'Environnement, les Réclamations, les Fournisseurs...).
ALTER TABLE "Action" ADD COLUMN "riskId" TEXT;
ALTER TABLE "Action" ADD CONSTRAINT "Action_riskId_fkey" FOREIGN KEY ("riskId") REFERENCES "Risk"("id") ON DELETE SET NULL;
