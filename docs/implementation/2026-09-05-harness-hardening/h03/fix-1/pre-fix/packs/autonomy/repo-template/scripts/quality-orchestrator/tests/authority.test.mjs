import test from 'node:test';
import assert from 'node:assert/strict';
import { fixture,bytes } from './helpers.mjs';
import { openRuntime, canonical } from '../index.mjs';
test('valid pinned adoption and accepted baseline yield opaque instance handles',()=>{
 const f=fixture();assert.equal(f.runtime.inspectAuthority(f.adopted).status,'VERIFIED_AUTHORITY');
 assert.equal(f.runtime.inspectContext(f.context()).status,'VERIFIED_CONTEXT');
 assert.equal(f.runtime.inspectAuthority({...f.adopted}).status,'UNKNOWN');
 assert.equal(fixture().runtime.inspectAuthority(f.adopted).status,'UNKNOWN');
});
for(const [name,changes] of Object.entries({repo:{repositoryId:'other'},subject:{subjectDigest:'0'.repeat(64)},scope:{scopeDigest:'0'.repeat(64)},kind:{kind:'bounded-grant'},role:{issuerRole:'bot'},issuer:{issuer:'attacker'},key:{keyId:'two'},expired:{expiresAt:999},future:{issuedAt:1001},epoch:{revocationEpoch:6},decision:{decision:'reject'}})) test('receipt '+name+' blocks even when signed',()=>{
 const f=fixture();const got=f.runtime.loadAuthority(bytes(canonical(f.authority)),f.receipt('policy-adoption',f.authorityDigest,changes));assert.notEqual(got.status,undefined);
 assert.notEqual(got.status,'VERIFIED_AUTHORITY');assert.equal(f.runtime.inspectAuthority(got).status,'UNKNOWN');
});
test('altered receipt signature and unknown fields block',()=>{
 const f=fixture(),r=f.receipt('policy-adoption',f.authorityDigest);
 for(const altered of [{...r,scopeDigest:'0'.repeat(64)},{...r,issuerRole:'admin'},{...r,trust:true},{...r,signature:'AAAA'}]) assert.equal(f.runtime.inspectAuthority(f.runtime.loadAuthority(bytes(canonical(f.authority)),altered)).status,'UNKNOWN');
});
test('missing time/revocation authority stops and revocation invalidates existing handles',()=>{
 assert.equal(openRuntime({repositoryId:'x'}).status,'BLOCKED_BY_MISSING_AUTHORITY_BINDING');
 const f=fixture();const context=f.context();f.setNow(1600);assert.equal(f.runtime.inspectContext(context).status,'BLOCKED_BY_STALE_AUTHORITY');
 const revoked=fixture({revocation:{epoch:7,asOf:900,expiresAt:2000,revokedReceiptIds:['receipt-policy-adoption']}});assert.equal(revoked.adopted.status,'BLOCKED_BY_REVOKED_AUTHORITY');
});
test('trusted inputs are copied and time/checkpoint freshness is checked repeatedly',()=>{
 const f=fixture();f.host.files[0].class='normative';f.host.revocation.epoch=8;
 assert.equal(f.runtime.inspectContext(f.context()).status,'VERIFIED_CONTEXT');
 f.setNow(2100);assert.equal(f.context().status,'BLOCKED_BY_STALE_AUTHORITY');
});
test('authority bytes reject duplicate keys, unknown policy and noncanonical serialization',()=>{
 const f=fixture(),r=f.receipt('policy-adoption',f.authorityDigest);
 for(const text of [JSON.stringify(f.authority),canonical(f.authority).replace('"version":1','"version":1,"version":1'),canonical({...f.authority,policyId:'attacker'})])assert.equal(f.runtime.inspectAuthority(f.runtime.loadAuthority(bytes(text),r)).status,'UNKNOWN');
});
test('signature domain separation prevents signatures over ordinary JSON from authorizing',()=>{
 const f=fixture(),r=f.receipt('policy-adoption',f.authorityDigest);const {signature,...body}=r;r.signature=f.signRaw(Buffer.from(canonical(body)));assert.ok(signature);
 assert.equal(f.runtime.loadAuthority(bytes(canonical(f.authority)),r).status,'BLOCKED_BY_INVALID_SIGNATURE');
});

test('adoption rejects even host-pinned signed authority for a different runtime/schema contract',()=>{
 const f=fixture({authorityOverrides:{runtimeBinding:'0'.repeat(64)}});assert.equal(f.adopted.status,'BLOCKED_BY_AUTHORITY_MISMATCH');
});
test('unavailable trusted clock is a structured stop on existing handles',()=>{
 let unavailable=false;
 const f=fixture({now:()=>{if(unavailable)throw Error('host clock unavailable');return 1000;}}),ctx=f.context();
 unavailable=true;let result;assert.doesNotThrow(()=>{result=f.runtime.inspectContext(ctx);});assert.equal(result.status,'BLOCKED_BY_STALE_AUTHORITY');
});
