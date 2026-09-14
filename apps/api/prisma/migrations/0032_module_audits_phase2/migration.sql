-- Additif uniquement. Aucune colonne ni table existante n'est modifiée ou
-- supprimée, aucune donnée ne peut être perdue par cette migration.
-- Phase 2 du module Audits : check-lists dynamiques, moteur de notation,
-- constats enrichis (points 6, 7, 9 du cahier des charges).

-- QhseAudit : check-list appliquée + moteur de notation
ALTER TABLE "QhseAudit" ADD COLUMN IF NOT EXISTS "checklistId" TEXT;
ALTER TABLE "QhseAudit" ADD COLUMN IF NOT EXISTS "scoringMethod" TEXT NOT NULL DEFAULT 'CONFORME_NON_CONFORME';
ALTER TABLE "QhseAudit" ADD COLUMN IF NOT EXISTS "scoreObtenu" DOUBLE PRECISION;
ALTER TABLE "QhseAudit" ADD COLUMN IF NOT EXISTS "scorePondere" DOUBLE PRECISION;

-- AuditFinding : preuve objective, zone, responsable, délai, origine check-list
ALTER TABLE "AuditFinding" ADD COLUMN IF NOT EXISTS "checklistItemId" TEXT;
ALTER TABLE "AuditFinding" ADD COLUMN IF NOT EXISTS "preuveObjective" TEXT;
ALTER TABLE "AuditFinding" ADD COLUMN IF NOT EXISTS "zone" TEXT;
ALTER TABLE "AuditFinding" ADD COLUMN IF NOT EXISTS "responsableId" TEXT;
ALTER TABLE "AuditFinding" ADD COLUMN IF NOT EXISTS "delai" TIMESTAMP(3);
ALTER TABLE "AuditFinding" ADD CONSTRAINT "AuditFinding_responsableId_fkey" FOREIGN KEY ("responsableId") REFERENCES "User"("id") ON DELETE SET NULL;

-- Modèle de check-list réutilisable
CREATE TABLE "AuditChecklist" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "code" TEXT NOT NULL,
  "title" TEXT NOT NULL,
  "referentialId" TEXT,
  "typeId" TEXT,
  "active" BOOLEAN NOT NULL DEFAULT true,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE UNIQUE INDEX "AuditChecklist_code_key" ON "AuditChecklist"("code");
ALTER TABLE "AuditChecklist" ADD CONSTRAINT "AuditChecklist_referentialId_fkey" FOREIGN KEY ("referentialId") REFERENCES "AuditReferential"("id") ON DELETE SET NULL;
ALTER TABLE "AuditChecklist" ADD CONSTRAINT "AuditChecklist_typeId_fkey" FOREIGN KEY ("typeId") REFERENCES "AuditType"("id") ON DELETE SET NULL;

ALTER TABLE "QhseAudit" ADD CONSTRAINT "QhseAudit_checklistId_fkey" FOREIGN KEY ("checklistId") REFERENCES "AuditChecklist"("id") ON DELETE SET NULL;

CREATE TABLE "AuditChecklistItem" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "checklistId" TEXT NOT NULL,
  "chapitre" TEXT,
  "numero" TEXT,
  "question" TEXT NOT NULL,
  "critereAttendu" TEXT,
  "preuveRecherchee" TEXT,
  "criticite" TEXT NOT NULL DEFAULT 'FAIBLE',
  "poids" DOUBLE PRECISION NOT NULL DEFAULT 1,
  "referentialItemId" TEXT,
  "order" INTEGER NOT NULL DEFAULT 0
);
ALTER TABLE "AuditChecklistItem" ADD CONSTRAINT "AuditChecklistItem_checklistId_fkey" FOREIGN KEY ("checklistId") REFERENCES "AuditChecklist"("id") ON DELETE CASCADE;
ALTER TABLE "AuditChecklistItem" ADD CONSTRAINT "AuditChecklistItem_referentialItemId_fkey" FOREIGN KEY ("referentialItemId") REFERENCES "AuditReferentialItem"("id") ON DELETE SET NULL;

ALTER TABLE "AuditFinding" ADD CONSTRAINT "AuditFinding_checklistItemId_fkey" FOREIGN KEY ("checklistItemId") REFERENCES "AuditChecklistItem"("id") ON DELETE SET NULL;

-- Réponse à une question de check-list pour un audit donné
CREATE TABLE "AuditQuestionResponse" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "auditId" TEXT NOT NULL,
  "checklistItemId" TEXT NOT NULL,
  "resultat" TEXT NOT NULL DEFAULT 'NON_EVALUE',
  "score" DOUBLE PRECISION,
  "commentaire" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL
);
CREATE UNIQUE INDEX "AuditQuestionResponse_auditId_checklistItemId_key" ON "AuditQuestionResponse"("auditId","checklistItemId");
ALTER TABLE "AuditQuestionResponse" ADD CONSTRAINT "AuditQuestionResponse_auditId_fkey" FOREIGN KEY ("auditId") REFERENCES "QhseAudit"("id") ON DELETE CASCADE;
ALTER TABLE "AuditQuestionResponse" ADD CONSTRAINT "AuditQuestionResponse_checklistItemId_fkey" FOREIGN KEY ("checklistItemId") REFERENCES "AuditChecklistItem"("id") ON DELETE CASCADE;
