#!/usr/bin/env bash
# Report observed local verification and inspected remote rules; never infer readiness from filenames.
# Usage: harness-status.sh [--target DIR] [DIR]
set -uo pipefail
TARGET=.
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) [[ $# -ge 2 ]] || exit 64; TARGET="$2"; shift 2 ;;
    -h|--help) sed -n '2,3p' "$0"; exit 0 ;;
    *) TARGET="$1"; shift ;;
  esac
done
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 -I - "$TARGET" "$KIT" <<'PY'
import json, os, pathlib, shutil, signal, subprocess, sys
root=pathlib.Path(sys.argv[1]).resolve(); kit=pathlib.Path(sys.argv[2])
if not root.is_dir(): print('harness-status: no such directory',file=sys.stderr); sys.exit(64)
if not all((root/x).is_file() for x in ['AGENTS.md','feature_list.json']): print('NOT_ACTIVATED — no harness contract/state'); sys.exit(1)
version=(kit/'VERSION').read_text().strip(); stamp=root/'.harness/kit-version'
print('Kit: '+(stamp.read_text().strip() if stamp.is_file() else version+' (version not recorded)'))
if stamp.is_file() and stamp.read_text().strip()!=version: print('desactualizado — hay '+version)
try:
    profile=json.loads((root/'.harness/installation-profile.json').read_text())
    if profile.get('installation')=='minimal': print('NOT_VERIFIED — minimal contract scaffold; full mechanical gates are not installed'); sys.exit(1)
    timeout=float(os.environ.get('HARNESS_STATUS_TIMEOUT','120'))
    if not 0 < timeout <= 1800: raise ValueError('timeout must be >0 and <=1800 seconds')
    # Own the ordinary verification descendants, not just the make parent.
    process=subprocess.Popen(['make','check'],cwd=root,stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE,text=True,start_new_session=True)
    try:
        stdout,stderr=process.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        try: os.killpg(process.pid,signal.SIGTERM)
        except ProcessLookupError: pass
        try:
            process.communicate(timeout=0.2)
        except subprocess.TimeoutExpired:
            pass
        # A descendant can ignore TERM or close its inherited pipes. Always
        # finish the owned group even when the direct make parent already exited.
        try: os.killpg(process.pid,signal.SIGKILL)
        except ProcessLookupError: pass
        try:
            process.communicate(timeout=0.2)
        except subprocess.TimeoutExpired:
            # Escaped process groups are outside this local cleanup contract;
            # their inherited pipes cannot make the status command wait forever.
            process.stdout.close(); process.stderr.close()
            process.wait(timeout=0.2)
        raise
    result=subprocess.CompletedProcess(['make','check'],process.returncode,stdout,stderr)
except (OSError,ValueError,subprocess.TimeoutExpired) as e:
    print('BLOCKED_TOOL — local verification indeterminate: '+str(e)); sys.exit(1)
if result.returncode:
    print('BLOCKED_LOCAL — make check exit '+str(result.returncode)); print(result.stdout+result.stderr); sys.exit(1)
print('Local: observed make check exit 0')
r=subprocess.run(['git','remote','get-url','origin'],cwd=root,capture_output=True,text=True)
if r.returncode or not r.stdout.strip(): print('READY_LOCAL — local check passed; no remote protection was inspected'); sys.exit(0)
url=r.stdout.strip()
if url.startswith('git@github.com:'): slug=url[len('git@github.com:'):]
elif url.startswith('https://github.com/'): slug=url[len('https://github.com/'):]
else: print('INDETERMINATE_REMOTE — unsupported remote'); sys.exit(1)
slug=slug[:-4] if slug.endswith('.git') else slug
def api(path):
    r=subprocess.run(['gh','api',path],capture_output=True,text=True,timeout=30)
    if r.returncode: raise ValueError('API query failed: '+path)
    return json.loads(r.stdout)
try:
    rules=api('repos/'+slug+'/rulesets?includes_parents=true')
    if not isinstance(rules,list): raise ValueError('invalid ruleset list')
    details=[api('repos/'+slug+'/rulesets/'+str(r['id'])) for r in rules]
    protected=False; integrity=False
    for d in details:
        if not isinstance(d,dict) or not isinstance(d.get('rules'),list) or not isinstance(d.get('bypass_actors'),list) or d.get('target') not in {'branch','tag','push'} or d.get('enforcement') not in {'active','disabled','evaluate'}: raise ValueError('invalid or incomplete ruleset detail')
        if d.get('enforcement')!='active' or d.get('bypass_actors'): continue
        rr=d['rules']; types={r.get('type') for r in rr}
        cond=d.get('conditions',{}).get('ref_name',{})
        applies=cond.get('include')==['~DEFAULT_BRANCH'] and cond.get('exclude')==[]
        if d.get('target')=='branch' and applies and {'pull_request','non_fast_forward'}<=types:
            for rule in rr:
                p=rule.get('parameters',{})
                if rule.get('type')=='required_status_checks' and p.get('strict_required_status_checks_policy') is True and any(x.get('context')=='Required quality' for x in p.get('required_status_checks',[])): protected=True
        if d.get('target')=='push':
            for rule in rr:
                if rule.get('type')=='file_path_restriction' and '.github/workflows/required-quality.yml' in rule.get('parameters',{}).get('restricted_file_paths',[]): integrity=True
    if protected and not (root/'.github/workflows/required-quality.yml').is_file(): raise ValueError('required workflow missing locally')
except (OSError,ValueError,KeyError,TypeError,subprocess.TimeoutExpired) as e:
    print('INDETERMINATE_REMOTE — local check passed, protection query incomplete: '+str(e)); sys.exit(1)
state='READY_DUAL' if protected and integrity else 'READY_PARTIAL' if protected else 'READY_LOCAL'
print(state+' — local check passed; inspected default-branch required check='+str(protected)+', workflow path protection='+str(integrity))
print('These observations are not an adversarial merge canary or production acceptance.')
PY
