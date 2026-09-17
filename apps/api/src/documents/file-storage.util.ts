import { BadRequestException } from '@nestjs/common';
import { createHash } from 'crypto';
import { mkdirSync, writeFileSync } from 'fs';
import { join } from 'path';

// Écriture disque d'une version de document — limite 20 Mo, hash sha256,
// nom de fichier assaini. Reprend exactement la logique historique du
// contrôleur (déplacée telle quelle dans ce module utilitaire partagé).
export function saveFile(fileName: string, base64: string) {
  const buffer = Buffer.from(String(base64).replace(/^data:[^;]+;base64,/, ''), 'base64');
  if (buffer.length > 20 * 1024 * 1024) throw new BadRequestException('Fichier supérieur à 20 Mo');
  const dir = join(process.cwd(), 'uploads');
  mkdirSync(dir, { recursive: true });
  const safeName = `${Date.now()}-${String(fileName).replace(/[^a-zA-Z0-9._-]/g, '_')}`;
  const storagePath = join(dir, safeName);
  writeFileSync(storagePath, buffer);
  return { storagePath, checksum: createHash('sha256').update(buffer).digest('hex') };
}
