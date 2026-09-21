-- AlterTable
ALTER TABLE "Action" ADD COLUMN     "trainingId" TEXT;

-- AlterTable
ALTER TABLE "Training" ADD COLUMN     "budgetAlloue" DOUBLE PRECISION,
ADD COLUMN     "categoryId" TEXT,
ADD COLUMN     "competenceVisee" TEXT,
ADD COLUMN     "coutPrevu" DOUBLE PRECISION,
ADD COLUMN     "coutReel" DOUBLE PRECISION,
ADD COLUMN     "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
ADD COLUMN     "domaine" TEXT,
ADD COLUMN     "interneExterne" TEXT NOT NULL DEFAULT 'INTERNE',
ADD COLUMN     "motifBesoin" TEXT,
ADD COLUMN     "obligatoire" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "objectif" TEXT,
ADD COLUMN     "organisme" TEXT,
ADD COLUMN     "periodiciteMois" INTEGER,
ADD COLUMN     "priorite" TEXT,
ADD COLUMN     "publicCible" TEXT,
ADD COLUMN     "recyclageNecessaire" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "referenceReglementaire" TEXT,
ADD COLUMN     "service" TEXT,
ADD COLUMN     "type" TEXT NOT NULL DEFAULT 'FORMATION',
ADD COLUMN     "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

-- CreateTable
CREATE TABLE "TrainingCategory" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "label" TEXT NOT NULL,
    "groupe" TEXT,
    "order" INTEGER NOT NULL DEFAULT 0,
    "active" BOOLEAN NOT NULL DEFAULT true,

    CONSTRAINT "TrainingCategory_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TrainingParticipant" (
    "id" TEXT NOT NULL,
    "trainingId" TEXT NOT NULL,
    "employeeId" TEXT NOT NULL,
    "present" BOOLEAN,
    "score" DOUBLE PRECISION,
    "seuilReussite" DOUBLE PRECISION,
    "resultat" TEXT,
    "commentaire" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "TrainingParticipant_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "HabilitationCategory" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "label" TEXT NOT NULL,
    "dureeValiditeMois" INTEGER,
    "order" INTEGER NOT NULL DEFAULT 0,
    "active" BOOLEAN NOT NULL DEFAULT true,

    CONSTRAINT "HabilitationCategory_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Habilitation" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "employeeId" TEXT NOT NULL,
    "categoryId" TEXT,
    "intitule" TEXT NOT NULL,
    "organisme" TEXT,
    "numeroDocument" TEXT,
    "dateObtention" TIMESTAMP(3),
    "dateExpiration" TIMESTAMP(3),
    "statut" TEXT NOT NULL DEFAULT 'VALIDE',
    "trainingId" TEXT,
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Habilitation_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TrainingSettings" (
    "id" TEXT NOT NULL,
    "alerteJ90" BOOLEAN NOT NULL DEFAULT true,
    "alerteJ60" BOOLEAN NOT NULL DEFAULT true,
    "alerteJ30" BOOLEAN NOT NULL DEFAULT true,
    "alerteJ15" BOOLEAN NOT NULL DEFAULT false,
    "ponderationScoreGlobal" DOUBLE PRECISION NOT NULL DEFAULT 10,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "TrainingSettings_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "TrainingCategory_code_key" ON "TrainingCategory"("code");

-- CreateIndex
CREATE UNIQUE INDEX "TrainingParticipant_trainingId_employeeId_key" ON "TrainingParticipant"("trainingId", "employeeId");

-- CreateIndex
CREATE UNIQUE INDEX "HabilitationCategory_code_key" ON "HabilitationCategory"("code");

-- CreateIndex
CREATE UNIQUE INDEX "Habilitation_code_key" ON "Habilitation"("code");

-- AddForeignKey
ALTER TABLE "Action" ADD CONSTRAINT "Action_trainingId_fkey" FOREIGN KEY ("trainingId") REFERENCES "Training"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Training" ADD CONSTRAINT "Training_categoryId_fkey" FOREIGN KEY ("categoryId") REFERENCES "TrainingCategory"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TrainingParticipant" ADD CONSTRAINT "TrainingParticipant_trainingId_fkey" FOREIGN KEY ("trainingId") REFERENCES "Training"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TrainingParticipant" ADD CONSTRAINT "TrainingParticipant_employeeId_fkey" FOREIGN KEY ("employeeId") REFERENCES "Employee"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Habilitation" ADD CONSTRAINT "Habilitation_employeeId_fkey" FOREIGN KEY ("employeeId") REFERENCES "Employee"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Habilitation" ADD CONSTRAINT "Habilitation_categoryId_fkey" FOREIGN KEY ("categoryId") REFERENCES "HabilitationCategory"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Habilitation" ADD CONSTRAINT "Habilitation_trainingId_fkey" FOREIGN KEY ("trainingId") REFERENCES "Training"("id") ON DELETE SET NULL ON UPDATE CASCADE;
