-- Additif uniquement. Aucune colonne ni table existante n'est modifiée ou
-- supprimée, aucune donnée ne peut être perdue par cette migration.
-- Point 16 du cahier des charges du Registre des risques : liens vers EPI,
-- Formations, Audits et Environnement.

ALTER TABLE "EnvironnementAspect" ADD COLUMN IF NOT EXISTS "riskId" TEXT;
ALTER TABLE "EnvironnementAspect" ADD CONSTRAINT "EnvironnementAspect_riskId_fkey" FOREIGN KEY ("riskId") REFERENCES "Risk"("id") ON DELETE SET NULL;

ALTER TABLE "AuditFinding" ADD COLUMN IF NOT EXISTS "riskId" TEXT;
ALTER TABLE "AuditFinding" ADD CONSTRAINT "AuditFinding_riskId_fkey" FOREIGN KEY ("riskId") REFERENCES "Risk"("id") ON DELETE SET NULL;

-- Un EPI ou une formation peuvent être une mesure de prévention réelle
-- (pas seulement du texte libre) rattachée à un risque.
ALTER TABLE "RiskMeasure" ADD COLUMN IF NOT EXISTS "epiId" TEXT;
ALTER TABLE "RiskMeasure" ADD COLUMN IF NOT EXISTS "trainingId" TEXT;
ALTER TABLE "RiskMeasure" ADD CONSTRAINT "RiskMeasure_epiId_fkey" FOREIGN KEY ("epiId") REFERENCES "Epi"("id") ON DELETE SET NULL;
ALTER TABLE "RiskMeasure" ADD CONSTRAINT "RiskMeasure_trainingId_fkey" FOREIGN KEY ("trainingId") REFERENCES "Training"("id") ON DELETE SET NULL;
