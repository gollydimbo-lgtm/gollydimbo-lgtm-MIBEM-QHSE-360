import { AsyncLocalStorage } from 'async_hooks';

export interface AuditContext {
  userId: string | null;
  siteId?: string | null;
  roles?: string[];
}

export const auditContext = new AsyncLocalStorage<AuditContext>();

export function currentAuditUserId(): string | null {
  return auditContext.getStore()?.userId ?? null;
}

// Cloisonnement multi-site (finding #37) : les rôles ADMINISTRATEUR et
// RESPONSABLE_QHSE gardent toujours la vue consolidée groupe, tout comme un
// compte sans site assigné (siteId null — comportement historique MIBEM
// mono-site, non régressif). Les autres comptes sont restreints à leur
// site. Retourne un fragment de `where` Prisma à fusionner (spread) :
// {} = pas de filtre, {siteId: '...'} = filtré.
const SITE_SCOPE_BYPASS_ROLES = ['ADMINISTRATEUR', 'RESPONSABLE_QHSE'];
export function currentSiteScope(): { siteId?: string } {
  const store = auditContext.getStore();
  if (!store) return {};
  const roles = store.roles ?? [];
  if (roles.some((r) => SITE_SCOPE_BYPASS_ROLES.includes(r))) return {};
  if (!store.siteId) return {};
  return { siteId: store.siteId };
}
