-- Additif uniquement. Aucune colonne ni table existante n'est modifiée ou
-- supprimée, aucune donnée ne peut être perdue par cette migration.

ALTER TABLE "VeilleReglementaire" ADD COLUMN "responsableId" TEXT;
ALTER TABLE "VeilleReglementaire" ADD CONSTRAINT "VeilleReglementaire_responsableId_fkey" FOREIGN KEY ("responsableId") REFERENCES "User"("id") ON DELETE SET NULL;
