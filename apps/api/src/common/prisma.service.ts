import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';
import { currentAuditUserId } from './audit-context';

// Modèles suivis par le journal d'audit du module EPI/EPC. Ajouter un nom
// ici suffit à activer la traçabilité pour ce modèle — aucune modification
// nécessaire dans les services qui l'utilisent.
const AUDITED_MODELS = new Set([
  'Epi', 'Epc', 'EpiCategory', 'EpcCategory', 'EpiAssignment',
  'EpiInspection', 'EpcInspection', 'EpcMaintenance', 'JobRiskProtection',
]);

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  async onModuleInit() {
    await this.$connect();
    this.$use(async (params, next) => {
      if (!params.model || !AUDITED_MODELS.has(params.model) || !['create', 'update', 'delete'].includes(params.action)) {
        return next(params);
      }

      const model = params.model;
      const action = params.action.toUpperCase();
      const userId = currentAuditUserId();

      // Pour update/delete, on récupère la valeur AVANT modification —
      // sans ça, "ancienne valeur" n'aurait aucun sens dans le journal.
      let oldValue: unknown = null;
      if (action !== 'CREATE' && params.args?.where) {
        try {
          oldValue = await (this as any)[model.charAt(0).toLowerCase() + model.slice(1)].findUnique({ where: params.args.where });
        } catch {
          oldValue = null;
        }
      }

      const result = await next(params);

      try {
        await this.auditLog.create({
          data: {
            userId,
            action,
            module: model,
            entityId: (result as any)?.id ?? (params.args?.where?.id ?? null),
            oldValue: oldValue ? JSON.parse(JSON.stringify(oldValue)) : undefined,
            newValue: action !== 'DELETE' && result ? JSON.parse(JSON.stringify(result)) : undefined,
          },
        });
      } catch {
        // Un échec de journalisation ne doit jamais faire échouer
        // l'opération métier elle-même.
      }

      return result;
    });
  }
  async onModuleDestroy() { await this.$disconnect(); }
}
