import type { Prisma, PrismaClient } from "@prisma/client";
import { ActionPriority, ActionStatus } from "@prisma/client";
import { ref } from "../lib/ref.js";

type Tx = Prisma.TransactionClient | PrismaClient;

const DEFAULT_ACTION_DELAY_DAYS = 15;

interface CreateFindingInput {
  checklistItemId?: string;
  type: string;
  description: string;
  responsibleId?: string;
  dueDate?: string;
}

/**
 * Crée un constat d'audit. Un constat NC_MAJEURE déclenche automatiquement
 * une action corrective (même moteur central que NC/Risque/Sécurité).
 */
export async function ingestAuditFinding(tx: Tx, auditId: string, createdById: string, input: CreateFindingInput) {
  const audit = await tx.audit.findUniqueOrThrow({ where: { id: auditId } });

  const finding = await tx.auditFinding.create({
    data: {
      auditId,
      checklistItemId: input.checklistItemId,
      type: input.type as any,
      description: input.description,
    },
  });

  let autoActionId: string | null = null;
  if (input.type === "NC_MAJEURE") {
    const dueDate = input.dueDate
      ? new Date(input.dueDate)
      : new Date(Date.now() + DEFAULT_ACTION_DELAY_DAYS * 86_400_000);

    const action = await tx.action.create({
      data: {
        reference: ref("ACT"),
        originType: "AUDIT",
        originId: audit.id,
        title: `Traiter le constat d'audit ${audit.reference}`,
        description: input.description,
        actionType: "CORRECTIVE",
        priority: ActionPriority.HAUTE,
        responsibleId: input.responsibleId ?? createdById,
        dueDate,
        status: ActionStatus.OUVERTE,
        sources: { create: { sourceType: "AUDIT", sourceId: audit.id } },
        history: {
          create: {
            fromStatus: null,
            toStatus: ActionStatus.OUVERTE,
            changedById: createdById,
            comment: "Création automatique suite à non-conformité majeure d'audit",
          },
        },
      },
    });
    autoActionId = action.id;
  }

  return { finding, autoActionId };
}
