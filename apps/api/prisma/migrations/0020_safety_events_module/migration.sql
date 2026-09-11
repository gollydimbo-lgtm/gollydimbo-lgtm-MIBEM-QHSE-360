-- Additif uniquement. Aucune colonne ni table existante n'est modifiée ou
-- supprimée, aucune donnée ne peut être perdue par cette migration.

ALTER TABLE "SafetyEvent" ADD COLUMN "categorie" TEXT;
ALTER TABLE "SafetyEvent" ADD COLUMN "siteId" TEXT;
ALTER TABLE "SafetyEvent" ADD COLUMN "zone" TEXT;
ALTER TABLE "SafetyEvent" ADD COLUMN "atelier" TEXT;
ALTER TABLE "SafetyEvent" ADD COLUMN "poste" TEXT;
ALTER TABLE "SafetyEvent" ADD COLUMN "activite" TEXT;
ALTER TABLE "SafetyEvent" ADD COLUMN "employeeId" TEXT;
ALTER TABLE "SafetyEvent" ADD COLUMN "personneNom" TEXT;
ALTER TABLE "SafetyEvent" ADD COLUMN "personneFonction" TEXT;
ALTER TABLE "SafetyEvent" ADD COLUMN "typePersonnel" TEXT;
ALTER TABLE "SafetyEvent" ADD COLUMN "typeLesion" TEXT;
ALTER TABLE "SafetyEvent" ADD COLUMN "siegeLesion" TEXT;
ALTER TABLE "SafetyEvent" ADD COLUMN "consequenceMaterielle" TEXT;
ALTER TABLE "SafetyEvent" ADD COLUMN "consequenceEnvironnementale" TEXT;
ALTER TABLE "SafetyEvent" ADD COLUMN "mecanisme" TEXT;
ALTER TABLE "SafetyEvent" ADD COLUMN "potentielGravite" TEXT;
ALTER TABLE "SafetyEvent" ADD COLUMN "enqueteurId" TEXT;
ALTER TABLE "SafetyEvent" ADD COLUMN "dateEnquete" TIMESTAMP(3);
ALTER TABLE "SafetyEvent" ADD COLUMN "methodeAnalyse" TEXT;
ALTER TABLE "SafetyEvent" ADD COLUMN "causeHumaine" TEXT;
ALTER TABLE "SafetyEvent" ADD COLUMN "causeMethode" TEXT;
ALTER TABLE "SafetyEvent" ADD COLUMN "causeMachine" TEXT;
ALTER TABLE "SafetyEvent" ADD COLUMN "causeMatiere" TEXT;
ALTER TABLE "SafetyEvent" ADD COLUMN "causeMilieu" TEXT;
ALTER TABLE "SafetyEvent" ADD COLUMN "causeManagement" TEXT;
ALTER TABLE "SafetyEvent" ADD COLUMN "causeRacine" TEXT;
ALTER TABLE "SafetyEvent" ADD COLUMN "statut" TEXT NOT NULL DEFAULT 'DECLARE';
ALTER TABLE "SafetyEvent" ADD COLUMN "dateCloture" TIMESTAMP(3);
ALTER TABLE "SafetyEvent" ADD COLUMN "riskId" TEXT;
ALTER TABLE "SafetyEvent" ADD COLUMN "epiId" TEXT;
ALTER TABLE "SafetyEvent" ADD COLUMN "epcId" TEXT;
ALTER TABLE "SafetyEvent" ADD COLUMN "processusId" TEXT;
ALTER TABLE "SafetyEvent" ADD COLUMN "fournisseurId" TEXT;
ALTER TABLE "SafetyEvent" ADD COLUMN "nonConformityId" TEXT;
ALTER TABLE "SafetyEvent" ADD COLUMN "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE "SafetyEvent" ADD CONSTRAINT "SafetyEvent_siteId_fkey" FOREIGN KEY ("siteId") REFERENCES "Site"("id") ON DELETE SET NULL;
ALTER TABLE "SafetyEvent" ADD CONSTRAINT "SafetyEvent_employeeId_fkey" FOREIGN KEY ("employeeId") REFERENCES "Employee"("id") ON DELETE SET NULL;
ALTER TABLE "SafetyEvent" ADD CONSTRAINT "SafetyEvent_enqueteurId_fkey" FOREIGN KEY ("enqueteurId") REFERENCES "User"("id") ON DELETE SET NULL;
ALTER TABLE "SafetyEvent" ADD CONSTRAINT "SafetyEvent_riskId_fkey" FOREIGN KEY ("riskId") REFERENCES "Risk"("id") ON DELETE SET NULL;
ALTER TABLE "SafetyEvent" ADD CONSTRAINT "SafetyEvent_epiId_fkey" FOREIGN KEY ("epiId") REFERENCES "Epi"("id") ON DELETE SET NULL;
ALTER TABLE "SafetyEvent" ADD CONSTRAINT "SafetyEvent_epcId_fkey" FOREIGN KEY ("epcId") REFERENCES "Epc"("id") ON DELETE SET NULL;
ALTER TABLE "SafetyEvent" ADD CONSTRAINT "SafetyEvent_processusId_fkey" FOREIGN KEY ("processusId") REFERENCES "Processus"("id") ON DELETE SET NULL;
ALTER TABLE "SafetyEvent" ADD CONSTRAINT "SafetyEvent_fournisseurId_fkey" FOREIGN KEY ("fournisseurId") REFERENCES "Fournisseur"("id") ON DELETE SET NULL;
ALTER TABLE "SafetyEvent" ADD CONSTRAINT "SafetyEvent_nonConformityId_fkey" FOREIGN KEY ("nonConformityId") REFERENCES "NonConformity"("id") ON DELETE SET NULL;

-- Le plan d'actions réutilise le module Actions déjà existant — un
-- seul champ ajouté, aucune duplication.
ALTER TABLE "Action" ADD COLUMN "safetyEventId" TEXT;
ALTER TABLE "Action" ADD CONSTRAINT "Action_safetyEventId_fkey" FOREIGN KEY ("safetyEventId") REFERENCES "SafetyEvent"("id") ON DELETE SET NULL;
