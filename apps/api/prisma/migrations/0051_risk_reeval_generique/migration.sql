-- AlterTable
-- Généralise RegulatoryRiskReevaluationRequest : requirementId devient
-- optionnel (une demande peut désormais venir d'un accident grave ou de
-- non-conformités récurrentes, pas seulement d'une exigence réglementaire),
-- et on ajoute sourceModule/sourceKey/sourceEntityId pour la détection
-- automatique idempotente (même motif que BesoinFormation.sourceKey).
ALTER TABLE "RegulatoryRiskReevaluationRequest" ALTER COLUMN "requirementId" DROP NOT NULL;
ALTER TABLE "RegulatoryRiskReevaluationRequest" ADD COLUMN     "sourceModule" TEXT NOT NULL DEFAULT 'REGLEMENTAIRE',
ADD COLUMN     "sourceKey" TEXT,
ADD COLUMN     "sourceEntityId" TEXT;

-- CreateIndex
CREATE UNIQUE INDEX "RegulatoryRiskReevaluationRequest_sourceKey_key" ON "RegulatoryRiskReevaluationRequest"("sourceKey");

-- DropForeignKey / AddForeignKey (requirementId FK devient nullable, même règle ON DELETE)
ALTER TABLE "RegulatoryRiskReevaluationRequest" DROP CONSTRAINT IF EXISTS "RegulatoryRiskReevaluationRequest_requirementId_fkey";
ALTER TABLE "RegulatoryRiskReevaluationRequest" ADD CONSTRAINT "RegulatoryRiskReevaluationRequest_requirementId_fkey" FOREIGN KEY ("requirementId") REFERENCES "RegulatoryRequirement"("id") ON DELETE CASCADE ON UPDATE CASCADE;
