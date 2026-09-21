import { Injectable } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { BusinessService } from '../business/business.service';
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
  constructor(private db: PrismaService, private business: BusinessService) {}

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
      formationsEnRetard,
      formationsObligatoiresNonRealisees,
      habilitationsExpirees,
      besoinsFormationEnAttente,
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
      this.db.training.count({ where: { status: { notIn: ['REALISEE', 'CLOTUREE', 'ANNULEE'] }, scheduledAt: { lt: now } } }),
      this.db.training.count({ where: { obligatoire: true, status: { notIn: ['REALISEE', 'CLOTUREE'] } } }),
      this.db.habilitation.count({ where: { dateExpiration: { lt: now } } }),
      this.db.besoinFormation.count({ where: { statut: 'PROPOSE' } }),
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
        formationsEnRetard,
        formationsObligatoiresNonRealisees,
        habilitationsExpirees,
        besoinsFormationEnAttente,
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
    const in30Days = new Date(now); in30Days.setDate(in30Days.getDate() + 30);

    const [overdueActions, dueSoonActions, criticalNc, upcomingAudits, epiDue, overdueEquipment, pendingDocs, overdueTrainings, expiringHabilitations] = await Promise.all([
      this.db.action.findMany({ where: { status: { not: 'CLOSED' }, dueDate: { lt: now } }, orderBy: { dueDate: 'asc' }, take: 20 }),
      this.db.action.findMany({ where: { status: { not: 'CLOSED' }, dueDate: { gte: now, lte: in3Days } }, orderBy: { dueDate: 'asc' }, take: 20 }),
      this.db.nonConformity.findMany({ where: { status: { not: 'CLOSED' }, severity: { gte: 4 } }, orderBy: { occurredAt: 'desc' }, take: 20 }),
      this.db.qhseAudit.findMany({ where: { status: 'PLANNED', auditDate: { gte: now, lte: in7Days } }, orderBy: { auditDate: 'asc' }, take: 20 }),
      this.db.epiAssignment.findMany({ where: { renewalAt: { gte: now, lte: in15Days } }, include: { employee: true, epi: true }, orderBy: { renewalAt: 'asc' }, take: 20 }),
      this.db.equipment.findMany({ where: { nextInspectionAt: { lt: now } }, orderBy: { nextInspectionAt: 'asc' }, take: 20 }),
      this.db.document.findMany({ where: { status: DocumentStatus.REVIEW }, orderBy: { updatedAt: 'asc' }, take: 20 }),
      this.db.training.findMany({ where: { status: { notIn: ['REALISEE', 'CLOTUREE', 'ANNULEE'] }, scheduledAt: { lt: now } }, orderBy: { scheduledAt: 'asc' }, take: 20 }),
      this.db.habilitation.findMany({ where: { dateExpiration: { lte: in30Days } }, include: { employee: true }, orderBy: { dateExpiration: 'asc' }, take: 20 }),
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
    for (const t of overdueTrainings) {
      alerts.push({ level: t.obligatoire ? 'CRITICAL' : 'WARNING', icon: t.obligatoire ? '🔴' : '🟠', domain: 'FORMATION', code: t.code, title: t.title, detail: t.obligatoire ? 'formation obligatoire en retard' : 'formation en retard', dueDate: t.scheduledAt });
    }
    for (const h of expiringHabilitations) {
      const late = h.dateExpiration && h.dateExpiration < now;
      alerts.push({ level: late ? 'CRITICAL' : 'WARNING', icon: late ? '🔴' : '🟠', domain: 'HABILITATION', code: h.code, title: `${h.intitule} — ${h.employee.firstName} ${h.employee.lastName}`, detail: late ? 'habilitation expirée' : 'habilitation arrivant à échéance sous 30 jours', dueDate: h.dateExpiration });
    }
    const besoinsEnAttente = await this.db.besoinFormation.count({ where: { statut: 'PROPOSE' } });
    if (besoinsEnAttente > 0) {
      alerts.push({ level: 'INFO', icon: '🔵', domain: 'FORMATION', code: null, title: `${besoinsEnAttente} besoin(s) de formation en attente de validation`, detail: 'proposés par le moteur de détection', dueDate: null });
    }

    const rank = { CRITICAL: 0, WARNING: 1, INFO: 2, SUCCESS: 3 } as const;
    alerts.sort((a, b) => rank[a.level] - rank[b.level] || (a.dueDate?.getTime() ?? Infinity) - (b.dueDate?.getTime() ?? Infinity));
    return alerts;
  }

  // ---------------------------------------------------------------------
  // Score composite QHSE : agrège qualité / sécurité / risques / actions
  // en un seul indicateur, en s'appuyant UNIQUEMENT sur des données déjà
  // saisies dans l'application. Règle absolue : jamais de valeur inventée.
  // Quand un domaine n'a pas assez de données pour être noté, on l'exclut
  // du calcul et on le signale explicitement (DONNEES_INSUFFISANTES),
  // au lieu de lui attribuer 0% ou de le passer sous silence.
  // ---------------------------------------------------------------------
  async score() {
    const ov = await this.overview();
    const { counters, indicators } = ov;

    const domaines: Record<string, { score: number | null; poids: number; fiabilite: 'DONNEES_SUFFISANTES' | 'DONNEES_INSUFFISANTES'; detail: string }> = {};

    // Qualité : taux de conformité des contrôles des 30 derniers jours.
    // Sous 5 contrôles soumis, l'échantillon est jugé trop faible pour noter.
    const controlesSoumis = indicators.qualite.controlesSoumis30j;
    const SEUIL_MIN_CONTROLES = 5;
    domaines.qualite = controlesSoumis >= SEUIL_MIN_CONTROLES
      ? { score: indicators.qualite.tauxConformite, poids: 0.35, fiabilite: 'DONNEES_SUFFISANTES', detail: `${controlesSoumis} contrôle(s) qualité soumis sur 30 jours` }
      : { score: null, poids: 0.35, fiabilite: 'DONNEES_INSUFFISANTES', detail: controlesSoumis === 0 ? 'Aucun contrôle qualité soumis sur 30 jours' : `Seulement ${controlesSoumis} contrôle(s) qualité soumis sur 30 jours (${SEUIL_MIN_CONTROLES} minimum requis)` };

    // Sécurité : indicateur basé sur un comptage d'événements. Un comptage est
    // toujours une donnée réelle (0 événement = vraiment 0), jamais "insuffisant".
    const evenements = counters.safetyEvents30d;
    domaines.securite = { score: Math.max(0, 100 - evenements * 10), poids: 0.25, fiabilite: 'DONNEES_SUFFISANTES', detail: `${evenements} événement(s) sécurité sur 30 jours` };

    // Risques maîtrisés : part des risques actifs qui ne sont PAS élevés.
    // Si le registre des risques est vide, ce n'est pas "0% de risque" : c'est
    // une absence de donnée à distinguer d'un vrai résultat.
    domaines.risques = counters.risksTotal > 0
      ? { score: Math.round(((counters.risksTotal - counters.risksHigh) / counters.risksTotal) * 100), poids: 0.20, fiabilite: 'DONNEES_SUFFISANTES', detail: `${counters.risksHigh} risque(s) élevé(s) sur ${counters.risksTotal} suivi(s)` }
      : { score: null, poids: 0.20, fiabilite: 'DONNEES_INSUFFISANTES', detail: 'Aucun risque suivi dans le registre' };

    // Actions correctives à jour : part des actions ouvertes qui ne sont pas en
    // retard. Zéro action ouverte est une vraie situation favorable (score 100),
    // pas une donnée manquante.
    domaines.actions = counters.actionsOpen > 0
      ? { score: Math.round(((counters.actionsOpen - counters.actionsOverdue) / counters.actionsOpen) * 100), poids: 0.20, fiabilite: 'DONNEES_SUFFISANTES', detail: `${counters.actionsOverdue} action(s) en retard sur ${counters.actionsOpen} ouverte(s)` }
      : { score: 100, poids: 0.20, fiabilite: 'DONNEES_SUFFISANTES', detail: 'Aucune action ouverte' };

    const domainesNotes = Object.values(domaines).filter((d) => d.score != null);
    const poidsTotal = domainesNotes.reduce((s, d) => s + d.poids, 0);
    const global = poidsTotal > 0
      ? Math.round(domainesNotes.reduce((s, d) => s + (d.score as number) * d.poids, 0) / poidsTotal)
      : null;

    const nbDomaines = Object.keys(domaines).length;
    const nbDomainesFiables = Object.values(domaines).filter((d) => d.fiabilite === 'DONNEES_SUFFISANTES').length;
    const confiance: 'ELEVEE' | 'MOYENNE' | 'FAIBLE' =
      nbDomainesFiables === nbDomaines ? 'ELEVEE' : nbDomainesFiables >= nbDomaines / 2 ? 'MOYENNE' : 'FAIBLE';

    return { global, confiance, domaines };
  }

  // ---------------------------------------------------------------------
  // Analyses cross-module : Pareto et récurrences. Ces moteurs existent déjà
  // dans les services métier (safetyEventsStats pour le Pareto des causes
  // racines sécurité, ncSyntheseDirection pour les processus les plus
  // problématiques et les non-conformités récurrentes) — on les RÉUTILISE
  // ici plutôt que de recalculer la même chose, pour que le Cockpit central
  // regroupe l'information au lieu de la dupliquer.
  // ---------------------------------------------------------------------
  async analyses() {
    const [ncSynthese, securite] = await Promise.all([
      this.business.ncSyntheseDirection(),
      this.business.safetyEventsStats(),
    ]);
    return {
      nonConformites: {
        processusLesPlusProblematiques: ncSynthese.processusLesPlusProblematiques,
        recurrences: ncSynthese.principalesRecurrences,
      },
      securite: {
        pareto: securite.pareto,
      },
    };
  }

  // ---------------------------------------------------------------------
  // Point d'entrée unique consommé par Flutter / le futur web : tout en un.
  // ---------------------------------------------------------------------
  async full() {
    const [overview, trends, alerts, score, analyses] = await Promise.all([this.overview(), this.trends(8), this.alerts(), this.score(), this.analyses()]);
    return { overview, trends, alerts, score, analyses };
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
