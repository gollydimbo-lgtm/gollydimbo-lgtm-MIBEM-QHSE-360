import { Injectable } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { writeAudit } from '../common/audit-log.helper';
@Injectable() export class BusinessService { constructor(private db:PrismaService){}
 dashboard(){return Promise.all([this.db.nonConformity.count({where:{status:{not:'CLOSED'}}}),this.db.action.count({where:{status:{not:'CLOSED'}}}),this.db.safetyEvent.count(),this.db.risk.count({where:{status:'ACTIVE',score:{gte:9}}}),this.db.qualityControl.count()]).then(([nonConformitiesOpen,actionsOpen,safetyEvents,highRisks,qualityControls])=>({nonConformitiesOpen,actionsOpen,safetyEvents,highRisks,qualityControls}));}
 qualityList(){return this.db.qualityControl.findMany({orderBy:{controlDate:'desc'}})} qualityCreate(b:any){return this.db.qualityControl.create({data:b})} qualityUpdate(id:string,b:any){return this.db.qualityControl.update({where:{id},data:b})} qualityDelete(id:string){return this.db.qualityControl.delete({where:{id}})}
 ncList(status?:string){return this.db.nonConformity.findMany({where:status?{status}:undefined,include:{actions:true,epi:true,epc:true,risk:true},orderBy:{createdAt:'desc'}})} ncCreate(b:any){return this.db.nonConformity.create({data:b})} ncUpdate(id:string,b:any){return this.db.nonConformity.update({where:{id},data:b})} ncDelete(id:string){return this.db.nonConformity.delete({where:{id}})}

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
 actionList(status?:string){return this.db.action.findMany({where:status?{status}:undefined,include:{nonConformity:true},orderBy:{dueDate:'asc'}})} actionCreate(b:any){return this.db.action.create({data:b})} actionUpdate(id:string,b:any){return this.db.action.update({where:{id},data:b})} actionDelete(id:string){return this.db.action.delete({where:{id}})}
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
