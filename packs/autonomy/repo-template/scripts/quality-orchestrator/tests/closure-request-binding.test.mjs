import test from 'node:test';
import assert from 'node:assert/strict';
import {setup,network,settle} from './closure-fixtures.mjs';

test('GR02 immutable dispatch input cannot borrow a replacement request current after preflight',async t=>{
  const s=setup(t),options={expiresAt:{slice:1010}},net=network(t,s,options);
  await settle(s,'slice-op');
  const described=s.describe('merge-op');assert.equal(described.status,'EXECUTION_DESCRIBED');assert.equal(described.request.operation,'merge');
  const wire=s.wire(described),before=s.r.journal.replay(s.ctx),dispatches=net.dispatches();let replaced=false;
  options.afterPreflight=()=>{
    s.f.setNow(1010);
    const current=s.describe('replacement-slice');assert.equal(current.status,'EXECUTION_DESCRIBED',current.reason);assert.equal(current.request.operation,'slice');
    wire.request=current.request;replaced=true;
  };
  const result=await s.r.executeReleaseObligation(s.handle,wire);
  assert.equal(replaced,true,'the replacement must occur inside the real awaited preflight');
  assert.notEqual(result.status,'EXECUTION_PENDING','validation of the replacement must not authorize the captured obsolete merge request');
  assert.equal(net.dispatches(),dispatches,'obsolete request must never reach dispatch');
  const after=s.r.journal.replay(s.ctx);assert.equal(after.budget.spent,before.budget.spent);assert.deepEqual(after.pending,[]);
  assert.equal(s.r.nextObligation(s.handle,s.r.replayRelease(s.handle)).nextObligation.kind,'verify-slice');
});

test('GR02 unchanged current dispatch input retains one reservation and the exact request',async t=>{
  const s=setup(t),net=network(t,s),described=s.describe('current-slice'),wire=s.wire(described);
  const result=await s.r.executeReleaseObligation(s.handle,wire);
  assert.equal(result.status,'EXECUTION_PENDING',result.reason);assert.equal(result.execution,'STARTED');assert.equal(net.dispatches(),1);
  assert.deepEqual([...net.runs.values()][0].descriptor.request,described.request);
  const state=s.r.journal.replay(s.ctx);assert.equal(state.budget.spent,1);assert.deepEqual(state.pending,['current-slice']);
});
