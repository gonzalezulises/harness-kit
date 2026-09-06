import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawn, spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { openRuntime, digestData, canonical } from '../index.mjs';
import { fixture, bytes, sample } from './helpers.mjs';
const ROOT=path.resolve(import.meta.dirname,'../../../../../..');
const sha=b=>createHash('sha256').update(b).digest('hex');
const reordered='threshold: 100\nenabled: true\nstatus: active\ntitle: hello\n';
const commitA='a'.repeat(40),commitB='b'.repeat(40);
function setup(t,options={}) {
  const directory=fs.mkdtempSync(path.join(os.tmpdir(),'h04-'));
  t.after(()=>fs.rmSync(directory,{recursive:true,force:true}));
  const f=fixture(); let final={commit:commitA,documents:[{path:'record.yaml',bytes:bytes(sample)}]},latest=null,reconcile={status:'UNKNOWN',outputDigest:null};
  const journal={directory,objectiveId:'objective-A',journalId:'journal-A',actorId:'supervisor',budgetLimit:2,
    readFinalBinding:()=>final,readLatestWitness:()=>latest,reconcileOperation:()=>reconcile,...options};
  const host={...f.host,issuers:f.host.issuers.map(i=>({...i,kinds:[...i.kinds,'journal-checkpoint','recovery']})),journal};
  const runtime=openRuntime(host);
  function context(r=runtime) {
    const authority=r.loadAuthority(bytes(canonical(f.authority)),f.receipt('policy-adoption',f.authorityDigest));
    const documents=[{path:'record.yaml',bytes:bytes(sample)}];
    return r.verifyContext({authority,documents,acceptance:f.receipt('baseline-acceptance',r.describeBaseline(documents).digest)});
  }
  const ctx=context();
  assert.ok(runtime.journal,'H04 runtime exposes journal when host configures it');
  const j=runtime.journal;
  const start=()=>j.start(ctx,'start');
  const replay=(strong=false)=>j.replay(ctx,{requireWitness:strong});
  function checkpoint(state=replay(),changes={},receiptChanges={}) {
    const value={version:1,repositoryId:'repo-A',objectiveId:'objective-A',journalId:'journal-A',sequence:state.sequence,headDigest:state.headDigest,previousWitnessDigest:latest?digestData(latest.checkpoint):null,authorityDigest:f.authorityDigest,runtimeDigest:state.runtimeDigest,issuedAt:1000,...changes};
    return {checkpoint:value,receipt:f.receipt('journal-checkpoint',digestData(value),{issuedAt:1000,scopeDigest:digestData({objectiveId:'objective-A',journalId:'journal-A'}),...receiptChanges})};
  }
  return {f,j,ctx,runtime,host,context,directory,start,replay,checkpoint,setLatest:v=>{latest=v;},setFinal:v=>{final=v;},setReconcile:v=>{reconcile=v;}};
}
function reserve(s,key='operation',units=1) {
  const state=s.replay();return s.j.appendEvent(state.headDigest,{kind:'reserve',operationKey:key,runId:state.runs.at(-1).runId,units,inputDigest:digestData({key})},s.ctx);
}
test('journal appends exclusively and replay is deterministic local diagnostic',t=>{
  const s=setup(t);assert.equal(s.start().status,'APPENDED');
  assert.deepEqual(s.replay(),s.replay());assert.equal(s.replay().assurance,'LOCAL_UNWITNESSED');
  assert.equal(s.replay(true).status,'BLOCKED_BY_REQUIRED_WITNESS');
  assert.equal(s.replay().budget.spent,0);assert.equal(s.replay().runs[0].verdict,'OPEN');
});
test('idempotency returns original event while changed inputs and stale CAS block',t=>{
  const s=setup(t);s.start();const before=s.replay();const first=reserve(s);
  assert.equal(first.status,'APPENDED');
  const request={kind:'reserve',operationKey:'operation',runId:before.runs[0].runId,units:1,inputDigest:digestData({key:'operation'})};
  assert.deepEqual(s.j.appendEvent(before.headDigest,request,s.ctx),first);
  assert.equal(s.j.appendEvent(before.headDigest,{...request,units:2},s.ctx).status,'POLICY');
  assert.equal(s.j.appendEvent(before.headDigest,{...request,operationKey:'new'},s.ctx).status,'CONFLICT');
});
for(const damage of ['alter','omit','reorder','partial','object']) test(`replay rejects ${damage} damage`,t=>{
  const s=setup(t);s.start();reserve(s);const log=path.join(s.directory,'events.jsonl');const lines=fs.readFileSync(log,'utf8').trimEnd().split('\n');
  if(damage==='alter'){const event=JSON.parse(lines[0]);event.actorId='intruder';lines[0]=canonical(event);}
  if(damage==='omit')lines.shift();
  if(damage==='reorder')lines.reverse();
  if(damage==='partial'){fs.appendFileSync(log,'{"partial":');assert.equal(s.replay().status,'INCOMPLETE');return;}
  if(damage==='object'){const event=JSON.parse(lines[0]);fs.writeFileSync(path.join(s.directory,'objects',event.digest+'.json'),'{}');}
  else fs.writeFileSync(log,lines.join('\n')+'\n');
  assert.equal(s.replay().status,'INCOMPLETE');
});
test('head index is reconstructed from complete log after interrupted publication',t=>{
  const s=setup(t);s.start();const old=s.replay();reserve(s);const current=s.replay();
  fs.writeFileSync(path.join(s.directory,'HEAD'),canonical({sequence:old.sequence,headDigest:old.headDigest}));
  const reopened=openRuntime(s.host),ctx=s.context(reopened);
  assert.deepEqual(reopened.journal.replay(ctx,{}),current);
  assert.equal(JSON.parse(fs.readFileSync(path.join(s.directory,'HEAD'))).headDigest,current.headDigest);
});
test('exclusive existing object is verified before reuse',t=>{
  const s=setup(t);s.start();const state=s.replay();const object=fs.readdirSync(path.join(s.directory,'objects'))[0];
  fs.writeFileSync(path.join(s.directory,'objects',object),'corrupt');
  assert.equal(s.j.appendEvent(state.headDigest,{kind:'reserve',operationKey:'next',runId:state.runs[0].runId,units:1,inputDigest:'a'.repeat(64)},s.ctx).status,'INCOMPLETE');
});
test('an existing ownership lock never expires into permission',t=>{
  const s=setup(t);s.start();fs.writeFileSync(path.join(s.directory,'LOCK'),'stale owner');
  assert.equal(reserve(s).status,'BLOCKED_BY_OWNERSHIP');
  assert.equal(s.replay().sequence,1);
});
test('signed latest checkpoint authenticates exact chain and stale signed prefix is rejected',t=>{
  const s=setup(t);s.start();const old=s.checkpoint();s.setLatest(old);assert.equal(s.replay(true).assurance,'EXTERNALLY_WITNESSED_CURRENT');
  reserve(s);assert.equal(s.replay(true).status,'BLOCKED_BY_WITNESS_MISMATCH');
  const current=s.checkpoint();s.setLatest(current);assert.equal(s.replay(true).status,'REPLAYED');
  s.setLatest(old);assert.equal(s.replay(true).status,'BLOCKED_BY_WITNESS_ROLLBACK');
});
for(const bad of ['signature','repository','runtime','kind','role','head','extra']) test(`checkpoint rejects ${bad}`,t=>{
  const s=setup(t);s.start();let value=s.checkpoint();
  if(bad==='signature')value.receipt.signature='AAAA';
  if(bad==='repository')value=s.checkpoint(undefined,{repositoryId:'elsewhere'});
  if(bad==='runtime')value=s.checkpoint(undefined,{runtimeDigest:'0'.repeat(64)});
  if(bad==='kind')value=s.checkpoint(undefined,{}, {kind:'baseline-acceptance'});
  if(bad==='role')value=s.checkpoint(undefined,{}, {issuerRole:'candidate'});
  if(bad==='head')value=s.checkpoint(undefined,{headDigest:'0'.repeat(64)});
  if(bad==='extra')value.checkpoint.latest=true;
  s.setLatest(value);assert.match(s.replay(true).status,/^BLOCKED/);
});
test('witness is fetched on every strong replay; unavailable freshness does not fall back',t=>{
  let reads=0;const s=setup(t,{readLatestWitness:()=>{reads++;throw Error('offline');}});s.start();
  assert.equal(s.replay(true).status,'BLOCKED_BY_REQUIRED_WITNESS');assert.equal(s.replay(true).status,'BLOCKED_BY_REQUIRED_WITNESS');assert.equal(reads,2);
});
test('fresh mechanical run preserves terminal verdict, acceptance, lineage and objective budget',t=>{
  const s=setup(t);s.start();reserve(s);s.setReconcile({status:'NOT_APPLIED',outputDigest:null});assert.equal(s.j.reconcile(s.replay().headDigest,'operation',s.ctx).status,'APPENDED');
  const old=s.replay().runs[0];assert.equal(s.j.appendEvent(s.replay().headDigest,{kind:'close-run',operationKey:'close',runId:old.runId,verdict:'FAILED'},s.ctx).status,'APPENDED');
  s.setFinal({commit:commitB,documents:[{path:'record.yaml',bytes:bytes(reordered)}]});
  assert.equal(s.j.replaceStaleRun(s.replay().headDigest,old.runId,'fresh',s.ctx).status,'APPENDED');
  const state=s.replay();assert.equal(state.runs[0].verdict,'FAILED');assert.equal(state.runs[1].parentRunId,old.runId);assert.equal(state.budget.spent,1);assert.equal(state.baselineDigest,s.runtime.inspectContext(s.ctx).baselineDigest);
  assert.equal(reserve(s,'operation-2').status,'APPENDED');s.setReconcile({status:'NOT_APPLIED',outputDigest:null});s.j.reconcile(s.replay().headDigest,'operation-2',s.ctx);
  assert.equal(reserve(s,'operation-3').status,'BUDGET_EXHAUSTED');
});
for(const bad of ['semantic','missing','foreign','stale-authority','caller-summary']) test(`fresh run rejects ${bad}`,t=>{
  const s=setup(t);s.start();const state=s.replay();
  s.setFinal({commit:commitB,documents:bad==='missing'?[]:[{path:'record.yaml',bytes:bytes(bad==='semantic'?sample.replace('hello','changed'):reordered)}]});
  if(bad==='stale-authority')s.f.setNow(1600);
  const context=bad==='foreign'?fixture().context():bad==='caller-summary'?s.runtime.inspectContext(s.ctx):s.ctx;
  assert.notEqual(s.j.replaceStaleRun(state.headDigest,state.runs[0].runId,'fresh',context).status,'APPENDED');
});
test('incomplete intent cannot be blindly repeated or resolved by candidate evidence',t=>{
  const s=setup(t);s.start();reserve(s);assert.equal(reserve(s,'second').status,'INCOMPLETE');
  assert.equal(s.j.reconcile(s.replay().headDigest,'operation',s.ctx).status,'INCOMPLETE');assert.equal(s.replay().budget.spent,1);
  assert.equal(s.j.appendEvent(s.replay().headDigest,{kind:'outcome',operationKey:'fake',intentKey:'operation',status:'COMPLETED',outputDigest:'a'.repeat(64)},s.ctx).status,'POLICY');
  s.setReconcile({status:'COMPLETED',outputDigest:'a'.repeat(64)});assert.equal(s.j.reconcile(s.replay().headDigest,'operation',s.ctx).status,'APPENDED');
  assert.equal(s.replay().pending.length,0);assert.equal(s.replay().budget.spent,1);
});
test('closed event contract forbids caller actor, arbitrary PASS and budget configuration',t=>{
  const s=setup(t);s.start();const state=s.replay();
  for(const request of [{kind:'close-run',operationKey:'pass',runId:state.runs[0].runId,verdict:'PASS'},{kind:'reserve',operationKey:'a',runId:state.runs[0].runId,units:1,inputDigest:'a'.repeat(64),actorId:'owner'},{kind:'budget-reset',operationKey:'reset',budgetLimit:99},{kind:'reserve',operationKey:'reconcile:future',runId:state.runs[0].runId,units:1,inputDigest:'a'.repeat(64)}])assert.equal(s.j.appendEvent(state.headDigest,request,s.ctx).status,'POLICY');
  assert.equal(s.replay().sequence,1);
});
test('legacy bytes and receipts are retained without retroactive PASS and projection is read-only',t=>{
  const s=setup(t);s.start();const raw=bytes('{ "features": [{"id":"F01","state":"passing","evidence":["old PASS"]}] }\n');
  assert.equal(s.j.importLegacy(s.replay().headDigest,'legacy',raw,s.ctx).status,'APPENDED');
  const projection=s.j.projectLegacy(s.ctx);assert.equal(projection.writable,false);assert.equal(projection.features[0].state,'blocked');assert.equal(projection.features[0].verificationStatus,'LEGACY_UNVERIFIED');assert.equal(projection.provenance.sourceDigest,sha(raw));
  assert.deepEqual(s.j.readLegacy(s.ctx),raw);assert.equal(projection.runs[0].verdict,'OPEN');
  fs.mkdirSync(path.join(s.directory,'scripts'));fs.copyFileSync(path.join(ROOT,'scripts/verify-feature.sh'),path.join(s.directory,'scripts/verify-feature.sh'));fs.writeFileSync(path.join(s.directory,'feature_list.json'),JSON.stringify(projection));
  const reader=spawnSync('bash',['scripts/verify-feature.sh','--ratio'],{cwd:s.directory,encoding:'utf8'});assert.equal(reader.status,0);assert.match(reader.stdout,/no features activated/);
});
test('adopted v2 marker blocks legacy direct writer before layer effects in source and scaffold',t=>{
  for(const script of ['scripts/verify-feature.sh','templates/full/scripts/verify-feature.sh']){
    const dir=fs.mkdtempSync(path.join(os.tmpdir(),'h04-legacy-'));t.after(()=>fs.rmSync(dir,{recursive:true,force:true}));fs.mkdirSync(path.join(dir,'scripts'));fs.mkdirSync(path.join(dir,'.harness'));fs.copyFileSync(path.join(ROOT,script),path.join(dir,'scripts/verify-feature.sh'));
    const raw=JSON.stringify({features:[{id:'F01',state:'active',verification_layers:[{label:'one',cmd:'touch EFFECT'}]}]});fs.writeFileSync(path.join(dir,'feature_list.json'),raw);fs.writeFileSync(path.join(dir,'.harness/autonomy-v2.json'),'{}');
    const result=spawnSync('bash',['scripts/verify-feature.sh','F01'],{cwd:dir,encoding:'utf8'});assert.equal(result.status,67);assert.match(result.stderr,/v2.*read.only/i);assert.equal(fs.existsSync(path.join(dir,'EFFECT')),false);assert.equal(fs.readFileSync(path.join(dir,'feature_list.json'),'utf8'),raw);
  }
});

test('stale run cannot reserve against changed current workspace bytes',t=>{
  const s=setup(t);s.start();s.setFinal({commit:commitB,documents:[{path:'record.yaml',bytes:bytes(reordered)}]});
  assert.equal(reserve(s).status,'BLOCKED_BY_STALE_RUN');assert.equal(s.replay().budget.spent,0);
});
test('witness publication uses host compare-and-append and verifies returned signed data',t=>{
  let latest=null;
  const s=setup(t,{readLatestWitness:()=>latest,compareAndAppendWitness:(expected,cp)=>{
    assert.equal(expected,latest?digestData(latest.checkpoint):null);
    latest=s.checkpoint(undefined,cp);return latest;
  }});s.start();assert.equal(s.j.publishCheckpoint(s.ctx).assurance,'EXTERNALLY_WITNESSED_CURRENT');
  reserve(s);assert.equal(s.j.publishCheckpoint(s.ctx).assurance,'EXTERNALLY_WITNESSED_CURRENT');
});
test('process crash after durable append retains intent and lock; scoped recovery repairs index',t=>{
  const s=setup(t);s.start();const source=path.resolve(import.meta.dirname,'../index.mjs');
  // The child uses the same real journal code and host fixture signing channel.
  // Patch a Node filesystem call only in the child to terminate at the precise
  // crash boundary: durable event bytes exist, HEAD has not been published.
  const child=`import fs from 'node:fs';import {openRuntime,canonical,digestData} from ${JSON.stringify(source)};import {fixture,bytes,sample} from ${JSON.stringify(path.resolve(import.meta.dirname,'helpers.mjs'))};
const f=fixture();const host={...f.host,journal:{directory:${JSON.stringify(s.directory)},objectiveId:'objective-A',journalId:'journal-A',actorId:'supervisor',budgetLimit:2,readFinalBinding:()=>({commit:'${commitA}',documents:[{path:'record.yaml',bytes:bytes(sample)}]})}};const r=openRuntime(host);const a=r.loadAuthority(bytes(canonical(f.authority)),f.receipt('policy-adoption',f.authorityDigest));const d=[{path:'record.yaml',bytes:bytes(sample)}];const c=r.verifyContext({authority:a,documents:d,acceptance:f.receipt('baseline-acceptance',r.describeBaseline(d).digest)});const state=r.journal.replay(c,{});const rename=fs.renameSync;fs.renameSync=(from,to)=>{if(to.endsWith('/HEAD'))process.kill(process.pid,'SIGKILL');return rename(from,to);};r.journal.appendEvent(state.headDigest,{kind:'reserve',operationKey:'crashed',runId:state.runs[0].runId,units:1,inputDigest:digestData({request:'crashed'})},c);`;
  const result=spawnSync(process.execPath,['--input-type=module','-e',child],{encoding:'utf8'});assert.equal(result.signal,'SIGKILL');
  assert.equal(s.replay().budget.spent,1);assert.deepEqual(s.replay().pending,['crashed']);assert.equal(reserve(s,'retry').status,'BLOCKED_BY_OWNERSHIP');
  const description=s.j.describeRecovery(s.ctx);assert.equal(description.status,'RECOVERY_DESCRIBED');
  assert.equal(s.j.recoverLock(s.ctx,s.f.receipt('recovery',description.subjectDigest,{scopeDigest:description.scopeDigest})).status,'RECOVERED');
  assert.equal(s.replay().budget.spent,1);assert.equal(reserve(s,'retry').status,'INCOMPLETE');
  s.setReconcile({status:'NOT_APPLIED',outputDigest:null});assert.equal(s.j.reconcile(s.replay().headDigest,'crashed',s.ctx).status,'APPENDED');
});
test('recovery requires scoped approval and does not remove a live owner lock',t=>{
  const s=setup(t);s.start();fs.writeFileSync(path.join(s.directory,'LOCK'),canonical({pid:process.pid,journalId:'journal-A'}));
  const d=s.j.describeRecovery(s.ctx);assert.equal(s.j.recoverLock(s.ctx,{}).status,'BLOCKED_BY_AUTHORITY_MISMATCH');
  assert.equal(s.j.recoverLock(s.ctx,s.f.receipt('recovery',d.subjectDigest,{scopeDigest:d.scopeDigest})).status,'BLOCKED_BY_OWNERSHIP');assert.equal(fs.existsSync(path.join(s.directory,'LOCK')),true);
});

test('two real writers with one expected head publish at most one reservation',async t=>{
  const s=setup(t);s.start();const state=s.replay();
  const prefix=`import fs from 'node:fs';import {openRuntime,canonical,digestData} from ${JSON.stringify(path.resolve(import.meta.dirname,'../index.mjs'))};import {fixture,bytes,sample} from ${JSON.stringify(path.resolve(import.meta.dirname,'helpers.mjs'))};const f=fixture();const r=openRuntime({...f.host,journal:{directory:${JSON.stringify(s.directory)},objectiveId:'objective-A',journalId:'journal-A',actorId:'supervisor',budgetLimit:2,readFinalBinding:()=>({commit:'${commitA}',documents:[{path:'record.yaml',bytes:bytes(sample)}]})}});const a=r.loadAuthority(bytes(canonical(f.authority)),f.receipt('policy-adoption',f.authorityDigest));const documents=[{path:'record.yaml',bytes:bytes(sample)}];const c=r.verifyContext({authority:a,documents,acceptance:f.receipt('baseline-acceptance',r.describeBaseline(documents).digest)});`;
  const run=key=>new Promise((resolve,reject)=>{const child=spawn(process.execPath,['--input-type=module','-e',prefix+`process.stdout.write(JSON.stringify(r.journal.appendEvent('${state.headDigest}',{kind:'reserve',operationKey:'${key}',runId:'${state.runs[0].runId}',units:1,inputDigest:'${'a'.repeat(64)}'},c)));`]);let out='',err='';child.stdout.on('data',v=>out+=v);child.stderr.on('data',v=>err+=v);child.on('error',reject);child.on('close',code=>{if(code!==0)reject(Error(err));else resolve(JSON.parse(out));});});
  const results=await Promise.all([run('writer-one'),run('writer-two')]);assert.equal(results.filter(r=>r.status==='APPENDED').length,1);assert.ok(results.some(r=>['CONFLICT','BLOCKED_BY_OWNERSHIP'].includes(r.status)));assert.equal(s.replay().budget.spent,1);assert.equal(s.replay().sequence,2);
});
test('terminal verdict cannot be rewritten and an earlier run cannot replace current lineage',t=>{
  const s=setup(t);s.start();const first=s.replay().runs[0];
  assert.equal(s.j.appendEvent(s.replay().headDigest,{kind:'close-run',operationKey:'terminal',runId:first.runId,verdict:'FAILED'},s.ctx).status,'APPENDED');
  assert.equal(s.j.appendEvent(s.replay().headDigest,{kind:'close-run',operationKey:'rewrite',runId:first.runId,verdict:'STALE'},s.ctx).status,'POLICY');
  s.setFinal({commit:commitB,documents:[{path:'record.yaml',bytes:bytes(reordered)}]});s.j.replaceStaleRun(s.replay().headDigest,first.runId,'fresh',s.ctx);
  assert.equal(s.j.replaceStaleRun(s.replay().headDigest,first.runId,'fork',s.ctx).status,'POLICY');assert.equal(s.replay().runs[0].verdict,'FAILED');
});
