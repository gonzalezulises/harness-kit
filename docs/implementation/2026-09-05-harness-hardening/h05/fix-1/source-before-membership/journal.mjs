import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { z } from 'zod';
import { canonical, digestData, freeze } from './identity.mjs';
import { RUNTIME_BINDING, stop } from './authority.mjs';
const hash=z.string().regex(/^[a-f0-9]{64}$/),id=z.string().min(1).max(200),integer=z.number().int().nonnegative().safe();
const operationKey=id.refine(v=>!v.startsWith('reconcile:'));
const base64=z.string().max(2*1024*1024).refine(v=>Buffer.from(v,'base64').toString('base64')===v);
const storedDocument=z.strictObject({path:id,bytesBase64:base64});
const binding=z.strictObject({commit:z.string().regex(/^[a-f0-9]{40}([a-f0-9]{24})?$/),manifestDigest:hash,documents:z.array(storedDocument).min(1)});
export const runSchema=z.strictObject({version:z.literal(1),runId:hash,parentRunId:hash.nullable(),binding,verdict:z.enum(['OPEN','STALE','FAILED','INCOMPLETE'])});
const start=z.strictObject({kind:z.literal('start'),operationKey,baselineDigest:hash,budgetLimit:integer,run:runSchema});
const replace=z.strictObject({kind:z.literal('replace-run'),operationKey,oldRunId:hash,run:runSchema});
const reserve=z.strictObject({kind:z.literal('reserve'),operationKey,runId:hash,units:integer.refine(v=>v>0),inputDigest:hash,effectKind:z.literal('local-capability.v1').optional()});
const close=z.strictObject({kind:z.literal('close-run'),operationKey,runId:hash,verdict:z.enum(['STALE','FAILED','INCOMPLETE'])});
const outcome=z.strictObject({kind:z.literal('outcome'),operationKey:z.string().min(1).max(210),intentKey:id,status:z.enum(['COMPLETED','NOT_APPLIED']),outputDigest:hash.nullable()}).refine(v=>v.status==='COMPLETED'?v.outputDigest!==null:v.outputDigest===null);
const legacy=z.strictObject({kind:z.literal('legacy-import'),operationKey,format:z.literal('feature-list.v1'),bytesBase64:base64,sourceDigest:hash});
const operation=z.discriminatedUnion('kind',[start,replace,reserve,close,outcome,legacy]);
export const eventSchema=z.strictObject({version:z.literal(1),repositoryId:id,objectiveId:id,journalId:id,sequence:integer.refine(v=>v>0),previousDigest:hash.nullable(),authorityDigest:hash,runtimeDigest:hash,actorId:id,issuedAt:integer,requestDigest:hash,operation,digest:hash});
export const witnessSchema=z.strictObject({version:z.literal(1),repositoryId:id,objectiveId:id,journalId:id,sequence:integer,headDigest:hash.nullable(),previousWitnessDigest:hash.nullable(),authorityDigest:hash,runtimeDigest:hash,issuedAt:integer});
export const JOURNAL_RUNTIME_BINDING=digestData({protocol:'harness.journal.v1',runtimeBinding:RUNTIME_BINDING,contracts:{event:z.toJSONSchema(eventSchema,{unrepresentable:'any'}),run:z.toJSONSchema(runSchema),witness:z.toJSONSchema(witnessSchema)}});
const rawHash=bytes=>createHash('sha256').update(bytes).digest('hex');
const fail=(status,reason)=>{throw Object.assign(Error(reason),{journalStatus:status});};
const must=(condition,reason,status='INCOMPLETE')=>{if(!condition)fail(status,reason);};
function parseCanonical(bytes,schema) {
  const text=new TextDecoder('utf-8',{fatal:true}).decode(bytes),value=schema.parse(JSON.parse(text));
  must(canonical(value)===text,'noncanonical or duplicate object fields');return value;
}
// Only the host constructor calls this factory. Host readers are trusted acquisition
// adapters; returned data is still checked here. They never decide verification.
export function journalBoundary(host,runtime,auth,contextPaths,internal={}) {
  const config=z.strictObject({directory:z.string().min(1),objectiveId:id,journalId:id,actorId:id,budgetLimit:integer,readFinalBinding:z.custom(v=>typeof v==='function'),readLatestWitness:z.custom(v=>typeof v==='function').optional(),compareAndAppendWitness:z.custom(v=>typeof v==='function').optional(),reconcileOperation:z.custom(v=>typeof v==='function').optional()}).parse(host);
  must(path.isAbsolute(config.directory),'host journal directory must be absolute','POLICY');
  const directory=config.directory,objects=path.join(directory,'objects'),log=path.join(directory,'events.jsonl'),headFile=path.join(directory,'HEAD'),lockFile=path.join(directory,'LOCK'),floorFile=path.join(directory,'WITNESS');
  fs.mkdirSync(objects,{recursive:true,mode:0o700});
  const scopeDigest=digestData({objectiveId:config.objectiveId,journalId:config.journalId});
  const common={version:1,repositoryId:auth.repositoryId,objectiveId:config.objectiveId,journalId:config.journalId,authorityDigest:auth.authorityDigest,runtimeDigest:JOURNAL_RUNTIME_BINDING};
  const safe=fn=>{try{return fn();}catch(error){return stop(error.journalStatus||'INCOMPLETE',error.message);}};
  function context(handle) {
    const checked=runtime.inspectContext(handle);must(checked.status==='VERIFIED_CONTEXT',checked.reason||'verified context required',checked.status);return checked;
  }
  function syncDirectory(dir) {const fd=fs.openSync(dir,'r');try{fs.fsyncSync(fd);}finally{fs.closeSync(fd);}}
  function writeExclusive(file,bytes) {
    let fd;
    try{fd=fs.openSync(file,'wx',0o600);}catch(error){if(error.code==='EEXIST'){must(fs.readFileSync(file).equals(Buffer.from(bytes)),'content object collision or altered bytes');return;}throw error;}
    try{fs.writeFileSync(fd,bytes);fs.fsyncSync(fd);}finally{fs.closeSync(fd);}syncDirectory(path.dirname(file));
  }
  function writeIndex(file,value) {
    const tmp=file+'.tmp',bytes=canonical(value);let fd;
    try {fd=fs.openSync(tmp,'w',0o600);fs.writeFileSync(fd,bytes);fs.fsyncSync(fd);}finally{if(fd!==undefined)fs.closeSync(fd);}
    fs.renameSync(tmp,file);syncDirectory(directory);
  }
  function exclusive(fn) {
    let fd;
    try{fd=fs.openSync(lockFile,'wx',0o600);}catch(error){if(error.code==='EEXIST')fail('BLOCKED_BY_OWNERSHIP','existing owner requires explicit scoped recovery; elapsed time is insufficient');throw error;}
    try{fs.writeFileSync(fd,canonical({pid:process.pid,journalId:config.journalId}));fs.fsyncSync(fd);syncDirectory(directory);return fn();}
    finally{fs.closeSync(fd);fs.unlinkSync(lockFile);syncDirectory(directory);}
  }
  function validateBinding(value,ctx) {
    const clean=binding.parse(value),documents=clean.documents.map(d=>({path:d.path,bytes:Buffer.from(d.bytesBase64,'base64')}));
    const paths=documents.map(d=>d.path).sort();must(canonical(paths)===canonical(contextPaths(ctx).sort()),'final manifest must cover exactly the accepted context','POLICY');
    const baseline=runtime.describeBaseline(documents);must(baseline.status==='BASELINE_DESCRIBED'&&baseline.digest===clean.manifestDigest,'final manifest binding mismatch','POLICY');
    const assessed=runtime.classifyChange({changes:documents.map(d=>({path:d.path,after:d.bytes}))},ctx);
    must(assessed.disposition==='MECHANICAL_ELIGIBLE','final bytes do not preserve accepted semantics','POLICY');return clean;
  }
  function finalBinding(ctx) {
    const data=z.strictObject({commit:binding.shape.commit,documents:z.array(z.strictObject({path:id,bytes:z.custom(v=>Buffer.isBuffer(v)||v instanceof Uint8Array)})).min(1)}).parse(config.readFinalBinding());
    const manifest=runtime.describeBaseline(data.documents);must(manifest.status==='BASELINE_DESCRIBED','invalid final workspace manifest','POLICY');
    return validateBinding({commit:data.commit,manifestDigest:manifest.digest,documents:data.documents.map(d=>({path:d.path,bytesBase64:Buffer.from(d.bytes).toString('base64')})).sort((a,b)=>a.path.localeCompare(b.path))},ctx);
  }
  function makeRun(parentRunId,value,key) {
    return {version:1,runId:digestData({domain:'harness.run.v1',...common,parentRunId,binding:value,operationKey:key}),parentRunId,binding:value,verdict:'OPEN'};
  }
  function read(ctx) {
    const verified=context(ctx),state={status:'REPLAYED',assurance:'LOCAL_UNWITNESSED',...common,sequence:0,headDigest:null,baselineDigest:verified.baselineDigest,budget:{limit:config.budgetLimit,spent:0},runs:[],pending:[],legacy:null};
    const events=[],keys=new Map(),intents=new Map();
    const data=fs.existsSync(log)?fs.readFileSync(log):Buffer.alloc(0);
    must(data.length===0||data.at(-1)===10,'partial journal tail retained; authorized recovery required');
    for(const line of data.length?data.subarray(0,-1).toString('utf8').split('\n'):[]) {
      const event=parseCanonical(Buffer.from(line),eventSchema),{digest,...body}=event;
      must(digestData(body)===digest,'event content digest mismatch');
      must(Object.entries(common).every(([key,value])=>event[key]===value)&&event.actorId===config.actorId,'event runtime/repository/authority/actor mismatch');
      must(event.sequence===state.sequence+1&&event.previousDigest===state.headDigest,'event sequence or previous digest mismatch');
      must(event.issuedAt<=auth.freshness(),'event time is in the future');
      must(fs.readFileSync(path.join(objects,digest+'.json')).equals(Buffer.from(line)),'event object differs from journal bytes');
      const op=event.operation;must(event.requestDigest===digestData(op),'operation request digest mismatch');must(!keys.has(op.operationKey),'duplicate operation key');
      const current=state.runs.at(-1);
      if(op.kind==='start') {
        must(state.sequence===0&&op.baselineDigest===verified.baselineDigest&&op.budgetLimit===config.budgetLimit,'invalid objective genesis');
        validateBinding(op.run.binding,ctx);must(canonical(op.run)===canonical(makeRun(null,op.run.binding,op.operationKey)),'invalid initial run');state.runs.push({...op.run});
      } else {
        must(state.sequence>0,'objective genesis is missing');
        if(op.kind==='replace-run') {
          must(current?.runId===op.oldRunId&&state.pending.length===0,'fresh run does not replace current settled run');
          validateBinding(op.run.binding,ctx);must(canonical(op.run)===canonical(makeRun(op.oldRunId,op.run.binding,op.operationKey)),'invalid fresh run lineage');
          must(canonical(op.run.binding)!==canonical(current.binding),'run is not stale');
          // Previous records, including OPEN, remain immutable. The lineage says
          // which run is current; it never overwrites an earlier verdict.
          state.runs.push({...op.run});
        } else if(op.kind==='reserve') {
          must(current?.runId===op.runId&&current.verdict==='OPEN','reservation requires current open run');must(!state.pending.length,'unreconciled operation intent','INCOMPLETE');
          must(op.units<=state.budget.limit-state.budget.spent,'objective budget exhausted','BUDGET_EXHAUSTED');state.budget.spent+=op.units;intents.set(op.operationKey,op);state.pending.push(op.operationKey);
        } else if(op.kind==='outcome') {
          must(state.pending.includes(op.intentKey),'outcome has no pending intent');state.pending=state.pending.filter(key=>key!==op.intentKey);
        } else if(op.kind==='close-run') {
          must(current?.runId===op.runId&&current.verdict==='OPEN','terminal run verdict is immutable');current.verdict=op.verdict;
        } else if(op.kind==='legacy-import') {
          must(!state.legacy,'legacy bytes already imported');const bytes=Buffer.from(op.bytesBase64,'base64');must(rawHash(bytes)===op.sourceDigest,'legacy source digest mismatch');legacyFeatures(bytes);state.legacy=op;
        }
      }
      state.sequence=event.sequence;state.headDigest=digest;keys.set(op.operationKey,event);events.push(event);
    }
    return {state,events,keys,intents};
  }
  function legacyFeatures(bytes) {
    must(bytes.length<=1024*1024,'legacy import exceeds 1MiB','POLICY');
    const value=JSON.parse(new TextDecoder('utf8',{fatal:true}).decode(bytes));must(Array.isArray(value.features)&&value.features.every(f=>typeof f.id==='string'&&f.id.length>0),'legacy feature list required','POLICY');
    must(new Set(value.features.map(f=>f.id)).size===value.features.length,'duplicate legacy feature ids','POLICY');return value.features;
  }
  const receipt=event=>freeze({status:'APPENDED',sequence:event.sequence,headDigest:event.digest,operationKey:event.operation.operationKey,requestDigest:event.requestDigest});
  function append(expectedHead,op,ctx) {
    return exclusive(()=>{
      const before=read(ctx);op=operation.parse(op);const existing=before.keys.get(op.operationKey);
      if(existing){must(existing.requestDigest===digestData(op),'operation key reused with different inputs','POLICY');return receipt(existing);}
      must(expectedHead===before.state.headDigest,'journal head changed','CONFLICT');
      const issuedAt=auth.freshness();must(typeof issuedAt==='number','fresh authority required','BLOCKED_BY_STALE_AUTHORITY');
      const body={...common,sequence:before.state.sequence+1,previousDigest:before.state.headDigest,actorId:config.actorId,issuedAt,requestDigest:digestData(op),operation:op};
      const event={...body,digest:digestData(body)},encoded=canonical(event);
      // Validate transition against exactly the same reducer before durable append.
      validateTransition(before,op,ctx);
      writeExclusive(path.join(objects,event.digest+'.json'),encoded);
      const fd=fs.openSync(log,'a',0o600);try{fs.writeFileSync(fd,encoded+'\n');fs.fsyncSync(fd);}finally{fs.closeSync(fd);}syncDirectory(directory);
      writeIndex(headFile,{sequence:event.sequence,headDigest:event.digest});return receipt(event);
    });
  }
  function validateTransition(before,op,ctx) {
    const state=before.state,current=state.runs.at(-1);
    if(op.kind==='start'){must(state.sequence===0&&op.baselineDigest===state.baselineDigest&&op.budgetLimit===config.budgetLimit,'objective already started','POLICY');validateBinding(op.run.binding,ctx);}
    else {must(state.sequence>0,'objective not started','POLICY');
      if(op.kind==='replace-run'){must(current.runId===op.oldRunId,'only current run can be replaced','POLICY');must(!state.pending.length,'unreconciled operation intent');validateBinding(op.run.binding,ctx);must(canonical(current.binding)!==canonical(op.run.binding),'run is not stale','POLICY');}
      if(op.kind==='reserve'){must(canonical(finalBinding(ctx))===canonical(current.binding),'workspace binding changed; create a fresh run','BLOCKED_BY_STALE_RUN');must(current.runId===op.runId&&current.verdict==='OPEN','current open run required','POLICY');must(!state.pending.length,'unreconciled operation intent');must(op.units<=state.budget.limit-state.budget.spent,'objective budget exhausted','BUDGET_EXHAUSTED');}
      if(op.kind==='outcome')must(state.pending.includes(op.intentKey),'pending intent required','POLICY');
      if(op.kind==='close-run')must(current.runId===op.runId&&current.verdict==='OPEN','terminal verdict is immutable','POLICY');
      if(op.kind==='legacy-import'){must(!state.legacy,'legacy already imported','POLICY');legacyFeatures(Buffer.from(op.bytesBase64,'base64'));}
    }
  }
  function verifiedWitness(value,state) {
    const wire=z.strictObject({checkpoint:witnessSchema,receipt:z.unknown()}).parse(value),cp=wire.checkpoint;
    must(Object.entries(common).every(([key,v])=>cp[key]===v),'checkpoint domain mismatch','BLOCKED_BY_WITNESS_MISMATCH');
    const handle=runtime.verifyApproval(wire.receipt,{kind:'journal-checkpoint',subjectDigest:digestData(cp),scopeDigest,authorityDigest:auth.authorityDigest});
    const check=handle.status?handle:runtime.inspectApproval(handle);must(check.status==='VERIFIED_APPROVAL',check.reason||'checkpoint signature invalid',check.status);
    must(cp.issuedAt===check.issuedAt&&cp.issuedAt<=auth.freshness(),'checkpoint time differs from attestation','BLOCKED_BY_WITNESS_MISMATCH');
    let floor=null;
    if(fs.existsSync(floorFile))floor=parseCanonical(fs.readFileSync(floorFile),witnessSchema);
    if(floor){must(cp.sequence>=floor.sequence,'older signed checkpoint replay','BLOCKED_BY_WITNESS_ROLLBACK');if(cp.sequence===floor.sequence)must(digestData(cp)===digestData(floor),'conflicting checkpoint at same sequence','BLOCKED_BY_WITNESS_ROLLBACK');else must(cp.previousWitnessDigest===digestData(floor),'checkpoint witness chain mismatch','BLOCKED_BY_WITNESS_MISMATCH');}
    must(cp.sequence===state.sequence&&cp.headDigest===state.headDigest,'checkpoint does not match complete local head','BLOCKED_BY_WITNESS_MISMATCH');return cp;
  }
  function replay(ctx,options={}) {return safe(()=>{
    const opts=z.strictObject({requireWitness:z.boolean().optional()}).parse(options),loaded=read(ctx),state=loaded.state;
    if(opts.requireWitness){
      let wire;try{wire=config.readLatestWitness?.(auth.repositoryId,config.objectiveId);}catch{fail('BLOCKED_BY_REQUIRED_WITNESS','authenticated latest external checkpoint unavailable');}
      must(wire,'authenticated latest external checkpoint required','BLOCKED_BY_REQUIRED_WITNESS');let cp;
      try{cp=verifiedWitness(wire,state);}catch(error){if(!error.journalStatus)fail('BLOCKED_BY_WITNESS_MISMATCH','invalid checkpoint contract');throw error;}
      exclusive(()=>{const current=read(ctx).state;must(current.headDigest===state.headDigest,'journal changed while witnessing','CONFLICT');writeIndex(floorFile,cp);});state.assurance='EXTERNALLY_WITNESSED_CURRENT';state.witnessDigest=digestData(cp);
    }
    // HEAD is only a cache. Repair from the full validated chain while owning lock.
    if(!fs.existsSync(lockFile))exclusive(()=>{const current=read(ctx).state;writeIndex(headFile,{sequence:current.sequence,headDigest:current.headDigest});});
    return freeze(state);
  });}
  function describeRecovery(ctx) {
    const state=read(ctx).state,raw=fs.readFileSync(lockFile);
    const lock=parseCanonical(raw,z.strictObject({pid:integer.refine(v=>v>0),journalId:z.literal(config.journalId)}));
    const subject={domain:'harness.journal-lock-recovery.v1',...common,headDigest:state.headDigest,lockDigest:rawHash(raw)};
    return {status:'RECOVERY_DESCRIBED',subjectDigest:digestData(subject),scopeDigest:digestData({action:'release-dead-local-owner',objectiveId:config.objectiveId,journalId:config.journalId}),pid:lock.pid,headDigest:state.headDigest,lockDigest:subject.lockDigest};
  }
  Object.assign(internal,{read,append,finalBinding});
  return Object.freeze({
    replay,
    describeRecovery:ctx=>safe(()=>freeze(describeRecovery(ctx))),
    recoverLock:(ctx,approval)=>safe(()=>{
      // Recovery has a separate exclusive owner. Its own interrupted ownership
      // requires operator repair; no recursive or time-based takeover exists.
      const recoveryFile=path.join(directory,'RECOVERY');let fd;
      try{fd=fs.openSync(recoveryFile,'wx',0o600);}catch{fail('BLOCKED_BY_OWNERSHIP','recovery owner already present');}
      try{
        const described=describeRecovery(ctx),handle=runtime.verifyApproval(approval,{kind:'recovery',subjectDigest:described.subjectDigest,scopeDigest:described.scopeDigest,authorityDigest:auth.authorityDigest});
        const checked=handle.status?handle:runtime.inspectApproval(handle);must(checked.status==='VERIFIED_APPROVAL',checked.reason||'scoped recovery required',checked.status);
        let dead=false;try{process.kill(described.pid,0);}catch(error){dead=error.code==='ESRCH';}
        must(dead,'recorded local owner is alive or cannot be checked','BLOCKED_BY_OWNERSHIP');
        must(rawHash(fs.readFileSync(lockFile))===described.lockDigest,'ownership changed during recovery','CONFLICT');
        fs.unlinkSync(lockFile);syncDirectory(directory);
        return exclusive(()=>{const state=read(ctx).state;must(state.headDigest===described.headDigest,'journal changed during recovery','CONFLICT');writeIndex(headFile,{sequence:state.sequence,headDigest:state.headDigest});return freeze({status:'RECOVERED',headDigest:state.headDigest});});
      }finally{fs.closeSync(fd);fs.unlinkSync(recoveryFile);syncDirectory(directory);}
    }),
    publishCheckpoint:ctx=>safe(()=>{
      must(config.readLatestWitness&&config.compareAndAppendWitness,'external witness transport required','BLOCKED_BY_REQUIRED_WITNESS');
      const loaded=read(ctx),state=loaded.state;let prior;
      try{prior=config.readLatestWitness(auth.repositoryId,config.objectiveId);}catch{fail('BLOCKED_BY_REQUIRED_WITNESS','latest witness unavailable');}
      let previousWitnessDigest=null;
      if(prior){
        const cp=witnessSchema.parse(prior.checkpoint);must(cp.sequence<=state.sequence,'external witness is ahead of local journal','BLOCKED_BY_WITNESS_MISMATCH');
        verifiedWitness(prior,{...state,sequence:cp.sequence,headDigest:cp.sequence?loaded.events[cp.sequence-1].digest:null});previousWitnessDigest=digestData(cp);
        exclusive(()=>{must(read(ctx).state.headDigest===state.headDigest,'journal changed while retaining witness','CONFLICT');writeIndex(floorFile,cp);});
        if(cp.sequence===state.sequence)return replay(ctx,{requireWitness:true});
      }else must(!fs.existsSync(floorFile),'external witness rolled back to empty','BLOCKED_BY_WITNESS_ROLLBACK');
      const issuedAt=auth.freshness();must(typeof issuedAt==='number','current time required','BLOCKED_BY_STALE_AUTHORITY');
      const checkpoint=freeze({...common,sequence:state.sequence,headDigest:state.headDigest,previousWitnessDigest,issuedAt});
      let result;try{result=config.compareAndAppendWitness(previousWitnessDigest,checkpoint);}catch{fail('INCOMPLETE','witness append outcome uncertain; read latest before retry');}
      must(canonical(result?.checkpoint)===canonical(checkpoint),'witness returned different checkpoint','BLOCKED_BY_WITNESS_MISMATCH');verifiedWitness(result,state);
      return replay(ctx,{requireWitness:true});
    }),
    start:(ctx,key)=>safe(()=>{const verified=context(ctx),value=finalBinding(ctx);return append(null,{kind:'start',operationKey:key,baselineDigest:verified.baselineDigest,budgetLimit:config.budgetLimit,run:makeRun(null,value,key)},ctx);}),
    appendEvent:(expectedHead,input,ctx)=>safe(()=>{const parsed=z.discriminatedUnion('kind',[reserve.omit({effectKind:true}),close]).safeParse(input);must(parsed.success,'unsupported or malformed candidate event','POLICY');return append(expectedHead,parsed.data,ctx);}),
    replaceStaleRun:(expectedHead,oldRunId,key,ctx)=>safe(()=>{context(ctx);const value=finalBinding(ctx);return append(expectedHead,{kind:'replace-run',operationKey:key,oldRunId,run:makeRun(oldRunId,value,key)},ctx);}),
    reconcile:(expectedHead,key,ctx)=>safe(()=>{const loaded=read(ctx),intent=loaded.intents.get(key);must(intent,'unknown intent key','POLICY');
      must(!intent.effectKind,'local capability requires supervised postcondition reconciliation','POLICY');
      const existing=loaded.keys.get('reconcile:'+key);if(existing)return receipt(existing);
      let result;try{result=config.reconcileOperation?.(freeze({...common,...intent}));}catch{fail('INCOMPLETE','target reconciliation unavailable');}
      const parsed=z.strictObject({status:z.enum(['COMPLETED','NOT_APPLIED','UNKNOWN']),outputDigest:hash.nullable()}).safeParse(result);must(parsed.success&&parsed.data.status!=='UNKNOWN','target cannot reconcile immutable operation key');
      return append(expectedHead,{kind:'outcome',operationKey:'reconcile:'+key,intentKey:key,...parsed.data},ctx);
    }),
    importLegacy:(expectedHead,key,bytes,ctx)=>safe(()=>{must(Buffer.isBuffer(bytes)||bytes instanceof Uint8Array,'legacy bytes required','POLICY');legacyFeatures(bytes);return append(expectedHead,{kind:'legacy-import',operationKey:key,format:'feature-list.v1',bytesBase64:Buffer.from(bytes).toString('base64'),sourceDigest:rawHash(bytes)},ctx);}),
    readLegacy:ctx=>safe(()=>{const state=read(ctx).state;must(state.legacy,'no imported legacy snapshot','POLICY');return Buffer.from(state.legacy.bytesBase64,'base64');}),
    projectLegacy:ctx=>safe(()=>{const state=read(ctx).state;return freeze({mode:'v2-read-only',writable:false,provenance:{assurance:state.assurance,journalId:state.journalId,sequence:state.sequence,headDigest:state.headDigest,sourceDigest:state.legacy?.sourceDigest||null},features:state.legacy?legacyFeatures(Buffer.from(state.legacy.bytesBase64,'base64')).map(f=>({id:f.id,state:'blocked',verificationStatus:'LEGACY_UNVERIFIED'})):[],runs:state.runs});})
  });
}
