import { Router } from "express";
import { prisma } from "../lib/prisma.js";

export const controlTemplatesRouter = Router();

/**
 * Retourne la (les) checklist(s) active(s) applicable(s) à une ligne de
 * production donnée, points de contrôle triés par séquence. Le client
 * Flutter génère son formulaire dynamique directement depuis cette réponse
 * (type de champ, unité, bornes, caractère critique...).
 */
controlTemplatesRouter.get("/line/:productionLineId", async (req, res) => {
  const { productionLineId } = req.params;

  const templates = await prisma.controlTemplate.findMany({
    where: {
      isActive: true,
      OR: [
        { lines: { some: { productionLineId } } },
        { lines: { none: {} } }, // templates génériques, non rattachés à une ligne précise
      ],
    },
    include: {
      points: { orderBy: { sequence: "asc" } },
    },
  });

  res.json(templates);
});

controlTemplatesRouter.get("/", async (_req, res) => {
  const templates = await prisma.controlTemplate.findMany({
    where: { isActive: true },
    include: { points: { orderBy: { sequence: "asc" } }, lines: true },
  });
  res.json(templates);
});

controlTemplatesRouter.get("/:id", async (req, res) => {
  const template = await prisma.controlTemplate.findUnique({
    where: { id: req.params.id },
    include: { points: { orderBy: { sequence: "asc" } }, lines: { include: { productionLine: true } } },
  });
  if (!template) return res.status(404).json({ message: "Template introuvable" });
  res.json(template);
});
