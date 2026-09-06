#!/usr/bin/env bash
# Optional runtime only; missing prerequisites never count as test success.
set -euo pipefail
PACK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME_DIR="$PACK_DIR/repo-template/scripts/quality-orchestrator"
command -v node >/dev/null 2>&1 || { echo 'TOOL_FAILURE: autonomy pack requires Node >=22' >&2; exit 69; }
node --input-type=module - "$RUNTIME_DIR" <<'JS'
import { readFileSync } from 'node:fs';
const root=process.argv[2];
try {
  if(Number(process.versions.node.split('.')[0])<22) throw Error('Node >=22 required');
  for(const [name,version] of Object.entries({yaml:'2.9.0',zod:'4.5.4'})) {
    const actual=JSON.parse(readFileSync(`${root}/node_modules/${name}/package.json`,'utf8'));
    if(actual.version!==version)throw Error(`${name} must be ${version}`);
  }
} catch(error) {
  console.error(`TOOL_FAILURE: ${error.message}; run npm ci --prefix ${root} --ignore-scripts --no-audit --no-fund`);
  process.exit(69);
}
JS
node --test --test-reporter=tap "$RUNTIME_DIR"/tests/*.test.mjs
