import { Request, Response, NextFunction } from 'express';
import * as jwt from 'jsonwebtoken';
import { auditContext } from './audit-context';

// Ce middleware ne vérifie PAS l'authentification (c'est déjà le rôle de
// JwtAuthGuard) — il se contente de lire, quand c'est possible, l'identité
// de l'utilisateur déjà authentifié pour l'attacher au journal d'audit.
// Un jeton absent ou invalide n'entraîne jamais d'erreur ici : il rend
// simplement les entrées d'audit anonymes pour cette requête.
//
// Le secret est injecté par bootstrap() (main.ts) depuis le même
// ConfigService que JwtStrategy (audit finding #6) : avant, ce middleware
// relisait process.env.JWT_SECRET directement, une seconde source
// indépendante de celle de l'authentification officielle — une rotation
// de clé mal synchronisée aurait rendu le journal d'audit silencieusement
// anonyme, sans erreur visible. Une seule source de vérité désormais.
export function createAuditContextMiddleware(secret: string) {
  return function auditContextMiddleware(req: Request, _res: Response, next: NextFunction) {
    let userId: string | null = null;
    let siteId: string | null = null;
    let roles: string[] = [];
    const header = req.headers['authorization'];
    if (header && header.startsWith('Bearer ')) {
      try {
        const token = header.slice(7);
        const payload = jwt.verify(token, secret) as { sub?: string; siteId?: string | null; roles?: string[] };
        userId = payload?.sub || null;
        siteId = payload?.siteId ?? null;
        roles = payload?.roles ?? [];
      } catch {
        userId = null;
      }
    }
    auditContext.run({ userId, siteId, roles }, () => next());
  };
}
