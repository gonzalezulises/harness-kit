#!/usr/bin/env python3
"""Reproduce the exact current-test RED overlay and shipped GREEN, recording raw streams.
The overlay uses preserved actual versions, not synthetic stubs; dependencies are
provided by the one installed package and are not copied into evidence.
"""
import hashlib, json, os, pathlib, subprocess
ROOT = pathlib.Path(__file__).resolve().parents[4]
EVIDENCE = pathlib.Path(__file__).resolve().parent
RUNTIME = ROOT / 'packs/autonomy/repo-template/scripts/quality-orchestrator'
SNAPSHOT = EVIDENCE / 'final-falsification-source'
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
def relative(path):
    return str(path.relative_to(ROOT))
def run(label, directory):
    command = ['node', '--test', '--test-reporter=tap'] + [relative(p) for p in sorted((directory/'tests').glob('*.test.mjs'))]
    result = subprocess.run(command, cwd=ROOT, capture_output=True)
    stdout=EVIDENCE/(label+'.stdout.log');stderr=EVIDENCE/(label+'.stderr.log')
    stdout.write_bytes(result.stdout);stderr.write_bytes(result.stderr)
    record={'command':command,'exit_code':result.returncode,'logs':{relative(p):sha(p) for p in [stdout,stderr]}}
    (EVIDENCE/(label+'.command.json')).write_text(json.dumps(record,indent=2)+'\n')
    return record
if (EVIDENCE/'final-red.stdout.log').exists():
    raise SystemExit('Refusing to overwrite immutable evidence; reproduce in a new copy/directory.')
link=SNAPSHOT/'node_modules'
try:
    link.symlink_to(RUNTIME/'node_modules',target_is_directory=True)
    red=run('final-red',SNAPSHOT)
finally:
    link.unlink(missing_ok=True)
green=run('final-green',RUNTIME)
receipt={'schema_version':1,**red,
 'tests':{relative(p):sha(p) for p in sorted((RUNTIME/'tests').glob('*.mjs'))},
 'source':{relative(p):sha(p) for p in sorted(SNAPSHOT.rglob('*')) if p.is_file()}}
(EVIDENCE/'red-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps({'red_exit':red['exit_code'],'green_exit':green['exit_code']}))
raise SystemExit(0 if red['exit_code']==1 and green['exit_code']==0 else 1)
