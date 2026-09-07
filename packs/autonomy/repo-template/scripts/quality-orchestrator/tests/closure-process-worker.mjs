// Local cooperating-controller fixture. No real HTTPS request is permitted.
import fs from 'node:fs';
import path from 'node:path';
import https from 'node:https';
import {createPublicKey} from 'node:crypto';
import {openRuntime,canonical,digestData} from '../index.mjs';
import {network,limits} from './closure-fixtures.mjs';
const [packetFile,label,mode='race']=process.argv.slice(2),packet=JSON.parse(fs.readFileSync(packetFile,'utf8'));
const documents=packet.documents.map(d=>({path:d.path,bytes:Buffer.from(d.bytesBase64,'base64')}));
const host={...packet.host,now:()=>1000,issuers:packet.host.issuers.map(i=>({...i,publicKey:createPublicKey(i.publicKey)})),journal:{...packet.host.journal,readFinalBinding:()=>({commit:packet.commit,documents})}};
const r=openRuntime(host);if(r.status)throw Error(r.reason);
const ctx=r.verifyContext({authority:r.loadAuthority(Buffer.from(canonical(packet.authority)),packet.adoption),documents,acceptance:packet.acceptance});
const handle=r.bindReleaseObjective(packet.objectiveWire,ctx);
const described=r.describeReleaseExecution(handle,{operationKey:packet.wire.budget.scope.operationKey,limits});
if(mode!=='resume'&&described.status!=='EXECUTION_DESCRIBED')throw Error(described.reason);
const control=path.dirname(packetFile),realOpen=fs.openSync;
const {token,...profile}=host.actions;
const descriptor={version:1,domain:'harness.execution-descriptor.v1',operationKey:packet.wire.budget.scope.operationKey,profile,request:packet.wire.request,budget:packet.wire.budget,approval:packet.wire.approval};
// Select the descriptor using its domain from the schema, not an assumed digest.
const {executionDomain}=await import('../execution.schema.mjs');descriptor.domain=executionDomain;
const descriptorFile=path.join(host.journal.directory,'objects',digestData(descriptor)+'.json');
if(mode==='race')fs.openSync=(file,flags,...rest)=>{
  if(file===descriptorFile&&flags==='wx'){
    fs.writeFileSync(path.join(control,label+'.ready'),String(process.pid));
    const deadline=Date.now()+30000;
    while(!fs.existsSync(path.join(control,label+'.go'))){if(Date.now()>deadline)throw Error('coordination timeout');Atomics.wait(new Int32Array(new SharedArrayBuffer(4)),0,0,10);}
  }
  return realOpen(file,flags,...rest);
};
network({mock:{method:(object,key,fn)=>object[key]=fn}},{r,ctx,actions:host.actions},{pending:true});
const fixedMock=https.request;
https.request=(url,...args)=>{
  if(String(url).endsWith('/dispatches')){
    if(mode==='crash')process.exit(73);
    fs.appendFileSync(path.join(control,'dispatches.jsonl'),JSON.stringify({pid:process.pid,label})+'\n');
  }
  return fixedMock(url,...args);
};
const result=mode==='resume'?await r.resumeReleaseExecution(handle,packet.wire.budget.scope.operationKey):await r.executeReleaseObligation(handle,packet.wire);
fs.openSync=realOpen;
fs.writeFileSync(path.join(control,label+'.result'),JSON.stringify(result));
