-- Additif uniquement. Aucune colonne ni table existante n'est modifiée ou
-- supprimée, aucune donnée ne peut être perdue par cette migration.

ALTER TABLE "ObjectifQhse" ADD COLUMN "valeurInitiale" DOUBLE PRECISION;
ALTER TABLE "ObjectifQhse" ADD COLUMN "sensInverse" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "ObjectifQhse" ADD COLUMN "responsableId" TEXT;
ALTER TABLE "ObjectifQhse" ADD COLUMN "budget" DOUBLE PRECISION;
ALTER TABLE "ObjectifQhse" ADD CONSTRAINT "ObjectifQhse_responsableId_fkey" FOREIGN KEY ("responsableId") REFERENCES "User"("id") ON DELETE SET NULL;
