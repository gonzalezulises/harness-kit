import {z} from 'zod';
import {canonical,digestData,freeze} from './identity.mjs';
import {stop} from './authority.mjs';
import {executionAsync,executionSafe} from './execution.mjs';
import {budgetLimitsSchema,mechanicalBudget} from './budget.mjs';
import {releaseObjectiveSchema,releaseInputSchema,releaseSimulationSchema,releaseWireSchema,releaseEvidenceSchema} from './release.schema.mjs';
const must=(value,reason,status='POLICY')=>{if(!value)throw Object.assign(Error(reason),{releaseStatus:status});};
const safe=fn=>{try{return fn();}catch(e){return stop(e.releaseStatus||e.journalStatus||'POLICY',e.message);}};
const unavailable={certification:'NOT_EXECUTED',productionPass:false,execution:'NOT_EXECUTED'};
const expectedApproval=(o,kind='bounded-grant',action)=>({kind,subjectDigest:digestData(o),scopeDigest:digestData(action?{...o.scope,action}:o.scope),authorityDigest:o.authorityDigest});

// Closed obligation calculation only. Its evidence parameter is private to this
// module: public wire data enters only through the explicitly simulated route.
// No caller-selected verifier, runner, adapter or proof factory exists.
function obligations(o,{events,now,pending=[]}){
  const binding={repositoryId:o.repositoryId,objectiveId:o.scope.objectiveId,objectiveDigest:digestData(o),integratedCommit:o.scope.integratedCommit,artifactDigest:o.scope.artifactDigest,target:o.scope.target};
  const seen=new Set();let priorTime=0,intent=null,deployment=null,rolledBack=false;
  for(const [index,e] of events.entries()){
    must(canonical(e.binding)===canonical(binding),'release evidence binding mismatch');
    must(!seen.has(e.operationKey),'duplicate release operation key');seen.add(e.operationKey);
    must(e.issuedAt>=priorTime&&e.issuedAt<=now&&e.expiresAt>e.issuedAt,'invalid or unordered evidence time');priorTime=e.issuedAt;
    if(e.kind==='deployment-intent'){
      must(!intent,'uncertain deployment must reconcile its original key','INCOMPLETE');
      must(e.result==='PASS','failed intent cannot authorize an operation');intent=e;
    }
    if(e.kind==='deployment'){
      must(intent&&e.intentKey===intent.operationKey&&e.approvalDigest===intent.approvalDigest,'deployment lacks exact intent and approval');
      // A verified terminal result settles uncertainty even when it failed.
      deployment={...e,index};intent=null;
    }
    if(e.kind==='deployment-readback'){
      must(deployment&&e.originalOperationKey===deployment.intentKey&&e.deploymentId===deployment.deploymentId,'readback lacks the original known deployment identity');
      deployment={...e,intentKey:e.originalOperationKey,index};
    }
    if(e.kind==='rollback'){
      must(deployment&&e.deploymentId===deployment.deploymentId&&e.previousDeploymentId!==e.deploymentId,'rollback lacks current deployment identity');
      // Rollback never rewrites the old success or makes the present objective
      // valid. Remediation needs a newly bound objective and fresh evidence.
      if(e.result==='PASS')rolledBack=true;
    }
  }
  const current=e=>e&&e.result==='PASS'&&e.expiresAt>now&&now-e.issuedAt<o.maxEvidenceAge;
  const latest=(kind,predicate=()=>true)=>events.findLast(e=>e.kind===kind&&predicate(e));
  const index=e=>events.indexOf(e);
  const merge=latest('merge'),verification=latest('integrated-verification'),review=latest('independent-review'),acceptance=latest('artifact-acceptance');
  const missing=[];
  for(const sliceId of o.slices)if(!current(latest('slice',e=>e.sliceId===sliceId)))missing.push({kind:'verify-slice',sliceId});
  if(!current(merge))missing.push({kind:'integrate'});
  if(!current(verification)||index(verification)<=index(merge))missing.push({kind:'revalidate-integrated-commit'});
  if(!current(review)||index(review)<=index(verification))missing.push({kind:'independent-review'});
  if(!current(acceptance)||index(acceptance)<=index(review))missing.push({kind:'accept-artifact'});
  const gate=o.externalGate&&latest('external-gate',e=>e.gateId===o.externalGate);
  if(o.externalGate&&(!current(gate)||index(gate)<=index(acceptance)))missing.push({kind:'external-gate',gateId:o.externalGate});
  if(!deployment)missing.push({kind:'deploy'});
  else {
    const deploymentCurrent=current(deployment)&&deployment.index>Math.max(index(merge),index(verification),index(review),index(acceptance),gate?index(gate):-1);
    if(!deploymentCurrent)missing.push({kind:'revalidate-deployment',operationKey:deployment.intentKey});
    const smoke=latest('smoke',e=>e.deploymentId===deployment.deploymentId),observation=latest('observability',e=>e.deploymentId===deployment.deploymentId);
    if(!current(smoke)||index(smoke)<=deployment.index)missing.push({kind:'smoke',deploymentId:deployment.deploymentId});
    if(!current(observation)||index(observation)<=deployment.index||observation.executionId===smoke?.executionId)missing.push({kind:'observability',deploymentId:deployment.deploymentId});
  }
  if(!deployment){missing.push({kind:'smoke'},{kind:'observability'});}
  let next=missing[0]||{kind:'complete'};
  if(rolledBack)next={kind:'remediate',deploymentId:deployment.deploymentId};
  // Uncertain side effects always reconcile before starting more work, even if
  // an unrelated earlier verification has since expired.
  if(intent)next={kind:'reconcile-deployment',operationKey:intent.operationKey};
  if(pending.length)next={kind:'reconcile-operation',operationKey:pending[0]};
  return freeze({nextObligation:next,unsatisfied:[...new Set([...missing.map(m=>m.kind),...(rolledBack?['remediate']:[])])],historyLength:events.length});
}
export function simulateRelease(objective,input){return safe(()=>{
  const o=releaseObjectiveSchema.parse(objective),trace=releaseSimulationSchema.parse(input);
  return freeze({status:'SIMULATION',assurance:'NON_AUTHORITATIVE',...unavailable,...obligations(o,trace)});
});}

export function releaseBoundary(runtime,auth,journal,execution,review={}){
  const objectives=new WeakMap(),replays=new WeakMap();
  function state(ctx){
    const loaded=journal.read(ctx).state,current=loaded.runs.at(-1);
    must(current&&current.verdict==='OPEN','current open run required','BLOCKED_BY_STALE_RUN');
    must(canonical(journal.finalBinding(ctx))===canonical(current.binding),'workspace changed; revalidate integrated commit in a fresh run','BLOCKED_BY_STALE_RUN');
    return loaded;
  }
  function owned(handle){
    const item=objectives.get(handle);must(item,'foreign or forged release objective');
    const approval=auth.inspectApproval(item.approval);must(approval.status==='VERIFIED_APPROVAL',approval.reason,approval.status);
    const loaded=state(item.ctx);must(loaded.runs.at(-1).binding.commit===item.objective.scope.integratedCommit,'integrated commit requires a new scoped objective','BLOCKED_BY_STALE_RUN');
    return {...item,state:loaded};
  }
  function decision(handle,replay){
    const item=owned(handle),snapshot=replays.get(replay);must(snapshot&&snapshot.objective===handle,'foreign, serialized or forged release replay');
    must(snapshot.headDigest===item.state.headDigest&&snapshot.runId===item.state.runs.at(-1).runId,'release replay is stale','BLOCKED_BY_STALE_RUN');
    const now=auth.freshness();must(typeof now==='number',now.reason,now.status);
    // Only observations reverified from backend-owned journal outcomes count.
    // Diagnostic review output and bare reservations remain non-evidence.
    const events=releaseEvents(item);
    const calculated=obligations(item.objective,{events,now,pending:item.state.pending});
    if(calculated.nextObligation.kind==='complete')return freeze({status:'PRODUCTION_PASS',certification:'VERIFIED',productionPass:true,execution:'COMPLETED',...calculated,journalAssurance:item.state.assurance,headDigest:item.state.headDigest});
    return freeze({status:item.state.pending.length?'INCOMPLETE':execution?'RELEASE_PENDING':'BLOCKED_BY_REQUIRED_CAPABILITY',reason:item.state.pending.length?'existing intent requires its original supervised reconciliation':execution?'required release obligations remain':'authenticated integration, review and approved target execution are unavailable',...unavailable,...calculated,journalAssurance:item.state.assurance,headDigest:item.state.headDigest});
  }
  const kinds={'verify-slice':'slice',integrate:'merge','revalidate-integrated-commit':'integrated-verification','independent-review':'independent-review','external-gate':'external-gate',deploy:'deployment',smoke:'smoke',observability:'observability'};
  function releaseBinding(o){return {repositoryId:o.repositoryId,objectiveId:o.scope.objectiveId,objectiveDigest:digestData(o),integratedCommit:o.scope.integratedCommit,artifactDigest:o.scope.artifactDigest,target:o.scope.target};}
  function originalDeployment(item,key){
    z.string().min(1).max(200).parse(key);
    const record=execution?.records(item.ctx).find(r=>r.descriptor.operationKey===key&&r.descriptor.request.operation==='deployment'&&r.descriptor.request.action!=='readback'&&r.descriptor.request.binding?.objectiveDigest===digestData(item.objective));
    must(record,'original deployment must have a verified terminal observation','INCOMPLETE');return record;
  }
  function actionExpectation(item,action,details){
    if(action==='deploy')return expectedApproval(item.objective,'deployment-authorization','deploy');
    if(action==='rollback')return {...expectedApproval(item.objective,'deployment-authorization','rollback'),subjectDigest:digestData({objectiveDigest:digestData(item.objective),action:'rollback',...details})};
    if(action==='readback'){
      const {operationKey}=z.strictObject({operationKey:z.string().min(1).max(200)}).parse(details),original=originalDeployment(item,operationKey);
      return {kind:'deployment-authorization',subjectDigest:digestData({objectiveDigest:digestData(item.objective),action,operationKey,sourceEvidenceDigest:original.evidenceDigest,deploymentId:original.observation.output.deploymentId}),scopeDigest:digestData({...item.objective.scope,action,operationKey}),authorityDigest:auth.authorityDigest};
    }
    must(action==='accept-artifact','unknown release approval action');
    const reviewed=releaseEvents(item).findLast(e=>e.kind==='independent-review');must(reviewed?.result==='PASS','verified review required before artifact acceptance','BLOCKED_BY_REQUIRED_CAPABILITY');
    return {kind:'artifact-acceptance',subjectDigest:digestData({objectiveDigest:digestData(item.objective),reviewEvidenceDigest:reviewed.evidenceDigest}),scopeDigest:digestData({...item.objective.scope,action}),authorityDigest:auth.authorityDigest};
  }
  function checkAction(item,action,approval,details){
    must(approval,'separate scoped '+action+' approval required','BLOCKED_BY_MISSING_AUTHORITY_BINDING');
    const checked=auth.verifyApproval(approval,actionExpectation(item,action,details));must(!checked.status,checked.reason,checked.status);
    if(action==='readback')must(approval.issuedAt>=originalDeployment(item,details.operationKey).observation.issuedAt,'readback authorization predates the original result','BLOCKED_BY_STALE_AUTHORITY');
    if(action==='accept-artifact'){const latest=releaseEvents(item).findLast(e=>e.kind==='independent-review');must(approval.issuedAt>=latest.issuedAt,'artifact acceptance predates verified review','BLOCKED_BY_STALE_AUTHORITY');}
  }
  function releaseEvents(item){
    if(!execution)return [];
    const events=[];
    for(const r of execution.records(item.ctx).filter(r=>r.descriptor.request.binding?.objectiveDigest===digestData(item.objective))){
      const request=r.descriptor.request,o=r.observation;
      must(canonical(request.binding)===canonical(releaseBinding(item.objective)),'release request binding mismatch');
      const common={version:1,operationKey:r.descriptor.operationKey,binding:request.binding,issuedAt:o.issuedAt,expiresAt:o.expiresAt,evidenceDigest:r.evidenceDigest};let output;
      if(request.operation==='independent-review'){
        must(review.verifyRecord,'contained review verifier is not configured','BLOCKED_BY_REQUIRED_CAPABILITY');const checked=review.verifyRecord(r);output={result:checked.verdict};
      }else if(request.operation==='deployment'){
        output=z.strictObject({result:z.enum(['PASS','FAIL']),deploymentId:z.string().min(1).max(200),readback:z.strictObject({integratedCommit:z.string(),artifactDigest:z.string(),target:item.objective.scope.target?releaseObjectiveSchema.shape.scope.shape.target:z.never(),deploymentId:z.string()})}).parse(o.output);
        must(output.readback.integratedCommit===request.binding.integratedCommit&&output.readback.artifactDigest===request.binding.artifactDigest&&canonical(output.readback.target)===canonical(request.binding.target)&&output.readback.deploymentId===output.deploymentId,'authenticated target readback mismatch');
      }else if(['smoke','observability'].includes(request.operation)){
        output=z.strictObject({result:z.enum(['PASS','FAIL']),deploymentId:z.string().min(1).max(200),executionId:z.string().min(1).max(200)}).parse(o.output);
        must(output.deploymentId===request.deploymentId&&output.executionId===String(o.runId),'postdeploy execution/deployment identity mismatch');
      }else if(request.operation==='rollback'){
        output=z.strictObject({result:z.enum(['PASS','FAIL']),deploymentId:z.string(),previousDeploymentId:z.string(),readback:z.strictObject({deploymentId:z.string(),target:releaseObjectiveSchema.shape.scope.shape.target})}).parse(o.output);
        must(output.deploymentId===request.deploymentId&&output.previousDeploymentId===request.previousDeploymentId&&output.readback.deploymentId===request.previousDeploymentId&&canonical(output.readback.target)===canonical(request.binding.target),'rollback readback mismatch');
      }else output=z.strictObject({result:z.enum(['PASS','FAIL'])}).parse(o.output);
      let extra={};
      if(request.operation==='artifact-acceptance'){
        const prior=events.findLast(e=>e.kind==='independent-review');must(prior?.result==='PASS','artifact acceptance lacks verified review');
        const expected={kind:'artifact-acceptance',subjectDigest:digestData({objectiveDigest:digestData(item.objective),reviewEvidenceDigest:prior.evidenceDigest}),scopeDigest:digestData({...item.objective.scope,action:'accept-artifact'}),authorityDigest:auth.authorityDigest};
        const approved=auth.verifyRecordedApproval(request.actionApproval,expected,o.issuedAt);must(approved.status==='VERIFIED_RECORDED_APPROVAL'&&approved.issuedAt>=prior.issuedAt,'artifact acceptance binding or freshness mismatch');
      }
      if(request.operation==='deployment'&&request.action==='readback'){
        const original=originalDeployment(item,request.originalOperationKey);
        must(request.originalEvidenceDigest===original.evidenceDigest&&request.deploymentId===original.observation.output.deploymentId&&output.deploymentId===request.deploymentId,'readback changed original deployment binding');
        const approved=auth.verifyRecordedApproval(request.actionApproval,actionExpectation(item,'readback',{operationKey:request.originalOperationKey}),o.issuedAt);
        must(approved.status==='VERIFIED_RECORDED_APPROVAL'&&approved.issuedAt>=original.observation.issuedAt,'readback authorization binding or freshness mismatch');
        events.push(releaseEvidenceSchema.parse({...common,kind:'deployment-readback',result:output.result,deploymentId:output.deploymentId,originalOperationKey:request.originalOperationKey,approvalDigest:digestData(request.actionApproval)}));continue;
      }
      if(['deployment','rollback'].includes(request.operation)){
        const action=request.operation==='deployment'?'deploy':'rollback',approved=auth.verifyRecordedApproval(request.actionApproval,actionExpectation(item,action,{deploymentId:request.deploymentId,previousDeploymentId:request.previousDeploymentId}),o.issuedAt);must(approved.status==='VERIFIED_RECORDED_APPROVAL',approved.reason,approved.status);
        extra={approvalDigest:digestData(request.actionApproval),deploymentId:output.deploymentId};
        if(action==='deploy'){extra.intentKey=r.descriptor.operationKey;events.push(releaseEvidenceSchema.parse({...common,kind:'deployment-intent',result:'PASS',approvalDigest:extra.approvalDigest}));common.operationKey='outcome:'+digestData(r.descriptor.operationKey);}
        else extra.previousDeploymentId=output.previousDeploymentId;
      }
      const event=releaseEvidenceSchema.parse({...common,kind:request.operation,result:output.result,...extra,...(request.sliceId?{sliceId:request.sliceId}:{}),...(request.gateId?{gateId:request.gateId}:{}),...(['smoke','observability'].includes(request.operation)?{deploymentId:output.deploymentId,executionId:output.executionId}:{})});events.push(event);
    }
    return events;
  }
  function requestFor(item,options={}){
    must(execution,'Actions backend is not configured','BLOCKED_BY_REQUIRED_CAPABILITY');
    const now=auth.freshness(),events=releaseEvents(item),next=obligations(item.objective,{events,now,pending:item.state.pending}).nextObligation;
    let operation=options.rollback?'rollback':next.kind==='accept-artifact'?'artifact-acceptance':next.kind==='revalidate-deployment'?'deployment':kinds[next.kind];must(operation,'next obligation requires separate approval or reconciliation','BLOCKED_BY_REQUIRED_CAPABILITY');
    must(!item.state.pending.length,'original operation must reconcile before new work','INCOMPLETE');execution.capable(operation,item.objective.scope.target);
    const binding=releaseBinding(item.objective);
    if(operation==='independent-review'){
      must(review.request&&options.reviewBinding&&options.reviewShadow,'exact approved review binding and shadow required','BLOCKED_BY_REQUIRED_CAPABILITY');
      must(review.context(options.reviewBinding)===item.ctx,'review belongs to a different context');return review.request(options.reviewBinding,options.reviewShadow,binding);
    }
    let extra={};
    if(operation==='artifact-acceptance'){checkAction(item,'accept-artifact',options.actionApproval);extra.actionApproval=options.actionApproval;}
    if(operation==='deployment'){
      if(next.kind==='revalidate-deployment'){
        const original=originalDeployment(item,next.operationKey);checkAction(item,'readback',options.actionApproval,{operationKey:next.operationKey});
        extra={action:'readback',originalOperationKey:next.operationKey,originalEvidenceDigest:original.evidenceDigest,deploymentId:original.observation.output.deploymentId,actionApproval:options.actionApproval};
      }else{checkAction(item,'deploy',options.actionApproval);extra.actionApproval=options.actionApproval;}
    }
    if(operation==='rollback'){
      const d=events.findLast(e=>e.kind==='deployment'&&e.result==='PASS');must(d&&options.rollback.deploymentId===d.deploymentId&&options.rollback.previousDeploymentId!==d.deploymentId,'rollback requires the current deployment and distinct previous identity');checkAction(item,'rollback',options.actionApproval,options.rollback);extra={...options.rollback,actionApproval:options.actionApproval};
    }
    if(['smoke','observability'].includes(operation))extra.deploymentId=next.deploymentId;
    return {version:1,domain:'harness.release.execution.v1',operation,binding,...extra,...(next.sliceId?{sliceId:next.sliceId}:{}),...(next.gateId?{gateId:next.gateId}:{})};
  }
  const prepared=new Map();
  const replayRelease=handle=>safe(()=>{const item=owned(handle),replay=Object.freeze(Object.create(null));replays.set(replay,{objective:handle,headDigest:item.state.headDigest,runId:item.state.runs.at(-1).runId});return replay;});
  return {
    runRelease:(handle,input)=>executionAsync(async()=>{
      const options=z.strictObject({authorizedExecutions:z.array(z.strictObject({wire:z.unknown(),input:z.record(z.string(),z.unknown())})).max(30),authorizedActions:z.array(z.unknown()).max(30),maxSteps:z.number().int().positive().max(30)}).parse(input);
      const blocked=(result,cause)=>freeze({...result,status:'OPERATIONAL_BLOCKED',interruption:{classification:'OPERATIONAL_DIAGNOSIS',cause,evidenceDigest:digestData({cause,next:result.nextObligation})}});
      for(let count=0;count<options.maxSteps;count++){
        const item=owned(handle),result=decision(handle,replayRelease(handle));if(result.status==='PRODUCTION_PASS')return result;if(!execution)return blocked(result,'REQUIRED_CAPABILITY_UNAVAILABLE');
        if(item.state.pending.length){const resumed=await runtime.resumeReleaseExecution(handle,item.state.pending[0]);if(resumed.status!=='EXECUTION_VERIFIED')return blocked(result,'ORIGINAL_OPERATION_RECONCILIATION_PENDING');continue;}
        const operation=result.nextObligation.kind==='accept-artifact'?'artifact-acceptance':result.nextObligation.kind==='revalidate-deployment'?'deployment':kinds[result.nextObligation.kind];
        const entry=options.authorizedExecutions.find(e=>e.wire?.request?.operation===operation&&canonical(e.wire.request.binding)===canonical(releaseBinding(item.objective))&&!journal.read(item.ctx).intents.has(e.wire.budget?.scope?.operationKey));
        if(!entry)return blocked(result,'EXACT_AUTHORIZED_INPUT_UNAVAILABLE');
        const requestInput={...entry.input};if(!requestInput.actionApproval&&['artifact-acceptance','deployment'].includes(operation)){
          const action=operation==='artifact-acceptance'?'accept-artifact':result.nextObligation.kind==='revalidate-deployment'?'readback':'deploy',expected=actionExpectation(item,action,action==='readback'?{operationKey:result.nextObligation.operationKey}:undefined);requestInput.actionApproval=options.authorizedActions.find(a=>a?.kind===expected.kind&&a?.subjectDigest===expected.subjectDigest&&a?.scopeDigest===expected.scopeDigest);
        }
        const described=runtime.describeReleaseExecution(handle,requestInput);if(described.status!=='EXECUTION_DESCRIBED')return blocked(result,'EXACT_AUTHORIZED_INPUT_UNAVAILABLE');must(canonical(described.request)===canonical(entry.wire.request)&&canonical(described.budget)===canonical(entry.wire.budget),'supplied release authorization differs from next exact obligation');
        const started=await runtime.executeReleaseObligation(handle,entry.wire);if(!['EXECUTION_PENDING','EXECUTION_VERIFIED'].includes(started.status))return blocked(decision(handle,replayRelease(handle)),'EXECUTION_NOT_SETTLED');
        const resumed=await runtime.resumeReleaseExecution(handle,entry.wire.budget.scope.operationKey);if(resumed.status!=='EXECUTION_VERIFIED')return blocked(decision(handle,replayRelease(handle)),'ORIGINAL_OPERATION_RECONCILIATION_PENDING');
      }
      return decision(handle,replayRelease(handle));
    }),
    describeReleaseApproval:(handle,action,details)=>safe(()=>{const item=owned(handle);return freeze({status:'RELEASE_APPROVAL_DESCRIBED',...actionExpectation(item,action,details)});}),
    describeReleaseExecution:(handle,input)=>executionSafe(()=>{
      const item=owned(handle),clean=z.strictObject({operationKey:z.string().min(1).max(200),limits:budgetLimitsSchema,actionApproval:z.unknown().optional(),reviewBinding:z.any().optional(),reviewShadow:z.any().optional(),rollback:z.strictObject({deploymentId:z.string().min(1).max(200),previousDeploymentId:z.string().min(1).max(200)}).optional()}).parse(input),request=requestFor(item,clean);
      if(request.review)must(clean.operationKey===request.review.policy.operationKey,'review operation key must match signed review policy');
      const result=execution.describe(request,{...clean,budgetKind:request.review?request.review.policy.budgetKind:mechanicalBudget},item.ctx);prepared.set(digestData(request),{handle,options:clean});return result;
    }),
    executeReleaseObligation:(handle,wire)=>executionAsync(async()=>{
      const item=owned(handle);must(execution,'Actions backend is not configured','BLOCKED_BY_REQUIRED_CAPABILITY');
      const prior=journal.read(item.ctx).intents.get(wire?.budget?.scope?.operationKey);
      if(!prior){const preparation=prepared.get(digestData(wire.request));must(preparation?.handle===handle,'describe the exact release execution before dispatch');must(canonical(wire.request)===canonical(requestFor(item,preparation.options)),'release execution request changed');}
      return execution.execute(wire,item.ctx);
    }),
    resumeReleaseExecution:(handle,key)=>executionAsync(async()=>{const item=owned(handle);must(execution,'Actions backend is not configured','BLOCKED_BY_REQUIRED_CAPABILITY');const result=await execution.resume(key,item.ctx);releaseEvents(owned(handle));return result;}),
    describeReleaseObjective:(input,ctx)=>safe(()=>{
      const clean=releaseInputSchema.parse(input),loaded=state(ctx);
      const objective=releaseObjectiveSchema.parse({version:1,domain:'harness.release.v1',repositoryId:auth.repositoryId,authorityDigest:auth.authorityDigest,baselineDigest:loaded.baselineDigest,goal:'PRODUCTION_PASS',scope:{objectiveId:loaded.objectiveId,journalId:loaded.journalId,integratedCommit:loaded.runs.at(-1).binding.commit,artifactDigest:clean.artifactDigest,target:clean.target},slices:clean.slices,externalGate:clean.externalGate,maxEvidenceAge:clean.maxEvidenceAge});
      return freeze({status:'RELEASE_OBJECTIVE_DESCRIBED',objective,...unavailable});
    }),
    bindReleaseObjective:(wire,ctx)=>safe(()=>{
      const {objective:o,approval:wireApproval}=releaseWireSchema.parse(wire),approval=auth.verifyApproval(wireApproval,expectedApproval(o));must(!approval.status,approval.reason,approval.status);
      const loaded=state(ctx);must(o.repositoryId===auth.repositoryId&&o.authorityDigest===auth.authorityDigest&&o.baselineDigest===loaded.baselineDigest&&o.scope.objectiveId===loaded.objectiveId&&o.scope.journalId===loaded.journalId&&o.scope.integratedCommit===loaded.runs.at(-1).binding.commit,'release objective context mismatch','BLOCKED_BY_AUTHORITY_MISMATCH');
      const handle=Object.freeze(Object.create(null));objectives.set(handle,{objective:freeze(o),approval,ctx});return handle;
    }),
    replayRelease,
    nextObligation:(handle,replay)=>safe(()=>decision(handle,replay)),
    certifyRelease:(handle,replay)=>safe(()=>decision(handle,replay)),
    prepareDeployment:(handle,wireApproval)=>safe(()=>{
      const item=owned(handle),approval=auth.verifyApproval(wireApproval,expectedApproval(item.objective,'deployment-authorization','deploy'));must(!approval.status,approval.reason,approval.status);
      // Exact authorization is necessary but cannot replace integration, review,
      // external gates, an approved adapter or authenticated execution evidence.
      // Known missing capability precedes all budget spending and intent writes.
      return decision(handle,replayRelease(handle));
    }),
    prepareRollback:(handle,input,wireApproval)=>safe(()=>{
      const item=owned(handle),request=z.strictObject({deploymentId:z.string().min(1).max(200),previousDeploymentId:z.string().min(1).max(200)}).parse(input);
      must(request.deploymentId!==request.previousDeploymentId,'rollback requires a different previous deployment');
      const expected={...expectedApproval(item.objective,'deployment-authorization','rollback'),subjectDigest:digestData({objectiveDigest:digestData(item.objective),action:'rollback',...request})};
      const approval=auth.verifyApproval(wireApproval,expected);must(!approval.status,approval.reason,approval.status);
      return freeze({status:'BLOCKED_BY_REQUIRED_CAPABILITY',reason:'authenticated rollback capability and target readback unavailable; no rollback or receipt created',...unavailable});
    }),
    reconcileDeployment:(handle,operationKey)=>safe(()=>{
      const item=owned(handle);z.string().min(1).max(200).parse(operationKey);
      must(item.state.pending.includes(operationKey),'unknown operation key');
      return freeze({status:'INCOMPLETE',reason:'authenticated target reconciliation unavailable; use the original operation key with its owning capability',operationKey,...unavailable});
    })
  };
}
