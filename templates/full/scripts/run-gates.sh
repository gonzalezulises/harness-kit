#!/usr/bin/env bash
# Versioned live gate registry. Only PASS satisfies an applicable gate.
# Base judge usage: bash /trusted/base/scripts/run-gates.sh quick --target /head
set -uo pipefail
JUDGE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGGREGATE="${1:-quick}"; [[ $# -eq 0 ]] || shift
TARGET="$JUDGE"
if [[ $# -gt 0 ]]; then
  [[ $# -eq 2 && "$1" == --target ]] || { echo 'usage: run-gates.sh [quick|full] [--target DIR]' >&2; exit 64; }
  TARGET="$(cd "$2" && pwd)" || exit 3
fi
case "$AGGREGATE" in quick|full) ;; *) exit 64 ;; esac
GATES=(
  "decisions-append-only|quick full|required|bash scripts/verify-decisions.sh"
  "agent-notes-tree|quick full|required|bash scripts/verify-agent-notes.sh"
  "arch-boundaries|quick full|required|bash scripts/check-arch.sh"
  "makefile-gates|quick full|required|bash scripts/verify-makefile-gates.sh"
  "version-sync|quick full|required|bash scripts/verify-version-sync.sh"
  "delivery-doc|quick full|required|bash scripts/verify-delivery-doc.sh"
  "context-routes|quick full|required|bash scripts/verify-context-routes.sh"
  "oracles-falsifiable|quick full|required|bash scripts/verify-oracles.sh"
  "claims-reverified|full|required|bash scripts/verify-claims.sh"
  "make-check|full|required|make check-core"
)
python3 -I - "$JUDGE" "$TARGET" "$AGGREGATE" "${GATES[@]}" <<'PY'
import json, os, pathlib, shlex, subprocess, sys, time
judge, target = map(pathlib.Path, sys.argv[1:3]); aggregate=sys.argv[3]
rows=[row.split('|') for row in sys.argv[4:]]
def strict(pairs):
    d={}
    for k,v in pairs:
        if k in d: raise ValueError('duplicate key: '+k)
        d[k]=v
    return d
def profile(root):
    p=root/'.harness/installation-profile.json'
    try: d=json.loads(p.read_text(), object_pairs_hook=strict)
    except (OSError,ValueError) as e: raise ValueError(f'ADOPTION_REQUIRED: {p}: {e}')
    if not isinstance(d,dict) or set(d)!={'schema_version','installation','gates'} or type(d['schema_version']) is not int or d['schema_version']!=1 or d['installation'] not in {'kit','full','minimal'}: raise ValueError('invalid installation profile v1')
    gates=d['gates']
    if not isinstance(gates,dict) or set(gates)!={r[0] for r in rows}: raise ValueError('profile must declare every registry gate exactly once')
    for name,v in gates.items():
        if not isinstance(v,dict) or set(v)!={'applicable','reason'} or type(v['applicable']) is not bool or not isinstance(v['reason'],str) or not v['reason'].strip(): raise ValueError('invalid applicability for '+name)
        expected=d['installation']!='minimal' and (name!='version-sync' or d['installation']=='kit')
        if v['applicable']!=expected: raise ValueError('profile cannot remove required gate '+name)
    return d
try:
    policy=profile(judge)
    if target!=judge:
        expected={'schema_version':1,'interfaces':['target-root-v1','installation-profile-v1','match-argv-v1']}
        try: contract=json.loads((judge/'.harness/judge-contract.json').read_text(),object_pairs_hook=strict)
        except (OSError,ValueError): raise ValueError('ADOPTION_REQUIRED: protected judge contract missing or invalid')
        if contract!=expected: raise ValueError('ADOPTION_REQUIRED: unsupported protected judge contract')
        if profile(target)!=policy: raise ValueError('ADOPTION_REQUIRED: head profile differs from protected base')
    if policy['installation']=='minimal': raise ValueError('minimal installation has no full gate capability')
except ValueError as e:
    print('NOT_CONFIGURED: '+str(e), file=sys.stderr); sys.exit(2)
print(f'── gates · aggregate {aggregate} · profile v1/{policy["installation"]}', flush=True)
if target!=judge:
    for label,path in [('judge/base',judge),('target/head',target)]:
        r=subprocess.run(['git','rev-parse','HEAD'],cwd=path,capture_output=True,text=True)
        if r.returncode: print('INCOMPLETE: cannot identify '+label); sys.exit(4)
        print(label+': '+r.stdout.strip())
states={0:'PASS',1:'FAIL',2:'NOT_CONFIGURED',3:'TOOL_FAILURE',4:'INCOMPLETE',5:'POLICY'}
passed=blocked=na=0
for name,aggs,requirement,cmd in rows:
    if aggregate not in aggs.split(): continue
    applicability=policy['gates'][name]
    if not applicability['applicable']:
        print(f'  {name:24s} NOT_APPLICABLE ({applicability["reason"]})'); na+=1; continue
    argv=shlex.split(cmd); env=os.environ.copy()
    env['HARNESS_TARGET_ROOT']=str(target)
    if target!=judge:
        env.update(ARCH_RULES_FILE=str(judge/'.harness/arch-rules.json'), CONTEXT_ROUTES=str(judge/'.harness/context-routes.json'), ORACLES_DIR=str(judge/'.harness/oracles'), CLAIMS_BASE_FILE=str(judge/'feature_list.json'), DECISIONS_BASE_FILE=str(judge/'DECISIONS.md'))
    if argv[0]=='bash':
        script=judge/argv[1]
        if not script.is_file():
            print(f'  {name:24s} NOT_EXECUTED (missing {script})'); blocked+=1; continue
        argv[1]=str(script)
        if name=='arch-boundaries': argv.append(str(target))
        # A missing architecture policy is an installation failure, not zero rules.
        if name=='arch-boundaries' and not pathlib.Path(env.get('ARCH_RULES_FILE',target/'.harness/arch-rules.json')).is_file():
            print('  arch-boundaries NOT_CONFIGURED (missing policy)'); blocked+=1; continue
    else: env.pop('HARNESS_TARGET_ROOT',None)
    start=time.monotonic()
    try: result=subprocess.run(argv,cwd=target,env=env,capture_output=True,text=True); state=states.get(result.returncode,'UNKNOWN')
    except OSError as e: print('TOOL_FAILURE: '+str(e)); blocked+=1; continue
    print(f'  {name:24s} {state} ({time.monotonic()-start:.1f}s, exit {result.returncode})',flush=True)
    if result.returncode: print(result.stdout+result.stderr); blocked+=1
    else: passed+=1
print(f'── {passed} pass · {blocked} blocking · {na} not applicable')
if blocked: print('Only PASS satisfies a gate. A non-PASS state was not verified.')
sys.exit(1 if blocked else 0)
PY
