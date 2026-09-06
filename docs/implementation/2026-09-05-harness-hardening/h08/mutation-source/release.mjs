import {z} from 'zod';
import {canonical,digestData,freeze} from './identity.mjs';
import {stop} from './authority.mjs';
import {releaseObjectiveSchema,releaseInputSchema,releaseSimulationSchema,releaseWireSchema} from './release.schema.mjs';
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
    // MUTATION_EXPERIMENT: deliberately omit exact receipt binding validation.
    must(!seen.has(e.operationKey),'duplicate release operation key');seen.add(e.operationKey);
    must(e.issuedAt>=priorTime&&e.issuedAt<=now&&e.expiresAt>e.issuedAt,'invalid or unordered evidence time');priorTime=e.issuedAt;
    if(e.kind==='deployment-intent'){
      must(!intent,'uncertain deployment must reconcile its original key','INCOMPLETE');
      must(e.result==='PASS','failed intent cannot authorize an operation');intent=e;
    }
    if(e.kind==='deployment'){
      must(intent&&e.intentKey===intent.operationKey&&e.approvalDigest===intent.approvalDigest,'deployment lacks exact intent and approval');
      if(e.result==='PASS'){deployment={...e,index};intent=null;}
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
    if(!deploymentCurrent)missing.push({kind:'reconcile-deployment',operationKey:deployment.intentKey});
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

export function releaseBoundary(runtime,auth,journal){
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
    // There is no authenticated release execution/receipt importer in this
    // build. H07 diagnostics and H04 reservations are not execution evidence.
    const calculated=obligations(item.objective,{events:[],now,pending:item.state.pending});
    return freeze({status:item.state.pending.length?'INCOMPLETE':'BLOCKED_BY_REQUIRED_CAPABILITY',reason:item.state.pending.length?'existing intent requires its original supervised reconciliation':'authenticated integration, review and approved target execution are unavailable',...unavailable,...calculated,journalAssurance:item.state.assurance,headDigest:item.state.headDigest});
  }
  const replayRelease=handle=>safe(()=>{const item=owned(handle),replay=Object.freeze(Object.create(null));replays.set(replay,{objective:handle,headDigest:item.state.headDigest,runId:item.state.runs.at(-1).runId});return replay;});
  return {
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
