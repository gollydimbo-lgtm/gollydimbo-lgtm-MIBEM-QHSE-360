-- Veille réglementaire — Phase 1 : fondations et chaîne centrale

CREATE TABLE "RegulatoryDomain" (
  "id" TEXT NOT NULL,
  "code" TEXT NOT NULL,
  "label" TEXT NOT NULL,
  "actif" BOOLEAN NOT NULL DEFAULT true,
  "order" INTEGER NOT NULL DEFAULT 0,
  CONSTRAINT "RegulatoryDomain_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "RegulatoryDomain_code_key" ON "RegulatoryDomain"("code");

CREATE TABLE "RegulatorySettings" (
  "id" TEXT NOT NULL,
  "alerteJ90" BOOLEAN NOT NULL DEFAULT true,
  "alerteJ60" BOOLEAN NOT NULL DEFAULT true,
  "alerteJ30" BOOLEAN NOT NULL DEFAULT true,
  "alerteJ15" BOOLEAN NOT NULL DEFAULT true,
  "alerteJ7" BOOLEAN NOT NULL DEFAULT true,
  "methodeCalculTaux" TEXT NOT NULL DEFAULT 'STANDARD',
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "RegulatorySettings_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "RegulatoryText" (
  "id" TEXT NOT NULL,
  "code" TEXT NOT NULL,
  "reference" TEXT,
  "titre" TEXT NOT NULL,
  "typeTexte" TEXT,
  "domainId" TEXT,
  "sousDomaine" TEXT,
  "pays" TEXT,
  "autoriteEmettrice" TEXT,
  "datePublication" TIMESTAMP(3),
  "dateEntreeVigueur" TIMESTAMP(3),
  "dateDerniereModification" TIMESTAMP(3),
  "dateAbrogation" TIMESTAMP(3),
  "version" TEXT,
  "statut" TEXT NOT NULL DEFAULT 'EN_VIGUEUR',
  "sourceOfficielle" TEXT,
  "lienSource" TEXT,
  "resume" TEXT,
  "objet" TEXT,
  "articlesApplicables" TEXT,
  "entreprisesConcernees" TEXT,
  "sitesConcernes" TEXT,
  "activitesConcernees" TEXT,
  "derniereVerificationSource" TIMESTAMP(3),
  "verifieParId" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "RegulatoryText_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "RegulatoryText_code_key" ON "RegulatoryText"("code");

CREATE TABLE "RegulatoryRequirement" (
  "id" TEXT NOT NULL,
  "code" TEXT NOT NULL,
  "textId" TEXT NOT NULL,
  "libelle" TEXT NOT NULL,
  "domainId" TEXT,
  "siteId" TEXT,
  "workUnitId" TEXT,
  "preuveAttendue" TEXT,
  "responsableId" TEXT,
  "frequenceEvaluationMois" INTEGER,
  "dateDerniereEvaluation" TIMESTAMP(3),
  "dateProchaineEvaluation" TIMESTAMP(3),
  "criticite" TEXT,
  "applicabilite" TEXT NOT NULL DEFAULT 'A_ANALYSER',
  "justificatifApplicabilite" TEXT,
  "statutConformite" TEXT,
  "statutFile" TEXT NOT NULL DEFAULT 'NOUVEAU',
  "commentaire" TEXT,
  "archivedAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "RegulatoryRequirement_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "RegulatoryRequirement_code_key" ON "RegulatoryRequirement"("code");

CREATE TABLE "RegulatoryEvaluation" (
  "id" TEXT NOT NULL,
  "requirementId" TEXT NOT NULL,
  "statut" TEXT NOT NULL,
  "constat" TEXT,
  "preuveExaminee" TEXT,
  "observation" TEXT,
  "personneInterrogee" TEXT,
  "dateControle" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "evaluateurId" TEXT,
  "criticite" TEXT,
  "commentaire" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "RegulatoryEvaluation_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "RegulatoryEvidence" (
  "id" TEXT NOT NULL,
  "requirementId" TEXT NOT NULL,
  "type" TEXT,
  "documentId" TEXT,
  "nom" TEXT,
  "dateEmission" TIMESTAMP(3),
  "dateExpiration" TIMESTAMP(3),
  "responsableId" TEXT,
  "statut" TEXT NOT NULL DEFAULT 'VALIDE',
  "commentaire" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "RegulatoryEvidence_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "RegulatoryRequirementRisk" (
  "id" TEXT NOT NULL,
  "requirementId" TEXT NOT NULL,
  "riskId" TEXT NOT NULL,
  "note" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "RegulatoryRequirementRisk_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "RegulatoryRequirementRisk_requirementId_riskId_key" ON "RegulatoryRequirementRisk"("requirementId", "riskId");

CREATE TABLE "RegulatoryRequirementDocument" (
  "id" TEXT NOT NULL,
  "requirementId" TEXT NOT NULL,
  "documentId" TEXT NOT NULL,
  "type" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "RegulatoryRequirementDocument_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "RegulatoryRequirementDocument_requirementId_documentId_key" ON "RegulatoryRequirementDocument"("requirementId", "documentId");

-- Colonnes de liaison (additif, nullable — aucune donnée existante affectée)
ALTER TABLE "NonConformity" ADD COLUMN "regulatoryRequirementId" TEXT;
ALTER TABLE "Action" ADD COLUMN "regulatoryRequirementId" TEXT;

-- Clés étrangères
ALTER TABLE "RegulatoryText" ADD CONSTRAINT "RegulatoryText_domainId_fkey" FOREIGN KEY ("domainId") REFERENCES "RegulatoryDomain"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "RegulatoryText" ADD CONSTRAINT "RegulatoryText_verifieParId_fkey" FOREIGN KEY ("verifieParId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "RegulatoryRequirement" ADD CONSTRAINT "RegulatoryRequirement_textId_fkey" FOREIGN KEY ("textId") REFERENCES "RegulatoryText"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "RegulatoryRequirement" ADD CONSTRAINT "RegulatoryRequirement_domainId_fkey" FOREIGN KEY ("domainId") REFERENCES "RegulatoryDomain"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "RegulatoryRequirement" ADD CONSTRAINT "RegulatoryRequirement_siteId_fkey" FOREIGN KEY ("siteId") REFERENCES "Site"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "RegulatoryRequirement" ADD CONSTRAINT "RegulatoryRequirement_workUnitId_fkey" FOREIGN KEY ("workUnitId") REFERENCES "WorkUnit"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "RegulatoryRequirement" ADD CONSTRAINT "RegulatoryRequirement_responsableId_fkey" FOREIGN KEY ("responsableId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "RegulatoryEvaluation" ADD CONSTRAINT "RegulatoryEvaluation_requirementId_fkey" FOREIGN KEY ("requirementId") REFERENCES "RegulatoryRequirement"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "RegulatoryEvaluation" ADD CONSTRAINT "RegulatoryEvaluation_evaluateurId_fkey" FOREIGN KEY ("evaluateurId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "RegulatoryEvidence" ADD CONSTRAINT "RegulatoryEvidence_requirementId_fkey" FOREIGN KEY ("requirementId") REFERENCES "RegulatoryRequirement"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "RegulatoryEvidence" ADD CONSTRAINT "RegulatoryEvidence_documentId_fkey" FOREIGN KEY ("documentId") REFERENCES "Document"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "RegulatoryEvidence" ADD CONSTRAINT "RegulatoryEvidence_responsableId_fkey" FOREIGN KEY ("responsableId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "RegulatoryRequirementRisk" ADD CONSTRAINT "RegulatoryRequirementRisk_requirementId_fkey" FOREIGN KEY ("requirementId") REFERENCES "RegulatoryRequirement"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "RegulatoryRequirementRisk" ADD CONSTRAINT "RegulatoryRequirementRisk_riskId_fkey" FOREIGN KEY ("riskId") REFERENCES "Risk"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "RegulatoryRequirementDocument" ADD CONSTRAINT "RegulatoryRequirementDocument_requirementId_fkey" FOREIGN KEY ("requirementId") REFERENCES "RegulatoryRequirement"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "RegulatoryRequirementDocument" ADD CONSTRAINT "RegulatoryRequirementDocument_documentId_fkey" FOREIGN KEY ("documentId") REFERENCES "Document"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "NonConformity" ADD CONSTRAINT "NonConformity_regulatoryRequirementId_fkey" FOREIGN KEY ("regulatoryRequirementId") REFERENCES "RegulatoryRequirement"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "Action" ADD CONSTRAINT "Action_regulatoryRequirementId_fkey" FOREIGN KEY ("regulatoryRequirementId") REFERENCES "RegulatoryRequirement"("id") ON DELETE SET NULL ON UPDATE CASCADE;
