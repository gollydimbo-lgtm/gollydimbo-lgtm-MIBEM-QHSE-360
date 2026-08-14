import { Router } from "express";
import { prisma } from "../lib/prisma.js";
import { createInspectionSchema } from "../validation/schemas.js";
import { ingestInspection } from "../services/inspectionIngestion.js";

export const inspectionsRouter = Router();

inspectionsRouter.get("/", async (req, res) => {
  const { siteId, productionLineId, machineId } = req.query;
  const data = await prisma.inspection.findMany({
    where: {
      siteId: typeof siteId === "string" ? siteId : undefined,
      productionLineId: typeof productionLineId === "string" ? productionLineId : undefined,
      machineId: typeof machineId === "string" ? machineId : undefined,
    },
    orderBy: { inspectionDate: "desc" },
    include: { inspector: true, template: true },
    take: 100,
  });
  res.json(data);
});

inspectionsRouter.get("/:id", async (req, res) => {
  const inspection = await prisma.inspection.findUnique({
    where: { id: req.params.id },
    include: {
      inspector: true,
      template: true,
      results: { include: { inspectionPoint: true } },
      attachments: true,
    },
  });
  if (!inspection) return res.status(404).json({ message: "Inspection introuvable" });
  res.json(inspection);
});

inspectionsRouter.post("/", async (req, res) => {
  const parsed = createInspectionSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ message: "Payload invalide", errors: parsed.error.flatten() });
  }
  const { inspection, autoActionIds } = await prisma.$transaction((tx) =>
    ingestInspection(tx, req.user!.employeeId, parsed.data)
  );
  res.status(201).json({ inspection, autoActionIds });
});

inspectionsRouter.get("/templates/list", async (_req, res) => {
  const templates = await prisma.inspectionTemplate.findMany({
    where: { isActive: true },
    include: { points: { orderBy: { sequence: "asc" } } },
  });
  res.json(templates);
});
