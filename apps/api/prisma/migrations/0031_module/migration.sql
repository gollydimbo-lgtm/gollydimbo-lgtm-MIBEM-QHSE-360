-- Additif uniquement. Aucune colonne ni table existante n'est modifiée ou
-- supprimée, aucune donnée ne peut être perdue par cette migration.
-- Phase 1 du module Audits : types, référentiels, programme, dashboard KPI.

-- QhseAudit : enrichissement (IF NOT EXISTS par prudence, comme pour le
-- Registre des risques où createdAt/updatedAt existaient déjà en base).
ALTER TABLE "QhseAudit" ADD COLUMN IF NOT EXISTS "typeId" TEXT;
ALTER TABLE "QhseAudit" ADD COLUMN IF NOT EXISTS "referentialId" TEXT;
ALTER TABLE "QhseAudit" ADD COLUMN IF NOT EXISTS "workUnitId" TEXT;
ALTER TABLE "QhseAudit" ADD COLUMN IF NOT EXISTS "responsableAuditeId" TEXT;
ALTER TABLE "QhseAudit" ADD COLUMN IF NOT EXISTS "scope" TEXT;
ALTER TABLE "QhseAudit" ADD COLUMN IF NOT EXISTS "objectif" TEXT;
ALTER TABLE "QhseAudit" ADD COLUMN IF NOT EXISTS "auditTeamIds" JSONB;
ALTER TABLE "QhseAudit" ADD COLUMN IF NOT EXISTS "dureePrevueHeures" DOUBLE PRECISION;
ALTER TABLE "QhseAudit" ADD COLUMN IF NOT EXISTS "priorite" TEXT NOT NULL DEFAULT 'NORMALE';
ALTER TABLE "QhseAudit" ADD COLUMN IF NOT EXISTS "scoreMax" DOUBLE PRECISION;
ALTER TABLE "QhseAudit" ADD COLUMN IF NOT EXISTS "tauxConformite" DOUBLE PRECISION;
ALTER TABLE "QhseAudit" ADD CONSTRAINT "QhseAudit_responsableAuditeId_fkey" FOREIGN KEY ("responsableAuditeId") REFERENCES "User"("id") ON DELETE SET NULL;

-- AuditFinding : criticité configurable + lien direct vers une action +
-- date de clôture (pour le délai moyen de clôture des constats)
ALTER TABLE "AuditFinding" ADD COLUMN IF NOT EXISTS "criticite" TEXT;
ALTER TABLE "AuditFinding" ADD COLUMN IF NOT EXISTS "closedAt" TIMESTAMP(3);

-- Action : lien direct vers le constat d'origine (point 12)
ALTER TABLE "Action" ADD COLUMN IF NOT EXISTS "auditFindingId" TEXT;
ALTER TABLE "Action" ADD CONSTRAINT "Action_auditFindingId_fkey" FOREIGN KEY ("auditFindingId") REFERENCES "AuditFinding"("id") ON DELETE SET NULL;

-- Bibliothèque de types d'audit
CREATE TABLE "AuditType" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "code" TEXT NOT NULL,
  "label" TEXT NOT NULL,
  "order" INTEGER NOT NULL DEFAULT 0,
  "active" BOOLEAN NOT NULL DEFAULT true
);
CREATE UNIQUE INDEX "AuditType_code_key" ON "AuditType"("code");

-- Référentiels d'audit
CREATE TABLE "AuditReferential" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "code" TEXT NOT NULL,
  "label" TEXT NOT NULL,
  "description" TEXT,
  "active" BOOLEAN NOT NULL DEFAULT true
);
CREATE UNIQUE INDEX "AuditReferential_code_key" ON "AuditReferential"("code");

CREATE TABLE "AuditReferentialItem" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "referentialId" TEXT NOT NULL,
  "chapitre" TEXT,
  "article" TEXT,
  "exigence" TEXT NOT NULL,
  "order" INTEGER NOT NULL DEFAULT 0
);
ALTER TABLE "AuditReferentialItem" ADD CONSTRAINT "AuditReferentialItem_referentialId_fkey" FOREIGN KEY ("referentialId") REFERENCES "AuditReferential"("id") ON DELETE CASCADE;

ALTER TABLE "QhseAudit" ADD CONSTRAINT "QhseAudit_typeId_fkey" FOREIGN KEY ("typeId") REFERENCES "AuditType"("id") ON DELETE SET NULL;
ALTER TABLE "QhseAudit" ADD CONSTRAINT "QhseAudit_referentialId_fkey" FOREIGN KEY ("referentialId") REFERENCES "AuditReferential"("id") ON DELETE SET NULL;
ALTER TABLE "QhseAudit" ADD CONSTRAINT "QhseAudit_workUnitId_fkey" FOREIGN KEY ("workUnitId") REFERENCES "WorkUnit"("id") ON DELETE SET NULL;

-- Programme d'audit annuel/périodique
CREATE TABLE "AuditProgram" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "code" TEXT NOT NULL,
  "title" TEXT NOT NULL,
  "year" INTEGER NOT NULL,
  "periode" TEXT,
  "typeId" TEXT,
  "referentialId" TEXT,
  "workUnitId" TEXT,
  "processusId" TEXT,
  "auditeurPrincipalId" TEXT,
  "datePrevue" TIMESTAMP(3),
  "dureePrevueHeures" DOUBLE PRECISION,
  "priorite" TEXT NOT NULL DEFAULT 'NORMALE',
  "frequence" TEXT,
  "statut" TEXT NOT NULL DEFAULT 'PLANIFIE',
  "commentaires" TEXT,
  "auditId" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE UNIQUE INDEX "AuditProgram_code_key" ON "AuditProgram"("code");
ALTER TABLE "AuditProgram" ADD CONSTRAINT "AuditProgram_typeId_fkey" FOREIGN KEY ("typeId") REFERENCES "AuditType"("id") ON DELETE SET NULL;
ALTER TABLE "AuditProgram" ADD CONSTRAINT "AuditProgram_referentialId_fkey" FOREIGN KEY ("referentialId") REFERENCES "AuditReferential"("id") ON DELETE SET NULL;
ALTER TABLE "AuditProgram" ADD CONSTRAINT "AuditProgram_workUnitId_fkey" FOREIGN KEY ("workUnitId") REFERENCES "WorkUnit"("id") ON DELETE SET NULL;
ALTER TABLE "AuditProgram" ADD CONSTRAINT "AuditProgram_processusId_fkey" FOREIGN KEY ("processusId") REFERENCES "Processus"("id") ON DELETE SET NULL;
ALTER TABLE "AuditProgram" ADD CONSTRAINT "AuditProgram_auditeurPrincipalId_fkey" FOREIGN KEY ("auditeurPrincipalId") REFERENCES "User"("id") ON DELETE SET NULL;
ALTER TABLE "AuditProgram" ADD CONSTRAINT "AuditProgram_auditId_fkey" FOREIGN KEY ("auditId") REFERENCES "QhseAudit"("id") ON DELETE SET NULL;
