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
# ── Only PASS satisfies a gate ───────────────────────────────────────────────
# This runner used to know two answers: it ran and exited zero, or it did not.
# Everything else became FAIL, and a gate whose script was missing became SKIP,
# which never failed the run. Both collapses hide the state that matters most:
# the gate that never actually checked anything.
#
# That is not hypothetical here. verify-delivery-doc.sh shipped with a branch
# that, handed a ref it could not resolve, printed "no new migrations" for a
# release that shipped one — a green line for work never done. The script was
# repaired, but a runner that cannot tell "checked and clean" from "could not
# check" will keep converting silence into confidence.
#
# So a gate now reports one of these, and only PASS lets the run go green:
#
#   PASS            exit 0 — it ran, it checked, it is clean
#   FAIL            exit 1 — it ran and found a real problem. Fix the code
#   NOT_CONFIGURED  exit 2 — its config or contract is invalid. Fix the config
#   TOOL_FAILURE    exit 3 — the tool or environment broke. Fix the environment
#   INCOMPLETE      exit 4 — it could not finish; the result is unknown or stale
#   POLICY          exit 5 — an integrity or policy violation
#   UNKNOWN         any other exit code — treated as blocking, never as pass
#   NOT_EXECUTED    its script is absent
#
# FAIL and TOOL_FAILURE both block, and the distinction is not cosmetic: one
# says fix your code, the other says fix your machine. Reporting them as one
# thing sends people to the wrong place.
#
# NOT_EXECUTED blocks for a gate declared `required` and stands down for one
# declared `optional` — the harness may legitimately be half-installed, but a
# required gate must not go missing quietly.
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR" || exit 66
AGGREGATE="${1:-quick}"
case "$AGGREGATE" in quick|full) ;; *) echo "usage: run-gates.sh [quick|full]" >&2; exit 64 ;; esac

# Registry: name | aggregates | required|optional | command
#
# `required` means: if this gate's script is not here, that is a finding. Mark a
# gate optional only when its absence is a real, expected configuration — never
# to quiet a gate that keeps failing.
GATES=(
  "decisions-append-only|quick full|required|bash scripts/verify-decisions.sh"
  "agent-notes-tree|quick full|required|bash scripts/verify-agent-notes.sh"
  "arch-boundaries|quick full|required|bash scripts/check-arch.sh"
  "makefile-gates|quick full|required|bash scripts/verify-makefile-gates.sh"
  "version-sync|quick full|required|bash scripts/verify-version-sync.sh"
  "delivery-doc|quick full|required|bash scripts/verify-delivery-doc.sh"
  "context-routes|quick full|required|bash scripts/verify-context-routes.sh"
  "claims-reverified|full|required|bash scripts/verify-claims.sh"
  "make-check|full|required|make check"
)

# What each exit code means, and whether it lets the run stay green.
state_for_exit() {
  case "$1" in
    0) printf 'PASS' ;;
    1) printf 'FAIL' ;;
    2) printf 'NOT_CONFIGURED' ;;
    3) printf 'TOOL_FAILURE' ;;
    4) printf 'INCOMPLETE' ;;
    5) printf 'POLICY' ;;
    *) printf 'UNKNOWN' ;;
  esac
}

# What to do about each state, in the words of whoever has to fix it.
repair_hint() {
  case "$1" in
    FAIL)           printf 'the gate ran and found a real problem — fix the code' ;;
    NOT_CONFIGURED) printf 'its configuration or contract is invalid — fix the config, not the gate' ;;
    TOOL_FAILURE)   printf 'the tool or environment broke — this is not a code defect' ;;
    INCOMPLETE)     printf 'it could not finish, so nothing was verified — do not read this as clean' ;;
    POLICY)         printf 'an integrity or policy violation — needs a human decision' ;;
    UNKNOWN)        printf 'it exited with a code this runner does not know — treat as unverified' ;;
    NOT_EXECUTED)   printf 'a required gate is missing from this repo — install it or declare it optional' ;;
    *)              printf '' ;;
  esac
}

pass=0; blocked=0; stood_down=0
declare -a BLOCKING_SUMMARY=()
printf '── gates · aggregate %s\n\n' "$AGGREGATE"

for row in "${GATES[@]}"; do
  IFS='|' read -r name aggs requirement cmd <<<"$row"
  case " $aggs " in *" $AGGREGATE "*) ;; *) continue ;; esac

  script_path="$(printf '%s' "$cmd" | awk '$1=="bash"{print $2}')"
  if [[ -n "$script_path" && ! -f "$script_path" ]]; then
    if [[ "$requirement" == "required" ]]; then
      printf '  %-24s NOT_EXECUTED  (missing %s)\n' "$name" "$script_path"
      printf '      %s\n' "$(repair_hint NOT_EXECUTED)"
      blocked=$((blocked+1)); BLOCKING_SUMMARY+=("$name NOT_EXECUTED")
    else
      printf '  %-24s not installed (optional)\n' "$name"
      stood_down=$((stood_down+1))
    fi
    continue
  fi

  start=$SECONDS
  out="$(eval "$cmd" 2>&1)"; rc=$?
  state="$(state_for_exit "$rc")"
  elapsed="$((SECONDS-start))"

  if [[ "$state" == "PASS" ]]; then
    printf '  %-24s PASS (%ss)\n' "$name" "$elapsed"
    pass=$((pass+1))
    continue
  fi

  printf '  %-24s %s (%ss, exit %s)\n' "$name" "$state" "$elapsed" "$rc"
  printf '      %s\n' "$(repair_hint "$state")"
  printf '%s\n' "$out" | sed 's/^/      /' | tail -15
  blocked=$((blocked+1)); BLOCKING_SUMMARY+=("$name $state")
done

printf '\n── %d pass · %d blocking · %d optional not installed\n' "$pass" "$blocked" "$stood_down"

if [[ "$blocked" -gt 0 ]]; then
  printf '\nBlocking:\n'
  for b in "${BLOCKING_SUMMARY[@]}"; do printf '  · %s\n' "$b"; done
  printf '\nOnly PASS satisfies a gate. A state that is not PASS was not verified,\n'
  printf 'and an unverified gate is not a passing one.\n'
  exit 1
fi
exit 0
