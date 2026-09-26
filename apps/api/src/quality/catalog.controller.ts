import { Roles } from '../common/roles.decorator';
import { RoleName } from '@prisma/client';
import { Body, Controller, Delete, Get, Param, Patch, Post } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { writeAudit } from '../common/audit-log.helper';
import { CreateSiteDto, CreateProductDto, CreateProductionLineDto, UpdateProductionLineDto, CreateMachineDto, CreateShiftDto } from './catalog.dto';
@Controller('quality/catalog')
export class QualityCatalogController {
  constructor(private db:PrismaService){}
  @Get('sites') sites(){return this.db.site.findMany({include:{lines:{include:{machines:true}}},orderBy:{name:'asc'}})}
  @Post('sites') site(@Body() b:CreateSiteDto){return this.db.site.create({data:{code:b.code,name:b.name,location:b.location}})}
  @Get('products') products(){return this.db.product.findMany({include:{formats:true},orderBy:{name:'asc'}})}
  @Post('products') product(@Body() b:CreateProductDto){return this.db.product.create({data:{code:b.code,name:b.name,category:b.category,formats:{create:(b.formats||[]).map((f)=>({code:f.code,label:f.label,volumeMl:f.volumeMl}))}} ,include:{formats:true}})}
  @Post('lines') line(@Body() b:CreateProductionLineDto){return this.db.productionLine.create({data:{siteId:b.siteId,code:b.code,name:b.name,area:b.area}})}
  @Post('machines') machine(@Body() b:CreateMachineDto){return this.db.machine.create({data:{lineId:b.lineId,code:b.code,name:b.name,category:b.category}})}
  @Post('shifts') shift(@Body() b:CreateShiftDto){return this.db.shift.create({data:{code:b.code,name:b.name,startTime:b.startTime,endTime:b.endTime}})}
  @Get('shifts') shifts(){return this.db.shift.findMany({where:{active:true},orderBy:{name:'asc'}})}
  @Patch('lines/:id') updateLine(@Param('id')id:string,@Body()b:UpdateProductionLineDto){return this.db.productionLine.update({where:{id},data:{code:b.code,name:b.name,area:b.area,siteId:b.siteId,active:b.active}})}
  @Delete('lines/:id') @Roles(RoleName.ADMINISTRATEUR,RoleName.RESPONSABLE_QHSE) async deleteLine(@Param('id')id:string){const row=await this.db.productionLine.delete({where:{id}});await writeAudit(this.db,'PRODUCTION_LINE','DELETE',id,row,null);return row;}
}
