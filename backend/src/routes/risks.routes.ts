import { Router } from "express";
import { prisma } from "../lib/prisma.js";
import {
  createRiskControlSchema,
  createRiskSchema,
  riskStatusTransitionSchema,
  updateRiskControlSchema,
} from "../validation/schemas.js";
import { ingestRisk } from "../services/riskIngestion.js";
import { computeRiskLevel } from "../services/riskScoring.js";
import { RiskTransitionError, transitionRisk } from "../services/riskTransitions.js";

export const risksRouter = Router();

risksRouter.get("/", async (req, res) => {
  const { status, category, siteId } = req.query;
  const data = await prisma.risk.findMany({
    where: {
      status: typeof status === "string" ? (status as any) : undefined,
      category: typeof category === "string" ? (category as any) : undefined,
      siteId: typeof siteId === "string" ? siteId : undefined,
    },
    orderBy: { identifiedAt: "desc" },
    include: { identifiedBy: true, owner: true, assessments: { orderBy: { assessedAt: "desc" }, take: 1 } },
    take: 100,
  });
  res.json(data);
});

risksRouter.get("/:id", async (req, res) => {
  const risk = await prisma.risk.findUnique({
    where: { id: req.params.id },
    include: {
      identifiedBy: true,
      owner: true,
      assessments: { orderBy: { assessedAt: "desc" } },
      controls: true,
      attachments: true,
      statusHistory: { orderBy: { changedAt: "asc" } },
    },
  });
  if (!risk) return res.status(404).json({ message: "Risque introuvable" });
  res.json(risk);
});

// Crée le risque + son évaluation initiale. Déclenche une action automatique
// si le niveau calculé est ÉLEVÉ ou CRITIQUE (voir services/riskIngestion.ts).
risksRouter.post("/", async (req, res) => {
  const parsed = createRiskSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ message: "Payload invalide", errors: parsed.error.flatten() });
  }

  const { risk, autoActionId } = await prisma.$transaction((tx) =>
    ingestRisk(tx, req.user!.employeeId, parsed.data)
  );
  res.status(201).json({ risk, autoActionId });
});

// Ajoute une réévaluation (par ex. après mise en place de mesures de
// maîtrise) — le score/niveau résiduel est recalculé et stocké séparément
// de l'évaluation initiale, conformément au document V3.
risksRouter.post("/:id/assessments", async (req, res) => {
  const parsed = createRiskSchema
    .pick({ severity: true, probability: true, exposure: true, comment: true })
    .safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ message: "Payload invalide", errors: parsed.error.flatten() });
  }

  const risk = await prisma.risk.findUnique({ where: { id: req.params.id } });
  if (!risk) return res.status(404).json({ message: "Risque introuvable" });

  const { score, level } = computeRiskLevel(parsed.data.severity, parsed.data.probability, parsed.data.exposure);

  const assessment = await prisma.riskAssessment.create({
    data: {
      riskId: risk.id,
      residualSeverity: parsed.data.severity,
      residualProbability: parsed.data.probability,
      residualExposure: parsed.data.exposure,
      residualScore: score,
      residualLevel: level,
      // Champs "initiaux" requis par le schéma : on les duplique avec les
      // mêmes valeurs pour cette réévaluation (une ligne = une évaluation).
      severity: parsed.data.severity,
      probability: parsed.data.probability,
      exposure: parsed.data.exposure,
      initialScore: score,
      initialLevel: level,
      comment: parsed.data.comment,
      assessedById: req.user!.employeeId,
    },
  });

  await prisma.risk.update({ where: { id: risk.id }, data: { residualLevel: level } });

  res.status(201).json(assessment);
});

risksRouter.post("/:id/controls", async (req, res) => {
  const parsed = createRiskControlSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ message: "Payload invalide", errors: parsed.error.flatten() });
  }
  const control = await prisma.riskControl.create({
    data: { riskId: req.params.id, ...parsed.data },
  });
  res.status(201).json(control);
});

risksRouter.patch("/:id/controls/:controlId", async (req, res) => {
  const parsed = updateRiskControlSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ message: "Payload invalide", errors: parsed.error.flatten() });
  }
  const control = await prisma.riskControl.update({
    where: { id: req.params.controlId },
    data: { implemented: parsed.data.implemented, implementedAt: parsed.data.implemented ? new Date() : null },
  });
  res.json(control);
});

risksRouter.patch("/:id/status", async (req, res) => {
  const parsed = riskStatusTransitionSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ message: "Payload invalide", errors: parsed.error.flatten() });
  }
  try {
    const updated = await prisma.$transaction((tx) =>
      transitionRisk(tx, req.params.id, parsed.data.toStatus, req.user!.employeeId, parsed.data.comment)
    );
    res.json(updated);
  } catch (err) {
    if (err instanceof RiskTransitionError) return res.status(409).json({ message: err.message });
    throw err;
  }
});
