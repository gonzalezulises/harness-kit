#!/usr/bin/env bash
# init.sh — standard startup path for harness-kit.
# Install, verify, and report how to start. Every session begins here.
#
# Set RUN_START_COMMAND=1 to also start the dev server.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

INSTALL_CMD=""
VERIFY_CMD="make test"
START_CMD="make check"

echo "== Working directory =="
pwd

echo ""
echo "== Installing dependencies =="
if [[ -n "$INSTALL_CMD" ]]; then
  eval "$INSTALL_CMD"
else
  echo "(no install step configured)"
fi

echo ""
echo "== Verifying core baseline (packs and live quick gates are not included) =="
if [[ -n "$VERIFY_CMD" ]]; then
  if eval "$VERIFY_CMD"; then
    echo "Core baseline verification: PASS — run make check for full verification"
  else
    echo ""
    echo "Baseline verification FAILED."
    echo "Repair the baseline before starting new feature work — do not stack"
    echo "new work on a red baseline."
    exit 1
  fi
else
  echo "(no verification step configured — set VERIFY_CMD in init.sh)"
fi

echo ""
echo "== Ready =="
echo "Start with: $START_CMD"

if [[ "${RUN_START_COMMAND:-0}" == "1" ]] && [[ -n "$START_CMD" ]]; then
  echo ""
  exec bash -c "$START_CMD"
fi
