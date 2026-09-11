-- Additif uniquement. Aucune colonne ni table existante n'est modifiée ou
-- supprimée, aucune donnée ne peut être perdue par cette migration.

ALTER TABLE "IndicateurQualite" ADD COLUMN "categorie" TEXT;
ALTER TABLE "IndicateurQualite" ADD COLUMN "formule" TEXT;
ALTER TABLE "IndicateurQualite" ADD COLUMN "frequence" TEXT;
ALTER TABLE "IndicateurQualite" ADD COLUMN "processusId" TEXT;
ALTER TABLE "IndicateurQualite" ADD COLUMN "seuilVert" DOUBLE PRECISION;
ALTER TABLE "IndicateurQualite" ADD COLUMN "seuilOrange" DOUBLE PRECISION;
ALTER TABLE "IndicateurQualite" ADD COLUMN "source" TEXT NOT NULL DEFAULT 'MANUEL';
ALTER TABLE "IndicateurQualite" ADD COLUMN "autoKey" TEXT;
ALTER TABLE "IndicateurQualite" ADD CONSTRAINT "IndicateurQualite_processusId_fkey" FOREIGN KEY ("processusId") REFERENCES "Processus"("id") ON DELETE SET NULL;

CREATE TABLE "IndicateurMesure" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "indicateurId" TEXT NOT NULL,
  "valeur" DOUBLE PRECISION NOT NULL,
  "periode" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "commentaire" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);
ALTER TABLE "IndicateurMesure" ADD CONSTRAINT "IndicateurMesure_indicateurId_fkey" FOREIGN KEY ("indicateurId") REFERENCES "IndicateurQualite"("id") ON DELETE CASCADE;
