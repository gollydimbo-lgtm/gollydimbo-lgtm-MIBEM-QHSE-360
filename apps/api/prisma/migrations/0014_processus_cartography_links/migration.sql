-- Additif uniquement. Aucune colonne ni table existante n'est modifiée ou
-- supprimée, aucune donnée ne peut être perdue par cette migration.

ALTER TABLE "Processus" ADD COLUMN "positionX" DOUBLE PRECISION;
ALTER TABLE "Processus" ADD COLUMN "positionY" DOUBLE PRECISION;

CREATE TABLE "ProcessusLink" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "sourceId" TEXT NOT NULL,
  "targetId" TEXT NOT NULL,
  "label" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE UNIQUE INDEX "ProcessusLink_sourceId_targetId_key" ON "ProcessusLink"("sourceId", "targetId");
ALTER TABLE "ProcessusLink" ADD CONSTRAINT "ProcessusLink_sourceId_fkey" FOREIGN KEY ("sourceId") REFERENCES "Processus"("id") ON DELETE CASCADE;
ALTER TABLE "ProcessusLink" ADD CONSTRAINT "ProcessusLink_targetId_fkey" FOREIGN KEY ("targetId") REFERENCES "Processus"("id") ON DELETE CASCADE;
