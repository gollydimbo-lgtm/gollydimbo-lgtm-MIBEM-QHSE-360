import { Router } from "express";
import { prisma } from "../lib/prisma.js";
import { ref } from "../lib/ref.js";
import {
  briefingStatusTransitionSchema,
  createSafetyBriefingSchema,
  recordBriefingAttendanceSchema,
} from "../validation/schemas.js";
import { suggestBriefingTopics } from "../services/briefingSuggestion.js";

export const safetyBriefingsRouter = Router();

// Propose des sujets sans rien créer — le QHSE manager choisit ensuite
// lesquels inclure dans le quart d'heure qu'il crée réellement.
safetyBriefingsRouter.get("/suggest-topics", async (req, res) => {
  const { siteId, productionLineId, sinceDays } = req.query;
  const topics = await suggestBriefingTopics(prisma, {
    siteId: typeof siteId === "string" ? siteId : undefined,
    productionLineId: typeof productionLineId === "string" ? productionLineId : undefined,
    sinceDays: sinceDays ? Number(sinceDays) : undefined,
  });
  res.json({ topics });
});

safetyBriefingsRouter.get("/", async (req, res) => {
  const { status, siteId } = req.query;
  const data = await prisma.safetyBriefing.findMany({
    where: {
      status: typeof status === "string" ? (status as any) : undefined,
      siteId: typeof siteId === "string" ? siteId : undefined,
    },
    orderBy: { scheduledDate: "desc" },
    include: { presenter: true, topics: true, _count: { select: { attendances: true } } },
    take: 100,
  });
  res.json(data);
});

safetyBriefingsRouter.get("/:id", async (req, res) => {
  const briefing = await prisma.safetyBriefing.findUnique({
    where: { id: req.params.id },
    include: {
      presenter: true,
      site: true,
      productionLine: true,
      topics: { orderBy: { sequence: "asc" } },
      attendances: { include: { employee: true } },
    },
  });
  if (!briefing) return res.status(404).json({ message: "Quart d'heure introuvable" });
  res.json(briefing);
});

// Crée le quart d'heure avec ses sujets (issus des suggestions retenues,
// et/ou saisis manuellement).
safetyBriefingsRouter.post("/", async (req, res) => {
  const parsed = createSafetyBriefingSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ message: "Payload invalide", errors: parsed.error.flatten() });

  const briefing = await prisma.safetyBriefing.create({
    data: {
      reference: ref("QHS"),
      title: parsed.data.title,
      scheduledDate: new Date(parsed.data.scheduledDate),
      siteId: parsed.data.siteId,
      productionLineId: parsed.data.productionLineId,
      presenterId: req.user!.employeeId,
      topics: {
        create: parsed.data.topics.map((t, i) => ({
          title: t.title,
          content: t.content,
          sourceType: t.sourceType ?? "MANUAL",
          sourceId: t.sourceId,
          sequence: i + 1,
        })),
      },
    },
    include: { topics: true },
  });

  res.status(201).json(briefing);
});

safetyBriefingsRouter.patch("/:id/status", async (req, res) => {
  const parsed = briefingStatusTransitionSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ message: "Payload invalide", errors: parsed.error.flatten() });
  const briefing = await prisma.safetyBriefing.update({
    where: { id: req.params.id },
    data: { status: parsed.data.toStatus, summary: parsed.data.summary },
  });
  res.json(briefing);
});

// Émargement — un employé par quart d'heure (contrainte unique en base).
safetyBriefingsRouter.post("/:id/attendance", async (req, res) => {
  const parsed = recordBriefingAttendanceSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ message: "Payload invalide", errors: parsed.error.flatten() });
  const attendance = await prisma.safetyBriefingAttendance.create({
    data: {
      briefingId: req.params.id,
      employeeId: parsed.data.employeeId,
      comment: parsed.data.comment,
      signedAt: new Date(),
    },
  });
  res.status(201).json(attendance);
});
