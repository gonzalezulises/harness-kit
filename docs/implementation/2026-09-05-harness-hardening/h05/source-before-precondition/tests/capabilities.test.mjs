import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { createHash } from 'node:crypto';
import * as api from '../index.mjs';
import { fixture, bytes, sample } from './helpers.mjs';
const {openRuntime,canonical,digestData}=api;
const sha=b=>createHash('sha256').update(b).digest('hex');
function setup(t,options={}) {
  const dir=fs.mkdtempSync(path.join(os.tmpdir(),'h05-'));t.after(()=>fs.rmSync(dir,{recursive:true,force:true}));
  const root=path.join(dir,'workspace');fs.mkdirSync(root);fs.writeFileSync(path.join(root,'record.yaml'),sample);
  fs.writeFileSync(path.join(root,'digest.yaml'),canonical({sourcePath:'record.yaml',sourceContentSha256:sha(sample)}));
  fs.writeFileSync(path.join(root,'policy.yaml'),sample);
  const f=fixture();const documents=(options.onlySource?['record.yaml','policy.yaml']:['record.yaml','digest.yaml','policy.yaml']).map(p=>({path:p,bytes:fs.readFileSync(path.join(root,p))}));
  let commit='a'.repeat(40),latest=null,reconciliation={status:'UNKNOWN',outputDigest:null};
  const host={...f.host,issuers:f.host.issuers.map(i=>({...i,kinds:[...i.kinds,'journal-checkpoint']})),journal:{directory:path.join(dir,'state'),objectiveId:'o',journalId:'j',actorId:'supervisor',budgetLimit:3,readFinalBinding:()=>({commit,documents:documents.map(d=>({path:d.path,bytes:fs.readFileSync(path.join(root,d.path))}))}),readLatestWitness:()=>latest,reconcileOperation:()=>reconciliation,...options.journal},capabilities:{workspace:root,writablePaths:['record.yaml','digest.yaml'],denyPaths:['policy.yaml'],bundleDigest:api.installedBundleDigest?.(),mode:'TRUSTED_RUNTIME_EXCLUSIVE',...options.capabilities}};
  function context(r){const a=r.loadAuthority(bytes(canonical(f.authority)),f.receipt('policy-adoption',f.authorityDigest));return r.verifyContext({authority:a,documents,acceptance:f.receipt('baseline-acceptance',r.describeBaseline(documents).digest)});}
  const r=openRuntime(host);assert.ok(r.journal,'journal configured');const ctx=context(r);r.journal.start(ctx,'start');
  const args={sourcePath:'record.yaml',path:'digest.yaml',operationKey:'write'};
  const describe=(id='derived-write.v1',a=args)=>r.describeCapability(id,a,ctx);
  const prepare=(id='derived-write.v1',a=args)=>{const d=describe(id,a);assert.equal(d.status,'CAPABILITY_DESCRIBED',d.reason);return r.prepareCapability(id,a,ctx,f.receipt('bounded-grant',d.subjectDigest,{scopeDigest:d.scopeDigest}));};
  function checkpoint(state=r.journal.replay(ctx),changes={}){const cp={version:1,repositoryId:'repo-A',objectiveId:'o',journalId:'j',sequence:state.sequence,headDigest:state.headDigest,previousWitnessDigest:latest?digestData(latest.checkpoint):null,authorityDigest:f.authorityDigest,runtimeDigest:state.runtimeDigest,issuedAt:1000,...changes};return {checkpoint:cp,receipt:f.receipt('journal-checkpoint',digestData(cp),{issuedAt:1000,scopeDigest:digestData({objectiveId:'o',journalId:'j'})})};}
  return {r,ctx,f,host,context,root,dir,args,describe,prepare,checkpoint,setLatest:v=>latest=v,setCommit:v=>commit=v,setReconciliation:v=>reconciliation=v};
}
test('H04 maximum accepted key reconciles without widening candidate keys',t=>{
  const s=setup(t),state=s.r.journal.replay(s.ctx),key='x'.repeat(200);
  assert.equal(s.r.journal.appendEvent(state.headDigest,{kind:'reserve',operationKey:key,runId:state.runs[0].runId,units:1,inputDigest:sha('x')},s.ctx).status,'APPENDED');
  s.setReconciliation({status:'NOT_APPLIED',outputDigest:null});assert.equal(s.r.journal.reconcile(s.r.journal.replay(s.ctx).headDigest,key,s.ctx).status,'APPENDED');
  assert.equal(s.r.journal.replay(s.ctx).pending.length,0);
  for(const input of [{operationKey:'x'.repeat(201)},{operationKey:'reconcile:forged'},{operationKey:'forged',effectKind:'local-capability.v1'}])assert.equal(s.r.journal.appendEvent(s.r.journal.replay(s.ctx).headDigest,{kind:'reserve',runId:state.runs[0].runId,units:1,inputDigest:sha('x'),...input},s.ctx).status,'POLICY');
});
test('H04 publication retains verified intermediate B before successor C',t=>{
  let latest;const s=setup(t,{journal:{readLatestWitness:()=>latest,compareAndAppendWitness:(previous,cp)=>{assert.equal(previous,digestData(latest.checkpoint));latest=s.checkpoint(undefined,cp);return latest;}}});
  latest=s.checkpoint();assert.equal(s.r.journal.replay(s.ctx,{requireWitness:true}).status,'REPLAYED');
  const reserve=key=>{const state=s.r.journal.replay(s.ctx);return s.r.journal.appendEvent(state.headDigest,{kind:'reserve',operationKey:key,runId:state.runs[0].runId,units:1,inputDigest:sha(key)},s.ctx);};
  reserve('one');latest=s.checkpoint(undefined,{previousWitnessDigest:digestData(latest.checkpoint)});
  s.setReconciliation({status:'NOT_APPLIED',outputDigest:null});s.r.journal.reconcile(s.r.journal.replay(s.ctx).headDigest,'one',s.ctx);
  assert.equal(s.r.journal.publishCheckpoint(s.ctx).assurance,'EXTERNALLY_WITNESSED_CURRENT');
});
test('e2e: public capability writes canonical source and derived digest with persistent exact receipt',t=>{
  const s=setup(t);assert.equal(typeof s.r.prepareCapability,'function');const permit=s.prepare(),lease=s.r.acquireLease(s.ctx);
  const result=s.r.executeCapability(permit,lease);assert.equal(result.status,'EFFECT_VERIFIED',result.reason);assert.equal(result.postconditions,'VERIFIED');assert.equal(result.assurance,'TRUSTED_RUNTIME_EXCLUSIVE');
  const source=fs.readFileSync(path.join(s.root,'record.yaml'));const derived=JSON.parse(fs.readFileSync(path.join(s.root,'digest.yaml')));assert.equal(derived.sourceContentSha256,sha(source));assert.deepEqual(result.delta,['digest.yaml','record.yaml']);
  assert.equal(s.r.journal.replay(s.ctx).budget.spent,1);assert.deepEqual(s.r.journal.replay(s.ctx).pending,[]);assert.deepEqual(s.r.executeCapability(permit,lease),result);
  assert.equal(s.r.releaseLease(lease).status,'LEASE_RELEASED');
  const reopened=openRuntime(s.host),ctx=s.context(reopened),next=reopened.acquireLease(ctx);assert.deepEqual(reopened.reconcileCapability('write',ctx,next),result);reopened.releaseLease(next);
});
test('canonical write uses exact numeric lexemes and preserves accepted semantics',t=>{
  const s=setup(t,{onlySource:true}),permit=s.prepare('canonical-write.v1',{path:'record.yaml',operationKey:'canonical'}),lease=s.r.acquireLease(s.ctx);
  assert.equal(s.r.executeCapability(permit,lease).status,'EFFECT_VERIFIED');assert.match(fs.readFileSync(path.join(s.root,'record.yaml'),'utf8'),/threshold: 100\n/);s.r.releaseLease(lease);
});
for(const bad of ['traversal','deny','symlink','hardlink','extra','callback'])test(`capability rejects ${bad} before mutation`,t=>{
  const s=setup(t);let args={...s.args};
  if(bad==='traversal')args.path='../outside';if(bad==='deny')args.path='policy.yaml';
  if(bad==='symlink'){fs.unlinkSync(path.join(s.root,'digest.yaml'));fs.symlinkSync('policy.yaml',path.join(s.root,'digest.yaml'));}
  if(bad==='hardlink'){fs.unlinkSync(path.join(s.root,'digest.yaml'));fs.linkSync(path.join(s.root,'policy.yaml'),path.join(s.root,'digest.yaml'));}
  if(bad==='extra')args.command='touch escape';if(bad==='callback')args.verify=()=>true;
  assert.notEqual(s.describe('derived-write.v1',args).status,'CAPABILITY_DESCRIBED');assert.equal(s.r.journal.replay(s.ctx).budget.spent,0);
});
test('deny wins even when host allowlist overlaps',t=>{const s=setup(t,{capabilities:{denyPaths:['record.yaml']}});assert.equal(s.describe().status,'POLICY');});
test('forged context, grant, permit and lease never confer execution authority',t=>{
  const s=setup(t);assert.notEqual(s.r.describeCapability('derived-write.v1',s.args,{}).status,'CAPABILITY_DESCRIBED');assert.notEqual(s.r.prepareCapability('derived-write.v1',s.args,s.ctx,{}).status,'PERMIT');
  const permit=s.prepare(),lease=s.r.acquireLease(s.ctx);assert.notEqual(s.r.executeCapability({},lease).status,'EFFECT_VERIFIED');assert.notEqual(s.r.executeCapability(permit,{}).status,'EFFECT_VERIFIED');s.r.releaseLease(lease);
});
for(const change of ['source','frozen','commit','alias','mode'])test(`execute rechecks ${change} after prepare`,t=>{
  const s=setup(t),permit=s.prepare(),lease=s.r.acquireLease(s.ctx);
  if(change==='source')fs.writeFileSync(path.join(s.root,'record.yaml'),sample.replace('hello','changed'));
  if(change==='frozen')fs.writeFileSync(path.join(s.root,'policy.yaml'),'changed');
  if(change==='commit')s.setCommit('b'.repeat(40));
  if(change==='alias'){fs.unlinkSync(path.join(s.root,'digest.yaml'));fs.symlinkSync('policy.yaml',path.join(s.root,'digest.yaml'));}
  if(change==='mode')fs.chmodSync(path.join(s.root,'record.yaml'),0o777);
  assert.notEqual(s.r.executeCapability(permit,lease).status,'EFFECT_VERIFIED');assert.equal(s.r.journal.replay(s.ctx).budget.spent,0);s.r.releaseLease(lease);
});
test('exclusive leases reject second owner and stale handles after release',t=>{
  const s=setup(t),p=s.prepare(),first=s.r.acquireLease(s.ctx);assert.equal(s.r.acquireLease(s.ctx).status,'BLOCKED_BY_OWNERSHIP');
  const other=openRuntime(s.host);assert.equal(other.acquireLease(s.context(other)).status,'BLOCKED_BY_OWNERSHIP');s.r.releaseLease(first);
  const second=s.r.acquireLease(s.ctx);assert.notEqual(s.r.executeCapability(p,first).status,'EFFECT_VERIFIED');assert.equal(s.r.executeCapability(p,second).status,'EFFECT_VERIFIED');s.r.releaseLease(second);
});
test('untrusted subprocess capability refuses missing real containment before spawn',t=>{
  const s=setup(t);const result=s.r.describeCapability('subprocess.v1',{cmd:'touch ESCAPE'},s.ctx);assert.equal(result.status,'BLOCKED_BY_REQUIRED_CAPABILITY');assert.equal(result.execution,'NOT_EXECUTED');assert.equal(fs.existsSync(path.join(s.root,'ESCAPE')),false);
});
test('canonical preparation validates dependent frozen documents before any effect',t=>{
  const s=setup(t),before=fs.readFileSync(path.join(s.root,'record.yaml'));
  assert.equal(s.describe('canonical-write.v1',{path:'record.yaml',operationKey:'canonical'}).status,'POLICY');
  assert.deepEqual(fs.readFileSync(path.join(s.root,'record.yaml')),before);assert.equal(s.r.journal.replay(s.ctx).budget.spent,0);
});
test('e2e: actual postcondition mismatch retains pending intent and never repeats a partial write',t=>{
  const s=setup(t),permit=s.prepare(),lease=s.r.acquireLease(s.ctx),rename=fs.renameSync;let publications=0;
  fs.renameSync=(from,to)=>{const value=rename(from,to);if(to===path.join(s.root,'record.yaml')){publications++;fs.writeFileSync(path.join(s.root,'policy.yaml'),'unexpected frozen delta');}return value;};
  let result;try{result=s.r.executeCapability(permit,lease);}finally{fs.renameSync=rename;}
  assert.equal(result.status,'INCOMPLETE');assert.equal(publications,1);assert.deepEqual(s.r.journal.replay(s.ctx).pending,['write']);assert.equal(s.r.journal.replay(s.ctx).budget.spent,1);
  assert.equal(s.r.executeCapability(permit,lease).status,'INCOMPLETE');assert.equal(fs.readFileSync(path.join(s.root,'policy.yaml'),'utf8'),'unexpected frozen delta');s.r.releaseLease(lease);
});
test('e2e: crash after complete publication reconciles exact bytes without republishing',t=>{
  const s=setup(t),permit=s.prepare(),lease=s.r.acquireLease(s.ctx),rename=fs.renameSync;
  fs.renameSync=(from,to)=>{const value=rename(from,to);if(to===path.join(s.root,'digest.yaml'))throw Error('simulated interruption after rename');return value;};
  try{assert.equal(s.r.executeCapability(permit,lease).status,'INCOMPLETE');}finally{fs.renameSync=rename;}
  assert.deepEqual(s.r.journal.replay(s.ctx).pending,['write']);s.r.releaseLease(lease);
  const r=openRuntime(s.host),ctx=s.context(r),next=r.acquireLease(ctx);let writes=0;
  fs.renameSync=(from,to)=>{if(to.startsWith(s.root+'/')){writes++;throw Error('must not publish again');}return rename(from,to);};
  try{assert.equal(r.reconcileCapability('write',ctx,next).status,'EFFECT_VERIFIED');}finally{fs.renameSync=rename;}
  assert.equal(writes,0);assert.equal(r.journal.replay(ctx).budget.spent,1);r.releaseLease(next);
});
test('expired grant stops a previously prepared effect before spend',t=>{const s=setup(t),p=s.prepare(),l=s.r.acquireLease(s.ctx);s.f.setNow(1500);assert.notEqual(s.r.executeCapability(p,l).status,'EFFECT_VERIFIED');assert.equal(fs.readFileSync(path.join(s.root,'record.yaml'),'utf8'),sample);s.r.releaseLease(l);});
test('runtime and transitive dependency bundle changes block prepared effects',t=>{
  const s=setup(t),p=s.prepare(),l=s.r.acquireLease(s.ctx),file=path.resolve(import.meta.dirname,'../node_modules/yaml/package.json'),original=fs.readFileSync(file);
  try{fs.appendFileSync(file,'\n');assert.equal(s.r.executeCapability(p,l).status,'BLOCKED_BY_RUNTIME_BINDING');}finally{fs.writeFileSync(file,original);}
  assert.equal(s.r.journal.replay(s.ctx).budget.spent,0);s.r.releaseLease(l);
});
test('host must pin installed implementation and claim only supported local mode',t=>{
  const s=setup(t);assert.equal(openRuntime({...s.host,capabilities:{...s.host.capabilities,bundleDigest:'0'.repeat(64)}}).status,'BLOCKED_BY_RUNTIME_BINDING');assert.ok(openRuntime({...s.host,capabilities:{...s.host.capabilities,mode:'OS_SANDBOX'}}).status);
});
test('oversized source and symlink ancestors are refused before write',t=>{
  const s=setup(t);fs.writeFileSync(path.join(s.root,'record.yaml'),'title: '+ 'x'.repeat(1024*1024));assert.notEqual(s.describe().status,'CAPABILITY_DESCRIBED');
  const link=path.join(s.dir,'alias');fs.symlinkSync(s.root,link);assert.ok(openRuntime({...s.host,capabilities:{...s.host.capabilities,workspace:link}}).status);
});
test('supervisor rejects unexpected frozen delta after last output publication',t=>{
  const s=setup(t),p=s.prepare(),l=s.r.acquireLease(s.ctx),rename=fs.renameSync;
  fs.renameSync=(from,to)=>{const value=rename(from,to);if(to===path.join(s.root,'digest.yaml'))fs.writeFileSync(path.join(s.root,'policy.yaml'),'late delta');return value;};
  try{assert.equal(s.r.executeCapability(p,l).status,'INCOMPLETE');}finally{fs.renameSync=rename;}
  assert.equal(fs.readdirSync(path.join(s.dir,'state/capabilities')).some(n=>n.endsWith('.receipt')),false);assert.deepEqual(s.r.journal.replay(s.ctx).pending,['write']);s.r.releaseLease(l);
});
for(const reopen of [false,true])test(`generic target reconciliation cannot substitute a supervised capability receipt (reopen=${reopen})`,t=>{
  const s=setup(t),p=s.prepare(),l=s.r.acquireLease(s.ctx),rename=fs.renameSync;
  fs.renameSync=(from,to)=>{const value=rename(from,to);if(to===path.join(s.root,'digest.yaml'))throw Error('interrupted receipt');return value;};
  try{assert.equal(s.r.executeCapability(p,l).status,'INCOMPLETE');}finally{fs.renameSync=rename;}
  s.setReconciliation({status:'COMPLETED',outputDigest:sha('unrelated target response')});
  const target=reopen?openRuntime({...s.host,capabilities:undefined}):s.r,targetContext=reopen?s.context(target):s.ctx;
  assert.equal(target.journal.reconcile(target.journal.replay(targetContext).headDigest,'write',targetContext).status,'POLICY');
  assert.deepEqual(s.r.journal.replay(s.ctx).pending,['write']);assert.equal(s.r.reconcileCapability('write',s.ctx,l).status,'EFFECT_VERIFIED');s.r.releaseLease(l);
});
