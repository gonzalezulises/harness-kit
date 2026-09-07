import test from 'node:test';
import assert from 'node:assert/strict';
import {productCorrectionFixture} from './product-corrections-fixture.mjs';

test('malformed verifier UTF-8 returns a controlled tool failure',async t=>{
 const f=productCorrectionFixture(t,{malformedVerifier:true});
 const result=await f.runtime.executeProductStep(f.handle,'red:0');
 assert.equal(result.status,'BLOCKED_TOOL_FAILURE',JSON.stringify(result));
 assert.match(result.reason,/UTF-8/);
 assert.equal(f.runtime.replayProduct(f.handle).pending.key,'red:0');
});
