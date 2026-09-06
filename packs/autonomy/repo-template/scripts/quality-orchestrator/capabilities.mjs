import fs from 'node:fs';
import path from 'node:path';
import { randomUUID } from 'node:crypto';
import { z } from 'zod';
import { canonical, digestData, sha256, freeze } from './identity.mjs';
import { stop } from './authority.mjs';
const validPath=z.string().min(1).max(200).refine(v=>!v.startsWith('/')&&!v.includes('\\')&&!v.includes('\0')&&v.split('/').every(s=>s&&s!=='.'&&s!=='..'));
const key=z.string().min(1).max(200).refine(v=>!v.startsWith('reconcile:'));
const argsSchema={
  'canonical-write.v1':z.strictObject({path:validPath,operationKey:key}),
  'derived-write.v1':z.strictObject({sourcePath:validPath,path:validPath,operationKey:key})
};
const fail=(reason,status='POLICY')=>{throw Object.assign(Error(reason),{capabilityStatus:status});};
const must=(ok,reason,status)=>{if(!ok)fail(reason,status);};
const safe=fn=>{try{return fn();}catch(e){return stop(e.capabilityStatus||'INCOMPLETE',e.message);}};
function syncDir(dir){const fd=fs.openSync(dir,'r');try{fs.fsyncSync(fd);}finally{fs.closeSync(fd);}}
function durable(file,bytes){const fd=fs.openSync(file,'wx',0o600);try{fs.writeFileSync(fd,bytes);fs.fsyncSync(fd);}finally{fs.closeSync(fd);}syncDir(path.dirname(file));}
function plainRoot(root){must(path.isAbsolute(root),'absolute host root required');let cursor=path.parse(root).root;for(const part of root.slice(cursor.length).split('/').filter(Boolean)){cursor=path.join(cursor,part);must(fs.lstatSync(cursor).isDirectory()&&!fs.lstatSync(cursor).isSymbolicLink(),'symlink or nondirectory ancestor');}return fs.realpathSync(root);}
function manifest(root){
  const result={};let total=0,count=0;
  function visit(dir,prefix=''){
    for(const name of fs.readdirSync(dir).sort()){
      const rel=prefix+name,full=path.join(dir,name),stat=fs.lstatSync(full);must(++count<=10000,'workspace entry bound exceeded');
      must(!stat.isSymbolicLink(),'symlink in workspace');
      if(stat.isDirectory()){result[rel]={kind:'directory',mode:stat.mode&0o777};visit(full,rel+'/');}
      else {must(stat.isFile()&&stat.nlink===1,'nonregular file or hardlink in workspace');total+=stat.size;must(total<=16*1024*1024,'workspace byte bound exceeded');must((stat.mode&0o222)!==0&&(stat.mode&0o7000)===0,'unsupported file mode');result[rel]={kind:'file',mode:stat.mode&0o777,digest:sha256(fs.readFileSync(full))};}
    }
  }visit(root);return result;
}
// Actual executable bundle, not a caller-provided protocol name. The operator
// pins this value in trusted host configuration; it is not an approval itself.
export function installedBundleDigest(){
  const root=import.meta.dirname,records={node:sha256(fs.readFileSync(process.execPath))};
  function walk(dir,prefix){for(const name of fs.readdirSync(dir).sort()){const full=path.join(dir,name),rel=prefix+name,st=fs.lstatSync(full);if(st.isSymbolicLink()){must(fs.realpathSync(full).startsWith(root+'/node_modules/'),'external dependency link');records[rel]={link:fs.readlinkSync(full)};}else if(st.isDirectory())walk(full,rel+'/');else if(st.isFile())records[rel]=sha256(fs.readFileSync(full));}}
  for(const name of fs.readdirSync(root).sort())if(name.endsWith('.mjs')||name==='package-lock.json'||name==='package.json')records[name]=sha256(fs.readFileSync(path.join(root,name)));
  walk(path.join(root,'node_modules'),'node_modules/');return digestData(records);
}
const loadedBundle=installedBundleDigest();
export function capabilityBoundary(host,runtime,auth,journal,files){
  const config=z.strictObject({workspace:z.string(),writablePaths:z.array(validPath),denyPaths:z.array(validPath),bundleDigest:z.string().regex(/^[a-f0-9]{64}$/),mode:z.literal('TRUSTED_RUNTIME_EXCLUSIVE')}).parse(host.capabilities);
  const root=plainRoot(config.workspace),stateRoot=plainRoot(host.journal.directory);
  must(root!==stateRoot&&!stateRoot.startsWith(root+'/')&&!root.startsWith(stateRoot+'/'),'workspace and trusted state must be disjoint');
  must(config.bundleDigest===loadedBundle&&installedBundleDigest()===loadedBundle,'actual runtime bundle differs from host binding','BLOCKED_BY_RUNTIME_BINDING');
  const directory=path.join(stateRoot,'capabilities');fs.mkdirSync(directory,{mode:0o700,recursive:true});plainRoot(directory);
  const leaseFile=path.join(directory,'LEASE'),fenceFile=path.join(directory,'FENCE'),permits=new WeakMap(),leases=new WeakMap();
  const registry=new Map(files.map(f=>[f.path,f]));
  const configDigest=digestData({...config,files,repositoryId:auth.repositoryId,authorityDigest:auth.authorityDigest});
  function fresh(ctx){const check=runtime.inspectContext(ctx);must(check.status==='VERIFIED_CONTEXT',check.reason||'verified context required',check.status);must(plainRoot(root)===root&&plainRoot(stateRoot)===stateRoot,'host root changed');must(installedBundleDigest()===loadedBundle,'runtime or dependency bytes changed','BLOCKED_BY_RUNTIME_BINDING');return check;}
  function owned(handle){const lease=leases.get(handle);must(lease&&fs.existsSync(leaseFile)&&fs.readFileSync(leaseFile,'utf8')===canonical(lease),'invalid or stale lease','BLOCKED_BY_OWNERSHIP');return lease;}
  function permitted(p){must(config.writablePaths.includes(p)&&!config.denyPaths.some(d=>p===d||p.startsWith(d+'/')),'path outside writable scope or denied');must(['data','derived'].includes(registry.get(p)?.class),'protected or unregistered path');}
  function sourceOutput(p){const entry=registry.get(p);must(entry?.class==='data'&&entry.schemaId==='record.v1','canonical source must be ordinary registered record');const value=runtime.identify(fs.readFileSync(path.join(root,p)),entry.schemaId);must(value.status==='IDENTIFIED','invalid source identity');return Object.keys(value.value).sort().map(k=>`${k}: ${k==='threshold'?value.value[k].lexeme:JSON.stringify(value.value[k])}\n`).join('');}
  function describe(id,input,ctx){
    if(id==='subprocess.v1')return freeze({status:'BLOCKED_BY_REQUIRED_CAPABILITY',reason:'tested OS containment backend unavailable',execution:'NOT_EXECUTED'});
    must(Object.hasOwn(argsSchema,id),'unknown closed capability');const args=argsSchema[id].parse(input);fresh(ctx);
    const state=journal.read(ctx).state;must(state.runs.at(-1)?.verdict==='OPEN','current open run required');must(!state.pending.length,'unreconciled intent','INCOMPLETE');
    const binding=journal.finalBinding(ctx);must(canonical(binding)===canonical(state.runs.at(-1).binding),'final workspace changed; fresh run required','BLOCKED_BY_STALE_RUN');
    const before=manifest(root),outputs={};permitted(args.path);
    if(id==='canonical-write.v1')outputs[args.path]=sourceOutput(args.path);
    else {permitted(args.sourcePath);must(args.path!==args.sourcePath,'source and derived target must differ');const target=registry.get(args.path);must(target?.class==='derived'&&target.schemaId==='digest.v1','derived target required');const old=runtime.identify(fs.readFileSync(path.join(root,args.path)),'digest.v1');must(old.status==='IDENTIFIED'&&old.value.sourcePath===args.sourcePath,'accepted source path mismatch');outputs[args.sourcePath]=sourceOutput(args.sourcePath);outputs[args.path]=canonical({sourcePath:args.sourcePath,sourceContentSha256:sha256(outputs[args.sourcePath])});}
    for(const [p,output] of Object.entries(outputs)){must(binding.documents.some(doc=>doc.path===p),'output missing accepted-before binding');must(before[p]?.kind==='file','existing regular output required');must(Buffer.byteLength(output)<=1024*1024,'output bound exceeded');}
    for(const doc of binding.documents)must(before[doc.path]?.digest===sha256(Buffer.from(doc.bytesBase64,'base64')),'host final binding differs from actual workspace');
    const assessment=runtime.classifyChange({changes:binding.documents.map(doc=>({path:doc.path,after:Object.hasOwn(outputs,doc.path)?Buffer.from(outputs[doc.path]):Buffer.from(doc.bytesBase64,'base64')}))},ctx);must(assessment.disposition==='MECHANICAL_ELIGIBLE','outputs do not preserve accepted equivalence');
    const after=structuredClone(before);for(const [p,value] of Object.entries(outputs))after[p].digest=sha256(value);
    const plan={version:1,id,args,repositoryId:auth.repositoryId,authorityDigest:auth.authorityDigest,baselineDigest:runtime.inspectContext(ctx).baselineDigest,configDigest,bundleDigest:loadedBundle,runId:state.runs.at(-1).runId,headDigest:state.headDigest,binding,before,after,outputs};
    return {plan,subjectDigest:digestData(plan),scopeDigest:digestData({capability:id,paths:Object.keys(outputs).sort(),units:1,objectiveId:state.objectiveId})};
  }
  function recordFile(key,suffix){return path.join(directory,sha256(key)+suffix);}
  function complete(plan,ctx,lease){
    owned(lease);fresh(ctx);must(plan.configDigest===configDigest&&plan.bundleDigest===loadedBundle,'stored capability binding mismatch');
    const loaded=journal.read(ctx),intent=loaded.intents.get(plan.args.operationKey);must(intent&&intent.effectKind==='local-capability.v1'&&intent.inputDigest===digestData(plan)&&intent.runId===plan.runId,'persistent intent differs from operation');
    must(loaded.state.runs.at(-1).runId===plan.runId,'operation run changed');
    must(canonical(manifest(root))===canonical(plan.after),'postcondition manifest differs; effect uncertain','INCOMPLETE');
    const final=journal.finalBinding(ctx);for(const doc of final.documents)must(plan.after[doc.path]?.digest===sha256(Buffer.from(doc.bytesBase64,'base64')),'final host binding differs from actual outputs','INCOMPLETE');must(final.commit===plan.binding.commit,'commit changed during effect','INCOMPLETE');
    const result=freeze({status:'EFFECT_VERIFIED',operationKey:plan.args.operationKey,capability:plan.id,runId:plan.runId,inputDigest:digestData(plan),bundleDigest:loadedBundle,preManifestDigest:digestData(plan.before),postManifestDigest:digestData(plan.after),delta:Object.keys(plan.outputs).filter(p=>plan.before[p].digest!==plan.after[p].digest).sort(),postconditions:'VERIFIED',assurance:'TRUSTED_RUNTIME_EXCLUSIVE',execution:'EXECUTED'});
    const receiptFile=recordFile(plan.args.operationKey,'.receipt');if(fs.existsSync(receiptFile))must(fs.readFileSync(receiptFile,'utf8')===canonical(result),'altered effect receipt');else durable(receiptFile,canonical(result));
    const outcome=journal.append(loaded.state.headDigest,{kind:'outcome',operationKey:'reconcile:'+plan.args.operationKey,intentKey:plan.args.operationKey,status:'COMPLETED',outputDigest:digestData(result)},ctx);must(outcome.status==='APPENDED',outcome.reason||'outcome recording failed',outcome.status);return result;
  }
  function reconcile(operationKey,ctx,lease){key.parse(operationKey);owned(lease);fresh(ctx);const file=recordFile(operationKey,'.intent');must(fs.existsSync(file),'unknown capability intent');const raw=fs.readFileSync(file,'utf8'),plan=JSON.parse(raw);must(canonical(plan)===raw&&plan.args.operationKey===operationKey,'invalid persistent intent');return complete(plan,ctx,lease);}
  return {
    describeCapability:(id,args,ctx)=>safe(()=>{const d=describe(id,args,ctx);return d.status?d:freeze({status:'CAPABILITY_DESCRIBED',subjectDigest:d.subjectDigest,scopeDigest:d.scopeDigest,outputs:Object.keys(d.plan.outputs).sort(),execution:'NOT_EXECUTED'});}),
    prepareCapability:(id,args,ctx,approval)=>safe(()=>{const d=describe(id,args,ctx);if(d.status)return d;const grant=runtime.verifyApproval(approval,{kind:'bounded-grant',subjectDigest:d.subjectDigest,scopeDigest:d.scopeDigest,authorityDigest:auth.authorityDigest});must(!grant.status,grant.reason||'scoped grant required',grant.status);const permit=Object.freeze(Object.create(null));permits.set(permit,{...d,ctx,grant});return permit;}),
    acquireLease:ctx=>safe(()=>{fresh(ctx);const state=journal.read(ctx).state;must(state.runs.at(-1)?.verdict==='OPEN','open run required');let fd;try{fd=fs.openSync(leaseFile,'wx',0o600);}catch(e){if(e.code==='EEXIST')fail('owner exists; no time-based takeover','BLOCKED_BY_OWNERSHIP');throw e;}try{const fence=fs.existsSync(fenceFile)?Number(fs.readFileSync(fenceFile,'utf8'))+1:1;must(Number.isSafeInteger(fence)&&fence>0,'invalid fencing counter');const value={fence,nonce:randomUUID(),pid:process.pid,runId:state.runs.at(-1).runId};const fenceFd=fs.openSync(fenceFile,'w',0o600);try{fs.writeFileSync(fenceFd,String(fence));fs.fsyncSync(fenceFd);}finally{fs.closeSync(fenceFd);}fs.writeFileSync(fd,canonical(value));fs.fsyncSync(fd);syncDir(directory);const handle=Object.freeze(Object.create(null));leases.set(handle,value);return handle;}finally{fs.closeSync(fd);}}),
    releaseLease:lease=>safe(()=>{owned(lease);fs.unlinkSync(leaseFile);syncDir(directory);leases.delete(lease);return stop('LEASE_RELEASED','exclusive ownership released');}),
    reconcileCapability:(operationKey,ctx,lease)=>safe(()=>reconcile(operationKey,ctx,lease)),
    executeCapability:(permit,lease)=>safe(()=>{
      const item=permits.get(permit);must(item,'foreign or forged permit');const owner=owned(lease),{plan,ctx,grant}=item;fresh(ctx);const checked=runtime.inspectApproval(grant);must(checked.status==='VERIFIED_APPROVAL',checked.reason,checked.status);must(owner.runId===plan.runId,'lease belongs to different run','BLOCKED_BY_OWNERSHIP');
      const intentFile=recordFile(plan.args.operationKey,'.intent');
      if(fs.existsSync(intentFile)){must(fs.readFileSync(intentFile,'utf8')===canonical(plan),'operation key reused with different inputs');return reconcile(plan.args.operationKey,ctx,lease);}
      const current=describe(plan.id,plan.args,ctx);must(current.subjectDigest===item.subjectDigest,'prepared binding changed');owned(lease);
      durable(intentFile,canonical(plan));
      const reserved=journal.append(plan.headDigest,{kind:'reserve',operationKey:plan.args.operationKey,runId:plan.runId,units:1,inputDigest:item.subjectDigest,effectKind:'local-capability.v1'},ctx);must(reserved.status==='APPENDED',reserved.reason||'reservation failed',reserved.status);
      for(const [p,output] of Object.entries(plan.outputs)){
        owned(lease);fresh(ctx);permitted(p);const currentManifest=manifest(root);const expected=structuredClone(plan.before);for(const done of Object.keys(plan.outputs)){if(done===p)break;expected[done]=plan.after[done];}must(canonical(currentManifest)===canonical(expected),'workspace changed during effect','INCOMPLETE');
        const target=path.join(root,p),stage=path.join(path.dirname(target),'.harness-stage-'+owner.nonce);durable(stage,output);fs.chmodSync(stage,plan.before[p].mode);owned(lease);fs.renameSync(stage,target);syncDir(path.dirname(target));
      }
      return complete(plan,ctx,lease);
    })
  };
}
