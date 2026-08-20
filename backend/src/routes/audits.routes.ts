import { Router } from "express";
import { prisma } from "../lib/prisma.js";
import { ref } from "../lib/ref.js";
import {
  auditStatusTransitionSchema,
  createAuditFindingSchema,
  createAuditSchema,
  submitAuditChecklistItemSchema,
} from "../validation/schemas.js";
import { ingestAuditFinding } from "../services/auditIngestion.js";

export const auditsRouter = Router();

auditsRouter.get("/", async (req, res) => {
  const { status, type, siteId } = req.query;
  const data = await prisma.audit.findMany({
    where: {
      status: typeof status === "string" ? (status as any) : undefined,
      type: typeof type === "string" ? (type as any) : undefined,
      siteId: typeof siteId === "string" ? siteId : undefined,
    },
    orderBy: { plannedDate: "desc" },
    include: { auditor: true, site: true, program: true, findings: true },
    take: 100,
  });
  res.json(data);
});

auditsRouter.get("/:id", async (req, res) => {
  const audit = await prisma.audit.findUnique({
    where: { id: req.params.id },
    include: {
      auditor: true,
      site: true,
      program: true,
      template: { include: { questions: { orderBy: { sequence: "asc" } } } },
      checklistItems: { include: { question: true } },
      findings: true,
      attachments: true,
    },
  });
  if (!audit) return res.status(404).json({ message: "Audit introuvable" });
  res.json(audit);
});

auditsRouter.post("/", async (req, res) => {
  const parsed = createAuditSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ message: "Payload invalide", errors: parsed.error.flatten() });
  }
  const audit = await prisma.audit.create({
    data: {
      reference: ref("AUD"),
      programId: parsed.data.programId,
      templateId: parsed.data.templateId,
      type: parsed.data.type,
      title: parsed.data.title,
      scope: parsed.data.scope,
      siteId: parsed.data.siteId,
      auditorId: req.user!.employeeId,
      plannedDate: new Date(parsed.data.plannedDate),
    },
  });
  res.status(201).json(audit);
});

auditsRouter.patch("/:id/status", async (req, res) => {
  const parsed = auditStatusTransitionSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ message: "Payload invalide", errors: parsed.error.flatten() });
  }
  const data: any = { status: parsed.data.toStatus };
  if (parsed.data.toStatus === "EN_COURS") data.startedAt = new Date();
  if (parsed.data.toStatus === "TERMINE") data.completedAt = new Date();
  const audit = await prisma.audit.update({ where: { id: req.params.id }, data });
  res.json(audit);
});

// Réponse à une question de la checklist d'audit.
auditsRouter.post("/:id/checklist-items", async (req, res) => {
  const parsed = submitAuditChecklistItemSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ message: "Payload invalide", errors: parsed.error.flatten() });
  }
  const item = await prisma.auditChecklistItem.create({
    data: { auditId: req.params.id, ...parsed.data },
  });
  res.status(201).json(item);
});

// Constat d'audit — une NC_MAJEURE crée automatiquement une action.
auditsRouter.post("/:id/findings", async (req, res) => {
  const parsed = createAuditFindingSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ message: "Payload invalide", errors: parsed.error.flatten() });
  }
  const { finding, autoActionId } = await prisma.$transaction((tx) =>
    ingestAuditFinding(tx, req.params.id, req.user!.employeeId, parsed.data)
  );
  res.status(201).json({ finding, autoActionId });
});

// ---- Référentiels checklist d'audit ----
auditsRouter.get("/templates/list", async (_req, res) => {
  const templates = await prisma.auditChecklistTemplate.findMany({
    where: { isActive: true },
    include: { questions: { orderBy: { sequence: "asc" } } },
  });
  res.json(templates);
});
