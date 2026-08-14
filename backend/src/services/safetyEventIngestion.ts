import type { Prisma, PrismaClient } from "@prisma/client";
import { ActionPriority, ActionStatus, InvestigationStatus, SafetyEventStatus, SeverityLevel } from "@prisma/client";
import { ref } from "../lib/ref.js";

type Tx = Prisma.TransactionClient | PrismaClient;

interface CreateSafetyEventInput {
  type: string;
  title: string;
  description: string;
  severity: string;
  probability?: string;
  siteId?: string;
  productionLineId?: string;
  machineId?: string;
  locationDescription?: string;
  latitude?: number;
  longitude?: number;
  injuryType?: string;
  lostWorkDays?: number;
  actionDueDate?: string;
}

const DEFAULT_ACTION_DELAY_DAYS = 7;
const SEVERE_LEVELS = new Set<SeverityLevel>([SeverityLevel.MAJEURE, SeverityLevel.CATASTROPHIQUE]);

function severityToPriority(severity: SeverityLevel): ActionPriority {
  switch (severity) {
    case SeverityLevel.CATASTROPHIQUE:
      return ActionPriority.CRITIQUE;
    case SeverityLevel.MAJEURE:
      return ActionPriority.HAUTE;
    case SeverityLevel.MODEREE:
      return ActionPriority.MOYENNE;
    default:
      return ActionPriority.BASSE;
  }
}

/**
 * Crée un événement sécurité (situation dangereuse, incident, presqu'accident,
 * accident). Une gravité MAJEURE ou CATASTROPHIQUE déclenche automatiquement :
 * le passage en investigation requise, et la création d'une action corrective
 * (même moteur central Action/ActionSource/ActionHistory que pour les NC et
 * les risques).
 */
export async function ingestSafetyEvent(tx: Tx, reportedById: string, input: CreateSafetyEventInput) {
  const severity = input.severity as SeverityLevel;
  const isSevere = SEVERE_LEVELS.has(severity);

  const event = await tx.safetyEvent.create({
    data: {
      reference: ref("HSE"),
      type: input.type as any,
      status: isSevere ? SafetyEventStatus.ACTION_REQUISE : SafetyEventStatus.SIGNALE,
      title: input.title,
      description: input.description,
      severity: severity as any,
      probability: input.probability as any,
      siteId: input.siteId,
      productionLineId: input.productionLineId,
      machineId: input.machineId,
      locationDescription: input.locationDescription,
      latitude: input.latitude,
      longitude: input.longitude,
      injuryType: (input.injuryType as any) ?? undefined,
      lostWorkDays: input.lostWorkDays ?? 0,
      reportedById,
      investigationStatus: isSevere ? InvestigationStatus.OUVERTE : InvestigationStatus.NON_REQUISE,
    },
  });

  await tx.safetyEventStatusHistory.create({
    data: {
      safetyEventId: event.id,
      fromStatus: SafetyEventStatus.SIGNALE,
      toStatus: event.status,
      changedById: reportedById,
      comment: isSevere ? "Gravité élevée : investigation et action requises automatiquement" : "Signalement initial",
    },
  });

  let autoActionId: string | null = null;
  if (isSevere) {
    const dueDate = input.actionDueDate
      ? new Date(input.actionDueDate)
      : new Date(Date.now() + DEFAULT_ACTION_DELAY_DAYS * 86_400_000);

    const action = await tx.action.create({
      data: {
        reference: ref("ACT"),
        originType: "SAFETY_EVENT",
        originId: event.id,
        title: `Traiter l'événement ${event.reference}`,
        description: `Action corrective requise suite à : ${input.title} (gravité ${severity})`,
        actionType: "CORRECTIVE",
        priority: severityToPriority(severity),
        responsibleId: reportedById,
        dueDate,
        status: ActionStatus.OUVERTE,
        sources: { create: { sourceType: "SAFETY_EVENT", sourceId: event.id } },
        history: {
          create: {
            fromStatus: null,
            toStatus: ActionStatus.OUVERTE,
            changedById: reportedById,
            comment: "Création automatique suite à événement sécurité de gravité élevée",
          },
        },
      },
    });
    autoActionId = action.id;
  }

  const full = await tx.safetyEvent.findUniqueOrThrow({
    where: { id: event.id },
    include: { witnesses: true, injuries: true, causes: true, statusHistory: true },
  });

  return { event: full, autoActionId };
}
