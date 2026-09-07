import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawn} from 'node:child_process';
import {setTimeout as delay} from 'node:timers/promises';
import {openRuntime,canonical,digestData,installedBundleDigest} from '../index.mjs';
import {fixture,bytes,sample} from './helpers.mjs';
import {sha256} from '../identity.mjs';
import {setup,network,settle,reviewer,deploymentReady,limits,mechanical} from './closure-fixtures.mjs';

function packet(s){
  const d=s.describe('shared-op'),documents=s.host.journal.readFinalBinding().documents;
  assert.equal(d.status,'EXECUTION_DESCRIBED',d.reason);
  const value={host:{...s.host,issuers:s.host.issuers.map(i=>({...i,publicKey:i.publicKey.export({type:'spki',format:'pem'})}))},commit:s.targetCommit,authority:s.f.authority,adoption:s.f.receipt('policy-adoption',s.f.authorityDigest),acceptance:s.f.receipt('baseline-acceptance',s.r.describeBaseline(documents).digest),documents:documents.map(d=>({path:d.path,bytesBase64:d.bytes.toString('base64')})),objectiveWire:{objective:s.objective,approval:s.f.receipt('bounded-grant',digestData(s.objective),{scopeDigest:digestData(s.objective.scope)})},wire:s.wire(d)};
  const file=path.join(s.directory,'packet.json');fs.writeFileSync(file,JSON.stringify(value));return file;
}
function worker(t,file,label,mode){
  const child=spawn(process.execPath,[path.join(import.meta.dirname,'closure-process-worker.mjs'),file,label,mode],{stdio:['ignore','pipe','pipe']});
  let output='';child.stdout.on('data',b=>output+=b);child.stderr.on('data',b=>output+=b);
  const done=new Promise((resolve,reject)=>{child.on('error',reject);child.on('exit',(code,signal)=>resolve({code,signal,output}));});
  t.after(()=>{if(child.exitCode===null)child.kill('SIGKILL');});return {child,done};
}
async function ready(file,child){const deadline=Date.now()+30000;while(!fs.existsSync(file)){if(child.exitCode!==null)throw Error('worker exited before rendezvous');if(Date.now()>deadline)throw Error('rendezvous timeout');await delay(10);}}
const starts=s=>fs.existsSync(path.join(s.directory,'dispatches.jsonl'))?fs.readFileSync(path.join(s.directory,'dispatches.jsonl'),'utf8').trim().split('\n').map(JSON.parse):[];
test('GR01 separate controllers that both saw absence may issue exactly one dispatch',async t=>{
  const s=setup(t),file=packet(s),a=worker(t,file,'a','race'),b=worker(t,file,'b','race');
  await Promise.all([ready(path.join(s.directory,'a.ready'),a.child),ready(path.join(s.directory,'b.ready'),b.child)]);
  assert.notEqual(a.child.pid,b.child.pid);
  fs.writeFileSync(path.join(s.directory,'a.go'),'go');assert.deepEqual(await a.done,{code:0,signal:null,output:''});
  fs.writeFileSync(path.join(s.directory,'b.go'),'go');assert.deepEqual(await b.done,{code:0,signal:null,output:''});
  const state=s.r.journal.replay(s.ctx);assert.equal(state.budget.spent,1);assert.deepEqual(state.pending,['shared-op']);
  assert.equal(starts(s).length,1,'one durable debit must never authorize two external starts');
  assert.equal(JSON.parse(fs.readFileSync(path.join(s.directory,'a.result'))).execution,'STARTED');
  assert.notEqual(JSON.parse(fs.readFileSync(path.join(s.directory,'b.result'))).execution,'STARTED');
});
test('GR01 owner death after durable intent before POST stays uncertain on original-key resume',async t=>{
  const s=setup(t),file=packet(s),first=worker(t,file,'crash','crash');assert.equal((await first.done).code,73);
  const second=worker(t,file,'resume','resume');assert.deepEqual(await second.done,{code:0,signal:null,output:''});
  assert.equal(starts(s).length,0);const state=s.r.journal.replay(s.ctx);assert.equal(state.budget.spent,1);assert.deepEqual(state.pending,['shared-op']);
  assert.equal(JSON.parse(fs.readFileSync(path.join(s.directory,'resume.result'))).status,'INCOMPLETE');
});
function noStart(s,net,before,result){
  assert.notEqual(result.status,'EXECUTION_PENDING','expired operation authority must not start work');
  assert.equal(net.dispatches(),before.dispatches);const state=s.r.journal.replay(s.ctx);assert.equal(state.budget.spent,before.spent);assert.deepEqual(state.pending,[]);
}
const before=(s,net)=>({spent:s.r.journal.replay(s.ctx).budget.spent,dispatches:net.dispatches()});
function approval(s,action,expiresAt,details){const d=s.r.describeReleaseApproval(s.handle,action,details);assert.equal(d.status,'RELEASE_APPROVAL_DESCRIBED',d.reason);return s.f.receipt(d.kind,d.subjectDigest,{scopeDigest:d.scopeDigest,issuedAt:1000,expiresAt});}
for(const action of ['deploy','rollback','accept-artifact','readback'])test('GR02 '+action+' approval expiring in asynchronous preflight blocks reservation',async t=>{
  const s=setup(t,{reviewEnabled:true}),options={},net=network(t,s,options);let args;
  if(action==='accept-artifact'){
    await settle(s,'slice-op');await settle(s,'merge-op');await settle(s,'verify-op');await settle(s,'review-op',await reviewer(s));
    args={actionApproval:approval(s,action,1010)};
  }else {
    const deployApproval=await deploymentReady(s);
    if(action==='deploy')args={actionApproval:approval(s,action,1010)};
    else {
      if(action==='readback')options.output={result:'FAIL'};
      await settle(s,'deploy-op',{actionApproval:deployApproval});delete options.output;
      if(action==='rollback'){const rollback={deploymentId:'deploy-1',previousDeploymentId:'deploy-0'};args={rollback,actionApproval:approval(s,action,1010,rollback)};}
      else args={actionApproval:approval(s,action,1010,{operationKey:'deploy-op'})};
    }
  }
  const d=s.r.describeReleaseExecution(s.handle,{operationKey:'expiry-op',limits,...args});assert.equal(d.status,'EXECUTION_DESCRIBED',d.reason);
  const wire=s.wire(d),prior=before(s,net);assert.equal(wire.approval.expiresAt,1500);
  options.afterPreflight=()=>s.f.setNow(1010);
  noStart(s,net,prior,await s.r.executeReleaseObligation(s.handle,wire));
});
test('GR02 release objective expiry alone during preflight blocks reservation',async t=>{
  const s=setup(t),options={},net=network(t,s,options);
  const handle=s.r.bindReleaseObjective({objective:s.objective,approval:s.f.receipt('bounded-grant',digestData(s.objective),{scopeDigest:digestData(s.objective.scope),expiresAt:1010})},s.ctx);
  const d=s.r.describeReleaseExecution(handle,{operationKey:'objective-expiry',limits});assert.equal(d.status,'EXECUTION_DESCRIBED');
  const prior=before(s,net);options.afterPreflight=()=>s.f.setNow(1010);
  noStart(s,net,prior,await s.r.executeReleaseObligation(handle,s.wire(d)));
});
for(const release of [false,true])test('GR02 '+(release?'release':'standalone')+' review policy expiry alone during preflight blocks reservation',async t=>{
  const s=setup(t,{reviewEnabled:true}),options={},net=network(t,s,options);
  if(release){await settle(s,'slice-op');await settle(s,'merge-op');await settle(s,'verify-op');}
  const review=await reviewer(s,{expiresAt:1010});
  const d=release?s.r.describeReleaseExecution(s.handle,{operationKey:'review-op',limits,...review}):s.r.describeReviewExecution(review.reviewBinding,review.reviewShadow,{limits});assert.equal(d.status,'EXECUTION_DESCRIBED',d.reason);
  const prior=before(s,net),wire=s.wire(d);assert.equal(wire.approval.expiresAt,1500);options.afterPreflight=()=>s.f.setNow(1010);
  noStart(s,net,prior,await (release?s.r.executeReleaseObligation(s.handle,wire):s.r.reviewRun(review.reviewBinding,review.reviewShadow,wire)));
});
test('GR02 prerequisite slice evidence expires in preflight while objective and budgets remain current',async t=>{
  const s=setup(t),options={expiresAt:{slice:1010}},net=network(t,s,options);await settle(s,'slice-op');
  const d=s.describe('merge-op');assert.equal(d.request.operation,'merge');const prior=before(s,net),wire=s.wire(d);
  options.afterPreflight=()=>s.f.setNow(1010);noStart(s,net,prior,await s.r.executeReleaseObligation(s.handle,wire));
  assert.equal(s.r.nextObligation(s.handle,s.r.replayRelease(s.handle)).nextObligation.kind,'verify-slice');
});
for(const id of ['canonical-write.v1','derived-write.v1'])test('GR04 '+id+' preserves literal output keys and verifies changed bytes, exact scope and one debit',t=>{
  const dir=fs.mkdtempSync(path.join(os.tmpdir(),'literal-output-'));t.after(()=>fs.rmSync(dir,{recursive:true,force:true}));const root=path.join(dir,'workspace');fs.mkdirSync(root);
  const literal='__proto__',names=id==='canonical-write.v1'?[literal,'policy.yaml']:['record.yaml',literal,'policy.yaml'];
  const files=names.map(name=>({path:name,schemaId:name===literal&&id==='derived-write.v1'?'digest.v1':'record.v1',class:name==='policy.yaml'?'normative':name===literal&&id==='derived-write.v1'?'derived':'data'}));
  for(const file of files)fs.writeFileSync(path.join(root,file.path),file.schemaId==='digest.v1'?canonical({sourcePath:'record.yaml',sourceContentSha256:sha256(sample)}):sample);
  const f=fixture({files,authorityOverrides:{scope:{paths:names}}}),documents=names.map(name=>({path:name,bytes:fs.readFileSync(path.join(root,name))}));
  const host={...f.host,journal:{directory:path.join(dir,'state'),objectiveId:'o',journalId:'j',actorId:'supervisor',budgetLimit:3,readFinalBinding:()=>({commit:'a'.repeat(40),documents:names.map(name=>({path:name,bytes:fs.readFileSync(path.join(root,name))}))})},capabilities:{workspace:root,writablePaths:names.filter(p=>p!=='policy.yaml'),denyPaths:['policy.yaml'],bundleDigest:installedBundleDigest(),mode:'TRUSTED_RUNTIME_EXCLUSIVE'}};
  const r=openRuntime(host);assert.equal(r.status,undefined,r.reason);const ctx=r.verifyContext({authority:r.loadAuthority(bytes(canonical(f.authority)),f.receipt('policy-adoption',f.authorityDigest)),documents,acceptance:f.receipt('baseline-acceptance',r.describeBaseline(documents).digest)});assert.equal(r.journal.start(ctx,'start').status,'APPENDED');
  const args={path:literal,operationKey:'literal',...(id==='derived-write.v1'?{sourcePath:'record.yaml'}:{})},d=r.describeCapability(id,args,ctx);assert.equal(d.status,'CAPABILITY_DESCRIBED',d.reason);
  const permit=r.prepareCapability(id,args,ctx,f.receipt('bounded-grant',d.subjectDigest,{scopeDigest:d.scopeDigest})),lease=r.acquireLease(ctx),result=r.executeCapability(permit,lease);
  assert.equal(result.status,'EFFECT_VERIFIED',result.reason);
  const expected='enabled: true\nstatus: "active"\nthreshold: 100\ntitle: "hello"\n';
  if(id==='canonical-write.v1')assert.equal(fs.readFileSync(path.join(root,literal),'utf8'),expected,'literal output must actually be canonicalized');
  else {assert.equal(fs.readFileSync(path.join(root,'record.yaml'),'utf8'),expected);assert.deepEqual(JSON.parse(fs.readFileSync(path.join(root,literal))),{sourcePath:'record.yaml',sourceContentSha256:sha256(expected)});}
  const outputs=id==='canonical-write.v1'?[literal]:[literal,'record.yaml'];assert.deepEqual(d.outputs,outputs);assert.deepEqual(result.delta,outputs);assert.equal(result.postconditions,'VERIFIED');assert.notEqual(result.preManifestDigest,result.postManifestDigest);
  assert.equal(fs.readFileSync(path.join(root,'policy.yaml'),'utf8'),sample);assert.deepEqual(fs.readdirSync(root).sort(),names.sort());const state=r.journal.replay(ctx);assert.equal(state.budget.spent,1);assert.equal(state.budget.byKind[mechanical],1);assert.deepEqual(state.pending,[]);r.releaseLease(lease);
});
