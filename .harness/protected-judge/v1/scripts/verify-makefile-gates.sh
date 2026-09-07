#!/usr/bin/env bash
# verify-makefile-gates.sh — a declared gate must be able to fail.
#
# Usage:
#   scripts/verify-makefile-gates.sh
#
# The Makefile is the harness's single entry point: agents call targets, not raw
# commands. A target that only announces what it would do exits 0, and the contract
# counts a verification that never ran. That is worse than a missing target — a
# missing one is noticed, half a one is trusted.
#
# Existe porque pasó: `make e2e` shipped as `echo 'TODO: set the end-to-end command'`
# while AGENTS.md declared layer 3 mandatory for any change crossing a component
# boundary. Three repos inherited a mandatory layer that could not fail.
#
# The check is deliberately dumb: it reads what each target actually runs and asks
# whether that could ever return non-zero. It does not need to understand the command.
#
# Exit codes (fail-closed):
#   0  every target does real work, or is declared informational
#   1  EMPTY_GATE — a target announces a TODO and still exits 0, or runs nothing
#  66  no Makefile to inspect

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT_DIR="${HARNESS_TARGET_ROOT:-$ROOT_DIR}"
unset HARNESS_TARGET_ROOT
cd "$ROOT_DIR" || { echo "cannot cd to $ROOT_DIR" >&2; exit 66; }

MAKEFILE="${MAKEFILE_UNDER_TEST:-Makefile}"
[[ -f "$MAKEFILE" ]] || { echo "verify-makefile-gates: $MAKEFILE not found in $ROOT_DIR" >&2; exit 66; }

if [[ ! -t 1 ]] || [[ -n "${NO_COLOR:-}" ]]; then
  RED=""; GREEN=""; BOLD=""; RESET=""
else
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
fi

# Targets whose job is to print. They inform, they do not verify, so they are not gates.
# Add to this list deliberately, with a reason — it is the documented escape hatch.
INFORMATIONAL="${HARNESS_INFORMATIONAL_TARGETS:-help}"

is_informational() {
  for t in $INFORMATIONAL; do [[ "$1" == "$t" ]] && return 0; done
  return 1
}

# ── Walk the targets ─────────────────────────────────────────────────────────
OFFENDERS=""
INSPECTED=0
TARGET=""
RECIPE=""

flush_target() {
  [[ -z "$TARGET" ]] && return 0
  is_informational "$TARGET" && { TARGET=""; RECIPE=""; return 0; }

  INSPECTED=$((INSPECTED + 1))

  # Nothing to run at all.
  if [[ -z "${RECIPE//[[:space:]]/}" ]]; then
    OFFENDERS="$OFFENDERS$TARGET|runs nothing"$'\n'
    TARGET=""; RECIPE=""; return 0
  fi

  # Announces a placeholder. Fine only if it also refuses to succeed.
  if printf '%s' "$RECIPE" | grep -qE '\b(TODO|FIXME|PENDIENTE)\b'; then
    if ! printf '%s' "$RECIPE" | grep -qE '(^|[;&[:space:]])(false|exit[[:space:]]+[1-9])'; then
      OFFENDERS="$OFFENDERS$TARGET|announces a TODO and still exits 0"$'\n'
    fi
  fi

  TARGET=""; RECIPE=""
}

while IFS= read -r line; do
  # A recipe line is the only thing that starts with a real tab.
  if [[ "$line" == $'\t'* ]]; then
    [[ -n "$TARGET" ]] && RECIPE="$RECIPE${line#	}"$'\n'
    continue
  fi
  flush_target
  # `name:` but not `name :=` and not `.PHONY:`
  if [[ "$line" =~ ^([a-zA-Z0-9_-]+):([^=]|$) ]]; then
    TARGET="${BASH_REMATCH[1]}"
    RECIPE=""
  fi
done < "$MAKEFILE"
flush_target

# ── Verdict ──────────────────────────────────────────────────────────────────
# Sentinel: reaching the end having inspected nothing would be a silent pass, which
# is the exact failure this script exists to prevent.
if [[ "$INSPECTED" -eq 0 ]]; then
  echo "${RED}${BOLD}EMPTY_GATE: no targets were inspected in $MAKEFILE.${RESET}" >&2
  echo "Either the file has no targets or the parser stopped matching them." >&2
  exit 1
fi

if [[ -n "${OFFENDERS//[$'\n'[:space:]]/}" ]]; then
  echo "${RED}${BOLD}EMPTY_GATE${RESET}" >&2
  while IFS='|' read -r name why; do
    [[ -z "$name" ]] && continue
    echo "  ${BOLD}make $name${RESET} — $why" >&2
  done <<< "$OFFENDERS"
  echo "" >&2
  echo "A target that cannot fail is not a gate. Implement the command, or make the" >&2
  echo "placeholder refuse to succeed (append '; false') so it blocks until someone does." >&2
  exit 1
fi

echo "${GREEN}${BOLD}$INSPECTED target(s) inspected.${RESET} Every declared gate can fail."
exit 0
