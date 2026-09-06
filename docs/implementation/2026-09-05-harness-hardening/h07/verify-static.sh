#!/usr/bin/env bash
set -eu
runtime=packs/autonomy/repo-template/scripts/quality-orchestrator
for file in review.mjs review.schema.mjs review-shadow.mjs classify.mjs index.mjs tests/review.test.mjs; do
  node --check "$runtime/$file"
done
git diff --check -- "$runtime/classify.mjs" "$runtime/index.mjs"
echo 'PASS: six H07 source/test syntax checks and integration whitespace'
