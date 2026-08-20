CREATE TYPE "QualityControlStatus" AS ENUM ('DRAFT','IN_PROGRESS','SUBMITTED','COMPLIANT','NON_COMPLIANT','CANCELLED');
CREATE TYPE "ControlValueType" AS ENUM ('BOOLEAN','NUMERIC','TEXT','CHOICE','PHOTO');
CREATE TYPE "SignatureType" AS ENUM ('CONTROLLER','RESPONSIBLE','VALIDATOR');
CREATE TYPE "AttachmentOwnerType" AS ENUM ('QUALITY_CONTROL','NON_CONFORMITY','ACTION','SAFETY_EVENT','RISK','AUDIT','EPI');
CREATE TYPE "QualityShift" AS ENUM ('MORNING','AFTERNOON','NIGHT');

CREATE TABLE "Site" (
 "id" TEXT PRIMARY KEY,"code" TEXT NOT NULL UNIQUE,"name" TEXT NOT NULL,"location" TEXT,"active" BOOLEAN NOT NULL DEFAULT TRUE,"createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE "ProductionLine" (
 "id" TEXT PRIMARY KEY,"siteId" TEXT NOT NULL,"code" TEXT NOT NULL UNIQUE,"name" TEXT NOT NULL,"area" TEXT,"active" BOOLEAN NOT NULL DEFAULT TRUE
);
CREATE TABLE "Machine" (
 "id" TEXT PRIMARY KEY,"lineId" TEXT NOT NULL,"code" TEXT NOT NULL UNIQUE,"name" TEXT NOT NULL,"category" TEXT,"active" BOOLEAN NOT NULL DEFAULT TRUE
);
CREATE TABLE "Product" (
 "id" TEXT PRIMARY KEY,"code" TEXT NOT NULL UNIQUE,"name" TEXT NOT NULL,"category" TEXT,"active" BOOLEAN NOT NULL DEFAULT TRUE
);
CREATE TABLE "ProductFormat" (
 "id" TEXT PRIMARY KEY,"productId" TEXT NOT NULL,"code" TEXT NOT NULL,"label" TEXT NOT NULL,"volumeMl" INTEGER,UNIQUE("productId","code")
);
CREATE TABLE "Shift" (
 "id" TEXT PRIMARY KEY,"code" TEXT NOT NULL UNIQUE,"name" TEXT NOT NULL,"startTime" TEXT,"endTime" TEXT,"active" BOOLEAN NOT NULL DEFAULT TRUE
);

ALTER TABLE "QualityControl" ALTER COLUMN "status" DROP DEFAULT;
ALTER TABLE "QualityControl" ALTER COLUMN "status" TYPE "QualityControlStatus" USING "status"::text::"QualityControlStatus";
ALTER TABLE "QualityControl" ALTER COLUMN "status" SET DEFAULT 'DRAFT';
ALTER TABLE "QualityControl" ADD COLUMN "siteId" TEXT;
ALTER TABLE "QualityControl" ADD COLUMN "lineId" TEXT;
ALTER TABLE "QualityControl" ADD COLUMN "machineId" TEXT;
ALTER TABLE "QualityControl" ADD COLUMN "productId" TEXT;
ALTER TABLE "QualityControl" ADD COLUMN "formatId" TEXT;
ALTER TABLE "QualityControl" ADD COLUMN "shiftId" TEXT;
ALTER TABLE "QualityControl" ADD COLUMN "latitude" DOUBLE PRECISION;
ALTER TABLE "QualityControl" ADD COLUMN "longitude" DOUBLE PRECISION;
ALTER TABLE "QualityControl" ADD COLUMN "gpsAccuracy" DOUBLE PRECISION;
ALTER TABLE "QualityControl" ADD COLUMN "startedAt" TIMESTAMP(3);
ALTER TABLE "QualityControl" ADD COLUMN "submittedAt" TIMESTAMP(3);

ALTER TABLE "ControlPoint" ALTER COLUMN "type" TYPE "ControlValueType" USING "type"::text::"ControlValueType";
ALTER TABLE "ControlPoint" ADD COLUMN "unit" TEXT;
ALTER TABLE "ControlResult" ADD COLUMN "photoRequired" BOOLEAN NOT NULL DEFAULT FALSE;

CREATE TABLE "QualityControlAttachment" (
 "id" TEXT PRIMARY KEY,"controlId" TEXT NOT NULL,"attachmentId" TEXT NOT NULL,UNIQUE("controlId","attachmentId")
);
CREATE TABLE "QualityControlSignature" (
 "id" TEXT PRIMARY KEY,"controlId" TEXT NOT NULL,"userId" TEXT,"type" "SignatureType" NOT NULL,"signatureData" TEXT NOT NULL,"signedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE "ProductionLine" ADD CONSTRAINT "ProductionLine_siteId_fkey" FOREIGN KEY("siteId") REFERENCES "Site"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "Machine" ADD CONSTRAINT "Machine_lineId_fkey" FOREIGN KEY("lineId") REFERENCES "ProductionLine"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "ProductFormat" ADD CONSTRAINT "ProductFormat_productId_fkey" FOREIGN KEY("productId") REFERENCES "Product"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "QualityControl" ADD CONSTRAINT "QualityControl_siteId_fkey" FOREIGN KEY("siteId") REFERENCES "Site"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "QualityControl" ADD CONSTRAINT "QualityControl_lineId_fkey" FOREIGN KEY("lineId") REFERENCES "ProductionLine"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "QualityControl" ADD CONSTRAINT "QualityControl_machineId_fkey" FOREIGN KEY("machineId") REFERENCES "Machine"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "QualityControl" ADD CONSTRAINT "QualityControl_productId_fkey" FOREIGN KEY("productId") REFERENCES "Product"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "QualityControl" ADD CONSTRAINT "QualityControl_formatId_fkey" FOREIGN KEY("formatId") REFERENCES "ProductFormat"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "QualityControl" ADD CONSTRAINT "QualityControl_shiftId_fkey" FOREIGN KEY("shiftId") REFERENCES "Shift"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "QualityControlAttachment" ADD CONSTRAINT "QualityControlAttachment_controlId_fkey" FOREIGN KEY("controlId") REFERENCES "QualityControl"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "QualityControlAttachment" ADD CONSTRAINT "QualityControlAttachment_attachmentId_fkey" FOREIGN KEY("attachmentId") REFERENCES "Attachment"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "QualityControlSignature" ADD CONSTRAINT "QualityControlSignature_controlId_fkey" FOREIGN KEY("controlId") REFERENCES "QualityControl"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "QualityControlSignature" ADD CONSTRAINT "QualityControlSignature_userId_fkey" FOREIGN KEY("userId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE INDEX "ProductionLine_siteId_idx" ON "ProductionLine"("siteId");
CREATE INDEX "QualityControl_lineId_controlDate_idx" ON "QualityControl"("lineId","controlDate");
CREATE INDEX "QualityControl_productId_lotNumber_idx" ON "QualityControl"("productId","lotNumber");
CREATE INDEX "QualityControlAttachment_controlId_idx" ON "QualityControlAttachment"("controlId");
CREATE INDEX "QualityControlSignature_controlId_idx" ON "QualityControlSignature"("controlId");
