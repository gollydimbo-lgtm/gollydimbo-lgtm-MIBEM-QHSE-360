-- AlterTable
ALTER TABLE "Training" ADD COLUMN     "evaluationType" TEXT,
ADD COLUMN     "delaiEvaluationEfficaciteJours" INTEGER;

-- AlterTable
ALTER TABLE "TrainingParticipant" ADD COLUMN     "employeeSignature" TEXT,
ADD COLUMN     "responsableSignature" TEXT;

-- CreateTable
CREATE TABLE "TrainingEfficaciteEvaluation" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "trainingId" TEXT NOT NULL,
    "employeeId" TEXT,
    "delaiJours" INTEGER NOT NULL,
    "dateEvaluation" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "niveauEfficacite" TEXT NOT NULL DEFAULT 'NON_EVALUEE',
    "applicationConnaissances" BOOLEAN,
    "respectProcedures" BOOLEAN,
    "changementComportement" BOOLEAN,
    "autonomie" BOOLEAN,
    "reductionErreurs" BOOLEAN,
    "reductionNc" BOOLEAN,
    "reductionIncidents" BOOLEAN,
    "commentaire" TEXT,
    "evaluateurId" TEXT,
    "besoinGenereId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "TrainingEfficaciteEvaluation_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "TrainingEfficaciteEvaluation_code_key" ON "TrainingEfficaciteEvaluation"("code");

-- AddForeignKey
ALTER TABLE "TrainingEfficaciteEvaluation" ADD CONSTRAINT "TrainingEfficaciteEvaluation_trainingId_fkey" FOREIGN KEY ("trainingId") REFERENCES "Training"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TrainingEfficaciteEvaluation" ADD CONSTRAINT "TrainingEfficaciteEvaluation_employeeId_fkey" FOREIGN KEY ("employeeId") REFERENCES "Employee"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TrainingEfficaciteEvaluation" ADD CONSTRAINT "TrainingEfficaciteEvaluation_evaluateurId_fkey" FOREIGN KEY ("evaluateurId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TrainingEfficaciteEvaluation" ADD CONSTRAINT "TrainingEfficaciteEvaluation_besoinGenereId_fkey" FOREIGN KEY ("besoinGenereId") REFERENCES "BesoinFormation"("id") ON DELETE SET NULL ON UPDATE CASCADE;
