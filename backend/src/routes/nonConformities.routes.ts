import { Router } from "express";
import { prisma } from "../lib/prisma.js";
import { ncStatusTransitionSchema } from "../validation/schemas.js";
import { NCTransitionError, transitionNonConformity } from "../services/ncTransitions.js";

export const nonConformitiesRouter = Router();

nonConformitiesRouter.get("/", async (req, res) => {
  const { status, severity, productionLineId } = req.query;
  const data = await prisma.nonConformity.findMany({
    where: {
      status: typeof status === "string" ? (status as any) : undefined,
      severity: typeof severity === "string" ? (severity as any) : undefined,
      productionLineId: typeof productionLineId === "string" ? productionLineId : undefined,
    },
    orderBy: { detectedAt: "desc" },
    include: { productionLine: true, product: true, actions: true, responsible: true, detectedBy: true },
    take: 100,
  });
  res.json(data);
});

nonConformitiesRouter.get("/:id", async (req, res) => {
  const nc = await prisma.nonConformity.findUnique({
    where: { id: req.params.id },
    include: {
      productionLine: true,
      product: true,
      actions: true,
      attachments: true,
      statusHistory: { orderBy: { changedAt: "asc" } },
      responsible: true,
      detectedBy: true,
    },
  });
  if (!nc) return res.status(404).json({ message: "Non-conformité introuvable" });
  res.json(nc);
});

nonConformitiesRouter.patch("/:id/status", async (req, res) => {
  const parsed = ncStatusTransitionSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ message: "Payload invalide", errors: parsed.error.flatten() });
  }
  // req.user est garanti par le middleware authenticate monté sur ce routeur.
  const changedById = req.user!.employeeId;

  try {
    const updated = await prisma.$transaction((tx) =>
      transitionNonConformity(tx, req.params.id, parsed.data.toStatus, changedById, parsed.data.comment)
    );
    res.json(updated);
  } catch (err) {
    if (err instanceof NCTransitionError) {
      return res.status(409).json({ message: err.message });
    }
    throw err;
  }
});
