import { Injectable } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { EpiMovementType, QualityControlStatus, DocumentStatus } from '@prisma/client';

type Alert = {
  level: 'CRITICAL' | 'WARNING' | 'INFO' | 'SUCCESS';
  icon: '🔴' | '🟠' | '🔵' | '🟢';
  domain: string;
  code: string | null;
  title: string;
  detail: string;
  dueDate: Date | null;
};

@Injectable()
export class DashboardService {
  constructor(private db: PrismaService) {}

  // ---------------------------------------------------------------------
  // Vue d'ensemble : compteurs par domaine (bloc du haut du tableau de bord)
  // ---------------------------------------------------------------------
  async overview() {
    const now = new Date();
    const in3Days = new Date(now); in3Days.setDate(in3Days.getDate() + 3);
    const in7Days = new Date(now); in7Days.setDate(in7Days.getDate() + 7);
    const in30Days = new Date(now); in30Days.setDate(in30Days.getDate() + 30);

    const [
      nonConformitiesOpen,
      nonConformitiesCritical,
      actionsOpen,
      actionsOverdue,
      actionsDueSoon,
      safetyEvents30d,
      safetyEventsBySeverity,
      risksHigh,
      risksTotal,
      qualityControlsSubmittedRange,
      qualityControlsNonCompliant,
      auditsPlanned,
      auditsUpcoming,
      documentsPendingApproval,
      trainingsExpiringSoon,
      equipmentOverdueInspection,
      epiRenewalsDue,
      environmentRecords30d,
    ] = await Promise.all([
      this.db.nonConformity.count({ where: { status: { not: 'CLOSED' } } }),
      this.db.nonConformity.count({ where: { status: { not: 'CLOSED' }, severity: { gte: 4 } } }),
      this.db.action.count({ where: { status: { not: 'CLOSED' } } }),
      this.db.action.count({ where: { status: { not: 'CLOSED' }, dueDate: { lt: now } } }),
      this.db.action.count({ where: { status: { not: 'CLOSED' }, dueDate: { gte: now, lte: in3Days } } }),
      this.db.safetyEvent.count({ where: { occurredAt: { gte: this.daysAgo(30) } } }),
      this.db.safetyEvent.groupBy({ by: ['severity'], _count: { _all: true } }),
      this.db.risk.count({ where: { status: 'ACTIVE', score: { gte: 9 } } }),
      this.db.risk.count({ where: { status: 'ACTIVE' } }),
      this.db.qualityControl.count({ where: { controlDate: { gte: this.daysAgo(30) }, status: { in: [QualityControlStatus.COMPLIANT, QualityControlStatus.NON_COMPLIANT] } } }),
      this.db.qualityControl.count({ where: { controlDate: { gte: this.daysAgo(30) }, status: QualityControlStatus.NON_COMPLIANT } }),
      this.db.qhseAudit.count({ where: { status: 'PLANNED' } }),
      this.db.qhseAudit.count({ where: { status: 'PLANNED', auditDate: { gte: now, lte: in7Days } } }),
      this.db.document.count({ where: { status: DocumentStatus.REVIEW } }),
      this.db.training.count({ where: { expiryAt: { gte: now, lte: in30Days } } }),
      this.db.equipment.count({ where: { nextInspectionAt: { lt: now } } }),
      this.db.epiAssignment.count({ where: { renewalAt: { gte: now, lte: in30Days } } }),
      this.db.environmentRecord.count({ where: { recordedAt: { gte: this.daysAgo(30) } } }),
    ]);

    const qualityComplianceRate = qualityControlsSubmittedRange > 0
      ? Math.round(((qualityControlsSubmittedRange - qualityControlsNonCompliant) / qualityControlsSubmittedRange) * 100)
      : null;

    return {
      generatedAt: now,
      counters: {
        nonConformitiesOpen,
        nonConformitiesCritical,
        actionsOpen,
        actionsOverdue,
        actionsDueSoon,
        safetyEvents30d,
        safetyEventsBySeverity: safetyEventsBySeverity.map((s: { severity: number; _count: { _all: number } }) => ({ severity: s.severity, count: s._count._all })),
        risksHigh,
        risksTotal,
        auditsPlanned,
        auditsUpcoming7d: auditsUpcoming,
        documentsPendingApproval,
        trainingsExpiringSoon,
        equipmentOverdueInspection,
        epiRenewalsDue30d: epiRenewalsDue,
        environmentRecords30d,
      },
      indicators: {
        qualite: {
          controlesSoumis30j: qualityControlsSubmittedRange,
          tauxConformite: qualityComplianceRate,
          nonConformitesOuvertes: nonConformitiesOpen,
          nonConformitesCritiques: nonConformitiesCritical,
        },
        securite: {
          evenements30j: safetyEvents30d,
          risquesEleves: risksHigh,
          risquesSuivis: risksTotal,
        },
        environnement: {
          releves30j: environmentRecords30d,
        },
        rh: {
          formationsExpirantSous30j: trainingsExpiringSoon,
          epiARenouvelerSous30j: epiRenewalsDue,
        },
      },
    };
  }

  // ---------------------------------------------------------------------
  // Tendances : évolution hebdomadaire NC / événements sécurité, et taux
  // de conformité qualité mensuel sur les 6 derniers mois.
  // ---------------------------------------------------------------------
  async trends(weeks = 8) {
    const since = new Date();
    since.setDate(since.getDate() - weeks * 7);

    const [ncList, eventList, controls] = await Promise.all([
      this.db.nonConformity.findMany({ where: { createdAt: { gte: since } }, select: { createdAt: true, severity: true } }),
      this.db.safetyEvent.findMany({ where: { occurredAt: { gte: since } }, select: { occurredAt: true, severity: true } }),
      this.db.qualityControl.findMany({
        where: { controlDate: { gte: this.monthsAgo(6) }, status: { in: [QualityControlStatus.COMPLIANT, QualityControlStatus.NON_COMPLIANT] } },
        select: { controlDate: true, status: true },
      }),
    ]);

    return {
      nonConformitesParSemaine: this.bucketByWeek(ncList.map((n: { createdAt: Date }) => n.createdAt), weeks),
      evenementsSecuriteParSemaine: this.bucketByWeek(eventList.map((e: { occurredAt: Date }) => e.occurredAt), weeks),
      tauxConformiteParMois: this.complianceByMonth(controls, 6),
    };
  }

  // ---------------------------------------------------------------------
  // Alertes prioritaires : liste unifiée toutes actions/domaines confondus,
  // triée par sévérité puis par échéance — c'est le bloc "🔴🟠🔵🟢" du mock.
  // ---------------------------------------------------------------------
  async alerts(): Promise<Alert[]> {
    const now = new Date();
    const in3Days = new Date(now); in3Days.setDate(in3Days.getDate() + 3);
    const in7Days = new Date(now); in7Days.setDate(in7Days.getDate() + 7);
    const in15Days = new Date(now); in15Days.setDate(in15Days.getDate() + 15);

    const [overdueActions, dueSoonActions, criticalNc, upcomingAudits, epiDue, overdueEquipment, pendingDocs] = await Promise.all([
      this.db.action.findMany({ where: { status: { not: 'CLOSED' }, dueDate: { lt: now } }, orderBy: { dueDate: 'asc' }, take: 20 }),
      this.db.action.findMany({ where: { status: { not: 'CLOSED' }, dueDate: { gte: now, lte: in3Days } }, orderBy: { dueDate: 'asc' }, take: 20 }),
      this.db.nonConformity.findMany({ where: { status: { not: 'CLOSED' }, severity: { gte: 4 } }, orderBy: { occurredAt: 'desc' }, take: 20 }),
      this.db.qhseAudit.findMany({ where: { status: 'PLANNED', auditDate: { gte: now, lte: in7Days } }, orderBy: { auditDate: 'asc' }, take: 20 }),
      this.db.epiAssignment.findMany({ where: { renewalAt: { gte: now, lte: in15Days } }, include: { employee: true, epi: true }, orderBy: { renewalAt: 'asc' }, take: 20 }),
      this.db.equipment.findMany({ where: { nextInspectionAt: { lt: now } }, orderBy: { nextInspectionAt: 'asc' }, take: 20 }),
      this.db.document.findMany({ where: { status: DocumentStatus.REVIEW }, orderBy: { updatedAt: 'asc' }, take: 20 }),
    ]);

    const alerts: Alert[] = [];

    for (const a of overdueActions) {
      const daysLate = Math.floor((now.getTime() - new Date(a.dueDate!).getTime()) / 86400000);
      alerts.push({ level: 'CRITICAL', icon: '🔴', domain: 'ACTION', code: a.code, title: a.title, detail: `retard ${daysLate} jour(s)`, dueDate: a.dueDate });
    }
    for (const a of dueSoonActions) {
      alerts.push({ level: 'WARNING', icon: '🟠', domain: 'ACTION', code: a.code, title: a.title, detail: 'échéance sous 3 jours', dueDate: a.dueDate });
    }
    for (const nc of criticalNc) {
      alerts.push({ level: 'CRITICAL', icon: '🔴', domain: 'NON_CONFORMITE', code: nc.code, title: nc.title, detail: `sévérité ${nc.severity}`, dueDate: null });
    }
    for (const au of upcomingAudits) {
      alerts.push({ level: 'WARNING', icon: '🟠', domain: 'AUDIT', code: au.code, title: au.title, detail: 'échéance sous 7 jours', dueDate: au.auditDate });
    }
    for (const e of epiDue) {
      alerts.push({ level: 'WARNING', icon: '🟠', domain: 'EPI', code: e.epi.code, title: `${e.epi.name} — ${e.employee.firstName} ${e.employee.lastName}`, detail: 'renouvellement à prévoir sous 15 jours', dueDate: e.renewalAt });
    }
    for (const eq of overdueEquipment) {
      alerts.push({ level: 'CRITICAL', icon: '🔴', domain: 'EQUIPEMENT', code: eq.code, title: eq.name, detail: 'inspection en retard', dueDate: eq.nextInspectionAt });
    }
    for (const d of pendingDocs) {
      alerts.push({ level: 'INFO', icon: '🔵', domain: 'DOCUMENT', code: d.code, title: d.title, detail: 'en attente de validation', dueDate: null });
    }

    const rank = { CRITICAL: 0, WARNING: 1, INFO: 2, SUCCESS: 3 } as const;
    alerts.sort((a, b) => rank[a.level] - rank[b.level] || (a.dueDate?.getTime() ?? Infinity) - (b.dueDate?.getTime() ?? Infinity));
    return alerts;
  }

  // ---------------------------------------------------------------------
  // Point d'entrée unique consommé par Flutter / le futur web : tout en un.
  // ---------------------------------------------------------------------
  async full() {
    const [overview, trends, alerts] = await Promise.all([this.overview(), this.trends(8), this.alerts()]);
    return { overview, trends, alerts };
  }

  // ------------------------------- utils --------------------------------
  private daysAgo(days: number) { const d = new Date(); d.setDate(d.getDate() - days); return d; }
  private monthsAgo(months: number) { const d = new Date(); d.setMonth(d.getMonth() - months); return d; }

  private bucketByWeek(dates: Date[], weeks: number) {
    const buckets: { weekStart: string; count: number }[] = [];
    const now = new Date();
    for (let i = weeks - 1; i >= 0; i--) {
      const start = new Date(now); start.setDate(start.getDate() - i * 7 - now.getDay());
      start.setHours(0, 0, 0, 0);
      const end = new Date(start); end.setDate(end.getDate() + 7);
      const count = dates.filter(d => d >= start && d < end).length;
      buckets.push({ weekStart: start.toISOString().slice(0, 10), count });
    }
    return buckets;
  }

  private complianceByMonth(controls: { controlDate: Date; status: QualityControlStatus }[], months: number) {
    const buckets: { month: string; total: number; compliant: number; rate: number | null }[] = [];
    const now = new Date();
    for (let i = months - 1; i >= 0; i--) {
      const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
      const next = new Date(now.getFullYear(), now.getMonth() - i + 1, 1);
      const inMonth = controls.filter(c => c.controlDate >= d && c.controlDate < next);
      const compliant = inMonth.filter(c => c.status === QualityControlStatus.COMPLIANT).length;
      buckets.push({
        month: `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`,
        total: inMonth.length,
        compliant,
        rate: inMonth.length > 0 ? Math.round((compliant / inMonth.length) * 100) : null,
      });
    }
    return buckets;
  }
}
