import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {createHash,generateKeyPairSync,sign} from 'node:crypto';
import {spawnSync} from 'node:child_process';

const kit=path.resolve(import.meta.dirname,'../../..');
const sample='title: hello\nstatus: active\nenabled: true\nthreshold: 100\n';
const expected='enabled: true\nstatus: "active"\nthreshold: 100\ntitle: "hello"\n';
const sha=b=>createHash('sha256').update(b).digest('hex');
const mechanical='mechanical-remediation-verification',product='product-semantic-review',harness='harness-implementation-review';

test('installed local canary: canonical RED, fresh commits, reused grant, human gate, unavailable release and lossless rollback',async t=>{
  const directory=fs.mkdtempSync(path.join(os.tmpdir(),'h09-canary-'));
  t.after(()=>fs.rmSync(directory,{recursive:true,force:true}));
  const consumer=path.join(directory,'consumer'),primary=path.join(consumer,'data'),work=path.join(primary,'product'),state=path.join(consumer,'.harness/FIXTURE_ONLY-state'),shadows=path.join(directory,'shadows');
  fs.mkdirSync(work,{recursive:true});fs.mkdirSync(shadows);
  const observations=[],commands=[],signatures=[];
  const run=(cmd,args,cwd=consumer,env=process.env)=>{const r=spawnSync(cmd,args,{cwd,env,encoding:'utf8',timeout:60000});commands.push({cmd,args,cwd,exit:r.status,stdout:r.stdout,stderr:r.stderr});assert.equal(r.error,undefined);return r;};
  const check=(r,status)=>{assert.equal(r.status,status,r.stdout+r.stderr);return r.stdout;};
  const legacy='{ "features": [{"id":"F01","state":"passing","evidence":["legacy fixture receipt retained"]}] }\n';
  const rootPackage='{"name":"h09-consumer-fixture","private":true}\n';
  fs.writeFileSync(path.join(consumer,'feature_list.json'),legacy);fs.writeFileSync(path.join(consumer,'package.json'),rootPackage);
  check(run('bash',[path.join(kit,'bin/harness-init.sh'),'--target',consumer,'--level','full','--with','autonomy']),0);
  const runtimeDir=path.join(consumer,'scripts/quality-orchestrator'),marker=path.join(consumer,'.harness/autonomy-v2.json');
  assert.equal(fs.existsSync(marker),false);assert.equal(fs.existsSync(path.join(runtimeDir,'node_modules')),false);
  // The installed lockfile is actually resolved in the nested package. No source
  // node_modules copy/symlink and no network fallback in this reproducible canary.
  check(run('npm',['ci','--prefix',runtimeDir,'--offline','--ignore-scripts','--no-audit','--no-fund']),0);
  const status=check(run('bash',[path.join(kit,'bin/harness-status.sh'),'--target',consumer,'--autonomy']),0);
  assert.match(status,/INSTALLED/);assert.match(status,/NOT_VERIFIED/);assert.match(status,/UNIMPLEMENTED/);
  const api=await import(pathToFileURL(path.join(runtimeDir,'index.mjs')));
  assert.equal(api.openRuntime({}).status,'BLOCKED_BY_MISSING_AUTHORITY_BINDING');
  fs.writeFileSync(path.join(work,'record.yaml'),sample);
  const gitEnv={PATH:process.env.PATH,GIT_CONFIG_NOSYSTEM:'1',GIT_CONFIG_GLOBAL:'/dev/null',GIT_AUTHOR_NAME:'H09 fixture',GIT_AUTHOR_EMAIL:'h09@example.invalid',GIT_COMMITTER_NAME:'H09 fixture',GIT_COMMITTER_EMAIL:'h09@example.invalid',GIT_AUTHOR_DATE:'2026-09-06T00:00:00Z',GIT_COMMITTER_DATE:'2026-09-06T00:00:00Z'};
  const git=(...args)=>check(run('/usr/bin/git',args,primary,gitEnv),0).trim();
  git('init','--template=','--initial-branch=main');git('add','product/record.yaml');git('-c','core.hooksPath=/dev/null','commit','-m','H09 fixture baseline');
  const initialCommit=git('rev-parse','HEAD');
  const documents=[{path:'record.yaml',bytes:Buffer.from(sample)}];
  // These keys exist only in this test process. They are never production owner
  // keys, never written to disk, and never used to approve the delivery bundle.
  const keys=generateKeyPairSync('ed25519'),repositoryId='H09-FIXTURE-ONLY';
  const authority={version:1,repositoryId,policyId:'conservative.v1',role:'normative',runtimeBinding:api.RUNTIME_BINDING,scope:{paths:['record.yaml']}};
  const authorityDigest=api.digestData(authority);
  function receipt(kind,subjectDigest,scopeDigest=api.digestData(authority.scope)){
    const envelope={version:1,issuer:'H09-FIXTURE-ONLY',issuerRole:'owner',keyId:'ephemeral-fixture',kind,receiptId:'fixture-'+signatures.length,repositoryId,subjectDigest,scopeDigest,authorityDigest,issuedAt:950,expiresAt:1500,revocationEpoch:7,decision:'approve'};
    const wire={...envelope,signature:sign(null,api.approvalSigningBytes(envelope),keys.privateKey).toString('base64')};signatures.push(wire);return wire;
  }
  const artifacts=['binary','dependency','protocol'].map(role=>{const file=path.join(directory,'FIXTURE_ONLY-'+role);fs.writeFileSync(file,'H09 diagnostic fixture '+role);return {role,path:file,digest:sha(fs.readFileSync(file))};});
  const host={repositoryId,authorityDigest,now:()=>1000,revocation:{epoch:7,asOf:900,expiresAt:2000,revokedReceiptIds:[]},issuers:[{issuer:'H09-FIXTURE-ONLY',keyId:'ephemeral-fixture',role:'owner',publicKey:keys.publicKey,kinds:['policy-adoption','baseline-acceptance','bounded-grant']}],files:[{path:'record.yaml',schemaId:'record.v1',class:'data'}],
    journal:{directory:state,objectiveId:'h09-local',journalId:'h09-fixture',actorId:'fixture-supervisor',budgetLimit:4,readFinalBinding:()=>({commit:git('rev-parse','HEAD'),documents:[{path:'record.yaml',bytes:fs.readFileSync(path.join(work,'record.yaml'))}]})},
    capabilities:{workspace:work,writablePaths:['record.yaml'],denyPaths:[],bundleDigest:api.installedBundleDigest(),mode:'TRUSTED_RUNTIME_EXCLUSIVE'},
    review:{primaryRoot:primary,shadowRoot:shadows,gitPath:'/usr/bin/git',gitDigest:sha(fs.readFileSync('/usr/bin/git')),artifacts,observation:{status:'FIXTURE',authMode:'chatgpt',models:[{model:'H09-FIXTURE-MODEL',efforts:['high']}],remoteSchema:true,complete:true}}};
  const r=api.openRuntime(host);assert.equal(r.status,undefined,r.reason);
  const adoption=receipt('policy-adoption',authorityDigest),baseline=r.describeBaseline(documents),acceptance=receipt('baseline-acceptance',baseline.digest);
  const context=runtime=>runtime.verifyContext({authority:runtime.loadAuthority(Buffer.from(api.canonical(authority)),adoption),documents,acceptance});
  const ctx=context(r);assert.equal(r.inspectContext(ctx).status,'VERIFIED_CONTEXT');assert.equal(r.journal.start(ctx,'start').status,'APPENDED');
  assert.equal(r.journal.importLegacy(r.journal.replay(ctx).headDigest,'legacy-import',Buffer.from(legacy),ctx).status,'APPENDED');
  assert.equal(r.journal.projectLegacy(ctx).features[0].verificationStatus,'LEGACY_UNVERIFIED');
  fs.writeFileSync(marker,JSON.stringify({fixtureOnly:true,authorityDigest,baselineDigest:baseline.digest,notice:'H09 FIXTURE ONLY — not owner adoption'})+'\n');
  const guarded=run('bash',['scripts/verify-feature.sh','F01']);assert.equal(guarded.status,67);assert.match(guarded.stderr,/v2.*read.only/i);
  const oracle="const fs=require('node:fs');const actual=fs.readFileSync(process.argv[1],'utf8');if(actual!==process.argv[2]){console.error('FIXTURE_REPRESENTATION_RED: expected canonical bytes');process.exit(1)}console.log('LOCAL_CANONICAL_VERIFIED');";
  const verify=()=>run(process.execPath,['-e',oracle,path.join(work,'record.yaml'),expected]);
  const firstRed=verify();assert.equal(firstRed.status,1);observations.push({step:'normal YAML before canonical effect',kind:'CONTROLLED_LOCAL_FIXTURE_RED',exit:firstRed.status,sourceSha256:sha(sample),oracleSha256:sha(oracle)});
  const reorder=sample.trim().split('\n').reverse().join('\n')+'\n';
  const grant=r.describeContinuation({acId:'AC-H09-canonical',paths:['record.yaml'],capabilities:['canonical-write.v1'],regressions:[{path:'record.yaml',afterBase64:Buffer.from(reorder).toString('base64'),expected:'MECHANICAL_ELIGIBLE'},{path:'record.yaml',afterBase64:Buffer.from(sample.replace('100','99.9')).toString('base64'),expected:'HUMAN_REQUIRED'}],limits:{[mechanical]:2,[product]:1,[harness]:1,total:4}},ctx).grant;
  assert.ok(grant);const continuationWire={grant,approval:receipt('bounded-grant',api.digestData(grant),api.digestData(grant.scope))};
  const continuation=()=>r.evaluateContinuation(continuationWire,{gateDigest:api.digestData(grant.humanGate),path:'record.yaml'},ctx);
  function effect(key){const permit=r.prepareCapability('canonical-write.v1',{path:'record.yaml',operationKey:key},ctx,continuation());assert.equal(permit.status,undefined,permit.reason);const lease=r.acquireLease(ctx),result=r.executeCapability(permit,lease);assert.equal(result.status,'EFFECT_VERIFIED',result.reason);assert.deepEqual(r.executeCapability(permit,lease),result);r.releaseLease(lease);observations.push({step:key,result});check(verify(),0);return result;}
  function commitFresh(message){git('add','product/record.yaml');git('-c','core.hooksPath=/dev/null','commit','-m',message);const before=r.journal.replay(ctx),result=r.journal.replaceStaleRun(before.headDigest,before.runs.at(-1).runId,message,ctx);assert.equal(result.status,'APPENDED',result.reason);return result;}
  effect('canonical-one');commitFresh('canonical-commit');
  assert.notEqual(git('rev-parse','HEAD'),initialCommit);
  const reviewPolicy=r.describeReviewPolicy({objectiveId:'h09-local',operationKey:'diagnostic-review',budgetKind:harness,targetCommit:git('rev-parse','HEAD'),prompt:'H09 fixture diagnostic only',authMode:'chatgpt',modelOrder:[{model:'H09-FIXTURE-MODEL',effort:'high'}],limits:{maxOutputBytes:65536,maxDurationMs:60000}}).policy;
  const reviewBinding=r.preflightReview({policy:reviewPolicy,approval:receipt('bounded-grant',api.digestData(reviewPolicy),api.digestData(reviewPolicy.scope))});
  const shadow=r.createReviewShadow(reviewBinding);assert.equal(r.inspectReviewShadow(shadow).status,'REVIEW_SHADOW_BUILT');
  const beforeReview=r.journal.replay(ctx),review=r.reviewRun(reviewBinding,shadow);assert.equal(review.status,'BLOCKED_BY_REQUIRED_CAPABILITY');assert.equal(review.executionReceipt,null);assert.equal(review.execution,'NOT_EXECUTED');assert.equal(r.journal.replay(ctx).headDigest,beforeReview.headDigest);observations.push({step:'installed review refusal after actual local shadow',result:review});
  const beforeThreshold=fs.readFileSync(path.join(work,'record.yaml'));
  const threshold=r.classifyChange({changes:[{path:'record.yaml',after:Buffer.from(sample.replace('100','99.9'))}]},ctx);
  assert.equal(threshold.disposition,'HUMAN_REQUIRED');assert.equal(threshold.executionAuthorized,false);assert.deepEqual(fs.readFileSync(path.join(work,'record.yaml')),beforeThreshold);observations.push({step:'threshold 100 to 99.9',result:threshold});
  fs.writeFileSync(path.join(work,'record.yaml'),reorder);const recoveryStart=performance.now();const secondRed=verify();assert.equal(secondRed.status,1);const stale=continuation();assert.equal(stale.status,'BLOCKED_BY_STALE_RUN');
  commitFresh('bounded-representation-defect');effect('canonical-two');const recoveryMs=performance.now()-recoveryStart;commitFresh('final-canonical');
  const current=r.journal.replay(ctx);assert.equal(current.budget.spent,2);assert.equal(current.budget.byKind[mechanical],2);assert.equal(Object.keys(current.continuations.grants).length,1);assert.equal(current.baselineDigest,baseline.digest);
  const finalBytes=fs.readFileSync(path.join(work,'record.yaml')),finalBaseline=r.describeBaseline([{path:'record.yaml',bytes:finalBytes}]);
  assert.notEqual(finalBaseline.digest,baseline.digest);assert.ok(r.verifyContext({authority:r.loadAuthority(Buffer.from(api.canonical(authority)),adoption),documents:[{path:'record.yaml',bytes:finalBytes}],acceptance}).status);
  const objective=r.describeReleaseObjective({artifactDigest:sha(finalBytes),target:{kind:'deployment.v1',id:'H09-NO-REAL-TARGET',environment:'production'},slices:['canonical-local','next-slice-unexecuted'],externalGate:null,maxEvidenceAge:100},ctx).objective;
  const release=r.bindReleaseObjective({objective,approval:receipt('bounded-grant',api.digestData(objective),api.digestData(objective.scope))},ctx),replay=r.replayRelease(release),next=r.nextObligation(release,replay),certificate=r.certifyRelease(release,replay);
  assert.equal(next.status,'BLOCKED_BY_REQUIRED_CAPABILITY');assert.equal(certificate.productionPass,false);assert.equal(certificate.certification,'NOT_EXECUTED');assert.equal(r.journal.replay(ctx).headDigest,current.headDigest);observations.push({step:'next slice/release remains unexecuted',next,certificate});
  const journalBeforeRollback=fs.readFileSync(path.join(state,'events.jsonl'));
  fs.copyFileSync(marker,path.join(state,'FIXTURE_ONLY-adoption-marker.json'));fs.unlinkSync(marker);fs.writeFileSync(path.join(work,'record.yaml'),sample);
  assert.equal(fs.readFileSync(path.join(consumer,'feature_list.json'),'utf8'),legacy);assert.equal(fs.readFileSync(path.join(consumer,'package.json'),'utf8'),rootPackage);
  assert.deepEqual(fs.readFileSync(path.join(state,'events.jsonl')),journalBeforeRollback);assert.equal(r.journal.readLegacy(ctx).toString(),legacy);assert.ok(fs.existsSync(path.join(runtimeDir,'index.mjs')));
  const reopened=api.openRuntime(host),reopenedContext=context(reopened);assert.equal(reopened.journal.replay(reopenedContext).headDigest,current.headDigest);check(run('bash',['scripts/verify-feature.sh','--ratio']),0);
  const metrics={scope:'installed local fixture only; not real human time saved',actualHumanPrompts:0,fixtureSignatures:signatures.length,fixtureSignaturesByKind:Object.fromEntries(['policy-adoption','baseline-acceptance','bounded-grant'].map(kind=>[kind,signatures.filter(s=>s.kind===kind).length])),humanGateReasonCodes:{HUMAN_REQUIRED:1},availabilityStops:{BLOCKED_BY_REQUIRED_CAPABILITY:2},staleStops:1,reusedContinuationGrants:1,effectRuns:2,freshRuns:current.runs.length-1,recoveryElapsedMs:recoveryMs,budgetSpent:current.budget.spent,authenticatedReviewReceipts:0,productionCertifications:0};
  const result={status:'LOCAL_CANARY_PASS',realAcceptance:'NOT_EXECUTED',positiveReviewBackend:'UNIMPLEMENTED',positiveProductionBackend:'UNIMPLEMENTED',initialCommit,finalCommit:objective.scope.integratedCommit,initialBaseline:baseline,finalCandidateBaseline:{...finalBaseline,acceptance:'CANDIDATE_NOT_ACCEPTED'},metrics,observations,rollback:{v1Sha256:sha(legacy),rootPackageSha256:sha(rootPackage),journalSha256:sha(journalBeforeRollback),markerRemoved:true,evidenceRetained:true}};
  if(process.env.H09_EVIDENCE_DIR){
    const out=path.resolve(process.env.H09_EVIDENCE_DIR);fs.mkdirSync(out,{recursive:true});
    for(const [name,value] of Object.entries({'canary.json':result,'commands.json':commands,'FIXTURE_ONLY-receipts.json':signatures,'FIXTURE_ONLY-authority.json':authority}))fs.writeFileSync(path.join(out,name),JSON.stringify(value,null,2)+'\n');
    fs.writeFileSync(path.join(out,'FIXTURE_ONLY-public-key.pem'),keys.publicKey.export({type:'spki',format:'pem'}));
    fs.writeFileSync(path.join(out,'legacy-v1.json'),legacy);fs.writeFileSync(path.join(out,'before.yaml'),sample);fs.writeFileSync(path.join(out,'bounded-defect.yaml'),reorder);fs.writeFileSync(path.join(out,'final-candidate.yaml'),finalBytes);fs.writeFileSync(path.join(out,'canonical-oracle.cjs'),oracle+'\n');
    fs.cpSync(state,path.join(out,'FIXTURE_ONLY-state'),{recursive:true});
  }
  console.log('H09_METRICS '+JSON.stringify(metrics));
});
