-- Additif uniquement. Aucune colonne existante n'est modifiée ou
-- supprimée, aucune donnée ne peut être perdue par cette migration.

-- Extension des types de réponse de checklist
ALTER TYPE "ControlValueType" ADD VALUE IF NOT EXISTS 'DATE';
ALTER TYPE "ControlValueType" ADD VALUE IF NOT EXISTS 'TIME';
ALTER TYPE "ControlValueType" ADD VALUE IF NOT EXISTS 'PERCENTAGE';
ALTER TYPE "ControlValueType" ADD VALUE IF NOT EXISTS 'SIGNATURE';
ALTER TYPE "ControlValueType" ADD VALUE IF NOT EXISTS 'RATING';

-- Catalogue des types de contrôle, géré par l'administrateur
CREATE TABLE "ControlType" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "code" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "domain" TEXT NOT NULL DEFAULT 'QUALITE',
  "description" TEXT,
  "active" BOOLEAN NOT NULL DEFAULT true,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE UNIQUE INDEX "ControlType_code_key" ON "ControlType"("code");

-- Un modèle de contrôle appartient désormais (optionnellement) à un type,
-- et porte lui aussi un domaine.
ALTER TABLE "ControlTemplate" ADD COLUMN "domain" TEXT NOT NULL DEFAULT 'QUALITE';
ALTER TABLE "ControlTemplate" ADD COLUMN "typeId" TEXT;
ALTER TABLE "ControlTemplate" ADD CONSTRAINT "ControlTemplate_typeId_fkey" FOREIGN KEY ("typeId") REFERENCES "ControlType"("id") ON DELETE SET NULL;

-- Domaine et liens universels sur le contrôle lui-même
ALTER TABLE "QualityControl" ADD COLUMN "domain" TEXT NOT NULL DEFAULT 'QUALITE';
ALTER TABLE "QualityControl" ADD COLUMN "typeId" TEXT;
ALTER TABLE "QualityControl" ADD COLUMN "epiId" TEXT;
ALTER TABLE "QualityControl" ADD COLUMN "epcId" TEXT;
ALTER TABLE "QualityControl" ADD COLUMN "riskId" TEXT;
ALTER TABLE "QualityControl" ADD COLUMN "fournisseurId" TEXT;
ALTER TABLE "QualityControl" ADD COLUMN "employeeId" TEXT;
ALTER TABLE "QualityControl" ADD CONSTRAINT "QualityControl_typeId_fkey" FOREIGN KEY ("typeId") REFERENCES "ControlType"("id") ON DELETE SET NULL;
ALTER TABLE "QualityControl" ADD CONSTRAINT "QualityControl_epiId_fkey" FOREIGN KEY ("epiId") REFERENCES "Epi"("id") ON DELETE SET NULL;
ALTER TABLE "QualityControl" ADD CONSTRAINT "QualityControl_epcId_fkey" FOREIGN KEY ("epcId") REFERENCES "Epc"("id") ON DELETE SET NULL;
ALTER TABLE "QualityControl" ADD CONSTRAINT "QualityControl_riskId_fkey" FOREIGN KEY ("riskId") REFERENCES "Risk"("id") ON DELETE SET NULL;
ALTER TABLE "QualityControl" ADD CONSTRAINT "QualityControl_fournisseurId_fkey" FOREIGN KEY ("fournisseurId") REFERENCES "Fournisseur"("id") ON DELETE SET NULL;
ALTER TABLE "QualityControl" ADD CONSTRAINT "QualityControl_employeeId_fkey" FOREIGN KEY ("employeeId") REFERENCES "Employee"("id") ON DELETE SET NULL;
CREATE INDEX "QualityControl_domain_controlDate_idx" ON "QualityControl"("domain", "controlDate");

-- Classification configurable des non-conformités
ALTER TABLE "NonConformity" ADD COLUMN "classification" TEXT;
