#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT
cp -R "$ROOT/docs/implementation/2026-09-05-harness-hardening/h04/red-source/." "$FIXTURE/"
ln -s "$ROOT/packs/autonomy/repo-template/scripts/quality-orchestrator/node_modules" "$FIXTURE/node_modules"
node --test --test-name-pattern='stale run cannot reserve|closed event contract' "$FIXTURE/tests/journal.test.mjs"
