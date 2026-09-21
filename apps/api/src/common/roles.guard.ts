import { CanActivate, ExecutionContext, ForbiddenException, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { RoleName } from '@prisma/client';
import { ROLES_KEY } from './roles.decorator';

// RolesGuard — contrôle d'accès par rôle (RBAC), enregistré globalement à
// côté de JwtAuthGuard (voir app.module.ts). Jusqu'ici les rôles/permissions
// étaient calculés dans le jeton JWT (auth.service.ts) mais jamais vérifiés
// nulle part : n'importe quel compte authentifié pouvait supprimer un audit,
// un risque ou valider un rapport direction. Ce garde corrige ça pour les
// routes annotées avec @Roles(...).
//
// Une route SANS @Roles() reste ouverte à tout compte authentifié (parité
// avec le comportement historique) — on verrouille au cas par cas les
// actions sensibles plutôt que tout d'un coup, pour ne pas bloquer des
// usages légitimes non encore couverts par le nouveau système de rôles.
// ADMINISTRATEUR passe toujours, quelle que soit la liste demandée.
@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const required = this.reflector.getAllAndOverride<RoleName[]>(ROLES_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (!required || required.length === 0) return true;

    const req = context.switchToHttp().getRequest();
    const userRoles: string[] = req.user?.roles || [];
    if (userRoles.includes('ADMINISTRATEUR')) return true;
    const allowed = userRoles.some((r) => (required as string[]).includes(r));
    if (!allowed) {
      throw new ForbiddenException(
        `Cette action est réservée aux rôles : ${required.join(', ')}.`,
      );
    }
    return true;
  }
}
