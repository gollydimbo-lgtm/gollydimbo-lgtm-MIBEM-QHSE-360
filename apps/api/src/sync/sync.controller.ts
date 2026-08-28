import { Body, Controller, Get, Post, Query } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';

// Entités que les applications terrain peuvent créer hors-ligne puis
// pousser une fois la connexion revenue. Le mapping traduit le nom
// générique envoyé par le client vers le modèle Prisma réel.
const ENTITY_CREATE: Record<string, (db: PrismaService, payload: any) => Promise<any>> = {
  nonConformity: (db, p) => db.nonConformity.create({ data: p }),
  action: (db, p) => db.action.create({ data: p }),
  safetyEvent: (db, p) => db.safetyEvent.create({ data: p }),
  risk: (db, p) => db.risk.create({ data: p }),
};

const ENTITY_UPDATE: Record<string, (db: PrismaService, id: string, payload: any) => Promise<any>> = {
  nonConformity: (db, id, p) => db.nonConformity.update({ where: { id }, data: p }),
  action: (db, id, p) => db.action.update({ where: { id }, data: p }),
  risk: (db, id, p) => db.risk.update({ where: { id }, data: p }),
};

@Controller('sync')
export class SyncController {
  constructor(private db: PrismaService) {}

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
          const created = await fn(this.db, item.payload);
          entityId = created.id;
        } else if (item.operation === 'UPDATE') {
          const fn = ENTITY_UPDATE[item.entity];
          if (!fn) throw new Error(`Mise à jour non supportée pour : ${item.entity}`);
          if (!entityId) throw new Error('entityId requis pour une mise à jour');
          await fn(this.db, entityId, item.payload);
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
