import { Module } from '@nestjs/common'; import { PrismaService } from '../common/prisma.service'; import { AttachmentsController } from './attachments.controller';
@Module({controllers:[AttachmentsController],providers:[PrismaService],exports:[PrismaService]}) export class AttachmentsModule{}
