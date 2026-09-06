#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$root"
bash -n bin/harness-status.sh
for source in packs/autonomy/repo-template/scripts/quality-orchestrator/*.mjs packs/autonomy/repo-template/scripts/quality-orchestrator/tests/product-loop.test.mjs; do
  node --check "$source"
done
bash docs/implementation/2026-09-06-execution-backends/verify-static.sh
node --input-type=module <<'JS'
import assert from 'node:assert/strict';
import {JOURNAL_RUNTIME_BINDING,PRODUCT_JOURNAL_RUNTIME_BINDING} from './packs/autonomy/repo-template/scripts/quality-orchestrator/journal.mjs';
assert.equal(JOURNAL_RUNTIME_BINDING,'5feecc71cf7f45ab4fbe449e1013b3769b4ff31fce7d6bed705eb779b43a483b');
assert.notEqual(PRODUCT_JOURNAL_RUNTIME_BINDING,JOURNAL_RUNTIME_BINDING);
console.log('Product syntax and distinct opt-in journal binding: PASS');
JS
