-- Additif uniquement. Aucune colonne ni table existante n'est modifiée ou
-- supprimée, aucune donnée ne peut être perdue par cette migration.
-- Matrice de liaison générique CAPA (points 2, 6, 7, 8, 26 du cahier des
-- charges) : une seule table de liaison, réutilisée par tous les modules,
-- plutôt qu'une table CAPA par module. Permet N sources -> 1 CAPA et
-- 1 source -> N CAPA, en complément des colonnes dédiées existantes sur
-- Action (nonConformityId, riskId, auditFindingId...) qui restent utilisées
-- telles quelles pour la source principale.

CREATE TABLE "CapaLink" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "actionId" TEXT NOT NULL,
  "sourceModule" TEXT NOT NULL,
  "sourceEntityId" TEXT NOT NULL,
  "relationType" TEXT NOT NULL DEFAULT 'GENEREE_PAR',
  "metadata" JSONB,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "createdById" TEXT
);
CREATE INDEX "CapaLink_sourceModule_sourceEntityId_idx" ON "CapaLink"("sourceModule","sourceEntityId");
ALTER TABLE "CapaLink" ADD CONSTRAINT "CapaLink_actionId_fkey" FOREIGN KEY ("actionId") REFERENCES "Action"("id") ON DELETE CASCADE;
ALTER TABLE "CapaLink" ADD CONSTRAINT "CapaLink_createdById_fkey" FOREIGN KEY ("createdById") REFERENCES "User"("id") ON DELETE SET NULL;
