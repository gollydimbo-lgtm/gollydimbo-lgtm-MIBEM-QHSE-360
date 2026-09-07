-- Additif uniquement : ajoute 2 colonnes optionnelles à SafetyEvent
-- (aucune ligne existante affectée, valeurs par défaut sûres) et crée une
-- nouvelle table. Aucune donnée existante ne peut être perdue.

ALTER TABLE "SafetyEvent" ADD COLUMN "withLostTime" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "SafetyEvent" ADD COLUMN "lostDays" INTEGER;

CREATE TABLE "WorkedHours" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "code" TEXT NOT NULL,
  "periodStart" TIMESTAMP(3) NOT NULL,
  "periodEnd" TIMESTAMP(3) NOT NULL,
  "hours" DOUBLE PRECISION NOT NULL,
  "site" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL
);
CREATE UNIQUE INDEX "WorkedHours_code_key" ON "WorkedHours"("code");
