-- CreateTable
CREATE TABLE "Notification" (
    "id" TEXT NOT NULL,
    "sourceKey" TEXT NOT NULL,
    "module" TEXT NOT NULL,
    "niveau" TEXT NOT NULL DEFAULT 'INFO',
    "titre" TEXT NOT NULL,
    "detail" TEXT,
    "dueDate" TIMESTAMP(3),
    "lienModule" TEXT,
    "lienEntityId" TEXT,
    "lu" BOOLEAN NOT NULL DEFAULT false,
    "luLe" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Notification_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Notification_sourceKey_key" ON "Notification"("sourceKey");
