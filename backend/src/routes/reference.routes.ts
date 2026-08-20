import { Router } from "express";
import { prisma } from "../lib/prisma.js";

export const referenceRouter = Router();

/**
 * Un seul appel pour peupler les sélecteurs du formulaire de contrôle
 * côté Flutter (ligne, produit/format, type d'emballage, équipe).
 * Évite plusieurs allers-retours réseau au démarrage de l'app.
 */
referenceRouter.get("/", async (_req, res) => {
  const [productionLines, products, packagingTypes, shifts] = await Promise.all([
    prisma.productionLine.findMany({ include: { site: true, machines: true }, orderBy: { name: "asc" } }),
    prisma.product.findMany({ include: { formats: true }, orderBy: { name: "asc" } }),
    prisma.packagingType.findMany({ orderBy: { name: "asc" } }),
    prisma.shift.findMany({ orderBy: { name: "asc" } }),
  ]);

  res.json({ productionLines, products, packagingTypes, shifts });
});
