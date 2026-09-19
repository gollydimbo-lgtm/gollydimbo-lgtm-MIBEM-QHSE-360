-- Rapports QHSE — Phase 1 : identite de l'entreprise reutilisee automatiquement
-- dans les rapports (page de garde, en-tete). Table singleton (une seule ligne,
-- id fixe 'default') : pas de nouvelle base parallele, juste les informations
-- de presentation.

CREATE TABLE "CompanyIdentity" (
  "id" TEXT NOT NULL,
  "nomOfficiel" TEXT,
  "nomCommercial" TEXT,
  "sigle" TEXT,
  "slogan" TEXT,
  "logoUrl" TEXT,
  "adresse" TEXT,
  "telephone" TEXT,
  "email" TEXT,
  "siteInternet" TEXT,
  "pays" TEXT,
  "responsableQhseId" TEXT,
  "directeurId" TEXT,
  "responsableRapportId" TEXT,
  "updatedById" TEXT,
  "updatedAt" TIMESTAMP(3) NOT NULL,

  CONSTRAINT "CompanyIdentity_pkey" PRIMARY KEY ("id")
);
