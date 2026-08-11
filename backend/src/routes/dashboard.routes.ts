import { Router } from "express";
import { ActionStatus, ControlResultValue, NCSeverity, NCStatus } from "@prisma/client";
import { prisma } from "../lib/prisma.js";

export const dashboardRouter = Router();

dashboardRouter.get("/overview", async (_req, res) => {
  const now = new Date();
  const [controls, results, nc, criticalNc, openNc, actions, overdueActions, pendingSync] = await Promise.all([
    prisma.control.count(),
    prisma.controlResult.count(),
    prisma.nonConformity.count(),
    prisma.nonConformity.count({ where: { severity: NCSeverity.CRITIQUE } }),
    prisma.nonConformity.count({ where: { status: { not: NCStatus.CLOTUREE } } }),
    prisma.action.count(),
    prisma.action.count({ where: { status: ActionStatus.EN_RETARD } }),
    prisma.control.count({ where: { syncStatus: "PENDING" } }),
  ]);

  const conformes = await prisma.controlResult.count({ where: { result: ControlResultValue.CONFORME } });
  const complianceRate = results === 0 ? 100 : Number(((conformes / results) * 100).toFixed(2));

  const byLine = await prisma.nonConformity.groupBy({
    by: ["productionLineId"],
    _count: { id: true },
    orderBy: { _count: { id: "desc" } },
  });

  res.json({
    controls,
    results,
    nonConformities: nc,
    criticalNonConformities: criticalNc,
    openNonConformities: openNc,
    actions,
    overdueActions,
    pendingSync,
    complianceRate,
    nonConformitiesByLine: byLine,
  });
});

/**
 * Pareto des non-conformités par catégorie (les 20% de causes qui expliquent
 * 80% des NC) — rejoint directement la logique SPC utilisée dans le mémoire.
 */
dashboardRouter.get("/pareto", async (req, res) => {
  const { from, to } = req.query;
  const grouped = await prisma.nonConformity.groupBy({
    by: ["category"],
    where: {
      detectedAt: {
        gte: typeof from === "string" ? new Date(from) : undefined,
        lte: typeof to === "string" ? new Date(to) : undefined,
      },
    },
    _count: { id: true },
    orderBy: { _count: { id: "desc" } },
  });

  const total = grouped.reduce((sum, g) => sum + g._count.id, 0);
  let cumulative = 0;
  const pareto = grouped.map((g) => {
    cumulative += g._count.id;
    return {
      category: g.category,
      count: g._count.id,
      percentage: total === 0 ? 0 : Number(((g._count.id / total) * 100).toFixed(1)),
      cumulativePercentage: total === 0 ? 0 : Number(((cumulative / total) * 100).toFixed(1)),
    };
  });

  res.json({ total, pareto });
});

/**
 * Tendance du taux de conformité par jour, sur les N derniers jours (30 par
 * défaut) — pour tracer une "carte" simple d'évolution dans le dashboard.
 */
dashboardRouter.get("/trend", async (req, res) => {
  const days = Number(req.query.days ?? 30);
  const since = new Date(Date.now() - days * 86_400_000);

  const results = await prisma.controlResult.findMany({
    where: { createdAt: { gte: since } },
    select: { result: true, createdAt: true },
  });

  const byDay = new Map<string, { total: number; conformes: number }>();
  for (const r of results) {
    const day = r.createdAt.toISOString().slice(0, 10);
    const entry = byDay.get(day) ?? { total: 0, conformes: 0 };
    entry.total += 1;
    if (r.result === ControlResultValue.CONFORME) entry.conformes += 1;
    byDay.set(day, entry);
  }

  const trend = [...byDay.entries()]
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([day, { total, conformes }]) => ({
      day,
      total,
      complianceRate: total === 0 ? 100 : Number(((conformes / total) * 100).toFixed(2)),
    }));

  res.json({ trend });
});
