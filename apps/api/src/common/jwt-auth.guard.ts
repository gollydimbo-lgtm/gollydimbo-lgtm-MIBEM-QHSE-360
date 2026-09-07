import { ExecutionContext, ForbiddenException, Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { Reflector } from '@nestjs/core';
import { IS_PUBLIC_KEY } from './public.decorator';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  constructor(private reflector: Reflector) {
    super();
  }

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (isPublic) return true;

    // Vérifie d'abord le jeton d'accès — comme avant, mais réellement
    // appliqué cette fois sur chaque requête, pas seulement à la connexion.
    const authenticated = (await super.canActivate(context)) as boolean;
    if (!authenticated) return false;

    // Un compte au rôle exclusivement "Consultation seule" ne peut jamais
    // écrire, quelle que soit la route — seule la lecture (GET) lui est
    // autorisée. Un compte cumulant CONSULTATION avec un autre rôle garde
    // les droits de cet autre rôle.
    const req = context.switchToHttp().getRequest();
    const roles: string[] = req.user?.roles || [];
    const isConsultationOnly = roles.length > 0 && roles.every((r) => r === 'CONSULTATION');
    if (isConsultationOnly && !['GET', 'HEAD', 'OPTIONS'].includes(req.method)) {
      throw new ForbiddenException('Votre rôle (Consultation seule) ne permet pas de modifier les données.');
    }
    return true;
  }
}
