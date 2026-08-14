import cron from "node-cron";
import { ActionStatus } from "@prisma/client";
import { prisma } from "../lib/prisma.js";

const SYSTEM_ACTOR = "SYSTEM";

/**
 * Toutes les heures : bascule en EN_RETARD les actions dont l'échéance
 * est dépassée et qui ne sont ni terminées ni clôturées.
 * Dès que l'utilisateur fait avancer une action EN_RETARD (voir
 * actionTransitions.ts), elle en ressort naturellement.
 *
 * Chaque bascule est aussi historisée dans ActionHistory (V3), avec
 * changedById = "SYSTEM" pour la distinguer d'une action humaine.
 */
export async function markOverdueActions() {
  const now = new Date();
  const overdue = await prisma.action.findMany({
    where: {
      dueDate: { lt: now },
      status: { notIn: [ActionStatus.TERMINEE, ActionStatus.CLOTUREE, ActionStatus.EN_RETARD] },
    },
    select: { id: true, status: true },
  });

  if (overdue.length === 0) return 0;

  await prisma.$transaction([
    prisma.action.updateMany({
      where: { id: { in: overdue.map((a) => a.id) } },
      data: { status: ActionStatus.EN_RETARD },
    }),
    prisma.actionHistory.createMany({
      data: overdue.map((a) => ({
        actionId: a.id,
        fromStatus: a.status,
        toStatus: ActionStatus.EN_RETARD,
        changedById: SYSTEM_ACTOR,
        comment: "Basculée automatiquement : échéance dépassée",
      })),
    }),
  ]);

  console.log(`[overdue-job] ${overdue.length} action(s) basculée(s) en EN_RETARD`);
  return overdue.length;
}

export function startOverdueActionsJob() {
  // Toutes les heures, à la minute 0
  cron.schedule("0 * * * *", () => {
    markOverdueActions().catch((err) => console.error("[overdue-job] échec :", err));
  });
  // Passage immédiat au démarrage pour ne pas attendre la première heure pleine
  markOverdueActions().catch((err) => console.error("[overdue-job] échec initial :", err));
}
