#!/usr/bin/env bash
# run-gates.sh — the registry of this repo's quality gates.
#
# Usage:
#   scripts/run-gates.sh [quick|full]     # default: quick
#
# One rule governs the registry: a convention without a gate is a suggestion.
# Every mechanically checkable rule in AGENTS.md gets a row here, and a new
# gate is proven by making it REJECT an invalid case before it ships.
#
# Aggregates:
#   quick  static gates only — no dependency install, safe mid-work, < seconds
#   full   quick + re-verification of claims + the complete `make check`
#
# A gate whose script is absent reports SKIP (the harness may be partially
# installed); SKIP never fails the run. FAIL always does.
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR" || exit 66
AGGREGATE="${1:-quick}"
case "$AGGREGATE" in quick|full) ;; *) echo "usage: run-gates.sh [quick|full]" >&2; exit 64 ;; esac

# Registry: name | aggregates it belongs to | command
GATES=(
  "decisions-append-only|quick full|bash scripts/verify-decisions.sh"
  "agent-notes-tree|quick full|bash scripts/verify-agent-notes.sh"
  "arch-boundaries|quick full|bash scripts/check-arch.sh"
  "claims-reverified|full|bash scripts/verify-claims.sh"
  "make-check|full|make check"
)

pass=0; fail=0; skip=0
printf '── gates · aggregate %s\n\n' "$AGGREGATE"

for row in "${GATES[@]}"; do
  name="${row%%|*}"; rest="${row#*|}"
  aggs="${rest%%|*}"; cmd="${rest#*|}"
  case " $aggs " in *" $AGGREGATE "*) ;; *) continue ;; esac

  script_path="$(printf '%s' "$cmd" | awk '$1=="bash"{print $2}')"
  if [[ -n "$script_path" && ! -f "$script_path" ]]; then
    printf '  %-24s SKIP (missing %s)\n' "$name" "$script_path"
    skip=$((skip+1)); continue
  fi

  start=$SECONDS
  if out="$(eval "$cmd" 2>&1)"; then
    printf '  %-24s PASS (%ss)\n' "$name" "$((SECONDS-start))"
    pass=$((pass+1))
  else
    printf '  %-24s FAIL (%ss)\n' "$name" "$((SECONDS-start))"
    printf '%s\n' "$out" | sed 's/^/      /' | tail -15
    fail=$((fail+1))
  fi
done

printf '\n── %d pass · %d fail · %d skip\n' "$pass" "$fail" "$skip"
[ "$fail" -eq 0 ]
