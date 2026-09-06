import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {openRuntime,canonical,digestData,installedBundleDigest} from '../index.mjs';
import {fixture,bytes,sample} from './helpers.mjs';
const mechanical='mechanical-remediation-verification',product='product-semantic-review',harness='harness-implementation-review';
function setup(t,limits={[product]:2,[harness]:2,[mechanical]:2,total:4}) {
  const directory=fs.mkdtempSync(path.join(os.tmpdir(),'h06-'));t.after(()=>fs.rmSync(directory,{recursive:true,force:true}));
  const workspace=path.join(directory,'work');fs.mkdirSync(workspace);fs.writeFileSync(path.join(workspace,'record.yaml'),sample);
  const f=fixture();let commit='a'.repeat(40);
  const documents=[{path:'record.yaml',bytes:bytes(sample)}];
  const host={...f.host,journal:{directory:path.join(directory,'state'),objectiveId:'objective',journalId:'journal',actorId:'supervisor',budgetLimit:limits.total,readFinalBinding:()=>({commit,documents:[{path:'record.yaml',bytes:fs.readFileSync(path.join(workspace,'record.yaml'))}]})},capabilities:{workspace,writablePaths:['record.yaml'],denyPaths:[],bundleDigest:installedBundleDigest(),mode:'TRUSTED_RUNTIME_EXCLUSIVE'}};
  const context=r=>r.verifyContext({authority:r.loadAuthority(bytes(canonical(f.authority)),f.receipt('policy-adoption',f.authorityDigest)),documents,acceptance:f.receipt('baseline-acceptance',r.describeBaseline(documents).digest)});
  const r=openRuntime(host),ctx=context(r);assert.equal(r.journal.start(ctx,'start').status,'APPENDED');
  const regressions=[{path:'record.yaml',afterBase64:bytes(sample.split('\n').filter(Boolean).reverse().join('\n')+'\n').toString('base64'),expected:'MECHANICAL_ELIGIBLE'},{path:'record.yaml',afterBase64:bytes(sample.replace('hello','different')).toString('base64'),expected:'HUMAN_REQUIRED'}];
  const input={acId:'AC-canonical',paths:['record.yaml'],capabilities:['canonical-write.v1'],regressions,limits};
  const describe=()=>r.describeContinuation(input,ctx);
  const sign=(grant,changes={})=>({grant,approval:f.receipt('bounded-grant',digestData(grant),{receiptId:'continuation',scopeDigest:digestData(grant.scope),...changes})});
  const wire=()=>{const d=describe();assert.equal(d.status,'CONTINUATION_DESCRIBED',d.reason);return sign(d.grant);};
  const observe=g=>({gateDigest:digestData(g.humanGate),path:'record.yaml'});
  const evaluate=(w=wire())=>r.evaluateContinuation(w,observe(w.grant),ctx);
  const fresh=(key='fresh')=>{commit=(commit[0]==='a'?'b':'a').repeat(40);const s=r.journal.replay(ctx);return r.journal.replaceStaleRun(s.headDigest,s.runs.at(-1).runId,key,ctx);};
  const prepare=(continuation,key='effect')=>r.prepareCapability('canonical-write.v1',{path:'record.yaml',operationKey:key},ctx,continuation);
  return {r,ctx,f,host,context,workspace,directory,input,describe,sign,wire,observe,evaluate,fresh,prepare};
}
test('e2e: one signed grant permits two mechanical runs and keeps original artifact acceptance',t=>{
  const s=setup(t),wire=s.wire(),permit=s.evaluate(wire);assert.equal(permit.status,undefined);
  const original=s.r.inspectContext(s.ctx).baselineDigest;
  const lease=s.r.acquireLease(s.ctx),effect=s.prepare(permit);assert.equal(s.r.executeCapability(effect,lease).status,'EFFECT_VERIFIED');s.r.releaseLease(lease);
  const nextBytes=fs.readFileSync(path.join(s.workspace,'record.yaml'));
  const baseline=s.r.describeBaseline([{path:'record.yaml',bytes:nextBytes}]);
  const oldAcceptance=s.f.receipt('baseline-acceptance',original);
  assert.ok(s.r.verifyContext({authority:s.r.loadAuthority(bytes(canonical(s.f.authority)),s.f.receipt('policy-adoption',s.f.authorityDigest)),documents:[{path:'record.yaml',bytes:nextBytes}],acceptance:oldAcceptance}).status);
  assert.notEqual(baseline.digest,original);
  fs.writeFileSync(path.join(s.workspace,'record.yaml'),sample);assert.equal(s.fresh().status,'APPENDED');
  const second=s.evaluate(wire),next=s.r.acquireLease(s.ctx);assert.equal(s.r.executeCapability(s.prepare(second,'effect-two'),next).status,'EFFECT_VERIFIED');s.r.releaseLease(next);
  const state=s.r.journal.replay(s.ctx);assert.equal(state.budget.spent,2);assert.equal(state.budget.byKind[mechanical],2);assert.equal(Object.keys(state.continuations.grants).length,1);assert.equal(state.baselineDigest,original);
});
test('durable regression bytes and signed gate bind actual accepted semantics',t=>{
  const s=setup(t),wire=s.wire();assert.equal(s.evaluate(wire).status,undefined);
  const state=s.r.journal.replay(s.ctx);assert.deepEqual(state.continuations.grants[digestData(wire.grant)],wire);
  const reopen=openRuntime(s.host),ctx=s.context(reopen);assert.equal(reopen.evaluateContinuation(wire,s.observe(wire.grant),ctx).status,undefined);
  for(const edit of [g=>g.humanGate.acId='another',g=>g.humanGate.defectClass='new',g=>g.humanGate.violatedRule='new',g=>g.humanGate.authorityDigest='0'.repeat(64),g=>g.humanGate.invariantDigest='0'.repeat(64),g=>g.scope.paths.push('policy.yaml'),g=>g.limits.total++]){const forged=structuredClone(wire);edit(forged.grant);assert.ok(s.evaluate(forged).status);}
  assert.ok(s.r.evaluateContinuation(wire,{...s.observe(wire.grant),same_threat:true},s.ctx).status);
  assert.ok(s.r.evaluateContinuation(wire,{gateDigest:'0'.repeat(64),path:'record.yaml'},s.ctx).status);
});
for(const scenario of ['missing','false-expectation','lost-coverage','callback'])test(`closed regressions refuse ${scenario}`,t=>{
  const s=setup(t);if(scenario==='missing')s.input.regressions=[];if(scenario==='false-expectation')s.input.regressions[1].expected='MECHANICAL_ELIGIBLE';if(scenario==='lost-coverage')s.input.regressions.pop();if(scenario==='callback')s.input.regressions[0].verify=()=>true;
  assert.notEqual(s.describe().status,'CONTINUATION_DESCRIBED');
});
test('signed unsupported product proof stops without simulated PASS',t=>{
  const s=setup(t);s.input.capabilities=['subprocess.v1'];const result=s.describe();assert.equal(result.status,'BLOCKED_BY_REQUIRED_CAPABILITY');assert.equal(result.execution,'NOT_EXECUTED');
});
test('H06 expiry is rechecked at effect use',t=>{
  const s=setup(t),wire=s.wire();wire.approval=s.sign(wire.grant,{expiresAt:1100}).approval;const permit=s.evaluate(wire),effect=s.prepare(permit),lease=s.r.acquireLease(s.ctx);s.f.setNow(1100);
  assert.equal(s.r.executeCapability(effect,lease).status,'BLOCKED_BY_STALE_AUTHORITY');assert.equal(s.r.journal.replay(s.ctx).budget.spent,0);assert.equal(fs.readFileSync(path.join(s.workspace,'record.yaml'),'utf8'),sample);s.r.releaseLease(lease);
});
test('H06 revocation survives reopen and blocks an already prepared effect',t=>{
  const s=setup(t),wire=s.wire(),continuation=s.evaluate(wire),effect=s.prepare(continuation),lease=s.r.acquireLease(s.ctx);
  assert.equal(s.r.revokeContinuation(digestData(wire.grant),'revoke',s.ctx).status,'APPENDED');
  assert.equal(s.r.executeCapability(effect,lease).status,'BLOCKED_BY_REVOKED_AUTHORITY');s.r.releaseLease(lease);
  const reopen=openRuntime(s.host),ctx=s.context(reopen);assert.equal(reopen.evaluateContinuation(wire,s.observe(wire.grant),ctx).status,'BLOCKED_BY_REVOKED_AUTHORITY');assert.deepEqual(reopen.journal.replay(ctx).continuations.revoked,[digestData(wire.grant)]);
});
test('H06 category exhaustion survives fresh run, retry and replacement grant',t=>{
  const s=setup(t),wire=s.wire();s.evaluate(wire);
  const first=s.r.spendBudget(product,'objective','p1');assert.equal(first.status,'APPENDED');assert.deepEqual(s.r.spendBudget(product,'objective','p1'),first);
  assert.equal(s.r.spendBudget(harness,'objective','p1').status,'POLICY');assert.equal(s.r.spendBudget(product,'different','p3').status,'POLICY');
  assert.equal(s.r.spendBudget(product,'objective','p2').status,'APPENDED');assert.equal(s.fresh().status,'APPENDED');assert.equal(s.r.spendBudget(product,'objective','p3').status,'BUDGET_EXHAUSTED');
  const changed=structuredClone(wire.grant);changed.limits[product]=3;const second=s.sign(changed,{receiptId:'new-grant'});assert.equal(s.evaluate(second).status,'POLICY');
  assert.equal(s.r.journal.replay(s.ctx).budget.byKind[product],2);
});
test('H06 all three categories share the signed total cap',t=>{
  const s=setup(t,{[product]:3,[harness]:3,[mechanical]:3,total:3});s.evaluate();
  for(const [i,kind] of [product,harness,mechanical].entries())assert.equal(s.r.spendBudget(kind,'objective','spend-'+i).status,'APPENDED');
  assert.equal(s.r.spendBudget(product,'objective','fourth').status,'BUDGET_EXHAUSTED');assert.equal(s.r.journal.replay(s.ctx).budget.spent,3);
});
test('H06 budget is rechecked between prepare and use without creating effect intent',t=>{
  const s=setup(t,{[product]:1,[harness]:1,[mechanical]:1,total:1}),grant=s.evaluate(),effect=s.prepare(grant),lease=s.r.acquireLease(s.ctx);assert.equal(s.r.spendBudget(product,'objective','last').status,'APPENDED');
  assert.equal(s.r.executeCapability(effect,lease).status,'BUDGET_EXHAUSTED');assert.equal(fs.readFileSync(path.join(s.workspace,'record.yaml'),'utf8'),sample);assert.equal(fs.readdirSync(path.join(s.directory,'state/capabilities')).some(p=>p.endsWith('.intent')),false);s.r.releaseLease(lease);
});
test('older bounded approvals do not become reusable continuation and foreign handles fail',t=>{
  const s=setup(t),wire=s.wire(),grant=s.evaluate(wire);assert.ok(s.r.evaluateContinuation(wire.approval,s.observe(wire.grant),s.ctx).status);assert.ok(s.prepare({}).status);
  const other=openRuntime(s.host),ctx=s.context(other);assert.ok(other.prepareCapability('canonical-write.v1',{path:'record.yaml',operationKey:'other'},ctx,grant).status);
});
test('H06 changed accepted authority, file classes and workspace semantics block continuation',t=>{
  const s=setup(t),wire=s.wire();s.evaluate(wire);
  fs.writeFileSync(path.join(s.workspace,'record.yaml'),sample.replace('hello','new product meaning'));assert.ok(s.evaluate(wire).status);
  fs.writeFileSync(path.join(s.workspace,'record.yaml'),sample);
  for(const cls of ['security','architecture']){const host={...s.host,files:s.host.files.map(f=>f.path==='record.yaml'?{...f,class:cls}:f)};const r=openRuntime(host),ctx=s.context(r);assert.ok(r.evaluateContinuation(wire,s.observe(wire.grant),ctx).status);}
});
test('H06 legacy and generic reserves cannot bypass category accounting',t=>{
  const s=setup(t);s.evaluate();const state=s.r.journal.replay(s.ctx);
  assert.equal(s.r.journal.appendEvent(state.headDigest,{kind:'reserve',operationKey:'bypass',runId:state.runs[0].runId,units:1,inputDigest:'0'.repeat(64)},s.ctx).status,'POLICY');
  assert.equal(s.r.journal.appendEvent(state.headDigest,{kind:'budget-spend',operationKey:'forged',budgetKind:product},s.ctx).status,'POLICY');
});
test('H06-R1 counterexample coverage cannot be replaced by identical accepted bytes',t=>{
  const s=setup(t);s.input.regressions[0].afterBase64=bytes(sample).toString('base64');
  assert.equal(s.describe().status,'POLICY');
});
test('e2e: H06 exhausted retry reconciles original intent without another unit',t=>{
  const s=setup(t,{[product]:0,[harness]:0,[mechanical]:1,total:1}),wire=s.wire(),grant=s.evaluate(wire),permit=s.prepare(grant),lease=s.r.acquireLease(s.ctx);
  const result=s.r.executeCapability(permit,lease);assert.equal(result.status,'EFFECT_VERIFIED');assert.deepEqual(s.r.executeCapability(permit,lease),result);s.r.releaseLease(lease);
  const events=fs.readFileSync(path.join(s.directory,'state/events.jsonl'),'utf8').trim().split('\n').map(JSON.parse);
  assert.equal(events.find(e=>e.operation.kind==='reserve').operation.grantDigest,digestData(wire.grant));
  const reopen=openRuntime(s.host),ctx=s.context(reopen),next=reopen.acquireLease(ctx);assert.deepEqual(reopen.reconcileCapability('effect',ctx,next),result);reopen.releaseLease(next);assert.equal(reopen.journal.replay(ctx).budget.spent,1);
});
