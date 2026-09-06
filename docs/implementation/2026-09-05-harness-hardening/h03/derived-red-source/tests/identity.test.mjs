import test from 'node:test';
import assert from 'node:assert/strict';
import { fixture,bytes,sample } from './helpers.mjs';
const id=(text,schema='record.v1')=>fixture().runtime.identify(bytes(text),schema);
test('key reorder preserves canonical and semantic identity while content changes',()=>{
  const a=id(sample), b=id('threshold: 100\nenabled: true\nstatus: active\ntitle: hello\n');
  assert.equal(a.status,'IDENTIFIED'); assert.notEqual(a.contentSha256,b.contentSha256);
  assert.equal(a.canonicalSha256,b.canonicalSha256); assert.equal(a.semanticSha256,b.semanticSha256);
  assert.equal(a.normalizerId,'typed-yaml.v1'); assert.equal(a.repositoryId,'repo-A');
  assert.match(a.schemaSha256,/^[a-f0-9]{64}$/); assert.equal(a.value.threshold.lexeme,'100');
});
for (const [name,from,to] of [
  ['lower threshold','100','99.9'],['large integers','9007199254740992','9007199254740993'],
  ['near decimals','0.10000000000000000001','0.10000000000000000002'],['signed zero','0','-0'],['exponents','1e3','1000'],['decimal spelling','1','1.0'],
]) test(name+' remains distinct',()=>{
  const a=id(sample.replace('100',from)),b=id(sample.replace('100',to));
  assert.equal(a.status,'IDENTIFIED');assert.equal(b.status,'IDENTIFIED');assert.notEqual(a.semanticSha256,b.semanticSha256);
});
test('human text whitespace and enum remain distinct',()=>{
 for(const after of [sample.replace('hello','"hello "'),sample.replace('active','paused')]) assert.notEqual(id(sample).semanticSha256,id(after).semanticSha256);
});
for(const [name,text] of [
 ['renamed field',sample.replace('threshold','limit')],['unknown field',sample+'extra: yes\n'],
 ['boolean as string',sample.replace('true','"true"')],['number as string',sample.replace('100','"100"')],['number as bool',sample.replace('100','true')],
 ['duplicate keys',sample+'title: again\n'],['alias',sample.replace('hello','&a hello')+'extra: *a\n'],
 ['tag',sample.replace('100','!!int 100')],['lossy form',sample.replace('100','.inf')],['hex',sample.replace('100','0x10')],
 ['invalid enum',sample.replace('active','invented')], ['merge key',sample+'<<: {title: changed}\n']
]) test(name+' rejects',()=>assert.equal(id(text).status,'UNKNOWN'));
test('unknown schema, schema hash claim and invalid UTF8 reject',()=>{
 const f=fixture();assert.equal(f.runtime.identify(bytes(sample),'unregistered').status,'UNKNOWN');
 assert.equal(f.runtime.identify(bytes(sample),{id:'record.v1',sha256:'0'.repeat(64)}).status,'UNKNOWN');
 assert.equal(f.runtime.identify(Buffer.from([0xff]),'record.v1').status,'UNKNOWN');
});
test('identities cannot be mutated and repository binding changes semantics',()=>{
 const a=id(sample);assert.throws(()=>{a.value.title='changed';},TypeError);
 const other=fixture({repositoryId:'repo-B'}).runtime.identify(bytes(sample),'record.v1');assert.notEqual(a.semanticSha256,other.semanticSha256);
});
