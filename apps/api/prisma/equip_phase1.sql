-- AlterTable
ALTER TABLE "Action" ADD COLUMN     "equipmentId" TEXT;

-- AlterTable
ALTER TABLE "Equipment" ADD COLUMN     "anneeFabrication" INTEGER,
ADD COLUMN     "archivedAt" TIMESTAMP(3),
ADD COLUMN     "batiment" TEXT,
ADD COLUMN     "categoryId" TEXT,
ADD COLUMN     "constructeur" TEXT,
ADD COLUMN     "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
ADD COLUMN     "criticiteEnvironnement" INTEGER,
ADD COLUMN     "criticiteNiveau" TEXT,
ADD COLUMN     "criticiteProduction" INTEGER,
ADD COLUMN     "criticiteQualite" INTEGER,
ADD COLUMN     "criticiteScore" INTEGER,
ADD COLUMN     "criticiteSecurite" INTEGER,
ADD COLUMN     "dateAcquisition" TIMESTAMP(3),
ADD COLUMN     "dateEtat" TIMESTAMP(3),
ADD COLUMN     "dateMiseEnService" TIMESTAMP(3),
ADD COLUMN     "dateRemiseEnServicePrevue" TIMESTAMP(3),
ADD COLUMN     "etat" TEXT NOT NULL DEFAULT 'ACTIF',
ADD COLUMN     "fournisseurId" TEXT,
ADD COLUMN     "justificatifEtat" TEXT,
ADD COLUMN     "marque" TEXT,
ADD COLUMN     "mesureMaitriseEtat" TEXT,
ADD COLUMN     "modele" TEXT,
ADD COLUMN     "motifEtat" TEXT,
ADD COLUMN     "numeroSerie" TEXT,
ADD COLUMN     "referenceFabricant" TEXT,
ADD COLUMN     "responsableEtatId" TEXT,
ADD COLUMN     "responsableId" TEXT,
ADD COLUMN     "risqueAssocieEtat" TEXT,
ADD COLUMN     "siteId" TEXT,
ADD COLUMN     "sousType" TEXT,
ADD COLUMN     "type" TEXT,
ADD COLUMN     "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
ADD COLUMN     "utilisateursAutorises" TEXT,
ADD COLUMN     "workUnitId" TEXT,
ADD COLUMN     "zone" TEXT;

-- AlterTable
ALTER TABLE "NonConformity" ADD COLUMN     "equipmentId" TEXT;

-- AlterTable
ALTER TABLE "Risk" ADD COLUMN     "equipmentId" TEXT;

-- AlterTable
ALTER TABLE "SafetyEvent" ADD COLUMN     "equipmentId" TEXT;

-- CreateTable
CREATE TABLE "EquipmentCategory" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "label" TEXT NOT NULL,
    "groupe" TEXT,
    "order" INTEGER NOT NULL DEFAULT 0,
    "active" BOOLEAN NOT NULL DEFAULT true,

    CONSTRAINT "EquipmentCategory_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "EquipmentSettings" (
    "id" TEXT NOT NULL,
    "seuilCriticiteModere" INTEGER NOT NULL DEFAULT 30,
    "seuilCriticiteEleve" INTEGER NOT NULL DEFAULT 60,
    "seuilCriticiteCritique" INTEGER NOT NULL DEFAULT 85,
    "alerteJ90" BOOLEAN NOT NULL DEFAULT true,
    "alerteJ60" BOOLEAN NOT NULL DEFAULT true,
    "alerteJ30" BOOLEAN NOT NULL DEFAULT true,
    "alerteJ7" BOOLEAN NOT NULL DEFAULT true,
    "ponderationScoreGlobal" DOUBLE PRECISION NOT NULL DEFAULT 10,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "EquipmentSettings_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "EquipmentCategory_code_key" ON "EquipmentCategory"("code");

-- AddForeignKey
ALTER TABLE "SafetyEvent" ADD CONSTRAINT "SafetyEvent_equipmentId_fkey" FOREIGN KEY ("equipmentId") REFERENCES "Equipment"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "NonConformity" ADD CONSTRAINT "NonConformity_equipmentId_fkey" FOREIGN KEY ("equipmentId") REFERENCES "Equipment"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Action" ADD CONSTRAINT "Action_equipmentId_fkey" FOREIGN KEY ("equipmentId") REFERENCES "Equipment"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Risk" ADD CONSTRAINT "Risk_equipmentId_fkey" FOREIGN KEY ("equipmentId") REFERENCES "Equipment"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Equipment" ADD CONSTRAINT "Equipment_categoryId_fkey" FOREIGN KEY ("categoryId") REFERENCES "EquipmentCategory"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Equipment" ADD CONSTRAINT "Equipment_siteId_fkey" FOREIGN KEY ("siteId") REFERENCES "Site"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Equipment" ADD CONSTRAINT "Equipment_workUnitId_fkey" FOREIGN KEY ("workUnitId") REFERENCES "WorkUnit"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Equipment" ADD CONSTRAINT "Equipment_fournisseurId_fkey" FOREIGN KEY ("fournisseurId") REFERENCES "Fournisseur"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Equipment" ADD CONSTRAINT "Equipment_responsableId_fkey" FOREIGN KEY ("responsableId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

