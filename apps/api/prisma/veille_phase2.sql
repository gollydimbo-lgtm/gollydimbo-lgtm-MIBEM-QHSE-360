-- Veille réglementaire — Phase 2 : réévaluation des risques

CREATE TABLE "RegulatoryRiskReevaluationRequest" (
  "id" TEXT NOT NULL,
  "requirementId" TEXT NOT NULL,
  "riskId" TEXT NOT NULL,
  "raison" TEXT,
  "responsableId" TEXT,
  "dateLimite" TIMESTAMP(3),
  "statut" TEXT NOT NULL DEFAULT 'A_PLANIFIER',
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "RegulatoryRiskReevaluationRequest_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "RegulatoryRiskReevaluationRequest" ADD CONSTRAINT "RegulatoryRiskReevaluationRequest_requirementId_fkey" FOREIGN KEY ("requirementId") REFERENCES "RegulatoryRequirement"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "RegulatoryRiskReevaluationRequest" ADD CONSTRAINT "RegulatoryRiskReevaluationRequest_riskId_fkey" FOREIGN KEY ("riskId") REFERENCES "Risk"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "RegulatoryRiskReevaluationRequest" ADD CONSTRAINT "RegulatoryRiskReevaluationRequest_responsableId_fkey" FOREIGN KEY ("responsableId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
