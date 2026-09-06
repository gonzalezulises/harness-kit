#!/usr/bin/env bash
set -eu
for source in packs/autonomy/repo-template/scripts/quality-orchestrator/{authority,budget,continuation,capabilities,classify,journal,index}.mjs packs/autonomy/repo-template/scripts/quality-orchestrator/tests/continuation.test.mjs; do
  node --check "$source"
done
printf '%s\n' 'PASS: H06 runtime, integration and focal test syntax'
