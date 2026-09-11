-- Additif uniquement. Aucune colonne ni table existante n'est modifiée ou
-- supprimée, aucune donnée ne peut être perdue par cette migration.

CREATE TABLE "IndicateurPonderation" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "autoKey" TEXT NOT NULL,
  "poids" DOUBLE PRECISION NOT NULL DEFAULT 1,
  "updatedAt" TIMESTAMP(3) NOT NULL
);
CREATE UNIQUE INDEX "IndicateurPonderation_autoKey_key" ON "IndicateurPonderation"("autoKey");
