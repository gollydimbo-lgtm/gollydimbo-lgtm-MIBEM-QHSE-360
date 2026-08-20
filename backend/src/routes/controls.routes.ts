import { Router } from "express";
import { prisma } from "../lib/prisma.js";
import { createControlSchema, syncControlsSchema } from "../validation/schemas.js";
import { fullControlInclude, ingestControl } from "../services/controlIngestion.js";

export const controlsRouter = Router();

controlsRouter.get("/", async (req, res) => {
  const { productionLineId, from, to, syncStatus } = req.query;

  const data = await prisma.control.findMany({
    where: {
      productionLineId: typeof productionLineId === "string" ? productionLineId : undefined,
      syncStatus: typeof syncStatus === "string" ? (syncStatus as any) : undefined,
      controlDate: {
        gte: typeof from === "string" ? new Date(from) : undefined,
        lte: typeof to === "string" ? new Date(to) : undefined,
      },
    },
    orderBy: { controlDate: "desc" },
    include: {
      controller: true,
      productionLine: true,
      product: true,
      results: { include: { controlPoint: true, nonConformity: true } },
    },
    take: 100,
  });
  res.json(data);
});

controlsRouter.get("/:id", async (req, res) => {
  const control = await prisma.control.findUnique({
    where: { id: req.params.id },
    include: fullControlInclude,
  });
  if (!control) return res.status(404).json({ message: "Contrôle introuvable" });
  res.json(control);
});

// Création "en ligne" classique (l'appareil a du réseau au moment de la saisie).
controlsRouter.post("/", async (req, res) => {
  const parsed = createControlSchema.safeParse(req.body);
  if (!parsed.success) {
    console.error("[POST /api/controls] Payload invalide :", JSON.stringify(parsed.error.flatten(), null, 2));
    console.error("[POST /api/controls] Corps reçu :", JSON.stringify(req.body, null, 2));
    return res.status(400).json({ message: "Payload invalide", errors: parsed.error.flatten() });
  }

  const { control } = await prisma.$transaction((tx) => ingestControl(tx, req.user!.employeeId, parsed.data));
  res.status(201).json(control);
});

/**
 * Synchronisation par lot pour le mode hors ligne du client Flutter.
 * Chaque élément du tableau porte un `clientLocalId` : s'il correspond à un
 * contrôle déjà connu côté serveur (renvoi après coupure réseau), il est
 * simplement renvoyé sans être recréé — l'appel est donc idempotent et peut
 * être rejoué sans risque de doublons de NC/actions.
 */
controlsRouter.post("/sync", async (req, res) => {
  const parsed = syncControlsSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ message: "Payload invalide", errors: parsed.error.flatten() });
  }

  const outcomes = [];
  for (const item of parsed.data.controls) {
    try {
      const { control, deduplicated } = await prisma.$transaction((tx) =>
        ingestControl(tx, req.user!.employeeId, item, { syncStatus: "SYNCED" })
      );
      outcomes.push({ clientLocalId: item.clientLocalId, status: "ok", deduplicated, controlId: control.id });
    } catch (err) {
      outcomes.push({
        clientLocalId: item.clientLocalId,
        status: "error",
        message: err instanceof Error ? err.message : "Erreur inconnue",
      });
    }
  }

  const hasErrors = outcomes.some((o) => o.status === "error");
  res.status(hasErrors ? 207 : 201).json({ results: outcomes });
});
