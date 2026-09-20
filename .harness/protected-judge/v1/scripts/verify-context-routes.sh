#!/usr/bin/env bash
# Govern committed, staged, unstaged and untracked paths using current citations.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${HARNESS_TARGET_ROOT:-$ROOT}" || exit 3
unset HARNESS_TARGET_ROOT
python3 -I - "${1:-gate}" <<'PY'
import fnmatch,json,os,pathlib,subprocess,sys
mode=sys.argv[1]
def git(*args):
    r=subprocess.run(['git',*args],capture_output=True)
    if r.returncode: raise RuntimeError(r.stderr.decode(errors='replace'))
    return r.stdout
def strict(pairs):
    d={}
    for k,v in pairs:
        if k in d: raise ValueError('duplicate key '+k)
        d[k]=v
    return d
try:
    cfg=json.loads(pathlib.Path(os.environ.get('CONTEXT_ROUTES','.harness/context-routes.json')).read_text(),object_pairs_hook=strict)
    if not isinstance(cfg,dict) or not isinstance(cfg.get('routes'),list) or not cfg['routes']: raise ValueError('route map declares no routes')
    routes=cfg['routes']
    for r in routes:
        if not isinstance(r,dict): raise ValueError('route must be an object')
        for key in ['paths','read']:
            if not isinstance(r.get(key),list) or not r[key] or any(not isinstance(x,str) or not x.strip() or '\0' in x for x in r[key]): raise ValueError('route needs nonempty paths and read arrays')
        if 'why' in r and not isinstance(r['why'],str): raise ValueError('why must be a string')
except (ValueError,OSError) as e: print('context-routes: NOT_CONFIGURED '+str(e),file=sys.stderr); sys.exit(2)
try:
    base=os.environ.get('ROUTES_BASE')
    if base:
        try: git('rev-parse','--verify',base+'^{commit}')
        except RuntimeError: print('context-routes: invalid ROUTES_BASE',file=sys.stderr); sys.exit(2)
    else:
        for ref in ['origin/main','origin/master','main','master']:
            try: base=git('merge-base','HEAD',ref).decode().strip(); break
            except RuntimeError: continue
        if not base: raise RuntimeError('no base ref; set ROUTES_BASE')
    changed=set()
    for args in [('diff','--name-only','-z',base,'HEAD'),('diff','--cached','--name-only','-z'),('diff','--name-only','-z'),('ls-files','--others','--exclude-standard','-z')]:
        changed.update(os.fsdecode(p) for p in git(*args).split(b'\0') if p)
    evidence=git('log','--format=%B',base+'..HEAD').decode(errors='replace')
    for name in sorted(changed):
        if name.startswith('.agents/notes/') or 'AGENT-NOTE' in name or 'agent-note' in name:
            p=pathlib.Path(name)
            if p.is_file(): evidence+='\n'+p.read_text()
except (RuntimeError,OSError,UnicodeError) as e: print('context-routes: INCOMPLETE '+str(e),file=sys.stderr); sys.exit(4)
hits=[(r,sorted(p for p in changed if any(fnmatch.fnmatchcase(p,pat) for pat in r['paths']))) for r in routes]
hits=[(r,paths) for r,paths in hits if paths]
if not hits: print('context-routes: no governed changes in branch/index/workspace'); sys.exit(0)
missing=0
for r,paths in hits:
    cited=any(d in evidence or pathlib.Path(d).name in evidence for d in r['read'])
    print(('read' if mode=='--list' else 'cites' if cited else 'CITES NOTHING')+': '+', '.join(paths))
    print('  governed by: '+', '.join(r['read']))
    if r.get('why'): print('  '+r['why'])
    if not cited: missing+=1
if mode=='--list': sys.exit(0)
if missing: print('Cite a governing document in a branch commit message or current Agent Note.',file=sys.stderr)
else: print('context-routes: every governed change cites a governing document')
sys.exit(1 if missing else 0)
PY
