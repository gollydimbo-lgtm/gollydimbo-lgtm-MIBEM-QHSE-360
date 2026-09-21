import { Logger } from '@nestjs/common';
import { PrismaService } from './prisma.service';
import { currentAuditUserId } from './audit-context';

const logger = new Logger('AuditLog');

// Un échec de journalisation ne doit jamais faire échouer l'opération
// métier elle-même — d'où le try/catch silencieux.
export async function writeAudit(
  db: PrismaService,
  module: string,
  action: 'CREATE' | 'UPDATE' | 'DELETE' | (string & {}),
  entityId: string | null,
  oldValue: unknown,
  newValue: unknown,
) {
  try {
    await db.auditLog.create({
      data: {
        userId: currentAuditUserId(),
        action,
        module,
        entityId,
        oldValue: oldValue ? JSON.parse(JSON.stringify(oldValue)) : undefined,
        newValue: newValue ? JSON.parse(JSON.stringify(newValue)) : undefined,
      },
    });
  } catch (err) {
    // L'échec ne doit jamais faire échouer l'opération métier elle-même
    // (d'où le catch), mais une panne silencieuse rendrait le journal
    // d'audit incomplet sans que personne ne le sache — on la trace au
    // moins côté serveur pour pouvoir la détecter.
    logger.error(`Échec d'écriture du journal d'audit (module=${module}, action=${action}, entityId=${entityId})`, err instanceof Error ? err.stack : String(err));
  }
}
