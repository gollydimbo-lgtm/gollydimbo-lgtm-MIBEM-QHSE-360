import { Body, Controller, Get, Post, Query } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { BusinessService } from '../business/business.service';
import { HaccpService } from '../haccp/haccp.service';
import { QualityService } from '../quality/quality.service';
import { QhsService } from '../qhs/qhs.service';

// Contexte transmis à chaque fonction ENTITY_CREATE / ENTITY_UPDATE — un
// objet plutôt que des paramètres positionnels, pour pouvoir ajouter un
// service (quality, qhs...) sans devoir retoucher chaque entrée existante.
interface SyncCtx { db: PrismaService; business: BusinessService; haccp: HaccpService; quality: QualityService; qhs: QhsService; }

// Entités que les applications terrain peuvent créer hors-ligne puis
// pousser une fois la connexion revenue. Le mapping traduit le nom
// générique envoyé par le client vers le modèle Prisma réel.
// "risk" passe par BusinessService (pas un create Prisma brut) pour que le
// risque créé hors-ligne bénéficie du même moteur de calcul, de la même
// traçabilité et du même historique d'évaluation qu'un risque créé en ligne.
const ENTITY_CREATE: Record<string, (ctx: SyncCtx, payload: any) => Promise<any>> = {
  nonConformity: (ctx, p) => ctx.business.ncCreate(p),
  action: (ctx, p) => ctx.db.action.create({ data: p }),
  safetyEvent: (ctx, p) => ctx.db.safetyEvent.create({ data: p }),
  risk: (ctx, p) => ctx.business.riskCreate(p),
  riskMeasure: (ctx, p) => ctx.db.riskMeasure.create({ data: p }),
  audit: (ctx, p) => ctx.db.qhseAudit.create({ data: p }),
  // Geste terrain HACCP prioritaire pour l'offline : saisie d'un relevé de
  // surveillance CCP hors ligne. Passe par HaccpService.monitoringCreate
  // (pas un create Prisma brut) pour que la chaîne automatique HACCP →
  // Non-conformité fonctionne aussi pour un relevé saisi hors ligne, comme
  // "risk" le fait déjà pour son propre moteur.
  haccpMonitoring: (ctx, p) => ctx.haccp.monitoringCreate(p.ccpId, p),
  // Contrôle réglementaire équipement saisi sur le terrain (Phase 4B) —
  // create Prisma direct, comme "action" : pas de moteur dédié à réutiliser
  // ici (générer une NC depuis un contrôle non conforme reste une action
  // manuelle explicite côté back-office, jamais automatique).
  equipmentControl: (ctx, p) => ctx.db.equipmentControl.create({ data: p }),
  // Chantier priorité 6 de l'audit (offline étendu Sécurité/Hygiène/
  // Environnement/Formation) : create Prisma direct pour ces quatre
  // entités, sur le même principe que "action"/"equipmentControl" —
  // aucune n'a de moteur de calcul dédié à réutiliser côté serveur, le
  // payload envoyé par le mobile (déjà complet, code inclus) suffit.
  epiInspection: (ctx, p) => ctx.db.epiInspection.create({ data: p }),
  epcInspection: (ctx, p) => ctx.db.epcInspection.create({ data: p }),
  tmsSignalement: (ctx, p) => ctx.db.tmsSignalement.create({ data: p }),
  environmentRecord: (ctx, p) => ctx.db.environmentRecord.create({ data: p }),
  training: (ctx, p) => ctx.db.training.create({ data: p }),

  // Chantier finding #28 de l'audit (offline étendu à 8 modules terrain
  // supplémentaires) : chaque entité repasse par le service métier existant
  // (pas un create Prisma brut) quand celui-ci porte une logique propre
  // (calcul de weekEnd, mise à jour de l'indicateur, statut initial...),
  // exactement sur le même principe que "risk"/"haccpMonitoring" ci-dessus.
  qualityControl: (ctx, p) => ctx.quality.createControl(p),
  reclamation: (ctx, p) => ctx.business.reclamationCreate(p),
  processus: (ctx, p) => ctx.business.processusCreate(p),
  indicateurMesure: (ctx, p) => { const { indicateurId, ...rest } = p; return ctx.business.indicateurMesureCreate(indicateurId, rest); },
  objectifQhse: (ctx, p) => ctx.business.objectifCreate(p),
  safetyTalk: (ctx, p) => ctx.qhs.create(p),
  fournisseur: (ctx, p) => ctx.business.fournisseurCreate(p),
  haccpStudy: (ctx, p) => ctx.haccp.studyCreate(p),
};

const ENTITY_UPDATE: Record<string, (ctx: SyncCtx, id: string, payload: any) => Promise<any>> = {
  nonConformity: (ctx, id, p) => ctx.business.ncUpdate(id, p),
  action: (ctx, id, p) => ctx.business.actionUpdate(id, p),
  risk: (ctx, id, p) => ctx.business.riskUpdate(id, p),
  // Entité distincte plutôt qu'un simple "risk" mis à jour : une
  // réévaluation doit passer par le moteur dédié (historique conservé),
  // jamais par un update générique qui écraserait silencieusement.
  riskReevaluate: (ctx, id, p) => ctx.business.riskReevaluate(id, p),
  // Même moteur qu'en ligne : la bascule conforme=false déclenche la NC
  // automatiquement même pour un relevé mis à jour après une synchro.
  haccpMonitoring: (ctx, id, p) => ctx.haccp.monitoringUpdate(id, p),
};

@Controller('sync')
export class SyncController {
  constructor(private db: PrismaService, private business: BusinessService, private haccp: HaccpService, private quality: QualityService, private qhs: QhsService) {}

  // Reçoit une file d'attente d'opérations créées hors-ligne par le client
  // (identifiées par un clientLocalId unique généré côté app) et les applique
  // réellement aux tables métier. Idempotent : rejouer le même clientLocalId
  // ne recrée pas l'enregistrement.
  @Post('push')
  async push(@Body() body: { items: any[] }) {
    const results: any[] = [];
    for (const item of body.items || []) {
      const existing = await this.db.syncItem.findUnique({ where: { clientLocalId: item.clientLocalId } });
      if (existing?.status === 'SYNCED') {
        results.push({ clientLocalId: item.clientLocalId, status: 'SYNCED', entityId: existing.entityId });
        continue;
      }

      const record = await this.db.syncItem.upsert({
        where: { clientLocalId: item.clientLocalId },
        create: { clientLocalId: item.clientLocalId, entity: item.entity, entityId: item.entityId, operation: item.operation, payload: item.payload, status: 'PENDING' },
        update: { payload: item.payload, operation: item.operation, status: 'PENDING' },
      });

      try {
        let entityId = item.entityId;
        if (item.operation === 'CREATE') {
          const fn = ENTITY_CREATE[item.entity];
          if (!fn) throw new Error(`Entité inconnue : ${item.entity}`);
          const ctx: SyncCtx = { db: this.db, business: this.business, haccp: this.haccp, quality: this.quality, qhs: this.qhs };
          const created = await fn(ctx, item.payload);
          entityId = created.id;
        } else if (item.operation === 'UPDATE') {
          const fn = ENTITY_UPDATE[item.entity];
          if (!fn) throw new Error(`Mise à jour non supportée pour : ${item.entity}`);
          if (!entityId) throw new Error('entityId requis pour une mise à jour');
          const ctx: SyncCtx = { db: this.db, business: this.business, haccp: this.haccp, quality: this.quality, qhs: this.qhs };
          await fn(ctx, entityId, item.payload);
        }
        await this.db.syncItem.update({ where: { id: record.id }, data: { status: 'SYNCED', entityId, syncedAt: new Date(), error: null } });
        results.push({ clientLocalId: item.clientLocalId, status: 'SYNCED', entityId });
      } catch (e: any) {
        await this.db.syncItem.update({ where: { id: record.id }, data: { status: 'FAILED', error: String(e?.message || e) } });
        results.push({ clientLocalId: item.clientLocalId, status: 'ERROR', error: String(e?.message || e) });
      }
    }
    return { accepted: results.length, items: results };
  }

  @Get('pending')
  pending() {
    return this.db.syncItem.findMany({ where: { status: 'PENDING' }, orderBy: { createdAt: 'asc' } });
  }

  @Get('status')
  async status() {
    const [pending, error, synced] = await Promise.all([
      this.db.syncItem.count({ where: { status: 'PENDING' } }),
      this.db.syncItem.count({ where: { status: 'FAILED' } }),
      this.db.syncItem.count({ where: { status: 'SYNCED' } }),
    ]);
    return { pending, error, synced };
  }

  // Permet à l'app terrain de rafraîchir son cache local avec ce qui a changé
  // côté serveur depuis sa dernière synchro (autres agents, back-office...).
  @Get('pull')
  async pull(@Query('since') since?: string) {
    const gte = since ? new Date(since) : new Date(0);
    const [nonConformities, actions, safetyEvents, risks] = await Promise.all([
      this.db.nonConformity.findMany({ where: { createdAt: { gte } }, orderBy: { createdAt: 'desc' }, take: 200 }),
      this.db.action.findMany({ where: { updatedAt: { gte } }, orderBy: { updatedAt: 'desc' }, take: 200 }),
      this.db.safetyEvent.findMany({ where: { createdAt: { gte } }, orderBy: { createdAt: 'desc' }, take: 200 }),
      this.db.risk.findMany({ where: { updatedAt: { gte } }, orderBy: { updatedAt: 'desc' }, take: 200 }),
    ]);
    return { serverTime: new Date().toISOString(), nonConformities, actions, safetyEvents, risks };
  }
}
