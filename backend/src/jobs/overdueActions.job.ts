import cron from "node-cron";
import { ActionStatus } from "@prisma/client";
import { prisma } from "../lib/prisma.js";

/**
 * Toutes les heures : bascule en EN_RETARD les actions dont l'échéance
 * est dépassée et qui ne sont ni terminées ni clôturées.
 * Dès que l'utilisateur fait avancer une action EN_RETARD (voir
 * actionTransitions.ts), elle en ressort naturellement.
 */
export async function markOverdueActions() {
  const now = new Date();
  const result = await prisma.action.updateMany({
    where: {
      dueDate: { lt: now },
      status: { notIn: [ActionStatus.TERMINEE, ActionStatus.CLOTUREE, ActionStatus.EN_RETARD] },
    },
    data: { status: ActionStatus.EN_RETARD },
  });
  if (result.count > 0) {
    console.log(`[overdue-job] ${result.count} action(s) basculée(s) en EN_RETARD`);
  }
  return result.count;
}

export function startOverdueActionsJob() {
  // Toutes les heures, à la minute 0
  cron.schedule("0 * * * *", () => {
    markOverdueActions().catch((err) => console.error("[overdue-job] échec :", err));
  });
  // Passage immédiat au démarrage pour ne pas attendre la première heure pleine
  markOverdueActions().catch((err) => console.error("[overdue-job] échec initial :", err));
}
