#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$ROOT"
bash -n bin/harness-init.sh
bash -n bin/harness-activate.sh
bash -n bin/harness-status.sh
bash -n packs/autonomy/verify-pack.sh
node --check packs/autonomy/tests/installation.test.mjs
node --check packs/autonomy/tests/canary.test.mjs
python3 -I - <<'PY'
import hashlib, json, pathlib
manifest=json.loads(pathlib.Path('docs/implementation/2026-09-05-harness-hardening/h09/source-manifest.json').read_text())
for name, expected in manifest['files'].items():
    path=pathlib.Path(name)
    assert hashlib.sha256(path.read_bytes()).hexdigest()==expected['sha256'], name+' bytes differ'
    assert path.stat().st_mode & 0o777==expected['mode'], name+' mode differs'
print('H09 static and exact scoped source manifest verified')
PY
