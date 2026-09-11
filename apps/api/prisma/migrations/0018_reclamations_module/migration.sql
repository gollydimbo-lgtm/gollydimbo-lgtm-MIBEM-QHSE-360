-- Additif uniquement. Aucune colonne existante n'est modifiée ou
-- supprimée, aucune donnée ne peut être perdue par cette migration.

ALTER TABLE "Reclamation" ADD COLUMN "typeClient" TEXT;
ALTER TABLE "Reclamation" ADD COLUMN "clientContact" TEXT;
ALTER TABLE "Reclamation" ADD COLUMN "canal" TEXT;
ALTER TABLE "Reclamation" ADD COLUMN "dateEvenement" TIMESTAMP(3);
ALTER TABLE "Reclamation" ADD COLUMN "produitService" TEXT;
ALTER TABLE "Reclamation" ADD COLUMN "reference" TEXT;
ALTER TABLE "Reclamation" ADD COLUMN "lotNumber" TEXT;
ALTER TABLE "Reclamation" ADD COLUMN "commandeNumber" TEXT;
ALTER TABLE "Reclamation" ADD COLUMN "factureNumber" TEXT;
ALTER TABLE "Reclamation" ADD COLUMN "quantiteConcernee" DOUBLE PRECISION;
ALTER TABLE "Reclamation" ADD COLUMN "siteId" TEXT;
ALTER TABLE "Reclamation" ADD COLUMN "processusId" TEXT;
ALTER TABLE "Reclamation" ADD COLUMN "fournisseurId" TEXT;
ALTER TABLE "Reclamation" ADD COLUMN "categorieProbleme" TEXT;
ALTER TABLE "Reclamation" ADD COLUMN "scoreCriticite" INTEGER;
ALTER TABLE "Reclamation" ADD COLUMN "dateAccuseReception" TIMESTAMP(3);
ALTER TABLE "Reclamation" ADD COLUMN "datePremiereReponse" TIMESTAMP(3);
ALTER TABLE "Reclamation" ADD COLUMN "dateResolutionPrevue" TIMESTAMP(3);
ALTER TABLE "Reclamation" ADD COLUMN "dateResolutionReelle" TIMESTAMP(3);
ALTER TABLE "Reclamation" ADD COLUMN "dateCloture" TIMESTAMP(3);
ALTER TABLE "Reclamation" ADD COLUMN "delaiCibleJours" INTEGER;
ALTER TABLE "Reclamation" ADD COLUMN "actionCurative" TEXT;
ALTER TABLE "Reclamation" ADD COLUMN "actionCurativeResponsableId" TEXT;
ALTER TABLE "Reclamation" ADD COLUMN "actionCurativeDate" TIMESTAMP(3);
ALTER TABLE "Reclamation" ADD COLUMN "actionCurativeCout" DOUBLE PRECISION;
ALTER TABLE "Reclamation" ADD COLUMN "methodeAnalyse" TEXT;
ALTER TABLE "Reclamation" ADD COLUMN "pourquoi1" TEXT;
ALTER TABLE "Reclamation" ADD COLUMN "pourquoi2" TEXT;
ALTER TABLE "Reclamation" ADD COLUMN "pourquoi3" TEXT;
ALTER TABLE "Reclamation" ADD COLUMN "pourquoi4" TEXT;
ALTER TABLE "Reclamation" ADD COLUMN "pourquoi5" TEXT;
ALTER TABLE "Reclamation" ADD COLUMN "categorieCauseIshikawa" TEXT;
ALTER TABLE "Reclamation" ADD COLUMN "causeRacine" TEXT;
ALTER TABLE "Reclamation" ADD COLUMN "efficacite" TEXT;
ALTER TABLE "Reclamation" ADD COLUMN "satisfaction" TEXT;
ALTER TABLE "Reclamation" ADD COLUMN "noteSatisfaction" DOUBLE PRECISION;
ALTER TABLE "Reclamation" ADD COLUMN "commentaireClient" TEXT;
ALTER TABLE "Reclamation" ADD COLUMN "coutRemboursement" DOUBLE PRECISION;
ALTER TABLE "Reclamation" ADD COLUMN "coutRemplacement" DOUBLE PRECISION;
ALTER TABLE "Reclamation" ADD COLUMN "coutTransport" DOUBLE PRECISION;
ALTER TABLE "Reclamation" ADD COLUMN "coutMainOeuvre" DOUBLE PRECISION;
ALTER TABLE "Reclamation" ADD COLUMN "coutAutres" DOUBLE PRECISION;
ALTER TABLE "Reclamation" ADD COLUMN "recurrente" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "Reclamation" ADD COLUMN "nonConformityId" TEXT;

ALTER TABLE "Reclamation" ADD CONSTRAINT "Reclamation_siteId_fkey" FOREIGN KEY ("siteId") REFERENCES "Site"("id") ON DELETE SET NULL;
ALTER TABLE "Reclamation" ADD CONSTRAINT "Reclamation_processusId_fkey" FOREIGN KEY ("processusId") REFERENCES "Processus"("id") ON DELETE SET NULL;
ALTER TABLE "Reclamation" ADD CONSTRAINT "Reclamation_fournisseurId_fkey" FOREIGN KEY ("fournisseurId") REFERENCES "Fournisseur"("id") ON DELETE SET NULL;
ALTER TABLE "Reclamation" ADD CONSTRAINT "Reclamation_nonConformityId_fkey" FOREIGN KEY ("nonConformityId") REFERENCES "NonConformity"("id") ON DELETE SET NULL;
ALTER TABLE "Reclamation" ADD CONSTRAINT "Reclamation_actionCurativeResponsableId_fkey" FOREIGN KEY ("actionCurativeResponsableId") REFERENCES "User"("id") ON DELETE SET NULL;

-- Le plan d'actions correctives des réclamations réutilise le module
-- Actions déjà existant — un seul champ ajouté, aucune duplication.
ALTER TABLE "Action" ADD COLUMN "reclamationId" TEXT;
ALTER TABLE "Action" ADD CONSTRAINT "Action_reclamationId_fkey" FOREIGN KEY ("reclamationId") REFERENCES "Reclamation"("id") ON DELETE SET NULL;
