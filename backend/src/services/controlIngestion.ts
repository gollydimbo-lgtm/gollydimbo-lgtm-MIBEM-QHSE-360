import type { Prisma, PrismaClient } from "@prisma/client";
import { ActionPriority, ActionStatus, NCSeverity, NCStatus } from "@prisma/client";
import { ref } from "../lib/ref.js";
import type { z } from "zod";
import type { createControlSchema } from "../validation/schemas.js";

type ControlInput = z.infer<typeof createControlSchema>;
type Tx = Prisma.TransactionClient | PrismaClient;

const DEFAULT_NC_DELAY_DAYS = 7;

function severityToPriority(severity: NCSeverity): ActionPriority {
  switch (severity) {
    case "CRITIQUE":
      return ActionPriority.CRITIQUE;
    case "MAJEURE":
      return ActionPriority.HAUTE;
    default:
      return ActionPriority.MOYENNE;
  }
}

/**
 * Crée un contrôle, ses résultats, et pour chaque résultat NON_CONFORME :
 * une non-conformité + une action corrective, atomiquement.
 *
 * Sécurité : `controllerId` est toujours celui de l'utilisateur authentifié
 * (paramètre explicite, dérivé du JWT), jamais une valeur fournie par le
 * client dans le payload — sinon n'importe quel appelant pourrait déclarer
 * un contrôle au nom d'un autre contrôleur.
 *
 * Règle métier : la sévérité par défaut d'une NC est dérivée du caractère
 * "critique" du point de contrôle (ControlPoint.isCritical) plutôt que
 * codée en dur, sauf si le payload force explicitement une sévérité.
 *
 * Idempotence : si `clientLocalId` correspond à un contrôle déjà synchronisé
 * (cas d'un renvoi réseau après une sync réussie mais un accusé perdu côté
 * mobile), on renvoie le contrôle existant sans dupliquer NC/actions.
 */
export async function ingestControl(
  tx: Tx,
  controllerId: string,
  input: ControlInput,
  resultOverride?: { syncStatus?: "SYNCED" | "PENDING" }
) {
  if (input.clientLocalId) {
    const existing = await tx.control.findUnique({
      where: { clientLocalId: input.clientLocalId },
      include: fullControlInclude,
    });
    if (existing) return { control: existing, deduplicated: true as const };
  }

  const control = await tx.control.create({
    data: {
      reference: ref("CTR"),
      clientLocalId: input.clientLocalId,
      controllerId,
      productionLineId: input.productionLineId,
      machineId: input.machineId,
      productId: input.productId,
      formatId: input.formatId,
      packagingTypeId: input.packagingTypeId,
      shiftId: input.shiftId,
      comments: input.comments,
      latitude: input.latitude,
      longitude: input.longitude,
      deviceId: input.deviceId,
      controlDate: input.controlDate ? new Date(input.controlDate) : undefined,
      syncStatus: resultOverride?.syncStatus ?? "SYNCED",
    },
  });

  for (const item of input.results) {
    const controlPoint = await tx.controlPoint.findUnique({ where: { id: item.controlPointId } });

    const result = await tx.controlResult.create({
      data: {
        controlId: control.id,
        controlPointId: item.controlPointId,
        result: item.result,
        numericValue: item.numericValue,
        textValue: item.textValue,
        observation: item.observation,
      },
    });

    if (item.result !== "NON_CONFORME") continue;

    const severity: NCSeverity = item.severity ?? (controlPoint?.isCritical ? NCSeverity.CRITIQUE : NCSeverity.MAJEURE);
    const dueDate = item.dueDate ? new Date(item.dueDate) : new Date(Date.now() + DEFAULT_NC_DELAY_DAYS * 86_400_000);

    const nc = await tx.nonConformity.create({
      data: {
        reference: ref("NC"),
        controlResultId: result.id,
        controlId: control.id,
        detectedById: controllerId,
        productionLineId: input.productionLineId,
        machineId: input.machineId,
        productId: input.productId,
        category: item.category ?? "CONTRÔLE LIGNE",
        description: item.observation ?? `Non-conformité détectée sur le point ${controlPoint?.code ?? item.controlPointId}`,
        severity,
        responsibleId: item.responsibleId ?? controllerId,
        dueDate,
        status: NCStatus.OUVERTE,
      },
    });

    await tx.nonConformityStatusHistory.create({
      data: {
        nonConformityId: nc.id,
        fromStatus: NCStatus.OUVERTE,
        toStatus: NCStatus.OUVERTE,
        changedById: controllerId,
        comment: "Création automatique suite à contrôle terrain",
      },
    });

    await tx.action.create({
      data: {
        reference: ref("ACT"),
        originType: "NON_CONFORMITY",
        originId: nc.id,
        nonConformityId: nc.id,
        description: item.action ?? `Traiter la NC ${nc.reference} : ${nc.description}`,
        actionType: "CORRECTIVE",
        priority: severityToPriority(severity),
        responsibleId: item.responsibleId ?? controllerId,
        dueDate,
        status: ActionStatus.OUVERTE,
      },
    });
  }

  const full = await tx.control.findUniqueOrThrow({ where: { id: control.id }, include: fullControlInclude });
  return { control: full, deduplicated: false as const };
}

export const fullControlInclude = {
  results: { include: { controlPoint: true, nonConformity: { include: { actions: true } } } },
  attachments: true,
} satisfies Prisma.ControlInclude;
