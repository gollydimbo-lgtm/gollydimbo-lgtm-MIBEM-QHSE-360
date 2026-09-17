import {Body,Controller,Delete,Get,Param,Patch,Post,Query} from '@nestjs/common'; import {DocumentsService} from './documents.service';
@Controller('documents') export class DocumentsController {constructor(private s:DocumentsService){}
@Get('dashboard') dashboard(){return this.s.dashboard()}
@Get('a-traiter') aTraiter(){return this.s.aTraiter()}
@Get('matrice') matrice(){return this.s.matrice()}
@Get('groups') groups(){return this.s.groups()}
@Get('types') typeList(){return this.s.typeList()} @Post('types') typeCreate(@Body()b:any){return this.s.typeCreate(b)} @Patch('types/:id') typeUpdate(@Param('id')id:string,@Body()b:any){return this.s.typeUpdate(id,b)} @Delete('types/:id') typeDelete(@Param('id')id:string){return this.s.typeDelete(id)}
@Get('categories') categoryList(){return this.s.categoryList()} @Post('categories') categoryCreate(@Body()b:any){return this.s.categoryCreate(b)} @Patch('categories/:id') categoryUpdate(@Param('id')id:string,@Body()b:any){return this.s.categoryUpdate(id,b)} @Delete('categories/:id') categoryDelete(@Param('id')id:string){return this.s.categoryDelete(id)}
@Get('for-source') linksBySource(@Query('sourceModule')sourceModule:string,@Query('sourceEntityId')sourceEntityId:string){return this.s.linksBySource(sourceModule,sourceEntityId)}
@Get('qr/:token') byQrToken(@Param('token')token:string){return this.s.byQrToken(token)}
@Get() list(@Query()q:any){return this.s.list(q)}
@Get(':id') getOne(@Param('id')id:string){return this.s.get(id)}
@Post() create(@Body()d:any){return this.s.create(d)}
@Patch(':id') update(@Param('id')id:string,@Body()d:any){return this.s.update(id,d)}
@Post(':id/versions') addVersion(@Param('id')id:string,@Body()d:any){return this.s.addVersion(id,d)}
@Delete(':id') remove(@Param('id')id:string){return this.s.remove(id)}
@Post(':id/submit') submit(@Param('id')id:string,@Body()b:any){return this.s.submit(id,b)}
@Post(':id/verify') verify(@Param('id')id:string,@Body()b:any){return this.s.verify(id,b)}
@Post(':id/approve') approve(@Param('id')id:string,@Body()b:any){return this.s.approve(id,b)}
@Post(':id/archive') archive(@Param('id')id:string,@Body()b:any){return this.s.archive(id,b)}
@Post(':id/reopen') reopen(@Param('id')id:string,@Body()b:any){return this.s.reopen(id,b)}
@Post(':id/diffuse') diffuse(@Param('id')id:string,@Body()b:any){return this.s.diffuse(id,b)}
@Get(':id/diffusions') diffusionsByDocument(@Param('id')id:string){return this.s.diffusionsByDocument(id)}
@Post('diffusion-recipients/:id/accuse') accuseLecture(@Param('id')id:string,@Body()b:any){return this.s.accuseLecture(id,b)}
@Get(':id/links') linksByDocument(@Param('id')id:string){return this.s.linksByDocument(id)}
@Post(':id/links') linkCreate(@Param('id')id:string,@Body()b:any){return this.s.linkCreate(id,b)}
@Delete('links/:id') linkDelete(@Param('id')id:string){return this.s.linkDelete(id)}
@Post(':id/request-revision') requestRevision(@Param('id')id:string,@Body()b:any){return this.s.requestRevision(id,b)}
@Post(':id/link-veille') linkVeille(@Param('id')id:string,@Body()b:any){return this.s.linkVeille(id,b)}
@Post(':id/regenerate-qr') regenerateQr(@Param('id')id:string){return this.s.regenerateQr(id)}
}
