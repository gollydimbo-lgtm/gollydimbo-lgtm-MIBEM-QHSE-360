import {PrismaClient,RoleName,EpiFrequency} from '@prisma/client';
import * as bcrypt from 'bcrypt';
const db=new PrismaClient();
async function main(){
 const perms=['users.read','documents.read','documents.write','epi.read','epi.write','epi.stock','qhs.generate','audit.read','sync.push','sync.pull','quality.read','quality.write','quality.submit','quality.template'];
 for(const code of perms) await db.permission.upsert({where:{code},update:{},create:{code}});
 for(const name of Object.values(RoleName)) await db.role.upsert({where:{name},update:{},create:{name}});
 const admin=await db.role.findUnique({where:{name:RoleName.ADMINISTRATEUR}}); const ps=await db.permission.findMany();
 if(admin) for(const p of ps) await db.rolePermission.upsert({where:{roleId_permissionId:{roleId:admin.id,permissionId:p.id}},update:{},create:{roleId:admin.id,permissionId:p.id}});
 const hash=await bcrypt.hash('Admin12345!',12);
 const u=await db.user.upsert({where:{email:'admin@qhse.local'},update:{},create:{email:'admin@qhse.local',passwordHash:hash,firstName:'Administrateur',lastName:'QHSE'}});
 if(admin) await db.userRole.upsert({where:{userId_roleId:{userId:u.id,roleId:admin.id}},update:{},create:{userId:u.id,roleId:admin.id}});
 const epi=[['EPI-CHAUSSURE','Chaussures de sécurité',EpiFrequency.ANNUAL],['EPI-TENUE','Tenue de travail',EpiFrequency.ANNUAL],['EPI-LUNETTE','Lunettes de sécurité',EpiFrequency.ANNUAL],['EPI-CASQUE','Casque',EpiFrequency.ANNUAL],['EPI-GANT','Gants',EpiFrequency.DAILY],['EPI-CACHE-NEZ','Cache-nez',EpiFrequency.DAILY],['EPI-CHARLOTTE','Charlotte',EpiFrequency.DAILY]] as const;
 for(const [code,name,frequency] of epi) await db.epi.upsert({where:{code},update:{name,frequency},create:{code,name,frequency,annualValidityDays:frequency===EpiFrequency.ANNUAL?365:null,minStock:10}});
 const site=await db.site.upsert({where:{code:'MIBEM-01'},update:{name:'MIBEM Production'},create:{code:'MIBEM-01',name:'MIBEM Production',location:'Site principal'}});
 const line=await db.productionLine.upsert({where:{code:'LIGNE-01'},update:{name:'Ligne 1',siteId:site.id},create:{code:'LIGNE-01',name:'Ligne 1',siteId:site.id}});
 await db.machine.upsert({where:{code:'MCH-PET-01'},update:{name:'Souffleuse PET',lineId:line.id},create:{code:'MCH-PET-01',name:'Souffleuse PET',lineId:line.id,category:'PET'}});
 await db.machine.upsert({where:{code:'MCH-REMPL-01'},update:{name:'Remplisseuse',lineId:line.id},create:{code:'MCH-REMPL-01',name:'Remplisseuse',lineId:line.id,category:'Remplissage'}});
 const wine=await db.product.upsert({where:{code:'VIN-BOUCHET'},update:{name:'Vin Bouchet'},create:{code:'VIN-BOUCHET',name:'Vin Bouchet',category:'Vin'}});
 await db.productFormat.upsert({where:{productId_code:{productId:wine.id,code:'75CL'}},update:{label:'75 cl',volumeMl:750},create:{productId:wine.id,code:'75CL',label:'75 cl',volumeMl:750}});
 await db.product.upsert({where:{code:'LIQUEUR'},update:{name:'Liqueur'},create:{code:'LIQUEUR',name:'Liqueur',category:'Liqueur'}});
 await db.product.upsert({where:{code:'PET'},update:{name:'PET'},create:{code:'PET',name:'PET',category:'PET'}});
 await db.product.upsert({where:{code:'VIN-BRIQUE'},update:{name:'Vin en brique'},create:{code:'VIN-BRIQUE',name:'Vin en brique',category:'Brique'}});
 for(const [code,name,start,end] of [['MATIN','Quart matin','06:00','14:00'],['SOIR','Quart soir','14:00','22:00'],['NUIT','Quart nuit','22:00','06:00']] as const) await db.shift.upsert({where:{code},update:{name,startTime:start,endTime:end},create:{code,name,startTime:start,endTime:end}});
 await db.controlTemplate.upsert({where:{code:'TPL-CONTROLE-LIGNE'},update:{},create:{code:'TPL-CONTROLE-LIGNE',name:'Contrôle sur les lignes',points:{create:[
   {code:'ETIQUETAGE',label:'Étiquetage conforme',type:'BOOLEAN',required:true,critical:true,order:1},
   {code:'LOT',label:'Numéro de lot conforme',type:'TEXT',required:true,order:2},
   {code:'ASPECT',label:'Aspect du produit conforme',type:'BOOLEAN',required:true,order:3}
 ]}}});
}
main().catch(e=>{console.error(e);process.exit(1)}).finally(()=>db.$disconnect());
