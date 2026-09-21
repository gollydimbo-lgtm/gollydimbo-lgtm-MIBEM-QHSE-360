import { Body, Controller, Get, Post, Query } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { BusinessService } from '../business/business.service';
import { HaccpService } from '../haccp/haccp.service';

// Entités que les applications terrain peuvent créer hors-ligne puis
// pousser une fois la connexion revenue. Le mapping traduit le nom
// générique envoyé par le client vers le modèle Prisma réel.
// "risk" passe par BusinessService (pas un create Prisma brut) pour que le
// risque créé hors-ligne bénéficie du même moteur de calcul, de la même
// traçabilité et du même historique d'évaluation qu'un risque créé en ligne.
const ENTITY_CREATE: Record<string, (db: PrismaService, business: BusinessService, haccp: HaccpService, payload: any) => Promise<any>> = {
  nonConformity: (db, business, haccp, p) => business.ncCreate(p),
  action: (db, business, haccp, p) => db.action.create({ data: p }),
  safetyEvent: (db, business, haccp, p) => db.safetyEvent.create({ data: p }),
  risk: (db, business, haccp, p) => business.riskCreate(p),
  riskMeasure: (db, business, haccp, p) => db.riskMeasure.create({ data: p }),
  audit: (db, business, haccp, p) => db.qhseAudit.create({ data: p }),
  // Geste terrain HACCP prioritaire pour l'offline : saisie d'un relevé de
  // surveillance CCP hors ligne. Passe par HaccpService.monitoringCreate
  // (pas un create Prisma brut) pour que la chaîne automatique HACCP →
  // Non-conformité fonctionne aussi pour un relevé saisi hors ligne, comme
  // "risk" le fait déjà pour son propre moteur.
  haccpMonitoring: (db, business, haccp, p) => haccp.monitoringCreate(p.ccpId, p),
  // Contrôle réglementaire équipement saisi sur le terrain (Phase 4B) —
  // create Prisma direct, comme "action" : pas de moteur dédié à réutiliser
  // ici (générer une NC depuis un contrôle non conforme reste une action
  // manuelle explicite côté back-office, jamais automatique).
  equipmentControl: (db, business, haccp, p) => db.equipmentControl.create({ data: p }),
  // Chantier priorité 6 de l'audit (offline étendu Sécurité/Hygiène/
  // Environnement/Formation) : create Prisma direct pour ces quatre
  // entités, sur le même principe que "action"/"equipmentControl" —
  // aucune n'a de moteur de calcul dédié à réutiliser côté serveur, le
  // payload envoyé par le mobile (déjà complet, code inclus) suffit.
  epiInspection: (db, business, haccp, p) => db.epiInspection.create({ data: p }),
  epcInspection: (db, business, haccp, p) => db.epcInspection.create({ data: p }),
  tmsSignalement: (db, business, haccp, p) => db.tmsSignalement.create({ data: p }),
  environmentRecord: (db, business, haccp, p) => db.environmentRecord.create({ data: p }),
  training: (db, business, haccp, p) => db.training.create({ data: p }),
};

const ENTITY_UPDATE: Record<string, (db: PrismaService, business: BusinessService, haccp: HaccpService, id: string, payload: any) => Promise<any>> = {
  nonConformity: (db, business, haccp, id, p) => business.ncUpdate(id, p),
  action: (db, business, haccp, id, p) => business.actionUpdate(id, p),
  risk: (db, business, haccp, id, p) => business.riskUpdate(id, p),
  // Entité distincte plutôt qu'un simple "risk" mis à jour : une
  // réévaluation doit passer par le moteur dédié (historique conservé),
  // jamais par un update générique qui écraserait silencieusement.
  riskReevaluate: (db, business, haccp, id, p) => business.riskReevaluate(id, p),
  // Même moteur qu'en ligne : la bascule conforme=false déclenche la NC
  // automatiquement même pour un relevé mis à jour après une synchro.
  haccpMonitoring: (db, business, haccp, id, p) => haccp.monitoringUpdate(id, p),
};

@Controller('sync')
export class SyncController {
  constructor(private db: PrismaService, private business: BusinessService, private haccp: HaccpService) {}

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
          const created = await fn(this.db, this.business, this.haccp, item.payload);
          entityId = created.id;
        } else if (item.operation === 'UPDATE') {
          const fn = ENTITY_UPDATE[item.entity];
          if (!fn) throw new Error(`Mise à jour non supportée pour : ${item.entity}`);
          if (!entityId) throw new Error('entityId requis pour une mise à jour');
          await fn(this.db, this.business, this.haccp, entityId, item.payload);
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
