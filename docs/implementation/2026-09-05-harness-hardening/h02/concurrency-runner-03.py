import datetime,hashlib,json,os,pathlib,signal,subprocess,time
root=pathlib.Path('/workspace/scratch/adce1c53b293/harness-kit');out=root/'docs/implementation/2026-09-05-harness-hardening/h02'
tool=root.parent/'h02-pack-tools';tool.mkdir(exist_ok=True)
gh=tool/'gh';gh.write_text('#!/usr/bin/env bash\n# Authenticated coverage deliberately unavailable; no external preflight retry.\nexit 1\n');gh.chmod(0o755)
env=os.environ.copy();env['PATH']=str(tool)+':/workspace/scratch/adce1c53b293/tooling/k6-v2.1.0-linux-amd64:'+env['PATH']
source=[*root.glob('scripts/*.sh'),*root.glob('bin/*.sh'),*root.glob('templates/full/scripts/*.sh'),root/'tests/run-tests.sh',root/'tests/h01-hardening-regressions.py',root/'tests/h02-hardening-regressions.py',root/'packs/load-testing/verify-pack.sh',root/'packs/load-testing/repo-template/bin/perf-resolve-target']
hashes={str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in source}
records=[];jobs=[]
for label,argv in [('core-a-03',['bash','tests/run-tests.sh']),('core-b-03',['bash','tests/run-tests.sh']),('pack-a-03',['bash','packs/load-testing/verify-pack.sh']),('pack-b-03',['bash','packs/load-testing/verify-pack.sh'])]:
 stdout=open(out/(label+'.stdout.log'),'wb');stderr=open(out/(label+'.stderr.log'),'wb')
 started=time.monotonic();p=subprocess.Popen(argv,cwd=root,env=env,stdout=stdout,stderr=stderr,start_new_session=True)
 jobs.append((label,p,stdout,stderr,started));records.append({'label':label,'argv':argv,'pid':p.pid,'start_monotonic':started,'started_at':datetime.datetime.now(datetime.timezone.utc).isoformat()})
# Controlled readiness failure executes while both real core and pack suites contend.
label='readiness-timeout-03';args=['bash','packs/load-testing/verify-pack.sh'];faultenv=env|{'HARNESS_TEST_SERVER_DELAY':'2','HARNESS_TEST_READY_TIMEOUT':'0.05'}
started=time.monotonic()
with open(out/(label+'.stdout.log'),'wb') as stdout,open(out/(label+'.stderr.log'),'wb') as stderr:
 p=subprocess.run(args,cwd=root,env=faultenv,stdout=stdout,stderr=stderr,timeout=25)
elapsed=time.monotonic()-started
(out/(label+'.exit')).write_text(str(p.returncode)+'\n')
records.append({'label':label,'argv':args,'fault_env':{'HARNESS_TEST_SERVER_DELAY':'2','HARNESS_TEST_READY_TIMEOUT':'0.05'},'exit':p.returncode,'seconds':elapsed,'asserted':p.returncode==3 and elapsed<25 and 'bounded fixture readiness timeout' in (out/(label+'.stderr.log')).read_text()})
for label,p,stdout,stderr,started in jobs:
 try: code=p.wait(timeout=max(1,300-(time.monotonic()-started)))
 except subprocess.TimeoutExpired:
  os.killpg(p.pid,signal.SIGTERM);code=p.wait(timeout=5)
 stdout.close();stderr.close();(out/(label+'.exit')).write_text(str(code)+'\n')
 record=next(r for r in records if r['label']==label);record.update(exit=code,end_monotonic=time.monotonic(),seconds=time.monotonic()-started)
unchanged={str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest()==hashes[str(p.relative_to(root))] for p in source}
(out/'concurrency-03.json').write_text(json.dumps({'records':records,'source_sha256':hashes,'source_unchanged':unchanged,'coverage':'kit contention; authenticated GitHub cases deliberately unavailable; no Aurobalance causal reproduction'},indent=2)+'\n')
print(json.dumps({'runs':[{k:r[k] for k in ['label','exit','seconds']} for r in records],'source_unchanged':all(unchanged.values())},indent=2))
