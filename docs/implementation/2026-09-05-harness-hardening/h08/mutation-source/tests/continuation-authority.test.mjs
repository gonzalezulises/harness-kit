import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { authorityBoundary, kinds } from '../authority.mjs';
import { openRuntime, canonical, digestData } from '../index.mjs';
import { fixture, bytes, sample } from './helpers.mjs';
const fabricatedSignature=Buffer.alloc(64).toString('base64');
function approvalFixture() {
  const f=fixture(),host={...f.host,issuers:f.host.issuers.map(i=>({...i,kinds}))},boundary=authorityBoundary(host);
  const expected=kind=>({kind,subjectDigest:'a'.repeat(64),scopeDigest:digestData(f.authority.scope),authorityDigest:f.authorityDigest});
  return {f,boundary,expected};
}
for(const mode of ['current','recorded'])test(`C1 ${mode} verifier rejects fabricated signatures for every approval kind`,()=>{
  const s=approvalFixture();
  for(const kind of kinds){const expected=s.expected(kind),receipt=s.f.receipt(kind,expected.subjectDigest,{signature:fabricatedSignature});receipt.signature=fabricatedSignature;
    const result=mode==='current'?s.boundary.verifyApproval(receipt,expected):s.boundary.verifyRecordedApproval(receipt,expected,1000);
    assert.equal(result.status,'BLOCKED_BY_INVALID_SIGNATURE',kind);
  }
});
test('C1 current and recorded verifiers accept genuine signatures and reject altered signed fields',()=>{
  const s=approvalFixture();
  for(const kind of kinds){const expected=s.expected(kind),receipt=s.f.receipt(kind,expected.subjectDigest);
    const handle=s.boundary.verifyApproval(receipt,expected);assert.equal(s.boundary.inspectApproval(handle).status,'VERIFIED_APPROVAL',kind);
    assert.equal(s.boundary.verifyRecordedApproval(receipt,expected,1000).status,'VERIFIED_RECORDED_APPROVAL',kind);
    const altered={...receipt,receiptId:receipt.receiptId+'-tampered'};
    assert.equal(s.boundary.verifyApproval(altered,expected).status,'BLOCKED_BY_INVALID_SIGNATURE',kind);
    assert.equal(s.boundary.verifyRecordedApproval(altered,expected,1000).status,'BLOCKED_BY_INVALID_SIGNATURE',kind);
  }
});
test('C1 valid historical signatures preserve event-time semantics without current authority',()=>{
  const s=approvalFixture(),expected=s.expected('bounded-grant'),receipt=s.f.receipt('bounded-grant',expected.subjectDigest,{expiresAt:1100});
  s.f.setNow(1200);
  assert.equal(s.boundary.verifyApproval(receipt,expected).status,'BLOCKED_BY_STALE_AUTHORITY');
  assert.equal(s.boundary.verifyRecordedApproval(receipt,expected,1000).status,'VERIFIED_RECORDED_APPROVAL');
  assert.equal(s.boundary.verifyRecordedApproval(receipt,expected,1100).status,'BLOCKED_BY_STALE_AUTHORITY');
});
function continuationFixture(t) {
  const directory=fs.mkdtempSync(path.join(os.tmpdir(),'h06-fix1-'));t.after(()=>fs.rmSync(directory,{recursive:true,force:true}));
  const f=fixture(),documents=[{path:'record.yaml',bytes:bytes(sample)}];
  const r=openRuntime({...f.host,journal:{directory,objectiveId:'objective',journalId:'journal',actorId:'supervisor',budgetLimit:2,readFinalBinding:()=>({commit:'a'.repeat(40),documents})}});
  const authority=r.loadAuthority(bytes(canonical(f.authority)),f.receipt('policy-adoption',f.authorityDigest));
  const ctx=r.verifyContext({authority,documents,acceptance:f.receipt('baseline-acceptance',r.describeBaseline(documents).digest)});
  assert.equal(r.journal.start(ctx,'start').status,'APPENDED');
  const described=r.describeContinuation({acId:'AC-record',paths:['record.yaml'],capabilities:['canonical-write.v1'],limits:{'product-semantic-review':0,'harness-implementation-review':0,'mechanical-remediation-verification':2,total:2},regressions:[{path:'record.yaml',afterBase64:bytes(sample.split('\n').filter(Boolean).reverse().join('\n')+'\n').toString('base64'),expected:'MECHANICAL_ELIGIBLE'},{path:'record.yaml',afterBase64:bytes(sample.replace('hello','different')).toString('base64'),expected:'HUMAN_REQUIRED'}]},ctx);
  assert.equal(described.status,'CONTINUATION_DESCRIBED');
  const grant=described.grant,wire={grant,approval:f.receipt('bounded-grant',digestData(grant),{scopeDigest:digestData(grant.scope)})};
  return {r,ctx,wire,directory,observed:{gateDigest:digestData(grant.humanGate),path:'record.yaml'}};
}
for(const observed of [undefined,null])test(`M1 public evaluation rejects ${observed} observation before registration`,t=>{
  const s=continuationFixture(t),before=s.r.journal.replay(s.ctx);
  assert.equal(s.r.evaluateContinuation(s.wire,observed,s.ctx).status,'POLICY');
  assert.deepEqual(s.r.journal.replay(s.ctx),before);
  assert.equal(s.r.evaluateContinuation(s.wire,s.observed,s.ctx).status,undefined);
});
test('e2e: C1 public continuation rejects a forged grant before registration',t=>{
  const s=continuationFixture(t),before=s.r.journal.replay(s.ctx),forged=structuredClone(s.wire);forged.approval.signature=fabricatedSignature;
  assert.equal(s.r.evaluateContinuation(forged,s.observed,s.ctx).status,'BLOCKED_BY_INVALID_SIGNATURE');
  assert.deepEqual(s.r.journal.replay(s.ctx),before);
  assert.equal(s.r.evaluateContinuation(s.wire,s.observed,s.ctx).status,undefined);
  assert.equal(s.r.journal.replay(s.ctx).budget.spent,0);
});
test('e2e: C1 replay rejects forged recorded grant even with recomputed journal hashes',t=>{
  const s=continuationFixture(t);assert.equal(s.r.evaluateContinuation(s.wire,s.observed,s.ctx).status,undefined);
  const log=path.join(s.directory,'events.jsonl'),events=fs.readFileSync(log,'utf8').trim().split('\n').map(JSON.parse),event=events.at(-1);
  assert.equal(event.operation.kind,'continuation-grant');event.operation.wire.approval.signature=fabricatedSignature;event.requestDigest=digestData(event.operation);
  const {digest,...body}=event;event.digest=digestData(body);
  fs.writeFileSync(path.join(s.directory,'objects',event.digest+'.json'),canonical(event));fs.writeFileSync(log,events.map(canonical).join('\n')+'\n');
  assert.equal(s.r.journal.replay(s.ctx).status,'BLOCKED_BY_INVALID_SIGNATURE');
});
