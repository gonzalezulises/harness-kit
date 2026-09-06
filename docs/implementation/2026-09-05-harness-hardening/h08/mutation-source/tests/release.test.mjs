import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import * as api from '../index.mjs';
import {fixture,bytes,sample} from './helpers.mjs';
const H='a'.repeat(64),C='a'.repeat(40),target={kind:'deployment.v1',id:'approved-target',environment:'production'};
function objective(){return {version:1,domain:'harness.release.v1',repositoryId:'repo-A',authorityDigest:H,baselineDigest:H,goal:'PRODUCTION_PASS',scope:{objectiveId:'objective',journalId:'journal',integratedCommit:C,artifactDigest:H,target},slices:['slice-A'],externalGate:null,maxEvidenceAge:100};}
function event(o,kind,extra={}){return {version:1,kind,operationKey:kind,binding:{repositoryId:o.repositoryId,objectiveId:o.scope.objectiveId,objectiveDigest:api.digestData(o),integratedCommit:o.scope.integratedCommit,artifactDigest:o.scope.artifactDigest,target:o.scope.target},issuedAt:950,expiresAt:1100,result:'PASS',evidenceDigest:H,...extra};}
function trace(o){return [event(o,'slice',{sliceId:'slice-A'}),event(o,'merge'),event(o,'integrated-verification'),event(o,'independent-review'),event(o,'artifact-acceptance'),event(o,'deployment-intent',{approvalDigest:H}),event(o,'deployment',{deploymentId:'A',intentKey:'deployment-intent',approvalDigest:H}),event(o,'smoke',{deploymentId:'A',executionId:'smoke-A'}),event(o,'observability',{deploymentId:'A',executionId:'observe-A'})];}
function simulate(o,events,now=1000){return api.simulateRelease(o,{provenance:'SIMULATION',now,events});}
function setup(t){
  const directory=fs.mkdtempSync(path.join(os.tmpdir(),'h08-'));t.after(()=>fs.rmSync(directory,{recursive:true,force:true}));
  const f=fixture();let commit=C;
  const host={...f.host,issuers:f.host.issuers.map(i=>({...i,kinds:[...i.kinds,'deployment-authorization']})),journal:{directory,objectiveId:'objective',journalId:'journal',actorId:'supervisor',budgetLimit:3,readFinalBinding:()=>({commit,documents:[{path:'record.yaml',bytes:bytes(sample)}]})}};
  function context(r){return r.verifyContext({authority:r.loadAuthority(bytes(api.canonical(f.authority)),f.receipt('policy-adoption',f.authorityDigest)),documents:[{path:'record.yaml',bytes:bytes(sample)}],acceptance:f.receipt('baseline-acceptance',r.describeBaseline([{path:'record.yaml',bytes:bytes(sample)}]).digest)});}
  const r=api.openRuntime(host),ctx=context(r);assert.equal(r.journal.start(ctx,'start').status,'APPENDED');
  const input={artifactDigest:H,target,slices:['slice-A'],externalGate:null,maxEvidenceAge:100};
  assert.equal(typeof r.describeReleaseObjective,'function','runtime must implement release obligations');
  const o=r.describeReleaseObjective(input,ctx).objective;
  const wire={objective:o,approval:f.receipt('bounded-grant',api.digestData(o),{scopeDigest:api.digestData(o.scope)})};
  const handle=r.bindReleaseObjective(wire,ctx);assert.equal(handle.status,undefined);
  const approval=(changes={})=>f.receipt('deployment-authorization',api.digestData(o),{scopeDigest:api.digestData({...o.scope,action:'deploy'}),...changes});
  return {r,ctx,f,host,context,o,wire,handle,approval,setCommit:v=>{commit=v;},directory};
}
test('H08 missing release API is an observable unmet objective',t=>{const s=setup(t);assert.equal(s.r.certifyRelease(s.handle,s.r.replayRelease(s.handle)).certification,'NOT_EXECUTED');});
test('HIST-11: green slice and merged PR continue through every obligation',()=>{
  const o=objective(),events=trace(o),expected=['verify-slice','integrate','revalidate-integrated-commit','independent-review','accept-artifact','deploy','reconcile-deployment','smoke','observability','complete'];
  for(let n=0;n<=events.length;n++){const r=simulate(o,events.slice(0,n));assert.equal(r.status,'SIMULATION',r.reason);assert.equal(r.nextObligation.kind,expected[n]);assert.equal(r.certification,'NOT_EXECUTED');}
});
test('production simulation never becomes production certification',()=>{const o=objective(),r=simulate(o,trace(o));assert.equal(r.status,'SIMULATION');assert.equal(r.nextObligation.kind,'complete');assert.equal(r.certification,'NOT_EXECUTED');assert.equal(r.productionPass,false);});
for(const kind of ['integrated-verification','deployment','smoke','observability'])test(`wrong artifact binding cannot discharge ${kind}`,()=>{const o=objective(),events=trace(o);events.find(e=>e.kind===kind).binding.artifactDigest='b'.repeat(64);assert.equal(simulate(o,events).status,'POLICY');});
for(const field of ['deploymentId','target','commit'])test(`deployment A cannot consume smoke B: ${field}`,()=>{const o=objective(),events=trace(o),smoke=events.find(e=>e.kind==='smoke');if(field==='deploymentId')smoke.deploymentId='B';if(field==='target')smoke.binding.target={...target,id:'other'};if(field==='commit')smoke.binding.integratedCommit='b'.repeat(40);const r=simulate(o,events);assert.ok(r.status==='POLICY'||r.nextObligation.kind==='smoke');});
test('preview and successful model JSON cannot satisfy production receipts',()=>{const o=objective(),events=trace(o);events[6].binding.target={...target,environment:'preview'};assert.equal(simulate(o,events).status,'POLICY');assert.equal(api.simulateRelease(o,{provenance:'HOST_AUTHENTICATED',now:1000,events:trace(o)}).status,'POLICY');assert.equal(simulate(o,[{status:'REVIEW_OUTPUT_VALIDATED',verdict:'PASS'}]).status,'POLICY');});
test('functional smoke and observability require separate actual execution identities in the contract',()=>{const o=objective(),events=trace(o);events.at(-1).executionId=events.at(-2).executionId;assert.equal(simulate(o,events).nextObligation.kind,'observability');});
test('freshness expiration future dates and later failure prevent reuse',()=>{
  const o=objective(),events=trace(o);assert.equal(simulate(o,events,1100).nextObligation.kind,'verify-slice');
  events.at(-1).issuedAt=1001;assert.equal(simulate(o,events).status,'POLICY');events.at(-1).issuedAt=950;
  events.push(event(o,'smoke',{operationKey:'smoke-failed',deploymentId:'A',executionId:'smoke-failed',issuedAt:960,result:'FAIL'}));assert.equal(simulate(o,events).nextObligation.kind,'smoke');
});
test('merge requires revalidation after integration even on the same commit',()=>{const o=objective(),events=trace(o);events[1].issuedAt=970;assert.equal(simulate(o,events).status,'POLICY');const merged=events.splice(1,1)[0];events.push(merged);assert.equal(simulate(o,events).nextObligation.kind,'revalidate-integrated-commit');});
test('crash resume retains exact pending deployment key and refuses duplicate uncertain intent',()=>{const o=objective(),events=trace(o).slice(0,6);assert.deepEqual(simulate(o,events).nextObligation,{kind:'reconcile-deployment',operationKey:'deployment-intent'});events.push(event(o,'deployment-intent',{operationKey:'deploy-again',approvalDigest:H}));assert.equal(simulate(o,events).status,'INCOMPLETE');});
test('deployment must reconcile matching prior approval and operation key',()=>{const o=objective();for(const edit of [e=>e.intentKey='wrong',e=>e.approvalDigest='b'.repeat(64)]){const events=trace(o);edit(events[6]);assert.equal(simulate(o,events).status,'POLICY');}});
test('rollback invalidates current objective without deleting deployment history',()=>{const o=objective(),events=trace(o);events.push(event(o,'rollback',{deploymentId:'A',previousDeploymentId:'previous',approvalDigest:H,issuedAt:960}));const copy=structuredClone(events),r=simulate(o,events);assert.equal(r.nextObligation.kind,'remediate');assert.equal(r.historyLength,10);assert.deepEqual(events,copy);assert.equal(r.productionPass,false);});
test('external gate is exact and independent from deployment permission',()=>{const o={...objective(),externalGate:'change-board'},events=trace(o);assert.equal(simulate(o,events).nextObligation.kind,'external-gate');events.splice(5,0,event(o,'external-gate',{gateId:'another'}));assert.equal(simulate(o,events).nextObligation.kind,'external-gate');events[5].gateId='change-board';assert.equal(simulate(o,events).nextObligation.kind,'complete');});
test('strict closed schemas reject unknown fields missing obligations and callbacks',()=>{const o=objective();for(const edited of [{...o,goal:'SLICE_PASS'},{...o,slices:[]},{...o,verify:()=>true},{...o,externalGate:undefined}])assert.equal(simulate(edited,[]).status,'POLICY');const events=trace(o);events.at(-1).same_artifact=true;assert.equal(simulate(o,events).status,'POLICY');});
test('e2e runtime: exact approved objective refuses production and preserves budget across reopen',t=>{
  const s=setup(t),before=s.r.journal.replay(s.ctx),replay=s.r.replayRelease(s.handle),next=s.r.nextObligation(s.handle,replay);
  assert.equal(next.status,'BLOCKED_BY_REQUIRED_CAPABILITY');assert.equal(next.certification,'NOT_EXECUTED');assert.ok(next.unsatisfied.includes('independent-review'));
  for(let n=0;n<2;n++){assert.equal(s.r.prepareDeployment(s.handle,s.approval()).status,'BLOCKED_BY_REQUIRED_CAPABILITY');assert.equal(s.r.certifyRelease(s.handle,replay).productionPass,false);}
  assert.equal(s.r.journal.replay(s.ctx).budget.spent,0);assert.equal(s.r.journal.replay(s.ctx).headDigest,before.headDigest);
  const r=api.openRuntime(s.host),ctx=s.context(r),handle=r.bindReleaseObjective(s.wire,ctx);assert.equal(r.certifyRelease(handle,r.replayRelease(handle)).certification,'NOT_EXECUTED');assert.equal(r.journal.replay(ctx).budget.spent,0);
});
test('wrong artifact approval, bounded grant and expired deployment approval do not authorize deployment',t=>{
  const s=setup(t);assert.equal(s.r.prepareDeployment(s.handle,s.approval({subjectDigest:'b'.repeat(64)})).status,'BLOCKED_BY_AUTHORITY_MISMATCH');assert.equal(s.r.prepareDeployment(s.handle,s.wire.approval).status,'BLOCKED_BY_AUTHORITY_MISMATCH');
  assert.equal(s.r.prepareDeployment(s.handle,s.approval({expiresAt:1000})).status,'BLOCKED_BY_STALE_AUTHORITY');assert.equal(s.r.journal.replay(s.ctx).budget.spent,0);
});
test('forged stale serialized and cross-runtime handles cannot certify',t=>{
  const s=setup(t),replay=s.r.replayRelease(s.handle);for(const forged of [{},s.r.journal.replay(s.ctx),{status:'PRODUCTION_PASS'},JSON.parse(JSON.stringify(replay))])assert.equal(s.r.certifyRelease(s.handle,forged).status,'POLICY');
  assert.equal(s.r.certifyRelease({},replay).status,'POLICY');const other=api.openRuntime(s.host);assert.equal(other.certifyRelease(s.handle,replay).status,'POLICY');
  const state=s.r.journal.replay(s.ctx);assert.equal(s.r.journal.appendEvent(state.headDigest,{kind:'reserve',operationKey:'uncertain',runId:state.runs.at(-1).runId,units:1,inputDigest:H},s.ctx).status,'APPENDED');assert.equal(s.r.certifyRelease(s.handle,replay).status,'BLOCKED_BY_STALE_RUN');
  const fresh=s.r.replayRelease(s.handle),r=s.r.nextObligation(s.handle,fresh);assert.equal(r.status,'INCOMPLETE');assert.deepEqual(r.nextObligation,{kind:'reconcile-operation',operationKey:'uncertain'});assert.equal(s.r.reconcileDeployment(s.handle,'uncertain').status,'INCOMPLETE');assert.equal(s.r.journal.replay(s.ctx).budget.spent,1);
});
test('integrated commit change requires a newly scoped objective and revalidation',t=>{const s=setup(t),replay=s.r.replayRelease(s.handle);s.setCommit('b'.repeat(40));assert.equal(s.r.nextObligation(s.handle,replay).status,'BLOCKED_BY_STALE_RUN');assert.equal(s.r.prepareDeployment(s.handle,s.approval()).status,'BLOCKED_BY_STALE_RUN');assert.equal(s.r.journal.replay(s.ctx).budget.spent,0);});
test('objective wire requires exact acceptance and scope binding',t=>{const s=setup(t),wire=structuredClone(s.wire);wire.objective.scope.artifactDigest='b'.repeat(64);assert.equal(s.r.bindReleaseObjective(wire,s.ctx).status,'BLOCKED_BY_AUTHORITY_MISMATCH');assert.equal(s.r.bindReleaseObjective({...s.wire,approved:true},s.ctx).status,'POLICY');});

test('rollback permission is exact and cannot reuse deployment approval',t=>{
  const s=setup(t),request={deploymentId:'A',previousDeploymentId:'previous'};
  assert.equal(s.r.prepareRollback(s.handle,request,s.approval()).status,'BLOCKED_BY_AUTHORITY_MISMATCH');
  const signed=s.f.receipt('deployment-authorization',api.digestData({objectiveDigest:api.digestData(s.o),action:'rollback',...request}),{scopeDigest:api.digestData({...s.o.scope,action:'rollback'})});
  assert.equal(s.r.prepareRollback(s.handle,request,signed).status,'BLOCKED_BY_REQUIRED_CAPABILITY');
  assert.equal(s.r.prepareRollback(s.handle,{...request,previousDeploymentId:'other'},signed).status,'BLOCKED_BY_AUTHORITY_MISMATCH');
  assert.equal(s.r.journal.replay(s.ctx).budget.spent,0);
});
test('e2e continuation budgets survive unavailable release work and scoped grants do not authorize deployment',t=>{
  const s=setup(t),mechanical='mechanical-remediation-verification',product='product-semantic-review',harness='harness-implementation-review';
  const input={acId:'AC-canonical',paths:['record.yaml'],capabilities:['canonical-write.v1'],regressions:[{path:'record.yaml',afterBase64:bytes(sample.split('\n').filter(Boolean).reverse().join('\n')+'\n').toString('base64'),expected:'MECHANICAL_ELIGIBLE'},{path:'record.yaml',afterBase64:bytes(sample.replace('hello','other')).toString('base64'),expected:'HUMAN_REQUIRED'}],limits:{[mechanical]:1,[product]:1,[harness]:1,total:3}};
  const grant=s.r.describeContinuation(input,s.ctx).grant,approval=s.f.receipt('bounded-grant',api.digestData(grant),{scopeDigest:api.digestData(grant.scope),receiptId:'remediation'});
  assert.equal(s.r.evaluateContinuation({grant,approval},{gateDigest:api.digestData(grant.humanGate),path:'record.yaml'},s.ctx).status,undefined);
  assert.equal(s.r.spendBudget(product,'objective','actual-reservation').status,'APPENDED');
  const before=s.r.journal.replay(s.ctx);assert.equal(s.r.prepareDeployment(s.handle,approval).status,'BLOCKED_BY_AUTHORITY_MISMATCH');assert.equal(s.r.prepareDeployment(s.handle,s.approval()).status,'BLOCKED_BY_REQUIRED_CAPABILITY');
  const after=s.r.journal.replay(s.ctx);assert.deepEqual(after.budget,before.budget);assert.equal(after.headDigest,before.headDigest);assert.equal(after.budget.byKind[product],1);
});
