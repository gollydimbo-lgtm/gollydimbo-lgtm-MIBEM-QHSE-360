import { Logger } from '@nestjs/common';

const logger = new Logger('MassAssignmentGuard');

// Champs qu'aucun endpoint de ce dépôt n'écrit jamais volontairement à
// partir du corps d'une requête (finding #2 de l'audit — 192 méthodes
// xxxCreate(b:any)/xxxUpdate(id,b:any) passent data:b directement à Prisma
// sans validation ni DTO). Une conversion complète en DTOs class-validator
// par endpoint reste le correctif le plus rigoureux mais représente un
// chantier de plusieurs sessions ; en attendant, cette fonction retire
// systématiquement du corps reçu les champs qu'aucun service métier de ce
// dépôt ne définit jamais lui-même via ce même spread — l'identifiant
// (qui doit toujours venir de Prisma, jamais du client) et les
// horodatages système. Elle ne filtre PAS les champs métier (statut,
// scores calculés, dates d'archivage...) : ceux-ci sont légitimement
// écrits par certains services eux-mêmes via ce même mécanisme de spread,
// et les distinguer d'une valeur injectée par un client nécessite une
// validation par endpoint (DTO), pas un filtre générique — le retirer ici
// casserait ces écritures légitimes.
const SYSTEM_FIELDS = ['id', 'createdAt', 'updatedAt'] as const;

export function stripSystemFields<T extends Record<string, any> | null | undefined>(body: T): T {
  if (!body || typeof body !== 'object') return body;
  let found: string[] = [];
  for (const f of SYSTEM_FIELDS) {
    if (f in body) found.push(f);
  }
  if (found.length === 0) return body;
  const clean = { ...body } as Record<string, any>;
  for (const f of found) delete clean[f];
  logger.warn(`Champ(s) système retiré(s) d'une requête : ${found.join(', ')}`);
  return clean as T;
}
