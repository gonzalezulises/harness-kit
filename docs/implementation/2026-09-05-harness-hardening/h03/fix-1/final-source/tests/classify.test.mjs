import test from 'node:test';
import assert from 'node:assert/strict';
import { fixture,bytes,sample } from './helpers.mjs';
const reordered='threshold: 100\nenabled: true\nstatus: active\ntitle: hello\n';
const change=(path,after,extra={})=>({path,after:bytes(after),...extra});
test('recomputes canonical reorder and returns assessment without execution permission',()=>{
 const f=fixture(),result=f.runtime.classifyChange({changes:[change('record.yaml',reordered)]},f.context());
 assert.equal(result.disposition,'MECHANICAL_ELIGIBLE');assert.equal(result.executionAuthorized,false);assert.equal(result.changes[0].proof.kind,'canonical-reorder.v1');
});
test('closed derived content digest update is recomputed from accepted/canonical source',()=>{
 const f=fixture(),before=f.runtime.identify(bytes(sample),'record.v1'),after=f.runtime.identify(bytes(reordered),'record.v1');
 const doc=hash=>`sourcePath: record.yaml\nsourceContentSha256: ${hash}\n`;
 const ctx=f.context([{path:'record.yaml',bytes:bytes(sample)},{path:'digest.yaml',bytes:bytes(doc(before.contentSha256))}]);
 const result=f.runtime.classifyChange({changes:[change('digest.yaml',doc(after.contentSha256)),change('record.yaml',reordered)]},ctx);
 assert.equal(result.disposition,'MECHANICAL_ELIGIBLE');assert.equal(result.changes[0].proof.kind,'derived-content-digest.v1');
 const bad=f.runtime.classifyChange({changes:[change('digest.yaml',doc('0'.repeat(64)))]},ctx);assert.equal(bad.disposition,'UNKNOWN');
});
test('semantic change, docs extension and arbitrary proof names cannot become mechanical',()=>{
 const f=fixture(),ctx=f.context();
 assert.equal(f.runtime.classifyChange({changes:[change('record.yaml',sample.replace('100','99.9'))]},ctx).disposition,'HUMAN_REQUIRED');
 for(const req of [{changes:[change('README.md','word')]},{changes:[change('record.yaml',reordered)],proofs:{testsGreen:true}},{changes:[change('record.yaml',reordered,{same_semantics:true})]},{changes:[change('record.yaml',reordered)],proofKind:'program-equivalence'}]) assert.equal(f.runtime.classifyChange(req,ctx).disposition,'UNKNOWN');
});
test('before substitution and unsigned/substituted baseline cannot be accepted',()=>{
 const f=fixture(),ctx=f.context();
 assert.equal(f.runtime.classifyChange({changes:[change('record.yaml',sample,{before:bytes(sample)})]},ctx).disposition,'UNKNOWN');
 const binding=f.runtime.describeBaseline([{path:'record.yaml',bytes:bytes(sample)}]);
 const substituted=f.runtime.verifyContext({authority:f.adopted,documents:[{path:'record.yaml',bytes:bytes(sample.replace('100','99.9'))}],acceptance:f.receipt('baseline-acceptance',binding.digest)});
 assert.equal(substituted.status,'BLOCKED_BY_AUTHORITY_MISMATCH');
});
test('forged, copied, foreign and stale contexts block',()=>{
 const f=fixture(),ctx=f.context(),request={changes:[change('record.yaml',reordered)]};
 for(const invalid of [{verified:true},{...ctx},fixture().context(),null]) assert.equal(f.runtime.classifyChange(request,invalid).disposition,'UNKNOWN');
 f.setNow(1600);assert.equal(f.runtime.classifyChange(request,ctx).disposition,'BLOCKED');
});
test('known normative changes require a human; mixed batches never partially authorize',()=>{
 const f=fixture(),ctx=f.context([{path:'record.yaml',bytes:bytes(sample)},{path:'policy.yaml',bytes:bytes(sample)}]);
 const result=f.runtime.classifyChange({changes:[change('record.yaml',reordered),change('policy.yaml',sample.replace('100','99.9'))]},ctx);
 assert.equal(result.disposition,'HUMAN_REQUIRED');assert.equal(result.executionAuthorized,false);
 const unknown=f.runtime.classifyChange({changes:[change('record.yaml',reordered),change('other.yaml',sample)]},ctx);assert.equal(unknown.disposition,'UNKNOWN');
});
test('empty batches, duplicate paths and missing before bindings are unknown',()=>{
 const f=fixture(),ctx=f.context();for(const changes of [[],[change('record.yaml',reordered),change('record.yaml',sample)],[change('digest.yaml','sourcePath: record.yaml\nsourceContentSha256: '+'0'.repeat(64))]]) assert.equal(f.runtime.classifyChange({changes},ctx).disposition,'UNKNOWN');
});
test('derived source substitution, recursive source and nonmechanical batch source block',()=>{
 const f=fixture(),id=f.runtime.identify(bytes(sample),'record.v1');
 const doc=(source,hash)=>`sourcePath: ${source}\nsourceContentSha256: ${hash}\n`;
 const ctx=f.context([{path:'record.yaml',bytes:bytes(sample)},{path:'digest.yaml',bytes:bytes(doc('record.yaml',id.contentSha256))}]);
 for(const changes of [
  [change('digest.yaml',doc('policy.yaml',id.contentSha256))],
  [change('digest.yaml',doc('digest.yaml',id.contentSha256))],
  [change('record.yaml',sample.replace('100','99.9')),change('digest.yaml',doc('record.yaml',f.runtime.identify(bytes(sample.replace('100','99.9')),'record.v1').contentSha256))]
 ]) assert.equal(f.runtime.classifyChange({changes},ctx).disposition,'UNKNOWN');
});
test('candidate cannot replace schema, trust roots, policy or execution adapter',()=>{
 const f=fixture(),ctx=f.context();
 for(const field of ['schemaId','issuerKeys','policyId','verifier','adapter','assurance'])assert.equal(f.runtime.classifyChange({changes:[change('record.yaml',reordered)], [field]:'attacker'},ctx).disposition,'UNKNOWN');
});
test('copied source bytes cannot mutate an already accepted context',()=>{
 const f=fixture(),source=bytes(sample),ctx=f.context([{path:'record.yaml',bytes:source}]);source.fill(0);
 assert.equal(f.runtime.classifyChange({changes:[change('record.yaml',reordered)]},ctx).disposition,'MECHANICAL_ELIGIBLE');
});
test('baseline order is code-unit deterministic across case and locale',()=>{
 const f=fixture({files:[{path:'a.yaml',schemaId:'record.v1',class:'data'},{path:'B.yaml',schemaId:'record.v1',class:'data'}]});
 const result=f.runtime.describeBaseline([{path:'a.yaml',bytes:bytes(sample)},{path:'B.yaml',bytes:bytes(sample)}]);
 assert.deepEqual(result.records.map(r=>r.path),['B.yaml','a.yaml']);
});
test('adding an explicit default TAG directive cannot earn canonical reorder eligibility',()=>{
 const f=fixture(),ctx=f.context();
 const result=f.runtime.classifyChange({changes:[change('record.yaml','%TAG !! tag:yaml.org,2002:\n---\n'+sample)]},ctx);
 assert.equal(result.disposition,'UNKNOWN');
 assert.equal(result.executionAuthorized,false);
 assert.equal(f.runtime.classifyChange({changes:[change('record.yaml',reordered)]},ctx).disposition,'MECHANICAL_ELIGIBLE');
});
