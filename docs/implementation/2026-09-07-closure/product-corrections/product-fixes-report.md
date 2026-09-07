# Product supervisor corrective report

## Status

DONE. Implemented only P0-R1-M1 linked-worktree object directory resolution and P0-R1-M3 malformed verifier UTF-8 controlled error handling. No schema, scope, nonce, budget, authority, readiness, publication, branch, index, historical evidence, feature ledger, or root documentation behavior was changed.

Repository: `/workspace/scratch/adce1c53b293/harness-human-interruption`  
Branch: `closure/harness-33-37`  
Starting/current HEAD: `dfd717b934667b1d6153a8934a657a70b8b0c9e1` (source left unstaged; no commit)

## Changed paths

- `packs/autonomy/repo-template/scripts/quality-orchestrator/product.mjs`
- `packs/autonomy/repo-template/scripts/quality-orchestrator/tests/product-corrections-fixture.mjs`
- `packs/autonomy/repo-template/scripts/quality-orchestrator/tests/product-linked-worktree.test.mjs`
- `packs/autonomy/repo-template/scripts/quality-orchestrator/tests/product-verifier-utf8.test.mjs`

Controller-owned pre-existing changes observed and not modified: `feature_list.json`, `docs/implementation/2026-09-07-closure/`, and `docs/superpowers/`.

## Root cause and correction

- P0-R1-M1: `git rev-parse --absolute-git-dir` returns the per-worktree administrative directory in a linked worktree; that directory has no `objects` child. PR preparation now asks Git for the absolute common directory and uses its object store as the isolated repository alternate.
- P0-R1-M3: fatal `TextDecoder` decoding happened in the child `close` event callback. A decode exception therefore escaped the verifier promise and reached the Node uncaught-exception path. The callback now rejects with the controlled `BLOCKED_TOOL_FAILURE` status and a stable UTF-8 reason.

## TDD evidence

Exact bytes used for both valid RED witnesses:

- pre-fix `product.mjs`: `4e7213881c760a7283db74d1d8126efd4308b0fb0ef2ca50ffd4b9a67e8f8a9d`
- fixture helper: `3af5f39a3943f388676437da2bf2255de96d1c739bde6622801f9cc58fad4978`
- linked-worktree test: `a42b5ead811973be942468c70f98349068879c5fb34128c134dad3afd6e72347`
- malformed UTF-8 test: `8c73c93f6f6c4fc86c30e11650c77d95ff9848b2744bced357c182c7d04715`

P0-R1-M1 RED command:

```sh
node --test packs/autonomy/repo-template/scripts/quality-orchestrator/tests/product-linked-worktree.test.mjs
```

Exit 1. The black-box product run returned `POLICY` because `realpathSync` attempted the nonexistent linked-worktree path `.../.git/worktrees/source/objects`; the test expected `HANDOFF_PREPARED`. Full log: `/workspace/scratch/0be017df5260/closure-review/product-linked-worktree-red.log`.

P0-R1-M3 RED command:

```sh
node --test packs/autonomy/repo-template/scripts/quality-orchestrator/tests/product-verifier-utf8.test.mjs
```

Exit 1. Invalid bytes `c3 28` produced uncaught `ERR_ENCODING_INVALID_ENCODED_DATA` at the `TextDecoder.decode` callback rather than a runtime result. Full log: `/workspace/scratch/0be017df5260/closure-review/product-verifier-utf8-red.log`.

The initial linked-worktree attempt before these witnesses had a fixture syntax error and is explicitly excluded from RED evidence. The helper was corrected before recording the hashes and valid causal failures above.

## GREEN and regression results

Final exact bytes:

- fixed `product.mjs`: `3a6497d7f81e9a10a53d5b20108ab190e2aa04de55f43cd5e7db9c3f9115ad2a`
- fixture helper: `3af5f39a3943f388676437da2bf2255de96d1c739bde6622801f9cc58fad4978`
- linked-worktree test: `a42b5ead811973be942468c70f98349068879c5fb34128c134dad3afd6e72347`
- malformed UTF-8 test: `8c73c93f6f6c4fc86c30e11650c77d95ff9848b2744bced357c182c7d04715`

- `node --check packs/autonomy/repo-template/scripts/quality-orchestrator/product.mjs` — exit 0.
- `node --test packs/autonomy/repo-template/scripts/quality-orchestrator/tests/product-linked-worktree.test.mjs packs/autonomy/repo-template/scripts/quality-orchestrator/tests/product-verifier-utf8.test.mjs` — exit 0, 2/2 pass, 0 fail.
- Individual causal GREEN logs: `/workspace/scratch/0be017df5260/closure-review/product-linked-worktree-green.log` and `/workspace/scratch/0be017df5260/closure-review/product-verifier-utf8-green.log`.
- `node --test packs/autonomy/repo-template/scripts/quality-orchestrator/tests/product-loop.test.mjs` — exit 0, 25/25 pass, 0 fail. Log: `/workspace/scratch/0be017df5260/closure-review/product-loop-regression.log`.
- `node --test packs/autonomy/repo-template/scripts/quality-orchestrator/tests/human-interruption.test.mjs` — exit 0, 25/25 pass, 0 fail. Log: `/workspace/scratch/0be017df5260/closure-review/human-interruption-regression.log`.

Per task ownership, no full `make check`, commit, staging, remote operation, publication, or global test run was performed.

## Concerns

No corrective-scope concern remains. The new linked-worktree behavior was exercised through the complete product runtime to a readable isolated commit, and malformed UTF-8 was exercised through the public runtime method with pending nonce state retained. The controller's separate GR01-GR05 findings and closure work remain outside this bounded task.

## Exact unstaged diff

```diff
diff --git a/packs/autonomy/repo-template/scripts/quality-orchestrator/product.mjs b/packs/autonomy/repo-template/scripts/quality-orchestrator/product.mjs
index f8b9dc7..57d7e8b 100644
--- a/packs/autonomy/repo-template/scripts/quality-orchestrator/product.mjs
+++ b/packs/autonomy/repo-template/scripts/quality-orchestrator/product.mjs
@@ -206,7 +206,7 @@ export function productBoundary(host,runtime,auth,journal){
    const child=spawn(config.nodePath,[config.verifier.path],{cwd:config.sessions,env:{LANG:'C.UTF-8'},shell:false,stdio:['pipe','pipe','pipe'],detached:true});let output=[],total=0,err='';
    const kill=()=>{try{process.kill(-child.pid,'SIGKILL');}catch{}};const timer=setTimeout(()=>{kill();reject(Error('verifier deadline exceeded'));},config.verifier.timeoutMs);
    child.on('error',reject);child.stdout.on('data',b=>{total+=b.length;if(total>config.verifier.outputLimit){kill();reject(Error('verifier output exceeds bound'));}else output.push(b);});child.stderr.on('data',b=>{total+=b.length;if(total>config.verifier.outputLimit){kill();reject(Error('verifier output exceeds bound'));}err=(err+b.toString()).slice(0,500);});
-   child.stdin.on('error',()=>{});child.stdin.end(canonical(q));child.on('close',(exit,signal)=>{clearTimeout(timer);kill();if(signal||![0,1].includes(exit))reject(Error('verifier tool failure: '+err));else resolve({exit,stdout:new TextDecoder('utf8',{fatal:true}).decode(Buffer.concat(output))});});
+   child.stdin.on('error',()=>{});child.stdin.end(canonical(q));child.on('close',(exit,signal)=>{clearTimeout(timer);kill();if(signal||![0,1].includes(exit))reject(Error('verifier tool failure: '+err));else{try{resolve({exit,stdout:new TextDecoder('utf8',{fatal:true}).decode(Buffer.concat(output))});}catch{reject(Object.assign(Error('verifier output is not valid UTF-8'),{productStatus:'BLOCKED_TOOL_FAILURE'}));}}});
   });
   fresh(item,s);let parsed;try{parsed=functionalObservationSchema.parse(JSON.parse(observed.stdout));}catch{must(false,'verifier did not produce typed functional cases','BLOCKED_TOOL_FAILURE');}
   must(new Set(parsed.cases.map(c=>c.id)).size===parsed.cases.length&&canonical(parsed.cases.map(c=>c.id).sort())===canonical(cases.map(c=>c.id).sort()),'verifier omitted or injected cases','BLOCKED_TOOL_FAILURE');
@@ -240,8 +240,8 @@ export function productBoundary(host,runtime,auth,journal){
   const git=(args,input)=>execFileSync(config.gitPath,args,{env,input,timeout:3000,maxBuffer:2*1024*1024,encoding:'utf8'}).trim();
   // A private object database, no source index/ref mutation, no hooks and no
   // push/merge. Alternates only read the exact base objects already on disk.
-  const gitDir=git(['--no-optional-locks','-C',config.root,'rev-parse','--absolute-git-dir']);
-  const objects=fs.realpathSync(path.join(gitDir,'objects'));must(!objects.includes('\n')&&!objects.includes('\r'),'unsafe local object path');
+  const commonGitDir=git(['--no-optional-locks','-C',config.root,'rev-parse','--path-format=absolute','--git-common-dir']);
+  const objects=fs.realpathSync(path.join(commonGitDir,'objects'));must(!objects.includes('\n')&&!objects.includes('\r'),'unsafe local object path');
   git(['init','--bare','--quiet',repository]);fs.writeFileSync(path.join(repository,'objects/info/alternates'),objects+'\n');
   const command=(args,input)=>git(['--git-dir',repository,'-c','core.hooksPath=/dev/null',...args],input);
   command(['cat-file','-e',item.objective.baseCommit+'^{commit}']);
--- /dev/null
+++ packs/autonomy/repo-template/scripts/quality-orchestrator/tests/product-corrections-fixture.mjs
@@ -0,0 +1,74 @@
+import fs from 'node:fs';
+import os from 'node:os';
+import path from 'node:path';
+import {spawnSync} from 'node:child_process';
+import {createHash} from 'node:crypto';
+import {fixture,bytes,sample} from './helpers.mjs';
+import {digestData} from '../index.mjs';
+
+const git=fs.realpathSync('/usr/bin/git');
+const node=fs.realpathSync(process.execPath);
+const hash=value=>createHash('sha256').update(value).digest('hex');
+const nAs={
+ UI:'No browser UI exists',
+ API_SERVER_ACTION:'No HTTP API exists',
+ RPC:'No RPC exists',
+ DIRECT_DML_POSTGREST:'No database exists',
+ BATCH_SYNC:'No batch interface exists',
+ STORAGE:'No storage interface exists',
+ TRIGGERS:'No triggers exist',
+ MIGRATIONS:'No migrations exist',
+ PRIVILEGED_CLIENTS:'No privileged client exists'
+};
+
+function runGit(cwd,args){
+ const result=spawnSync(git,args,{cwd,encoding:'utf8'});
+ if(result.status!==0)throw Error(`git ${args.join(' ')} failed: ${result.stderr}`);
+ return result.stdout.trim();
+}
+
+export function productCorrectionFixture(t,{linkedWorktree=false,malformedVerifier=false}={}){
+ const dir=fs.mkdtempSync(path.join(os.tmpdir(),'product-correction-'));
+ t.after(()=>fs.rmSync(dir,{recursive:true,force:true}));
+ const repository=path.join(dir,'repository'),root=linkedWorktree?path.join(dir,'source'):repository,sessions=path.join(dir,'sessions');
+ fs.mkdirSync(repository);fs.mkdirSync(sessions);
+ fs.writeFileSync(path.join(repository,'product.json'),'{'+'"value":false}');
+ fs.writeFileSync(path.join(repository,'frozen.json'),'{}');
+ runGit(repository,['init','-q']);runGit(repository,['config','user.name','Fixture']);runGit(repository,['config','user.email','fixture@example.invalid']);
+ runGit(repository,['add','product.json','frozen.json']);runGit(repository,['commit','-qm','fixture']);
+ if(linkedWorktree)runGit(repository,['worktree','add','--detach',root,'HEAD']);
+ const commit=runGit(root,['rev-parse','HEAD']);
+ const protocol=path.join(dir,'protocol.json');fs.writeFileSync(protocol,'{"properties":{"outputSchema":{}}}');
+ const verifier=path.join(dir,'verifier.mjs');
+ fs.writeFileSync(verifier,malformedVerifier
+  ? "process.stdout.write(Buffer.from([0xc3,0x28]));\n"
+  : "import fs from 'node:fs';let raw='';for await(const chunk of process.stdin)raw+=chunk;const q=JSON.parse(raw),value=JSON.parse(fs.readFileSync(q.root+'/product.json')).value,id=q.stage==='COUNTEREXAMPLE'?'semantic':'value';console.log(JSON.stringify({version:1,cases:[{id,actual:value}],identity:{version:'fixture-v1',artifactDigest:q.manifestDigest,schemaState:'N/A'}}));process.exit(value?0:1);\n");
+ const binary=path.join(dir,'codex-fixture');
+ fs.writeFileSync(binary,`#!${node}
+import fs from 'node:fs';import readline from 'node:readline';import {createHash,randomUUID} from 'node:crypto';
+const hash=value=>createHash('sha256').update(value).digest('hex'),send=value=>process.stdout.write(JSON.stringify(value)+'\\n');let source,thread='fixture-'+randomUUID();
+for await(const line of readline.createInterface({input:process.stdin})){
+ const message=JSON.parse(line);if(message.id===undefined)continue;let result={};
+ if(message.method==='account/read')result={account:{type:'chatgpt'}};
+ if(message.method==='model/list')result={data:[{model:'fixture-model',supportedReasoningEfforts:[{reasoningEffort:'high'}]}],nextCursor:null};
+ if(message.method==='thread/start'){source=message.params.cwd;result={thread:{id:thread},model:'fixture-model',modelProvider:'openai',reasoningEffort:'high',approvalPolicy:'never',sandbox:{type:'readOnly'},cwd:source};}
+ if(message.method==='turn/start'){
+  result={turn:{id:'turn'}};send({id:message.id,result});const prompt=JSON.parse(message.params.input[0].text),data=fs.readFileSync(source+'/product.json');
+  const output=prompt.operation==='AUTHOR'?{version:1,objectiveDigest:prompt.objectiveDigest,beforeManifestDigest:prompt.manifestDigest,changes:[{path:'product.json',beforeDigest:hash(data),afterBytesBase64:Buffer.from('{"value":true}').toString('base64'),mode:'100644'}]}:{version:1,verdict:'PASS',findings:[]};
+  send({method:'item/completed',params:{threadId:thread,turnId:'turn',item:{type:'agentMessage',phase:'final_answer',text:JSON.stringify(output)}}});
+  send({method:'turn/completed',params:{threadId:thread,turn:{id:'turn',status:'completed'}}});continue;
+ }
+ send({id:message.id,result});
+}`);fs.chmodSync(binary,0o755);
+ const product={root,sessions,gitPath:git,gitDigest:hash(fs.readFileSync(git)),nodePath:node,nodeDigest:hash(fs.readFileSync(node)),verifier:{path:verifier,digest:hash(fs.readFileSync(verifier)),timeoutMs:3000,outputLimit:65536},worker:{binary,binaryDigest:hash(fs.readFileSync(binary)),protocolPath:protocol,protocolDigest:hash(fs.readFileSync(protocol))},containment:{status:'FIXTURE',digest:hash('fixture containment')},model:'fixture-model',effort:'high',authMode:'chatgpt'};
+ const journal={contract:'product.v1',directory:path.join(dir,'journal'),objectiveId:'correction',journalId:'correction-journal',actorId:'fixture-controller',budgetLimit:10,readFinalBinding:()=>({commit,documents:[{path:'record.yaml',bytes:bytes(sample)}]})};
+ const f=fixture({journal,product}),ctx=f.context();
+ if(ctx.status!==undefined)throw Error(JSON.stringify(ctx));
+ const started=f.runtime.journal.start(ctx,'start');if(started.status!=='APPENDED')throw Error(JSON.stringify(started));
+ const coverage=[{invariantId:'value',surface:'CLI',mutationPath:'product.json',principal:'local-user',negativeTestId:'value',applicability:'APPLICABLE',basis:'Run the pinned verifier'},...Object.entries(nAs).map(([surface,basis])=>({invariantId:'value',surface,mutationPath:'N/A',principal:'N/A',negativeTestId:null,applicability:'N/A',basis}))];
+ const input={version:1,objectiveId:'correction',outcome:'Prepare verified product change',scope:{paths:['product.json'],frozenPaths:['frozen.json']},acceptance:[{id:'value',expected:true}],regressions:[{id:'semantic',expected:true}],coverage,expiresAt:1400,maxSteps:10};
+ const described=f.runtime.describeProductObjective(input,ctx);if(described.status!=='PRODUCT_OBJECTIVE_DESCRIBED')throw Error(JSON.stringify(described));
+ const wire={objective:described.objective,approval:f.receipt('bounded-grant',digestData(described.objective),{scopeDigest:digestData(described.objective.scope)})};
+ const handle=f.runtime.bindProductObjective({objective:described.objective,approval:wire.approval},ctx);if(handle.status!==undefined)throw Error(JSON.stringify(handle));
+ return {...f,dir,repository,root,sessions,commit,product,journal,ctx,handle,runGit:(args,cwd=root)=>runGit(cwd,args)};
+}

--- /dev/null
+++ packs/autonomy/repo-template/scripts/quality-orchestrator/tests/product-linked-worktree.test.mjs
@@ -0,0 +1,16 @@
+import test from 'node:test';
+import assert from 'node:assert/strict';
+import fs from 'node:fs';
+import path from 'node:path';
+import {productCorrectionFixture} from './product-corrections-fixture.mjs';
+
+test('local PR preparation reads base objects from a linked worktree common Git directory',async t=>{
+ const f=productCorrectionFixture(t,{linkedWorktree:true});
+ const worktreeGitDir=f.runGit(['rev-parse','--absolute-git-dir']);
+ assert.equal(fs.existsSync(path.join(worktreeGitDir,'objects')),false,'fixture must use split linked-worktree metadata');
+ const result=await f.runtime.runProduct(f.handle);
+ assert.equal(result.stage,'HANDOFF_PREPARED',JSON.stringify(result));
+ assert.equal(result.handoff.baseCommit,f.commit);
+ assert.equal(f.runGit(['--git-dir',result.handoff.repository,'cat-file','-e',`${result.handoff.headCommit}^{commit}`]),'');
+ assert.equal(f.runGit(['--git-dir',result.handoff.repository,'show',`${result.handoff.headCommit}:product.json`]),'{"value":true}');
+});

--- /dev/null
+++ packs/autonomy/repo-template/scripts/quality-orchestrator/tests/product-verifier-utf8.test.mjs
@@ -0,0 +1,11 @@
+import test from 'node:test';
+import assert from 'node:assert/strict';
+import {productCorrectionFixture} from './product-corrections-fixture.mjs';
+
+test('malformed verifier UTF-8 returns a controlled tool failure',async t=>{
+ const f=productCorrectionFixture(t,{malformedVerifier:true});
+ const result=await f.runtime.executeProductStep(f.handle,'red:0');
+ assert.equal(result.status,'BLOCKED_TOOL_FAILURE',JSON.stringify(result));
+ assert.match(result.reason,/UTF-8/);
+ assert.equal(f.runtime.replayProduct(f.handle).pending.key,'red:0');
+});
```
