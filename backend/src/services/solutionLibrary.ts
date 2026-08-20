import type { Prisma, PrismaClient } from "@prisma/client";
import { ActionStatus, EffectivenessStatus } from "@prisma/client";

type Tx = Prisma.TransactionClient | PrismaClient;

/**
 * Suggère les solutions les plus pertinentes pour une catégorie/origine
 * donnée, classées par nombre d'utilisations puis taux de succès. Utilisée
 * par le client (Flutter) avant même la création d'une NC/Risque/Événement,
 * pour proposer une action déjà éprouvée plutôt que de partir de zéro.
 */
export async function suggestSolutions(
  tx: Tx,
  params: { sourceType: string; category?: string; search?: string; limit?: number }
) {
  const solutions = await tx.solution.findMany({
    where: {
      sourceType: params.sourceType as any,
      category: params.category ? { equals: params.category, mode: "insensitive" } : undefined,
      OR: params.search
        ? [
            { title: { contains: params.search, mode: "insensitive" } },
            { keywords: { contains: params.search, mode: "insensitive" } },
          ]
        : undefined,
    },
    orderBy: [{ usageCount: "desc" }, { successCount: "desc" }],
    take: params.limit ?? 5,
  });
  return solutions;
}

class SolutionPromotionError extends Error {}

/**
 * Transforme une action clôturée et jugée efficace en solution réutilisable.
 * C'est ainsi que la bibliothèque s'enrichit au fil de l'usage réel du
 * terrain, plutôt que d'être pré-remplie artificiellement.
 */
export async function promoteActionToSolution(tx: Tx, actionId: string, createdById: string) {
  const action = await tx.action.findUnique({ where: { id: actionId }, include: { sources: true } });
  if (!action) throw new SolutionPromotionError("Action introuvable");
  if (action.status !== ActionStatus.CLOTUREE) {
    throw new SolutionPromotionError("Seule une action clôturée peut être promue en solution");
  }
  if (action.effectivenessStatus !== EffectivenessStatus.EFFICACE) {
    throw new SolutionPromotionError("Seule une action jugée EFFICACE peut être promue en solution");
  }

  const primarySource = action.sources[0];
  const sourceType = primarySource?.sourceType ?? "MANUAL";

  const solution = await tx.solution.create({
    data: {
      title: action.title ?? action.description.slice(0, 80),
      description: action.description,
      sourceType,
      category: action.actionType,
      createdById,
      isValidated: false, // à valider par un QHSE_MANAGER avant diffusion large
      usageCount: 1,
      successCount: 1,
    },
  });

  await tx.action.update({ where: { id: actionId }, data: { solutionId: solution.id } });

  return solution;
}
