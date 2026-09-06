#!/usr/bin/env bash
set -u
ROOT=$(git rev-parse --show-toplevel)
EVIDENCE="$ROOT/docs/implementation/2026-09-05-harness-hardening/h06"
TEMP_H06=$(mktemp -d)
trap 'rm -rf "$TEMP_H06"' EXIT
cp -R "$EVIDENCE/source-before-regression/." "$TEMP_H06/"
cp -R "$ROOT/packs/autonomy/repo-template/scripts/quality-orchestrator/node_modules" "$TEMP_H06/node_modules"
node --test --test-name-pattern='H06-R1|H06 exhausted retry' "$TEMP_H06/tests/continuation.test.mjs"
