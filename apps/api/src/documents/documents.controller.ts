import { BadRequestException, Body, Controller, Get, Param, Post, Query } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { DocumentGroup } from '@prisma/client';
import { createHash } from 'crypto';
import { mkdirSync, writeFileSync } from 'fs';
import { join } from 'path';

function saveFile(fileName: string, base64: string) {
  const buffer = Buffer.from(String(base64).replace(/^data:[^;]+;base64,/, ''), 'base64');
  if (buffer.length > 20 * 1024 * 1024) throw new BadRequestException('Fichier supérieur à 20 Mo');
  const dir = join(process.cwd(), 'uploads');
  mkdirSync(dir, { recursive: true });
  const safeName = `${Date.now()}-${String(fileName).replace(/[^a-zA-Z0-9._-]/g, '_')}`;
  const storagePath = join(dir, safeName);
  writeFileSync(storagePath, buffer);
  return { storagePath, checksum: createHash('sha256').update(buffer).digest('hex') };
}

@Controller('documents')
export class DocumentsController {
  constructor(private db: PrismaService) {}

  @Get()
  list(@Query('group') group?: DocumentGroup) {
    return this.db.document.findMany({
      where: group ? { documentGroup: group } : undefined,
      include: { versions: { orderBy: { version: 'desc' } }, attachments: true },
      orderBy: { updatedAt: 'desc' },
    });
  }

  @Get('groups')
  groups() {
    return Object.values(DocumentGroup);
  }

  @Get(':id')
  getOne(@Param('id') id: string) {
    return this.db.document.findUnique({ where: { id }, include: { versions: { orderBy: { version: 'desc' } }, attachments: true } });
  }

  // Crée un document. Si fileName/mimeType/base64 sont fournis, le fichier
  // est enregistré tout de suite comme version 1 — sinon le document est
  // créé sans fichier (une version pourra être ajoutée ensuite via
  // POST /documents/:id/versions).
  @Post()
  async create(@Body() d: { code: string; title: string; category: string; documentGroup?: DocumentGroup; fileName?: string; mimeType?: string; base64?: string }) {
    const doc = await this.db.document.create({ data: { code: d.code, title: d.title, category: d.category, documentGroup: d.documentGroup, status: d.base64 ? 'ACTIVE' : 'DRAFT' } });
    if (d.fileName && d.base64) {
      const { storagePath, checksum } = saveFile(d.fileName, d.base64);
      await this.db.documentVersion.create({ data: { documentId: doc.id, version: 1, fileName: d.fileName, storagePath, checksum, status: 'ACTIVE' } });
    }
    return this.db.document.findUnique({ where: { id: doc.id }, include: { versions: true, attachments: true } });
  }

  // Ajoute une nouvelle version (mise à jour progressive) à un document
  // existant. Le numéro de version s'incrémente automatiquement.
  @Post(':id/versions')
  async addVersion(@Param('id') id: string, @Body() d: { fileName: string; mimeType: string; base64: string }) {
    if (!d?.fileName || !d?.base64) throw new BadRequestException('fileName et base64 sont obligatoires');
    const doc = await this.db.document.findUnique({ where: { id }, include: { versions: true } });
    if (!doc) throw new BadRequestException('Document introuvable');
    const nextVersion = (doc.versions.reduce((max, v) => Math.max(max, v.version), 0)) + 1;
    const { storagePath, checksum } = saveFile(d.fileName, d.base64);
    await this.db.documentVersion.create({ data: { documentId: id, version: nextVersion, fileName: d.fileName, storagePath, checksum, status: 'ACTIVE' } });
    return this.db.document.update({ where: { id }, data: { currentVersion: nextVersion, status: 'ACTIVE' }, include: { versions: { orderBy: { version: 'desc' } } } });
  }
}
