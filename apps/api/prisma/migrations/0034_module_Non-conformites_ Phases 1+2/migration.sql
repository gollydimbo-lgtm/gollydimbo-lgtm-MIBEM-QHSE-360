-- Additif uniquement. Aucune colonne ni table existante n'est modifiée ou
-- supprimée, aucune donnée ne peut être perdue par cette migration.
-- Phases 1+2 du module Non-conformités : criticité, confinement, étendue,
-- analyse des causes, vérification d'efficacité.

ALTER TABLE "NonConformity" ADD COLUMN IF NOT EXISTS "workUnitId" TEXT;
ALTER TABLE "NonConformity" ADD COLUMN IF NOT EXISTS "declarantId" TEXT;
ALTER TABLE "NonConformity" ADD COLUMN IF NOT EXISTS "responsibleId" TEXT;
ALTER TABLE "NonConformity" ADD COLUMN IF NOT EXISTS "gravite" INTEGER;
ALTER TABLE "NonConformity" ADD COLUMN IF NOT EXISTS "probabilite" INTEGER;
ALTER TABLE "NonConformity" ADD COLUMN IF NOT EXISTS "etendue" INTEGER;
ALTER TABLE "NonConformity" ADD COLUMN IF NOT EXISTS "criticiteScore" INTEGER;
ALTER TABLE "NonConformity" ADD COLUMN IF NOT EXISTS "criticiteNiveau" TEXT;
ALTER TABLE "NonConformity" ADD COLUMN IF NOT EXISTS "quantiteNc" DOUBLE PRECISION;
ALTER TABLE "NonConformity" ADD COLUMN IF NOT EXISTS "quantiteControlee" DOUBLE PRECISION;
ALTER TABLE "NonConformity" ADD COLUMN IF NOT EXISTS "quantiteBloquee" DOUBLE PRECISION;
ALTER TABLE "NonConformity" ADD COLUMN IF NOT EXISTS "quantiteLiberee" DOUBLE PRECISION;
ALTER TABLE "NonConformity" ADD COLUMN IF NOT EXISTS "quantiteDetruite" DOUBLE PRECISION;
ALTER TABLE "NonConformity" ADD COLUMN IF NOT EXISTS "quantiteReparee" DOUBLE PRECISION;
ALTER TABLE "NonConformity" ADD COLUMN IF NOT EXISTS "tauxNc" DOUBLE PRECISION;
ALTER TABLE "NonConformity" ADD COLUMN IF NOT EXISTS "dueDate" TIMESTAMP(3);
ALTER TABLE "NonConformity" ADD COLUMN IF NOT EXISTS "closedAt" TIMESTAMP(3);
ALTER TABLE "NonConformity" ADD COLUMN IF NOT EXISTS "reopenedCount" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "NonConformity" ADD COLUMN IF NOT EXISTS "causeRacineIdentifiee" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "NonConformity" ADD COLUMN IF NOT EXISTS "effectivenessResult" TEXT;
ALTER TABLE "NonConformity" ADD COLUMN IF NOT EXISTS "effectivenessCheckedAt" TIMESTAMP(3);
ALTER TABLE "NonConformity" ADD COLUMN IF NOT EXISTS "effectivenessNotes" TEXT;
ALTER TABLE "NonConformity" ADD CONSTRAINT "NonConformity_workUnitId_fkey" FOREIGN KEY ("workUnitId") REFERENCES "WorkUnit"("id") ON DELETE SET NULL;
ALTER TABLE "NonConformity" ADD CONSTRAINT "NonConformity_declarantId_fkey" FOREIGN KEY ("declarantId") REFERENCES "User"("id") ON DELETE SET NULL;
ALTER TABLE "NonConformity" ADD CONSTRAINT "NonConformity_responsibleId_fkey" FOREIGN KEY ("responsibleId") REFERENCES "User"("id") ON DELETE SET NULL;

CREATE TABLE "NcContainmentAction" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "nonConformityId" TEXT NOT NULL,
  "type" TEXT NOT NULL,
  "description" TEXT,
  "responsableId" TEXT,
  "date" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "echeance" TIMESTAMP(3),
  "resultat" TEXT,
  "cout" DOUBLE PRECISION,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);
ALTER TABLE "NcContainmentAction" ADD CONSTRAINT "NcContainmentAction_nonConformityId_fkey" FOREIGN KEY ("nonConformityId") REFERENCES "NonConformity"("id") ON DELETE CASCADE;
ALTER TABLE "NcContainmentAction" ADD CONSTRAINT "NcContainmentAction_responsableId_fkey" FOREIGN KEY ("responsableId") REFERENCES "User"("id") ON DELETE SET NULL;

CREATE TABLE "NcCause" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "nonConformityId" TEXT NOT NULL,
  "methode" TEXT NOT NULL,
  "niveau" TEXT,
  "categorie" TEXT,
  "description" TEXT NOT NULL,
  "type" TEXT,
  "estRacine" BOOLEAN NOT NULL DEFAULT false,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);
ALTER TABLE "NcCause" ADD CONSTRAINT "NcCause_nonConformityId_fkey" FOREIGN KEY ("nonConformityId") REFERENCES "NonConformity"("id") ON DELETE CASCADE;

CREATE TABLE "NcSettings" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "seuilModeree" INTEGER NOT NULL DEFAULT 20,
  "seuilMajeure" INTEGER NOT NULL DEFAULT 50,
  "seuilCritique" INTEGER NOT NULL DEFAULT 75,
  "delaiStandardJours" INTEGER NOT NULL DEFAULT 30,
  "updatedAt" TIMESTAMP(3) NOT NULL
);
