import { CallHandler, ExecutionContext, Injectable, NestInterceptor } from '@nestjs/common';
import { Observable } from 'rxjs';

// StripForbiddenFieldsInterceptor — première parade contre le
// "mass assignment" généralisé identifié à l'audit : la quasi-totalité des
// méthodes xxxCreate(b:any)/xxxUpdate(id,b:any) passent le corps de la
// requête tel quel à Prisma (`data:b`), sans DTO ni sélection de champs.
// Réécrire chacun des 250+ endpoints avec un DTO class-validator dédié est
// un chantier bien plus large que cette session ne peut couvrir d'un coup
// (voir le rapport d'audit) — ceci est une protection mécanique immédiate,
// appliquée partout sans travail par module : elle retire du corps de
// toute requête d'écriture les clés qu'un client ne devrait jamais pouvoir
// fixer lui-même (identifiant, horodatages gérés par la base, verrous
// d'archivage), quel que soit le modèle visé.
//
// Elle ne remplace PAS des DTOs par modèle : un client peut toujours
// injecter un champ métier non prévu mais dont le NOM est légitime (ex.
// forcer un statut ou un score qui devrait être recalculé côté serveur).
// Fermer complètement cette faille demande un DTO par endpoint — c'est le
// chantier de suite recommandé dans le rapport d'audit.
const FORBIDDEN_TOP_LEVEL_KEYS = ['id', 'createdAt', 'updatedAt', 'archivedAt'];

function stripForbidden(value: unknown): void {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return;
  for (const key of FORBIDDEN_TOP_LEVEL_KEYS) {
    if (key in (value as Record<string, unknown>)) delete (value as Record<string, unknown>)[key];
  }
}

@Injectable()
export class StripForbiddenFieldsInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const req = context.switchToHttp().getRequest();
    if (['POST', 'PATCH', 'PUT'].includes(req.method) && req.body) {
      stripForbidden(req.body);
    }
    return next.handle();
  }
}
