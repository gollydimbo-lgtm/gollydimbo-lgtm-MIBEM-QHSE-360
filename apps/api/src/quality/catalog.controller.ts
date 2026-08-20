import { Body, Controller, Delete, Get, Param, Patch, Post } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
@Controller('quality/catalog')
export class QualityCatalogController {
  constructor(private db:PrismaService){}
  @Get('sites') sites(){return this.db.site.findMany({include:{lines:{include:{machines:true}}},orderBy:{name:'asc'}})}
  @Post('sites') site(@Body() b:any){return this.db.site.create({data:{code:b.code,name:b.name,location:b.location}})}
  @Get('products') products(){return this.db.product.findMany({include:{formats:true},orderBy:{name:'asc'}})}
  @Post('products') product(@Body() b:any){return this.db.product.create({data:{code:b.code,name:b.name,category:b.category,formats:{create:(b.formats||[]).map((f:any)=>({code:f.code,label:f.label,volumeMl:f.volumeMl}))}} ,include:{formats:true}})}
  @Post('lines') line(@Body() b:any){return this.db.productionLine.create({data:{siteId:b.siteId,code:b.code,name:b.name,area:b.area}})}
  @Post('machines') machine(@Body() b:any){return this.db.machine.create({data:{lineId:b.lineId,code:b.code,name:b.name,category:b.category}})}
  @Post('shifts') shift(@Body() b:any){return this.db.shift.create({data:{code:b.code,name:b.name,startTime:b.startTime,endTime:b.endTime}})}
  @Get('shifts') shifts(){return this.db.shift.findMany({where:{active:true},orderBy:{name:'asc'}})}
  @Patch('lines/:id') updateLine(@Param('id')id:string,@Body()b:any){return this.db.productionLine.update({where:{id},data:b})}
  @Delete('lines/:id') deleteLine(@Param('id')id:string){return this.db.productionLine.delete({where:{id}})}
}
