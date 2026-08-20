import { BadRequestException, Body, Controller, Get, Post, Query } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { createHash } from 'crypto';
import { mkdirSync, writeFileSync } from 'fs';
import { join } from 'path';
import { AttachmentOwnerType } from '@prisma/client';

@Controller('attachments')
export class AttachmentsController {
  constructor(private readonly db: PrismaService) {}
  @Post('base64')
  async upload(@Body() body:any) {
    if (!body?.fileName || !body?.mimeType || !body?.base64) throw new BadRequestException('fileName, mimeType et base64 sont obligatoires');
    const buffer=Buffer.from(String(body.base64).replace(/^data:[^;]+;base64,/,''),'base64');
    if(buffer.length>10*1024*1024) throw new BadRequestException('Fichier supérieur à 10 Mo');
    const dir=join(process.cwd(),'uploads'); mkdirSync(dir,{recursive:true});
    const safe=Date.now()+'-'+String(body.fileName).replace(/[^a-zA-Z0-9._-]/g,'_');
    const path=join(dir,safe); writeFileSync(path,buffer);
    return this.db.attachment.create({data:{originalName:body.fileName,storagePath:path,mimeType:body.mimeType,size:buffer.length,sha256:createHash('sha256').update(buffer).digest('hex')}});
  }

  // Lie un attachment déjà uploadé (via /attachments/base64) à n'importe quelle entité
  // métier (accident, non-conformité, action, risque, audit, EPI...).
  @Post('link')
  async link(@Body() body:{ownerType:AttachmentOwnerType; ownerId:string; attachmentId:string}) {
    if (!body?.ownerType || !body?.ownerId || !body?.attachmentId) throw new BadRequestException('ownerType, ownerId et attachmentId sont obligatoires');
    return this.db.attachmentLink.create({ data: { ownerType: body.ownerType, ownerId: body.ownerId, attachmentId: body.attachmentId }, include: { attachment: true } });
  }

  // Liste les pièces jointes d'une entité donnée.
  @Get('for')
  async listFor(@Query('ownerType') ownerType: AttachmentOwnerType, @Query('ownerId') ownerId: string) {
    if (!ownerType || !ownerId) throw new BadRequestException('ownerType et ownerId sont obligatoires');
    return this.db.attachmentLink.findMany({ where: { ownerType, ownerId }, include: { attachment: true }, orderBy: { createdAt: 'desc' } });
  }
}
