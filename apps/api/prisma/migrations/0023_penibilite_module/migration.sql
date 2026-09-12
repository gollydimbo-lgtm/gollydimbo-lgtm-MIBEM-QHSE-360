-- Additif uniquement. Aucune colonne ni table existante n'est modifiée ou
-- supprimée, aucune donnée ne peut être perdue par cette migration.

CREATE TABLE "PenibiliteFactor" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "nom" TEXT NOT NULL,
  "description" TEXT,
  "actif" BOOLEAN NOT NULL DEFAULT true,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE UNIQUE INDEX "PenibiliteFactor_nom_key" ON "PenibiliteFactor"("nom");

CREATE TABLE "PenibiliteExposition" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "employeeId" TEXT,
  "facteurId" TEXT NOT NULL,
  "poste" TEXT,
  "niveauExposition" TEXT,
  "duree" TEXT,
  "frequence" TEXT,
  "mesuresPrevention" TEXT,
  "dateEvaluation" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "prochaineReevaluation" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);
ALTER TABLE "PenibiliteExposition" ADD CONSTRAINT "PenibiliteExposition_employeeId_fkey" FOREIGN KEY ("employeeId") REFERENCES "Employee"("id") ON DELETE SET NULL;
ALTER TABLE "PenibiliteExposition" ADD CONSTRAINT "PenibiliteExposition_facteurId_fkey" FOREIGN KEY ("facteurId") REFERENCES "PenibiliteFactor"("id") ON DELETE CASCADE;
