import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaService } from './common/prisma.service';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { AuditModule } from './audit/audit.module';
import { EpiModule } from './epi/epi.module';
import { SyncModule } from './sync/sync.module';
import { DocumentsModule } from './documents/documents.module';
import { QhsModule } from './qhs/qhs.module';
import { BusinessModule } from './business/business.module';
import { QualityModule } from './quality/quality.module';
import { AttachmentsModule } from './attachments/attachments.module';
import { DashboardModule } from './dashboard/dashboard.module';
import { RecommendationsModule } from './recommendations/recommendations.module';
import { HealthController } from './health.controller';
@Module({imports:[ConfigModule.forRoot({isGlobal:true}),AuthModule,UsersModule,AuditModule,EpiModule,SyncModule,DocumentsModule,QhsModule,BusinessModule,QualityModule,AttachmentsModule,DashboardModule,RecommendationsModule],controllers:[HealthController],providers:[PrismaService]}) export class AppModule {}
