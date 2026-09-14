-- Additif uniquement. Aucune colonne ni table existante n'est modifiée ou
-- supprimée, aucune donnée ne peut être perdue par cette migration.
-- Phases 3+4 du module Non-conformités : coût de non-qualité (récurrence,
-- alertes, rapports et tendances sont des endpoints calculés, sans nouvelle
-- table).

CREATE TABLE "NcCost" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "nonConformityId" TEXT NOT NULL,
  "type" TEXT NOT NULL,
  "montant" DOUBLE PRECISION NOT NULL,
  "description" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);
ALTER TABLE "NcCost" ADD CONSTRAINT "NcCost_nonConformityId_fkey" FOREIGN KEY ("nonConformityId") REFERENCES "NonConformity"("id") ON DELETE CASCADE;
