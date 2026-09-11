import { Injectable } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
@Injectable() export class BusinessService { constructor(private db:PrismaService){}
 dashboard(){return Promise.all([this.db.nonConformity.count({where:{status:{not:'CLOSED'}}}),this.db.action.count({where:{status:{not:'CLOSED'}}}),this.db.safetyEvent.count(),this.db.risk.count({where:{status:'ACTIVE',score:{gte:9}}}),this.db.qualityControl.count()]).then(([nonConformitiesOpen,actionsOpen,safetyEvents,highRisks,qualityControls])=>({nonConformitiesOpen,actionsOpen,safetyEvents,highRisks,qualityControls}));}
 qualityList(){return this.db.qualityControl.findMany({orderBy:{controlDate:'desc'}})} qualityCreate(b:any){return this.db.qualityControl.create({data:b})} qualityUpdate(id:string,b:any){return this.db.qualityControl.update({where:{id},data:b})} qualityDelete(id:string){return this.db.qualityControl.delete({where:{id}})}
 ncList(status?:string){return this.db.nonConformity.findMany({where:status?{status}:undefined,include:{actions:true,epi:true,epc:true},orderBy:{createdAt:'desc'}})} ncCreate(b:any){return this.db.nonConformity.create({data:b})} ncUpdate(id:string,b:any){return this.db.nonConformity.update({where:{id},data:b})} ncDelete(id:string){return this.db.nonConformity.delete({where:{id}})}
 actionList(status?:string){return this.db.action.findMany({where:status?{status}:undefined,include:{nonConformity:true},orderBy:{dueDate:'asc'}})} actionCreate(b:any){return this.db.action.create({data:b})} actionUpdate(id:string,b:any){return this.db.action.update({where:{id},data:b})} actionDelete(id:string){return this.db.action.delete({where:{id}})}
 riskList(){return this.db.risk.findMany({orderBy:{score:'desc'}})} riskCreate(b:any){return this.db.risk.create({data:{...b,score:Number(b.severity)*Number(b.probability)*Number(b.control||1)}})} riskUpdate(id:string,b:any){const score=b.severity&&b.probability?Number(b.severity)*Number(b.probability)*Number(b.control||1):undefined;return this.db.risk.update({where:{id},data:{...b,...(score?{score}:{})}})} riskDelete(id:string){return this.db.risk.delete({where:{id}})}
 haccpList(){return this.db.haccpRecord.findMany({orderBy:{recordDate:'desc'}})} haccpCreate(b:any){return this.db.haccpRecord.create({data:b})} haccpUpdate(id:string,b:any){return this.db.haccpRecord.update({where:{id},data:b})} haccpDelete(id:string){return this.db.haccpRecord.delete({where:{id}})}
 auditList(){return this.db.qhseAudit.findMany({include:{auditor:true,processus:true,auditFindings:{include:{nonConformity:true}}},orderBy:{auditDate:'desc'}})} auditCreate(b:any){return this.db.qhseAudit.create({data:b})} auditUpdate(id:string,b:any){return this.db.qhseAudit.update({where:{id},data:b})} auditDelete(id:string){return this.db.qhseAudit.delete({where:{id}})}

 auditFindingCreate(auditId:string,b:any){return this.db.auditFinding.create({data:{auditId,description:b.description,classification:b.classification,critical:!!b.critical}})}
 auditFindingUpdate(id:string,b:any){return this.db.auditFinding.update({where:{id},data:{description:b.description,classification:b.classification,critical:b.critical,status:b.status}})}
 auditFindingDelete(id:string){return this.db.auditFinding.delete({where:{id}})}
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
 envList(){return this.db.environmentRecord.findMany({orderBy:{recordedAt:'desc'}})} envCreate(b:any){return this.db.environmentRecord.create({data:b})} envUpdate(id:string,b:any){return this.db.environmentRecord.update({where:{id},data:b})} envDelete(id:string){return this.db.environmentRecord.delete({where:{id}})}
 trainingList(){return this.db.training.findMany({include:{processus:true},orderBy:{scheduledAt:'desc'}})} trainingCreate(b:any){return this.db.training.create({data:b})} trainingUpdate(id:string,b:any){return this.db.training.update({where:{id},data:b})} trainingDelete(id:string){return this.db.training.delete({where:{id}})}
 equipmentList(){return this.db.equipment.findMany({orderBy:{name:'asc'}})} equipmentCreate(b:any){return this.db.equipment.create({data:b})} equipmentUpdate(id:string,b:any){return this.db.equipment.update({where:{id},data:b})} equipmentDelete(id:string){return this.db.equipment.delete({where:{id}})}
 events(){return this.db.safetyEvent.findMany({orderBy:{occurredAt:'desc'}})} eventCreate(b:any){return this.db.safetyEvent.create({data:b})} eventUpdate(id:string,b:any){return this.db.safetyEvent.update({where:{id},data:b})} eventDelete(id:string){return this.db.safetyEvent.delete({where:{id}})}
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
 indicateurList(){return this.db.indicateurQualite.findMany({include:{processus:true,mesures:{orderBy:{periode:'desc'},take:12}},orderBy:{createdAt:'desc'}})} indicateurCreate(b:any){return this.db.indicateurQualite.create({data:{...b,actuel:Number(b.actuel),cible:Number(b.cible),seuilVert:b.seuilVert!==undefined?Number(b.seuilVert):undefined,seuilOrange:b.seuilOrange!==undefined?Number(b.seuilOrange):undefined}})} indicateurUpdate(id:string,b:any){return this.db.indicateurQualite.update({where:{id},data:{...b,...(b.actuel!==undefined?{actuel:Number(b.actuel)}:{}),...(b.cible!==undefined?{cible:Number(b.cible)}:{}),...(b.seuilVert!==undefined?{seuilVert:Number(b.seuilVert)}:{}),...(b.seuilOrange!==undefined?{seuilOrange:Number(b.seuilOrange)}:{})}})} indicateurDelete(id:string){return this.db.indicateurQualite.delete({where:{id}})}

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
 fournisseurList(){return this.db.fournisseur.findMany({orderBy:{nom:'asc'}})} fournisseurCreate(b:any){return this.db.fournisseur.create({data:b})} fournisseurUpdate(id:string,b:any){return this.db.fournisseur.update({where:{id},data:b})} fournisseurDelete(id:string){return this.db.fournisseur.delete({where:{id}})}
 visiteMedicaleList(){return this.db.visiteMedicale.findMany({orderBy:{prochaineVisite:'asc'}})} visiteMedicaleCreate(b:any){return this.db.visiteMedicale.create({data:b})} visiteMedicaleUpdate(id:string,b:any){return this.db.visiteMedicale.update({where:{id},data:b})} visiteMedicaleDelete(id:string){return this.db.visiteMedicale.delete({where:{id}})}
 veilleList(){return this.db.veilleReglementaire.findMany({orderBy:{dateApplication:'asc'}})} veilleCreate(b:any){return this.db.veilleReglementaire.create({data:b})} veilleUpdate(id:string,b:any){return this.db.veilleReglementaire.update({where:{id},data:b})} veilleDelete(id:string){return this.db.veilleReglementaire.delete({where:{id}})}
 objectifList(){return this.db.objectifQhse.findMany({orderBy:{createdAt:'desc'}})} objectifCreate(b:any){return this.db.objectifQhse.create({data:{...b,cible:Number(b.cible),actuel:b.actuel!==undefined?Number(b.actuel):0}})} objectifUpdate(id:string,b:any){return this.db.objectifQhse.update({where:{id},data:{...b,...(b.cible!==undefined?{cible:Number(b.cible)}:{}),...(b.actuel!==undefined?{actuel:Number(b.actuel)}:{})}})} objectifDelete(id:string){return this.db.objectifQhse.delete({where:{id}})}
 workedHoursList(){return this.db.workedHours.findMany({orderBy:{periodStart:'desc'}})} workedHoursCreate(b:any){return this.db.workedHours.create({data:{...b,hours:Number(b.hours)}})} workedHoursUpdate(id:string,b:any){return this.db.workedHours.update({where:{id},data:{...b,...(b.hours!==undefined?{hours:Number(b.hours)}:{})}})} workedHoursDelete(id:string){return this.db.workedHours.delete({where:{id}})}
}
