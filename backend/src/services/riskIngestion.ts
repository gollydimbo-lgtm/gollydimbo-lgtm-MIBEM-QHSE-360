import type { Prisma, PrismaClient } from "@prisma/client";
import { ActionPriority, ActionStatus, RiskLevel, RiskStatus } from "@prisma/client";
import { ref } from "../lib/ref.js";
import { computeRiskLevel, requiresAutoAction } from "./riskScoring.js";

type Tx = Prisma.TransactionClient | PrismaClient;

interface CreateRiskInput {
  title: string;
  description?: string;
  category: string;
  siteId?: string;
  productionLineId?: string;
  machineId?: string;
  ownerId?: string;
  severity: number;
  probability: number;
  exposure?: number;
  comment?: string;
  actionDueDate?: string;
  solutionId?: string;
}

const DEFAULT_ACTION_DELAY_DAYS = 14;

function levelToPriority(level: RiskLevel): ActionPriority {
  switch (level) {
    case RiskLevel.CRITIQUE:
      return ActionPriority.CRITIQUE;
    case RiskLevel.ELEVE:
      return ActionPriority.HAUTE;
    case RiskLevel.MODERE:
      return ActionPriority.MOYENNE;
    default:
      return ActionPriority.BASSE;
  }
}

/**
 * Crée un risque avec son évaluation initiale (gravité/probabilité/exposition
 * → score → niveau). Si le niveau calculé est ÉLEVÉ ou CRITIQUE, une action
 * de traitement est créée automatiquement (même logique que pour les NC :
 * ActionSource + ActionHistory), conformément à la règle du document V3.
 */
export async function ingestRisk(tx: Tx, identifiedById: string, input: CreateRiskInput) {
  const { score, level } = computeRiskLevel(input.severity, input.probability, input.exposure);

  const risk = await tx.risk.create({
    data: {
      reference: ref("RISK"),
      title: input.title,
      description: input.description,
      category: input.category as any,
      status: RiskStatus.EVALUE,
      siteId: input.siteId,
      productionLineId: input.productionLineId,
      machineId: input.machineId,
      identifiedById,
      ownerId: input.ownerId ?? identifiedById,
      initialLevel: level,
    },
  });

  await tx.riskAssessment.create({
    data: {
      riskId: risk.id,
      severity: input.severity,
      probability: input.probability,
      exposure: input.exposure,
      initialScore: score,
      initialLevel: level,
      comment: input.comment,
      assessedById: identifiedById,
    },
  });

  await tx.riskStatusHistory.create({
    data: {
      riskId: risk.id,
      fromStatus: RiskStatus.IDENTIFIE,
      toStatus: RiskStatus.EVALUE,
      changedById: identifiedById,
      comment: `Évaluation initiale : score ${score}, niveau ${level}`,
    },
  });

  let autoActionId: string | null = null;
  if (requiresAutoAction(level)) {
    const dueDate = input.actionDueDate
      ? new Date(input.actionDueDate)
      : new Date(Date.now() + DEFAULT_ACTION_DELAY_DAYS * 86_400_000);

    const action = await tx.action.create({
      data: {
        reference: ref("ACT"),
        originType: "RISK",
        originId: risk.id,
        title: `Traiter le risque ${risk.reference}`,
        description: `Mesure de réduction requise pour le risque "${input.title}" (niveau ${level}, score ${score})`,
        actionType: "PREVENTIVE",
        priority: levelToPriority(level),
        responsibleId: input.ownerId ?? identifiedById,
        dueDate,
        status: ActionStatus.OUVERTE,
        solutionId: input.solutionId,
        sources: { create: { sourceType: "RISK", sourceId: risk.id } },
        history: {
          create: {
            fromStatus: null,
            toStatus: ActionStatus.OUVERTE,
            changedById: identifiedById,
            comment: "Création automatique suite à évaluation de risque",
          },
        },
      },
    });
    autoActionId = action.id;

    if (input.solutionId) {
      await tx.solution.update({ where: { id: input.solutionId }, data: { usageCount: { increment: 1 } } });
    }

    await tx.risk.update({ where: { id: risk.id }, data: { status: RiskStatus.TRAITEMENT_REQUIS } });
    await tx.riskStatusHistory.create({
      data: {
        riskId: risk.id,
        fromStatus: RiskStatus.EVALUE,
        toStatus: RiskStatus.TRAITEMENT_REQUIS,
        changedById: identifiedById,
        comment: "Niveau de risque élevé/critique : traitement requis",
      },
    });
  }

  const full = await tx.risk.findUniqueOrThrow({
    where: { id: risk.id },
    include: { assessments: true, controls: true, statusHistory: true },
  });

  return { risk: full, autoActionId };
}
