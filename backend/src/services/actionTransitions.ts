import { ActionStatus, EffectivenessStatus } from "@prisma/client";
import type { Prisma, PrismaClient } from "@prisma/client";

type Tx = Prisma.TransactionClient | PrismaClient;

// EN_RETARD n'est jamais une cible de transition manuelle : elle est
// positionnée automatiquement par le job planifié (voir jobs/overdueActions.job.ts)
// et quittée automatiquement dès que l'utilisateur avance le statut.
const ALLOWED_TRANSITIONS: Record<ActionStatus, ActionStatus[]> = {
  OUVERTE: [ActionStatus.EN_COURS],
  EN_COURS: [ActionStatus.TERMINEE, ActionStatus.OUVERTE],
  TERMINEE: [ActionStatus.A_VERIFIER],
  A_VERIFIER: [ActionStatus.CLOTUREE, ActionStatus.EN_COURS], // renvoi si vérif négative
  CLOTUREE: [],
  EN_RETARD: [ActionStatus.EN_COURS, ActionStatus.TERMINEE],
};

export class ActionTransitionError extends Error {}

export async function transitionAction(
  tx: Tx,
  actionId: string,
  toStatus: ActionStatus,
  changedById: string,
  fields: {
    effectiveness?: string;
    verificationComment?: string;
    effectivenessStatus?: EffectivenessStatus;
    comment?: string;
  } = {}
) {
  const action = await tx.action.findUnique({ where: { id: actionId } });
  if (!action) throw new ActionTransitionError("Action introuvable");

  const allowed = ALLOWED_TRANSITIONS[action.status] ?? [];
  if (!allowed.includes(toStatus)) {
    throw new ActionTransitionError(
      `Transition ${action.status} → ${toStatus} non autorisée. Transitions possibles : ${allowed.join(", ") || "aucune"}`
    );
  }

  if (toStatus === ActionStatus.CLOTUREE && !fields.effectiveness) {
    throw new ActionTransitionError("Un commentaire d'efficacité est requis pour clôturer une action");
  }

  const isVerificationStep = toStatus === ActionStatus.CLOTUREE && action.status === ActionStatus.A_VERIFIER;

  const updated = await tx.action.update({
    where: { id: actionId },
    data: {
      status: toStatus,
      completedAt: toStatus === ActionStatus.TERMINEE ? new Date() : action.completedAt,
      effectiveness: fields.effectiveness ?? action.effectiveness,
      verificationComment: fields.verificationComment ?? action.verificationComment,
      // V3 : trace qui a vérifié l'action et quand, et qualifie son
      // efficacité au-delà du simple commentaire texte existant.
      verifiedById: isVerificationStep ? changedById : action.verifiedById,
      verifiedAt: isVerificationStep ? new Date() : action.verifiedAt,
      effectivenessStatus: fields.effectivenessStatus ?? action.effectivenessStatus,
    },
  });

  await tx.actionHistory.create({
    data: {
      actionId,
      fromStatus: action.status,
      toStatus,
      changedById,
      comment: fields.comment,
    },
  });

  return updated;
}
