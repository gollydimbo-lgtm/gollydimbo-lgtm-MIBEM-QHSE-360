-- Rapports QHSE — Phase 4 : lien vers la fiche GED creee lors de
-- l'archivage automatique (uniquement apres generation reelle d'un PDF,
-- jamais une fiche documentaire sans fichier derriere).

ALTER TABLE "RapportQhse" ADD COLUMN "documentId" TEXT;
ALTER TABLE "RapportQhse" ADD CONSTRAINT "RapportQhse_documentId_fkey" FOREIGN KEY ("documentId") REFERENCES "Document"("id") ON DELETE SET NULL ON UPDATE CASCADE;
