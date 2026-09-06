import { z } from 'zod';
import { canonical, digestData, freeze } from './identity.mjs';
import { stop } from './authority.mjs';
import { budgetLimitsSchema, budgetKindSchema } from './budget.mjs';
const hash=z.string().regex(/^[a-f0-9]{64}$/),id=z.string().min(1).max(200);
const paths=z.array(id).min(1).max(100).refine(v=>new Set(v).size===v.length);
const base64=z.string().max(2*1024*1024).refine(v=>Buffer.from(v,'base64').toString('base64')===v);
const regression=z.strictObject({path:id,afterBase64:base64,expected:z.enum(['MECHANICAL_ELIGIBLE','HUMAN_REQUIRED'])});
export const humanGateSchema=z.strictObject({version:z.literal(1),acId:id,defectClass:z.literal('canonical-record-representation'),violatedRule:z.literal('canonical-record.v1'),authorityDigest:hash,baselineDigest:hash,invariantDigest:hash,regressions:z.array(regression).min(2).max(200)});
export const remediationGrantSchema=z.strictObject({version:z.literal(1),domain:z.literal('harness.continuation.v1'),humanGate:humanGateSchema,scope:z.strictObject({objectiveId:id,journalId:id,paths,capabilities:z.array(z.enum(['canonical-write.v1','derived-write.v1'])).min(1).max(2)}),limits:budgetLimitsSchema});
export const continuationWireSchema=z.strictObject({grant:remediationGrantSchema,approval:z.unknown()});
export const grantExpectation=grant=>({kind:'bounded-grant',subjectDigest:digestData(grant),scopeDigest:digestData(grant.scope),authorityDigest:grant.humanGate.authorityDigest});
const fail=(reason,status='POLICY')=>{throw Object.assign(Error(reason),{continuationStatus:status});};
const must=(value,reason,status)=>{if(!value)fail(reason,status);};
const safe=fn=>{try{return fn();}catch(e){return stop(e.continuationStatus||e.journalStatus||'POLICY',e.message);}};
export function continuationBoundary(runtime,auth,journal,files,acceptedRecords,internal) {
  const handles=new WeakMap();let active=null;
  function facts(ctx) {
    const verified=runtime.inspectContext(ctx);must(verified.status==='VERIFIED_CONTEXT',verified.reason,verified.status);
    return {authorityDigest:verified.authorityDigest,baselineDigest:verified.baselineDigest,invariantDigest:digestData({files,records:acceptedRecords(ctx)})};
  }
  function regressions(gate,scope,ctx) {
    for(const p of scope.paths)must(acceptedRecords(ctx).some(r=>r.path===p)&&files.some(f=>f.path===p&&['data','derived'].includes(f.class)),'continuation path lacks ordinary accepted scope');
    for(const r of gate.regressions){must(scope.paths.includes(r.path),'regression outside grant');const assessment=runtime.classifyChange({changes:[{path:r.path,after:Buffer.from(r.afterBase64,'base64')}]},ctx);must(assessment.disposition===r.expected,'closed regression expectation failed');
      if(r.expected==='MECHANICAL_ELIGIBLE'){const config=files.find(f=>f.path===r.path),before=acceptedRecords(ctx).find(record=>record.path===r.path)?.identity,after=runtime.identify(Buffer.from(r.afterBase64,'base64'),config?.schemaId);must(before&&after.status==='IDENTIFIED'&&before.contentSha256!==after.contentSha256&&before.canonicalSha256===after.canonicalSha256&&before.semanticSha256===after.semanticSha256,'regression must exercise changed representation with preserved identity');}}
    for(const p of scope.paths.filter(p=>files.some(f=>f.path===p&&f.class==='data')))for(const expected of ['MECHANICAL_ELIGIBLE','HUMAN_REQUIRED'])must(gate.regressions.some(r=>r.path===p&&r.expected===expected),'positive and counterexample coverage required for each source');
  }
  function verify(wire,ctx,observed,requireCurrent=true) {
    const value=continuationWireSchema.parse(wire),{grant}=value;
    const permission=auth.verifyApproval(value.approval,grantExpectation(grant));must(!permission.status,permission.reason,permission.status);
    const state=journal.read(ctx).state;
    must(grant.scope.objectiveId===state.objectiveId&&grant.scope.journalId===state.journalId,'grant objective/journal mismatch');
    must(Object.entries(facts(ctx)).every(([k,v])=>grant.humanGate[k]===v),'accepted authority, scope, threat or architecture binding changed');
    must(!state.continuations.revoked.includes(digestData(grant)),'continuation revoked','BLOCKED_BY_REVOKED_AUTHORITY');
    must(grant.limits.total===state.budget.limit&&(!state.budget.limits||canonical(grant.limits)===canonical(state.budget.limits)),'signed limits differ from objective limits');
    regressions(grant.humanGate,grant.scope,ctx);
    const binding=journal.finalBinding(ctx);if(requireCurrent)must(canonical(binding)===canonical(state.runs.at(-1)?.binding),'fresh current run required','BLOCKED_BY_STALE_RUN');
    if(observed){const defect=z.strictObject({gateDigest:hash,path:id}).parse(observed);must(defect.gateDigest===digestData(grant.humanGate)&&grant.scope.paths.includes(defect.path),'different AC, defect, rule or scope');
      const file=files.find(f=>f.path===defect.path),doc=binding.documents.find(d=>d.path===defect.path);must(file?.class==='data'&&file.schemaId==='record.v1'&&doc,'unsupported defect proof','BLOCKED_BY_REQUIRED_CAPABILITY');
      const identity=runtime.identify(Buffer.from(doc.bytesBase64,'base64'),'record.v1');must(identity.status==='IDENTIFIED','invalid defect record');
      const expected=Object.keys(identity.value).sort().map(k=>`${k}: ${k==='threshold'?identity.value[k].lexeme:JSON.stringify(identity.value[k])}\n`).join('');
      must(Buffer.from(doc.bytesBase64,'base64').toString('utf8')!==expected,'no observed canonical representation defect');
    }
    return {wire:value,ctx,state};
  }
  function inspect(handle,ctx,plan) {
    const item=handles.get(handle);must(item&&item.ctx===ctx,'foreign or forged continuation');const checked=verify(item.wire,ctx,undefined,false);
    must(checked.state.continuations.grants[digestData(item.wire.grant)],'continuation not durably registered');
    if(plan)must(item.wire.grant.scope.capabilities.includes(plan.id)&&Object.keys(plan.outputs).every(p=>item.wire.grant.scope.paths.includes(p)),'operation outside reusable grant');
    return checked;
  }
  Object.assign(internal,{has:handle=>handles.has(handle),inspect:(handle,ctx,plan)=>safe(()=>{const checked=inspect(handle,ctx,plan);return {status:'VERIFIED_CONTINUATION',grantDigest:digestData(checked.wire.grant)};})});
  return {
    describeContinuation:(input,ctx)=>safe(()=>{
      if(Array.isArray(input?.capabilities)&&input.capabilities.some(c=>!['canonical-write.v1','derived-write.v1'].includes(c)))return freeze({status:'BLOCKED_BY_REQUIRED_CAPABILITY',reason:'product/execution regression capability unavailable',execution:'NOT_EXECUTED'});
      const clean=z.strictObject({acId:id,paths,capabilities:remediationGrantSchema.shape.scope.shape.capabilities,regressions:humanGateSchema.shape.regressions,limits:budgetLimitsSchema}).parse(input),state=journal.read(ctx).state;
      const grant=remediationGrantSchema.parse({version:1,domain:'harness.continuation.v1',humanGate:{version:1,acId:clean.acId,defectClass:'canonical-record-representation',violatedRule:'canonical-record.v1',...facts(ctx),regressions:clean.regressions},scope:{objectiveId:state.objectiveId,journalId:state.journalId,paths:clean.paths,capabilities:clean.capabilities},limits:clean.limits});
      regressions(grant.humanGate,grant.scope,ctx);must(grant.limits.total===state.budget.limit,'signed total must match host objective cap');return freeze({status:'CONTINUATION_DESCRIBED',grant,execution:'NOT_EXECUTED'});
    }),
    evaluateContinuation:(wire,observed,ctx)=>safe(()=>{
      const value=verify(wire,ctx,observed),grantDigest=digestData(value.wire.grant),key='grant:'+grantDigest;
      const result=journal.append(value.state.headDigest,{kind:'continuation-grant',operationKey:key,wire:value.wire},ctx);must(result.status==='APPENDED',result.reason,result.status);
      const handle=Object.freeze(Object.create(null));handles.set(handle,{wire:freeze(value.wire),ctx});active={wire:freeze(value.wire),ctx};return handle;
    }),
    revokeContinuation:(grantDigest,operationKey,ctx)=>safe(()=>{hash.parse(grantDigest);const state=journal.read(ctx).state;return journal.append(state.headDigest,{kind:'continuation-revoke',operationKey,grantDigest},ctx);}),
    spendBudget:(kind,objectiveId,operationKey)=>safe(()=>{
      budgetKindSchema.parse(kind);must(active,'verified continuation required');const checked=verify(active.wire,active.ctx);must(objectiveId===checked.state.objectiveId,'budget objective mismatch');
      return journal.append(checked.state.headDigest,{kind:'budget-spend',operationKey,budgetKind:kind,grantDigest:digestData(active.wire.grant)},active.ctx);
    })
  };
}
