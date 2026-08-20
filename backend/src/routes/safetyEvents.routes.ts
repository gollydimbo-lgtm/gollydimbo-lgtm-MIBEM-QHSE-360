import { Router } from "express";
import { prisma } from "../lib/prisma.js";
import {
  createSafetyEventCauseSchema,
  createSafetyEventInjurySchema,
  createSafetyEventSchema,
  createSafetyEventWitnessSchema,
  safetyEventStatusTransitionSchema,
} from "../validation/schemas.js";
import { ingestSafetyEvent } from "../services/safetyEventIngestion.js";
import { SafetyEventTransitionError, transitionSafetyEvent } from "../services/safetyEventTransitions.js";

export const safetyEventsRouter = Router();

safetyEventsRouter.get("/", async (req, res) => {
  const { status, type, severity, siteId } = req.query;
  const data = await prisma.safetyEvent.findMany({
    where: {
      status: typeof status === "string" ? (status as any) : undefined,
      type: typeof type === "string" ? (type as any) : undefined,
      severity: typeof severity === "string" ? (severity as any) : undefined,
      siteId: typeof siteId === "string" ? siteId : undefined,
    },
    orderBy: { reportedAt: "desc" },
    include: { reportedBy: true, investigatedBy: true },
    take: 100,
  });
  res.json(data);
});

safetyEventsRouter.get("/:id", async (req, res) => {
  const event = await prisma.safetyEvent.findUnique({
    where: { id: req.params.id },
    include: {
      reportedBy: true,
      investigatedBy: true,
      witnesses: true,
      injuries: true,
      causes: true,
      attachments: true,
      statusHistory: { orderBy: { changedAt: "asc" } },
    },
  });
  if (!event) return res.status(404).json({ message: "Événement introuvable" });
  res.json(event);
});

// Crée l'événement. Une gravité MAJEURE/CATASTROPHIQUE déclenche
// automatiquement l'investigation et une action corrective.
safetyEventsRouter.post("/", async (req, res) => {
  const parsed = createSafetyEventSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ message: "Payload invalide", errors: parsed.error.flatten() });
  }
  const { event, autoActionId } = await prisma.$transaction((tx) =>
    ingestSafetyEvent(tx, req.user!.employeeId, parsed.data)
  );
  res.status(201).json({ event, autoActionId });
});

safetyEventsRouter.post("/:id/witnesses", async (req, res) => {
  const parsed = createSafetyEventWitnessSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ message: "Payload invalide", errors: parsed.error.flatten() });
  }
  const witness = await prisma.safetyEventWitness.create({
    data: { safetyEventId: req.params.id, ...parsed.data },
  });
  res.status(201).json(witness);
});

safetyEventsRouter.post("/:id/injuries", async (req, res) => {
  const parsed = createSafetyEventInjurySchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ message: "Payload invalide", errors: parsed.error.flatten() });
  }
  const injury = await prisma.safetyEventInjury.create({
    data: { safetyEventId: req.params.id, ...parsed.data },
  });
  res.status(201).json(injury);
});

// L'arborescence des causes (5 Pourquoi / Ishikawa) se construit en
// rappelant cet endpoint avec parentCauseId pointant vers la cause précédente.
safetyEventsRouter.post("/:id/causes", async (req, res) => {
  const parsed = createSafetyEventCauseSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ message: "Payload invalide", errors: parsed.error.flatten() });
  }
  const cause = await prisma.safetyEventCause.create({
    data: { safetyEventId: req.params.id, ...parsed.data },
  });
  res.status(201).json(cause);
});

safetyEventsRouter.patch("/:id/status", async (req, res) => {
  const parsed = safetyEventStatusTransitionSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ message: "Payload invalide", errors: parsed.error.flatten() });
  }
  try {
    const updated = await prisma.$transaction((tx) =>
      transitionSafetyEvent(tx, req.params.id, parsed.data.toStatus, req.user!.employeeId, parsed.data.comment)
    );
    res.json(updated);
  } catch (err) {
    if (err instanceof SafetyEventTransitionError) return res.status(409).json({ message: err.message });
    throw err;
  }
});
