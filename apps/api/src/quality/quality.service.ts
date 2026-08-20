import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';

@Injectable()
export class QualityService {
  constructor(private readonly db: PrismaService) {}

  listCatalogs() {
    return Promise.all([
      this.db.site.findMany({where:{active:true},include:{lines:{where:{active:true},include:{machines:{where:{active:true}}}}},orderBy:{name:'asc'}}),
      this.db.product.findMany({where:{active:true},include:{formats:true},orderBy:{name:'asc'}}),
      this.db.shift.findMany({where:{active:true},orderBy:{name:'asc'}}),
      this.db.controlTemplate.findMany({where:{active:true},include:{points:{orderBy:{order:'asc'}}},orderBy:{name:'asc'}}),
    ]);
  }

  listTemplates() { return this.db.controlTemplate.findMany({ where:{active:true}, include:{points:{orderBy:{order:'asc'}}}, orderBy:{name:'asc'} }); }

  createTemplate(data:any) {
    if (!data.code || !data.name) throw new BadRequestException('code et name sont obligatoires');
    return this.db.controlTemplate.create({data:{code:data.code,name:data.name,points:{create:(data.points||[]).map((p:any,i:number)=>({code:p.code,label:p.label,type:p.type||'BOOLEAN',required:!!p.required,critical:!!p.critical,minValue:p.minValue,maxValue:p.maxValue,choices:p.choices,unit:p.unit,order:p.order??i}))}},include:{points:true}});
  }

  async createControl(data:any) {
    if (!data.code) throw new BadRequestException('code obligatoire');
    if (!data.lineId || !data.productId || !data.shiftId || !data.lotNumber) throw new BadRequestException('ligne, produit, quart et lot sont obligatoires');
    if (data.templateId) {
      const t=await this.db.controlTemplate.findUnique({where:{id:data.templateId}});
      if(!t) throw new NotFoundException('Template introuvable');
    }
    return this.db.qualityControl.create({data:{
      code:data.code, siteId:data.siteId, lineId:data.lineId, machineId:data.machineId, productId:data.productId,
      formatId:data.formatId, shiftId:data.shiftId, line:data.line, product:data.product, format:data.format,
      lotNumber:data.lotNumber, shift:data.shift, controlDate:data.controlDate?new Date(data.controlDate):new Date(),
      notes:data.notes, latitude:data.latitude, longitude:data.longitude, gpsAccuracy:data.gpsAccuracy,
      startedAt:new Date(), status:'IN_PROGRESS', createdById:data.createdById, templateId:data.templateId
    },include:{template:{include:{points:true}},productionLine:true,machine:true,productRef:true,productFormat:true,shiftRef:true}});
  }

  listControls() { return this.db.qualityControl.findMany({include:{template:{include:{points:true}},productionLine:true,machine:true,productRef:true,productFormat:true,shiftRef:true,results:{include:{point:true}},nonConformities:{include:{actions:true}},attachments:{include:{attachment:true}},signatures:true,createdBy:true},orderBy:{controlDate:'desc'}}); }

  getControl(id:string) { return this.db.qualityControl.findUnique({where:{id},include:{template:{include:{points:true}},productionLine:true,machine:true,productRef:true,productFormat:true,shiftRef:true,results:{include:{point:true}},nonConformities:{include:{actions:true}},attachments:{include:{attachment:true}},signatures:{include:{user:true}},createdBy:true}}); }

  async recordResult(controlId:string, pointId:string, data:any) {
    const control=await this.db.qualityControl.findUnique({where:{id:controlId}});
    const point=await this.db.controlPoint.findUnique({where:{id:pointId}});
    if(!control || !point || point.templateId !== control.templateId) throw new BadRequestException('Point de contrôle incompatible');
    if(['COMPLIANT','NON_COMPLIANT','CANCELLED'].includes(control.status)) throw new BadRequestException('Contrôle déjà clôturé');
    if(point.required && (data.value===undefined || data.value===null || data.value==='')) throw new BadRequestException(`Valeur obligatoire: ${point.label}`);
    let compliant=data.compliant;
    if(point.type==='NUMERIC' && typeof data.value==='number') compliant = (point.minValue==null || data.value>=point.minValue) && (point.maxValue==null || data.value<=point.maxValue);
    return this.db.controlResult.upsert({where:{controlId_pointId:{controlId,pointId}},update:{value:data.value,compliant,comment:data.comment,createdById:data.createdById,photoRequired:!!data.photoRequired},create:{controlId,pointId,value:data.value,compliant,comment:data.comment,createdById:data.createdById,photoRequired:!!data.photoRequired}});
  }

  async addAttachment(controlId:string, data:any) {
    const c=await this.db.qualityControl.findUnique({where:{id:controlId}}); if(!c) throw new NotFoundException('Contrôle introuvable');
    return this.db.qualityControlAttachment.create({data:{controlId,attachmentId:data.attachmentId}});
  }

  async sign(id:string, data:any) {
    const c=await this.db.qualityControl.findUnique({where:{id}}); if(!c) throw new NotFoundException('Contrôle introuvable');
    if(!data.signatureData || !data.type) throw new BadRequestException('Signature et type obligatoires');
    return this.db.qualityControlSignature.create({data:{controlId:id,userId:data.userId,type:data.type,signatureData:data.signatureData}});
  }

  async updateControl(id:string,data:any) {
    const c=await this.db.qualityControl.findUnique({where:{id}}); if(!c) throw new NotFoundException('Contrôle introuvable');
    if(['COMPLIANT','NON_COMPLIANT','CANCELLED'].includes(c.status)) throw new BadRequestException('Contrôle clôturé');
    return this.db.qualityControl.update({where:{id},data:{notes:data.notes,latitude:data.latitude,longitude:data.longitude,gpsAccuracy:data.gpsAccuracy,machineId:data.machineId,formatId:data.formatId}});
  }

  async submit(id:string) {
    const c=await this.getControl(id); if(!c) throw new NotFoundException('Contrôle introuvable');
    const required=(c.template?.points||[]).filter((p:any)=>p.required); const done=new Set((c.results||[]).map((r:any)=>r.pointId));
    if(required.some((p:any)=>!done.has(p.id))) throw new BadRequestException('Tous les points obligatoires doivent être renseignés');
    const failed=(c.results||[]).filter((r:any)=>r.compliant===false);
    return this.db.$transaction(async tx=>{
      const updated=await tx.qualityControl.update({where:{id},data:{status:failed.length?'NON_COMPLIANT':'COMPLIANT',result:failed.length?'FAIL':'PASS',submittedAt:new Date()}});
      for(const r of failed){
        const nc=await tx.nonConformity.create({data:{code:`NC-${Date.now()}-${Math.random().toString(36).slice(2,6).toUpperCase()}`,title:`Écart contrôle ${c.code}`,description:r.comment||`Point: ${r.point?.label||r.pointId}`,severity:r.point?.critical?3:1,source:'QUALITY_CONTROL',qualityControlId:id}});
        await tx.action.create({data:{code:`ACT-${Date.now()}-${Math.random().toString(36).slice(2,6).toUpperCase()}`,title:`Traiter ${nc.code}`,description:`Analyser et corriger l'écart du contrôle ${c.code}`,priority:r.point?.critical?1:2,nonConformityId:nc.id}});
      }
      return updated;
    });
  }
}
