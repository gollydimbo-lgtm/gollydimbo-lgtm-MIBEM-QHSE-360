-- Additif uniquement. Aucune colonne ni table existante n'est modifiée ou
-- supprimée, aucune donnée ne peut être perdue par cette migration.
-- Phases 1+2 du module Actions CAPA : type curative/corrective/préventive/
-- amélioration, sous-actions, dates, avancement, analyse des causes.

ALTER TABLE "Action" ADD COLUMN IF NOT EXISTS "actionType" TEXT;
ALTER TABLE "Action" ADD COLUMN IF NOT EXISTS "criticite" TEXT;
ALTER TABLE "Action" ADD COLUMN IF NOT EXISTS "source" TEXT;
ALTER TABLE "Action" ADD COLUMN IF NOT EXISTS "workUnitId" TEXT;
ALTER TABLE "Action" ADD COLUMN IF NOT EXISTS "parentActionId" TEXT;
ALTER TABLE "Action" ADD COLUMN IF NOT EXISTS "avancement" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "Action" ADD COLUMN IF NOT EXISTS "dateDebutPrevue" TIMESTAMP(3);
ALTER TABLE "Action" ADD COLUMN IF NOT EXISTS "dateDebutReelle" TIMESTAMP(3);
ALTER TABLE "Action" ADD COLUMN IF NOT EXISTS "dateValidation" TIMESTAMP(3);
ALTER TABLE "Action" ADD COLUMN IF NOT EXISTS "dateCloture" TIMESTAMP(3);
ALTER TABLE "Action" ADD CONSTRAINT "Action_workUnitId_fkey" FOREIGN KEY ("workUnitId") REFERENCES "WorkUnit"("id") ON DELETE SET NULL;
ALTER TABLE "Action" ADD CONSTRAINT "Action_parentActionId_fkey" FOREIGN KEY ("parentActionId") REFERENCES "Action"("id") ON DELETE SET NULL;

CREATE TABLE "ActionCause" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "actionId" TEXT NOT NULL,
  "methode" TEXT NOT NULL,
  "niveau" TEXT,
  "categorie" TEXT,
  "description" TEXT NOT NULL,
  "type" TEXT,
  "estRacine" BOOLEAN NOT NULL DEFAULT false,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);
ALTER TABLE "ActionCause" ADD CONSTRAINT "ActionCause_actionId_fkey" FOREIGN KEY ("actionId") REFERENCES "Action"("id") ON DELETE CASCADE;
