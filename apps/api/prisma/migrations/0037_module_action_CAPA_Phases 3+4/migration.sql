-- Additif uniquement. Aucune colonne ni table existante n'est modifiée ou
-- supprimée, aucune donnée ne peut être perdue par cette migration.
-- Phases 3+4 du module Actions CAPA : efficacité obligatoire avant
-- clôture, prolongation, réouverture, alertes/escalade (score de
-- performance, tendances et rapport sont des endpoints calculés, sans
-- nouvelle table).

ALTER TABLE "Action" ADD COLUMN IF NOT EXISTS "effectivenessResult" TEXT;
ALTER TABLE "Action" ADD COLUMN IF NOT EXISTS "effectivenessCheckedAt" TIMESTAMP(3);
ALTER TABLE "Action" ADD COLUMN IF NOT EXISTS "effectivenessNotes" TEXT;
ALTER TABLE "Action" ADD COLUMN IF NOT EXISTS "reopenedCount" INTEGER NOT NULL DEFAULT 0;

CREATE TABLE "ActionExtension" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "actionId" TEXT NOT NULL,
  "ancienneEcheance" TIMESTAMP(3),
  "nouvelleEcheance" TIMESTAMP(3) NOT NULL,
  "motif" TEXT NOT NULL,
  "demandeurId" TEXT,
  "validateurId" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);
ALTER TABLE "ActionExtension" ADD CONSTRAINT "ActionExtension_actionId_fkey" FOREIGN KEY ("actionId") REFERENCES "Action"("id") ON DELETE CASCADE;
ALTER TABLE "ActionExtension" ADD CONSTRAINT "ActionExtension_demandeurId_fkey" FOREIGN KEY ("demandeurId") REFERENCES "User"("id") ON DELETE SET NULL;
ALTER TABLE "ActionExtension" ADD CONSTRAINT "ActionExtension_validateurId_fkey" FOREIGN KEY ("validateurId") REFERENCES "User"("id") ON DELETE SET NULL;
