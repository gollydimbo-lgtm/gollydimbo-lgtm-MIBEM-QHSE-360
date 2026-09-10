-- Additif uniquement. Aucune colonne existante n'est modifiée ou
-- supprimée, aucune donnée ne peut être perdue par cette migration.

ALTER TABLE "ControlResult" ADD COLUMN "notApplicable" BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE "QualityControl" ADD COLUMN "conformityRate" DOUBLE PRECISION;
ALTER TABLE "QualityControl" ADD COLUMN "finalDecision" TEXT;
ALTER TABLE "QualityControl" ADD COLUMN "lotSize" INTEGER;
ALTER TABLE "QualityControl" ADD COLUMN "sampleSize" INTEGER;
ALTER TABLE "QualityControl" ADD COLUMN "samplingMethod" TEXT;
ALTER TABLE "QualityControl" ADD COLUMN "defectRate" DOUBLE PRECISION;
ALTER TABLE "QualityControl" ADD COLUMN "acceptanceThreshold" DOUBLE PRECISION;
ALTER TABLE "QualityControl" ADD COLUMN "rejectionThreshold" DOUBLE PRECISION;
