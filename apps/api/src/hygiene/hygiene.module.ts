import { Module } from '@nestjs/common';
import { HygieneService } from './hygiene.service';
import { HygieneController } from './hygiene.controller';
import { PrismaModule } from '../prisma/prisma.module'; // adapter si le nom diffère chez vous

@Module({
  imports: [PrismaModule],
  controllers: [HygieneController],
  providers: [HygieneService],
})
export class HygieneModule {}
