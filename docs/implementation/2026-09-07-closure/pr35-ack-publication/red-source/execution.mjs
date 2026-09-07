import {z} from 'zod';
import {canonical,digestData,freeze} from './identity.mjs';
import {stop} from './authority.mjs';
import {installedBundleDigest} from './capabilities.mjs';
import {actionsHostSchema,descriptorSchema,executionBudgetSchema,executionDomain,observationWireSchema,id} from './execution.schema.mjs';
import {githubActions} from './github-actions.mjs';
const must=(value,reason,status='POLICY')=>{if(!value)throw Object.assign(Error(reason),{executionStatus:status});};
export const executionSafe=fn=>{try{return fn();}catch(e){return stop(e.executionStatus||e.releaseStatus||e.reviewStatus||e.journalStatus||'POLICY',e.message);}};
export const executionAsync=async fn=>{try{return await fn();}catch(e){return stop(e.executionStatus||e.releaseStatus||e.reviewStatus||e.journalStatus||'INCOMPLETE',e.message);}};
export function executionBoundary(host,auth,journal){
  const {token,...profile}=actionsHostSchema.parse(host),transport=githubActions(profile,token),bundle=installedBundleDigest();
  const profileDigest=digestData(profile);
  function fresh(){must(bundle===installedBundleDigest(),'execution runtime/dependencies changed','BLOCKED_BY_RUNTIME_BINDING');const now=auth.freshness();must(typeof now==='number',now.reason,now.status);return now;}
  function capable(operation,target){fresh();must(auth.canVerifyExecution(),'execution-supervisor observation issuer is not enrolled','BLOCKED_BY_REQUIRED_CAPABILITY');must(profile.operations.includes(operation),'workflow does not register this operation','BLOCKED_BY_REQUIRED_CAPABILITY');if(target)must(profile.target&&canonical(profile.target)===canonical(target),'approved target is not configured','BLOCKED_BY_REQUIRED_CAPABILITY');}
  function expected(budget){return {kind:'execution-budget',subjectDigest:digestData(budget),scopeDigest:digestData(budget.scope),authorityDigest:auth.authorityDigest};}
  function describe(request,{operationKey,budgetKind,limits},ctx){
    capable(request.operation,request.binding?.target);id.parse(operationKey);
    const state=journal.read(ctx).state,run=state.runs.at(-1);must(run?.verdict==='OPEN','current open run required','BLOCKED_BY_STALE_RUN');
    const budget=executionBudgetSchema.parse({version:1,domain:'harness.execution-budget.v1',repositoryId:auth.repositoryId,authorityDigest:auth.authorityDigest,baselineDigest:state.baselineDigest,scope:{objectiveId:state.objectiveId,journalId:state.journalId,runId:run.runId,operationKey,budgetKind},requestDigest:digestData(request),profileDigest,limits});
    return freeze({status:'EXECUTION_DESCRIBED',request,budget,execution:'NOT_EXECUTED'});
  }
  async function execute(wire,ctx){
    fresh();const clean=z.strictObject({request:z.record(z.string(),z.unknown()),budget:executionBudgetSchema,approval:z.unknown()}).parse(wire),b=clean.budget;
    const approval=auth.verifyApproval(clean.approval,expected(b));must(!approval.status,approval.reason,approval.status);
    capable(clean.request.operation,clean.request.binding?.target);
    must(canonical(describe(clean.request,b.scope?{...b.scope,limits:b.limits}:null,ctx).budget)===canonical(b),'execution budget changed','BLOCKED_BY_AUTHORITY_MISMATCH');
    const descriptor=descriptorSchema.parse({version:1,domain:executionDomain,operationKey:b.scope.operationKey,profile,request:clean.request,budget:b,approval:clean.approval}),digest=digestData(descriptor);
    must(Buffer.byteLength(canonical(descriptor))<=60000,'execution descriptor exceeds workflow input bound');
    const before=journal.read(ctx),prior=before.intents.get(descriptor.operationKey);
    if(prior){must(prior.inputDigest===digest,'operation key reused with different inputs');return resume(descriptor.operationKey,ctx);}
    must(!before.state.pending.length,'existing operation must reconcile first','INCOMPLETE');
    // Read-only capability discovery precedes spending. Recheck authority and CAS
    // after await, then persist the exact intent before the sole POST attempt.
    await transport.preflight();fresh();const checked=auth.inspectApproval(approval);must(checked.status==='VERIFIED_APPROVAL',checked.reason,checked.status);
    const raced=journal.read(ctx).intents.get(descriptor.operationKey);
    if(raced){must(raced.inputDigest===digest,'operation key reused with different inputs');return resume(descriptor.operationKey,ctx);}
    if(clean.request.review){const catalog=records(ctx).find(record=>record.evidenceDigest===clean.request.review.catalogDigest);must(catalog?.descriptor.request.operation==='catalog'&&catalog.observation.issuedAt<=fresh()&&catalog.observation.expiresAt>fresh(),'authenticated catalog was not current at reservation','BLOCKED_BY_REQUIRED_CAPABILITY');}
    journal.putObject(descriptor);
    journal.append(before.state.headDigest,{kind:'reserve',operationKey:descriptor.operationKey,runId:b.scope.runId,units:1,inputDigest:digest,budgetKind:b.scope.budgetKind,grantDigest:digestData(b)},ctx);
    const ack=await transport.dispatch(descriptor);journal.retainAcknowledgement(digest,ack);
    return freeze({status:'EXECUTION_PENDING',operationKey:descriptor.operationKey,descriptorDigest:digest,...ack,execution:'STARTED'});
  }
  function verified(wire,descriptor,ack,recordedAt){
    const {observation:o,approval}=observationWireSchema.parse(wire),digest=digestData(descriptor);
    must(approval?.issuerRole==='execution-supervisor','execution-specific supervisor issuer role required','BLOCKED_BY_AUTHORITY_MISMATCH');
    must(o.descriptorDigest===digest&&o.operationKey===descriptor.operationKey&&o.repositoryId===profile.repositoryId&&o.workflowId===profile.workflowId&&o.workflowSha===profile.workflowSha&&o.workflowPath===profile.workflowPath&&o.contractDigest===profile.contractDigest&&o.runId===ack.runId&&o.runAttempt===ack.runAttempt&&o.outputDigest===digestData(o.output),'supervisor observation binding mismatch');
    must(o.issuedAt<=recordedAt&&o.expiresAt>o.issuedAt&&approval.issuedAt===o.issuedAt&&approval.expiresAt===o.expiresAt,'observation freshness mismatch');
    const expected={kind:'execution-observation',subjectDigest:digestData(o),scopeDigest:digestData({descriptorDigest:digest,runId:ack.runId,runAttempt:ack.runAttempt}),authorityDigest:auth.authorityDigest};
    const checked=auth.verifyRecordedApproval(approval,expected,Math.min(recordedAt,o.expiresAt-1));must(checked.status==='VERIFIED_RECORDED_APPROVAL',checked.reason,checked.status);
    const current=auth.verifyApproval(approval,expected);must(!current.status||current.status==='BLOCKED_BY_STALE_AUTHORITY',current.reason,current.status);
    return {descriptor,observation:o,approval,evidenceDigest:digestData(wire)};
  }
  function descriptorFor(intent){must(intent,'unknown execution intent');const d=descriptorSchema.parse(journal.getObject(intent.inputDigest));must(digestData(d.profile)===profileDigest,'operator workflow profile changed','BLOCKED_BY_RUNTIME_BINDING');return d;}
  function records(ctx){
    fresh();const loaded=journal.read(ctx),records=[];
    for(const event of loaded.events){if(event.operation.kind!=='outcome'||!event.operation.outputDigest)continue;
      const intent=loaded.intents.get(event.operation.intentKey);let raw;try{raw=journal.getObject(intent.inputDigest);}catch(error){if(error.code==='ENOENT')continue;throw error;}if(raw.domain!==executionDomain)continue;
      const d=descriptorFor(intent),ack=journal.readAcknowledgement(intent.inputDigest);must(ack,'execution acknowledgement missing','INCOMPLETE');
      const record=verified(journal.getObject(event.operation.outputDigest),d,ack,event.issuedAt);records.push({...record,reservedAt:loaded.keys.get(d.operationKey).issuedAt,sequence:event.sequence});
    }
    return records;
  }
  async function resume(key,ctx){
    fresh();id.parse(key);const loaded=journal.read(ctx),intent=loaded.intents.get(key),descriptor=descriptorFor(intent);
    const done=records(ctx).find(r=>r.descriptor.operationKey===key);if(done)return result(done);
    must(loaded.state.pending.includes(key),'execution intent is not pending');
    let ack=journal.readAcknowledgement(intent.inputDigest);
    if(!ack){ack=await transport.discover(descriptor);journal.retainAcknowledgement(intent.inputDigest,ack);}
    const wire=await transport.observe(ack),record=verified(wire,descriptor,ack,fresh());
    must(record.observation.expiresAt>fresh(),'new observation already expired','INCOMPLETE');
    const digest=journal.putObject(wire),head=journal.read(ctx).state.headDigest;
    journal.append(head,{kind:'outcome',operationKey:'reconcile:'+key,intentKey:key,status:'COMPLETED',outputDigest:digest},ctx);
    return result(record);
  }
  function result(record){return freeze({status:'EXECUTION_VERIFIED',operationKey:record.descriptor.operationKey,evidenceDigest:record.evidenceDigest,output:record.observation.output,assurance:'host-authenticated',execution:'COMPLETED'});}
  return {profile:freeze(profile),describe,execute,resume,records,capable};
}
