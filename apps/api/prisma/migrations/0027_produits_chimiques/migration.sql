-- Additif uniquement. Aucune colonne ni table existante n'est modifiée ou
-- supprimée, aucune donnée ne peut être perdue par cette migration.

CREATE TABLE "ProduitChimique" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "code" TEXT NOT NULL,
  "nom" TEXT NOT NULL,
  "reference" TEXT,
  "fournisseurId" TEXT,
  "quantiteStockee" DOUBLE PRECISION,
  "quantiteConsommee" DOUBLE PRECISION,
  "unite" TEXT,
  "classification" TEXT,
  "dangerEnvironnemental" TEXT,
  "zoneStockage" TEXT,
  "retention" BOOLEAN NOT NULL DEFAULT false,
  "fdsDisponible" BOOLEAN NOT NULL DEFAULT false,
  "dateControle" TIMESTAMP(3),
  "dateExpiration" TIMESTAMP(3),
  "seuilAlerteStock" DOUBLE PRECISION,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL
);
CREATE UNIQUE INDEX "ProduitChimique_code_key" ON "ProduitChimique"("code");
ALTER TABLE "ProduitChimique" ADD CONSTRAINT "ProduitChimique_fournisseurId_fkey" FOREIGN KEY ("fournisseurId") REFERENCES "Fournisseur"("id") ON DELETE SET NULL;
