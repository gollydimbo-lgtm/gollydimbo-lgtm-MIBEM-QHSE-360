-- Additif uniquement. Aucune colonne ni table existante n'est modifiée ou
-- supprimée, aucune donnée ne peut être perdue par cette migration.

-- Enrichissement de la fiche Processus
ALTER TABLE "Processus" ADD COLUMN "type" TEXT NOT NULL DEFAULT 'OPERATIONNEL';
ALTER TABLE "Processus" ADD COLUMN "domaine" TEXT;
ALTER TABLE "Processus" ADD COLUMN "departement" TEXT;
ALTER TABLE "Processus" ADD COLUMN "siteId" TEXT;
ALTER TABLE "Processus" ADD COLUMN "version" TEXT;
ALTER TABLE "Processus" ADD COLUMN "statut" TEXT NOT NULL DEFAULT 'ACTIF';
ALTER TABLE "Processus" ADD COLUMN "criticite" TEXT;
ALTER TABLE "Processus" ADD COLUMN "piloteId" TEXT;
ALTER TABLE "Processus" ADD COLUMN "suppleantId" TEXT;
ALTER TABLE "Processus" ADD COLUMN "finalite" TEXT;
ALTER TABLE "Processus" ADD COLUMN "objectifPrincipal" TEXT;
ALTER TABLE "Processus" ADD COLUMN "perimetreDebut" TEXT;
ALTER TABLE "Processus" ADD COLUMN "perimetreFin" TEXT;
ALTER TABLE "Processus" ADD COLUMN "suppliers" JSONB;
ALTER TABLE "Processus" ADD COLUMN "inputs" JSONB;
ALTER TABLE "Processus" ADD COLUMN "outputs" JSONB;
ALTER TABLE "Processus" ADD COLUMN "customers" JSONB;
ALTER TABLE "Processus" ADD COLUMN "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE "Processus" ADD CONSTRAINT "Processus_siteId_fkey" FOREIGN KEY ("siteId") REFERENCES "Site"("id") ON DELETE SET NULL;
ALTER TABLE "Processus" ADD CONSTRAINT "Processus_piloteId_fkey" FOREIGN KEY ("piloteId") REFERENCES "User"("id") ON DELETE SET NULL;
ALTER TABLE "Processus" ADD CONSTRAINT "Processus_suppleantId_fkey" FOREIGN KEY ("suppleantId") REFERENCES "User"("id") ON DELETE SET NULL;

-- Activités (le "P" du SIPOC)
CREATE TABLE "ProcessusActivity" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "processusId" TEXT NOT NULL,
  "code" TEXT,
  "order" INTEGER NOT NULL DEFAULT 0,
  "name" TEXT NOT NULL,
  "description" TEXT,
  "responsibleId" TEXT,
  "inputs" TEXT,
  "outputs" TEXT,
  "resources" TEXT,
  "equipment" TEXT,
  "frequency" TEXT,
  "criticality" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);
ALTER TABLE "ProcessusActivity" ADD CONSTRAINT "ProcessusActivity_processusId_fkey" FOREIGN KEY ("processusId") REFERENCES "Processus"("id") ON DELETE CASCADE;
ALTER TABLE "ProcessusActivity" ADD CONSTRAINT "ProcessusActivity_responsibleId_fkey" FOREIGN KEY ("responsibleId") REFERENCES "User"("id") ON DELETE SET NULL;

-- Matrice RACI par activité
CREATE TABLE "ProcessusRaci" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "activityId" TEXT NOT NULL,
  "userId" TEXT,
  "roleLabel" TEXT,
  "raci" TEXT NOT NULL
);
ALTER TABLE "ProcessusRaci" ADD CONSTRAINT "ProcessusRaci_activityId_fkey" FOREIGN KEY ("activityId") REFERENCES "ProcessusActivity"("id") ON DELETE CASCADE;
ALTER TABLE "ProcessusRaci" ADD CONSTRAINT "ProcessusRaci_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE SET NULL;

-- Exigences légales, réglementaires et normatives
CREATE TABLE "ProcessusExigence" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "processusId" TEXT NOT NULL,
  "exigence" TEXT NOT NULL,
  "origine" TEXT,
  "reference" TEXT,
  "applicable" BOOLEAN NOT NULL DEFAULT true,
  "preuveConformite" TEXT,
  "responsableId" TEXT,
  "frequenceVerification" TEXT,
  "derniereVerification" TIMESTAMP(3),
  "prochaineEcheance" TIMESTAMP(3),
  "statutConformite" TEXT NOT NULL DEFAULT 'CONFORME',
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);
ALTER TABLE "ProcessusExigence" ADD CONSTRAINT "ProcessusExigence_processusId_fkey" FOREIGN KEY ("processusId") REFERENCES "Processus"("id") ON DELETE CASCADE;
ALTER TABLE "ProcessusExigence" ADD CONSTRAINT "ProcessusExigence_responsableId_fkey" FOREIGN KEY ("responsableId") REFERENCES "User"("id") ON DELETE SET NULL;

-- Liens universels vers les modules déjà existants — un seul champ
-- ajouté à chaque fois, jamais de duplication de données.
ALTER TABLE "Risk" ADD COLUMN "processusId" TEXT;
ALTER TABLE "Risk" ADD CONSTRAINT "Risk_processusId_fkey" FOREIGN KEY ("processusId") REFERENCES "Processus"("id") ON DELETE SET NULL;

ALTER TABLE "Action" ADD COLUMN "processusId" TEXT;
ALTER TABLE "Action" ADD CONSTRAINT "Action_processusId_fkey" FOREIGN KEY ("processusId") REFERENCES "Processus"("id") ON DELETE SET NULL;

ALTER TABLE "NonConformity" ADD COLUMN "processusId" TEXT;
ALTER TABLE "NonConformity" ADD CONSTRAINT "NonConformity_processusId_fkey" FOREIGN KEY ("processusId") REFERENCES "Processus"("id") ON DELETE SET NULL;

ALTER TABLE "QhseAudit" ADD COLUMN "processusId" TEXT;
ALTER TABLE "QhseAudit" ADD CONSTRAINT "QhseAudit_processusId_fkey" FOREIGN KEY ("processusId") REFERENCES "Processus"("id") ON DELETE SET NULL;

ALTER TABLE "Document" ADD COLUMN "processusId" TEXT;
ALTER TABLE "Document" ADD CONSTRAINT "Document_processusId_fkey" FOREIGN KEY ("processusId") REFERENCES "Processus"("id") ON DELETE SET NULL;

ALTER TABLE "Training" ADD COLUMN "processusId" TEXT;
ALTER TABLE "Training" ADD CONSTRAINT "Training_processusId_fkey" FOREIGN KEY ("processusId") REFERENCES "Processus"("id") ON DELETE SET NULL;

ALTER TABLE "ObjectifQhse" ADD COLUMN "processusId" TEXT;
ALTER TABLE "ObjectifQhse" ADD CONSTRAINT "ObjectifQhse_processusId_fkey" FOREIGN KEY ("processusId") REFERENCES "Processus"("id") ON DELETE SET NULL;

ALTER TABLE "QualityControl" ADD COLUMN "processusId" TEXT;
ALTER TABLE "QualityControl" ADD CONSTRAINT "QualityControl_processusId_fkey" FOREIGN KEY ("processusId") REFERENCES "Processus"("id") ON DELETE SET NULL;
