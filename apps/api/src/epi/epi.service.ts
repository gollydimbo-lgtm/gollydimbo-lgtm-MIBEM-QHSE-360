import { Injectable } from '@nestjs/common'; import { PrismaService } from '../common/prisma.service'; import {EpiFrequency,EpiMovementType} from '@prisma/client'; @Injectable() export class EpiService{constructor(private db:PrismaService){} async dashboard(date=new Date()){const start=new Date(date);start.setHours(0,0,0,0);const end=new Date(start);end.setDate(end.getDate()+1);const [epis,movements,headcount,employees]=await Promise.all([this.db.epi.findMany({where:{active:true}}),this.db.epiMovement.findMany(),this.db.dailyHeadcount.findUnique({where:{date:start}}),this.db.employee.count({where:{active:true}})]); const stock=epis.map(e=>{const ms=movements.filter(m=>m.epiId===e.id);return {...e,stock:ms.reduce((s,m)=>s+((m.type===EpiMovementType.RECEIPT||m.type===EpiMovementType.ADJUSTMENT)?m.quantity:-m.quantity),0),dailyDistributed:ms.filter(m=>m.distributionDate>=start&&m.distributionDate<end&&m.type===EpiMovementType.DAILY_DISTRIBUTION).reduce((s,m)=>s+m.quantity,0)}}); return {date:start,effectiveHeadcount:headcount?.headcount??employees,dailyExpected:stock.filter(e=>e.frequency===EpiFrequency.DAILY).map(e=>({epi:e.name,quantity:headcount?.headcount??employees})),stock};} async annualRenewals(days=30){const until=new Date();until.setDate(until.getDate()+days);return this.db.epiAssignment.findMany({where:{renewalAt:{lte:until}},include:{employee:true,epi:true},orderBy:{renewalAt:'asc'}})}
 employeeList(){return this.db.employee.findMany({orderBy:{lastName:'asc'}})} employeeCreate(b:any){return this.db.employee.create({data:b})} employeeUpdate(id:string,b:any){return this.db.employee.update({where:{id},data:b})} employeeDelete(id:string){return this.db.employee.delete({where:{id}})}
 catalogList(){return this.db.epi.findMany({orderBy:{name:'asc'}})} catalogCreate(b:any){return this.db.epi.create({data:b})} catalogUpdate(id:string,b:any){return this.db.epi.update({where:{id},data:b})} catalogDelete(id:string){return this.db.epi.delete({where:{id}})}
 movementCreate(b:any){return this.db.epiMovement.create({data:b})}
 epiCategoryList(){return this.db.epiCategory.findMany({orderBy:{name:'asc'}})} epiCategoryCreate(b:any){return this.db.epiCategory.create({data:b})} epiCategoryUpdate(id:string,b:any){return this.db.epiCategory.update({where:{id},data:b})} epiCategoryDelete(id:string){return this.db.epiCategory.delete({where:{id}})}
 epcCategoryList(){return this.db.epcCategory.findMany({orderBy:{name:'asc'}})} epcCategoryCreate(b:any){return this.db.epcCategory.create({data:b})} epcCategoryUpdate(id:string,b:any){return this.db.epcCategory.update({where:{id},data:b})} epcCategoryDelete(id:string){return this.db.epcCategory.delete({where:{id}})}
 epcList(){return this.db.epc.findMany({include:{category:true,responsible:true},orderBy:{name:'asc'}})} epcCreate(b:any){return this.db.epc.create({data:b})} epcUpdate(id:string,b:any){return this.db.epc.update({where:{id},data:b})} epcDelete(id:string){return this.db.epc.delete({where:{id}})}
 async epcInspectionCreate(b:any){const insp=await this.db.epcInspection.create({data:b}); await this.db.epc.update({where:{id:b.epcId},data:{lastInspectionAt:insp.inspectedAt,...(b.nextInspectionAt?{nextInspectionAt:b.nextInspectionAt}:{})}}); return insp;}
 epiInspectionList(){return this.db.epiInspection.findMany({include:{epi:true,employee:true},orderBy:{inspectedAt:'desc'}})} epiInspectionCreate(b:any){return this.db.epiInspection.create({data:b})}
 epcInspectionList(){return this.db.epcInspection.findMany({include:{epc:true},orderBy:{inspectedAt:'desc'}})}
 jobRiskProtectionList(){return this.db.jobRiskProtection.findMany({include:{epi:true,epc:true},orderBy:{jobTitle:'asc'}})} jobRiskProtectionCreate(b:any){return this.db.jobRiskProtection.create({data:b})} jobRiskProtectionUpdate(id:string,b:any){return this.db.jobRiskProtection.update({where:{id},data:b})} jobRiskProtectionDelete(id:string){return this.db.jobRiskProtection.delete({where:{id}})}
 assignmentList(){return this.db.epiAssignment.findMany({include:{employee:true,epi:true,responsible:true},orderBy:{distributedAt:'desc'}})}
 assignmentGet(id:string){return this.db.epiAssignment.findUnique({where:{id},include:{employee:true,epi:true,responsible:true}})}
 // La création d'une dotation enregistre aussi automatiquement le mouvement
 // de stock correspondant — pas besoin de le saisir deux fois séparément.
 async assignmentCreate(b:any){
  return this.db.$transaction(async(tx)=>{
   const epi=await tx.epi.findUnique({where:{id:b.epiId}});
   const assignment=await tx.epiAssignment.create({data:{...b,quantity:Number(b.quantity)}});
   if(epi){
    await tx.epiMovement.create({data:{epiId:b.epiId,type:epi.frequency==='DAILY'?'DAILY_DISTRIBUTION':'ANNUAL_DISTRIBUTION',quantity:Number(b.quantity),employeeId:b.employeeId,note:`Dotation ${assignment.code}`}});
   }
   return assignment;
  });
 }
 assignmentUpdate(id:string,b:any){return this.db.epiAssignment.update({where:{id},data:b})}
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
}
