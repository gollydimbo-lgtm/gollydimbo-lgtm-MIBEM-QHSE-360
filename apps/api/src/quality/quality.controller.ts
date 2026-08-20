import { Body, Controller, Get, Param, Patch, Post } from '@nestjs/common';
import { QualityService } from './quality.service';
@Controller('quality')
export class QualityController {
  constructor(private readonly service:QualityService){}
  @Get('catalogs') catalogs(){return this.service.listCatalogs();}
  @Get('templates') listTemplates(){return this.service.listTemplates();}
  @Post('templates') createTemplate(@Body() body:any){return this.service.createTemplate(body);}
  @Get('controls') listControls(){return this.service.listControls();}
  @Get('controls/:id') getControl(@Param('id') id:string){return this.service.getControl(id);}
  @Post('controls') createControl(@Body() body:any){return this.service.createControl(body);}
  @Patch('controls/:id') update(@Param('id')id:string,@Body()body:any){return this.service.updateControl(id,body);}
  @Post('controls/:id/results') result(@Param('id')id:string,@Body()body:any){return this.service.recordResult(id,body.pointId,body);}
  @Post('controls/:id/attachments') attachment(@Param('id')id:string,@Body()body:any){return this.service.addAttachment(id,body);}
  @Post('controls/:id/signatures') sign(@Param('id')id:string,@Body()body:any){return this.service.sign(id,body);}
  @Post('controls/:id/submit') submit(@Param('id')id:string){return this.service.submit(id);}
}
