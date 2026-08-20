import { Controller, Get, Query } from '@nestjs/common';
import { DashboardService } from './dashboard.service';

@Controller('dashboard')
export class DashboardController {
  constructor(private readonly service: DashboardService) {}

  // Tout-en-un : overview + tendances + alertes, en un seul appel réseau.
  // C'est l'endpoint que consomment Flutter (Android/Windows) et le futur web.
  @Get()
  full() {
    return this.service.full();
  }

  @Get('overview')
  overview() {
    return this.service.overview();
  }

  @Get('trends')
  trends(@Query('weeks') weeks?: string) {
    return this.service.trends(weeks ? parseInt(weeks, 10) : 8);
  }

  @Get('alerts')
  alerts() {
    return this.service.alerts();
  }
}
