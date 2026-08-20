import { NCStatus, ActionStatus } from "@prisma/client";
import type { Prisma, PrismaClient } from "@prisma/client";

type Tx = Prisma.TransactionClient | PrismaClient;

// Transitions autorisées. Toute transition absente de cette table est refusée.
const ALLOWED_TRANSITIONS: Record<NCStatus, NCStatus[]> = {
  OUVERTE: [NCStatus.EN_ANALYSE, NCStatus.REJETEE],
  EN_ANALYSE: [NCStatus.ACTION_EN_COURS, NCStatus.REJETEE, NCStatus.OUVERTE],
  ACTION_EN_COURS: [NCStatus.A_VERIFIER, NCStatus.EN_ANALYSE],
  A_VERIFIER: [NCStatus.CLOTUREE, NCStatus.ACTION_EN_COURS],
  CLOTUREE: [],
  REJETEE: [],
};

export class NCTransitionError extends Error {}

/**
 * Applique une transition de statut à une NC en vérifiant :
 * 1. que la transition est autorisée par la machine à états métier,
 * 2. qu'une clôture (-> CLOTUREE) n'est possible que si toutes les actions
 *    liées sont TERMINEE ou CLOTUREE (pas de clôture d'une NC "orpheline"
 *    d'action non traitée).
 * Historise chaque changement dans NonConformityStatusHistory.
 */
export async function transitionNonConformity(
  tx: Tx,
  ncId: string,
  toStatus: NCStatus,
  changedById: string,
  comment?: string
) {
  const nc = await tx.nonConformity.findUnique({
    where: { id: ncId },
    include: { actions: true },
  });
  if (!nc) throw new NCTransitionError("Non-conformité introuvable");

  const allowed = ALLOWED_TRANSITIONS[nc.status] ?? [];
  if (!allowed.includes(toStatus)) {
    throw new NCTransitionError(
      `Transition ${nc.status} → ${toStatus} non autorisée. Transitions possibles : ${allowed.join(", ") || "aucune"}`
    );
  }

  if (toStatus === NCStatus.CLOTUREE) {
    const unresolved = nc.actions.filter(
      (a) => a.status !== ActionStatus.TERMINEE && a.status !== ActionStatus.CLOTUREE
    );
    if (unresolved.length > 0) {
      throw new NCTransitionError(
        `Impossible de clôturer : ${unresolved.length} action(s) corrective(s) encore non terminée(s)`
      );
    }
  }

  const updated = await tx.nonConformity.update({
    where: { id: ncId },
    data: {
      status: toStatus,
      closedAt: toStatus === NCStatus.CLOTUREE ? new Date() : nc.closedAt,
    },
  });

  await tx.nonConformityStatusHistory.create({
    data: {
      nonConformityId: ncId,
      fromStatus: nc.status,
      toStatus,
      changedById,
      comment,
    },
  });

  return updated;
}
