import { Router } from "express";
import { prisma } from "../lib/prisma.js";
import { actionStatusTransitionSchema } from "../validation/schemas.js";
import { ActionTransitionError, transitionAction } from "../services/actionTransitions.js";

export const actionsRouter = Router();

actionsRouter.get("/", async (req, res) => {
  const { status, responsibleId, overdue } = req.query;
  const data = await prisma.action.findMany({
    where: {
      status: typeof status === "string" ? (status as any) : undefined,
      responsibleId: typeof responsibleId === "string" ? responsibleId : undefined,
      dueDate: overdue === "true" ? { lt: new Date() } : undefined,
    },
    orderBy: { dueDate: "asc" },
    include: { nonConformity: true, responsible: true, sources: true },
    take: 100,
  });
  res.json(data);
});

actionsRouter.get("/:id", async (req, res) => {
  const action = await prisma.action.findUnique({
    where: { id: req.params.id },
    include: {
      nonConformity: true,
      responsible: true,
      verifiedBy: true,
      attachments: true,
      sources: true,
      history: { orderBy: { changedAt: "asc" } },
    },
  });
  if (!action) return res.status(404).json({ message: "Action introuvable" });
  res.json(action);
});

actionsRouter.patch("/:id/status", async (req, res) => {
  const parsed = actionStatusTransitionSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ message: "Payload invalide", errors: parsed.error.flatten() });
  }
  const changedById = req.user!.employeeId;

  try {
    const updated = await prisma.$transaction((tx) =>
      transitionAction(tx, req.params.id, parsed.data.toStatus, changedById, {
        effectiveness: parsed.data.effectiveness,
        verificationComment: parsed.data.verificationComment,
        effectivenessStatus: parsed.data.effectivenessStatus,
        comment: parsed.data.comment,
      })
    );
    res.json(updated);
  } catch (err) {
    if (err instanceof ActionTransitionError) {
      return res.status(409).json({ message: err.message });
    }
    throw err;
  }
});
