-- CreateIndex
CREATE INDEX "SafetyEvent_statut_idx" ON "SafetyEvent"("statut");

-- CreateIndex
CREATE INDEX "SafetyEvent_occurredAt_idx" ON "SafetyEvent"("occurredAt");

-- CreateIndex
CREATE INDEX "QhseAudit_status_idx" ON "QhseAudit"("status");

-- CreateIndex
CREATE INDEX "QhseAudit_auditDate_idx" ON "QhseAudit"("auditDate");

-- CreateIndex
CREATE INDEX "Equipment_status_idx" ON "Equipment"("status");

-- CreateIndex
CREATE INDEX "Equipment_nextInspectionAt_idx" ON "Equipment"("nextInspectionAt");

-- CreateIndex
CREATE INDEX "Reclamation_statut_idx" ON "Reclamation"("statut");

-- CreateIndex
CREATE INDEX "Reclamation_date_idx" ON "Reclamation"("date");

-- CreateIndex
CREATE INDEX "Fournisseur_statut_idx" ON "Fournisseur"("statut");

-- CreateIndex
CREATE INDEX "Fournisseur_createdAt_idx" ON "Fournisseur"("createdAt");

-- CreateIndex
CREATE INDEX "RegulatoryRequirement_dateProchaineEvaluation_idx" ON "RegulatoryRequirement"("dateProchaineEvaluation");
