import { Router } from "express";
import { prisma } from "../lib/prisma.js";
import { ref } from "../lib/ref.js";
import { createTrainingSchema, createTrainingSessionSchema, recordAttendanceSchema } from "../validation/schemas.js";
import { recordTrainingAttendance } from "../services/trainingIngestion.js";

export const trainingsRouter = Router();

trainingsRouter.get("/", async (_req, res) => {
  const data = await prisma.training.findMany({
    orderBy: { title: "asc" },
    include: { sessions: { orderBy: { sessionDate: "desc" }, take: 5 } },
  });
  res.json(data);
});

trainingsRouter.post("/", async (req, res) => {
  const parsed = createTrainingSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ message: "Payload invalide", errors: parsed.error.flatten() });
  }
  const training = await prisma.training.create({ data: parsed.data });
  res.status(201).json(training);
});

trainingsRouter.post("/:id/sessions", async (req, res) => {
  const parsed = createTrainingSessionSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ message: "Payload invalide", errors: parsed.error.flatten() });
  }
  const session = await prisma.trainingSession.create({
    data: {
      trainingId: req.params.id,
      sessionDate: new Date(parsed.data.sessionDate),
      location: parsed.data.location,
      trainerName: parsed.data.trainerName,
    },
  });
  res.status(201).json(session);
});

// Enregistre une présence — crée/renouvelle automatiquement la compétence
// employé si `attended` est vrai (voir services/trainingIngestion.ts).
trainingsRouter.post("/sessions/:sessionId/attendance", async (req, res) => {
  const parsed = recordAttendanceSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ message: "Payload invalide", errors: parsed.error.flatten() });
  }
  const { attendance, competencyId } = await prisma.$transaction((tx) =>
    recordTrainingAttendance(tx, req.params.sessionId, parsed.data)
  );
  res.status(201).json({ attendance, competencyId });
});

trainingsRouter.get("/competencies/employee/:employeeId", async (req, res) => {
  const data = await prisma.employeeCompetency.findMany({
    where: { employeeId: req.params.employeeId },
    include: { training: true },
    orderBy: { obtainedAt: "desc" },
  });
  res.json(data);
});

trainingsRouter.get("/competencies/expiring", async (req, res) => {
  const days = Number(req.query.days ?? 30);
  const until = new Date(Date.now() + days * 86_400_000);
  const data = await prisma.employeeCompetency.findMany({
    where: { expiresAt: { lte: until, gte: new Date() } },
    include: { employee: true, training: true },
    orderBy: { expiresAt: "asc" },
  });
  res.json(data);
});
