-- Additif uniquement. Aucune colonne existante n'est modifiée, aucune
-- donnée ne peut être perdue par cette migration.

ALTER TABLE "NonConformity" ADD COLUMN "epiId" TEXT;
ALTER TABLE "NonConformity" ADD COLUMN "epcId" TEXT;
ALTER TABLE "NonConformity" ADD CONSTRAINT "NonConformity_epiId_fkey" FOREIGN KEY ("epiId") REFERENCES "Epi"("id") ON DELETE SET NULL;
ALTER TABLE "NonConformity" ADD CONSTRAINT "NonConformity_epcId_fkey" FOREIGN KEY ("epcId") REFERENCES "Epc"("id") ON DELETE SET NULL;

CREATE TABLE "EpcMaintenance" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "epcId" TEXT NOT NULL,
  "date" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "type" TEXT NOT NULL,
  "description" TEXT,
  "cost" DOUBLE PRECISION,
  "performedById" TEXT,
  "nextMaintenanceAt" TIMESTAMP(3),
  "status" TEXT NOT NULL DEFAULT 'DONE'
);
ALTER TABLE "EpcMaintenance" ADD CONSTRAINT "EpcMaintenance_epcId_fkey" FOREIGN KEY ("epcId") REFERENCES "Epc"("id") ON DELETE CASCADE;
ALTER TABLE "EpcMaintenance" ADD CONSTRAINT "EpcMaintenance_performedById_fkey" FOREIGN KEY ("performedById") REFERENCES "User"("id") ON DELETE SET NULL;
