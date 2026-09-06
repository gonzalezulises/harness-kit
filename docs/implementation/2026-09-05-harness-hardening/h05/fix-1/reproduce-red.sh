#!/usr/bin/env bash
set -u
ROOT=$(git rev-parse --show-toplevel)
EVIDENCE="$ROOT/docs/implementation/2026-09-05-harness-hardening/h05/fix-1"
TEMP_H05=$(mktemp -d)
trap 'rm -rf "$TEMP_H05"' EXIT
cp -R "$EVIDENCE/source-before-membership/." "$TEMP_H05/"
cp -R "$ROOT/packs/autonomy/repo-template/scripts/quality-orchestrator/node_modules" "$TEMP_H05/node_modules"
node --test --test-name-pattern='H05-R1' "$TEMP_H05/tests/capabilities.test.mjs"
