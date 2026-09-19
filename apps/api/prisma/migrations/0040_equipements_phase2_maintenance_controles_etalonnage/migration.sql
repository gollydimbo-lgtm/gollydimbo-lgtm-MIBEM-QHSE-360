-- AlterTable
ALTER TABLE "Equipment" ALTER COLUMN "updatedAt" DROP DEFAULT;

-- AlterTable
ALTER TABLE "EquipmentSettings" ALTER COLUMN "updatedAt" DROP DEFAULT;

-- CreateTable
CREATE TABLE "EquipmentMaintenancePlan" (
    "id" TEXT NOT NULL,
    "equipmentId" TEXT NOT NULL,
    "designation" TEXT NOT NULL,
    "frequenceType" TEXT NOT NULL DEFAULT 'CALENDAIRE',
    "frequenceValeur" INTEGER NOT NULL,
    "uniteFrequence" TEXT,
    "dateDerniere" TIMESTAMP(3),
    "dateProchaine" TIMESTAMP(3),
    "responsableId" TEXT,
    "prestataire" TEXT,
    "actif" BOOLEAN NOT NULL DEFAULT true,
    "description" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "EquipmentMaintenancePlan_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "EquipmentMaintenanceRecord" (
    "id" TEXT NOT NULL,
    "equipmentId" TEXT NOT NULL,
    "planId" TEXT,
    "type" TEXT NOT NULL DEFAULT 'CORRECTIVE',
    "statut" TEXT NOT NULL DEFAULT 'PLANIFIEE',
    "datePanne" TIMESTAMP(3),
    "dateDebut" TIMESTAMP(3),
    "dateFin" TIMESTAMP(3),
    "dureeHeures" DOUBLE PRECISION,
    "responsableId" TEXT,
    "prestataire" TEXT,
    "description" TEXT,
    "causePanne" TEXT,
    "piecesRemplacees" TEXT,
    "cout" DOUBLE PRECISION,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "EquipmentMaintenanceRecord_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "EquipmentControl" (
    "id" TEXT NOT NULL,
    "equipmentId" TEXT NOT NULL,
    "designation" TEXT NOT NULL,
    "organisme" TEXT,
    "referenceReglementaire" TEXT,
    "dateControle" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "dateProchainControle" TIMESTAMP(3),
    "statut" TEXT NOT NULL DEFAULT 'CONFORME',
    "observations" TEXT,
    "controleurId" TEXT,
    "cout" DOUBLE PRECISION,
    "nonConformityId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "EquipmentControl_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "EquipmentCalibration" (
    "id" TEXT NOT NULL,
    "equipmentId" TEXT NOT NULL,
    "dateEtalonnage" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "dateProchaineEtalonnage" TIMESTAMP(3),
    "organismeEtalonneur" TEXT,
    "certificatNumero" TEXT,
    "resultat" TEXT NOT NULL DEFAULT 'CONFORME',
    "incertitude" TEXT,
    "nePasUtiliser" BOOLEAN NOT NULL DEFAULT false,
    "nonConformityId" TEXT,
    "cout" DOUBLE PRECISION,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "EquipmentCalibration_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "EquipmentInspection" (
    "id" TEXT NOT NULL,
    "equipmentId" TEXT NOT NULL,
    "type" TEXT NOT NULL DEFAULT 'PRE_USE',
    "date" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "inspecteurId" TEXT,
    "statutGlobal" TEXT NOT NULL DEFAULT 'CONFORME',
    "items" JSONB,
    "commentaire" TEXT,
    "signature" TEXT,
    "localisation" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "EquipmentInspection_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "EquipmentConsignation" (
    "id" TEXT NOT NULL,
    "equipmentId" TEXT NOT NULL,
    "dateDebut" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "dateFinPrevue" TIMESTAMP(3),
    "dateFinReelle" TIMESTAMP(3),
    "motif" TEXT NOT NULL,
    "responsableId" TEXT,
    "risqueAssocie" TEXT,
    "mesureControle" TEXT,
    "statut" TEXT NOT NULL DEFAULT 'EN_COURS',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "EquipmentConsignation_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "EquipmentMaintenancePlan" ADD CONSTRAINT "EquipmentMaintenancePlan_equipmentId_fkey" FOREIGN KEY ("equipmentId") REFERENCES "Equipment"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "EquipmentMaintenancePlan" ADD CONSTRAINT "EquipmentMaintenancePlan_responsableId_fkey" FOREIGN KEY ("responsableId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "EquipmentMaintenanceRecord" ADD CONSTRAINT "EquipmentMaintenanceRecord_equipmentId_fkey" FOREIGN KEY ("equipmentId") REFERENCES "Equipment"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "EquipmentMaintenanceRecord" ADD CONSTRAINT "EquipmentMaintenanceRecord_planId_fkey" FOREIGN KEY ("planId") REFERENCES "EquipmentMaintenancePlan"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "EquipmentMaintenanceRecord" ADD CONSTRAINT "EquipmentMaintenanceRecord_responsableId_fkey" FOREIGN KEY ("responsableId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "EquipmentControl" ADD CONSTRAINT "EquipmentControl_equipmentId_fkey" FOREIGN KEY ("equipmentId") REFERENCES "Equipment"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "EquipmentControl" ADD CONSTRAINT "EquipmentControl_controleurId_fkey" FOREIGN KEY ("controleurId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "EquipmentControl" ADD CONSTRAINT "EquipmentControl_nonConformityId_fkey" FOREIGN KEY ("nonConformityId") REFERENCES "NonConformity"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "EquipmentCalibration" ADD CONSTRAINT "EquipmentCalibration_equipmentId_fkey" FOREIGN KEY ("equipmentId") REFERENCES "Equipment"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "EquipmentCalibration" ADD CONSTRAINT "EquipmentCalibration_nonConformityId_fkey" FOREIGN KEY ("nonConformityId") REFERENCES "NonConformity"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "EquipmentInspection" ADD CONSTRAINT "EquipmentInspection_equipmentId_fkey" FOREIGN KEY ("equipmentId") REFERENCES "Equipment"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "EquipmentInspection" ADD CONSTRAINT "EquipmentInspection_inspecteurId_fkey" FOREIGN KEY ("inspecteurId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "EquipmentConsignation" ADD CONSTRAINT "EquipmentConsignation_equipmentId_fkey" FOREIGN KEY ("equipmentId") REFERENCES "Equipment"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "EquipmentConsignation" ADD CONSTRAINT "EquipmentConsignation_responsableId_fkey" FOREIGN KEY ("responsableId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

