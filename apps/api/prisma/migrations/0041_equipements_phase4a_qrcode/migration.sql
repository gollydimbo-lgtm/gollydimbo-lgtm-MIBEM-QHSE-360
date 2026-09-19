-- Phase 4A : QR code équipement
ALTER TABLE "Equipment" ADD COLUMN "qrToken" TEXT;
CREATE UNIQUE INDEX "Equipment_qrToken_key" ON "Equipment"("qrToken");
