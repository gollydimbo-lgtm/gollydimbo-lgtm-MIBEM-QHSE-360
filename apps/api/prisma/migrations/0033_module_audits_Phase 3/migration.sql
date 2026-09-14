-- Additif uniquement. Aucune colonne ni table existante n'est modifiée ou
-- supprimée, aucune donnée ne peut être perdue par cette migration.
-- Phase 3 du module Audits : profils auditeurs, signatures électroniques.
-- Le calendrier et le rapport (points 17 et 31) réutilisent les données
-- déjà en base (dates des audits/programme, constats, actions) et ne
-- nécessitent aucune nouvelle table.

CREATE TABLE "AuditorProfile" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "userId" TEXT NOT NULL,
  "competence" TEXT,
  "domainesExpertise" JSONB,
  "formation" TEXT,
  "experienceAnnees" INTEGER,
  "disponible" BOOLEAN NOT NULL DEFAULT true,
  "habilitation" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE UNIQUE INDEX "AuditorProfile_userId_key" ON "AuditorProfile"("userId");
ALTER TABLE "AuditorProfile" ADD CONSTRAINT "AuditorProfile_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE;

CREATE TABLE "AuditSignature" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "auditId" TEXT NOT NULL,
  "role" TEXT NOT NULL,
  "signataireId" TEXT,
  "signedAt" TIMESTAMP(3),
  "statut" TEXT NOT NULL DEFAULT 'EN_ATTENTE'
);
ALTER TABLE "AuditSignature" ADD CONSTRAINT "AuditSignature_auditId_fkey" FOREIGN KEY ("auditId") REFERENCES "QhseAudit"("id") ON DELETE CASCADE;
ALTER TABLE "AuditSignature" ADD CONSTRAINT "AuditSignature_signataireId_fkey" FOREIGN KEY ("signataireId") REFERENCES "User"("id") ON DELETE SET NULL;
