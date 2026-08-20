import { Controller, Get, Param, Post } from '@nestjs/common';
import { QhsService } from './qhs.service';

@Controller('safety-talks')
export class QhsController {
  constructor(private s: QhsService) {}
  @Post('generate') generate() { return this.s.generate(); }
  @Get() list() { return this.s.list(); }
  @Post(':id/approve') approve(@Param('id') id: string) { return this.s.approve(id); }
  @Post(':id/deliver') deliver(@Param('id') id: string) { return this.s.deliver(id); }
}
