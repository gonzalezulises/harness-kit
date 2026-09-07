import hashlib,json,os,pathlib,random,subprocess,tempfile,time
r=pathlib.Path(tempfile.mkdtemp(prefix='harness-git-lifetime-'))
def git(*args,trace=False):
    e=os.environ.copy()
    if trace:e['GIT_TRACE2_EVENT']=str(r/'trace.jsonl')
    p=subprocess.run(['git',*args],cwd=r,env=e,text=True,capture_output=True,timeout=30)
    assert p.returncode==0,(args,p.stdout,p.stderr)
    return p
git('init','-q','-b','main');git('config','user.name','lifetime fixture');git('config','user.email','fixture@example.test')
git('config','gc.auto','1');git('config','maintenance.strategy','gc')
rng=random.Random(12873)
count=0
while count<5:
    data=rng.randbytes(256*1024)
    if hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest().startswith('17'):
        (r/f'blob-{count}').write_bytes(data);count+=1
git('add','-A')
git('-c','maintenance.auto=false','commit','-qm','seed reachable loose objects')
p=git('gc','--auto',trace=True);returned=time.time_ns()
before=(r/'trace.jsonl').read_text()
deadline=time.monotonic()+20
while time.monotonic()<deadline:
    events=[json.loads(l) for l in (r/'trace.jsonl').read_text().splitlines()]
    if any(e.get('event')=='exit' and e.get('sid','').count('/')==0 and e.get('time') for e in events) and not (r/'.git/gc.pid').exists():
        time.sleep(.1);break
    time.sleep(.05)
after=(r/'trace.jsonl').read_text()
out={'root':str(r),'git_version':git('--version').stdout.strip(),'returned_ns':returned,'trace_before':len(before),'trace_after':len(after),'late_trace_lines':after[len(before):].splitlines(),'pid_remains':(r/'.git/gc.pid').exists(),'stdout':p.stdout,'stderr':p.stderr}
print(json.dumps(out,indent=2))
