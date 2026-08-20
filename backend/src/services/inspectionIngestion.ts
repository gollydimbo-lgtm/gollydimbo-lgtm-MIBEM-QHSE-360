import type { Prisma, PrismaClient } from "@prisma/client";
import { ActionPriority, ActionStatus } from "@prisma/client";
import { ref } from "../lib/ref.js";

type Tx = Prisma.TransactionClient | PrismaClient;

const DEFAULT_ACTION_DELAY_DAYS = 7;

interface CreateInspectionInput {
  templateId: string;
  siteId?: string;
  productionLineId?: string;
  machineId?: string;
  comments?: string;
  results: Array<{ inspectionPointId: string; result: string; observation?: string }>;
}

/**
 * Crée une inspection et ses résultats en une fois (comme pour Control).
 * Un point CRITIQUE relevé NON_CONFORME déclenche automatiquement une
 * action corrective.
 */
export async function ingestInspection(tx: Tx, inspectorId: string, input: CreateInspectionInput) {
  const inspection = await tx.inspection.create({
    data: {
      reference: ref("INSP"),
      templateId: input.templateId,
      inspectorId,
      siteId: input.siteId,
      productionLineId: input.productionLineId,
      machineId: input.machineId,
      comments: input.comments,
    },
  });

  const autoActionIds: string[] = [];

  for (const item of input.results) {
    const point = await tx.inspectionPoint.findUnique({ where: { id: item.inspectionPointId } });

    await tx.inspectionResult.create({
      data: {
        inspectionId: inspection.id,
        inspectionPointId: item.inspectionPointId,
        result: item.result as any,
        observation: item.observation,
      },
    });

    if (item.result === "NON_CONFORME" && point?.isCritical) {
      const dueDate = new Date(Date.now() + DEFAULT_ACTION_DELAY_DAYS * 86_400_000);
      const action = await tx.action.create({
        data: {
          reference: ref("ACT"),
          originType: "INSPECTION",
          originId: inspection.id,
          title: `Traiter le point critique — inspection ${inspection.reference}`,
          description: item.observation ?? `Point critique non conforme : ${point?.description ?? item.inspectionPointId}`,
          actionType: "CORRECTIVE",
          priority: ActionPriority.HAUTE,
          responsibleId: inspectorId,
          dueDate,
          status: ActionStatus.OUVERTE,
          sources: { create: { sourceType: "INSPECTION", sourceId: inspection.id } },
          history: {
            create: {
              fromStatus: null,
              toStatus: ActionStatus.OUVERTE,
              changedById: inspectorId,
              comment: "Création automatique : point critique non conforme lors d'une inspection",
            },
          },
        },
      });
      autoActionIds.push(action.id);
    }
  }

  const full = await tx.inspection.findUniqueOrThrow({
    where: { id: inspection.id },
    include: { results: { include: { inspectionPoint: true } } },
  });

  return { inspection: full, autoActionIds };
}
