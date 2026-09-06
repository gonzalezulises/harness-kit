#!/usr/bin/env bash
set -u
ROOT=$(git rev-parse --show-toplevel)
EVIDENCE="$ROOT/docs/implementation/2026-09-05-harness-hardening/h06/fix-1"
TEMP_H06_FIX=$(mktemp -d)
trap 'rm -rf "$TEMP_H06_FIX"' EXIT
cp -R "$EVIDENCE/source-before-review/." "$TEMP_H06_FIX/"
cp -R "$ROOT/packs/autonomy/repo-template/scripts/quality-orchestrator/node_modules" "$TEMP_H06_FIX/node_modules"
node --test "$TEMP_H06_FIX/tests/continuation-authority.test.mjs"
