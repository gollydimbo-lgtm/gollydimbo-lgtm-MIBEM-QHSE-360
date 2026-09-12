-- Additif uniquement. Aucune colonne ni table existante n'est modifiée ou
-- supprimée, aucune donnée ne peut être perdue par cette migration.

ALTER TABLE "VisiteMedicale" ADD COLUMN "employeeId" TEXT;
ALTER TABLE "VisiteMedicale" ADD COLUMN "service" TEXT;
ALTER TABLE "VisiteMedicale" ADD COLUMN "typeVisite" TEXT;
ALTER TABLE "VisiteMedicale" ADD COLUMN "dateDerniereVisite" TIMESTAMP(3);
ALTER TABLE "VisiteMedicale" ADD COLUMN "restrictions" TEXT;
ALTER TABLE "VisiteMedicale" ADD COLUMN "amenagementPoste" TEXT;
ALTER TABLE "VisiteMedicale" ADD COLUMN "medecinService" TEXT;
ALTER TABLE "VisiteMedicale" ADD COLUMN "suiviParticulier" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "VisiteMedicale" ADD CONSTRAINT "VisiteMedicale_employeeId_fkey" FOREIGN KEY ("employeeId") REFERENCES "Employee"("id") ON DELETE SET NULL;

CREATE TABLE "RisqueSanitaire" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "code" TEXT NOT NULL,
  "categorie" TEXT,
  "danger" TEXT NOT NULL,
  "source" TEXT,
  "activite" TEXT,
  "poste" TEXT,
  "zone" TEXT,
  "siteId" TEXT,
  "processusId" TEXT,
  "personnelExpose" TEXT,
  "nombrePersonnesExposees" INTEGER,
  "dureeExposition" TEXT,
  "frequenceExposition" TEXT,
  "voieExposition" TEXT,
  "niveauExposition" TEXT,
  "gravite" INTEGER NOT NULL DEFAULT 1,
  "probabilite" INTEGER NOT NULL DEFAULT 1,
  "criticite" INTEGER NOT NULL DEFAULT 1,
  "mesuresExistantes" TEXT,
  "mesuresSupplementaires" TEXT,
  "responsableId" TEXT,
  "echeance" TIMESTAMP(3),
  "statut" TEXT NOT NULL DEFAULT 'ACTIVE',
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL
);
CREATE UNIQUE INDEX "RisqueSanitaire_code_key" ON "RisqueSanitaire"("code");
ALTER TABLE "RisqueSanitaire" ADD CONSTRAINT "RisqueSanitaire_siteId_fkey" FOREIGN KEY ("siteId") REFERENCES "Site"("id") ON DELETE SET NULL;
ALTER TABLE "RisqueSanitaire" ADD CONSTRAINT "RisqueSanitaire_processusId_fkey" FOREIGN KEY ("processusId") REFERENCES "Processus"("id") ON DELETE SET NULL;
ALTER TABLE "RisqueSanitaire" ADD CONSTRAINT "RisqueSanitaire_responsableId_fkey" FOREIGN KEY ("responsableId") REFERENCES "User"("id") ON DELETE SET NULL;

CREATE TABLE "ExpositionSurveillance" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "risqueSanitaireId" TEXT NOT NULL,
  "employeeId" TEXT,
  "agentDangereux" TEXT,
  "poste" TEXT,
  "niveauExposition" TEXT,
  "frequence" TEXT,
  "duree" TEXT,
  "dateMesure" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "valeurMesuree" DOUBLE PRECISION,
  "valeurLimite" DOUBLE PRECISION,
  "unite" TEXT,
  "conforme" BOOLEAN,
  "commentaire" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);
ALTER TABLE "ExpositionSurveillance" ADD CONSTRAINT "ExpositionSurveillance_risqueSanitaireId_fkey" FOREIGN KEY ("risqueSanitaireId") REFERENCES "RisqueSanitaire"("id") ON DELETE CASCADE;
ALTER TABLE "ExpositionSurveillance" ADD CONSTRAINT "ExpositionSurveillance_employeeId_fkey" FOREIGN KEY ("employeeId") REFERENCES "Employee"("id") ON DELETE SET NULL;

-- Le plan d'actions des risques sanitaires réutilise le module Actions
-- déjà existant — un seul champ ajouté, aucune duplication.
ALTER TABLE "Action" ADD COLUMN "risqueSanitaireId" TEXT;
ALTER TABLE "Action" ADD CONSTRAINT "Action_risqueSanitaireId_fkey" FOREIGN KEY ("risqueSanitaireId") REFERENCES "RisqueSanitaire"("id") ON DELETE SET NULL;
