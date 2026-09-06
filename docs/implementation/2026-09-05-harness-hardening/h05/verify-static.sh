#!/usr/bin/env bash
set -eu
for source in packs/autonomy/repo-template/scripts/quality-orchestrator/{capabilities,classify,journal,index}.mjs packs/autonomy/repo-template/scripts/quality-orchestrator/tests/capabilities.test.mjs; do
  node --check "$source"
done
printf '%s\n' 'PASS: H05 runtime, integration and focal test syntax'
