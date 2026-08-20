import type { Prisma, PrismaClient } from "@prisma/client";
import { RiskLevel, SeverityLevel } from "@prisma/client";

type Tx = Prisma.TransactionClient | PrismaClient;

export interface SuggestedTopic {
  title: string;
  content: string;
  sourceType: "SAFETY_EVENT" | "RISK" | "NON_CONFORMITY";
  sourceId: string;
}

/**
 * Construit des propositions de sujets de quart d'heure sécurité à partir
 * des événements sécurité, risques et non-conformités récents et graves.
 * Volontairement basé sur des règles déterministes (pas d'appel à une IA
 * générative) : le contenu doit rester factuel, traçable et vérifiable
 * pour un usage QHSE/ISO — chaque sujet renvoie explicitement à sa source.
 */
export async function suggestBriefingTopics(
  tx: Tx,
  params: { siteId?: string; productionLineId?: string; sinceDays?: number; limit?: number }
): Promise<SuggestedTopic[]> {
  const since = new Date(Date.now() - (params.sinceDays ?? 30) * 86_400_000);
  const limit = params.limit ?? 5;

  const [safetyEvents, risks, nonConformities] = await Promise.all([
    tx.safetyEvent.findMany({
      where: {
        reportedAt: { gte: since },
        severity: { in: [SeverityLevel.MAJEURE, SeverityLevel.CATASTROPHIQUE, SeverityLevel.MODEREE] },
        siteId: params.siteId,
        productionLineId: params.productionLineId,
      },
      orderBy: { reportedAt: "desc" },
      take: limit,
    }),
    tx.risk.findMany({
      where: {
        identifiedAt: { gte: since },
        initialLevel: { in: [RiskLevel.ELEVE, RiskLevel.CRITIQUE] },
        siteId: params.siteId,
        productionLineId: params.productionLineId,
      },
      orderBy: { identifiedAt: "desc" },
      take: limit,
    }),
    tx.nonConformity.findMany({
      where: {
        detectedAt: { gte: since },
        severity: { in: ["MAJEURE", "CRITIQUE"] },
        productionLineId: params.productionLineId,
      },
      orderBy: { detectedAt: "desc" },
      take: limit,
    }),
  ]);

  const topics: SuggestedTopic[] = [];

  for (const e of safetyEvents) {
    topics.push({
      title: `Rappel sécurité : ${e.title}`,
      content:
        `Le ${e.reportedAt.toLocaleDateString("fr-FR")}, un événement de type ${e.type} ` +
        `(gravité ${e.severity}) a été signalé : ${e.description}\n\n` +
        `Points à rappeler à l'équipe : identifier les situations similaires sur le poste, ` +
        `respecter les consignes de sécurité associées, et signaler immédiatement toute anomalie comparable.`,
      sourceType: "SAFETY_EVENT",
      sourceId: e.id,
    });
  }

  for (const r of risks) {
    topics.push({
      title: `Risque à surveiller : ${r.title}`,
      content:
        `Un risque de niveau ${r.initialLevel} a été identifié le ${r.identifiedAt.toLocaleDateString("fr-FR")} ` +
        `(catégorie ${r.category})${r.description ? " : " + r.description : "."}\n\n` +
        `Points à rappeler à l'équipe : mesures de maîtrise en place, comportements attendus, ` +
        `et procédure à suivre en cas de constat similaire.`,
      sourceType: "RISK",
      sourceId: r.id,
    });
  }

  for (const nc of nonConformities) {
    topics.push({
      title: `Non-conformité récente : ${nc.category}`,
      content:
        `Une non-conformité de sévérité ${nc.severity} a été détectée le ${nc.detectedAt.toLocaleDateString("fr-FR")} : ` +
        `${nc.description}\n\n` +
        `Points à rappeler à l'équipe : bonnes pratiques de contrôle associées, ` +
        `et importance de la remontée immédiate de toute anomalie.`,
      sourceType: "NON_CONFORMITY",
      sourceId: nc.id,
    });
  }

  return topics;
}
