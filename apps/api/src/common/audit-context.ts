import { AsyncLocalStorage } from 'async_hooks';

export interface AuditContext {
  userId: string | null;
}

export const auditContext = new AsyncLocalStorage<AuditContext>();

export function currentAuditUserId(): string | null {
  return auditContext.getStore()?.userId ?? null;
}
