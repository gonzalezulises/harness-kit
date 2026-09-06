import { z } from 'zod';
import { digestData, freeze, identifyForRepository, schemaIds } from './identity.mjs';
import { authorityBoundary, stop } from './authority.mjs';
const bytes=z.custom(v=>Buffer.isBuffer(v)||v instanceof Uint8Array);
const path=z.string().min(1).refine(v=>!v.startsWith('/')&&!v.includes('\\')&&!v.includes('\0')&&v.split('/').every(s=>s && s!=='.' && s!=='..'));
const document=z.strictObject({path,bytes});
const change=z.strictObject({path,after:bytes});
const assessment=(disposition,reason,changes=[])=>freeze({status:'ASSESSMENT',disposition,reason,changes,executionAuthorized:false,assurance:'recomputed',postconditions:'NOT_EXECUTED'});
export function openRuntime(host) {
  let auth,files;
  try {
    auth=authorityBoundary(host);
    files=z.array(z.strictObject({path,schemaId:z.enum(schemaIds),class:z.enum(['data','derived','normative','architecture','security','shared'])})).min(1).parse(host.files);
    if(new Set(files.map(f=>f.path)).size!==files.length)throw Error('duplicate path registry');
  } catch(error) {return stop('BLOCKED_BY_MISSING_AUTHORITY_BINDING',error.message);}
  const registry=new Map(files.map(f=>[f.path,freeze(f)])),contexts=new WeakMap();
  const identify=(input,schemaId)=>identifyForRepository(auth.repositoryId,input,schemaId);
  function describeBaseline(inputs) {
    try {
      const docs=z.array(document).min(1).parse(inputs),seen=new Set();
      const records=docs.map(doc=>{
        const config=registry.get(doc.path);if(!config||seen.has(doc.path))throw Error('unknown or duplicate path');seen.add(doc.path);
        const identity=identify(doc.bytes,config.schemaId);if(identity.status!=='IDENTIFIED')throw Error(identity.reason);
        return {path:doc.path,identity};
      }).sort((a,b)=>a.path.localeCompare(b.path,'en'));
      return freeze({status:'BASELINE_DESCRIBED',records,digest:digestData({domain:'harness.baseline.v1',repositoryId:auth.repositoryId,records})});
    }catch(error){return stop('UNKNOWN',error.message);}
  }
  function verifyContext(request) {
    try {
      const clean=z.strictObject({authority:z.any(),documents:z.array(document).min(1),acceptance:z.any()}).parse(request);
      const authority=auth.inspectAuthority(clean.authority);if(authority.status!=='VERIFIED_AUTHORITY')return authority;
      const baseline=describeBaseline(clean.documents);if(baseline.status!=='BASELINE_DESCRIBED')return baseline;
      if(baseline.records.some(r=>!authority.scope.paths.includes(r.path)))return stop('BLOCKED_BY_AUTHORITY_MISMATCH','baseline outside adopted scope');
      const acceptance=auth.verifyApproval(clean.acceptance,{kind:'baseline-acceptance',subjectDigest:baseline.digest,scopeDigest:digestData(authority.scope),authorityDigest:auth.authorityDigest});
      const checked=auth.inspectApproval(acceptance);if(checked.status!=='VERIFIED_APPROVAL')return acceptance;
      const handle=Object.freeze(Object.create(null));contexts.set(handle,{authority:clean.authority,acceptance,baseline});return handle;
    }catch{return stop('UNKNOWN','invalid context request');}
  }
  function inspectContext(handle) {
    const ctx=contexts.get(handle);if(!ctx)return stop('UNKNOWN','foreign or forged context handle');
    for(const status of [auth.inspectAuthority(ctx.authority),auth.inspectApproval(ctx.acceptance)])if(!['VERIFIED_AUTHORITY','VERIFIED_APPROVAL'].includes(status.status))return status;
    return freeze({status:'VERIFIED_CONTEXT',baselineDigest:ctx.baseline.digest,repositoryId:auth.repositoryId,authorityDigest:auth.authorityDigest,assurance:'host-authenticated'});
  }
  function classifyChange(request,handle) {
    try {
      const check=inspectContext(handle);if(check.status!=='VERIFIED_CONTEXT')return assessment(check.status==='UNKNOWN'?'UNKNOWN':'BLOCKED',check.reason);
      const inputs=z.strictObject({changes:z.array(change).min(1)}).parse(request).changes;
      if(new Set(inputs.map(i=>i.path)).size!==inputs.length)return assessment('UNKNOWN','duplicate change path');
      const accepted=new Map(contexts.get(handle).baseline.records.map(r=>[r.path,r.identity]));
      const results=inputs.map(input=>{
        const config=registry.get(input.path),before=accepted.get(input.path);
        if(!config||!before)return {path:input.path,disposition:'UNKNOWN',reason:'missing registered accepted before binding'};
        const after=identify(input.after,config.schemaId);
        if(after.status!=='IDENTIFIED')return {path:input.path,disposition:'UNKNOWN',reason:after.reason};
        if(before.contentSha256===after.contentSha256)return {path:input.path,disposition:'MECHANICAL_ELIGIBLE',proof:{kind:'identical-bytes.v1',before,after}};
        if(['normative','architecture','security','shared'].includes(config.class))return {path:input.path,disposition:'HUMAN_REQUIRED',reason:'protected authority class'};
        if(before.canonicalSha256===after.canonicalSha256 && before.semanticSha256===after.semanticSha256)return {path:input.path,disposition:'MECHANICAL_ELIGIBLE',proof:{kind:'canonical-reorder.v1',before,after}};
        return {path:input.path,disposition:'HUMAN_REQUIRED',reason:'no registered semantic equivalence proof'};
      });
      // Closed, nonrecursive digest derivation. Source must itself be an accepted
      // non-derived file with a recomputed eligible transformation in this batch.
      for (let index=0;index<inputs.length;index++) {
        const input=inputs[index], config=registry.get(input.path), before=accepted.get(input.path);
        if(config?.class!=='derived' || config.schemaId!=='digest.v1' || !before)continue;
        const after=identify(input.after,config.schemaId);
        const fail=reason=>({path:input.path,disposition:'UNKNOWN',reason});
        if(after.status!=='IDENTIFIED'){results[index]=fail('invalid derived document');continue;}
        const sourcePath=before.value.sourcePath, sourceBefore=accepted.get(sourcePath), sourceConfig=registry.get(sourcePath);
        const sourceIndex=inputs.findIndex(i=>i.path===sourcePath);
        if(after.value.sourcePath!==sourcePath || !sourceBefore || !sourceConfig || sourceConfig.class==='derived' || before.value.sourceContentSha256!==sourceBefore.contentSha256) {
          results[index]=fail('derived rule lacks accepted source binding');continue;
        }
        if(sourceIndex>=0 && results[sourceIndex].disposition!=='MECHANICAL_ELIGIBLE') {
          results[index]=fail('derived source transformation is not eligible');continue;
        }
        const sourceAfter=sourceIndex<0?sourceBefore:identify(inputs[sourceIndex].after,sourceConfig.schemaId);
        if(after.value.sourceContentSha256!==sourceAfter.contentSha256) {
          results[index]=fail('derived digest does not match recomputed source');continue;
        }
        results[index]={path:input.path,disposition:'MECHANICAL_ELIGIBLE',proof:{kind:'derived-content-digest.v1',sourcePath,sourceBefore,sourceAfter,before,after}};
      }
      const disposition=results.some(r=>r.disposition==='UNKNOWN')?'UNKNOWN':results.some(r=>r.disposition==='HUMAN_REQUIRED')?'HUMAN_REQUIRED':'MECHANICAL_ELIGIBLE';
      return assessment(disposition,'classification does not grant execution permission',results);
    }catch{return assessment('UNKNOWN','invalid data-only classification request');}
  }
  return Object.freeze({identify,describeBaseline,verifyContext,inspectContext,classifyChange,loadAuthority:auth.loadAuthority,inspectAuthority:auth.inspectAuthority,verifyApproval:auth.verifyApproval,inspectApproval:auth.inspectApproval});
}
