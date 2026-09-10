import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';

const CONTROL_INCLUDE = {
  template:{include:{points:true}}, productionLine:true, machine:true, productRef:true, productFormat:true, shiftRef:true,
  type:true, epi:true, epc:true, risk:true, fournisseur:true, employee:true,
};

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

  // --- Types de contrôle (catalogue configurable, jamais figé en dur) ---
  listTypes(domain?:string) { return this.db.controlType.findMany({ where:domain?{domain}:undefined, orderBy:{name:'asc'} }); }
  createType(data:any) {
    if (!data.code || !data.name) throw new BadRequestException('code et name sont obligatoires');
    return this.db.controlType.create({data:{code:data.code,name:data.name,domain:data.domain||'QUALITE',description:data.description,active:data.active??true}});
  }
  updateType(id:string,data:any) { return this.db.controlType.update({where:{id},data}); }
  deleteType(id:string) { return this.db.controlType.delete({where:{id}}); }

  listTemplates(domain?:string) { return this.db.controlTemplate.findMany({ where:{active:true,...(domain?{domain}:{})}, include:{points:{orderBy:{order:'asc'}},type:true}, orderBy:{name:'asc'} }); }

  createTemplate(data:any) {
    if (!data.code || !data.name) throw new BadRequestException('code et name sont obligatoires');
    return this.db.controlTemplate.create({data:{
      code:data.code,name:data.name,domain:data.domain||'QUALITE',typeId:data.typeId,
      points:{create:(data.points||[]).map((p:any,i:number)=>({code:p.code,label:p.label,type:p.type||'BOOLEAN',required:!!p.required,critical:!!p.critical,minValue:p.minValue,maxValue:p.maxValue,choices:p.choices,unit:p.unit,order:p.order??i}))}
    },include:{points:true,type:true}});
  }

  async createControl(data:any) {
    if (!data.code) throw new BadRequestException('code obligatoire');
    const domain = data.domain || 'QUALITE';
    // La validation stricte (ligne/produit/quart/lot) ne s'applique qu'au
    // domaine Qualité — c'est exactement ce qu'utilise déjà l'application
    // mobile de conditionnement. Les autres domaines (sécurité, hygiène,
    // EPI/EPC...) n'ont pas ce contexte de ligne de production et ne
    // doivent pas être bloqués par cette exigence.
    if (domain === 'QUALITE' && (!data.lineId || !data.productId || !data.shiftId || !data.lotNumber)) {
      throw new BadRequestException('ligne, produit, quart et lot sont obligatoires');
    }
    if (data.templateId) {
      const t=await this.db.controlTemplate.findUnique({where:{id:data.templateId}});
      if(!t) throw new NotFoundException('Template introuvable');
    }
    return this.db.qualityControl.create({data:{
      code:data.code, siteId:data.siteId, lineId:data.lineId, machineId:data.machineId, productId:data.productId,
      formatId:data.formatId, shiftId:data.shiftId, line:data.line, product:data.product, format:data.format,
      lotNumber:data.lotNumber, shift:data.shift, controlDate:data.controlDate?new Date(data.controlDate):new Date(),
      notes:data.notes, latitude:data.latitude, longitude:data.longitude, gpsAccuracy:data.gpsAccuracy,
      startedAt:new Date(), status:'IN_PROGRESS', createdById:data.createdById, templateId:data.templateId,
      domain, typeId:data.typeId, epiId:data.epiId, epcId:data.epcId, riskId:data.riskId, fournisseurId:data.fournisseurId, employeeId:data.employeeId,
    },include:CONTROL_INCLUDE});
  }

  listControls(domain?:string) { return this.db.qualityControl.findMany({where:domain?{domain}:undefined,include:{...CONTROL_INCLUDE,results:{include:{point:true}},nonConformities:{include:{actions:true}},attachments:{include:{attachment:true}},signatures:true,createdBy:true},orderBy:{controlDate:'desc'}}); }

  getControl(id:string) { return this.db.qualityControl.findUnique({where:{id},include:{...CONTROL_INCLUDE,results:{include:{point:true}},nonConformities:{include:{actions:true}},attachments:{include:{attachment:true}},signatures:{include:{user:true}},createdBy:true}}); }

  async recordResult(controlId:string, pointId:string, data:any) {
    const control=await this.db.qualityControl.findUnique({where:{id:controlId}});
    const point=await this.db.controlPoint.findUnique({where:{id:pointId}});
    if(!control || !point || point.templateId !== control.templateId) throw new BadRequestException('Point de contrôle incompatible');
    if(['COMPLIANT','NON_COMPLIANT','CANCELLED'].includes(control.status)) throw new BadRequestException('Contrôle déjà clôturé');
    // Un point marqué non applicable n'a pas besoin de valeur, même s'il
    // est par ailleurs obligatoire — il sera exclu du taux de conformité.
    if(point.required && !data.notApplicable && (data.value===undefined || data.value===null || data.value==='')) throw new BadRequestException(`Valeur obligatoire: ${point.label}`);
    let compliant=data.compliant;
    if(point.type==='NUMERIC' && typeof data.value==='number') compliant = (point.minValue==null || data.value>=point.minValue) && (point.maxValue==null || data.value<=point.maxValue);
    const notApplicable = !!data.notApplicable;
    return this.db.controlResult.upsert({where:{controlId_pointId:{controlId,pointId}},update:{value:data.value,compliant:notApplicable?null:compliant,notApplicable,comment:data.comment,createdById:data.createdById,photoRequired:!!data.photoRequired},create:{controlId,pointId,value:data.value,compliant:notApplicable?null:compliant,notApplicable,comment:data.comment,createdById:data.createdById,photoRequired:!!data.photoRequired}});
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
    return this.db.qualityControl.update({where:{id},data:{
      notes:data.notes,latitude:data.latitude,longitude:data.longitude,gpsAccuracy:data.gpsAccuracy,machineId:data.machineId,formatId:data.formatId,
      lotSize:data.lotSize, sampleSize:data.sampleSize, samplingMethod:data.samplingMethod,
      acceptanceThreshold:data.acceptanceThreshold, rejectionThreshold:data.rejectionThreshold,
    }});
  }

  async submit(id:string) {
    const c=await this.getControl(id); if(!c) throw new NotFoundException('Contrôle introuvable');
    const required=(c.template?.points||[]).filter((p:any)=>p.required); const done=new Set((c.results||[]).map((r:any)=>r.pointId));
    if(required.some((p:any)=>!done.has(p.id))) throw new BadRequestException('Tous les points obligatoires doivent être renseignés');
    const results = c.results||[];
    // Les points non applicables sont exclus du dénominateur — un
    // contrôle avec beaucoup de N/A ne doit jamais paraître mauvais.
    const evaluated = results.filter((r:any)=>!r.notApplicable);
    const failed = evaluated.filter((r:any)=>r.compliant===false);
    const compliantCount = evaluated.filter((r:any)=>r.compliant===true).length;
    const conformityRate = evaluated.length ? Math.round((compliantCount/evaluated.length)*1000)/10 : null;
    const criticalFailed = failed.some((r:any)=>r.point?.critical);
    // Taux de défaut : basé sur la taille d'échantillon si elle a été
    // renseignée (contrôle produit avec échantillonnage), sinon sur
    // l'ensemble des points évalués.
    const defectRate = c.sampleSize ? Math.round((failed.length/c.sampleSize)*1000)/10 : (conformityRate!=null ? Math.round((100-conformityRate)*10)/10 : null);
    let finalDecision = 'CONFORME';
    if (failed.length) {
      if (criticalFailed) finalDecision = 'REFUSE';
      else if (c.rejectionThreshold!=null && defectRate!=null && defectRate > c.rejectionThreshold) finalDecision = 'REFUSE';
      else if (c.acceptanceThreshold!=null && defectRate!=null && defectRate <= c.acceptanceThreshold) finalDecision = 'CONFORME_SOUS_RESERVE';
      else finalDecision = 'NON_CONFORME';
    }
    return this.db.$transaction(async tx=>{
      const updated=await tx.qualityControl.update({where:{id},data:{
        status:failed.length?'NON_COMPLIANT':'COMPLIANT', result:failed.length?'FAIL':'PASS', submittedAt:new Date(),
        conformityRate, defectRate, finalDecision,
      }});
      for(const r of failed){
        const critical = r.point?.critical;
        // Fusion des liens : la non-conformité générée hérite des liens
        // du contrôle qui l'a produite (EPI, EPC...), pour rester
        // reliée au bon élément quel que soit le domaine du contrôle.
        const nc=await tx.nonConformity.create({data:{
          code:`NC-${Date.now()}-${Math.random().toString(36).slice(2,6).toUpperCase()}`,
          title:`Écart contrôle ${c.code}`,description:r.comment||`Point: ${r.point?.label||r.pointId}`,
          severity:critical?3:1,
          classification: critical ? 'NC_CRITIQUE' : 'NC_MINEURE',
          source:c.domain==='QUALITE'?'QUALITY_CONTROL':c.domain,
          qualityControlId:id, epiId:c.epiId, epcId:c.epcId,
        }});
        await tx.action.create({data:{code:`ACT-${Date.now()}-${Math.random().toString(36).slice(2,6).toUpperCase()}`,title:`Traiter ${nc.code}`,description:`Analyser et corriger l'écart du contrôle ${c.code}`,priority:critical?1:2,nonConformityId:nc.id}});
      }
      return updated;
    });
  }

  removeControl(id: string) {
    return this.db.qualityControl.delete({ where: { id } });
  }
}
