import { Body, Controller, Delete, Get, Param, Patch, Post, Query } from '@nestjs/common';
import { QualityService } from './quality.service';
@Controller('quality')
export class QualityController {
  constructor(private readonly service:QualityService){}
  @Get('catalogs') catalogs(){return this.service.listCatalogs();}
  @Get('types') listTypes(@Query('domain')domain?:string){return this.service.listTypes(domain);}
  @Post('types') createType(@Body() body:any){return this.service.createType(body);}
  @Patch('types/:id') updateType(@Param('id')id:string,@Body()body:any){return this.service.updateType(id,body);}
  @Delete('types/:id') deleteType(@Param('id')id:string){return this.service.deleteType(id);}
  @Get('templates') listTemplates(@Query('domain')domain?:string){return this.service.listTemplates(domain);}
  @Post('templates') createTemplate(@Body() body:any){return this.service.createTemplate(body);}
  @Get('controls') listControls(@Query('domain')domain?:string){return this.service.listControls(domain);}
  @Get('controls/:id') getControl(@Param('id') id:string){return this.service.getControl(id);}
  @Post('controls') createControl(@Body() body:any){return this.service.createControl(body);}
  @Patch('controls/:id') update(@Param('id')id:string,@Body()body:any){return this.service.updateControl(id,body);}
  @Post('controls/:id/results') result(@Param('id')id:string,@Body()body:any){return this.service.recordResult(id,body.pointId,body);}
  @Post('controls/:id/attachments') attachment(@Param('id')id:string,@Body()body:any){return this.service.addAttachment(id,body);}
  @Post('controls/:id/signatures') sign(@Param('id')id:string,@Body()body:any){return this.service.sign(id,body);}
  @Post('controls/:id/submit') submit(@Param('id')id:string){return this.service.submit(id);}
  @Delete('controls/:id') remove(@Param('id')id:string){return this.service.removeControl(id);}
  @Get('schedules') listSchedules(@Query('domain')domain?:string){return this.service.listSchedules(domain);}
  @Post('schedules') createSchedule(@Body()body:any){return this.service.createSchedule(body);}
  @Patch('schedules/:id') updateSchedule(@Param('id')id:string,@Body()body:any){return this.service.updateSchedule(id,body);}
  @Delete('schedules/:id') deleteSchedule(@Param('id')id:string){return this.service.deleteSchedule(id);}
  @Post('schedules/:id/generate') generateFromSchedule(@Param('id')id:string){return this.service.generateFromSchedule(id);}
  @Get('schedules-buckets') scheduleBuckets(){return this.service.scheduleBuckets();}
}
