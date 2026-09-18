-- Additif uniquement. "code" est ajouté avec une valeur temporaire unique
-- pour les lignes déjà existantes, avant de devenir obligatoire — aucune
-- ligne existante ne peut être perdue ou bloquée par cette migration.

ALTER TABLE "EpiAssignment" ADD COLUMN "code" TEXT;
UPDATE "EpiAssignment" SET "code" = 'DOT-LEGACY-' || "id" WHERE "code" IS NULL;
ALTER TABLE "EpiAssignment" ALTER COLUMN "code" SET NOT NULL;
CREATE UNIQUE INDEX "EpiAssignment_code_key" ON "EpiAssignment"("code");

ALTER TABLE "EpiAssignment" ADD COLUMN "size" TEXT;
ALTER TABLE "EpiAssignment" ADD COLUMN "expectedDurationDays" INTEGER;
ALTER TABLE "EpiAssignment" ADD COLUMN "status" TEXT NOT NULL DEFAULT 'ACTIVE';
ALTER TABLE "EpiAssignment" ADD COLUMN "responsibleId" TEXT;
ALTER TABLE "EpiAssignment" ADD COLUMN "employeeSignature" TEXT;
ALTER TABLE "EpiAssignment" ADD COLUMN "responsibleSignature" TEXT;
ALTER TABLE "EpiAssignment" ADD CONSTRAINT "EpiAssignment_responsibleId_fkey" FOREIGN KEY ("responsibleId") REFERENCES "User"("id") ON DELETE SET NULL;
