import { Module } from '@nestjs/common';
import { NotificationsController } from './notifications.controller';
import { NotificationsService } from './notifications.service';
import { PrismaService } from '../common/prisma.service';
import { BusinessModule } from '../business/business.module';
import { DashboardModule } from '../dashboard/dashboard.module';

@Module({
  imports: [BusinessModule, DashboardModule],
  controllers: [NotificationsController],
  providers: [NotificationsService, PrismaService],
})
export class NotificationsModule {}
