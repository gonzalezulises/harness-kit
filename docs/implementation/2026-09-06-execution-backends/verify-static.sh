#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$root"
for source in packs/autonomy/repo-template/scripts/quality-orchestrator/*.mjs packs/autonomy/repo-template/scripts/quality-orchestrator/tests/execution-backend.test.mjs; do
  node --check "$source"
done
node --input-type=module <<'JS'
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createHash} from 'node:crypto';
import {JOURNAL_RUNTIME_BINDING} from './packs/autonomy/repo-template/scripts/quality-orchestrator/index.mjs';
const test=fs.readFileSync('packs/autonomy/repo-template/scripts/quality-orchestrator/tests/execution-backend.test.mjs','utf8');
assert.ok(test.includes("assert.equal(JOURNAL_RUNTIME_BINDING,'"+JOURNAL_RUNTIME_BINDING+"')"));
for(const receiptPath of ['docs/implementation/2026-09-05-harness-hardening/h07/red-receipt.json','docs/implementation/2026-09-05-harness-hardening/h08/mutation-receipt.json']){
  const receipt=JSON.parse(fs.readFileSync(receiptPath,'utf8'));
  for(const section of ['tests','source','logs'])for(const [file,expected] of Object.entries(receipt[section]))assert.equal(createHash('sha256').update(fs.readFileSync(file)).digest('hex'),expected,file);
}
console.log('F24 syntax, unchanged journal runtime binding and preserved H07/H08 evidence: PASS');
JS
