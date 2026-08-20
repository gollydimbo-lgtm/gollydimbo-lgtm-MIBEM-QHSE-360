import { Router } from "express";
import { prisma } from "../lib/prisma.js";
import { createSolutionSchema, updateSolutionSchema } from "../validation/schemas.js";
import { promoteActionToSolution, suggestSolutions } from "../services/solutionLibrary.js";

export const solutionsRouter = Router();

// Suggestions classées par usage/efficacité — appelé par le client avant
// même la création d'une NC/Risque/Événement pour proposer une solution
// déjà éprouvée plutôt que de repartir de zéro.
solutionsRouter.get("/suggest", async (req, res) => {
  const { sourceType, category, search } = req.query;
  if (typeof sourceType !== "string") {
    return res.status(400).json({ message: "sourceType est requis" });
  }
  const solutions = await suggestSolutions(prisma, {
    sourceType,
    category: typeof category === "string" ? category : undefined,
    search: typeof search === "string" ? search : undefined,
  });
  res.json(solutions);
});

solutionsRouter.get("/", async (req, res) => {
  const { sourceType, isValidated } = req.query;
  const data = await prisma.solution.findMany({
    where: {
      sourceType: typeof sourceType === "string" ? (sourceType as any) : undefined,
      isValidated: isValidated === "true" ? true : isValidated === "false" ? false : undefined,
    },
    orderBy: { usageCount: "desc" },
    include: { createdBy: true },
    take: 200,
  });
  res.json(data);
});

solutionsRouter.post("/", async (req, res) => {
  const parsed = createSolutionSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ message: "Payload invalide", errors: parsed.error.flatten() });
  const solution = await prisma.solution.create({
    data: { ...parsed.data, createdById: req.user!.employeeId },
  });
  res.status(201).json(solution);
});

solutionsRouter.patch("/:id", async (req, res) => {
  const parsed = updateSolutionSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ message: "Payload invalide", errors: parsed.error.flatten() });
  const solution = await prisma.solution.update({ where: { id: req.params.id }, data: parsed.data });
  res.json(solution);
});

// Capture le savoir-faire terrain : promeut une action clôturée et jugée
// efficace en solution réutilisable pour les prochains cas similaires.
solutionsRouter.post("/from-action/:actionId", async (req, res) => {
  try {
    const solution = await prisma.$transaction((tx) =>
      promoteActionToSolution(tx, req.params.actionId, req.user!.employeeId)
    );
    res.status(201).json(solution);
  } catch (err) {
    if (err instanceof Error) return res.status(409).json({ message: err.message });
    throw err;
  }
});
