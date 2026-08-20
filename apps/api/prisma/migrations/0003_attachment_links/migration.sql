CREATE TABLE "AttachmentLink" (
 "id" TEXT PRIMARY KEY,
 "ownerType" "AttachmentOwnerType" NOT NULL,
 "ownerId" TEXT NOT NULL,
 "attachmentId" TEXT NOT NULL,
 "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
 CONSTRAINT "AttachmentLink_attachmentId_fkey" FOREIGN KEY ("attachmentId") REFERENCES "Attachment"("id") ON DELETE CASCADE
);
CREATE UNIQUE INDEX "AttachmentLink_ownerType_ownerId_attachmentId_key" ON "AttachmentLink"("ownerType","ownerId","attachmentId");
CREATE INDEX "AttachmentLink_ownerType_ownerId_idx" ON "AttachmentLink"("ownerType","ownerId");
