import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {productCorrectionFixture} from './product-corrections-fixture.mjs';

test('malformed verifier UTF-8 returns a controlled tool failure',async t=>{
 const f=productCorrectionFixture(t,{malformedVerifier:true});
 const result=await f.runtime.executeProductStep(f.handle,'red:0');
 assert.equal(result.status,'BLOCKED_TOOL_FAILURE',JSON.stringify(result));
 assert.match(result.reason,/UTF-8/);
 assert.equal(f.runtime.replayProduct(f.handle).pending.key,'red:0');
 const before=f.runtime.journal.replay(f.ctx).budget.spent;
 const pending=f.runtime.replayProduct(f.handle).pending;
 assert.equal(fs.readFileSync(f.verifierCalls,'utf8'),'call\n');
 const resumed=await f.runtime.resumeProductStep(f.handle,'red:0');
 assert.equal(resumed.status,'INCOMPLETE',JSON.stringify(resumed));
 assert.equal(fs.readFileSync(f.verifierCalls,'utf8'),'call\n');
 assert.equal(f.runtime.journal.replay(f.ctx).budget.spent,before);
 assert.deepEqual(f.runtime.replayProduct(f.handle).pending,pending);
});
