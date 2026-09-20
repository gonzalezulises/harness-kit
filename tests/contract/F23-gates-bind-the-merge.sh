#!/usr/bin/env bash
# F23 — the gate registry runs where a merge can be refused, judged from the base.
#
# «A convention without a gate is a suggestion» — and a gate that only runs when
# someone types `make gates` is a convention. The required workflow executes three
# things: `make check`, verify-claims and verify-decisions. Architecture rules,
# falsifiable oracles, context routes, the delivery document and Agent Notes — every
# gate added since 2026-08-30 — bind nothing. The proof is in DECISIONS: a `required`
# gate was NOT_EXECUTED in every installation from 2026-09-03 and nobody knew until
# 2026-09-15, because no merge was ever refused for it.
#
# This probe is STATIC, and the kit's own lesson applies to it: configuration
# present is not evidence of enforcement. It only keeps the wiring from regressing.
# The receipt for this feature is a canary run like docs/evidence/2026-08-14 — a PR
# that violates an architecture rule and a PR that deletes a registry row, both
# refused by GitHub. Record it in docs/evidence/ and name it in the feature.
#
# What the wiring must have, in the kit's workflow AND the template's:
#   · the runner (and the registry, F19) come from the BASE checkout — a PR must not
#     be able to drop the gate that would have caught it
#   · the step writes a sentinel only after an observed zero, and the final
#     conclusion requires it
#   · the head is checked out with enough history for the gates that diff from a
#     base (context-routes, oracles, no-weakening): depth 1 makes them INCOMPLETE
#
# Usage: bash tests/contract/F23-gates-bind-the-merge.sh

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_DIR="$(cd "$HERE/../.." && pwd)"
# shellcheck source=tests/contract/lib.sh
. "$HERE/lib.sh"

echo "${BOLD}F23 — the gate registry binds the merge${RESET}"

for wf in ".github/workflows/required-quality.yml" "templates/full/.github/workflows/required-quality.yml"; do
  f="$KIT_DIR/$wf"
  [[ -f "$f" ]] || { bad "$wf not found — the probe inspected nothing"; continue; }

  if grep -qE 'run-gates\.sh' "$f"; then ok "$wf runs the gate registry"
  else bad "$wf never runs the gate registry — its gates bind no merge"; fi

  # The base checkout's sparse list is where protected files are declared.
  if awk '/sparse-checkout: \|/{f=1;next} f&&/^[[:space:]]+[A-Za-z0-9_.\/*-]+[[:space:]]*$/{print;next} {f=0}' "$f" \
       | grep -qE 'scripts/run-gates\.sh'; then
    ok "$wf takes the runner from the protected base"
  else
    bad "$wf does not take the runner from the base — a PR could drop its own gate"
  fi

  if grep -q 'gates-observed-zero' "$f" \
     && [[ "$(grep -c 'gates-observed-zero' "$f")" -ge 2 ]]; then
    ok "$wf writes a gates sentinel and the conclusion requires it"
  else
    bad "$wf has no gates sentinel in both the step and the final conclusion"
  fi

  if grep -qE 'fetch-depth:[[:space:]]*1[[:space:]]*$' "$f" && ! grep -qE 'fetch-depth:[[:space:]]*0' "$f"; then
    bad "$wf checks the head out at depth 1 — diff-based gates cannot resolve a base"
  else
    ok "$wf gives the head enough history for diff-based gates"
  fi
done

finish "F23"
