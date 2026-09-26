import { Injectable } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PrismaService } from '../common/prisma.service';
import { BusinessService } from '../business/business.service';
import { DashboardService } from '../dashboard/dashboard.service';
import { MailerService } from './mailer.service';

// Calendrier centralisé + notifications actives (chantier issu de l'audit).
// Jusqu'ici les échéances (habilitations, actions, audits, EPI, équipements,
// formations) n'étaient calculées qu'à l'affichage du tableau de bord
// Pilotage, sans persistance ni visibilité ailleurs dans l'application.
// Ce service :
//  1) réutilise DashboardService.alerts() (déjà exhaustif sur ces domaines)
//  2) y ajoute les domaines qui n'y figuraient pas encore : maintenance des
//     équipements, veille réglementaire, visites médicales, réévaluations
//     de risque en attente, alertes fournisseurs.
//  3) persiste chaque signal comme Notification, de façon idempotente
//     (sourceKey unique — même principe que BesoinFormation et
//     RegulatoryRiskReevaluationRequest) : relancer la génération ne
//     duplique jamais une notification déjà créée pour le même événement,
//     et une notification déjà marquée "lue" par un utilisateur le reste.
// E-mail : envoyé aux ADMINISTRATEUR/RESPONSABLE_QHSE pour toute nouvelle
// notification CRITICAL/WARNING, via MailerService (SMTP configuré par
// variables d'environnement, voir .env.example). SMS différé (findings
// #26/#40) : aucun fournisseur SMS choisi et aucun champ téléphone sur
// User (décision du 26/09) — à ajouter quand un fournisseur sera retenu.
// Déclenchement : génération manuelle (POST /notifications/generer) et
// désormais aussi un job planifié quotidien (voir genererNotificationsPlanifiees).
@Injectable()
export class NotificationsService {
  constructor(
    private db: PrismaService,
    private business: BusinessService,
    private dashboard: DashboardService,
    private mailer: MailerService,
  ) {}

  async list(opts?: { nonLuesSeulement?: boolean; take?: number }) {
    return this.db.notification.findMany({
      where: opts?.nonLuesSeulement ? { lu: false } : undefined,
      orderBy: [{ lu: 'asc' }, { dueDate: 'asc' }, { createdAt: 'desc' }],
      take: opts?.take ?? 200,
    });
  }

  async compteurNonLues() {
    return { nonLues: await this.db.notification.count({ where: { lu: false } }) };
  }

  async marquerLue(id: string) {
    return this.db.notification.update({ where: { id }, data: { lu: true, luLe: new Date() } });
  }

  async marquerToutesLues() {
    return this.db.notification.updateMany({ where: { lu: false }, data: { lu: true, luLe: new Date() } });
  }

  // Calendrier centralisé — toutes les échéances datées, tous modules
  // confondus, triées chronologiquement. Lecture directe (jamais persistée
  // en tant que telle : une échéance déplacée dans son module d'origine
  // doit se refléter immédiatement ici, sans resynchronisation à faire).
  async calendrier() {
    const now = new Date();
    const dans90Jours = new Date(now.getTime() + 90 * 86400000);
    const enRetard: any[] = [];
    const aVenir: any[] = [];

    const push = (item: { module: string; titre: string; dueDate: Date | null; lienEntityId?: string }) => {
      if (!item.dueDate) return;
      const cible = item.dueDate < now ? enRetard : aVenir;
      if (item.dueDate <= dans90Jours || item.dueDate < now) cible.push(item);
    };

    const [actions, audits, habilitations, maintenances, veilles, visites, calibrations, formations] = await Promise.all([
      this.db.action.findMany({ where: { status: { not: 'CLOSED' }, dueDate: { not: null } }, select: { id: true, title: true, dueDate: true } }),
      this.db.qhseAudit.findMany({ where: { status: 'PLANNED' }, select: { id: true, title: true, auditDate: true } }),
      this.db.habilitation.findMany({ where: { dateExpiration: { not: null } }, include: { employee: true } }),
      this.db.equipmentMaintenancePlan.findMany({ where: { dateProchaine: { not: null } }, include: { equipment: true } }),
      this.db.regulatoryRequirement.findMany({ where: { dateProchaineEvaluation: { not: null } }, include: { text: true } }),
      this.db.visiteMedicale.findMany({ where: { prochaineVisite: { not: null } }, include: { employee: true } }),
      this.db.equipment.findMany({ where: { nextInspectionAt: { not: null } }, select: { id: true, name: true, nextInspectionAt: true } }),
      this.db.training.findMany({ where: { status: { notIn: ['REALISEE', 'CLOTUREE', 'ANNULEE'] } }, select: { id: true, title: true, scheduledAt: true } }),
    ]);

    for (const a of actions) push({ module: 'ACTION', titre: a.title, dueDate: a.dueDate, lienEntityId: a.id });
    for (const au of audits) push({ module: 'AUDIT', titre: au.title, dueDate: au.auditDate, lienEntityId: au.id });
    for (const h of habilitations) push({ module: 'HABILITATION', titre: `${h.intitule} — ${h.employee.firstName} ${h.employee.lastName}`, dueDate: h.dateExpiration, lienEntityId: h.id });
    for (const m of maintenances) push({ module: 'MAINTENANCE', titre: `Maintenance — ${m.equipment?.name ?? ''}`, dueDate: m.dateProchaine, lienEntityId: m.id });
    for (const v of veilles) push({ module: 'VEILLE_REGLEMENTAIRE', titre: v.text?.reference ?? 'Exigence réglementaire', dueDate: v.dateProchaineEvaluation, lienEntityId: v.id });
    for (const vm of visites) push({ module: 'VISITE_MEDICALE', titre: `Visite médicale — ${vm.employee ? vm.employee.firstName + ' ' + vm.employee.lastName : vm.employeNom}`, dueDate: vm.prochaineVisite, lienEntityId: vm.id });
    for (const c of calibrations) push({ module: 'EQUIPEMENT', titre: `Inspection — ${c.name}`, dueDate: c.nextInspectionAt, lienEntityId: c.id });
    for (const t of formations) push({ module: 'FORMATION', titre: t.title, dueDate: t.scheduledAt, lienEntityId: t.id });

    const tri = (arr: any[]) => arr.sort((x, y) => (x.dueDate?.getTime() ?? 0) - (y.dueDate?.getTime() ?? 0));
    return { enRetard: tri(enRetard), aVenir: tri(aVenir) };
  }

  // Génère les notifications persistantes à partir de tous les signaux déjà
  // détectés ailleurs dans l'application. Idempotent : à appeler aussi
  // souvent que nécessaire (à l'ouverture de l'app, ou périodiquement),
  // sans jamais dupliquer une notification déjà créée pour le même
  // événement.
  async genererNotifications() {
    const candidats: Array<{ sourceKey: string; module: string; niveau: string; titre: string; detail?: string; dueDate?: Date | null; lienModule?: string; lienEntityId?: string }> = [];

    // 1) Tout ce que couvre déjà le tableau de bord Pilotage (actions,
    // NC critiques, audits, EPI, équipements, documents, formations,
    // habilitations, besoins de formation, efficacité, accueil sécurité).
    const alertesDashboard = await this.dashboard.alerts();
    for (const a of alertesDashboard) {
      const cle = a.code ? `${a.domain}::${a.code}` : `${a.domain}::${a.title}::${a.detail}`;
      candidats.push({
        sourceKey: `DASHBOARD::${cle}`, module: a.domain, niveau: a.level, titre: a.title, detail: a.detail,
        dueDate: a.dueDate, lienModule: a.domain,
      });
    }

    // 2) Maintenance des équipements en retard
    const now = new Date();
    const maintenancesEnRetard = await this.db.equipmentMaintenancePlan.findMany({ where: { dateProchaine: { lt: now } }, include: { equipment: true } });
    for (const m of maintenancesEnRetard) {
      candidats.push({
        sourceKey: `MAINTENANCE_RETARD::${m.id}`, module: 'MAINTENANCE', niveau: 'CRITICAL',
        titre: `Maintenance en retard — ${m.equipment?.name ?? 'équipement'}`,
        detail: `Prévue le ${m.dateProchaine!.toISOString().slice(0, 10)}`, dueDate: m.dateProchaine,
        lienModule: 'EQUIPEMENT', lienEntityId: m.equipmentId,
      });
    }

    // 3) Veille réglementaire — exigences à réévaluer
    const veillesEnRetard = await this.db.regulatoryRequirement.findMany({ where: { dateProchaineEvaluation: { lt: now } }, include: { text: true } });
    for (const v of veillesEnRetard) {
      candidats.push({
        sourceKey: `VEILLE_RETARD::${v.id}`, module: 'VEILLE_REGLEMENTAIRE', niveau: 'WARNING',
        titre: `Exigence réglementaire à réévaluer — ${v.text?.reference ?? ''}`,
        detail: `Échéance dépassée le ${v.dateProchaineEvaluation!.toISOString().slice(0, 10)}`, dueDate: v.dateProchaineEvaluation,
        lienModule: 'VEILLE_REGLEMENTAIRE', lienEntityId: v.id,
      });
    }

    // 4) Visites médicales échues
    const visitesEnRetard = await this.db.visiteMedicale.findMany({ where: { prochaineVisite: { lt: now } }, include: { employee: true } });
    for (const vm of visitesEnRetard) {
      candidats.push({
        sourceKey: `VISITE_MEDICALE_RETARD::${vm.id}`, module: 'VISITE_MEDICALE', niveau: 'WARNING',
        titre: `Visite médicale échue — ${vm.employee ? vm.employee.firstName + ' ' + vm.employee.lastName : vm.employeNom}`,
        detail: `Prévue le ${vm.prochaineVisite!.toISOString().slice(0, 10)}`, dueDate: vm.prochaineVisite,
        lienModule: 'VISITE_MEDICALE', lienEntityId: vm.id,
      });
    }

    // 5) Réévaluations de risque en attente (réglementaires + croisées —
    // tâches #43)
    const reevaluationsEnAttente = await this.db.regulatoryRiskReevaluationRequest.findMany({ where: { statut: 'A_PLANIFIER' }, include: { risk: true } });
    for (const r of reevaluationsEnAttente) {
      candidats.push({
        sourceKey: `REEVAL_RISQUE::${r.id}`, module: 'RISQUE', niveau: 'WARNING',
        titre: `Réévaluation de risque à planifier — ${r.risk?.hazard ?? ''}`,
        detail: r.raison ?? undefined, dueDate: r.dateLimite,
        lienModule: 'RISQUE', lienEntityId: r.riskId,
      });
    }

    // 6) Alertes fournisseurs critiques/urgentes
    const alertesFournisseurs = await this.business.fournisseursAlertes();
    for (const f of alertesFournisseurs) {
      if (f.niveau === 'ATTENTION') continue; // on ne notifie que critique/urgent, pour ne pas noyer la cloche
      candidats.push({
        sourceKey: `FOURNISSEUR_ALERTE::${f.id}::${now.toISOString().slice(0, 7)}`, module: 'FOURNISSEUR',
        niveau: f.niveau === 'CRITIQUE' ? 'CRITICAL' : 'WARNING',
        titre: `Fournisseur à risque — ${f.nom}`, detail: f.motifs.map((m: any) => m.label).join(' ; '),
        lienModule: 'FOURNISSEUR', lienEntityId: f.id,
      });
    }

    const creees: any[] = [];
    for (const c of candidats) {
      const existe = await this.db.notification.findUnique({ where: { sourceKey: c.sourceKey } });
      if (existe) continue;
      const row = await this.db.notification.create({
        data: {
          sourceKey: c.sourceKey, module: c.module, niveau: c.niveau, titre: c.titre, detail: c.detail,
          dueDate: c.dueDate ?? null, lienModule: c.lienModule, lienEntityId: c.lienEntityId,
        },
      });
      creees.push(row);
    }
    const aNotifier = creees.filter((c) => c.niveau === 'CRITICAL' || c.niveau === 'WARNING');
    if (aNotifier.length) {
      const destinataires = await this.db.user.findMany({
        where: { status: 'ACTIVE', roles: { some: { role: { name: { in: ['ADMINISTRATEUR', 'RESPONSABLE_QHSE'] } } } } },
        select: { email: true },
      });
      await this.mailer.envoyerNotificationsCritiques(
        destinataires.map((d) => d.email),
        aNotifier,
      );
    }

    return { analyses: candidats.length, nouvellesNotifications: creees.length, notifications: creees };
  }

  // Déclenchement automatique quotidien (finding #25) : jusqu'ici
  // POST /notifications/generer n'était appelé qu'à la main, donc les
  // notifications n'étaient jamais réellement "actives". Ce job les
  // régénère (et déclenche l'e-mail ci-dessus) sans action utilisateur.
  @Cron(CronExpression.EVERY_DAY_AT_6AM)
  async genererNotificationsPlanifiees() {
    return this.genererNotifications();
  }
}
