import { Injectable } from '@nestjs/common'; import { PrismaService } from '../common/prisma.service'; import {EpiFrequency,EpiMovementType} from '@prisma/client'; import { writeAudit } from '../common/audit-log.helper';
@Injectable() export class EpiService{constructor(private db:PrismaService){} async dashboard(date=new Date()){const start=new Date(date);start.setHours(0,0,0,0);const end=new Date(start);end.setDate(end.getDate()+1);const [epis,movements,headcount,employees]=await Promise.all([this.db.epi.findMany({where:{active:true}}),this.db.epiMovement.findMany(),this.db.dailyHeadcount.findUnique({where:{date:start}}),this.db.employee.count({where:{active:true}})]); const stock=epis.map(e=>{const ms=movements.filter(m=>m.epiId===e.id);return {...e,stock:ms.reduce((s,m)=>s+((m.type===EpiMovementType.RECEIPT||m.type===EpiMovementType.ADJUSTMENT)?m.quantity:-m.quantity),0),dailyDistributed:ms.filter(m=>m.distributionDate>=start&&m.distributionDate<end&&m.type===EpiMovementType.DAILY_DISTRIBUTION).reduce((s,m)=>s+m.quantity,0)}}); return {date:start,effectiveHeadcount:headcount?.headcount??employees,dailyExpected:stock.filter(e=>e.frequency===EpiFrequency.DAILY).map(e=>({epi:e.name,quantity:headcount?.headcount??employees})),stock};} async annualRenewals(days=30){const until=new Date();until.setDate(until.getDate()+days);return this.db.epiAssignment.findMany({where:{renewalAt:{lte:until}},include:{employee:true,epi:true},orderBy:{renewalAt:'asc'}})}

 employeeList(){return this.db.employee.findMany({orderBy:{lastName:'asc'}})}
 async employeeCreate(b:any){const r=await this.db.employee.create({data:b}); await writeAudit(this.db,'Employee','CREATE',r.id,null,r); return r;}
 async employeeUpdate(id:string,b:any){const old=await this.db.employee.findUnique({where:{id}}); const r=await this.db.employee.update({where:{id},data:b}); await writeAudit(this.db,'Employee','UPDATE',id,old,r); return r;}
 async employeeDelete(id:string){const old=await this.db.employee.findUnique({where:{id}}); const r=await this.db.employee.delete({where:{id}}); await writeAudit(this.db,'Employee','DELETE',id,old,null); return r;}

 catalogList(){return this.db.epi.findMany({orderBy:{name:'asc'}})}
 async catalogCreate(b:any){const r=await this.db.epi.create({data:b}); await writeAudit(this.db,'Epi','CREATE',r.id,null,r); return r;}
 async catalogUpdate(id:string,b:any){const old=await this.db.epi.findUnique({where:{id}}); const r=await this.db.epi.update({where:{id},data:b}); await writeAudit(this.db,'Epi','UPDATE',id,old,r); return r;}
 async catalogDelete(id:string){const old=await this.db.epi.findUnique({where:{id}}); const r=await this.db.epi.delete({where:{id}}); await writeAudit(this.db,'Epi','DELETE',id,old,null); return r;}

 movementCreate(b:any){return this.db.epiMovement.create({data:b})}

 epiCategoryList(){return this.db.epiCategory.findMany({orderBy:{name:'asc'}})}
 async epiCategoryCreate(b:any){const r=await this.db.epiCategory.create({data:b}); await writeAudit(this.db,'EpiCategory','CREATE',r.id,null,r); return r;}
 async epiCategoryUpdate(id:string,b:any){const old=await this.db.epiCategory.findUnique({where:{id}}); const r=await this.db.epiCategory.update({where:{id},data:b}); await writeAudit(this.db,'EpiCategory','UPDATE',id,old,r); return r;}
 async epiCategoryDelete(id:string){const old=await this.db.epiCategory.findUnique({where:{id}}); const r=await this.db.epiCategory.delete({where:{id}}); await writeAudit(this.db,'EpiCategory','DELETE',id,old,null); return r;}

 epcCategoryList(){return this.db.epcCategory.findMany({orderBy:{name:'asc'}})}
 async epcCategoryCreate(b:any){const r=await this.db.epcCategory.create({data:b}); await writeAudit(this.db,'EpcCategory','CREATE',r.id,null,r); return r;}
 async epcCategoryUpdate(id:string,b:any){const old=await this.db.epcCategory.findUnique({where:{id}}); const r=await this.db.epcCategory.update({where:{id},data:b}); await writeAudit(this.db,'EpcCategory','UPDATE',id,old,r); return r;}
 async epcCategoryDelete(id:string){const old=await this.db.epcCategory.findUnique({where:{id}}); const r=await this.db.epcCategory.delete({where:{id}}); await writeAudit(this.db,'EpcCategory','DELETE',id,old,null); return r;}

 epcList(){return this.db.epc.findMany({include:{category:true,responsible:true},orderBy:{name:'asc'}})}
 async epcCreate(b:any){const r=await this.db.epc.create({data:b}); await writeAudit(this.db,'Epc','CREATE',r.id,null,r); return r;}
 async epcUpdate(id:string,b:any){const old=await this.db.epc.findUnique({where:{id}}); const r=await this.db.epc.update({where:{id},data:b}); await writeAudit(this.db,'Epc','UPDATE',id,old,r); return r;}
 async epcDelete(id:string){const old=await this.db.epc.findUnique({where:{id}}); const r=await this.db.epc.delete({where:{id}}); await writeAudit(this.db,'Epc','DELETE',id,old,null); return r;}

 async epcInspectionCreate(b:any){
  const insp=await this.db.epcInspection.create({data:b});
  await this.db.epc.update({where:{id:b.epcId},data:{lastInspectionAt:insp.inspectedAt,...(b.nextInspectionAt?{nextInspectionAt:b.nextInspectionAt}:{})}});
  await writeAudit(this.db,'EpcInspection','CREATE',insp.id,null,insp);
  return insp;
 }

 epiInspectionList(){return this.db.epiInspection.findMany({include:{epi:true,employee:true},orderBy:{inspectedAt:'desc'}})}
 async epiInspectionCreate(b:any){const r=await this.db.epiInspection.create({data:b}); await writeAudit(this.db,'EpiInspection','CREATE',r.id,null,r); return r;}

 epcInspectionList(){return this.db.epcInspection.findMany({include:{epc:true},orderBy:{inspectedAt:'desc'}})}

 jobRiskProtectionList(){return this.db.jobRiskProtection.findMany({include:{epi:true,epc:true},orderBy:{jobTitle:'asc'}})}
 async jobRiskProtectionCreate(b:any){const r=await this.db.jobRiskProtection.create({data:b}); await writeAudit(this.db,'JobRiskProtection','CREATE',r.id,null,r); return r;}
 async jobRiskProtectionUpdate(id:string,b:any){const old=await this.db.jobRiskProtection.findUnique({where:{id}}); const r=await this.db.jobRiskProtection.update({where:{id},data:b}); await writeAudit(this.db,'JobRiskProtection','UPDATE',id,old,r); return r;}
 async jobRiskProtectionDelete(id:string){const old=await this.db.jobRiskProtection.findUnique({where:{id}}); const r=await this.db.jobRiskProtection.delete({where:{id}}); await writeAudit(this.db,'JobRiskProtection','DELETE',id,old,null); return r;}

 assignmentList(){return this.db.epiAssignment.findMany({include:{employee:true,epi:true,responsible:true},orderBy:{distributedAt:'desc'}})}
 assignmentGet(id:string){return this.db.epiAssignment.findUnique({where:{id},include:{employee:true,epi:true,responsible:true}})}
 // La création d'une dotation enregistre aussi automatiquement le mouvement
 // de stock correspondant — pas besoin de le saisir deux fois séparément.
 async assignmentCreate(b:any){
  const assignment=await this.db.$transaction(async(tx)=>{
   const epi=await tx.epi.findUnique({where:{id:b.epiId}});
   const a=await tx.epiAssignment.create({data:{...b,quantity:Number(b.quantity)}});
   if(epi){
    await tx.epiMovement.create({data:{epiId:b.epiId,type:epi.frequency==='DAILY'?'DAILY_DISTRIBUTION':'ANNUAL_DISTRIBUTION',quantity:Number(b.quantity),employeeId:b.employeeId,note:`Dotation ${a.code}`}});
   }
   return a;
  });
  await writeAudit(this.db,'EpiAssignment','CREATE',assignment.id,null,assignment);
  return assignment;
 }
 async assignmentUpdate(id:string,b:any){const old=await this.db.epiAssignment.findUnique({where:{id}}); const r=await this.db.epiAssignment.update({where:{id},data:b}); await writeAudit(this.db,'EpiAssignment','UPDATE',id,old,r); return r;}

 // Moteur de renouvellement : classe chaque dotation active par palier
 // d'échéance (90 / 60 / 30 jours, ou déjà échue) plutôt qu'une liste plate.
 async renewalBuckets(){
  const now=new Date();
  const in30=new Date(now); in30.setDate(in30.getDate()+30);
  const in60=new Date(now); in60.setDate(in60.getDate()+60);
  const in90=new Date(now); in90.setDate(in90.getDate()+90);
  const all=await this.db.epiAssignment.findMany({where:{status:'ACTIVE',renewalAt:{not:null}},include:{employee:true,epi:true}});
  return {
   expired:all.filter(a=>a.renewalAt! < now),
   within30:all.filter(a=>a.renewalAt! >= now && a.renewalAt! <= in30),
   within60:all.filter(a=>a.renewalAt! > in30 && a.renewalAt! <= in60),
   within90:all.filter(a=>a.renewalAt! > in60 && a.renewalAt! <= in90),
  };
 }

 maintenanceList(epcId?:string){return this.db.epcMaintenance.findMany({where:epcId?{epcId}:undefined,include:{epc:true,performedBy:true},orderBy:{date:'desc'}})}
 // Enregistrer une maintenance met aussi à jour automatiquement la fiche
 // EPC (dernière intervention, et prochaine échéance si renseignée) —
 // pas besoin de le faire deux fois séparément.
 async maintenanceCreate(b:any){
  const m=await this.db.$transaction(async(tx)=>{
   const rec=await tx.epcMaintenance.create({data:{...b,cost:b.cost!==undefined&&b.cost!==null?Number(b.cost):null}});
   await tx.epc.update({where:{id:b.epcId},data:{lastInspectionAt:rec.date,...(b.nextMaintenanceAt?{nextInspectionAt:b.nextMaintenanceAt}:{})}});
   return rec;
  });
  await writeAudit(this.db,'EpcMaintenance','CREATE',m.id,null,m);
  return m;
 }
 async maintenanceUpdate(id:string,b:any){const old=await this.db.epcMaintenance.findUnique({where:{id}}); const r=await this.db.epcMaintenance.update({where:{id},data:{...b,...(b.cost!==undefined?{cost:b.cost===null?null:Number(b.cost)}:{})}}); await writeAudit(this.db,'EpcMaintenance','UPDATE',id,old,r); return r;}
 async maintenanceDelete(id:string){const old=await this.db.epcMaintenance.findUnique({where:{id}}); const r=await this.db.epcMaintenance.delete({where:{id}}); await writeAudit(this.db,'EpcMaintenance','DELETE',id,old,null); return r;}
}
