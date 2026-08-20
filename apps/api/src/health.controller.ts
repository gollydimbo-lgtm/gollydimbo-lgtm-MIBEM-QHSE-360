import { Controller, Get } from '@nestjs/common';
import { PrismaService } from './common/prisma.service';
@Controller('health')
export class HealthController {
  constructor(private readonly db:PrismaService){}
  @Get() async health(){ await this.db.$queryRaw`SELECT 1`; return {status:'ok',database:'up',timestamp:new Date().toISOString()}; }
}
