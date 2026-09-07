import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {canonical} from '../index.mjs';
import {productAckFixture} from './product-ack-fixture.mjs';

function contendAfterAck(f,{persistent=false,onRetry=()=>{}}={}){
 const open=fs.openSync,lock=path.join(f.journal.directory,'LOCK'),objects=path.join(f.journal.directory,'objects');let acquired=false,collisions=0;
 const owner=canonical({pid:process.pid,journalId:'fixture-owner'});
 fs.openSync=function(file,flags,...rest){
  if(String(file)===lock&&flags==='wx'&&fs.readdirSync(objects).some(n=>n.startsWith('ack-'))){
   if(!acquired){acquired=true;const fd=open(lock,'wx',0o600);fs.writeFileSync(fd,owner);fs.closeSync(fd);}
   else if(!persistent&&fs.existsSync(lock)){fs.unlinkSync(lock);onRetry();}
   if(fs.existsSync(lock))collisions++;
  }
  return open.call(this,file,flags,...rest);
 };
 return {restore(){fs.openSync=open;},get collisions(){return collisions;},lock,owner};
}
const count=f=>fs.existsSync(f.verifierCalls)?fs.readFileSync(f.verifierCalls,'utf8').trim().split('\n').filter(Boolean).length:0;
const replay=f=>f.runtime.replayProduct(f.handle);
function observe(f,result,guard){return {result,effects:count(f),state:replay(f),budget:f.runtime.journal.replay(f.ctx).budget,acknowledgements:fs.readdirSync(path.join(f.journal.directory,'objects')).filter(n=>n.startsWith('ack-')),collisions:guard.collisions};}
function cleanup(guard){guard.restore();if(fs.existsSync(guard.lock))fs.unlinkSync(guard.lock);}

test('v1 acknowledges one verifier effect after transient publication custody contention',async t=>{
 const f=productAckFixture(t),guard=contendAfterAck(f);let result;
 try{result=await f.runtime.executeProductStep(f.handle,'red:0');}finally{cleanup(guard);}
 const observed=observe(f,result,guard);t.diagnostic(JSON.stringify(observed));
 assert.ok(guard.collisions>0);assert.equal(count(f),1);assert.equal(observed.state.steps.filter(x=>x.key==='red:0').length,1);assert.equal(result.status,'PRODUCT_REPLAYED');assert.equal(observed.budget.spent,1);
 const resumed=await f.runtime.resumeProductStep(f.handle,'red:0');assert.equal(resumed.status,'PRODUCT_REPLAYED');assert.equal(count(f),1);assert.equal(f.runtime.journal.replay(f.ctx).budget.spent,1);
});
test('v1 persistent publication custody retains the original acknowledgement and charge',async t=>{
 const f=productAckFixture(t),guard=contendAfterAck(f,{persistent:true});let result,again;
 try{result=await f.runtime.executeProductStep(f.handle,'red:0');again=await f.runtime.resumeProductStep(f.handle,'red:0');assert.equal(fs.readFileSync(guard.lock,'utf8'),guard.owner);}finally{cleanup(guard);}
 const observed=observe(f,result,guard);t.diagnostic(JSON.stringify({...observed,again}));
 assert.equal(result.status,'BLOCKED_BY_OWNERSHIP');assert.equal(again.status,'BLOCKED_BY_OWNERSHIP');assert.equal(count(f),1);assert.equal(observed.state.steps.length,0);assert.equal(observed.budget.spent,1);assert.equal(observed.acknowledgements.length,1);assert.ok(guard.collisions>=2&&guard.collisions<=6);
});
test('v1 acknowledgement publication revalidates expired authority after custody is released',async t=>{
 const f=productAckFixture(t),guard=contendAfterAck(f,{onRetry:()=>f.setNow(1500)});let result;
 try{result=await f.runtime.executeProductStep(f.handle,'red:0');}finally{cleanup(guard);}
 t.diagnostic(JSON.stringify({result,effects:count(f),collisions:guard.collisions}));
 assert.equal(result.status,'BLOCKED_BY_STALE_AUTHORITY');f.setNow(1000);assert.equal(count(f),1);assert.equal(replay(f).steps.length,0);assert.equal(f.runtime.journal.replay(f.ctx).budget.spent,1);
});
