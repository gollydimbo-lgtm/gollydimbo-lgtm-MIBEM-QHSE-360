import { Router } from "express";
import { prisma } from "../lib/prisma.js";
import {
  createPPEAssignmentSchema,
  createPPEInspectionSchema,
  createPPEItemSchema,
  updatePPEStockSchema,
} from "../validation/schemas.js";
import { z } from "zod";

export const ppeRouter = Router();

ppeRouter.get("/categories", async (_req, res) => {
  const data = await prisma.pPECategory.findMany({ include: { items: true }, orderBy: { name: "asc" } });
  res.json(data);
});

ppeRouter.post("/categories", async (req, res) => {
  const parsed = z.object({ code: z.string().min(1), name: z.string().min(1) }).safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ message: "Payload invalide", errors: parsed.error.flatten() });
  const category = await prisma.pPECategory.create({ data: parsed.data });
  res.status(201).json(category);
});

ppeRouter.get("/items", async (_req, res) => {
  const data = await prisma.pPEItem.findMany({ include: { category: true, stock: true }, orderBy: { name: "asc" } });
  res.json(data);
});

ppeRouter.post("/items", async (req, res) => {
  const parsed = createPPEItemSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ message: "Payload invalide", errors: parsed.error.flatten() });
  const item = await prisma.pPEItem.create({ data: parsed.data });
  res.status(201).json(item);
});

// Upsert simple du stock (un enregistrement par item+site).
ppeRouter.post("/stock", async (req, res) => {
  const parsed = updatePPEStockSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ message: "Payload invalide", errors: parsed.error.flatten() });

  const existing = await prisma.pPEStock.findFirst({
    where: { itemId: parsed.data.itemId, siteId: parsed.data.siteId ?? null },
  });

  const stock = existing
    ? await prisma.pPEStock.update({ where: { id: existing.id }, data: { quantity: parsed.data.quantity } })
    : await prisma.pPEStock.create({ data: parsed.data });

  res.status(existing ? 200 : 201).json(stock);
});

ppeRouter.get("/assignments/employee/:employeeId", async (req, res) => {
  const data = await prisma.pPEAssignment.findMany({
    where: { employeeId: req.params.employeeId },
    include: { item: { include: { category: true } }, inspections: true },
    orderBy: { assignedAt: "desc" },
  });
  res.json(data);
});

ppeRouter.post("/assignments", async (req, res) => {
  const parsed = createPPEAssignmentSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ message: "Payload invalide", errors: parsed.error.flatten() });

  const assignment = await prisma.$transaction(async (tx) => {
    const created = await tx.pPEAssignment.create({
      data: {
        itemId: parsed.data.itemId,
        employeeId: parsed.data.employeeId,
        expectedReplacementAt: parsed.data.expectedReplacementAt ? new Date(parsed.data.expectedReplacementAt) : undefined,
      },
    });
    // Décrémente le stock disponible si une ligne de stock existe (best-effort).
    const stock = await tx.pPEStock.findFirst({ where: { itemId: parsed.data.itemId, quantity: { gt: 0 } } });
    if (stock) {
      await tx.pPEStock.update({ where: { id: stock.id }, data: { quantity: { decrement: 1 } } });
    }
    return created;
  });

  res.status(201).json(assignment);
});

ppeRouter.patch("/assignments/:id/return", async (req, res) => {
  const parsed = z.object({ status: z.enum(["RETOURNE", "PERDU"]) }).safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ message: "Payload invalide", errors: parsed.error.flatten() });
  const assignment = await prisma.pPEAssignment.update({
    where: { id: req.params.id },
    data: { status: parsed.data.status, returnedAt: new Date() },
  });
  res.json(assignment);
});

ppeRouter.post("/assignments/:id/inspections", async (req, res) => {
  const parsed = createPPEInspectionSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ message: "Payload invalide", errors: parsed.error.flatten() });
  const inspection = await prisma.pPEInspection.create({
    data: { assignmentId: req.params.id, inspectedById: req.user!.employeeId, ...parsed.data },
  });
  res.status(201).json(inspection);
});
