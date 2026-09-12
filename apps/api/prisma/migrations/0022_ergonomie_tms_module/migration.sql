-- Additif uniquement. Aucune colonne ni table existante n'est modifiée ou
-- supprimée, aucune donnée ne peut être perdue par cette migration.

CREATE TABLE "AnalyseErgonomique" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "code" TEXT NOT NULL,
  "poste" TEXT NOT NULL,
  "zone" TEXT,
  "siteId" TEXT,
  "processusId" TEXT,
  "stationDeboutProlongee" BOOLEAN NOT NULL DEFAULT false,
  "stationAssiseProlongee" BOOLEAN NOT NULL DEFAULT false,
  "travailRepetitif" BOOLEAN NOT NULL DEFAULT false,
  "manutentionChargesLourdes" BOOLEAN NOT NULL DEFAULT false,
  "posturesContraignantes" BOOLEAN NOT NULL DEFAULT false,
  "ecranInformatiquePosture" BOOLEAN NOT NULL DEFAULT false,
  "vibrations" BOOLEAN NOT NULL DEFAULT false,
  "eclairageInsuffisant" BOOLEAN NOT NULL DEFAULT false,
  "espaceInsuffisant" BOOLEAN NOT NULL DEFAULT false,
  "observations" TEXT,
  "scoreErgonomique" TEXT NOT NULL DEFAULT 'FAIBLE',
  "actionsProposees" TEXT,
  "dateEvaluation" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "evaluateurId" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL
);
CREATE UNIQUE INDEX "AnalyseErgonomique_code_key" ON "AnalyseErgonomique"("code");
ALTER TABLE "AnalyseErgonomique" ADD CONSTRAINT "AnalyseErgonomique_siteId_fkey" FOREIGN KEY ("siteId") REFERENCES "Site"("id") ON DELETE SET NULL;
ALTER TABLE "AnalyseErgonomique" ADD CONSTRAINT "AnalyseErgonomique_processusId_fkey" FOREIGN KEY ("processusId") REFERENCES "Processus"("id") ON DELETE SET NULL;
ALTER TABLE "AnalyseErgonomique" ADD CONSTRAINT "AnalyseErgonomique_evaluateurId_fkey" FOREIGN KEY ("evaluateurId") REFERENCES "User"("id") ON DELETE SET NULL;

CREATE TABLE "TmsSignalement" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "code" TEXT NOT NULL,
  "employeeId" TEXT,
  "poste" TEXT,
  "zoneCorporelle" TEXT NOT NULL,
  "activite" TEXT,
  "frequence" TEXT,
  "dateSignalement" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "analyseErgonomiqueId" TEXT,
  "statut" TEXT NOT NULL DEFAULT 'SIGNALE',
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL
);
CREATE UNIQUE INDEX "TmsSignalement_code_key" ON "TmsSignalement"("code");
ALTER TABLE "TmsSignalement" ADD CONSTRAINT "TmsSignalement_employeeId_fkey" FOREIGN KEY ("employeeId") REFERENCES "Employee"("id") ON DELETE SET NULL;
ALTER TABLE "TmsSignalement" ADD CONSTRAINT "TmsSignalement_analyseErgonomiqueId_fkey" FOREIGN KEY ("analyseErgonomiqueId") REFERENCES "AnalyseErgonomique"("id") ON DELETE SET NULL;

-- Le plan d'actions ergonomiques réutilise le module Actions déjà
-- existant — un seul champ ajouté, aucune duplication.
ALTER TABLE "Action" ADD COLUMN "ergonomieId" TEXT;
ALTER TABLE "Action" ADD CONSTRAINT "Action_ergonomieId_fkey" FOREIGN KEY ("ergonomieId") REFERENCES "AnalyseErgonomique"("id") ON DELETE SET NULL;
