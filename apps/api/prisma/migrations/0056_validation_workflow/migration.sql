-- Workflow de validation multi-niveaux (audit finding #23) : NonConformity, Action, Risk.
-- Non régressif : validationStatus démarre à 'APPROUVEE' pour tous les enregistrements
-- existants, comme si le workflow n'existait pas encore.

ALTER TABLE "NonConformity" ADD COLUMN "validationStatus" TEXT NOT NULL DEFAULT 'APPROUVEE';
ALTER TABLE "NonConformity" ADD COLUMN "validationDemandeeParId" TEXT;
ALTER TABLE "NonConformity" ADD COLUMN "validationDemandeeLe" TIMESTAMP(3);
ALTER TABLE "NonConformity" ADD COLUMN "valideParId" TEXT;
ALTER TABLE "NonConformity" ADD COLUMN "valideLe" TIMESTAMP(3);
ALTER TABLE "NonConformity" ADD COLUMN "commentaireValidation" TEXT;
ALTER TABLE "NonConformity" ADD CONSTRAINT "NonConformity_validationDemandeeParId_fkey" FOREIGN KEY ("validationDemandeeParId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "NonConformity" ADD CONSTRAINT "NonConformity_valideParId_fkey" FOREIGN KEY ("valideParId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "Action" ADD COLUMN "validationStatus" TEXT NOT NULL DEFAULT 'APPROUVEE';
ALTER TABLE "Action" ADD COLUMN "validationDemandeeParId" TEXT;
ALTER TABLE "Action" ADD COLUMN "validationDemandeeLe" TIMESTAMP(3);
ALTER TABLE "Action" ADD COLUMN "valideParId" TEXT;
ALTER TABLE "Action" ADD COLUMN "valideLe" TIMESTAMP(3);
ALTER TABLE "Action" ADD COLUMN "commentaireValidation" TEXT;
ALTER TABLE "Action" ADD CONSTRAINT "Action_validationDemandeeParId_fkey" FOREIGN KEY ("validationDemandeeParId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "Action" ADD CONSTRAINT "Action_valideParId_fkey" FOREIGN KEY ("valideParId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "Risk" ADD COLUMN "validationStatus" TEXT NOT NULL DEFAULT 'APPROUVEE';
ALTER TABLE "Risk" ADD COLUMN "validationDemandeeParId" TEXT;
ALTER TABLE "Risk" ADD COLUMN "validationDemandeeLe" TIMESTAMP(3);
ALTER TABLE "Risk" ADD COLUMN "valideParId" TEXT;
ALTER TABLE "Risk" ADD COLUMN "valideLe" TIMESTAMP(3);
ALTER TABLE "Risk" ADD COLUMN "commentaireValidation" TEXT;
ALTER TABLE "Risk" ADD CONSTRAINT "Risk_validationDemandeeParId_fkey" FOREIGN KEY ("validationDemandeeParId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "Risk" ADD CONSTRAINT "Risk_valideParId_fkey" FOREIGN KEY ("valideParId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
