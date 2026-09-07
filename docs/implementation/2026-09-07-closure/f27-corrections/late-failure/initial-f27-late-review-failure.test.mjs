import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {setup,state} from './f27-corrections-fixture.mjs';
import {canonical,digestData} from '../index.mjs';
const scenarios=[
 {code:'serverOverloaded',mode:'resume',allowed:true,retries:2},
 {code:'internalServerError',mode:'run',allowed:true,retries:2},
 {code:'cyberPolicy',mode:'resume',allowed:false,retries:2},
 {code:'serverOverloaded',mode:'resume',allowed:false,retries:0},
];
for(const scenario of scenarios)test('F27 M3/M4 late '+scenario.code+' via '+scenario.mode+' with retry allowance '+scenario.retries+' reconciles only original evidence then '+(scenario.allowed?'continues':'stays blocked'),async t=>{
 const f=setup(t,{turnError:{message:'synthetic settled cause',codexErrorInfo:scenario.code},retries:scenario.retries});await f.runtime.runProduct(f.handle,{maxSteps:4});assert.equal(state(f).stage,'INDEPENDENT_REVIEW');
 const open=fs.openSync,close=fs.closeSync;let ackFd,ackPath,hidden;
 fs.openSync=function(file,flags,...args){const fd=open.call(this,file,flags,...args);if(flags==='wx'&&String(file).includes('/ack-')){ackFd=fd;ackPath=String(file);}return fd;};
 fs.closeSync=function(fd){const result=close.call(this,fd);if(fd===ackFd){ackFd=undefined;hidden=ackPath+'.late';fs.renameSync(ackPath,hidden);}return result;};
 try{await f.runtime.executeProductStep(f.handle,'review:full');}finally{fs.openSync=open;fs.closeSync=close;}
 assert.ok(hidden&&fs.existsSync(hidden),'retain the actual original acknowledgement outside visibility');assert.equal(state(f).pending.key,'review:full');
 assert.equal((await f.runtime.resumeProductStep(f.handle,'review:full')).status,'OPERATIONAL_BLOCKED');const before=state(f),spent=f.runtime.journal.replay(f.ctx).budget.spent,events=fs.readFileSync(path.join(f.journal.directory,'events.jsonl'),'utf8');assert.equal(f.count().filter(x=>x.kind==='REVIEW').length,1);fs.renameSync(hidden,ackPath);
 const docs=[{path:'record.yaml',bytes:Buffer.from('title: hello\nstatus: active\nenabled: true\nthreshold: 100\n')}],cfg={host:{...f.host,issuers:f.host.issuers.map(x=>({...x,publicKey:x.publicKey.export({type:'spki',format:'pem'})}))},authority:f.authority,authorityApproval:f.receipt('policy-adoption',f.authorityDigest),baselineApproval:f.receipt('baseline-acceptance',f.runtime.describeBaseline(docs).digest),wire:f.wire,mode:scenario.mode};
 const script=`import {openRuntime,canonical} from ${JSON.stringify(new URL('../index.mjs',import.meta.url).href)};let raw='';for await(const c of process.stdin)raw+=c;const f=JSON.parse(raw),documents=[{path:'record.yaml',bytes:Buffer.from('title: hello\\nstatus: active\\nenabled: true\\nthreshold: 100\\n')}],r=openRuntime({...f.host,now:()=>1000,journal:{...f.host.journal,readFinalBinding:()=>({commit:f.wire.objective.baseCommit,documents})}}),authority=r.loadAuthority(Buffer.from(canonical(f.authority)),f.authorityApproval),ctx=r.verifyContext({authority,documents,acceptance:f.baselineApproval}),h=r.bindProductObjective(f.wire,ctx);if(h.status)throw Error(JSON.stringify({h,ctx,authority}));const reconciled=f.mode==='resume'?await r.resumeProductStep(h,'review:full'):await r.runProduct(h,{maxSteps:1}),reconciledSpend=r.journal.replay(ctx).budget.spent,next=await r.runProduct(h,{maxSteps:1});console.log(JSON.stringify({reconciled,reconciledSpend,next,spent:r.journal.replay(ctx).budget.spent,wire:r.journal.replay(ctx).product.wire}));`;
 const child=spawnSync(process.execPath,['--input-type=module','-e',script],{input:JSON.stringify(cfg),encoding:'utf8'});assert.equal(child.status,0,child.stderr);const actual=JSON.parse(child.stdout);
 assert.equal(actual.reconciled.stage,scenario.allowed?'INDEPENDENT_REVIEW':'OPERATIONAL_BLOCKED',JSON.stringify(actual.reconciled));assert.equal(actual.reconciled.pending,null);assert.equal(actual.reconciled.counters.starts,before.counters.starts,'late reconciliation itself may not reserve a new attempt');assert.equal(actual.reconciledSpend,spent);assert.equal(actual.reconciled.counters.fullReview,0);assert.equal(actual.reconciled.tooling.retries['review:full']||0,scenario.code==='cyberPolicy'?0:1);assert.deepEqual(actual.wire,f.wire);assert.ok(fs.readFileSync(path.join(f.journal.directory,'events.jsonl'),'utf8').startsWith(events));
 if(scenario.allowed){assert.equal(actual.next.status,'PRODUCT_REPLAYED');assert.equal(actual.next.counters.fullReview,1);assert.equal(actual.next.ingestions[0].key,'review:full:tool:1');assert.equal(actual.spent,spent+1);assert.equal(f.count().filter(x=>x.kind==='REVIEW').length,2);}else{assert.equal(actual.next.status,'OPERATIONAL_BLOCKED');assert.equal(actual.next.interruption.classification,scenario.code==='cyberPolicy'?'OPERATIONAL_DIAGNOSIS':'AUTO_REMEDIABLE');assert.equal(actual.spent,spent);assert.equal(f.count().filter(x=>x.kind==='REVIEW').length,1);}
});
