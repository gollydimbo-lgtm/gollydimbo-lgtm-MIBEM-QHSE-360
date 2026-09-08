-- Additif uniquement. Aucune colonne existante n'est modifiée ou
-- supprimée, aucune donnée ne peut être perdue par cette migration.

-- Extension de l'enum des mouvements de stock (retour, réforme)
ALTER TYPE "EpiMovementType" ADD VALUE IF NOT EXISTS 'RETURN';
ALTER TYPE "EpiMovementType" ADD VALUE IF NOT EXISTS 'REFORM';

-- Catégories EPI (gérables par l'administrateur, pas figées en dur)
CREATE TABLE "EpiCategory" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "name" TEXT NOT NULL
);
CREATE UNIQUE INDEX "EpiCategory_name_key" ON "EpiCategory"("name");

-- Enrichissement de la fiche EPI existante
ALTER TABLE "Epi" ADD COLUMN "categoryId" TEXT;
ALTER TABLE "Epi" ADD COLUMN "reference" TEXT;
ALTER TABLE "Epi" ADD COLUMN "subcategory" TEXT;
ALTER TABLE "Epi" ADD COLUMN "description" TEXT;
ALTER TABLE "Epi" ADD COLUMN "manufacturer" TEXT;
ALTER TABLE "Epi" ADD COLUMN "model" TEXT;
ALTER TABLE "Epi" ADD COLUMN "size" TEXT;
ALTER TABLE "Epi" ADD COLUMN "color" TEXT;
ALTER TABLE "Epi" ADD COLUMN "material" TEXT;
ALTER TABLE "Epi" ADD COLUMN "standard" TEXT;
ALTER TABLE "Epi" ADD COLUMN "durationMode" TEXT;
ALTER TABLE "Epi" ADD COLUMN "durationValueDays" INTEGER;
ALTER TABLE "Epi" ADD COLUMN "disposable" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "Epi" ADD COLUMN "shared" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "Epi" ADD COLUMN "maxStock" INTEGER;
ALTER TABLE "Epi" ADD COLUMN "location" TEXT;
ALTER TABLE "Epi" ADD COLUMN "status" TEXT NOT NULL DEFAULT 'ACTIVE';
ALTER TABLE "Epi" ADD CONSTRAINT "Epi_categoryId_fkey" FOREIGN KEY ("categoryId") REFERENCES "EpiCategory"("id") ON DELETE SET NULL;

-- Inspections EPI
CREATE TABLE "EpiInspection" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "epiId" TEXT NOT NULL,
  "employeeId" TEXT,
  "inspectedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "result" TEXT NOT NULL,
  "observations" TEXT,
  "inspectedById" TEXT
);
ALTER TABLE "EpiInspection" ADD CONSTRAINT "EpiInspection_epiId_fkey" FOREIGN KEY ("epiId") REFERENCES "Epi"("id") ON DELETE CASCADE;
ALTER TABLE "EpiInspection" ADD CONSTRAINT "EpiInspection_employeeId_fkey" FOREIGN KEY ("employeeId") REFERENCES "Employee"("id") ON DELETE SET NULL;
ALTER TABLE "EpiInspection" ADD CONSTRAINT "EpiInspection_inspectedById_fkey" FOREIGN KEY ("inspectedById") REFERENCES "User"("id") ON DELETE SET NULL;

-- Catégories EPC
CREATE TABLE "EpcCategory" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "name" TEXT NOT NULL
);
CREATE UNIQUE INDEX "EpcCategory_name_key" ON "EpcCategory"("name");

-- Bibliothèque EPC
CREATE TABLE "Epc" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "code" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "categoryId" TEXT,
  "location" TEXT,
  "zone" TEXT,
  "description" TEXT,
  "manufacturer" TEXT,
  "model" TEXT,
  "reference" TEXT,
  "installedAt" TIMESTAMP(3),
  "responsibleId" TEXT,
  "condition" TEXT,
  "status" TEXT NOT NULL DEFAULT 'ACTIVE',
  "inspectionFrequencyDays" INTEGER,
  "lastInspectionAt" TIMESTAMP(3),
  "nextInspectionAt" TIMESTAMP(3),
  "notes" TEXT
);
CREATE UNIQUE INDEX "Epc_code_key" ON "Epc"("code");
ALTER TABLE "Epc" ADD CONSTRAINT "Epc_categoryId_fkey" FOREIGN KEY ("categoryId") REFERENCES "EpcCategory"("id") ON DELETE SET NULL;
ALTER TABLE "Epc" ADD CONSTRAINT "Epc_responsibleId_fkey" FOREIGN KEY ("responsibleId") REFERENCES "User"("id") ON DELETE SET NULL;

-- Inspections EPC
CREATE TABLE "EpcInspection" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "epcId" TEXT NOT NULL,
  "inspectedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "result" TEXT NOT NULL,
  "observations" TEXT,
  "inspectedById" TEXT
);
ALTER TABLE "EpcInspection" ADD CONSTRAINT "EpcInspection_epcId_fkey" FOREIGN KEY ("epcId") REFERENCES "Epc"("id") ON DELETE CASCADE;
ALTER TABLE "EpcInspection" ADD CONSTRAINT "EpcInspection_inspectedById_fkey" FOREIGN KEY ("inspectedById") REFERENCES "User"("id") ON DELETE SET NULL;

-- Matrice Poste / Activité / Danger / Risque / Mesure / EPI / EPC
CREATE TABLE "JobRiskProtection" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "code" TEXT NOT NULL,
  "jobTitle" TEXT NOT NULL,
  "activity" TEXT,
  "hazard" TEXT NOT NULL,
  "riskDescription" TEXT,
  "preventionMeasure" TEXT,
  "epiId" TEXT,
  "epcId" TEXT,
  "usageFrequency" TEXT,
  "controlCriteria" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE UNIQUE INDEX "JobRiskProtection_code_key" ON "JobRiskProtection"("code");
ALTER TABLE "JobRiskProtection" ADD CONSTRAINT "JobRiskProtection_epiId_fkey" FOREIGN KEY ("epiId") REFERENCES "Epi"("id") ON DELETE SET NULL;
ALTER TABLE "JobRiskProtection" ADD CONSTRAINT "JobRiskProtection_epcId_fkey" FOREIGN KEY ("epcId") REFERENCES "Epc"("id") ON DELETE SET NULL;
