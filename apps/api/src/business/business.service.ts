import { Injectable } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { writeAudit } from '../common/audit-log.helper';
@Injectable() export class BusinessService { constructor(private db:PrismaService){}
 dashboard(){return Promise.all([this.db.nonConformity.count({where:{status:{not:'CLOSED'}}}),this.db.action.count({where:{status:{not:'CLOSED'}}}),this.db.safetyEvent.count(),this.db.risk.count({where:{status:'ACTIVE',score:{gte:9}}}),this.db.qualityControl.count()]).then(([nonConformitiesOpen,actionsOpen,safetyEvents,highRisks,qualityControls])=>({nonConformitiesOpen,actionsOpen,safetyEvents,highRisks,qualityControls}));}
 qualityList(){return this.db.qualityControl.findMany({orderBy:{controlDate:'desc'}})} qualityCreate(b:any){return this.db.qualityControl.create({data:b})} qualityUpdate(id:string,b:any){return this.db.qualityControl.update({where:{id},data:b})} qualityDelete(id:string){return this.db.qualityControl.delete({where:{id}})}
 ncList(status?:string){return this.db.nonConformity.findMany({where:status?{status}:undefined,include:{actions:true,epi:true,epc:true,risk:true,workUnit:true,declarant:true,responsible:true,containmentActions:true,causes:true},orderBy:{createdAt:'desc'}})}
 ncGet(id:string){return this.db.nonConformity.findUnique({where:{id},include:{actions:{include:{responsible:true}},epi:true,epc:true,risk:true,workUnit:true,declarant:true,responsible:true,processus:true,fournisseur:true,containmentActions:{include:{responsable:true},orderBy:{date:'desc'}},causes:{orderBy:{createdAt:'asc'}},costs:{orderBy:{createdAt:'desc'}}}})}

 // === NON-CONFORMITÉS — moteur de criticité, paramétrage ==================

 async ncSettingsGet(){
  let s=await this.db.ncSettings.findFirst();
  if(!s) s=await this.db.ncSettings.create({data:{}});
  return s;
 }
 async ncSettingsUpdate(b:any){
  const current=await this.ncSettingsGet();
  return this.db.ncSettings.update({where:{id:current.id},data:b});
 }
 private ncNiveau(score:number,seuils:{seuilModeree:number,seuilMajeure:number,seuilCritique:number}){
  if(score>=seuils.seuilCritique) return 'CRITIQUE';
  if(score>=seuils.seuilMajeure) return 'MAJEURE';
  if(score>=seuils.seuilModeree) return 'MODEREE';
  return 'MINEURE';
 }
 // Score de criticité sur 100, à partir de gravité/probabilité/étendue
 // (1 à 5 chacun, donc 125 au maximum, ramené sur 100) — jamais saisi
 // manuellement, toujours recalculé à l'écriture.
 private async calculerCriticiteNc(b:any){
  const settings=await this.ncSettingsGet();
  const out:any={};
  if(b.gravite!=null&&b.probabilite!=null){
   const g=Number(b.gravite),p=Number(b.probabilite),e=Number(b.etendue)||1;
   const brut=g*p*e;
   const score=Math.min(100,Math.round((brut/125)*100));
   out.criticiteScore=score; out.criticiteNiveau=this.ncNiveau(score,settings);
  }
  if(b.quantiteNc!=null&&b.quantiteControlee){
   out.tauxNc=Math.round((Number(b.quantiteNc)/Number(b.quantiteControlee))*1000)/10;
  }
  if(!b.dueDate&&!b.id){
   out.dueDate=new Date(Date.now()+settings.delaiStandardJours*86400000);
  }
  return out;
 }
 async ncCreate(b:any){
  const calc=await this.calculerCriticiteNc(b);
  const nc=await this.db.nonConformity.create({data:{...b,...calc}});
  await writeAudit(this.db,'NC','CREATE',nc.id,null,nc);
  return nc;
 }
 async ncUpdate(id:string,b:any){
  const current=await this.db.nonConformity.findUnique({where:{id}});
  if(!current) throw new Error('Non-conformité introuvable');
  if(b.status==='CLOSED'&&current.status!=='CLOSED') throw new Error('Utilisez la clôture dédiée (vérification d\'efficacité requise) plutôt qu\'une modification directe du statut.');
  const calc=await this.calculerCriticiteNc({...current,...b,id});
  const nc=await this.db.nonConformity.update({where:{id},data:{...b,...calc}});
  await writeAudit(this.db,'NC','UPDATE',id,current,nc);
  return nc;
 }
 async ncDelete(id:string){
  const current=await this.db.nonConformity.findUnique({where:{id}});
  const nc=await this.db.nonConformity.delete({where:{id}});
  await writeAudit(this.db,'NC','DELETE',id,current,null);
  return nc;
 }

 // Confinement / action immédiate (point 9) — sécurise la situation tout de
 // suite, distinct des actions correctives qui traitent la cause.
 ncContainmentActionList(nonConformityId:string){return this.db.ncContainmentAction.findMany({where:{nonConformityId},include:{responsable:true},orderBy:{date:'desc'}})}
 ncContainmentActionCreate(b:any){return this.db.ncContainmentAction.create({data:b})}
 ncContainmentActionUpdate(id:string,b:any){return this.db.ncContainmentAction.update({where:{id},data:b})}
 ncContainmentActionDelete(id:string){return this.db.ncContainmentAction.delete({where:{id}})}

 // === NON-CONFORMITÉS — analyse des causes et vérification d'efficacité ===

 ncCauseList(nonConformityId:string){return this.db.ncCause.findMany({where:{nonConformityId},orderBy:{createdAt:'asc'}})}
 async ncCauseCreate(b:any){
  const cause=await this.db.ncCause.create({data:b});
  if(b.estRacine) await this.db.nonConformity.update({where:{id:b.nonConformityId},data:{causeRacineIdentifiee:true}});
  return cause;
 }
 ncCauseUpdate(id:string,b:any){return this.db.ncCause.update({where:{id},data:b})}
 ncCauseDelete(id:string){return this.db.ncCause.delete({where:{id}})}

 // Vérification d'efficacité (point 15) — étape obligatoire avant clôture.
 async ncEffectivenessCheck(id:string,b:any){
  const nc=await this.db.nonConformity.update({where:{id},data:{
   effectivenessResult:b.result, effectivenessCheckedAt:new Date(), effectivenessNotes:b.notes||null,
  }});
  await writeAudit(this.db,'NC','UPDATE',id,null,nc);
  return nc;
 }
 // La clôture définitive est refusée tant que l'efficacité n'a pas été
 // évaluée comme « Efficace » — une action inefficace ou non vérifiée
 // renvoie vers une nouvelle analyse plutôt que de clore silencieusement.
 async ncClose(id:string,b:any){
  const nc=await this.db.nonConformity.findUnique({where:{id}});
  if(!nc) throw new Error('Non-conformité introuvable');
  if(nc.effectivenessResult!=='EFFICACE'){
   throw new Error("Clôture impossible : la vérification d'efficacité doit d'abord conclure à une action efficace.");
  }
  const closed=await this.db.nonConformity.update({where:{id},data:{status:'CLOSED',closedAt:new Date(),effectivenessNotes:b?.notes??nc.effectivenessNotes}});
  await writeAudit(this.db,'NC','UPDATE',id,nc,closed);
  return closed;
 }
 async ncReopen(id:string){
  const nc=await this.db.nonConformity.findUnique({where:{id}});
  if(!nc) throw new Error('Non-conformité introuvable');
  const reopened=await this.db.nonConformity.update({where:{id},data:{status:'OPEN',closedAt:null,reopenedCount:{increment:1}}});
  await writeAudit(this.db,'NC','UPDATE',id,nc,reopened);
  return reopened;
 }

 // Tableau de bord réel (point 2) — chaque KPI reste `null` si non calculable.
 async ncDashboard(){
  const now=new Date();
  const [ncs,actions]=await Promise.all([
   this.db.nonConformity.findMany({select:{id:true,status:true,classification:true,criticiteNiveau:true,createdAt:true,closedAt:true,dueDate:true,reopenedCount:true,effectivenessResult:true}}),
   this.db.action.findMany({where:{nonConformityId:{not:null}},select:{status:true,dueDate:true}}),
  ]);
  const total=ncs.length;
  const ouvertes=ncs.filter(n=>n.status!=='CLOSED').length;
  const cloturees=ncs.filter(n=>n.status==='CLOSED').length;
  const reouvertes=ncs.filter(n=>n.reopenedCount>0).length;
  const enRetard=ncs.filter(n=>n.status!=='CLOSED'&&n.dueDate&&new Date(n.dueDate)<now).length;
  const critiques=ncs.filter(n=>n.criticiteNiveau==='CRITIQUE').length;
  const majeures=ncs.filter(n=>n.criticiteNiveau==='MAJEURE').length;
  const nouvelles=ncs.filter(n=>new Date(n.createdAt)>new Date(now.getTime()-7*86400000)).length;
  const tauxCloture=total?Math.round((cloturees/total)*1000)/10:null;
  const clotureesDansLesDelais=ncs.filter(n=>n.status==='CLOSED'&&n.closedAt&&(!n.dueDate||new Date(n.closedAt)<=new Date(n.dueDate)));
  const tauxClotureDansLesDelais=cloturees?Math.round((clotureesDansLesDelais.length/cloturees)*1000)/10:null;
  const tauxEnRetard=ouvertes?Math.round((enRetard/ouvertes)*1000)/10:null;
  const closedWithDelay=ncs.filter(n=>n.closedAt);
  const delaiMoyenTraitement=closedWithDelay.length
   ?Math.round(closedWithDelay.reduce((s,n)=>s+(new Date(n.closedAt!).getTime()-new Date(n.createdAt).getTime()),0)/closedWithDelay.length/86400000*10)/10
   :null;
  const ouvertesData=ncs.filter(n=>n.status!=='CLOSED');
  const ageMoyenOuvertes=ouvertesData.length
   ?Math.round(ouvertesData.reduce((s,n)=>s+(now.getTime()-new Date(n.createdAt).getTime()),0)/ouvertesData.length/86400000*10)/10
   :null;
  const plusAncienne=ouvertesData.length?ouvertesData.reduce((a,b)=>new Date(a.createdAt)<new Date(b.createdAt)?a:b):null;
  const actionsEnRetard=actions.filter(a=>a.status!=='CLOSED'&&a.dueDate&&new Date(a.dueDate)<now).length;
  const actionsEvaluees=ncs.filter(n=>n.effectivenessResult);
  const actionsEfficaces=ncs.filter(n=>n.effectivenessResult==='EFFICACE');
  const tauxEfficacite=actionsEvaluees.length?Math.round((actionsEfficaces.length/actionsEvaluees.length)*1000)/10:null;
  return {
   total,nouvelles,ouvertes,cloturees,reouvertes,enRetard,critiques,majeures,
   tauxCloture,tauxClotureDansLesDelais,tauxEnRetard,delaiMoyenTraitement,ageMoyenOuvertes,
   ncPlusAncienneDate:plusAncienne?.createdAt??null,
   actionsEnRetard,tauxEfficaciteActions:tauxEfficacite,
   recurrentes:await this.ncRecurrentesCount(),
   ...await this.ncCoutStats(),
  };
 }

 // === NON-CONFORMITÉS — Phase 3 : récurrence, coût, alertes ==============

 // Regroupe les NC par processus + début de titre (approximation de la
 // similarité, cohérente avec le même mécanisme utilisé pour les audits) —
 // ne retient que ce qui s'est répété au moins deux fois (point 16).
 async ncRecurrentes(){
  const ncs=await this.db.nonConformity.findMany({
   include:{processus:{select:{nom:true}}},
   orderBy:{createdAt:'desc'},
  });
  const groupes:Record<string,any[]>={};
  for(const n of ncs){
   const cle=`${n.processusId||'sans-processus'}::${(n.title||'').trim().toLowerCase().slice(0,60)}`;
   (groupes[cle]=groupes[cle]||[]).push(n);
  }
  return Object.values(groupes).filter(g=>g.length>=2).map(g=>({
   titre:g[0].title, processus:g[0].processus?.nom||'Sans processus',
   occurrences:g.length, premiereOccurrence:g[g.length-1].occurredAt, derniereOccurrence:g[0].occurredAt,
   historique:g.map(n=>({id:n.id,code:n.code,date:n.occurredAt,statut:n.status})),
  })).sort((a,b)=>b.occurrences-a.occurrences);
 }
 private async ncRecurrentesCount(){ return (await this.ncRecurrentes()).reduce((s,g)=>s+g.occurrences,0); }

 ncCostList(nonConformityId:string){return this.db.ncCost.findMany({where:{nonConformityId},orderBy:{createdAt:'desc'}})}
 ncCostCreate(b:any){return this.db.ncCost.create({data:b})}
 ncCostUpdate(id:string,b:any){return this.db.ncCost.update({where:{id},data:b})}
 ncCostDelete(id:string){return this.db.ncCost.delete({where:{id}})}
 private async ncCoutStats(){
  const costs=await this.db.ncCost.findMany({select:{montant:true,nonConformityId:true}});
  const coutTotal=costs.reduce((s,c)=>s+c.montant,0);
  const ncAvecCout=new Set(costs.map(c=>c.nonConformityId)).size;
  return {coutTotalNonQualite:Math.round(coutTotal*100)/100, coutMoyenParNc:ncAvecCout?Math.round((coutTotal/ncAvecCout)*100)/100:null};
 }

 // Centre d'alertes (point 24) — les mêmes conditions que celles listées
 // dans le cahier des charges, jamais de champ recalculé silencieusement.
 async ncAlertes(){
  const now=new Date();
  const ncs=await this.db.nonConformity.findMany({where:{status:{not:'CLOSED'}},include:{actions:true,causes:true}});
  const alertes:any[]=[];
  for(const n of ncs){
   if(n.criticiteNiveau==='CRITIQUE') alertes.push({id:n.id,label:`NC critique : ${n.title}`,niveau:'CRITIQUE'});
   if(!n.responsibleId) alertes.push({id:n.id,label:`Aucun responsable désigné : ${n.title}`,niveau:'ATTENTION'});
   if(!n.actions.length) alertes.push({id:n.id,label:`Aucune action définie : ${n.title}`,niveau:'ATTENTION'});
   if(n.dueDate&&new Date(n.dueDate)<now) alertes.push({id:n.id,label:`Délai dépassé : ${n.title}`,niveau:'URGENT'});
   if(n.actions.some(a=>a.status!=='CLOSED'&&a.dueDate&&new Date(a.dueDate)<now)) alertes.push({id:n.id,label:`Action en retard : ${n.title}`,niveau:'URGENT'});
   if(!n.causes.length) alertes.push({id:n.id,label:`Aucune cause identifiée : ${n.title}`,niveau:'ATTENTION'});
   if(!n.effectivenessCheckedAt) alertes.push({id:n.id,label:`Vérification d'efficacité non réalisée : ${n.title}`,niveau:'ATTENTION'});
   if(n.effectivenessResult==='INEFFICACE') alertes.push({id:n.id,label:`Action inefficace : ${n.title}`,niveau:'URGENT'});
   if(n.reopenedCount>0) alertes.push({id:n.id,label:`NC réouverte (${n.reopenedCount}x) : ${n.title}`,niveau:'ATTENTION'});
  }
  const poids:any={CRITIQUE:0,URGENT:1,ATTENTION:2,INFORMATION:3};
  return alertes.sort((a,b)=>poids[a.niveau]-poids[b.niveau]);
 }

 // === NON-CONFORMITÉS — Phase 4 : tendances et synthèse ===================

 async ncTrends(){
  const depuis=new Date(); depuis.setMonth(depuis.getMonth()-11); depuis.setDate(1); depuis.setHours(0,0,0,0);
  const ncs=await this.db.nonConformity.findMany({where:{createdAt:{gte:depuis}},select:{createdAt:true,status:true,criticiteNiveau:true}});
  const mois:{cle:string,label:string,nouvelles:number,critiques:number}[]=[];
  for(let i=11;i>=0;i--){
   const d=new Date(); d.setMonth(d.getMonth()-i); d.setDate(1);
   const label=d.toLocaleDateString('fr-FR',{month:'short',year:'2-digit'});
   const duMois=ncs.filter(n=>{const nd=new Date(n.createdAt);return nd.getFullYear()===d.getFullYear()&&nd.getMonth()===d.getMonth();});
   mois.push({cle:`${d.getFullYear()}-${d.getMonth()}`,label,nouvelles:duMois.length,critiques:duMois.filter(n=>n.criticiteNiveau==='CRITIQUE').length});
  }
  return mois;
 }

 async ncSyntheseDirection(){
  const [dashboard,trends,recurrentes]=await Promise.all([this.ncDashboard(),this.ncTrends(),this.ncRecurrentes()]);
  const parProcessus=await this.db.nonConformity.groupBy({by:['processusId'],_count:{_all:true},where:{processusId:{not:null}}});
  const processusDetails=await this.db.processus.findMany({where:{id:{in:parProcessus.map(p=>p.processusId).filter((id):id is string=>!!id)}},select:{id:true,nom:true}});
  const parProcessusLabel=parProcessus.map(p=>({processus:processusDetails.find(d=>d.id===p.processusId)?.nom||'Inconnu',nombre:p._count._all})).sort((a,b)=>b.nombre-a.nombre);
  return {
   dashboard, tendanceRecente:trends.slice(-3),
   processusLesPlusProblematiques:parProcessusLabel.slice(0,5),
   principalesRecurrences:recurrentes.slice(0,5),
   genereLe:new Date(),
  };
 }

 // Point 19 du cahier des charges du Registre des risques : proposer de
 // créer (ou relier) un risque à partir d'une non-conformité ou d'un
 // accident, en préremplissant ce qui est déjà connu — jamais un risque
 // vide, et jamais de doublon si un risque est déjà relié.
 async nonConformityGenerateRisk(id:string){
  const nc=await this.db.nonConformity.findUnique({where:{id}});
  if(!nc) throw new Error('Non-conformité introuvable');
  if(nc.riskId) throw new Error('Cette non-conformité est déjà reliée à un risque');
  const calc=await this.calculerRisque({severity:nc.severity||3,probability:3});
  const risk=await this.db.risk.create({data:{
   code:`RISK-${Date.now()}-${Math.random().toString(36).slice(2,6).toUpperCase()}`, hazard:nc.title, hazardousEvent:nc.description||undefined,
   processusId:nc.processusId, fournisseurId:nc.fournisseurId, ...calc,
  }});
  await writeAudit(this.db,'RISK','CREATE',risk.id,null,risk);
  await this.db.nonConformity.update({where:{id},data:{riskId:risk.id}});
  return risk;
 }

 // Un accident survenu correspond par définition à une probabilité déjà
 // avérée — 4/5 par défaut plutôt que la valeur neutre 3/5, modifiable
 // ensuite comme tout autre risque.
 async safetyEventGenerateRisk(id:string){
  const ev=await this.db.safetyEvent.findUnique({where:{id}});
  if(!ev) throw new Error('Événement introuvable');
  if(ev.riskId) throw new Error('Cet événement est déjà relié à un risque');
  const calc=await this.calculerRisque({severity:ev.severity||3,probability:4});
  const risk=await this.db.risk.create({data:{
   code:`RISK-${Date.now()}-${Math.random().toString(36).slice(2,6).toUpperCase()}`, hazard:ev.title, hazardousEvent:ev.mecanisme||ev.description||undefined,
   potentialDamage:ev.consequenceMaterielle||ev.consequenceEnvironnementale||undefined,
   activity:ev.activite, processusId:ev.processusId, fournisseurId:ev.fournisseurId, ...calc,
  }});
  await writeAudit(this.db,'RISK','CREATE',risk.id,null,risk);
  await this.db.safetyEvent.update({where:{id},data:{riskId:risk.id}});
  return risk;
 }
 actionList(status?:string){return this.db.action.findMany({where:status?{status}:undefined,include:{nonConformity:true,responsible:true,workUnit:true,parentAction:true,subActions:true},orderBy:{dueDate:'asc'}})}
 actionGet(id:string){return this.db.action.findUnique({where:{id},include:{nonConformity:true,responsible:true,workUnit:true,processus:true,risk:true,auditFinding:true,parentAction:true,subActions:{include:{responsible:true}},causes:{orderBy:{createdAt:'asc'}},extensions:{include:{demandeur:true,validateur:true},orderBy:{createdAt:'desc'}},links:true}})}
 actionCreate(b:any){return this.db.action.create({data:b})}
 async actionUpdate(id:string,b:any){
  const current=await this.db.action.findUnique({where:{id}});
  if(!current) throw new Error('Action introuvable');
  if(b.status==='CLOSED'&&current.status!=='CLOSED') throw new Error('Utilisez la clôture dédiée (vérification d\'efficacité requise) plutôt qu\'une modification directe du statut.');
  const action=await this.db.action.update({where:{id},data:b});
  // La progression d'une CAPA peut se déduire de ses sous-actions plutôt
  // que d'être ressaisie manuellement au niveau parent (point 11).
  if(current.parentActionId) await this.actionRecalcAvancement(current.parentActionId);
  return action;
 }
 actionDelete(id:string){return this.db.action.delete({where:{id}})}
 private async actionRecalcAvancement(parentId:string){
  const subs=await this.db.action.findMany({where:{parentActionId:parentId},select:{avancement:true}});
  if(!subs.length) return;
  const moyenne=Math.round(subs.reduce((s,a)=>s+a.avancement,0)/subs.length);
  await this.db.action.update({where:{id:parentId},data:{avancement:moyenne}});
 }

 // === ACTIONS CAPA — Phase 3 : efficacité, clôture, prolongation, réouverture

 async actionEffectivenessCheck(id:string,b:any){
  return this.db.action.update({where:{id},data:{effectivenessResult:b.result,effectivenessCheckedAt:new Date(),effectivenessNotes:b.notes||null}});
 }
 // Règle métier fondamentale (point 35) : « réalisée » n'est jamais
 // synonyme d'« efficace ». La clôture est refusée tant que la vérification
 // d'efficacité n'a pas conclu à une action efficace.
 async actionClose(id:string,b:any){
  const action=await this.db.action.findUnique({where:{id}});
  if(!action) throw new Error('Action introuvable');
  if(action.effectivenessResult!=='EFFICACE'){
   throw new Error("Clôture impossible : la vérification d'efficacité doit d'abord conclure à une action efficace.");
  }
  const closed=await this.db.action.update({where:{id},data:{status:'CLOSED',dateCloture:new Date(),completedAt:action.completedAt||new Date()}});
  if(action.parentActionId) await this.actionRecalcAvancement(action.parentActionId);
  return closed;
 }
 async actionReopen(id:string){
  const action=await this.db.action.findUnique({where:{id}});
  if(!action) throw new Error('Action introuvable');
  return this.db.action.update({where:{id},data:{status:'OPEN',dateCloture:null,reopenedCount:{increment:1}}});
 }
 // Une prolongation ne remplace jamais silencieusement l'échéance : l'ancienne
 // reste tracée dans ActionExtension (point 26).
 async actionExtensionCreate(id:string,b:any){
  const action=await this.db.action.findUnique({where:{id}});
  if(!action) throw new Error('Action introuvable');
  const extension=await this.db.actionExtension.create({data:{
   actionId:id, ancienneEcheance:action.dueDate, nouvelleEcheance:new Date(b.nouvelleEcheance),
   motif:b.motif, demandeurId:b.demandeurId||null, validateurId:b.validateurId||null,
  }});
  await this.db.action.update({where:{id},data:{dueDate:new Date(b.nouvelleEcheance)}});
  return extension;
 }
 actionExtensionList(actionId:string){return this.db.actionExtension.findMany({where:{actionId},include:{demandeur:true,validateur:true},orderBy:{createdAt:'desc'}})}

 // Centre d'alertes avec escalade (points 19-20) — le niveau grimpe avec le
 // retard plutôt que de rester fixe, pour refléter une vraie escalade.
 async actionAlertes(){
  const now=new Date();
  const dans7Jours=new Date(now.getTime()+7*86400000);
  const actions=await this.db.action.findMany({where:{status:{notIn:['CLOSED','CANCELLED']}},select:{id:true,title:true,criticite:true,dueDate:true,status:true,effectivenessResult:true}});
  const alertes:any[]=[];
  for(const a of actions){
   if(a.criticite==='CRITIQUE') alertes.push({id:a.id,label:`Action critique non traitée : ${a.title}`,niveau:'CRITIQUE'});
   if(a.status==='VALIDATION_PENDING') alertes.push({id:a.id,label:`En attente de validation : ${a.title}`,niveau:'ATTENTION'});
   if(a.effectivenessResult==='INEFFICACE') alertes.push({id:a.id,label:`CAPA déclarée inefficace : ${a.title}`,niveau:'URGENT'});
   if(a.dueDate){
    const joursRetard=Math.floor((now.getTime()-new Date(a.dueDate).getTime())/86400000);
    if(joursRetard>14) alertes.push({id:a.id,label:`Retard important (${joursRetard}j) — escalade Direction : ${a.title}`,niveau:'CRITIQUE'});
    else if(joursRetard>7) alertes.push({id:a.id,label:`Retard (${joursRetard}j) — escalade Responsable QHSE : ${a.title}`,niveau:'URGENT'});
    else if(joursRetard>0) alertes.push({id:a.id,label:`En retard (${joursRetard}j) : ${a.title}`,niveau:'ATTENTION'});
    else if(new Date(a.dueDate)<=dans7Jours) alertes.push({id:a.id,label:`Échéance proche : ${a.title}`,niveau:'INFORMATION'});
   }
  }
  const poids:any={CRITIQUE:0,URGENT:1,ATTENTION:2,INFORMATION:3};
  return alertes.sort((x,y)=>poids[x.niveau]-poids[y.niveau]);
 }

 // === ACTIONS CAPA — Phase 4 : score de performance, tendances ===========

 async actionPerformanceScore(){
  const dash=await this.actionDashboard();
  const actionsEvaluees=await this.db.action.count({where:{effectivenessResult:{not:null},parentActionId:null}});
  const actionsEfficaces=await this.db.action.count({where:{effectivenessResult:'EFFICACE',parentActionId:null}});
  const tauxEfficacite=actionsEvaluees?Math.round((actionsEfficaces/actionsEvaluees)*1000)/10:null;
  // Indice composite configurable en poids fixes pour l'instant — clôture,
  // respect des délais et efficacité pèsent chacun un tiers.
  const composantes=[dash.tauxCloture,dash.tauxEnRetard!=null?100-dash.tauxEnRetard:null,tauxEfficacite].filter((v):v is number=>v!=null);
  const score=composantes.length?Math.round(composantes.reduce((s,v)=>s+v,0)/composantes.length):null;
  const niveau=score==null?null:score>=85?'EXCELLENT':score>=70?'BON':score>=50?'A_SURVEILLER':score>=30?'INSUFFISANT':'CRITIQUE';
  return {score,niveau,tauxEfficacite,...dash};
 }

 async actionTrends(){
  const depuis=new Date(); depuis.setMonth(depuis.getMonth()-11); depuis.setDate(1); depuis.setHours(0,0,0,0);
  const actions=await this.db.action.findMany({where:{createdAt:{gte:depuis},parentActionId:null},select:{createdAt:true,completedAt:true,status:true}});
  const mois:{cle:string,label:string,creees:number,realisees:number}[]=[];
  for(let i=11;i>=0;i--){
   const d=new Date(); d.setMonth(d.getMonth()-i); d.setDate(1);
   const label=d.toLocaleDateString('fr-FR',{month:'short',year:'2-digit'});
   const creees=actions.filter(a=>{const ad=new Date(a.createdAt);return ad.getFullYear()===d.getFullYear()&&ad.getMonth()===d.getMonth();}).length;
   const realisees=actions.filter(a=>{if(!a.completedAt) return false;const ad=new Date(a.completedAt);return ad.getFullYear()===d.getFullYear()&&ad.getMonth()===d.getMonth();}).length;
   mois.push({cle:`${d.getFullYear()}-${d.getMonth()}`,label,creees,realisees});
  }
  return mois;
 }

 actionCauseList(actionId:string){return this.db.actionCause.findMany({where:{actionId},orderBy:{createdAt:'asc'}})}

 // === MATRICE DE LIAISON CAPA GÉNÉRIQUE ===================================
 // Une seule table de liaison, réutilisée par tous les modules, plutôt
 // qu'une table CAPA par module (recommandation explicite du cahier des
 // charges). Les colonnes dédiées existantes sur Action restent utilisées
 // pour la source principale ; CapaLink complète pour le reste :
 // N sources -> 1 CAPA et 1 source -> N CAPA.
 private readonly CAPA_LEGACY_FIELD:Record<string,string>={
  NON_CONFORMITY:'nonConformityId', RISK:'riskId', AUDIT_FINDING:'auditFindingId', SAFETY_EVENT:'safetyEventId',
  RECLAMATION:'reclamationId', FOURNISSEUR:'fournisseurId', PROCESSUS:'processusId',
  RISQUE_SANITAIRE:'risqueSanitaireId', ERGONOMIE:'ergonomieId', ENVIRONNEMENT_ASPECT:'environnementAspectId',
 };

 capaLinksByAction(actionId:string){return this.db.capaLink.findMany({where:{actionId},include:{createdBy:true},orderBy:{createdAt:'desc'}})}
 // Union de la matrice générique ET de la colonne dédiée héritée quand ce
 // module en a une — sinon une CAPA créée via un ancien bouton "+ Action"
 // (qui ne passe pas par CapaLink) resterait invisible ici alors qu'elle
 // existe bien (même logique que capaDetectDuplicates, pour rester cohérent).
 async capaLinksBySource(sourceModule:string,sourceEntityId:string){
  const viaLink=await this.db.capaLink.findMany({where:{sourceModule,sourceEntityId},include:{action:{include:{responsible:true}}}});
  const champ=this.CAPA_LEGACY_FIELD[sourceModule];
  let viaLegacy:{action:any}[]=[];
  if(champ){
   const actions=await this.db.action.findMany({where:{[champ]:sourceEntityId},include:{responsible:true}});
   viaLegacy=actions.map(action=>({action}));
  }
  const tous=[...viaLink.map(l=>({id:l.id,action:l.action})),...viaLegacy.map((l,i)=>({id:`legacy-${i}`,action:l.action}))];
  return Array.from(new Map(tous.map(l=>[l.action.id,l])).values());
 }
 // Rattache une source supplémentaire à une CAPA déjà existante — c'est ce
 // qui permet à une même action de traiter plusieurs sources (point 8).
 capaLinkAdd(actionId:string,b:any){
  return this.db.capaLink.create({data:{actionId,sourceModule:b.sourceModule,sourceEntityId:b.sourceEntityId,relationType:b.relationType||'GENEREE_PAR',metadata:b.metadata,createdById:b.createdById||null}});
 }
 capaLinkDelete(id:string){return this.db.capaLink.delete({where:{id}})}

 // Détecte les CAPA déjà liées à cette source, via la matrice générique ET
 // via la colonne dédiée quand ce module en possède une — pour ne jamais
 // proposer un doublon silencieusement (point 5).
 async capaDetectDuplicates(sourceModule:string,sourceEntityId:string){
  const viaLink=await this.db.capaLink.findMany({where:{sourceModule,sourceEntityId},include:{action:{include:{responsible:true}}}});
  const champ=this.CAPA_LEGACY_FIELD[sourceModule];
  let viaLegacy:any[]=[];
  if(champ) viaLegacy=await this.db.action.findMany({where:{[champ]:sourceEntityId},include:{responsible:true}});
  const actions=[...viaLink.map(l=>l.action),...viaLegacy];
  return Array.from(new Map(actions.map(a=>[a.id,a])).values());
 }

 // Point de création générique — le bouton « Créer une CAPA » de chaque
 // module passe par ici plutôt que par une implémentation par module.
 async capaCreateFromSource(sourceModule:string,sourceEntityId:string,b:any){
  const champ=this.CAPA_LEGACY_FIELD[sourceModule];
  const data:any={...b}; delete data.sourceModule; delete data.sourceEntityId; delete data.relationType; delete data.createdById;
  if(champ) data[champ]=sourceEntityId;
  const action=await this.db.action.create({data});
  await this.db.capaLink.create({data:{actionId:action.id,sourceModule,sourceEntityId,relationType:b.relationType||'GENEREE_PAR',createdById:b.createdById||null}});
  return action;
 }

 // Échéance suggérée par criticité — règle unique de l'entreprise plutôt
 // qu'une valeur ressaisie à chaque module (7j critique, 15j
 // majeure/élevée, 30j modérée, 60j mineure/faible, 30j par défaut).
 private capaEcheanceProposee(niveau?:string|null):Date{
  const j:Record<string,number>={CRITIQUE:7,MAJEURE:15,ELEVEE:15,ELEVE:15,MODEREE:30,MODERE:30,MINEURE:60,FAIBLE:60};
  const d=new Date(); d.setDate(d.getDate()+(niveau&&j[niveau.toUpperCase()]?j[niveau.toUpperCase()]:30)); return d;
 }
 private capaPrioriteProposee(niveau?:string|null):number{
  const n=(niveau||'').toUpperCase();
  if(n==='CRITIQUE') return 1;
  if(['MAJEURE','ELEVEE','ELEVE'].includes(n)) return 2;
  if(['MODEREE','MODERE'].includes(n)) return 3;
  return 4;
 }
 // Pièces jointes déjà rattachées à la source, via la liaison générique
 // AttachmentLink — ne duplique jamais physiquement un fichier, la CAPA
 // ne fait que référencer les mêmes pièces (point 4 du cahier des charges).
 private async capaAttachmentsDisponibles(ownerType:string,ownerId:string){
  try{
   const liens=await this.db.attachmentLink.findMany({where:{ownerType:ownerType as any,ownerId},include:{attachment:true}});
   return liens.map(l=>({id:l.attachment.id,nom:l.attachment.originalName,type:l.attachment.mimeType}));
  }catch{return [];}
 }

 // Mapping intelligent centralisé (point 3 du cahier des charges) — un seul
 // point d'entrée qui lit l'enregistrement source et calcule tout le
 // préremplissage d'une CAPA, module par module. Le principe directeur :
 // une information déjà saisie dans le module d'origine ne doit jamais
 // être ressaisie manuellement dans le formulaire CAPA. Les règles
 // (type d'action, priorité, échéance) restent volontairement lisibles et
 // modifiables ici plutôt que dispersées dans chaque écran.
 async capaPrefillFromSource(sourceModule:string,sourceEntityId:string){
  switch(sourceModule){
   case 'NON_CONFORMITY':{
    const nc=await this.db.nonConformity.findUnique({where:{id:sourceEntityId},include:{workUnit:true,processus:true}});
    if(!nc) throw new Error('Non-conformité introuvable');
    return {
     title:`Traiter — ${nc.title}`, description:nc.description||nc.title, date:nc.occurredAt,
     processusId:nc.processusId, workUnitId:nc.workUnitId, departement:nc.workUnit?.department||null, service:nc.workUnit?.service||null,
     gravite:nc.gravite, probabilite:nc.probabilite, criticite:nc.criticiteNiveau,
     priority:this.capaPrioriteProposee(nc.criticiteNiveau), actionType:'CORRECTIVE',
     responsibleId:nc.responsibleId, dueDate:nc.dueDate||this.capaEcheanceProposee(nc.criticiteNiveau),
     attachments:await this.capaAttachmentsDisponibles('NON_CONFORMITY',nc.id),
    };
   }
   case 'RISK':{
    const r=await this.db.risk.findUnique({where:{id:sourceEntityId},include:{workUnit:true,processus:true}});
    if(!r) throw new Error('Risque introuvable');
    return {
     title:`Maîtriser le risque — ${r.hazard}`, description:r.hazardousEvent||r.potentialDamage||r.hazard, date:new Date(),
     processusId:r.processusId, workUnitId:r.workUnitId, departement:r.workUnit?.department||null, service:r.workUnit?.service||null,
     gravite:r.severity, probabilite:r.probability, criticite:r.grossLevel,
     priority:this.capaPrioriteProposee(r.grossLevel), actionType:'PREVENTIVE',
     dueDate:r.nextReviewDate||this.capaEcheanceProposee(r.grossLevel),
     attachments:await this.capaAttachmentsDisponibles('RISK',r.id),
    };
   }
   case 'AUDIT': case 'AUDIT_FINDING':{
    const f=await this.db.auditFinding.findUnique({where:{id:sourceEntityId},include:{audit:{include:{workUnit:true}},responsable:true}});
    if(!f) throw new Error('Constat introuvable');
    return {
     title:`Traiter le constat — ${f.audit.title}`, description:f.description, date:f.audit.auditDate,
     processusId:f.audit.processusId, workUnitId:f.audit.workUnitId, departement:f.audit.workUnit?.department||null, service:f.audit.workUnit?.service||null,
     zone:f.zone, criticite:f.criticite, priority:this.capaPrioriteProposee(f.criticite), actionType:'CORRECTIVE',
     responsibleId:f.responsableId, dueDate:f.delai||this.capaEcheanceProposee(f.criticite),
     attachments:await this.capaAttachmentsDisponibles('AUDIT',f.auditId),
    };
   }
   case 'SAFETY_EVENT':{
    const ev=await this.db.safetyEvent.findUnique({where:{id:sourceEntityId}});
    if(!ev) throw new Error('Événement introuvable');
    const niveau=ev.severity>=4?'CRITIQUE':ev.severity===3?'MAJEURE':ev.severity===2?'MODEREE':'MINEURE';
    const preventif=/PRESQUE|SITUATION/i.test(`${ev.categorie||''} ${ev.type||''}`);
    return {
     title:`Action — ${ev.title}`, description:ev.description||ev.title, date:ev.occurredAt,
     zone:ev.zone, siteId:ev.siteId, criticite:niveau, priority:this.capaPrioriteProposee(niveau),
     actionType:preventif?'PREVENTIVE':'CORRECTIVE', dueDate:this.capaEcheanceProposee(niveau),
     attachments:await this.capaAttachmentsDisponibles('SAFETY_EVENT',ev.id),
    };
   }
   case 'FOURNISSEUR':{
    const f=await this.db.fournisseur.findUnique({where:{id:sourceEntityId}});
    if(!f) throw new Error('Fournisseur introuvable');
    const niveau=f.criticite?'ELEVEE':f.niveauRisque;
    return {
     title:`Plan de progrès — ${f.nom}`, description:`Écart constaté chez le fournisseur ${f.nom}`, date:new Date(),
     criticite:niveau, priority:this.capaPrioriteProposee(niveau), actionType:'CORRECTIVE',
     dueDate:this.capaEcheanceProposee(niveau), attachments:[],
    };
   }
   case 'RECLAMATION':{
    const r=await this.db.reclamation.findUnique({where:{id:sourceEntityId}});
    if(!r) throw new Error('Réclamation introuvable');
    return {
     title:`Traiter la réclamation — ${r.client}`, description:r.description||r.motif, date:r.date,
     processusId:r.processusId, criticite:r.gravite, priority:this.capaPrioriteProposee(r.gravite),
     actionType:'CORRECTIVE', dueDate:this.capaEcheanceProposee(r.gravite), attachments:[],
    };
   }
   case 'CONTROLE':{
    const c=await this.db.qualityControl.findUnique({where:{id:sourceEntityId}});
    if(!c) throw new Error('Contrôle introuvable');
    const niveau=c.result==='NON_COMPLIANT'?'MAJEURE':'MODEREE';
    return {
     title:`Traiter le contrôle non conforme — ${c.code}`, description:`${c.finalDecision||c.result||'Non conforme'}${c.line?` — ${c.line}`:''}${c.product?` — ${c.product}`:''}`.trim(),
     date:c.controlDate, processusId:c.processusId, criticite:niveau, priority:this.capaPrioriteProposee(niveau),
     actionType:c.domain==='HYGIENE'?'CORRECTIVE':'CORRECTIVE', dueDate:this.capaEcheanceProposee(niveau),
     attachments:await this.capaAttachmentsDisponibles('QUALITY_CONTROL',c.id),
    };
   }
   case 'ENVIRONNEMENT_ASPECT':{
    const a=await this.db.environnementAspect.findUnique({where:{id:sourceEntityId}});
    if(!a) throw new Error('Aspect environnemental introuvable');
    const niveau=a.criticite>=15?'CRITIQUE':a.criticite>=8?'MAJEURE':'MODEREE';
    return {
     title:`Maîtriser l'aspect — ${a.aspect}`, description:a.impact||a.aspect, date:new Date(),
     processusId:a.processusId, criticite:niveau, priority:this.capaPrioriteProposee(niveau),
     actionType:a.significatif?'CORRECTIVE':'PREVENTIVE', responsibleId:a.responsableId,
     dueDate:a.echeance||this.capaEcheanceProposee(niveau), attachments:[],
    };
   }
   case 'HACCP':{
    const h=await this.db.haccpRecord.findUnique({where:{id:sourceEntityId}});
    if(!h) throw new Error('Enregistrement HACCP introuvable');
    const niveau=h.ccp?'CRITIQUE':'MAJEURE';
    return {
     title:`Traiter l'écart CCP — ${h.step}`, description:`${h.hazard}${h.criticalLimit?` — limite critique : ${h.criticalLimit}`:''}`,
     date:h.recordDate, criticite:niveau, priority:this.capaPrioriteProposee(niveau),
     actionType:'CORRECTIVE', dueDate:this.capaEcheanceProposee(niveau), attachments:[],
    };
   }
   case 'INDICATEUR':{
    const i=await this.db.indicateurQualite.findUnique({where:{id:sourceEntityId}});
    if(!i) throw new Error('Indicateur introuvable');
    const ecart=i.sensInverse?i.actuel-i.cible:i.cible-i.actuel;
    return {
     title:`Redresser l'indicateur — ${i.indicateur}`, description:`Valeur actuelle ${i.actuel}${i.unite||''} vs cible ${i.cible}${i.unite||''} (écart ${ecart})`,
     date:new Date(), processusId:i.processusId, criticite:'MODEREE', priority:this.capaPrioriteProposee('MODEREE'),
     actionType:'AMELIORATION', dueDate:this.capaEcheanceProposee('MODEREE'), attachments:[],
    };
   }
   case 'PROCESSUS':{
    const p=await this.db.processus.findUnique({where:{id:sourceEntityId}});
    if(!p) throw new Error('Processus introuvable');
    return {
     title:`Améliorer le processus — ${p.nom}`, description:p.objectifPrincipal||p.finalite||p.nom, date:new Date(),
     processusId:p.id, criticite:p.criticite, priority:this.capaPrioriteProposee(p.criticite),
     actionType:'AMELIORATION', responsibleId:p.piloteId, dueDate:this.capaEcheanceProposee(p.criticite||'MODEREE'),
     attachments:[],
    };
   }
   case 'EPI':{
    const e=await this.db.epi.findUnique({where:{id:sourceEntityId}});
    if(!e) throw new Error('EPI introuvable');
    return {
     title:`Traiter l'anomalie EPI — ${e.name}`, description:`Statut : ${e.status}`, date:new Date(),
     criticite:'MODEREE', priority:this.capaPrioriteProposee('MODEREE'), actionType:'CORRECTIVE',
     dueDate:this.capaEcheanceProposee('MODEREE'), attachments:await this.capaAttachmentsDisponibles('EPI',e.id),
    };
   }
   default:
    throw new Error(`Module source non pris en charge pour le préremplissage : ${sourceModule}`);
  }
 }

 // La présence d'une ActionCause avec estRacine=true répond à elle seule à
 // « cause racine identifiée ? » — pas besoin d'un champ dupliqué sur Action.
 actionCauseCreate(b:any){return this.db.actionCause.create({data:b})}
 actionCauseUpdate(id:string,b:any){return this.db.actionCause.update({where:{id},data:b})}
 actionCauseDelete(id:string){return this.db.actionCause.delete({where:{id}})}

 // Tableau de bord réel (point 1) — chaque KPI reste `null` si non calculable.
 async actionDashboard(){
  const now=new Date();
  const dans7Jours=new Date(now.getTime()+7*86400000);
  const actions=await this.db.action.findMany({select:{status:true,priority:true,criticite:true,dueDate:true,completedAt:true,createdAt:true,responsibleId:true,source:true,parentActionId:true}});
  const principales=actions.filter(a=>!a.parentActionId); // les sous-actions ne comptent pas deux fois dans les totaux
  const total=principales.length;
  const cloturees=principales.filter(a=>a.status==='CLOSED').length;
  const terminees=principales.filter(a=>a.status==='COMPLETED'||a.status==='CLOSED').length;
  const ouvertes=principales.filter(a=>!['COMPLETED','CLOSED','CANCELLED','REJECTED'].includes(a.status)).length;
  const enRetard=principales.filter(a=>a.dueDate&&new Date(a.dueDate)<now&&!['COMPLETED','CLOSED','CANCELLED'].includes(a.status)).length;
  const echeanceProche=principales.filter(a=>a.dueDate&&new Date(a.dueDate)>=now&&new Date(a.dueDate)<=dans7Jours&&!['COMPLETED','CLOSED','CANCELLED'].includes(a.status)).length;
  const critiques=principales.filter(a=>a.criticite==='CRITIQUE').length;
  const enAttenteValidation=principales.filter(a=>a.status==='VALIDATION_PENDING').length;
  const refusees=principales.filter(a=>a.status==='REJECTED').length;
  const tauxCloture=total?Math.round((cloturees/total)*1000)/10:null;
  const tauxEnRetard=ouvertes?Math.round((enRetard/ouvertes)*1000)/10:null;
  const clotureesAvecDelai=principales.filter(a=>a.completedAt);
  const delaiMoyenRealisation=clotureesAvecDelai.length
   ?Math.round(clotureesAvecDelai.reduce((s,a)=>s+(new Date(a.completedAt!).getTime()-new Date(a.createdAt).getTime()),0)/clotureesAvecDelai.length/86400000*10)/10
   :null;
  const parOrigine=Object.entries(principales.reduce((acc:Record<string,number>,a)=>{const k=a.source||'Non renseignée';acc[k]=(acc[k]||0)+1;return acc;},{})).map(([source,nombre])=>({source,nombre}));
  const parPriorite=[1,2,3,4].map(p=>({priorite:p,nombre:principales.filter(a=>a.priority===p).length}));
  return {
   total,ouvertes,terminees,enRetard,echeanceProche,critiques,enAttenteValidation,cloturees,refusees,
   tauxCloture,tauxEnRetard,delaiMoyenRealisation,parOrigine,parPriorite,
  };
 }
 // === REGISTRE DES RISQUES ===================================================

 // Paramétrage — une seule ligne, créée à la demande avec les valeurs par
 // défaut si elle n'existe pas encore.
 async riskSettingsGet(){
  let s=await this.db.riskSettings.findFirst();
  if(!s) s=await this.db.riskSettings.create({data:{}});
  return s;
 }
 async riskSettingsUpdate(b:any){
  const current=await this.riskSettingsGet();
  return this.db.riskSettings.update({where:{id:current.id},data:b});
 }

 private riskNiveau(score:number,seuils:{seuilModere:number,seuilEleve:number,seuilCritique:number}){
  if(score>=seuils.seuilCritique) return 'CRITIQUE';
  if(score>=seuils.seuilEleve) return 'ELEVE';
  if(score>=seuils.seuilModere) return 'MODERE';
  return 'FAIBLE';
 }

 // Calcule brut/résiduel et le statut de maîtrise depuis les seuils
 // configurés — jamais saisis manuellement, toujours recalculés à l'écriture,
 // exactement comme calculerAspect() le fait pour l'Environnement.
 private async calculerRisque(b:any){
  const settings=await this.riskSettingsGet();
  const method=b.method||settings.method;
  const severity=Number(b.severity),probability=Number(b.probability),exposure=Number(b.exposure)||1;
  const grossScore=method==='GPE'?severity*probability*exposure:severity*probability;
  const grossLevel=this.riskNiveau(grossScore,settings);
  const out:any={method,severity,probability,exposure,grossScore,grossLevel,score:grossScore};
  if(b.residualSeverity!=null&&b.residualProbability!=null){
   const rs=Number(b.residualSeverity),rp=Number(b.residualProbability),re=Number(b.residualExposure)||1;
   const residualScore=method==='GPE'?rs*rp*re:rs*rp;
   const residualLevel=this.riskNiveau(residualScore,settings);
   out.residualScore=residualScore; out.residualLevel=residualLevel;
   out.controlStatus=residualScore<settings.seuilModere?'MAITRISE':(residualScore<settings.seuilActionRequise?'PARTIELLEMENT_MAITRISE':'NON_MAITRISE');
  } else out.controlStatus='NON_MAITRISE';
  out.nextReviewDate=new Date(Date.now()+(Number(b.reviewPeriodDays)||settings.reviewPeriodDays)*86400000);
  return out;
 }

 // Si le risque résiduel (ou brut à défaut) dépasse le seuil défini et
 // qu'aucune action ouverte n'existe déjà pour ce risque, une action est
 // proposée automatiquement — jamais dupliquée.
 private async declencherActionSiNecessaire(risk:any){
  const settings=await this.riskSettingsGet();
  const score=risk.residualScore??risk.grossScore;
  if(score==null||score<settings.seuilActionRequise) return null;
  const existante=await this.db.action.findFirst({where:{riskId:risk.id,status:{not:'CLOSED'}}});
  if(existante) return existante;
  return this.db.action.create({data:{
   code:`ACT-${Date.now()}-${Math.random().toString(36).slice(2,6).toUpperCase()}`,
   title:`Traiter le risque ${risk.code} — ${risk.hazard}`,
   description:'Action requise : risque au-dessus du seuil acceptable.',
   priority:risk.grossLevel==='CRITIQUE'?1:2,
   riskId:risk.id,
  }});
 }

 riskCategoryList(){return this.db.riskCategory.findMany({orderBy:{order:'asc'}})}
 riskCategoryCreate(b:any){return this.db.riskCategory.create({data:b})}
 riskCategoryUpdate(id:string,b:any){return this.db.riskCategory.update({where:{id},data:b})}
 riskCategoryDelete(id:string){return this.db.riskCategory.delete({where:{id}})}

 workUnitList(){return this.db.workUnit.findMany({include:{site:true},orderBy:{name:'asc'}})}
 workUnitCreate(b:any){return this.db.workUnit.create({data:b})}
 workUnitUpdate(id:string,b:any){return this.db.workUnit.update({where:{id},data:b})}
 workUnitDelete(id:string){return this.db.workUnit.update({where:{id},data:{active:false}})}

 riskList(){return this.db.risk.findMany({where:{archivedAt:null},include:{workUnit:true,category:true,processus:true,fournisseur:true,actions:true},orderBy:{grossScore:'desc'}})}
 riskGet(id:string){return this.db.risk.findUnique({where:{id},include:{workUnit:true,category:true,processus:true,fournisseur:true,riskMeasures:{include:{responsable:true,epi:true,training:true}},evaluations:{orderBy:{evaluatedAt:'desc'}},actions:{include:{responsible:true}}}})}

 // Recherche intelligente (point 20) — reste rapide même avec plusieurs
 // milliers de risques car limitée aux champs indexés/texte du risque
 // lui-même et des libellés de catégorie/unité, sans jointure lourde.
 riskSearch(q:string){
  if(!q||!q.trim()) return this.riskList();
  const contains=(field:string)=>({[field]:{contains:q,mode:'insensitive'}});
  return this.db.risk.findMany({
   where:{archivedAt:null,OR:[
    contains('code'),contains('hazard'),contains('hazardousSituation'),contains('hazardousEvent'),
    contains('activity'),contains('exposedPersons'),
    {category:{label:{contains:q,mode:'insensitive'}}},
    {workUnit:{name:{contains:q,mode:'insensitive'}}},
   ]},
   include:{workUnit:true,category:true,processus:true,fournisseur:true,actions:true},
   orderBy:{grossScore:'desc'},
  });
 }

 async riskCreate(b:any){
  const calc=await this.calculerRisque(b);
  const risk=await this.db.risk.create({data:{...b,...calc}});
  await this.db.riskEvaluation.create({data:{riskId:risk.id,severity:calc.severity,probability:calc.probability,exposure:calc.exposure,grossScore:calc.grossScore,grossLevel:calc.grossLevel,residualSeverity:b.residualSeverity,residualProbability:b.residualProbability,residualExposure:b.residualExposure,residualScore:calc.residualScore,residualLevel:calc.residualLevel,evaluatedById:b.evaluatedById,note:'Évaluation initiale'}});
  await writeAudit(this.db,'RISK','CREATE',risk.id,null,risk);
  await this.declencherActionSiNecessaire(risk);
  return risk;
 }

 async riskUpdate(id:string,b:any){
  const current=await this.db.risk.findUnique({where:{id}});
  if(!current) throw new Error('Risque introuvable');
  const calc=await this.calculerRisque({...current,...b});
  const risk=await this.db.risk.update({where:{id},data:{...b,...calc}});
  await writeAudit(this.db,'RISK','UPDATE',id,current,risk);
  await this.declencherActionSiNecessaire(risk);
  return risk;
 }

 // Bouton RÉÉVALUER — conserve l'ancienne évaluation dans l'historique au
 // lieu de simplement écraser les valeurs précédentes.
 async riskReevaluate(id:string,b:any){
  const current=await this.db.risk.findUnique({where:{id}});
  if(!current) throw new Error('Risque introuvable');
  const merged={...current,...b};
  const calc=await this.calculerRisque(merged);
  const risk=await this.db.risk.update({where:{id},data:{...b,...calc,reviewedAt:new Date()}});
  await this.db.riskEvaluation.create({data:{riskId:id,severity:calc.severity,probability:calc.probability,exposure:calc.exposure,grossScore:calc.grossScore,grossLevel:calc.grossLevel,residualSeverity:merged.residualSeverity,residualProbability:merged.residualProbability,residualExposure:merged.residualExposure,residualScore:calc.residualScore,residualLevel:calc.residualLevel,evaluatedById:b.evaluatedById,note:b.note||'Réévaluation'}});
  await writeAudit(this.db,'RISK','UPDATE',id,current,risk);
  await this.declencherActionSiNecessaire(risk);
  return risk;
 }

 // Archivage plutôt que suppression définitive (point 17 du cahier des
 // charges) — un risque déjà évalué reste dans l'historique QHSE.
 async riskDelete(id:string){
  const current=await this.db.risk.findUnique({where:{id}});
  const risk=await this.db.risk.update({where:{id},data:{archivedAt:new Date(),status:'ARCHIVE'}});
  await writeAudit(this.db,'RISK','DELETE',id,current,risk);
  return risk;
 }

 riskMeasureList(riskId:string){return this.db.riskMeasure.findMany({where:{riskId},include:{responsable:true},orderBy:{createdAt:'desc'}})}
 riskMeasureCreate(b:any){return this.db.riskMeasure.create({data:b})}
 riskMeasureUpdate(id:string,b:any){return this.db.riskMeasure.update({where:{id},data:b})}
 riskMeasureDelete(id:string){return this.db.riskMeasure.delete({where:{id}})}

 // Tableau de bord réel : chaque KPI reste `null` si la donnée n'existe pas.
 async riskDashboard(){
  const [risks,nombreUnitesTravail]=await Promise.all([
   this.db.risk.findMany({where:{archivedAt:null},include:{actions:true}}),
   this.db.workUnit.count({where:{active:true}}),
  ]);
  const now=new Date();
  const total=risks.length;
  const parNiveau=(n:string)=>risks.filter(r=>r.grossLevel===n).length;
  const nonMaitrises=risks.filter(r=>r.controlStatus==='NON_MAITRISE').length;
  const avecActionsOuvertes=risks.filter(r=>r.actions.some(a=>a.status!=='CLOSED')).length;
  const actionsEnRetard=risks.flatMap(r=>r.actions).filter(a=>a.dueDate&&new Date(a.dueDate)<now&&a.status!=='CLOSED').length;
  const reevalues=risks.filter(r=>r.reviewedAt).length;
  const aReevaluer=risks.filter(r=>r.nextReviewDate&&new Date(r.nextReviewDate)<now).length;
  const tauxMaitrise=total?Math.round((risks.filter(r=>r.controlStatus==='MAITRISE').length/total)*1000)/10:null;
  const tauxMiseAJour=total?Math.round((reevalues/total)*1000)/10:null;
  const actionsTotal=risks.flatMap(r=>r.actions).length;
  const actionsCloturees=risks.flatMap(r=>r.actions).filter(a=>a.status==='CLOSED').length;
  const tauxClotureActions=actionsTotal?Math.round((actionsCloturees/actionsTotal)*1000)/10:null;
  const depuis30j=new Date(now.getTime()-30*86400000);
  const nouveaux=risks.filter(r=>new Date(r.createdAt)>depuis30j).length;
  return {
   total,critiques:parNiveau('CRITIQUE'),eleves:parNiveau('ELEVE'),moderes:parNiveau('MODERE'),faibles:parNiveau('FAIBLE'),
   nonMaitrises,avecActionsOuvertes,actionsEnRetard,reevalues,aReevaluer,
   tauxMaitrise,tauxMiseAJour,tauxClotureActions,
   nombreUnitesTravail,nouveauxDepuis30Jours:nouveaux,
  };
 }

 // Heatmap 5x5 gravité x probabilité — chaque case liste les risques concernés.
 async riskMatrice(){
  const risks=await this.db.risk.findMany({where:{archivedAt:null},select:{id:true,code:true,hazard:true,severity:true,probability:true,grossLevel:true}});
  const cases:Record<string,any[]>={};
  for(const r of risks){
   const key=`${r.severity}-${r.probability}`;
   if(!cases[key]) cases[key]=[];
   cases[key].push(r);
  }
  return Object.entries(cases).map(([key,items])=>{
   const [severity,probability]=key.split('-').map(Number);
   return {severity,probability,count:items.length,niveau:items[0]?.grossLevel,risques:items};
  });
 }

 riskTop10(){return this.db.risk.findMany({where:{archivedAt:null},orderBy:{grossScore:'desc'},take:10,include:{workUnit:true,category:true,actions:{include:{responsible:true}}}})}

 async riskAlertes(){
  const now=new Date();
  const dans30Jours=new Date(now.getTime()+30*86400000);
  const risks=await this.db.risk.findMany({where:{archivedAt:null},include:{actions:true}});
  const alertes:any[]=[];
  for(const r of risks){
   if(r.grossLevel==='CRITIQUE') alertes.push({id:r.id,label:`Risque critique : ${r.hazard}`,niveau:'CRITIQUE'});
   if(r.grossLevel==='ELEVE'&&!r.actions.some(a=>a.status!=='CLOSED')) alertes.push({id:r.id,label:`Risque élevé sans action : ${r.hazard}`,niveau:'URGENT'});
   if(r.nextReviewDate){
    const d=new Date(r.nextReviewDate);
    if(d<now) alertes.push({id:r.id,label:`Réévaluation en retard : ${r.hazard}`,niveau:'ATTENTION'});
    else if(d<dans30Jours) alertes.push({id:r.id,label:`Réévaluation à prévoir : ${r.hazard}`,niveau:'ATTENTION'});
   }
   for(const a of r.actions) if(a.dueDate&&new Date(a.dueDate)<now&&a.status!=='CLOSED') alertes.push({id:a.id,label:`Action en retard sur le risque ${r.hazard} : ${a.title}`,niveau:'URGENT'});
  }
  return alertes.sort((a,b)=>({CRITIQUE:0,URGENT:1,ATTENTION:2} as any)[a.niveau]-({CRITIQUE:0,URGENT:1,ATTENTION:2} as any)[b.niveau]);
 }
 haccpList(){return this.db.haccpRecord.findMany({orderBy:{recordDate:'desc'}})} haccpCreate(b:any){return this.db.haccpRecord.create({data:b})} haccpUpdate(id:string,b:any){return this.db.haccpRecord.update({where:{id},data:b})} haccpDelete(id:string){return this.db.haccpRecord.delete({where:{id}})}
 auditList(){return this.db.qhseAudit.findMany({include:{auditor:true,responsableAudite:true,processus:true,type:true,referential:true,workUnit:true,auditFindings:{include:{nonConformity:true}}},orderBy:{auditDate:'desc'}})}
 async auditGet(id:string){
  const audit=await this.db.qhseAudit.findUnique({where:{id},include:{
   auditor:true,responsableAudite:true,fournisseur:true,type:true,referential:true,workUnit:true,
   processus:{include:{pilote:true,suppleant:true}},
   checklist:{include:{items:{orderBy:{order:'asc'}}}},responses:true,
   auditFindings:{include:{nonConformity:true,risk:true,actions:true,responsable:true,checklistItem:true}},
   programs:true,signatures:{include:{signataire:true}},
  }});
  if(!audit) return null;
  // Point 15 : signale (sans jamais bloquer) qu'un auditeur pourrait auditer
  // son propre processus — la politique interne peut ensuite l'autoriser.
  const independenceWarning=!!(audit.processus&&audit.auditorId&&(audit.processus.piloteId===audit.auditorId||audit.processus.suppleantId===audit.auditorId));
  return {...audit,independenceWarning};
 }
 auditCreate(b:any){return this.db.qhseAudit.create({data:b})} auditUpdate(id:string,b:any){return this.db.qhseAudit.update({where:{id},data:b})} auditDelete(id:string){return this.db.qhseAudit.delete({where:{id}})}

 auditFindingCreate(auditId:string,b:any){return this.db.auditFinding.create({data:{
  auditId,description:b.description,classification:b.classification,criticite:b.criticite,critical:!!b.critical,
  checklistItemId:b.checklistItemId||null,preuveObjective:b.preuveObjective||null,zone:b.zone||null,
  responsableId:b.responsableId||null,delai:b.delai||null,
 }})}
 // La date de clôture se fixe automatiquement au moment où le statut passe
 // à CLOSED (et se libère si le constat est rouvert) — jamais saisie à la
 // main, pour que le délai moyen de clôture reste fiable.
 auditFindingUpdate(id:string,b:any){
  const data:any={
   description:b.description,classification:b.classification,criticite:b.criticite,critical:b.critical,status:b.status,
   preuveObjective:b.preuveObjective,zone:b.zone,responsableId:b.responsableId,delai:b.delai,
  };
  if(b.status==='CLOSED') data.closedAt=new Date();
  else if(b.status) data.closedAt=null;
  return this.db.auditFinding.update({where:{id},data});
 }
 auditFindingDelete(id:string){return this.db.auditFinding.delete({where:{id}})}
 // Un constat nécessitant une action peut en générer une directement,
 // sans passer obligatoirement par une NC (point 12 du cahier des charges).
 async auditFindingGenerateAction(id:string,b:any){
  const finding=await this.db.auditFinding.findUnique({where:{id},include:{audit:true}});
  if(!finding) throw new Error('Constat introuvable');
  return this.db.action.create({data:{
   code:`ACT-${Date.now()}-${Math.random().toString(36).slice(2,6).toUpperCase()}`,
   title:b?.title||`Traiter le constat — ${finding.audit.title}`,
   description:b?.description||finding.description,
   priority:finding.critical?1:2, processusId:finding.audit.processusId,
   auditFindingId:finding.id, responsibleId:b?.responsibleId||finding.responsableId||null, dueDate:b?.dueDate||finding.delai||null,
  }});
 }

 // === AUDITS — Phase 2 : check-lists dynamiques et moteur de notation ====

 auditChecklistList(){return this.db.auditChecklist.findMany({include:{items:{orderBy:{order:'asc'}},referential:true,type:true},orderBy:{title:'asc'}})}
 auditChecklistCreate(b:any){return this.db.auditChecklist.create({data:b})}
 auditChecklistUpdate(id:string,b:any){return this.db.auditChecklist.update({where:{id},data:b})}
 auditChecklistDelete(id:string){return this.db.auditChecklist.delete({where:{id}})}
 auditChecklistItemCreate(b:any){return this.db.auditChecklistItem.create({data:b})}
 auditChecklistItemUpdate(id:string,b:any){return this.db.auditChecklistItem.update({where:{id},data:b})}
 auditChecklistItemDelete(id:string){return this.db.auditChecklistItem.delete({where:{id}})}

 // Valeur numérique (0 à 1) attribuée à chaque résultat possible — les
 // résultats non évaluables (non applicable, non évalué, à vérifier) sont
 // exclus du calcul plutôt que comptés comme un échec.
 private readonly RESULTAT_VALEUR:Record<string,number>={CONFORME:1,BONNE_PRATIQUE:1,PISTE_AMELIORATION:1,OBSERVATION:1,PARTIELLEMENT_CONFORME:0.5,NON_CONFORME:0};
 private readonly CRITICITE_POIDS:Record<string,number>={FAIBLE:1,MODEREE:2,ELEVEE:3,CRITIQUE:4};

 // Enregistre (ou met à jour) la réponse à une question de check-list pour
 // un audit, puis recalcule immédiatement le score global de l'audit —
 // jamais de score obsolète affiché après une réponse.
 async auditResponseSave(auditId:string,checklistItemId:string,b:any){
  const response=await this.db.auditQuestionResponse.upsert({
   where:{auditId_checklistItemId:{auditId,checklistItemId}},
   update:{resultat:b.resultat,score:b.score,commentaire:b.commentaire},
   create:{auditId,checklistItemId,resultat:b.resultat||'NON_EVALUE',score:b.score,commentaire:b.commentaire},
  });
  await this.calculerScoreAudit(auditId);
  return response;
 }

 private async calculerScoreAudit(auditId:string){
  const audit=await this.db.qhseAudit.findUnique({where:{id:auditId}});
  if(!audit) return;
  const responses=await this.db.auditQuestionResponse.findMany({where:{auditId},include:{checklistItem:true}});
  const evaluables=responses.filter(r=>['CONFORME','NON_CONFORME','PARTIELLEMENT_CONFORME','OBSERVATION','PISTE_AMELIORATION','BONNE_PRATIQUE'].includes(r.resultat));
  if(!evaluables.length){
   await this.db.qhseAudit.update({where:{id:auditId},data:{scoreObtenu:null,scoreMax:null,tauxConformite:null,scorePondere:null}});
   return;
  }
  let scoreObtenu=0,scoreMaximum=0;
  const methode=audit.scoringMethod;
  for(const r of evaluables){
   let valeur:number,poids=1;
   if(methode==='ECHELLE_0_5'||methode==='ECHELLE_0_10'||methode==='POURCENTAGE'){
    const echelle=methode==='ECHELLE_0_5'?5:methode==='ECHELLE_0_10'?10:100;
    valeur=(r.score??this.RESULTAT_VALEUR[r.resultat]*echelle)/echelle;
   } else {
    valeur=this.RESULTAT_VALEUR[r.resultat]??0;
   }
   if(methode==='PONDERATION') poids=r.checklistItem.poids||1;
   else if(methode==='CRITICITE') poids=this.CRITICITE_POIDS[r.checklistItem.criticite]||1;
   scoreObtenu+=valeur*poids;
   scoreMaximum+=poids;
  }
  const tauxConformite=scoreMaximum?Math.round((scoreObtenu/scoreMaximum)*1000)/10:null;
  await this.db.qhseAudit.update({where:{id:auditId},data:{
   scoreObtenu:Math.round(scoreObtenu*100)/100, scoreMax:Math.round(scoreMaximum*100)/100,
   tauxConformite, scorePondere:methode==='PONDERATION'||methode==='CRITICITE'?Math.round(scoreObtenu*100)/100:null,
   score:tauxConformite,
  }});
 }

 // === AUDITS — Phase 3 : auditeurs, indépendance, signatures ===========

 // Liste les utilisateurs déjà impliqués dans au moins un audit ou ayant un
 // profil auditeur, avec leurs statistiques calculées (point 14) — jamais
 // stockées, toujours recalculées depuis les audits réels.
 async auditeursList(){
  const users=await this.db.user.findMany({
   where:{OR:[{audits:{some:{}}},{auditorProfile:{isNot:null}}]},
   include:{auditorProfile:true,audits:{select:{status:true,score:true}}},
  });
  return users.map(u=>{
   const clotureStatuts=['COMPLETED','VALIDATED','CLOSED'];
   const realises=u.audits.filter(a=>clotureStatuts.includes(a.status)).length;
   const enCours=u.audits.filter(a=>!clotureStatuts.includes(a.status)&&a.status!=='CANCELLED').length;
   const scores=u.audits.map(a=>a.score).filter((s):s is number=>s!=null);
   const performanceMoyenne=scores.length?Math.round((scores.reduce((s,v)=>s+v,0)/scores.length)*10)/10:null;
   return {
    id:u.id,firstName:u.firstName,lastName:u.lastName,email:u.email,profile:u.auditorProfile,
    nombreAuditsRealises:realises,nombreAuditsEnCours:enCours,performanceMoyenne,
   };
  });
 }
 auditorProfileUpsert(userId:string,b:any){return this.db.auditorProfile.upsert({where:{userId},update:b,create:{userId,...b}})}

 auditSignatureCreate(auditId:string,b:any){return this.db.auditSignature.create({data:{auditId,role:b.role,signataireId:b.signataireId||null}})}
 // Signer, c'est enregistrer qui a signé et quand — jamais un simple
 // changement de statut sans identité ni horodatage.
 auditSignatureSign(id:string,signataireId:string){return this.db.auditSignature.update({where:{id},data:{signataireId,signedAt:new Date(),statut:'SIGNE'}})}
 auditSignatureDelete(id:string){return this.db.auditSignature.delete({where:{id}})}
 // Génère une non-conformité (et son action corrective) à partir d'un
 // constat d'audit — même principe que l'échec d'un point de contrôle
 // critique dans le moteur de contrôle universel. Le constat hérite du
 // lien processus de l'audit qui l'a produit.
 async auditFindingGenerateNc(id:string){
  const finding=await this.db.auditFinding.findUnique({where:{id},include:{audit:true}});
  if(!finding) throw new Error('Constat introuvable');
  if(finding.nonConformityId) throw new Error('Une non-conformité a déjà été générée pour ce constat');
  return this.db.$transaction(async(tx)=>{
   const nc=await tx.nonConformity.create({data:{
    code:`NC-${Date.now()}-${Math.random().toString(36).slice(2,6).toUpperCase()}`,
    title:`Constat d'audit — ${finding.audit.title}`,description:finding.description,
    severity:finding.critical?3:1,
    classification:finding.classification||(finding.critical?'NC_CRITIQUE':'NC_MINEURE'),
    source:'AUDIT', processusId:finding.audit.processusId,
   }});
   await tx.action.create({data:{code:`ACT-${Date.now()}-${Math.random().toString(36).slice(2,6).toUpperCase()}`,title:`Traiter ${nc.code}`,description:`Analyser et corriger le constat de l'audit ${finding.audit.title}`,priority:finding.critical?1:2,nonConformityId:nc.id,processusId:finding.audit.processusId}});
   return tx.auditFinding.update({where:{id},data:{nonConformityId:nc.id,status:'CLOSED'},include:{nonConformity:true}});
  });
 }
 // Un constat d'audit peut aussi générer directement un risque dans le
 // Registre — même principe que pour une non-conformité ou un accident.
 async auditFindingGenerateRisk(id:string){
  const finding=await this.db.auditFinding.findUnique({where:{id},include:{audit:true}});
  if(!finding) throw new Error('Constat introuvable');
  if(finding.riskId) throw new Error('Un risque a déjà été généré pour ce constat');
  const calc=await this.calculerRisque({severity:finding.critical?4:2,probability:3});
  const risk=await this.db.risk.create({data:{
   code:`RISK-${Date.now()}-${Math.random().toString(36).slice(2,6).toUpperCase()}`,
   hazard:`Constat d'audit — ${finding.audit.title}`, hazardousEvent:finding.description,
   processusId:finding.audit.processusId, ...calc,
  }});
  await writeAudit(this.db,'RISK','CREATE',risk.id,null,risk);
  await this.db.auditFinding.update({where:{id},data:{riskId:risk.id}});
  return risk;
 }

 // === AUDITS — Phase 1 : programme, types, référentiels, dashboard ========

 auditTypeList(){return this.db.auditType.findMany({orderBy:{order:'asc'}})}
 auditTypeCreate(b:any){return this.db.auditType.create({data:b})}
 auditTypeUpdate(id:string,b:any){return this.db.auditType.update({where:{id},data:b})}
 auditTypeDelete(id:string){return this.db.auditType.delete({where:{id}})}

 auditReferentialList(){return this.db.auditReferential.findMany({include:{items:{orderBy:{order:'asc'}}},orderBy:{label:'asc'}})}
 auditReferentialCreate(b:any){return this.db.auditReferential.create({data:b})}
 auditReferentialUpdate(id:string,b:any){return this.db.auditReferential.update({where:{id},data:b})}
 auditReferentialDelete(id:string){return this.db.auditReferential.delete({where:{id}})}
 auditReferentialItemCreate(b:any){return this.db.auditReferentialItem.create({data:b})}
 auditReferentialItemUpdate(id:string,b:any){return this.db.auditReferentialItem.update({where:{id},data:b})}
 auditReferentialItemDelete(id:string){return this.db.auditReferentialItem.delete({where:{id}})}

 auditProgramList(){return this.db.auditProgram.findMany({include:{type:true,referential:true,workUnit:true,processus:true,auditeurPrincipal:true,audit:true},orderBy:{datePrevue:'asc'}})}
 auditProgramCreate(b:any){return this.db.auditProgram.create({data:b})}
 auditProgramUpdate(id:string,b:any){return this.db.auditProgram.update({where:{id},data:b})}
 auditProgramDelete(id:string){return this.db.auditProgram.delete({where:{id}})}
 // Génère l'audit réel à partir d'une ligne de programme, préremplie,
 // jamais ressaisie — même principe que pour le Registre des risques.
 async auditProgramGenerateAudit(id:string){
  const program=await this.db.auditProgram.findUnique({where:{id}});
  if(!program) throw new Error('Programme introuvable');
  if(program.auditId) throw new Error('Un audit a déjà été généré pour ce programme');
  const audit=await this.db.qhseAudit.create({data:{
   code:`AUD-${Date.now()}-${Math.random().toString(36).slice(2,6).toUpperCase()}`,
   title:program.title, auditDate:program.datePrevue||new Date(), status:'PLANNED',
   typeId:program.typeId, referentialId:program.referentialId, workUnitId:program.workUnitId,
   processusId:program.processusId, auditorId:program.auditeurPrincipalId,
   dureePrevueHeures:program.dureePrevueHeures, priorite:program.priorite,
  }});
  await this.db.auditProgram.update({where:{id},data:{auditId:audit.id,statut:'PLANIFIE'}});
  return audit;
 }

 // Tableau de bord réel (point 2 du cahier des charges) — chaque KPI reste
 // `null` s'il n'est pas calculable plutôt que d'afficher un faux zéro.
 async auditDashboard(){
  const now=new Date();
  const enCoursStatuts=['PLANNED','TO_PREPARE','PREPARING','READY','IN_PROGRESS','REPORT_PENDING','VALIDATION_PENDING'];
  const clotureStatuts=['COMPLETED','VALIDATED','CLOSED'];
  const [audits,programs,findings]=await Promise.all([
   this.db.qhseAudit.findMany({select:{id:true,status:true,auditDate:true,score:true}}),
   this.db.auditProgram.findMany({select:{id:true,statut:true,auditId:true}}),
   this.db.auditFinding.findMany({select:{id:true,classification:true,criticite:true,status:true,createdAt:true,closedAt:true,auditId:true}}),
  ]);
  const total=audits.length;
  const parStatut=(s:string)=>audits.filter(a=>a.status===s).length;
  const enRetard=audits.filter(a=>new Date(a.auditDate)<now&&!clotureStatuts.includes(a.status)&&a.status!=='CANCELLED'&&a.status!=='POSTPONED').length;
  const aVenir=audits.filter(a=>new Date(a.auditDate)>now&&enCoursStatuts.includes(a.status)).length;
  const clotures=audits.filter(a=>clotureStatuts.includes(a.status)).length;
  const programsRealises=programs.filter(p=>p.auditId).length;
  const tauxRealisationProgramme=programs.length?Math.round((programsRealises/programs.length)*1000)/10:null;
  const conformes=findings.filter(f=>f.classification==='CONFORME').length;
  const ncMineures=findings.filter(f=>f.classification==='NC_MINEURE').length;
  const ncMajeures=findings.filter(f=>f.classification==='NC_MAJEURE').length;
  const pistesAmelioration=findings.filter(f=>f.classification==='PISTE_AMELIORATION').length;
  const evaluables=conformes+ncMineures+ncMajeures;
  const tauxConformite=evaluables?Math.round((conformes/evaluables)*1000)/10:null;
  const tauxNonConformite=evaluables?Math.round(((ncMineures+ncMajeures)/evaluables)*1000)/10:null;
  const constatsOuverts=findings.filter(f=>f.status!=='CLOSED').length;
  const constatsClotures=findings.filter(f=>f.status==='CLOSED').length;
  const closedWithDelay=findings.filter(f=>f.closedAt);
  const delaiMoyenClotureConstats=closedWithDelay.length
   ?Math.round(closedWithDelay.reduce((s,f)=>s+(new Date(f.closedAt!).getTime()-new Date(f.createdAt).getTime()),0)/closedWithDelay.length/86400000*10)/10
   :null;
  const scores=audits.map(a=>a.score).filter((s):s is number=>s!=null);
  const scoreMoyen=scores.length?Math.round((scores.reduce((s,v)=>s+v,0)/scores.length)*10)/10:null;
  return {
   total,
   planifies:parStatut('PLANNED'),enPreparation:parStatut('PREPARING')+parStatut('TO_PREPARE'),enCours:parStatut('IN_PROGRESS'),
   realises:parStatut('COMPLETED'),reportes:parStatut('POSTPONED'),annules:parStatut('CANCELLED'),
   enRetard,aVenir,clotures,
   tauxRealisationProgramme,tauxConformite,tauxNonConformite,
   nombreConstats:findings.length,ncMajeures,ncMineures,pistesAmelioration,pointsConformes:conformes,
   constatsOuverts,constatsClotures,delaiMoyenClotureConstats,
   scoreMoyen,
  };
 }

 // === AUDITS — Phase 4 : analyses, tendances, comparaisons, synthèse =====

 // Évolution mensuelle sur 12 mois (point 23, graphique 1 et 4).
 async auditTrends(){
  const depuis=new Date(); depuis.setMonth(depuis.getMonth()-11); depuis.setDate(1); depuis.setHours(0,0,0,0);
  const audits=await this.db.qhseAudit.findMany({where:{auditDate:{gte:depuis}},select:{auditDate:true,tauxConformite:true,status:true}});
  const mois:{cle:string,label:string,realises:number,tauxConformiteMoyen:number|null}[]=[];
  for(let i=11;i>=0;i--){
   const d=new Date(); d.setMonth(d.getMonth()-i); d.setDate(1);
   const cle=`${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}`;
   const label=d.toLocaleDateString('fr-FR',{month:'short',year:'2-digit'});
   const duMois=audits.filter(a=>{const ad=new Date(a.auditDate);return ad.getFullYear()===d.getFullYear()&&ad.getMonth()===d.getMonth();});
   const taux=duMois.map(a=>a.tauxConformite).filter((t):t is number=>t!=null);
   mois.push({cle,label,realises:duMois.length,tauxConformiteMoyen:taux.length?Math.round((taux.reduce((s,v)=>s+v,0)/taux.length)*10)/10:null});
  }
  return mois;
 }

 // Détection des non-conformités récurrentes (point 25) — regroupe les
 // constats NC par processus et cause racine approximative (classification
 // + description), et ne retient que ce qui s'est répété au moins deux fois.
 async auditNcRecurrentes(){
  const findings=await this.db.auditFinding.findMany({
   where:{classification:{in:['NC_MINEURE','NC_MAJEURE']}},
   include:{audit:{select:{title:true,auditDate:true,processusId:true,processus:{select:{nom:true}}}}},
   orderBy:{createdAt:'desc'},
  });
  const groupes:Record<string,any[]>={};
  for(const f of findings){
   const cle=`${f.audit.processusId||'sans-processus'}::${(f.description||'').trim().toLowerCase().slice(0,60)}`;
   (groupes[cle]=groupes[cle]||[]).push(f);
  }
  return Object.values(groupes).filter(g=>g.length>=2).map(g=>({
   description:g[0].description, processus:g[0].audit.processus?.nom||'Sans processus',
   occurrences:g.length, derniereOccurrence:g[0].audit.auditDate,
   historique:g.map(f=>({audit:f.audit.title,date:f.audit.auditDate,statut:f.status})),
  })).sort((a,b)=>b.occurrences-a.occurrences);
 }

 // Compare deux périodes (point 34) sur les mêmes indicateurs que le
 // tableau de bord, sans dupliquer sa logique de calcul.
 async auditComparaison(debut1:string,fin1:string,debut2:string,fin2:string){
  const kpiPeriode=async(debut:string,fin:string)=>{
   const audits=await this.db.qhseAudit.findMany({where:{auditDate:{gte:new Date(debut),lte:new Date(fin)}},select:{tauxConformite:true,score:true,status:true}});
   const findings=await this.db.auditFinding.findMany({where:{audit:{auditDate:{gte:new Date(debut),lte:new Date(fin)}}},select:{classification:true}});
   const taux=audits.map(a=>a.tauxConformite).filter((t):t is number=>t!=null);
   const scores=audits.map(a=>a.score).filter((s):s is number=>s!=null);
   return {
    nombreAudits:audits.length,
    tauxConformiteMoyen:taux.length?Math.round((taux.reduce((s,v)=>s+v,0)/taux.length)*10)/10:null,
    scoreMoyen:scores.length?Math.round((scores.reduce((s,v)=>s+v,0)/scores.length)*10)/10:null,
    ncMajeures:findings.filter(f=>f.classification==='NC_MAJEURE').length,
    ncMineures:findings.filter(f=>f.classification==='NC_MINEURE').length,
   };
  };
  const [periode1,periode2]=await Promise.all([kpiPeriode(debut1,fin1),kpiPeriode(debut2,fin2)]);
  return {periode1,periode2};
 }

 // Synthèse Direction (point 35) — un instantané prêt à être lu ou exporté,
 // recomposé à partir des mêmes données que le tableau de bord et les
 // tendances, jamais stocké séparément (donc jamais périmé).
 async auditSyntheseDirection(){
  const [dashboard,trends,ncRecurrentes]=await Promise.all([this.auditDashboard(),this.auditTrends(),this.auditNcRecurrentes()]);
  const parProcessus=await this.db.qhseAudit.groupBy({by:['processusId'],_avg:{tauxConformite:true},where:{processusId:{not:null}}});
  const processusDetails=await this.db.processus.findMany({where:{id:{in:parProcessus.map(p=>p.processusId).filter((id):id is string=>!!id)}},select:{id:true,nom:true}});
  const performance=parProcessus.map(p=>({
   processus:processusDetails.find(d=>d.id===p.processusId)?.nom||'Inconnu',
   tauxConformiteMoyen:p._avg.tauxConformite!=null?Math.round(p._avg.tauxConformite*10)/10:null,
  })).sort((a,b)=>(b.tauxConformiteMoyen||0)-(a.tauxConformiteMoyen||0));
  return {
   dashboard, tendanceRecente:trends.slice(-3),
   processusLesPlusPerformants:performance.slice(0,5),
   processusLesPlusProblematiques:[...performance].reverse().slice(0,5),
   principalesCausesRecurrentes:ncRecurrentes.slice(0,5),
   genereLe:new Date(),
  };
 }
 envList(){return this.db.environmentRecord.findMany({include:{processus:true},orderBy:{recordedAt:'desc'}})} envCreate(b:any){return this.db.environmentRecord.create({data:b})} envUpdate(id:string,b:any){return this.db.environmentRecord.update({where:{id},data:b})} envDelete(id:string){return this.db.environmentRecord.delete({where:{id}})}

 // Aspects & impacts environnementaux — la criticité et le caractère
 // significatif se recalculent à chaque écriture depuis la méthode de
 // cotation documentée, jamais ressaisis séparément.
 private calculerAspect(b:any){
  const frequence=Number(b.frequence)||1,gravite=Number(b.gravite)||1,probabilite=Number(b.probabilite)||1,maitrise=Number(b.maitrise)||1;
  const criticite=Math.round((frequence*gravite*probabilite)/maitrise);
  return {frequence,gravite,probabilite,maitrise,criticite,significatif:criticite>=12};
 }
 environnementAspectList(){return this.db.environnementAspect.findMany({include:{site:true,processus:true,responsable:true,actions:true,risk:true},orderBy:{criticite:'desc'}})}
 environnementAspectGet(id:string){return this.db.environnementAspect.findUnique({where:{id},include:{site:true,processus:true,responsable:true,actions:{include:{responsible:true}},risk:true}})}
 environnementAspectCreate(b:any){return this.db.environnementAspect.create({data:{...b,...this.calculerAspect(b)}})}
 async environnementAspectUpdate(id:string,b:any){
  const current=await this.db.environnementAspect.findUnique({where:{id}});
  const merged={...current,...b};
  return this.db.environnementAspect.update({where:{id},data:{...b,...this.calculerAspect(merged)}});
 }
 environnementAspectDelete(id:string){return this.db.environnementAspect.delete({where:{id}})}

 // Environnement — tableau de bord réel : chaque valeur reste `null`
 // si la donnée n'existe pas, jamais une valeur inventée à la place.
 async environnementDashboard(){
  const [records,aspects,ponderations]=await Promise.all([
   this.db.environmentRecord.findMany(),
   this.db.environnementAspect.findMany(),
   this.indicateurPonderationList(),
  ]);
  const objectifsEnv=await this.db.objectifQhse.findMany({where:{pilier:'Environnement'}});
  const actionsEnv=await this.db.action.findMany({where:{environnementAspectId:{not:null}}});
  const now=new Date();

  const sumByCategorie=(cat:string)=>{
   const items=records.filter(r=>r.categorie===cat&&r.value!=null);
   return items.length?Math.round(items.reduce((s,r)=>s+(r.value||0),0)*100)/100:null;
  };
  const avecConformite=records.filter(r=>r.conforme!=null);
  const tauxConformite=avecConformite.length?Math.round((avecConformite.filter(r=>r.conforme).length/avecConformite.length)*1000)/10:null;

  const aspectsActifs=aspects.filter(a=>a.statut==='ACTIVE');
  const aspectsSignificatifs=aspectsActifs.filter(a=>a.significatif).length;
  const tauxAspectsMaitrises=aspectsActifs.length?Math.round((1-aspectsSignificatifs/aspectsActifs.length)*1000)/10:null;

  const actionsEnRetard=actionsEnv.filter(a=>a.dueDate&&new Date(a.dueDate)<now&&a.status!=='CLOSED').length;
  const tauxClotureActions=actionsEnv.length?Math.round((actionsEnv.filter(a=>a.status==='CLOSED').length/actionsEnv.length)*1000)/10:null;

  const progressionObjectif=(o:any)=>{
   if(o.valeurInitiale==null)return null;
   const denom=o.cible-o.valeurInitiale;
   if(denom===0)return null;
   const p=((o.actuel-o.valeurInitiale)/denom)*100;
   return Math.max(0,Math.min(100,Math.round(p*10)/10));
  };
  const objectifsAvecProgression=objectifsEnv.map(o=>({...o,progression:progressionObjectif(o)})).filter(o=>o.progression!=null);
  const tauxObjectifsAtteints=objectifsAvecProgression.length?Math.round((objectifsAvecProgression.filter(o=>(o.progression as number)>=90).length/objectifsAvecProgression.length)*1000)/10:null;

  const poidsMap=Object.fromEntries(ponderations.map(p=>[p.autoKey,p.poids]));
  const composantesScore=[
   {key:'env_conformite',nom:'Conformité des relevés',valeur:tauxConformite},
   {key:'env_aspects',nom:'Maîtrise des aspects',valeur:tauxAspectsMaitrises},
   {key:'env_actions',nom:'Clôture des actions',valeur:tauxClotureActions},
   {key:'env_objectifs',nom:'Atteinte des objectifs',valeur:tauxObjectifsAtteints},
  ];
  let somme=0,poidsTotal=0;
  const detailScore=composantesScore.map(c=>{
   const poids=poidsMap[c.key]??1;
   if(c.valeur!=null){somme+=c.valeur*poids;poidsTotal+=poids;}
   return {...c,poids};
  });
  const scoreGlobal=poidsTotal>0?Math.round((somme/poidsTotal)*10)/10:null;

  const dechetsRecords=records.filter(r=>r.categorie==='Déchets'&&r.value!=null);
  const dechetsValorises=dechetsRecords.filter(r=>r.modeTraitement&&/recycl|valoris|r[ée]utilis/i.test(r.modeTraitement));
  const totalDechets=dechetsRecords.reduce((s,r)=>s+(r.value||0),0);
  const tauxValorisationDechets=dechetsRecords.length&&totalDechets>0?Math.round((dechetsValorises.reduce((s,r)=>s+(r.value||0),0)/totalDechets)*1000)/10:null;

  const veilleEnv=await this.db.veilleReglementaire.findMany({where:{domaine:'Environnement'}});
  const veilleConformes=veilleEnv.filter(v=>['CONFORME','INTEGREE'].includes(v.statut));
  const veilleApplicable=veilleEnv.filter(v=>v.statut!=='NON_APPLICABLE');
  const tauxConformiteReglementaire=veilleApplicable.length?Math.round((veilleConformes.length/veilleApplicable.length)*1000)/10:null;

  return {
   score:scoreGlobal,scoreDetail:detailScore,
   tauxConformite,
   dechets:sumByCategorie('Déchets'),
   tauxValorisationDechets,
   eau:sumByCategorie('Eau'),
   energie:sumByCategorie('Énergie'),
   ges:sumByCategorie('GES / Carbone'),
   aspectsSignificatifs,
   actionsEnRetard,
   tauxConformiteReglementaire,
  };
 }

 async environnementAlertes(){
  const now=new Date();
  const dans30Jours=new Date(now.getTime()+30*86400000);
  const [records,aspects,actionsEnv,objectifsEnv,produits]=await Promise.all([
   this.db.environmentRecord.findMany({where:{conforme:false},orderBy:{recordedAt:'desc'},take:20}),
   this.db.environnementAspect.findMany({where:{statut:'ACTIVE',significatif:true}}),
   this.db.action.findMany({where:{environnementAspectId:{not:null},status:{not:'CLOSED'}}}),
   this.db.objectifQhse.findMany({where:{pilier:'Environnement',echeance:{not:null}}}),
   this.db.produitChimique.findMany(),
  ]);
  const alertes:any[]=[];
  for(const r of records) alertes.push({id:r.id,label:`Relevé non conforme : ${r.type}`,niveau:'CRITIQUE'});
  for(const a of aspects) if(!a.mesuresMaitrise) alertes.push({id:a.id,label:`Aspect significatif sans mesure de maîtrise : ${a.aspect}`,niveau:'ATTENTION'});
  for(const a of actionsEnv) if(a.dueDate&&new Date(a.dueDate)<now) alertes.push({id:a.id,label:`Action environnementale en retard : ${a.title}`,niveau:'URGENT'});
  for(const o of objectifsEnv){
   const ech=new Date(o.echeance as Date);
   if(ech<now) alertes.push({id:o.id,label:`Objectif environnemental en retard : ${o.titre}`,niveau:'ATTENTION'});
   else if(ech<dans30Jours) alertes.push({id:o.id,label:`Échéance d'objectif proche : ${o.titre}`,niveau:'ATTENTION'});
  }
  for(const p of produits){
   if(!p.fdsDisponible) alertes.push({id:p.id,label:`FDS manquante : ${p.nom}`,niveau:'ATTENTION'});
   if(p.dateExpiration&&new Date(p.dateExpiration)<now) alertes.push({id:p.id,label:`Produit chimique expiré : ${p.nom}`,niveau:'CRITIQUE'});
   if(p.dangerEnvironnemental&&!p.retention) alertes.push({id:p.id,label:`Absence de rétention pour un produit dangereux : ${p.nom}`,niveau:'CRITIQUE'});
   if(p.seuilAlerteStock!=null&&p.quantiteStockee!=null&&p.quantiteStockee>p.seuilAlerteStock) alertes.push({id:p.id,label:`Stock excessif : ${p.nom}`,niveau:'ATTENTION'});
  }
  return alertes.sort((a,b)=>({CRITIQUE:0,URGENT:1,ATTENTION:2} as any)[a.niveau]-({CRITIQUE:0,URGENT:1,ATTENTION:2} as any)[b.niveau]);
 }

 produitChimiqueList(){return this.db.produitChimique.findMany({include:{fournisseur:true},orderBy:{nom:'asc'}})}
 produitChimiqueCreate(b:any){return this.db.produitChimique.create({data:b})}
 produitChimiqueUpdate(id:string,b:any){return this.db.produitChimique.update({where:{id},data:b})}
 produitChimiqueDelete(id:string){return this.db.produitChimique.delete({where:{id}})}

 // Tendances mensuelles — calculées uniquement sur les mois où des
 // relevés existent réellement, jamais une valeur comblée à zéro.
 async environnementTendances(){
  const records=await this.db.environmentRecord.findMany({where:{value:{not:null}},orderBy:{recordedAt:'asc'}});
  const parCategorieMois=new Map<string,Map<string,number>>();
  for(const r of records){
   const cat=r.categorie||'Non catégorisé';
   const mois=new Date(r.recordedAt).toISOString().slice(0,7);
   if(!parCategorieMois.has(cat))parCategorieMois.set(cat,new Map());
   const m=parCategorieMois.get(cat)!;
   m.set(mois,(m.get(mois)||0)+(r.value||0));
  }
  return [...parCategorieMois.entries()].map(([categorie,moisMap])=>({
   categorie,
   points:[...moisMap.entries()].sort((a,b)=>a[0].localeCompare(b[0])).map(([mois,valeur])=>({mois,valeur:Math.round(valeur*100)/100})),
  }));
 }
 trainingList(){return this.db.training.findMany({include:{processus:true},orderBy:{scheduledAt:'desc'}})} trainingCreate(b:any){return this.db.training.create({data:b})} trainingUpdate(id:string,b:any){return this.db.training.update({where:{id},data:b})} trainingDelete(id:string){return this.db.training.delete({where:{id}})}
 equipmentList(){return this.db.equipment.findMany({orderBy:{name:'asc'}})} equipmentCreate(b:any){return this.db.equipment.create({data:b})} equipmentUpdate(id:string,b:any){return this.db.equipment.update({where:{id},data:b})} equipmentDelete(id:string){return this.db.equipment.delete({where:{id}})}
 events(){return this.db.safetyEvent.findMany({include:{site:true,employee:true,enqueteur:true,risk:true,processus:true,fournisseur:true,actions:true},orderBy:{occurredAt:'desc'}})}
 eventGet(id:string){return this.db.safetyEvent.findUnique({where:{id},include:{site:true,employee:true,enqueteur:true,risk:true,epi:true,epc:true,processus:true,fournisseur:true,nonConformity:true,actions:{include:{responsible:true}}}})}
 eventCreate(b:any){return this.db.safetyEvent.create({data:b})}
 eventUpdate(id:string,b:any){return this.db.safetyEvent.update({where:{id},data:b})}
 eventDelete(id:string){return this.db.safetyEvent.delete({where:{id}})}

 // Statistiques Phase 2 — répartitions et Pareto des causes, calculés à
 // la demande depuis les événements déjà enregistrés.
 async safetyEventsStats(){
  const list=await this.db.safetyEvent.findMany();
  const groupCount=(items:any[],keyFn:(x:any)=>string|null|undefined)=>{
   const m=new Map<string,number>();
   for(const it of items){const k=keyFn(it)||'Non renseigné';m.set(k,(m.get(k)||0)+1);}
   return [...m.entries()].map(([name,value])=>({name,value})).sort((a,b)=>b.value-a.value);
  };
  const accidents=list.filter(e=>e.type==='ACCIDENT');
  const incidents=list.filter(e=>e.type!=='ACCIDENT');
  const parType=groupCount(list,e=>e.type);
  const parMecanisme=groupCount(accidents.filter(e=>e.mecanisme),e=>e.mecanisme);
  const parLesion=groupCount(accidents.filter(e=>e.typeLesion),e=>e.typeLesion);
  const parZone=groupCount(list.filter(e=>e.zone),e=>e.zone);
  // Pareto des causes racines — toutes catégories d'événements confondues.
  const causesList=list.filter(e=>e.causeRacine).map(e=>e.causeRacine as string);
  const parCause=groupCount(causesList.map(c=>({c})),(x:any)=>x.c);
  const totalCauses=parCause.reduce((s,c)=>s+c.value,0);
  let cumul=0;
  const pareto=parCause.map(c=>{cumul+=c.value;return {...c,pct:totalCauses?Math.round((c.value/totalCauses)*1000)/10:0,cumulPct:totalCauses?Math.round((cumul/totalCauses)*1000)/10:0};});
  return {
   volume:{total:list.length,accidents:accidents.length,incidents:incidents.length,avecArret:list.filter(e=>e.withLostTime).length,graves:list.filter(e=>e.severity>=4).length},
   parType,parMecanisme,parLesion,parZone,pareto,
  };
 }

 // Alertes automatiques — chaque événement encore ouvert passé au
 // crible de plusieurs critères indépendants.
 async safetyEventsAlertes(){
  const list=await this.db.safetyEvent.findMany({where:{statut:{not:'CLOTURE'}},include:{actions:true}});
  const now=new Date();
  const alertes:any[]=[];
  for(const e of list){
   const motifs:{label:string,niveau:string}[]=[];
   if(e.severity>=4) motifs.push({label:'Événement grave',niveau:'CRITIQUE'});
   if(['DECES','INVALIDITE','COLLECTIF'].includes(e.potentielGravite||'')) motifs.push({label:'Fort potentiel de gravité',niveau:'CRITIQUE'});
   const joursDepuisDeclaration=(now.getTime()-new Date(e.occurredAt).getTime())/86400000;
   if(e.statut==='DECLARE'&&joursDepuisDeclaration>3) motifs.push({label:'Enquête non réalisée',niveau:'URGENT'});
   if(!e.enqueteurId&&joursDepuisDeclaration>3) motifs.push({label:'Sans enquêteur affecté',niveau:'ATTENTION'});
   if((e.actions||[]).some((a:any)=>a.dueDate&&new Date(a.dueDate)<now&&a.status!=='CLOSED')) motifs.push({label:'Action en retard',niveau:'URGENT'});
   if((e.actions||[]).length===0&&['ANALYSE_CAUSES','ACTIONS_DEFINIES'].includes(e.statut)) motifs.push({label:'Sans action définie',niveau:'ATTENTION'});
   if(motifs.length) alertes.push({id:e.id,title:e.title,type:e.type,niveau:motifs.some(m=>m.niveau==='CRITIQUE')?'CRITIQUE':motifs.some(m=>m.niveau==='URGENT')?'URGENT':'ATTENTION',motifs});
  }
  return alertes.sort((a,b)=>({CRITIQUE:0,URGENT:1,ATTENTION:2} as any)[a.niveau]-({CRITIQUE:0,URGENT:1,ATTENTION:2} as any)[b.niveau]);
 }

 // Détection de récidive — même cause racine, même zone ou même
 // mécanisme apparu plus d'une fois.
 async safetyEventsRecidives(){
  const list=await this.db.safetyEvent.findMany({orderBy:{occurredAt:'desc'}});
  const buildGroups=(keyFn:(e:any)=>string|null)=>{
   const map=new Map<string,any[]>();
   for(const e of list){const k=keyFn(e);if(!k)continue;if(!map.has(k))map.set(k,[]);map.get(k)!.push(e);}
   return [...map.entries()].filter(([,items])=>items.length>1).map(([key,items])=>({critere:key,nombre:items.length,dernierEvenement:items[0].title,derniereOccurrence:items[0].occurredAt}));
  };
  return {
   parCauseRacine:buildGroups(e=>e.causeRacine).sort((a,b)=>b.nombre-a.nombre),
   parZone:buildGroups(e=>e.zone).sort((a,b)=>b.nombre-a.nombre),
   parMecanisme:buildGroups(e=>e.mecanisme).sort((a,b)=>b.nombre-a.nombre),
  };
 }

 processusList(){return this.db.processus.findMany({include:{pilote:true,suppleant:true,site:true,activities:{include:{racis:true}},exigences:true,trainings:true,objectifsQhse:true,documents:true,audits:true,_count:{select:{
   risks:{where:{status:'ACTIVE'}},
   actions:{where:{status:{not:'CLOSED'}}},
   nonConformities:{where:{status:'OPEN'}},
   qualityControls:true,
 }}},orderBy:{createdAt:'desc'}})}
 processusGet(id:string){return this.db.processus.findUnique({where:{id},include:{pilote:true,suppleant:true,site:true,activities:{include:{racis:{include:{user:true}},responsible:true},orderBy:{order:'asc'}},exigences:{include:{responsable:true}},risks:true,actions:{include:{responsible:true}},nonConformities:true,audits:true,documents:true,trainings:true,objectifsQhse:true,qualityControls:true}})}
 processusCreate(b:any){return this.db.processus.create({data:b})}
 processusUpdate(id:string,b:any){return this.db.processus.update({where:{id},data:b})}
 processusDelete(id:string){return this.db.processus.delete({where:{id}})}

 processusActivityList(processusId:string){return this.db.processusActivity.findMany({where:{processusId},include:{responsible:true,racis:{include:{user:true}}},orderBy:{order:'asc'}})}
 processusActivityCreate(b:any){return this.db.processusActivity.create({data:b})}
 processusActivityUpdate(id:string,b:any){return this.db.processusActivity.update({where:{id},data:b})}
 processusActivityDelete(id:string){return this.db.processusActivity.delete({where:{id}})}

 processusRaciUpsert(activityId:string,b:any){
  // Une seule ligne RACI par (activité, utilisateur ou libellé de rôle) —
  // on remplace plutôt que d'empiler des doublons à chaque saisie.
  if(b.id) return this.db.processusRaci.update({where:{id:b.id},data:{raci:b.raci,userId:b.userId,roleLabel:b.roleLabel}});
  return this.db.processusRaci.create({data:{activityId,userId:b.userId,roleLabel:b.roleLabel,raci:b.raci}});
 }
 processusRaciDelete(id:string){return this.db.processusRaci.delete({where:{id}})}

 processusExigenceList(processusId:string){return this.db.processusExigence.findMany({where:{processusId},include:{responsable:true},orderBy:{createdAt:'desc'}})}
 processusExigenceCreate(b:any){return this.db.processusExigence.create({data:b})}
 processusExigenceUpdate(id:string,b:any){return this.db.processusExigence.update({where:{id},data:b})}
 processusExigenceDelete(id:string){return this.db.processusExigence.delete({where:{id}})}

 processusLinkList(){return this.db.processusLink.findMany()}
 processusLinkCreate(b:any){return this.db.processusLink.create({data:{sourceId:b.sourceId,targetId:b.targetId,label:b.label}})}
 processusLinkDelete(id:string){return this.db.processusLink.delete({where:{id}})}
 indicateurList(domaine?:string){return this.db.indicateurQualite.findMany({where:domaine?{domaine}:undefined,include:{processus:true,mesures:{orderBy:{periode:'desc'},take:12}},orderBy:{createdAt:'desc'}})} indicateurCreate(b:any){return this.db.indicateurQualite.create({data:{...b,actuel:Number(b.actuel),cible:Number(b.cible),seuilVert:b.seuilVert!==undefined?Number(b.seuilVert):undefined,seuilOrange:b.seuilOrange!==undefined?Number(b.seuilOrange):undefined}})} indicateurUpdate(id:string,b:any){return this.db.indicateurQualite.update({where:{id},data:{...b,...(b.actuel!==undefined?{actuel:Number(b.actuel)}:{}),...(b.cible!==undefined?{cible:Number(b.cible)}:{}),...(b.seuilVert!==undefined?{seuilVert:Number(b.seuilVert)}:{}),...(b.seuilOrange!==undefined?{seuilOrange:Number(b.seuilOrange)}:{})}})} indicateurDelete(id:string){return this.db.indicateurQualite.delete({where:{id}})}

 // Ajouter une mesure met aussi à jour la valeur actuelle affichée sur
 // la fiche — pas besoin de le faire deux fois séparément.
 async indicateurMesureCreate(indicateurId:string,b:any){
  return this.db.$transaction(async(tx)=>{
   const m=await tx.indicateurMesure.create({data:{indicateurId,valeur:Number(b.valeur),periode:b.periode?new Date(b.periode):new Date(),commentaire:b.commentaire}});
   await tx.indicateurQualite.update({where:{id:indicateurId},data:{actuel:Number(b.valeur)}});
   return m;
  });
 }
 indicateurMesureList(indicateurId:string){return this.db.indicateurMesure.findMany({where:{indicateurId},orderBy:{periode:'desc'}})}

 // Bibliothèque d'indicateurs calculés automatiquement depuis les
 // données déjà enregistrées dans les autres modules — le principe de
 // convergence demandé : Contrôle → NC → Action → KPI, Réclamation →
 // KPI, Fournisseur → KPI, Audit → KPI, Processus → KPI. Rien n'est
 // ressaisi, tout est recalculé à la demande depuis les tables déjà
 // remplies par les autres écrans.
 async indicateursAuto(range?:{from:Date,to:Date}){
  const dateFilter=(field:string)=>range?{[field]:{gte:range.from,lt:range.to}}:{};
  const [controls,nc,actions,reclamations,fournisseurControls,audits]=await Promise.all([
   this.db.qualityControl.groupBy({by:['status'],_count:true,where:{status:{in:['COMPLIANT','NON_COMPLIANT']},...dateFilter('controlDate')}}),
   this.db.nonConformity.groupBy({by:['status'],_count:true,where:{...dateFilter('occurredAt')}}),
   this.db.action.groupBy({by:['status'],_count:true,where:{...dateFilter('createdAt')}}),
   this.db.reclamation.groupBy({by:['statut'],_count:true,where:{...dateFilter('date')}}),
   this.db.qualityControl.groupBy({by:['status'],_count:true,where:{fournisseurId:{not:null},status:{in:['COMPLIANT','NON_COMPLIANT']},...dateFilter('controlDate')}}),
   this.db.qhseAudit.groupBy({by:['status'],_count:true,where:{...dateFilter('auditDate')}}),
  ]);
  const pct=(list:any[],key:string,matchValues:string[],totalValues?:string[])=>{
   const total=totalValues?list.filter(x=>totalValues.includes(x[key])).reduce((s,x)=>s+x._count,0):list.reduce((s,x)=>s+x._count,0);
   const match=list.filter(x=>matchValues.includes(x[key])).reduce((s,x)=>s+x._count,0);
   return total>0?Math.round((match/total)*1000)/10:null;
  };
  return [
   {key:'taux_conformite_controles',nom:'Taux de conformité des contrôles',categorie:'Contrôle qualité',formule:'Contrôles conformes / Contrôles réalisés × 100',unite:'%',sensInverse:false,valeur:pct(controls,'status',['COMPLIANT'])},
   {key:'taux_nc_ouvertes',nom:'Taux de non-conformités ouvertes',categorie:'Non-conformités',formule:'NC ouvertes / NC totales × 100',unite:'%',sensInverse:true,valeur:pct(nc,'status',['OPEN'])},
   {key:'taux_cloture_actions',nom:'Taux de clôture des actions',categorie:'Actions',formule:'Actions clôturées / Actions totales × 100',unite:'%',sensInverse:false,valeur:pct(actions,'status',['CLOSED'])},
   {key:'taux_reclamations_cloturees',nom:'Taux de réclamations clôturées',categorie:'Satisfaction client',formule:'Réclamations clôturées / Réclamations totales × 100',unite:'%',sensInverse:false,valeur:pct(reclamations,'statut',['CLOSED'])},
   {key:'taux_conformite_fournisseur',nom:'Taux de conformité fournisseur',categorie:'Fournisseurs',formule:'Contrôles fournisseur conformes / Contrôles fournisseur réalisés × 100',unite:'%',sensInverse:false,valeur:pct(fournisseurControls,'status',['COMPLIANT'])},
   {key:'taux_realisation_audits',nom:'Taux de réalisation des audits',categorie:'Audits',formule:'Audits réalisés / Audits planifiés × 100',unite:'%',sensInverse:false,valeur:pct(audits,'status',['COMPLETED'],['PLANNED','IN_PROGRESS','COMPLETED'])},
  ];
 }

 // Comparaison mois en cours / mois précédent — même bibliothèque,
 // juste calculée sur deux fenêtres de dates différentes.
 async indicateursAutoCompare(){
  const now=new Date();
  const startCurrent=new Date(now.getFullYear(),now.getMonth(),1);
  const startPrevious=new Date(now.getFullYear(),now.getMonth()-1,1);
  const [current,previous]=await Promise.all([
   this.indicateursAuto({from:startCurrent,to:now}),
   this.indicateursAuto({from:startPrevious,to:startCurrent}),
  ]);
  return current.map((c,i)=>({...c,valeurPrecedente:previous[i]?.valeur??null}));
 }

 indicateurPonderationList(){return this.db.indicateurPonderation.findMany()}
 async indicateurPonderationSet(autoKey:string,poids:number){
  return this.db.indicateurPonderation.upsert({where:{autoKey},update:{poids},create:{autoKey,poids}});
 }

 // Indice global de performance qualité — moyenne pondérée des
 // indicateurs de la bibliothèque automatique, pondérations
 // entièrement configurables (poids égal à 1 par défaut si non réglé).
 async indiceGlobalQualite(){
  const [autoList,ponderations]=await Promise.all([this.indicateursAuto(),this.indicateurPonderationList()]);
  const poidsMap=Object.fromEntries(ponderations.map(p=>[p.autoKey,p.poids]));
  let sommePonderee=0,sommePoids=0;
  const detail=autoList.map(a=>{
   const poids=poidsMap[a.key]??1;
   // Un indicateur "sens inverse" (ex: taux de NC) est normalisé pour
   // que 100 corresponde toujours à la meilleure performance possible.
   const valeurNormalisee=a.valeur==null?null:(a.sensInverse?100-a.valeur:a.valeur);
   if(valeurNormalisee!=null){sommePonderee+=valeurNormalisee*poids;sommePoids+=poids;}
   return {...a,poids,valeurNormalisee};
  });
  return {indice:sommePoids>0?Math.round((sommePonderee/sommePoids)*10)/10:null,detail};
 }

 async reclamationList(){
  const list=await this.db.reclamation.findMany({include:{site:true,processus:true,fournisseur:true,nonConformity:true,actionCurativeResponsable:true,actions:true},orderBy:{date:'desc'}});
  return list.map(r=>({...r,coutTotal:[r.coutRemboursement,r.coutRemplacement,r.coutTransport,r.coutMainOeuvre,r.coutAutres,r.actionCurativeCout].reduce((s:number,v)=>s+(v||0),0)}));
 }
 reclamationGet(id:string){return this.db.reclamation.findUnique({where:{id},include:{site:true,processus:true,fournisseur:true,nonConformity:true,actionCurativeResponsable:true,actions:{include:{responsible:true}}}})}
 reclamationCreate(b:any){return this.db.reclamation.create({data:b})}
 reclamationUpdate(id:string,b:any){return this.db.reclamation.update({where:{id},data:b})}
 reclamationDelete(id:string){return this.db.reclamation.delete({where:{id}})}

 // Tableau de bord Phase 2 — tout calculé à la demande depuis les
 // réclamations déjà enregistrées, rien de nouveau à saisir.
 async reclamationsStats(){
  const list=await this.db.reclamation.findMany({include:{processus:true}});
  const now=new Date();
  const closed=list.filter(r=>r.statut==='CLOSED');
  const open=list.filter(r=>r.statut==='OPEN');
  const critiques=list.filter(r=>['Majeure','Critique','Élevée'].includes(r.gravite));
  const enRetard=open.filter(r=>r.delaiCibleJours&&(now.getTime()-new Date(r.date).getTime())/86400000>r.delaiCibleJours);
  const avgDays=(items:any[],fromField:string,toField:string)=>{
   const diffs=items.filter(r=>(r as any)[fromField]&&(r as any)[toField]).map(r=>(new Date((r as any)[toField]).getTime()-new Date((r as any)[fromField]).getTime())/86400000);
   return diffs.length?Math.round((diffs.reduce((s,d)=>s+d,0)/diffs.length)*10)/10:null;
  };
  const closedInDelay=closed.filter(r=>r.delaiCibleJours&&r.dateCloture&&(new Date(r.dateCloture).getTime()-new Date(r.date).getTime())/86400000<=r.delaiCibleJours).length;
  const groupCount=(items:any[],keyFn:(x:any)=>string)=>{
   const m=new Map<string,number>();
   for(const it of items){const k=keyFn(it)||'Non renseigné';m.set(k,(m.get(k)||0)+1);}
   return [...m.entries()].map(([name,value])=>({name,value})).sort((a,b)=>b.value-a.value);
  };
  const parCause=groupCount(list,(r)=>r.categorieProbleme);
  const totalCauses=parCause.reduce((s,c)=>s+c.value,0);
  let cumul=0;
  const pareto=parCause.map(c=>{cumul+=c.value;return {...c,pct:totalCauses?Math.round((c.value/totalCauses)*1000)/10:0,cumulPct:totalCauses?Math.round((cumul/totalCauses)*1000)/10:0};});
  // Récurrence détectée automatiquement — même client et même nature de
  // problème apparus plus d'une fois, indépendamment de la case à
  // cocher manuelle.
  const recurrenceKey=(r:any)=>r.categorieProbleme?`${r.client}__${r.categorieProbleme}`:null;
  const recurrenceMap=new Map<string,any[]>();
  for(const r of list){const k=recurrenceKey(r);if(!k)continue;if(!recurrenceMap.has(k))recurrenceMap.set(k,[]);recurrenceMap.get(k)!.push(r);}
  const recurrencesDetectees=[...recurrenceMap.entries()].filter(([,items])=>items.length>1).map(([key,items])=>{
   const [client,cause]=key.split('__');
   return {client,cause,nombre:items.length,derniereOccurrence:items.map(i=>i.date).sort().reverse()[0]};
  }).sort((a,b)=>b.nombre-a.nombre);
  return {
   volume:{total:list.length,ouvertes:open.length,cloturees:closed.length,critiques:critiques.length,recurrentesManuelles:list.filter(r=>r.recurrente).length,recurrencesDetectees:recurrencesDetectees.length,enRetard:enRetard.length},
   performance:{
    tauxCloture:list.length?Math.round((closed.length/list.length)*1000)/10:null,
    tauxClotureDelai:closed.length?Math.round((closedInDelay/closed.length)*1000)/10:null,
    delaiMoyenAccuseReception:avgDays(list,'date','dateAccuseReception'),
    delaiMoyenPremiereReponse:avgDays(list,'date','datePremiereReponse'),
    delaiMoyenResolution:avgDays(list,'date','dateResolutionReelle'),
    delaiMoyenCloture:avgDays(list,'date','dateCloture'),
   },
   pareto,
   parClient:groupCount(list,(r)=>r.client).slice(0,10),
   parProduit:groupCount(list.filter(r=>r.produitService),(r)=>r.produitService).slice(0,10),
   parProcessus:groupCount(list.filter(r=>r.processus),(r)=>r.processus.nom).slice(0,10),
   recurrencesDetectees,
  };
 }

 // Alertes automatiques — chaque réclamation ouverte est passée au
 // crible de plusieurs critères indépendants, avec un niveau de
 // sévérité par alerte plutôt qu'un seul statut global.
 async reclamationsAlertes(){
  const list=await this.db.reclamation.findMany({where:{statut:'OPEN'},include:{actions:true}});
  const now=new Date();
  const alertes:any[]=[];
  for(const r of list){
   const motifs:{label:string,niveau:string}[]=[];
   if(r.delaiCibleJours&&(now.getTime()-new Date(r.date).getTime())/86400000>r.delaiCibleJours) motifs.push({label:'Délai cible dépassé',niveau:'URGENT'});
   if(['Critique','Majeure','Élevée'].includes(r.gravite)) motifs.push({label:'Réclamation critique',niveau:'CRITIQUE'});
   if(!r.actionCurativeResponsableId) motifs.push({label:'Sans responsable',niveau:'ATTENTION'});
   if((r.actions||[]).length===0) motifs.push({label:'Sans action corrective',niveau:'ATTENTION'});
   if((r.actions||[]).some(a=>a.dueDate&&new Date(a.dueDate)<now&&a.status!=='CLOSED')) motifs.push({label:'Action en retard',niveau:'URGENT'});
   if(['Critique','Majeure'].includes(r.gravite)&&!r.causeRacine) motifs.push({label:'Analyse des causes requise',niveau:'ATTENTION'});
   if(r.recurrente) motifs.push({label:'Problème récurrent',niveau:'ATTENTION'});
   if(motifs.length) alertes.push({id:r.id,client:r.client,motif:r.motif,niveau:motifs.some(m=>m.niveau==='CRITIQUE')?'CRITIQUE':motifs.some(m=>m.niveau==='URGENT')?'URGENT':'ATTENTION',motifs});
  }
  return alertes.sort((a,b)=>({CRITIQUE:0,URGENT:1,ATTENTION:2,INFORMATION:3} as any)[a.niveau]-({CRITIQUE:0,URGENT:1,ATTENTION:2,INFORMATION:3} as any)[b.niveau]);
 }

 // Score global de performance réclamations — même principe que
 // l'indice global de performance qualité : moyenne pondérée,
 // pondérations réutilisant la même table de configuration.
 async reclamationsScoreGlobal(){
  const [statsData,ponderations]=await Promise.all([this.reclamationsStats(),this.indicateurPonderationList()]);
  const poidsMap=Object.fromEntries(ponderations.map(p=>[p.autoKey,p.poids]));
  const closedList=await this.db.reclamation.findMany({where:{statut:'CLOSED'}});
  const withEfficacite=closedList.filter(r=>r.efficacite);
  const efficaces=withEfficacite.filter(r=>r.efficacite==='EFFICACE').length;
  const tauxEfficacite=withEfficacite.length?Math.round((efficaces/withEfficacite.length)*1000)/10:null;
  const withSatisfaction=await this.db.reclamation.count({where:{satisfaction:{not:null}}});
  const satisfaits=await this.db.reclamation.count({where:{satisfaction:'SATISFAIT'}});
  const tauxSatisfaction=withSatisfaction?Math.round((satisfaits/withSatisfaction)*1000)/10:null;
  const tauxRecurrence=statsData.volume.total?Math.round((statsData.recurrencesDetectees.length/statsData.volume.total)*1000)/10:null;
  const tauxCritiques=statsData.volume.total?Math.round((statsData.volume.critiques/statsData.volume.total)*1000)/10:null;
  const composantes=[
   {key:'reclam_taux_cloture',nom:'Taux de clôture',valeur:statsData.performance.tauxCloture},
   {key:'reclam_taux_delai',nom:'Respect des délais',valeur:statsData.performance.tauxClotureDelai},
   {key:'reclam_taux_recurrence',nom:'Faible récurrence',valeur:tauxRecurrence==null?null:100-tauxRecurrence},
   {key:'reclam_satisfaction',nom:'Satisfaction client',valeur:tauxSatisfaction},
   {key:'reclam_efficacite',nom:'Efficacité des actions',valeur:tauxEfficacite},
   {key:'reclam_faible_criticite',nom:'Faible taux de critiques',valeur:tauxCritiques==null?null:100-tauxCritiques},
  ];
  let somme=0,poidsTotal=0;
  const detail=composantes.map(c=>{
   const poids=poidsMap[c.key]??1;
   if(c.valeur!=null){somme+=c.valeur*poids;poidsTotal+=poids;}
   return {...c,poids};
  });
  return {score:poidsTotal>0?Math.round((somme/poidsTotal)*10)/10:null,detail};
 }
 fournisseurList(){return this.db.fournisseur.findMany({include:{responsableInterne:true,certifications:true,_count:{select:{nonConformities:{where:{status:'OPEN'}},actions:{where:{status:{not:'CLOSED'}}},audits:true,risks:{where:{status:'ACTIVE'}}}}},orderBy:{nom:'asc'}})}
 fournisseurGet(id:string){return this.db.fournisseur.findUnique({where:{id},include:{responsableInterne:true,certifications:true,nonConformities:true,actions:{include:{responsible:true}},audits:true,risks:true,qualityControls:true,reclamations:true}})}
 fournisseurCreate(b:any){return this.db.fournisseur.create({data:b})}
 fournisseurUpdate(id:string,b:any){return this.db.fournisseur.update({where:{id},data:b})}
 fournisseurDelete(id:string){return this.db.fournisseur.delete({where:{id}})}

 fournisseurCertificationList(fournisseurId:string){return this.db.fournisseurCertification.findMany({where:{fournisseurId},orderBy:{dateExpiration:'asc'}})}
 fournisseurCertificationCreate(b:any){return this.db.fournisseurCertification.create({data:b})}
 fournisseurCertificationUpdate(id:string,b:any){return this.db.fournisseurCertification.update({where:{id},data:b})}
 fournisseurCertificationDelete(id:string){return this.db.fournisseurCertification.delete({where:{id}})}

 // Score global pondéré — même principe que l'indice qualité et le
 // score réclamations : moyenne pondérée des scores par domaine,
 // pondérations réutilisant la même table de configuration.
 async fournisseurScoreGlobal(id:string){
  const f=await this.db.fournisseur.findUnique({where:{id}});
  if(!f) throw new Error('Fournisseur introuvable');
  const ponderations=await this.indicateurPonderationList();
  const poidsMap=Object.fromEntries(ponderations.map(p=>[p.autoKey,p.poids]));
  const composantes=[
   {key:'fourn_qualite',nom:'Qualité',valeur:f.scoreQualite},
   {key:'fourn_livraison',nom:'Livraison',valeur:f.scoreLivraison},
   {key:'fourn_qhse',nom:'QHSE',valeur:f.scoreQhse},
   {key:'fourn_commercial',nom:'Commercial',valeur:f.scoreCommercial},
   {key:'fourn_reactivite',nom:'Réactivité',valeur:f.scoreReactivite},
  ];
  let somme=0,poidsTotal=0;
  const detail=composantes.map(c=>{
   const poids=poidsMap[c.key]??1;
   if(c.valeur!=null){somme+=c.valeur*poids;poidsTotal+=poids;}
   return {...c,poids};
  });
  return {score:poidsTotal>0?Math.round((somme/poidsTotal)*10)/10:null,detail};
 }

 // Classement automatique — tous les fournisseurs ayant au moins un
 // score renseigné, triés du meilleur au moins bon.
 async fournisseursClassement(){
  const list=await this.db.fournisseur.findMany();
  const ponderations=await this.indicateurPonderationList();
  const poidsMap=Object.fromEntries(ponderations.map(p=>[p.autoKey,p.poids]));
  const withScore=list.map(f=>{
   const composantes=[
    {key:'fourn_qualite',valeur:f.scoreQualite},{key:'fourn_livraison',valeur:f.scoreLivraison},
    {key:'fourn_qhse',valeur:f.scoreQhse},{key:'fourn_commercial',valeur:f.scoreCommercial},{key:'fourn_reactivite',valeur:f.scoreReactivite},
   ];
   let somme=0,poidsTotal=0;
   for(const c of composantes){const poids=poidsMap[c.key]??1;if(c.valeur!=null){somme+=c.valeur*poids;poidsTotal+=poids;}}
   return {id:f.id,nom:f.nom,score:poidsTotal>0?Math.round((somme/poidsTotal)*10)/10:null};
  }).filter(f=>f.score!=null).sort((a,b)=>(b.score as number)-(a.score as number));
  return {top:withScore.slice(0,10),flop:[...withScore].reverse().slice(0,10)};
 }

 // Alertes automatiques — chaque fournisseur passé au crible de
 // plusieurs critères indépendants, avec un niveau de sévérité par
 // alerte plutôt qu'un seul statut global.
 async fournisseursAlertes(){
  const list=await this.db.fournisseur.findMany({include:{certifications:true,_count:{select:{nonConformities:{where:{status:'OPEN'}}}}}});
  const now=new Date();
  const dans60Jours=new Date(now.getTime()+60*86400000);
  const alertes:any[]=[];
  for(const f of list){
   if(['SUSPENDU','BLOQUE','RETIRE','INACTIF'].includes(f.statut)) continue;
   const motifs:{label:string,niveau:string}[]=[];
   for(const cert of f.certifications){
    if(cert.dateExpiration&&new Date(cert.dateExpiration)<now) motifs.push({label:`Certification expirée : ${cert.type}`,niveau:'CRITIQUE'});
    else if(cert.dateExpiration&&new Date(cert.dateExpiration)<dans60Jours) motifs.push({label:`Certification bientôt expirée : ${cert.type}`,niveau:'ATTENTION'});
   }
   if(f.dateProchaineReevaluation&&new Date(f.dateProchaineReevaluation)<now) motifs.push({label:'Réévaluation échue',niveau:'URGENT'});
   if((f._count?.nonConformities||0)>0&&f.criticite) motifs.push({label:'NC ouverte chez un fournisseur critique',niveau:'CRITIQUE'});
   if(f.criticite&&f.monoSource&&!f.solutionSecours) motifs.push({label:'Mono-source critique sans solution de secours',niveau:'URGENT'});
   const scores=[f.scoreQualite,f.scoreLivraison,f.scoreQhse,f.scoreCommercial,f.scoreReactivite].filter(v=>v!=null) as number[];
   const moyenne=scores.length?scores.reduce((s,v)=>s+v,0)/scores.length:null;
   if(moyenne!=null&&moyenne<50) motifs.push({label:'Score global sous le seuil critique (< 50%)',niveau:'CRITIQUE'});
   if(motifs.length) alertes.push({id:f.id,nom:f.nom,niveau:motifs.some(m=>m.niveau==='CRITIQUE')?'CRITIQUE':motifs.some(m=>m.niveau==='URGENT')?'URGENT':'ATTENTION',motifs});
  }
  return alertes.sort((a,b)=>({CRITIQUE:0,URGENT:1,ATTENTION:2} as any)[a.niveau]-({CRITIQUE:0,URGENT:1,ATTENTION:2} as any)[b.niveau]);
 }

 // Matrice de risque — réutilise le module Risques déjà existant
 // (probabilité × gravité déjà calculées là-bas), simplement filtré
 // sur les risques liés à un fournisseur.
 async fournisseursMatriceRisque(){
  const risks=await this.db.risk.findMany({where:{fournisseurId:{not:null},status:'ACTIVE'},include:{fournisseur:true},orderBy:{score:'desc'}});
  return risks.map(r=>({id:r.id,fournisseur:r.fournisseur?.nom,hazard:r.hazard,severity:r.severity,probability:r.probability,score:r.score}));
 }
 visiteMedicaleList(){return this.db.visiteMedicale.findMany({include:{employee:true},orderBy:{prochaineVisite:'asc'}})} visiteMedicaleCreate(b:any){return this.db.visiteMedicale.create({data:b})} visiteMedicaleUpdate(id:string,b:any){return this.db.visiteMedicale.update({where:{id},data:b})} visiteMedicaleDelete(id:string){return this.db.visiteMedicale.delete({where:{id}})}

 // Risques sanitaires — la criticité se recalcule à chaque écriture,
 // jamais ressaisie séparément par l'utilisateur.
 risqueSanitaireList(){return this.db.risqueSanitaire.findMany({include:{site:true,processus:true,responsable:true,expositions:true,actions:true},orderBy:{criticite:'desc'}})}
 risqueSanitaireGet(id:string){return this.db.risqueSanitaire.findUnique({where:{id},include:{site:true,processus:true,responsable:true,expositions:{include:{employee:true}},actions:{include:{responsible:true}}}})}
 risqueSanitaireCreate(b:any){
  const gravite=Number(b.gravite)||1,probabilite=Number(b.probabilite)||1;
  return this.db.risqueSanitaire.create({data:{...b,gravite,probabilite,criticite:gravite*probabilite}});
 }
 async risqueSanitaireUpdate(id:string,b:any){
  const current=await this.db.risqueSanitaire.findUnique({where:{id}});
  const gravite=b.gravite!==undefined?Number(b.gravite):current?.gravite??1;
  const probabilite=b.probabilite!==undefined?Number(b.probabilite):current?.probabilite??1;
  return this.db.risqueSanitaire.update({where:{id},data:{...b,gravite,probabilite,criticite:gravite*probabilite}});
 }
 risqueSanitaireDelete(id:string){return this.db.risqueSanitaire.delete({where:{id}})}

 expositionCreate(b:any){return this.db.expositionSurveillance.create({data:{...b,valeurMesuree:b.valeurMesuree!==undefined?Number(b.valeurMesuree):undefined,valeurLimite:b.valeurLimite!==undefined?Number(b.valeurLimite):undefined,conforme:b.valeurMesuree!=null&&b.valeurLimite!=null?Number(b.valeurMesuree)<=Number(b.valeurLimite):b.conforme}})}
 expositionDelete(id:string){return this.db.expositionSurveillance.delete({where:{id}})}

 // Ergonomie — le score se recalcule depuis les facteurs cochés à
 // chaque écriture, jamais ressaisi séparément par l'utilisateur.
 private calculerScoreErgonomique(b:any):string{
  const facteurs=['stationDeboutProlongee','stationAssiseProlongee','travailRepetitif','manutentionChargesLourdes','posturesContraignantes','ecranInformatiquePosture','vibrations','eclairageInsuffisant','espaceInsuffisant'];
  const count=facteurs.filter(f=>b[f]===true).length;
  return count>=6?'CRITIQUE':count>=4?'ELEVE':count>=2?'MODERE':'FAIBLE';
 }
 analyseErgonomiqueList(){return this.db.analyseErgonomique.findMany({include:{site:true,processus:true,evaluateur:true,tmsSignalements:true,actions:true},orderBy:{createdAt:'desc'}})}
 analyseErgonomiqueGet(id:string){return this.db.analyseErgonomique.findUnique({where:{id},include:{site:true,processus:true,evaluateur:true,tmsSignalements:{include:{employee:true}},actions:{include:{responsible:true}}}})}
 analyseErgonomiqueCreate(b:any){return this.db.analyseErgonomique.create({data:{...b,scoreErgonomique:this.calculerScoreErgonomique(b)}})}
 async analyseErgonomiqueUpdate(id:string,b:any){
  const current=await this.db.analyseErgonomique.findUnique({where:{id}});
  const merged={...current,...b};
  return this.db.analyseErgonomique.update({where:{id},data:{...b,scoreErgonomique:this.calculerScoreErgonomique(merged)}});
 }
 analyseErgonomiqueDelete(id:string){return this.db.analyseErgonomique.delete({where:{id}})}

 tmsSignalementList(){return this.db.tmsSignalement.findMany({include:{employee:true,analyseErgonomique:true},orderBy:{dateSignalement:'desc'}})}
 tmsSignalementCreate(b:any){return this.db.tmsSignalement.create({data:b})}
 tmsSignalementUpdate(id:string,b:any){return this.db.tmsSignalement.update({where:{id},data:b})}
 tmsSignalementDelete(id:string){return this.db.tmsSignalement.delete({where:{id}})}

 penibiliteFactorList(){return this.db.penibiliteFactor.findMany({where:{actif:true},orderBy:{nom:'asc'}})}
 penibiliteFactorCreate(b:any){return this.db.penibiliteFactor.create({data:b})}
 penibiliteFactorDelete(id:string){return this.db.penibiliteFactor.update({where:{id},data:{actif:false}})}

 penibiliteExpositionList(){return this.db.penibiliteExposition.findMany({include:{employee:true,facteur:true},orderBy:{dateEvaluation:'desc'}})}
 penibiliteExpositionCreate(b:any){return this.db.penibiliteExposition.create({data:b})}
 penibiliteExpositionDelete(id:string){return this.db.penibiliteExposition.delete({where:{id}})}

 // Alertes automatiques hygiène au travail — chaque critère est
 // indépendant, avec un niveau de sévérité propre.
 async hygieneAlertes(){
  const now=new Date();
  const dans30Jours=new Date(now.getTime()+30*86400000);
  const [visites,risques,ergonomies,expositionsNC,penibiliteEchues]=await Promise.all([
   this.db.visiteMedicale.findMany({where:{prochaineVisite:{not:null}}}),
   this.db.risqueSanitaire.findMany({where:{statut:'ACTIVE'}}),
   this.db.analyseErgonomique.findMany({where:{scoreErgonomique:{in:['ELEVE','CRITIQUE']}}}),
   this.db.expositionSurveillance.findMany({where:{conforme:false},include:{risqueSanitaire:true}}),
   this.db.penibiliteExposition.findMany({where:{prochaineReevaluation:{lt:now}}}),
  ]);
  const alertes:any[]=[];
  for(const v of visites){
   if(new Date(v.prochaineVisite as Date)<now) alertes.push({id:v.id,type:'VISITE_MEDICALE',label:`Visite médicale échue : ${v.employeNom}`,niveau:'URGENT'});
   else if(new Date(v.prochaineVisite as Date)<dans30Jours) alertes.push({id:v.id,type:'VISITE_MEDICALE',label:`Visite médicale proche : ${v.employeNom}`,niveau:'ATTENTION'});
  }
  for(const r of risques){
   if(r.criticite>=12) alertes.push({id:r.id,type:'RISQUE_SANITAIRE',label:`Risque sanitaire critique : ${r.danger}`,niveau:'CRITIQUE'});
  }
  for(const e of ergonomies){
   alertes.push({id:e.id,type:'ERGONOMIE',label:`Poste ergonomiquement ${e.scoreErgonomique==='CRITIQUE'?'critique':'à risque élevé'} : ${e.poste}`,niveau:e.scoreErgonomique==='CRITIQUE'?'CRITIQUE':'ATTENTION'});
  }
  for(const ex of expositionsNC){
   alertes.push({id:ex.id,type:'EXPOSITION',label:`Valeur d'exposition dépassée : ${ex.agentDangereux||ex.risqueSanitaire?.danger||'—'}`,niveau:'CRITIQUE'});
  }
  for(const p of penibiliteEchues){
   alertes.push({id:p.id,type:'PENIBILITE',label:'Réévaluation de pénibilité nécessaire',niveau:'ATTENTION'});
  }
  return alertes.sort((a,b)=>({CRITIQUE:0,URGENT:1,ATTENTION:2} as any)[a.niveau]-({CRITIQUE:0,URGENT:1,ATTENTION:2} as any)[b.niveau]);
 }

 // Indice global Hygiène au travail — remplace les données de
 // démonstration figées du tableau de bord général par un vrai calcul,
 // pondérations réutilisant la même table de configuration que les
 // autres indices de l'application.
 async hygieneIndiceGlobal(){
  const [visites,risques,ergonomies,tms,ponderations]=await Promise.all([
   this.db.visiteMedicale.findMany(),
   this.db.risqueSanitaire.findMany({where:{statut:'ACTIVE'}}),
   this.db.analyseErgonomique.findMany(),
   this.db.tmsSignalement.findMany(),
   this.indicateurPonderationList(),
  ]);
  const poidsMap=Object.fromEntries(ponderations.map(p=>[p.autoKey,p.poids]));
  const now=new Date();
  const avecEcheance=visites.filter(v=>v.prochaineVisite);
  const enRetard=avecEcheance.filter(v=>new Date(v.prochaineVisite as Date)<now).length;
  const tauxSuiviMedical=avecEcheance.length?Math.round((1-enRetard/avecEcheance.length)*1000)/10:null;
  const tauxMaitriseRisques=risques.length?Math.round((1-risques.filter(r=>r.criticite>=12).length/risques.length)*1000)/10:null;
  const tauxErgonomie=ergonomies.length?Math.round((1-ergonomies.filter(e=>['ELEVE','CRITIQUE'].includes(e.scoreErgonomique)).length/ergonomies.length)*1000)/10:null;
  const tauxTms=tms.length?Math.round(Math.max(0,100-tms.length*5)*10)/10:100;
  const composantes=[
   {key:'hyg_suivi_medical',nom:'Suivi médical',valeur:tauxSuiviMedical},
   {key:'hyg_maitrise_risques',nom:'Maîtrise des risques sanitaires',valeur:tauxMaitriseRisques},
   {key:'hyg_ergonomie',nom:'Ergonomie des postes',valeur:tauxErgonomie},
   {key:'hyg_tms',nom:'Faible sinistralité TMS',valeur:tauxTms},
  ];
  let somme=0,poidsTotal=0;
  const detail=composantes.map(c=>{
   const poids=poidsMap[c.key]??1;
   if(c.valeur!=null){somme+=c.valeur*poids;poidsTotal+=poids;}
   return {...c,poids};
  });
  return {indice:poidsTotal>0?Math.round((somme/poidsTotal)*10)/10:null,detail};
 }
 veilleList(){return this.db.veilleReglementaire.findMany({include:{responsable:true},orderBy:{dateApplication:'asc'}})} veilleCreate(b:any){return this.db.veilleReglementaire.create({data:b})} veilleUpdate(id:string,b:any){return this.db.veilleReglementaire.update({where:{id},data:b})} veilleDelete(id:string){return this.db.veilleReglementaire.delete({where:{id}})}
 objectifList(){
  return this.db.objectifQhse.findMany({include:{processus:true,responsable:true},orderBy:{createdAt:'desc'}}).then(list=>list.map(o=>{
   let progression=null;
   if(o.valeurInitiale!=null){
    const denom=o.cible-o.valeurInitiale;
    if(denom!==0){const p=((o.actuel-o.valeurInitiale)/denom)*100;progression=Math.max(0,Math.min(100,Math.round(p*10)/10));}
   }
   return {...o,progression};
  }));
 }
 objectifCreate(b:any){return this.db.objectifQhse.create({data:{...b,cible:Number(b.cible),actuel:b.actuel!==undefined?Number(b.actuel):0,valeurInitiale:b.valeurInitiale!==undefined?Number(b.valeurInitiale):undefined,budget:b.budget!==undefined?Number(b.budget):undefined}})} objectifUpdate(id:string,b:any){return this.db.objectifQhse.update({where:{id},data:{...b,...(b.cible!==undefined?{cible:Number(b.cible)}:{}),...(b.actuel!==undefined?{actuel:Number(b.actuel)}:{}),...(b.valeurInitiale!==undefined?{valeurInitiale:Number(b.valeurInitiale)}:{}),...(b.budget!==undefined?{budget:Number(b.budget)}:{})}})} objectifDelete(id:string){return this.db.objectifQhse.delete({where:{id}})}
 workedHoursList(){return this.db.workedHours.findMany({orderBy:{periodStart:'desc'}})} workedHoursCreate(b:any){return this.db.workedHours.create({data:{...b,hours:Number(b.hours)}})} workedHoursUpdate(id:string,b:any){return this.db.workedHours.update({where:{id},data:{...b,...(b.hours!==undefined?{hours:Number(b.hours)}:{})}})} workedHoursDelete(id:string){return this.db.workedHours.delete({where:{id}})}
}
