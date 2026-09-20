-- Rapports QHSE — Phase 3 : persistance, statut, version et contenu
-- editorial separe des donnees sources. Un rapport valide ou distribue est
-- verrouille cote application ; toute modification passe par une nouvelle
-- version (versionOfId / versionGroupId), jamais un ecrasement silencieux.

CREATE TABLE "RapportQhse" (
  "id" TEXT NOT NULL,
  "titre" TEXT NOT NULL,
  "mode" TEXT NOT NULL DEFAULT 'COMPLET',
  "domaineThematique" TEXT,
  "periodeFrom" TIMESTAMP(3) NOT NULL,
  "periodeTo" TIMESTAMP(3) NOT NULL,
  "siteId" TEXT,
  "confidentialite" TEXT,
  "statut" TEXT NOT NULL DEFAULT 'BROUILLON',
  "version" INTEGER NOT NULL DEFAULT 1,
  "versionGroupId" TEXT,
  "versionOfId" TEXT,
  "donnees" JSONB NOT NULL,
  "analyseQhse" TEXT,
  "observationsDirection" TEXT,
  "conclusion" TEXT,
  "preparePar" TEXT,
  "prepareParDate" TIMESTAMP(3),
  "verifiePar" TEXT,
  "verifieParDate" TIMESTAMP(3),
  "validePar" TEXT,
  "valideParDate" TIMESTAMP(3),
  "createdById" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,

  CONSTRAINT "RapportQhse_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "RapportQhse_statut_idx" ON "RapportQhse"("statut");
CREATE INDEX "RapportQhse_versionGroupId_idx" ON "RapportQhse"("versionGroupId");

CREATE TABLE "RapportDistribution" (
  "id" TEXT NOT NULL,
  "rapportId" TEXT NOT NULL,
  "destinataireId" TEXT,
  "destinataireEmail" TEXT,
  "distribuePar" TEXT,
  "dateDistribution" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "version" INTEGER NOT NULL,

  CONSTRAINT "RapportDistribution_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "RapportQhse" ADD CONSTRAINT "RapportQhse_siteId_fkey" FOREIGN KEY ("siteId") REFERENCES "Site"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "RapportQhse" ADD CONSTRAINT "RapportQhse_createdById_fkey" FOREIGN KEY ("createdById") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "RapportDistribution" ADD CONSTRAINT "RapportDistribution_rapportId_fkey" FOREIGN KEY ("rapportId") REFERENCES "RapportQhse"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "RapportDistribution" ADD CONSTRAINT "RapportDistribution_destinataireId_fkey" FOREIGN KEY ("destinataireId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
