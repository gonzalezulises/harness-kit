#!/usr/bin/env bash
set -eu
for source in packs/autonomy/repo-template/scripts/quality-orchestrator/{authority,continuation}.mjs packs/autonomy/repo-template/scripts/quality-orchestrator/tests/continuation-authority.test.mjs; do
  node --check "$source"
done
printf '%s\n' 'PASS: H06 fix-1 changed modules and focused regression syntax'
