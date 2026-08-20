import { Module } from '@nestjs/common';
import { QualityController } from './quality.controller';
import { QualityService } from './quality.service';
import { QualityCatalogController } from './catalog.controller';
import { PrismaService } from '../common/prisma.service';
@Module({controllers:[QualityController,QualityCatalogController],providers:[QualityService,PrismaService],exports:[QualityService]})
export class QualityModule {}
