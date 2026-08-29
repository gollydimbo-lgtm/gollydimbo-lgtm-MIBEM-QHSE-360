import assert from 'node:assert/strict';
const base=process.env.API_URL||'http://localhost:3000/api/v4';
async function request(path:string,options:RequestInit={}){const r=await fetch(base+path,{headers:{'content-type':'application/json',...(options.headers||{})},...options});const text=await r.text();let body:any;try{body=JSON.parse(text)}catch{body=text}assert.ok(r.ok,`${options.method||'GET'} ${path} -> ${r.status}: ${text}`);return body;}

async function main(){
  const health=await request('/health');assert.equal(health.status,'ok');
  const login=await request('/auth/login',{method:'POST',body:JSON.stringify({email:'admin@qhse.local',password:'Admin12345!'})});assert.ok(login.accessToken);
  const catalogs=await request('/quality/catalogs');const sites=catalogs[0],products=catalogs[1],shifts=catalogs[2],templates=catalogs[3];assert.ok(sites.length&&products.length&&shifts.length&&templates.length);
  const line=sites[0].lines[0],machine=line.machines[0],product=products[0],format=product.formats[0],shift=shifts[0];
  const suffix=Date.now();
  const template=await request('/quality/templates',{method:'POST',body:JSON.stringify({code:`TPL-${suffix}`,name:'Contrôle ligne — test API',points:[{code:'TEMP',label:'Température',type:'NUMERIC',required:true,minValue:0,maxValue:100},{code:'ETIQUETTE',label:'Étiquetage conforme',type:'BOOLEAN',required:true,critical:true}]})});
  const control=await request('/quality/controls',{method:'POST',body:JSON.stringify({code:`CTRL-${suffix}`,siteId:sites[0].id,lineId:line.id,machineId:machine.id,productId:product.id,formatId:format?.id,shiftId:shift.id,lotNumber:`LOT-${suffix}`,templateId:template.id,latitude:5.32,longitude:-4.02})});
  await request(`/quality/controls/${control.id}/results`,{method:'POST',body:JSON.stringify({pointId:template.points[0].id,value:22,compliant:true})});
  await request(`/quality/controls/${control.id}/results`,{method:'POST',body:JSON.stringify({pointId:template.points[1].id,value:false,compliant:false,comment:'Étiquette non conforme'})});
  const submitted=await request(`/quality/controls/${control.id}/submit`,{method:'POST'});assert.equal(submitted.status,'NON_COMPLIANT');
  const detail=await request(`/quality/controls/${control.id}`);assert.equal(detail.nonConformities.length,1);assert.equal(detail.nonConformities[0].actions.length,1);
  console.log('API SMOKE TEST: PASS — Quality control → result → NC → action');
}

main().catch(e=>{console.error('API SMOKE TEST: FAIL');console.error(e);process.exit(1)});
