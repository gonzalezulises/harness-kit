#!/usr/bin/env bash
# F16 — the architecture gate must be able to fail, and must not pass by absence.
#
# «Una puerta declarada tiene que poder fallar» was applied to the Makefile and
# never to check-arch.sh. Three ways it could not fail were reproduced on
# 2026-09-19 against 9f4e047:
#
#   · the rules file deleted            → exit 0, and run-gates printed PASS
#   · `expect: exit0` on a failing check → [OK], because `|| true` zeroes $?
#   · an unparseable `expect` value      → silently treated as `empty`
#
# The two controls at the top keep the repair honest: a checker that always fails
# would satisfy every case below them.
#
# `rules: []` is deliberately NOT a failure here: the kit's convention is that an
# empty set passes as long as it says so out loud (NO_CLAIMS, no oracles). Rules
# REMOVED relative to the base are a weakening, and F24 owns that.
#
# Usage: bash tests/contract/F16-check-arch-fails-closed.sh

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_DIR="$(cd "$HERE/../.." && pwd)"
# shellcheck source=tests/contract/lib.sh
. "$HERE/lib.sh"

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
CHECKER="$KIT_DIR/templates/full/scripts/check-arch.sh"
echo "${BOLD}F16 — check-arch fails closed${RESET}"
[[ -f "$CHECKER" ]] || { echo "missing $CHECKER" >&2; exit 3; }

# write_rules <json> — replace the rules file in the current repo.
write_rules() { mkdir -p .harness; printf '%s\n' "$1" > .harness/arch-rules.json; }

new_repo "$WORK/repo"
mkdir -p scripts && cp "$CHECKER" scripts/check-arch.sh
echo 'export const ok = 1' > a.ts
commit_all "base"

# ── controls ─────────────────────────────────────────────────────────────────
write_rules '{"rules":[{"id":"holds","check":"git grep -n FORBIDDEN -- a.ts || true","expect":"empty","what":"w","why":"y","fix":"f"}]}'
bash scripts/check-arch.sh . >/dev/null 2>&1; expect_zero "control: a rule that holds passes" $?

write_rules '{"rules":[{"id":"fires","check":"git grep -n export -- a.ts || true","expect":"empty","what":"w","why":"y","fix":"f"}]}'
bash scripts/check-arch.sh . >/dev/null 2>&1; expect_nonzero "control: a violated rule blocks" $?

# ── the three ways it could not fail ─────────────────────────────────────────
rm -f .harness/arch-rules.json
bash scripts/check-arch.sh . >/dev/null 2>&1; expect_nonzero "a missing rules file does not pass" $?

write_rules '{"rules":[{"id":"must-exit-zero","check":"false","expect":"exit0","what":"w","why":"y","fix":"f"}]}'
bash scripts/check-arch.sh . >/dev/null 2>&1; expect_nonzero "expect=exit0 fires when the check exits non-zero" $?

write_rules '{"rules":[{"id":"typo","check":"true","expect":"exti0","what":"w","why":"y","fix":"f"}]}'
bash scripts/check-arch.sh . >/dev/null 2>&1; expect_nonzero "an unknown expect value is a config error, not a default" $?

# ── and the runner must not launder the absence into PASS ────────────────────
RUNNER="$KIT_DIR/templates/full/scripts/run-gates.sh"
if [[ -f "$RUNNER" ]]; then
  cp "$RUNNER" scripts/run-gates.sh
  rm -f .harness/arch-rules.json
  OUT="$(bash scripts/run-gates.sh quick 2>&1)"
  if printf '%s\n' "$OUT" | grep -E '^[[:space:]]*arch-boundaries[[:space:]]' | grep -q 'PASS'; then
    bad "run-gates reports arch-boundaries PASS with no rules file"
  else
    ok "run-gates does not report arch-boundaries PASS with no rules file"
  fi
else
  bad "run-gates.sh template not found — the runner case inspected nothing"
fi

finish "F16"
