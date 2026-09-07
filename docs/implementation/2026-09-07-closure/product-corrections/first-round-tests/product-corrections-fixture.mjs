import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {fixture,bytes,sample} from './helpers.mjs';
import {digestData} from '../index.mjs';

const git=fs.realpathSync('/usr/bin/git');
const node=fs.realpathSync(process.execPath);
const hash=value=>createHash('sha256').update(value).digest('hex');
const nAs={
 UI:'No browser UI exists',
 API_SERVER_ACTION:'No HTTP API exists',
 RPC:'No RPC exists',
 DIRECT_DML_POSTGREST:'No database exists',
 BATCH_SYNC:'No batch interface exists',
 STORAGE:'No storage interface exists',
 TRIGGERS:'No triggers exist',
 MIGRATIONS:'No migrations exist',
 PRIVILEGED_CLIENTS:'No privileged client exists'
};

function runGit(cwd,args){
 const result=spawnSync(git,args,{cwd,encoding:'utf8'});
 if(result.status!==0)throw Error(`git ${args.join(' ')} failed: ${result.stderr}`);
 return result.stdout.trim();
}

export function productCorrectionFixture(t,{linkedWorktree=false,malformedVerifier=false}={}){
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'product-correction-'));
 t.after(()=>fs.rmSync(dir,{recursive:true,force:true}));
 const repository=path.join(dir,'repository'),root=linkedWorktree?path.join(dir,'source'):repository,sessions=path.join(dir,'sessions');
 fs.mkdirSync(repository);fs.mkdirSync(sessions);
 fs.writeFileSync(path.join(repository,'product.json'),'{'+'"value":false}');
 fs.writeFileSync(path.join(repository,'frozen.json'),'{}');
 runGit(repository,['init','-q']);runGit(repository,['config','user.name','Fixture']);runGit(repository,['config','user.email','fixture@example.invalid']);
 runGit(repository,['add','product.json','frozen.json']);runGit(repository,['commit','-qm','fixture']);
 if(linkedWorktree)runGit(repository,['worktree','add','--detach',root,'HEAD']);
 const commit=runGit(root,['rev-parse','HEAD']);
 const protocol=path.join(dir,'protocol.json');fs.writeFileSync(protocol,'{"properties":{"outputSchema":{}}}');
 const verifier=path.join(dir,'verifier.mjs');
 fs.writeFileSync(verifier,malformedVerifier
  ? "process.stdout.write(Buffer.from([0xc3,0x28]));\n"
  : "import fs from 'node:fs';let raw='';for await(const chunk of process.stdin)raw+=chunk;const q=JSON.parse(raw),value=JSON.parse(fs.readFileSync(q.root+'/product.json')).value,id=q.stage==='COUNTEREXAMPLE'?'semantic':'value';console.log(JSON.stringify({version:1,cases:[{id,actual:value}],identity:{version:'fixture-v1',artifactDigest:q.manifestDigest,schemaState:'N/A'}}));process.exit(value?0:1);\n");
 const binary=path.join(dir,'codex-fixture');
 fs.writeFileSync(binary,`#!${node}
import fs from 'node:fs';import readline from 'node:readline';import {createHash,randomUUID} from 'node:crypto';
const hash=value=>createHash('sha256').update(value).digest('hex'),send=value=>process.stdout.write(JSON.stringify(value)+'\\n');let source,thread='fixture-'+randomUUID();
for await(const line of readline.createInterface({input:process.stdin})){
 const message=JSON.parse(line);if(message.id===undefined)continue;let result={};
 if(message.method==='account/read')result={account:{type:'chatgpt'}};
 if(message.method==='model/list')result={data:[{model:'fixture-model',supportedReasoningEfforts:[{reasoningEffort:'high'}]}],nextCursor:null};
 if(message.method==='thread/start'){source=message.params.cwd;result={thread:{id:thread},model:'fixture-model',modelProvider:'openai',reasoningEffort:'high',approvalPolicy:'never',sandbox:{type:'readOnly'},cwd:source};}
 if(message.method==='turn/start'){
  result={turn:{id:'turn'}};send({id:message.id,result});const prompt=JSON.parse(message.params.input[0].text),data=fs.readFileSync(source+'/product.json');
  const output=prompt.operation==='AUTHOR'?{version:1,objectiveDigest:prompt.objectiveDigest,beforeManifestDigest:prompt.manifestDigest,changes:[{path:'product.json',beforeDigest:hash(data),afterBytesBase64:Buffer.from('{"value":true}').toString('base64'),mode:'100644'}]}:{version:1,verdict:'PASS',findings:[]};
  send({method:'item/completed',params:{threadId:thread,turnId:'turn',item:{type:'agentMessage',phase:'final_answer',text:JSON.stringify(output)}}});
  send({method:'turn/completed',params:{threadId:thread,turn:{id:'turn',status:'completed'}}});continue;
 }
 send({id:message.id,result});
}`);fs.chmodSync(binary,0o755);
 const product={root,sessions,gitPath:git,gitDigest:hash(fs.readFileSync(git)),nodePath:node,nodeDigest:hash(fs.readFileSync(node)),verifier:{path:verifier,digest:hash(fs.readFileSync(verifier)),timeoutMs:3000,outputLimit:65536},worker:{binary,binaryDigest:hash(fs.readFileSync(binary)),protocolPath:protocol,protocolDigest:hash(fs.readFileSync(protocol))},containment:{status:'FIXTURE',digest:hash('fixture containment')},model:'fixture-model',effort:'high',authMode:'chatgpt'};
 const journal={contract:'product.v1',directory:path.join(dir,'journal'),objectiveId:'correction',journalId:'correction-journal',actorId:'fixture-controller',budgetLimit:10,readFinalBinding:()=>({commit,documents:[{path:'record.yaml',bytes:bytes(sample)}]})};
 const f=fixture({journal,product}),ctx=f.context();
 if(ctx.status!==undefined)throw Error(JSON.stringify(ctx));
 const started=f.runtime.journal.start(ctx,'start');if(started.status!=='APPENDED')throw Error(JSON.stringify(started));
 const coverage=[{invariantId:'value',surface:'CLI',mutationPath:'product.json',principal:'local-user',negativeTestId:'value',applicability:'APPLICABLE',basis:'Run the pinned verifier'},...Object.entries(nAs).map(([surface,basis])=>({invariantId:'value',surface,mutationPath:'N/A',principal:'N/A',negativeTestId:null,applicability:'N/A',basis}))];
 const input={version:1,objectiveId:'correction',outcome:'Prepare verified product change',scope:{paths:['product.json'],frozenPaths:['frozen.json']},acceptance:[{id:'value',expected:true}],regressions:[{id:'semantic',expected:true}],coverage,expiresAt:1400,maxSteps:10};
 const described=f.runtime.describeProductObjective(input,ctx);if(described.status!=='PRODUCT_OBJECTIVE_DESCRIBED')throw Error(JSON.stringify(described));
 const wire={objective:described.objective,approval:f.receipt('bounded-grant',digestData(described.objective),{scopeDigest:digestData(described.objective.scope)})};
 const handle=f.runtime.bindProductObjective({objective:described.objective,approval:wire.approval},ctx);if(handle.status!==undefined)throw Error(JSON.stringify(handle));
 return {...f,dir,repository,root,sessions,commit,product,journal,ctx,handle,runGit:(args,cwd=root)=>runGit(cwd,args)};
}
