-- CreateTable
CREATE TABLE "CompetenceNiveau" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "label" TEXT NOT NULL,
    "ordre" INTEGER NOT NULL,
    "active" BOOLEAN NOT NULL DEFAULT true,

    CONSTRAINT "CompetenceNiveau_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Competence" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "label" TEXT NOT NULL,
    "domaine" TEXT,
    "order" INTEGER NOT NULL DEFAULT 0,
    "active" BOOLEAN NOT NULL DEFAULT true,

    CONSTRAINT "Competence_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "EmployeeCompetence" (
    "id" TEXT NOT NULL,
    "employeeId" TEXT NOT NULL,
    "competenceId" TEXT NOT NULL,
    "poste" TEXT,
    "niveauRequisId" TEXT,
    "niveauActuelId" TEXT,
    "dateEvaluation" TIMESTAMP(3),
    "formationAssocieeId" TEXT,
    "habilitationAssocieeId" TEXT,
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "EmployeeCompetence_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "BesoinFormation" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "sourceModule" TEXT NOT NULL,
    "sourceKey" TEXT NOT NULL,
    "sourceEntityId" TEXT,
    "titre" TEXT NOT NULL,
    "description" TEXT,
    "competenceVisee" TEXT,
    "employeeId" TEXT,
    "posteConcerne" TEXT,
    "priorite" TEXT NOT NULL DEFAULT 'MOYENNE',
    "statut" TEXT NOT NULL DEFAULT 'PROPOSE',
    "motif" TEXT,
    "trainingId" TEXT,
    "traiteParId" TEXT,
    "traiteLe" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "BesoinFormation_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "CompetenceNiveau_code_key" ON "CompetenceNiveau"("code");

-- CreateIndex
CREATE UNIQUE INDEX "Competence_code_key" ON "Competence"("code");

-- CreateIndex
CREATE UNIQUE INDEX "EmployeeCompetence_employeeId_competenceId_key" ON "EmployeeCompetence"("employeeId", "competenceId");

-- CreateIndex
CREATE UNIQUE INDEX "BesoinFormation_code_key" ON "BesoinFormation"("code");

-- CreateIndex
CREATE UNIQUE INDEX "BesoinFormation_sourceKey_key" ON "BesoinFormation"("sourceKey");

-- AddForeignKey
ALTER TABLE "EmployeeCompetence" ADD CONSTRAINT "EmployeeCompetence_employeeId_fkey" FOREIGN KEY ("employeeId") REFERENCES "Employee"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "EmployeeCompetence" ADD CONSTRAINT "EmployeeCompetence_competenceId_fkey" FOREIGN KEY ("competenceId") REFERENCES "Competence"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "EmployeeCompetence" ADD CONSTRAINT "EmployeeCompetence_niveauRequisId_fkey" FOREIGN KEY ("niveauRequisId") REFERENCES "CompetenceNiveau"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "EmployeeCompetence" ADD CONSTRAINT "EmployeeCompetence_niveauActuelId_fkey" FOREIGN KEY ("niveauActuelId") REFERENCES "CompetenceNiveau"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "EmployeeCompetence" ADD CONSTRAINT "EmployeeCompetence_formationAssocieeId_fkey" FOREIGN KEY ("formationAssocieeId") REFERENCES "Training"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "EmployeeCompetence" ADD CONSTRAINT "EmployeeCompetence_habilitationAssocieeId_fkey" FOREIGN KEY ("habilitationAssocieeId") REFERENCES "Habilitation"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BesoinFormation" ADD CONSTRAINT "BesoinFormation_employeeId_fkey" FOREIGN KEY ("employeeId") REFERENCES "Employee"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BesoinFormation" ADD CONSTRAINT "BesoinFormation_trainingId_fkey" FOREIGN KEY ("trainingId") REFERENCES "Training"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BesoinFormation" ADD CONSTRAINT "BesoinFormation_traiteParId_fkey" FOREIGN KEY ("traiteParId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- Seed des niveaux de competence par defaut (modifiables ensuite par
-- l'administrateur) — evite une matrice inutilisable "a vide" au premier
-- lancement.
INSERT INTO "CompetenceNiveau" ("id","code","label","ordre","active") VALUES
  ('cniv0001','NON_ACQUIS','Non acquis',0,true),
  ('cniv0002','DEBUTANT','Débutant',1,true),
  ('cniv0003','EN_PROGRESSION','En progression',2,true),
  ('cniv0004','OPERATIONNEL','Opérationnel',3,true),
  ('cniv0005','MAITRISE','Maîtrisé',4,true),
  ('cniv0006','EXPERT','Expert',5,true);
