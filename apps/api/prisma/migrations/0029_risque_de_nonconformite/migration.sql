-- Additif uniquement. Aucune colonne ni table existante n'est modifiée ou
-- supprimée, aucune donnée ne peut être perdue par cette migration.
-- Point 16 du cahier des charges du Registre des risques : une
-- non-conformité peut être reliée à un risque existant, ou en générer un.
ALTER TABLE "NonConformity" ADD COLUMN IF NOT EXISTS "riskId" TEXT;
ALTER TABLE "NonConformity" ADD CONSTRAINT "NonConformity_riskId_fkey" FOREIGN KEY ("riskId") REFERENCES "Risk"("id") ON DELETE SET NULL;
