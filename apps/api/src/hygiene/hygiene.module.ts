import { Module } from '@nestjs/common';
import { HygieneService } from './hygiene.service';
import { HygieneController } from './hygiene.controller';
import { PrismaService } from '../common/prisma.service';

@Module({
  controllers: [HygieneController],
  providers: [HygieneService, PrismaService],
})
export class HygieneModule {}
