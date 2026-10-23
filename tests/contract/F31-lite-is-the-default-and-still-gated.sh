#!/usr/bin/env bash
# F31 — lite is the default level, carries no feature ceremony, and still gates the merge.
#
# On 2026-10-23 a measurement over the last 30 merged PRs of each governed repo showed the
# cost of the harness was not CI time (1–6 min) but bookkeeping: 32–35 % of the files a PR
# touched were process files, against 0 % in ungoverned repos. The root was that
# harness-activate always installed `--level full`. Lite keeps what caught real failures
# (the Required quality workflow, both rulesets, verify-claims, verify-decisions) and
# drops what only produced paperwork.
#
# The control at the bottom keeps the cut honest: lite must still refuse a rewritten
# decision, or it is not a gate.
#
# Usage: bash tests/contract/F31-lite-is-the-default-and-still-gated.sh

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_DIR="$(cd "$HERE/../.." && pwd)"
# shellcheck source=tests/contract/lib.sh
. "$HERE/lib.sh"

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
echo "${BOLD}F31 — lite is the default and still gated${RESET}"

new_repo "$WORK/app"
printf '%s\n' '{"name":"x","version":"1.0.0","scripts":{"check":"echo ok"}}' > package.json
echo '{}' > package-lock.json
commit_all "base"

bash "$KIT_DIR/bin/harness-init.sh" --target . >/dev/null 2>&1
expect_zero "harness-init without --level succeeds" $?
[[ "$(cat .harness/level 2>/dev/null)" == "lite" ]]
expect_zero "the default level is lite" $?

for f in AGENTS.md CLAUDE.md DECISIONS.md Makefile feature_list.json \
         scripts/verify-claims.sh scripts/verify-decisions.sh \
         .github/workflows/required-quality.yml \
         .github/rulesets/required-quality-check.json \
         .github/rulesets/required-quality-integrity.json .harness/kit-version; do
  [[ -f "$f" ]]
  expect_zero "lite installs the gate piece $f" $?
done

for f in PROGRESS.md session-handoff.md clean-state-checklist.md init.sh \
         scripts/verify-feature.sh scripts/run-gates.sh; do
  [[ ! -e "$f" ]]
  expect_zero "lite does not install the ceremony piece $f" $?
done

commit_all "harness"
make check >/dev/null 2>&1
expect_zero "make check is green straight after activation" $?
bash scripts/verify-claims.sh >/dev/null 2>&1
expect_zero "verify-claims accepts the empty feature list (NO_CLAIMS)" $?
bash scripts/verify-decisions.sh >/dev/null 2>&1
expect_zero "verify-decisions accepts the seeded ledger" $?

# ── control: lite still refuses a rewritten decision ─────────────────────────
# The rewrite lands on a branch, as a pull request would; main stays the protected base.
git branch -M main >/dev/null 2>&1
git checkout -q -b rewrite
python3 - <<'PYEOF'
p = "DECISIONS.md"; s = open(p, encoding="utf-8").read()
open(p, "w", encoding="utf-8").write(s.replace("Adopt", "Quietly drop", 1))
PYEOF
commit_all "rewrite history"
bash scripts/verify-decisions.sh main >/dev/null 2>&1
expect_nonzero "control: an edited earlier decision is still rejected" $?

finish "F31"
