import { SetMetadata } from '@nestjs/common';
import { RoleName } from '@prisma/client';

// Décorateur @Roles(...) — pose la liste des rôles autorisés sur une route
// ou un contrôleur entier. Lu par RolesGuard (voir roles.guard.ts). Une
// route sans ce décorateur reste accessible à tout compte authentifié
// (comportement inchangé) : on l'ajoute uniquement sur les actions
// sensibles (suppressions, validations) plutôt que de tout verrouiller
// d'un coup, pour rester cohérent avec le reste de l'application qui n'a
// jamais eu de contrôle par rôle jusqu'ici.
export const ROLES_KEY = 'roles';
export const Roles = (...roles: RoleName[]) => SetMetadata(ROLES_KEY, roles);
