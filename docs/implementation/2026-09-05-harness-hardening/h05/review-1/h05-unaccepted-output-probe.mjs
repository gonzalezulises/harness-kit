import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {openRuntime,canonical,installedBundleDigest} from './harness-kit/packs/autonomy/repo-template/scripts/quality-orchestrator/index.mjs';
import {fixture,sample,bytes} from './harness-kit/packs/autonomy/repo-template/scripts/quality-orchestrator/tests/helpers.mjs';
const dir=fs.mkdtempSync(path.join(os.tmpdir(),'h05-review-'));
try {
 const root=path.join(dir,'workspace');fs.mkdirSync(root);
 fs.writeFileSync(path.join(root,'policy.yaml'),sample);
 fs.writeFileSync(path.join(root,'record.yaml'),sample);
 const f=fixture({authorityOverrides:{scope:{paths:['policy.yaml']}}});
 const docs=[{path:'policy.yaml',bytes:bytes(sample)}];
 const host={...f.host,journal:{directory:path.join(dir,'state'),objectiveId:'o',journalId:'j',actorId:'supervisor',budgetLimit:3,readFinalBinding:()=>({commit:'a'.repeat(40),documents:docs.map(d=>({path:d.path,bytes:fs.readFileSync(path.join(root,d.path))}))})},capabilities:{workspace:root,writablePaths:['record.yaml'],denyPaths:['policy.yaml'],bundleDigest:installedBundleDigest(),mode:'TRUSTED_RUNTIME_EXCLUSIVE'}};
 const r=openRuntime(host),auth=r.loadAuthority(bytes(canonical(f.authority)),f.receipt('policy-adoption',f.authorityDigest));
 const ctx=r.verifyContext({authority:auth,documents:docs,acceptance:f.receipt('baseline-acceptance',r.describeBaseline(docs).digest)});
 console.log('authority paths',f.authority.scope.paths,'accepted paths',docs.map(d=>d.path));
 console.log('start',r.journal.start(ctx,'start').status);
 console.log('direct classifier for requested output',r.classifyChange({changes:[{path:'record.yaml',after:bytes(sample)}]},ctx).disposition);
 const args={path:'record.yaml',operationKey:'outside-accepted'},d=r.describeCapability('canonical-write.v1',args,ctx);console.log('describe',d);
 if(d.status==='CAPABILITY_DESCRIBED'){
 const p=r.prepareCapability('canonical-write.v1',args,ctx,f.receipt('bounded-grant',d.subjectDigest,{scopeDigest:d.scopeDigest})),l=r.acquireLease(ctx);
 const result=r.executeCapability(p,l);console.log('execution',result);
 console.log('actual output changed',fs.readFileSync(path.join(root,'record.yaml'),'utf8')!==sample);
 console.log('spent',r.journal.replay(ctx).budget.spent);
 r.releaseLease(l);
 }
} finally {fs.rmSync(dir,{recursive:true,force:true});}
