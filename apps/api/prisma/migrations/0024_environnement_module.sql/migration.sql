-- Additif uniquement. Aucune colonne ni table existante n'est modifiée ou
-- supprimée, aucune donnée ne peut être perdue par cette migration.

ALTER TABLE "IndicateurQualite" ADD COLUMN "domaine" TEXT NOT NULL DEFAULT 'QUALITE';
ALTER TABLE "IndicateurQualite" ADD COLUMN "poids" DOUBLE PRECISION NOT NULL DEFAULT 1;

ALTER TABLE "EnvironmentRecord" ADD COLUMN "categorie" TEXT;
ALTER TABLE "EnvironmentRecord" ADD COLUMN "sousCategorie" TEXT;
ALTER TABLE "EnvironmentRecord" ADD COLUMN "processusId" TEXT;
ALTER TABLE "EnvironmentRecord" ADD COLUMN "seuilReglementaire" DOUBLE PRECISION;
ALTER TABLE "EnvironmentRecord" ADD COLUMN "conforme" BOOLEAN;
ALTER TABLE "EnvironmentRecord" ADD COLUMN "cout" DOUBLE PRECISION;
ALTER TABLE "EnvironmentRecord" ADD COLUMN "modeTraitement" TEXT;
ALTER TABLE "EnvironmentRecord" ADD COLUMN "destination" TEXT;
ALTER TABLE "EnvironmentRecord" ADD CONSTRAINT "EnvironmentRecord_processusId_fkey" FOREIGN KEY ("processusId") REFERENCES "Processus"("id") ON DELETE SET NULL;

CREATE TABLE "EnvironnementAspect" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "code" TEXT NOT NULL,
  "siteId" TEXT,
  "processusId" TEXT,
  "activite" TEXT,
  "aspect" TEXT NOT NULL,
  "source" TEXT,
  "impact" TEXT,
  "milieu" TEXT,
  "situation" TEXT NOT NULL DEFAULT 'NORMALE',
  "frequence" INTEGER NOT NULL DEFAULT 1,
  "gravite" INTEGER NOT NULL DEFAULT 1,
  "probabilite" INTEGER NOT NULL DEFAULT 1,
  "maitrise" INTEGER NOT NULL DEFAULT 1,
  "criticite" INTEGER NOT NULL DEFAULT 1,
  "significatif" BOOLEAN NOT NULL DEFAULT false,
  "mesuresMaitrise" TEXT,
  "responsableId" TEXT,
  "echeance" TIMESTAMP(3),
  "statut" TEXT NOT NULL DEFAULT 'ACTIVE',
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL
);
CREATE UNIQUE INDEX "EnvironnementAspect_code_key" ON "EnvironnementAspect"("code");
ALTER TABLE "EnvironnementAspect" ADD CONSTRAINT "EnvironnementAspect_siteId_fkey" FOREIGN KEY ("siteId") REFERENCES "Site"("id") ON DELETE SET NULL;
ALTER TABLE "EnvironnementAspect" ADD CONSTRAINT "EnvironnementAspect_processusId_fkey" FOREIGN KEY ("processusId") REFERENCES "Processus"("id") ON DELETE SET NULL;
ALTER TABLE "EnvironnementAspect" ADD CONSTRAINT "EnvironnementAspect_responsableId_fkey" FOREIGN KEY ("responsableId") REFERENCES "User"("id") ON DELETE SET NULL;

-- Le plan d'actions des aspects environnementaux réutilise le module
-- Actions déjà existant — un seul champ ajouté, aucune duplication.
ALTER TABLE "Action" ADD COLUMN "environnementAspectId" TEXT;
ALTER TABLE "Action" ADD CONSTRAINT "Action_environnementAspectId_fkey" FOREIGN KEY ("environnementAspectId") REFERENCES "EnvironnementAspect"("id") ON DELETE SET NULL;
