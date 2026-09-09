import { Request, Response, NextFunction } from 'express';
import * as jwt from 'jsonwebtoken';
import { auditContext } from './audit-context';

// Ce middleware ne vérifie PAS l'authentification (c'est déjà le rôle de
// JwtAuthGuard) — il se contente de lire, quand c'est possible, l'identité
// de l'utilisateur déjà authentifié pour l'attacher au journal d'audit.
// Un jeton absent ou invalide n'entraîne jamais d'erreur ici : il rend
// simplement les entrées d'audit anonymes pour cette requête.
export function auditContextMiddleware(req: Request, _res: Response, next: NextFunction) {
  let userId: string | null = null;
  const header = req.headers['authorization'];
  if (header && header.startsWith('Bearer ')) {
    try {
      const token = header.slice(7);
      const secret = process.env.JWT_SECRET || '';
      const payload = jwt.verify(token, secret) as { sub?: string };
      userId = payload?.sub || null;
    } catch {
      userId = null;
    }
  }
  auditContext.run({ userId }, () => next());
}
