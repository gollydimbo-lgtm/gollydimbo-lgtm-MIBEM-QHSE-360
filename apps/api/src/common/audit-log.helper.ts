import { PrismaService } from './prisma.service';
import { currentAuditUserId } from './audit-context';

// Un échec de journalisation ne doit jamais faire échouer l'opération
// métier elle-même — d'où le try/catch silencieux.
export async function writeAudit(
  db: PrismaService,
  module: string,
  action: 'CREATE' | 'UPDATE' | 'DELETE',
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
  } catch {
    // silencieux, volontairement
  }
}
