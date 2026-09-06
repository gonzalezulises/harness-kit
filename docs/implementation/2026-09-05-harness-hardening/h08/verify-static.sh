#!/usr/bin/env bash
set -euo pipefail
for file in \
  packs/autonomy/repo-template/scripts/quality-orchestrator/release.schema.mjs \
  packs/autonomy/repo-template/scripts/quality-orchestrator/release.mjs \
  packs/autonomy/repo-template/scripts/quality-orchestrator/classify.mjs \
  packs/autonomy/repo-template/scripts/quality-orchestrator/index.mjs \
  packs/autonomy/repo-template/scripts/quality-orchestrator/tests/release.test.mjs; do
  node --check "$file"
  echo "PASS syntax $file"
done
git diff --check -- packs/autonomy .harness/oracles/AC-H08.yaml .agents/notes/implemented/feature/2026-09-06-release-obligations-require-execution-provenance.md
echo 'PASS changed tracked source whitespace'
