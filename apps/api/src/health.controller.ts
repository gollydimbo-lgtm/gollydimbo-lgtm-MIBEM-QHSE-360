import { Controller, Get } from '@nestjs/common';
import { PrismaService } from './common/prisma.service';
import { Public } from './common/public.decorator';
@Controller('health')
export class HealthController {
  constructor(private readonly db:PrismaService){}
  @Public() @Get() async health(){ await this.db.$queryRaw`SELECT 1`; return {status:'ok',database:'up',timestamp:new Date().toISOString()}; }
}
