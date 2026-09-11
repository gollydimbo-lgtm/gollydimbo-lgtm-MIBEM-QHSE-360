-- Additif uniquement. Aucune colonne ni table existante n'est modifiée ou
-- supprimée, aucune donnée ne peut être perdue par cette migration.

ALTER TABLE "Fournisseur" ADD COLUMN "nomCommercial" TEXT;
ALTER TABLE "Fournisseur" ADD COLUMN "typeFournisseur" TEXT;
ALTER TABLE "Fournisseur" ADD COLUMN "familleAchat" TEXT;
ALTER TABLE "Fournisseur" ADD COLUMN "produitsServices" TEXT;
ALTER TABLE "Fournisseur" ADD COLUMN "adresse" TEXT;
ALTER TABLE "Fournisseur" ADD COLUMN "pays" TEXT;
ALTER TABLE "Fournisseur" ADD COLUMN "region" TEXT;
ALTER TABLE "Fournisseur" ADD COLUMN "ville" TEXT;
ALTER TABLE "Fournisseur" ADD COLUMN "contactNom" TEXT;
ALTER TABLE "Fournisseur" ADD COLUMN "contactTelephone" TEXT;
ALTER TABLE "Fournisseur" ADD COLUMN "contactEmail" TEXT;
ALTER TABLE "Fournisseur" ADD COLUMN "siteWeb" TEXT;
ALTER TABLE "Fournisseur" ADD COLUMN "responsableInterneId" TEXT;
ALTER TABLE "Fournisseur" ADD COLUMN "dateDebutRelation" TIMESTAMP(3);
ALTER TABLE "Fournisseur" ADD COLUMN "niveauRisque" TEXT;
ALTER TABLE "Fournisseur" ADD COLUMN "criticite" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "Fournisseur" ADD COLUMN "capaciteTechnique" TEXT;
ALTER TABLE "Fournisseur" ADD COLUMN "capaciteCommerciale" TEXT;
ALTER TABLE "Fournisseur" ADD COLUMN "situationFinanciere" TEXT;
ALTER TABLE "Fournisseur" ADD COLUMN "dateHomologation" TIMESTAMP(3);
ALTER TABLE "Fournisseur" ADD COLUMN "dateProchaineReevaluation" TIMESTAMP(3);
ALTER TABLE "Fournisseur" ADD COLUMN "motifDemande" TEXT;
ALTER TABLE "Fournisseur" ADD COLUMN "avisQhse" TEXT;
ALTER TABLE "Fournisseur" ADD COLUMN "avisAchats" TEXT;
ALTER TABLE "Fournisseur" ADD COLUMN "avisTechnique" TEXT;
ALTER TABLE "Fournisseur" ADD COLUMN "decisionFinale" TEXT;
ALTER TABLE "Fournisseur" ADD COLUMN "conditionsParticulieres" TEXT;
ALTER TABLE "Fournisseur" ADD COLUMN "monoSource" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "Fournisseur" ADD COLUMN "solutionSecours" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "Fournisseur" ADD COLUMN "delaiRemplacementJours" INTEGER;
ALTER TABLE "Fournisseur" ADD COLUMN "planContinuite" TEXT;
ALTER TABLE "Fournisseur" ADD COLUMN "scoreLivraison" INTEGER;
ALTER TABLE "Fournisseur" ADD COLUMN "scoreQhse" INTEGER;
ALTER TABLE "Fournisseur" ADD COLUMN "scoreCommercial" INTEGER;
ALTER TABLE "Fournisseur" ADD COLUMN "scoreReactivite" INTEGER;
ALTER TABLE "Fournisseur" ADD COLUMN "scoreEnvironnemental" INTEGER;
ALTER TABLE "Fournisseur" ADD COLUMN "scoreSecurite" INTEGER;
ALTER TABLE "Fournisseur" ADD CONSTRAINT "Fournisseur_responsableInterneId_fkey" FOREIGN KEY ("responsableInterneId") REFERENCES "User"("id") ON DELETE SET NULL;

CREATE TABLE "FournisseurCertification" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "fournisseurId" TEXT NOT NULL,
  "type" TEXT NOT NULL,
  "numero" TEXT,
  "organismeCertificateur" TEXT,
  "dateEmission" TIMESTAMP(3),
  "dateExpiration" TIMESTAMP(3),
  "statut" TEXT NOT NULL DEFAULT 'VALIDE',
  "commentaire" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);
ALTER TABLE "FournisseurCertification" ADD CONSTRAINT "FournisseurCertification_fournisseurId_fkey" FOREIGN KEY ("fournisseurId") REFERENCES "Fournisseur"("id") ON DELETE CASCADE;

-- Liens universels vers les modules déjà existants — un seul champ
-- ajouté à chaque fois, jamais de duplication.
ALTER TABLE "NonConformity" ADD COLUMN "fournisseurId" TEXT;
ALTER TABLE "NonConformity" ADD CONSTRAINT "NonConformity_fournisseurId_fkey" FOREIGN KEY ("fournisseurId") REFERENCES "Fournisseur"("id") ON DELETE SET NULL;

ALTER TABLE "Action" ADD COLUMN "fournisseurId" TEXT;
ALTER TABLE "Action" ADD CONSTRAINT "Action_fournisseurId_fkey" FOREIGN KEY ("fournisseurId") REFERENCES "Fournisseur"("id") ON DELETE SET NULL;

ALTER TABLE "QhseAudit" ADD COLUMN "fournisseurId" TEXT;
ALTER TABLE "QhseAudit" ADD CONSTRAINT "QhseAudit_fournisseurId_fkey" FOREIGN KEY ("fournisseurId") REFERENCES "Fournisseur"("id") ON DELETE SET NULL;

ALTER TABLE "Risk" ADD COLUMN "fournisseurId" TEXT;
ALTER TABLE "Risk" ADD CONSTRAINT "Risk_fournisseurId_fkey" FOREIGN KEY ("fournisseurId") REFERENCES "Fournisseur"("id") ON DELETE SET NULL;
