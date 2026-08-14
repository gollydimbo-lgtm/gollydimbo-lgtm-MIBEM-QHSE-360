import { RiskStatus } from "@prisma/client";
import type { Prisma, PrismaClient } from "@prisma/client";

type Tx = Prisma.TransactionClient | PrismaClient;

const ALLOWED_TRANSITIONS: Record<RiskStatus, RiskStatus[]> = {
  IDENTIFIE: [RiskStatus.EVALUE],
  EVALUE: [RiskStatus.TRAITEMENT_REQUIS, RiskStatus.ACCEPTE, RiskStatus.MAITRISE],
  TRAITEMENT_REQUIS: [RiskStatus.TRAITEMENT_EN_COURS],
  TRAITEMENT_EN_COURS: [RiskStatus.MAITRISE, RiskStatus.EVALUE],
  ACCEPTE: [RiskStatus.CLOTURE, RiskStatus.EVALUE],
  MAITRISE: [RiskStatus.CLOTURE, RiskStatus.EVALUE],
  CLOTURE: [],
};

export class RiskTransitionError extends Error {}

export async function transitionRisk(
  tx: Tx,
  riskId: string,
  toStatus: RiskStatus,
  changedById: string,
  comment?: string
) {
  const risk = await tx.risk.findUnique({ where: { id: riskId } });
  if (!risk) throw new RiskTransitionError("Risque introuvable");

  const allowed = ALLOWED_TRANSITIONS[risk.status] ?? [];
  if (!allowed.includes(toStatus)) {
    throw new RiskTransitionError(
      `Transition ${risk.status} → ${toStatus} non autorisée. Transitions possibles : ${allowed.join(", ") || "aucune"}`
    );
  }

  const updated = await tx.risk.update({ where: { id: riskId }, data: { status: toStatus } });

  await tx.riskStatusHistory.create({
    data: { riskId, fromStatus: risk.status, toStatus, changedById, comment },
  });

  return updated;
}
