import { SafetyEventStatus } from "@prisma/client";
import type { Prisma, PrismaClient } from "@prisma/client";

type Tx = Prisma.TransactionClient | PrismaClient;

const ALLOWED_TRANSITIONS: Record<SafetyEventStatus, SafetyEventStatus[]> = {
  SIGNALE: [SafetyEventStatus.EN_EXAMEN, SafetyEventStatus.REJETE],
  EN_EXAMEN: [SafetyEventStatus.EN_INVESTIGATION, SafetyEventStatus.ACTION_REQUISE, SafetyEventStatus.REJETE],
  EN_INVESTIGATION: [SafetyEventStatus.ACTION_REQUISE, SafetyEventStatus.RESOLU],
  ACTION_REQUISE: [SafetyEventStatus.RESOLU],
  RESOLU: [SafetyEventStatus.CLOTURE, SafetyEventStatus.EN_INVESTIGATION],
  CLOTURE: [],
  REJETE: [],
};

export class SafetyEventTransitionError extends Error {}

export async function transitionSafetyEvent(
  tx: Tx,
  eventId: string,
  toStatus: SafetyEventStatus,
  changedById: string,
  comment?: string
) {
  const event = await tx.safetyEvent.findUnique({ where: { id: eventId } });
  if (!event) throw new SafetyEventTransitionError("Événement introuvable");

  const allowed = ALLOWED_TRANSITIONS[event.status] ?? [];
  if (!allowed.includes(toStatus)) {
    throw new SafetyEventTransitionError(
      `Transition ${event.status} → ${toStatus} non autorisée. Transitions possibles : ${allowed.join(", ") || "aucune"}`
    );
  }

  const updated = await tx.safetyEvent.update({ where: { id: eventId }, data: { status: toStatus } });

  await tx.safetyEventStatusHistory.create({
    data: { safetyEventId: eventId, fromStatus: event.status, toStatus, changedById, comment },
  });

  return updated;
}
