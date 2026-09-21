import { Controller, Get, Patch, Post, Param, Query } from '@nestjs/common';
import { NotificationsService } from './notifications.service';

@Controller('notifications')
export class NotificationsController {
  constructor(private readonly s: NotificationsService) {}

  @Get() list(@Query('nonLuesSeulement') nonLuesSeulement?: string) {
    return this.s.list({ nonLuesSeulement: nonLuesSeulement === 'true' });
  }

  @Get('compteur') compteur() {
    return this.s.compteurNonLues();
  }

  @Get('calendrier') calendrier() {
    return this.s.calendrier();
  }

  @Patch(':id/lue') marquerLue(@Param('id') id: string) {
    return this.s.marquerLue(id);
  }

  @Patch('marquer-toutes-lues') marquerToutesLues() {
    return this.s.marquerToutesLues();
  }

  @Post('generer') generer() {
    return this.s.genererNotifications();
  }
}
