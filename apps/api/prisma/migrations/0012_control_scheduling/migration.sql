-- Additif uniquement. Aucune table ni colonne existante n'est modifiée,
-- aucune donnée ne peut être perdue par cette migration.

CREATE TABLE "ControlSchedule" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "code" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "domain" TEXT NOT NULL DEFAULT 'QUALITE',
  "typeId" TEXT,
  "templateId" TEXT,
  "frequency" TEXT NOT NULL,
  "intervalDays" INTEGER,
  "assignedToId" TEXT,
  "nextDueDate" TIMESTAMP(3) NOT NULL,
  "lastGeneratedAt" TIMESTAMP(3),
  "active" BOOLEAN NOT NULL DEFAULT true,
  "siteId" TEXT,
  "lineId" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE UNIQUE INDEX "ControlSchedule_code_key" ON "ControlSchedule"("code");
CREATE INDEX "ControlSchedule_nextDueDate_active_idx" ON "ControlSchedule"("nextDueDate", "active");
ALTER TABLE "ControlSchedule" ADD CONSTRAINT "ControlSchedule_typeId_fkey" FOREIGN KEY ("typeId") REFERENCES "ControlType"("id") ON DELETE SET NULL;
ALTER TABLE "ControlSchedule" ADD CONSTRAINT "ControlSchedule_templateId_fkey" FOREIGN KEY ("templateId") REFERENCES "ControlTemplate"("id") ON DELETE SET NULL;
ALTER TABLE "ControlSchedule" ADD CONSTRAINT "ControlSchedule_assignedToId_fkey" FOREIGN KEY ("assignedToId") REFERENCES "User"("id") ON DELETE SET NULL;
ALTER TABLE "ControlSchedule" ADD CONSTRAINT "ControlSchedule_siteId_fkey" FOREIGN KEY ("siteId") REFERENCES "Site"("id") ON DELETE SET NULL;
ALTER TABLE "ControlSchedule" ADD CONSTRAINT "ControlSchedule_lineId_fkey" FOREIGN KEY ("lineId") REFERENCES "ProductionLine"("id") ON DELETE SET NULL;
