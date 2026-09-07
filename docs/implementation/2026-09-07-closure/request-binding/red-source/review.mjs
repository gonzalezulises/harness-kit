import fs from 'node:fs';
import path from 'node:path';
import {z} from 'zod';
import {parseDocument} from 'yaml';
import {canonical,digestData,sha256,freeze} from './identity.mjs';
import {stop} from './authority.mjs';
import {executionAsync} from './execution.mjs';
import {budgetLimitsSchema,mechanicalBudget} from './budget.mjs';
import {installedBundleDigest} from './capabilities.mjs';
import {reviewHostSchema,reviewInputSchema,reviewPolicySchema,reviewSchema,reviewReceiptSchema,reviewSchemaDigest,reviewJSONSchema} from './review.schema.mjs';
import {buildReviewShadow,plainReviewRoot,reviewManifest,requireReview as must} from './review-shadow.mjs';

// Operator-only bootstrap, like the journal boundary. No candidate provider,
// executable callback, containment boolean, credential or generic runner input.
export function reviewBoundary(host,runtime,auth,execution,journal,internal={}){
  const config=freeze(reviewHostSchema.parse(host)),bindings=new WeakMap(),shadows=new WeakMap();
  const primary=plainReviewRoot(config.primaryRoot),shadowRoot=plainReviewRoot(config.shadowRoot);
  must(primary!==shadowRoot&&!primary.startsWith(shadowRoot+'/')&&!shadowRoot.startsWith(primary+'/'),'review roots must be disjoint');
  must(path.isAbsolute(config.gitPath)&&fs.realpathSync(config.gitPath)===config.gitPath,'absolute resolved Git path required');
  must(new Set(config.artifacts.map(a=>a.path)).size===config.artifacts.length,'duplicate artifact path');
  for(const role of ['binary','dependency','protocol'])must(config.artifacts.some(a=>a.role===role),'missing artifact role '+role);
  must(config.artifacts.filter(a=>a.role==='binary').length===1,'one Codex executable required');
  for(const item of config.artifacts)must(path.isAbsolute(item.path)&&fs.realpathSync(item.path)===item.path,'absolute resolved artifact path required');
  const loadedBundle=installedBundleDigest(),configDigest=digestData(config),artifactsDigest=digestData(config.artifacts);
  const pins=freeze({adapterDigest:loadedBundle,configDigest,artifactsDigest,schemaDigest:reviewSchemaDigest,containment:execution?.profile.review?.containmentDigest||'UNAVAILABLE'});
  const safe=fn=>{try{return fn();}catch(e){return stop(e.reviewStatus||'POLICY',e.message);}};
  function fresh(){
    must(plainReviewRoot(primary)===primary&&plainReviewRoot(shadowRoot)===shadowRoot,'review root changed');
    must(installedBundleDigest()===loadedBundle,'adapter or dependency bytes changed','BLOCKED_BY_RUNTIME_BINDING');
    for(const a of [...config.artifacts,{path:config.gitPath,digest:config.gitDigest}])must(fs.realpathSync(a.path)===a.path&&sha256(fs.readFileSync(a.path))===a.digest,'pinned executable/dependency/protocol changed','BLOCKED_BY_RUNTIME_BINDING');
  }
  function owned(binding){const item=bindings.get(binding);must(item,'foreign or forged review binding');fresh();const approval=runtime.inspectApproval(item.approval);must(approval.status==='VERIFIED_APPROVAL',approval.reason,approval.status);return item;}
  function target(shadow,item){const result=shadows.get(shadow);must(result&&result.binding===item,'foreign, forged or different binding shadow');must(digestData(reviewManifest(primary))===result.primaryDigest,'primary manifest changed');must(digestData(reviewManifest(result.container))===result.shadowDigest,'shadow/config manifest changed');return result;}
  function describe(input){fresh();const clean=reviewInputSchema.parse(input);must(new Set(clean.modelOrder.map(m=>m.model+'\0'+m.effort)).size===clean.modelOrder.length,'duplicate model preference');const scope={objectiveId:clean.objectiveId,operationKey:clean.operationKey,budgetKind:clean.budgetKind,targetCommit:clean.targetCommit};return freeze({status:'REVIEW_POLICY_DESCRIBED',policy:{version:1,repositoryId:auth.repositoryId,...clean,scope,pins},execution:'NOT_EXECUTED'});}
  function inspect(item){return freeze({status:'REVIEW_PREFLIGHT_FROZEN',bindingDigest:item.digest,model:item.model,effort:item.effort,authMode:item.policy.authMode,schemaTransport:item.schemaTransport,schemaDigest:reviewSchemaDigest,adapterDigest:loadedBundle,promptDigest:sha256(item.policy.prompt),containment:pins.containment,catalogAssurance:item.catalog?'HOST_AUTHENTICATED':'FIXTURE',acceptance:'NOT_EXECUTED'});}
  function catalogPins(){must(execution?.profile.review,'contained remote worker is not configured','BLOCKED_BY_REQUIRED_CAPABILITY');return {...execution.profile.review,artifactsDigest,schemaDigest:reviewSchemaDigest};}
  function catalogRequest(authMode){return {version:1,domain:'harness.review.catalog.v1',operation:'catalog',authMode,pins:catalogPins()};}
  function catalogOutput(value){const result=z.strictObject({authMode:z.enum(['chatgpt','apiKey']),complete:z.literal(true),models:z.array(z.strictObject({model:z.string().min(1),efforts:z.array(z.string().min(1)).min(1)})).min(1).max(1000),remoteSchema:z.boolean(),containmentDigest:z.string(),workerDigest:z.string(),protocolDigest:z.string(),artifactsDigest:z.string(),schemaDigest:z.string()}).parse(value);must(Object.entries(catalogPins()).every(([k,v])=>result[k]===v),'catalog worker/protocol/containment mismatch');return result;}
  function localOutput(text,files,limit){
    must(typeof text==='string'&&Buffer.byteLength(text)<=limit,'review output exceeds bound');
    must(parseDocument(text,{strict:true,uniqueKeys:true}).errors.length===0,'duplicate or invalid JSON fields');const output=reviewSchema.parse(JSON.parse(text));
    must(new Set(output.findings.map(f=>f.id)).size===output.findings.length,'duplicate finding id');must(output.verdict===(output.findings.length?'FAIL':'PASS'),'verdict contradicts findings');
    for(const finding of output.findings)must(Object.hasOwn(files,finding.path)&&finding.line<=files[finding.path].lines,'finding location does not resolve in exact shadow');return output;
  }
  function reviewRequest(binding,shadow,releaseBinding,at=auth.freshness()){
    const item=owned(binding),s=target(shadow,item);must(item.catalog,'authenticated catalog required','BLOCKED_BY_REQUIRED_CAPABILITY');
    must(item.catalog.observation.issuedAt<=at&&item.catalog.observation.expiresAt>at,'authenticated catalog expired','BLOCKED_BY_REQUIRED_CAPABILITY');
    const files=Object.fromEntries(Object.keys(s.files).sort().map(name=>[name,{...s.files[name],bytesBase64:fs.readFileSync(path.join(s.directory,name)).toString('base64')}]));
    const expectedReceipt={repositoryId:auth.repositoryId,objectiveId:item.policy.objectiveId,operationKey:item.policy.operationKey,targetCommit:item.policy.targetCommit,targetManifestDigest:s.manifestDigest,promptDigest:sha256(item.policy.prompt),bindingDigest:item.digest,adapterDigest:loadedBundle,model:item.model,effort:item.effort,authMode:item.policy.authMode,schemaDigest:reviewSchemaDigest,primaryBeforeDigest:s.primaryDigest,primaryAfterDigest:s.primaryDigest,exitCode:0,termination:'COMPLETED',limits:item.policy.limits};
    if(releaseBinding)must(releaseBinding.integratedCommit===item.policy.targetCommit&&releaseBinding.objectiveId===item.policy.objectiveId,'review must bind exact integrated objective');
    return {version:1,domain:'harness.review.execution.v1',operation:releaseBinding?'independent-review':'review',...(releaseBinding?{binding:releaseBinding}:{}),review:{policy:item.policy,approval:item.wireApproval,catalogDigest:item.catalog.evidenceDigest,pins:catalogPins(),files,expectedReceipt}};
  }
  function verifyRecord(record){
    fresh();const request=record.descriptor.request,p=request.review;must(['review','independent-review'].includes(request.operation)&&p,'registered review request required');
    must(canonical(p.pins)===canonical(catalogPins()),'review worker pins changed','BLOCKED_BY_RUNTIME_BINDING');
    const policy=reviewPolicySchema.parse(p.policy),checked=auth.verifyRecordedApproval(p.approval,{kind:'bounded-grant',subjectDigest:digestData(policy),scopeDigest:digestData(policy.scope),authorityDigest:auth.authorityDigest},record.observation.issuedAt);must(checked.status==='VERIFIED_RECORDED_APPROVAL',checked.reason,checked.status);
    must(digestData(reviewManifest(primary))===p.expectedReceipt.primaryBeforeDigest&&p.expectedReceipt.primaryAfterDigest===p.expectedReceipt.primaryBeforeDigest,'primary manifest changed since review dispatch');
    const raw=z.strictObject({output:z.string(),receipt:reviewReceiptSchema}).parse(record.observation.output),output=localOutput(raw.output,p.files,policy.limits.maxOutputBytes);
    must(!raw.receipt.simulation&&raw.receipt.rawOutputDigest===sha256(raw.output)&&Object.entries(p.expectedReceipt).every(([k,v])=>canonical(raw.receipt[k])===canonical(v)),'review execution receipt mismatch');
    return freeze({status:'REVIEW_VERIFIED',...output,independentReviewVerified:true,assurance:'host-authenticated',evidenceDigest:record.evidenceDigest,counterexamples:'NOT_EXECUTED',unresolvedHighCritical:output.findings.filter(f=>['High','Critical'].includes(f.severity)).length});
  }
  Object.assign(internal,{request:reviewRequest,verifyRecord,context:binding=>owned(binding).ctx});
  return {
    describeReviewCatalog:(input,ctx)=>safe(()=>{fresh();const value=z.strictObject({operationKey:z.string().min(1).max(200),authMode:z.enum(['chatgpt','apiKey']),limits:budgetLimitsSchema}).parse(input);return execution.describe(catalogRequest(value.authMode),{...value,budgetKind:mechanicalBudget},ctx);}),
    executeReviewCatalog:(wire,ctx)=>executionAsync(async()=>{const validateStart=()=>{fresh();must(canonical(wire?.request)===canonical(catalogRequest(wire?.request?.authMode)),'catalog request changed');};validateStart();return execution.execute(wire,ctx,validateStart);}),
    resumeReviewCatalog:(key,ctx)=>executionAsync(async()=>{fresh();const result=await execution.resume(key,ctx),record=execution.records(ctx).find(r=>r.descriptor.operationKey===key);must(record?.descriptor.request.operation==='catalog','not a catalog operation');catalogOutput(record.observation.output);return result;}),
    describeReviewExecution:(binding,shadow,input)=>safe(()=>{const item=owned(binding),value=z.strictObject({limits:budgetLimitsSchema}).parse(input);return execution.describe(reviewRequest(binding,shadow),{...value,operationKey:item.policy.operationKey,budgetKind:item.policy.budgetKind},item.ctx);}),
    resumeReview:(binding,shadow)=>executionAsync(async()=>{const item=owned(binding);target(shadow,item);await execution.resume(item.policy.operationKey,item.ctx);target(shadow,item);const record=execution.records(item.ctx).find(r=>r.descriptor.operationKey===item.policy.operationKey);must(record&&canonical(record.descriptor.request)===canonical(reviewRequest(binding,shadow,undefined,record.reservedAt)),'review request binding changed');must(record.observation.expiresAt>auth.freshness(),'review observation expired','BLOCKED_BY_STALE_AUTHORITY');return verifyRecord(record);}),
    describeReviewPolicy:input=>safe(()=>describe(input)),
    preflightReview:(wire,ctx)=>safe(()=>{
      const clean=z.strictObject({policy:reviewPolicySchema,approval:z.any()}).parse(wire),policy=clean.policy;
      const approval=runtime.verifyApproval(clean.approval,{kind:'bounded-grant',subjectDigest:digestData(policy),scopeDigest:digestData(policy.scope),authorityDigest:auth.authorityDigest});must(!approval.status,approval.reason,approval.status);
      fresh();must(canonical(policy.pins)===canonical(pins),'review policy pins changed','BLOCKED_BY_RUNTIME_BINDING');
      const {version,repositoryId,scope,pins:ignored,...input}=policy;must(repositoryId===auth.repositoryId&&canonical(describe(input).policy)===canonical(policy),'review policy scope mismatch');
      let observation=config.observation,catalog;
      if(execution?.profile.review){
        const records=execution.records(ctx).filter(r=>r.descriptor.request.operation==='catalog'&&canonical(r.descriptor.request)===canonical(catalogRequest(policy.authMode)));
        catalog=records.at(-1);must(catalog&&catalog.observation.expiresAt>auth.freshness(),'authenticated catalog preflight not executed or stale','BLOCKED_BY_REQUIRED_CAPABILITY');
        observation=catalogOutput(catalog.observation.output);
      }else must(observation.status==='FIXTURE','authenticated catalog preflight not executed','BLOCKED_BY_REQUIRED_CAPABILITY');must(observation.complete,'partial model catalog is not capability discovery','BLOCKED_BY_REQUIRED_CAPABILITY');must(observation.authMode===policy.authMode,'authentication mode mismatch','BLOCKED_BY_AUTHORITY_MISMATCH');
      must(new Set(observation.models.map(m=>m.model)).size===observation.models.length,'ambiguous duplicate catalog models');
      const selected=policy.modelOrder.find(p=>observation.models.some(m=>m.model===p.model&&m.efforts.includes(p.effort)));must(selected,'no approved compatible model and effort','BLOCKED_BY_REQUIRED_CAPABILITY');
      const item={policy,approval,wireApproval:clean.approval,ctx,catalog,...selected,schemaTransport:observation.remoteSchema?'REMOTE_AND_LOCAL':'LOCAL_ONLY'};item.digest=digestData({policy,model:item.model,effort:item.effort,schemaTransport:item.schemaTransport,...(catalog?{catalogDigest:catalog.evidenceDigest}:{})});
      const binding=Object.freeze(Object.create(null));bindings.set(binding,item);return binding;
    }),
    inspectReviewBinding:binding=>safe(()=>inspect(owned(binding))),
    createReviewShadow:binding=>safe(()=>{const item=owned(binding);if(item.shadow){target(item.shadow,item);return item.shadow;}const built=buildReviewShadow(config,item.policy.targetCommit),handle=Object.freeze(Object.create(null));shadows.set(handle,{...built,binding:item});item.shadow=handle;return handle;}),
    inspectReviewShadow:shadow=>safe(()=>{const item=shadows.get(shadow);must(item,'foreign or forged shadow');fresh();target(shadow,item.binding);return freeze({status:'REVIEW_SHADOW_BUILT',directory:item.directory,commit:item.commit,manifestDigest:item.manifestDigest,primaryDigest:item.primaryDigest,assurance:'TRUSTED_RUNTIME_EXCLUSIVE',execution:'NOT_EXECUTED'});}),
    describeReviewRound:(binding,shadow)=>safe(()=>{
      const item=owned(binding),s=target(shadow,item);
      // A data-only transport plan, not permission to start a session. Every
      // round repeats pinned values; callers cannot supply override fields.
      return freeze({status:'REVIEW_ROUND_DESCRIBED',execution:'NOT_EXECUTED',thread:{model:item.model,modelProvider:'openai',cwd:s.directory,sandbox:'read-only',approvalPolicy:'never',ephemeral:true,config:{model_reasoning_effort:item.effort}},turn:{model:item.model,effort:item.effort,cwd:s.directory,approvalPolicy:'never',...(item.schemaTransport==='REMOTE_AND_LOCAL'?{outputSchema:reviewJSONSchema}:{})},containment:'UNAVAILABLE'});
    }),
    reviewRun:(binding,shadow,wire)=>{if(execution?.profile.review)return executionAsync(async()=>{const item=owned(binding),validateStart=()=>{must(canonical(wire?.request)===canonical(reviewRequest(binding,shadow)),'review request changed');must(wire.budget.scope.operationKey===item.policy.operationKey&&wire.budget.scope.budgetKind===item.policy.budgetKind,'review budget scope mismatch');};validateStart();return execution.execute(wire,item.ctx,validateStart);});return safe(()=>{
      const item=owned(binding);target(shadow,item);
      // No available production backend exists. In particular neither fixture
      // discovery nor CLI sandbox flags establish process/network containment.
      // Known unavailability precedes any spendBudget call. A future supported
      // host must reserve through that existing API immediately before launch.
      return freeze({status:'BLOCKED_BY_REQUIRED_CAPABILITY',reason:'tested OS containment and authenticated independent session unavailable',execution:'NOT_EXECUTED',acceptance:'NOT_EXECUTED',rawOutput:null,executionReceipt:null,budgetReceipt:null});
    });},
    validateReview:(raw,binding)=>safe(()=>{
      const item=owned(binding);must(item.shadow,'trusted target shadow required');const s=target(item.shadow,item);
      const value=z.strictObject({output:z.string(),receipt:reviewReceiptSchema.nullable()}).parse(raw);must(Buffer.byteLength(value.output)<=item.policy.limits.maxOutputBytes,'review output exceeds bound');
      const parsed=JSON.parse(value.output);must(parseDocument(value.output,{strict:true,uniqueKeys:true}).errors.length===0,'duplicate or invalid JSON fields');const output=reviewSchema.parse(parsed);
      must(new Set(output.findings.map(f=>f.id)).size===output.findings.length,'duplicate finding id');must(output.verdict===(output.findings.length?'FAIL':'PASS'),'verdict contradicts findings');
      for(const finding of output.findings){const file=s.files[finding.path];must(file&&finding.line<=file.lines,'finding location does not resolve in exact shadow');}
      if(value.receipt){const expected={repositoryId:auth.repositoryId,objectiveId:item.policy.objectiveId,operationKey:item.policy.operationKey,targetCommit:item.policy.targetCommit,targetManifestDigest:s.manifestDigest,promptDigest:sha256(item.policy.prompt),bindingDigest:item.digest,adapterDigest:loadedBundle,rawOutputDigest:sha256(value.output),model:item.model,effort:item.effort,authMode:item.policy.authMode,schemaDigest:reviewSchemaDigest,primaryBeforeDigest:s.primaryDigest,primaryAfterDigest:s.primaryDigest,exitCode:0,termination:'COMPLETED',limits:item.policy.limits};
        must(Object.entries(expected).every(([key,valueExpected])=>canonical(value.receipt[key])===canonical(valueExpected)),'execution receipt binding or termination mismatch');
        return stop('BLOCKED_BY_MISSING_AUTHORITY_BINDING','raw or fixture execution receipt has no authenticated host supervisor provenance');
      }
      return freeze({status:'REVIEW_OUTPUT_VALIDATED',...output,assurance:'recomputed',acceptance:'NOT_EXECUTED',independentReviewVerified:false,counterexamples:'NOT_EXECUTED',unresolvedHighCritical:output.findings.filter(f=>['High','Critical'].includes(f.severity)).length});
    })
  };
}
