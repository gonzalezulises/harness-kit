#!/usr/bin/env bash
# F19 — a repository registers its own gates without editing the runner.
#
# run-gates.sh is two things in one file: the runner (kit-owned, must stay
# byte-identical everywhere so a fix can propagate) and the registry (what THIS
# repository checks — necessarily different per repository). Fusing them has
# already cost three things:
#
#   · 2026-09-15: `version-sync` had to become `optional` for everyone because
#     installations share the kit's registry. DECISIONS records the price: deleting
#     verify-version-sync.sh from the kit now stands down instead of blocking.
#   · mallol-costos patched its copy of run-gates.sh by hand to get unblocked. A
#     file consumers must edit cannot also be a file an upgrade may replace.
#   · stack profiles (F26+) need to add gates per repository. Today that means
#     forking the runner.
#
# This REOPENS an alternative rejected on 2026-09-15 («a separate registry for
# installations: it breaks the in-sync test and the shared-file decision»). The
# new evidence is the upgrade path: see F20/F21. The runner stays one shared file;
# only the rows move out.
#
# Proposed contract (adjust the probe if you choose another shape): the runner
# appends rows from `.harness/gates.conf`, same format it already uses —
#     name|aggregates|required|optional|command
#
# Usage: bash tests/contract/F19-registry-is-not-the-runner.sh

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_DIR="$(cd "$HERE/../.." && pwd)"
# shellcheck source=tests/contract/lib.sh
. "$HERE/lib.sh"

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
echo "${BOLD}F19 — the gate registry is not the runner${RESET}"

sha_of() { git hash-object "$1" 2>/dev/null; }

new_repo "$WORK/consumer"
printf '%s\n' '{"name":"x","version":"1.0.0","scripts":{"check":"echo ok","dev":"echo dev"}}' > package.json
commit_all "base"
bash "$KIT_DIR/bin/harness-init.sh" --target . --level full >/dev/null 2>&1
commit_all "harness"
RUNNER_BEFORE="$(sha_of scripts/run-gates.sh)"

# ── a project gate that fails must block, without touching the runner ────────
mkdir -p .harness
printf '%s\n' 'probe-project-gate|quick full|required|false' > .harness/gates.conf
OUT="$(bash scripts/run-gates.sh quick 2>&1)"; RC=$?
expect_nonzero "a failing project gate registered in .harness/gates.conf blocks" "$RC"
case "$OUT" in
  *probe-project-gate*) ok "and the runner names it" ;;
  *)                    bad "the runner never mentions the project gate — it was not read" ;;
esac

# ── the same gate, passing, is reported as PASS ──────────────────────────────
printf '%s\n' 'probe-project-gate|quick full|required|true' > .harness/gates.conf
OUT="$(bash scripts/run-gates.sh quick 2>&1)"
if printf '%s\n' "$OUT" | grep -E '^[[:space:]]*probe-project-gate[[:space:]]' | grep -q 'PASS'; then
  ok "a passing project gate is reported as PASS"
else
  bad "a passing project gate is not reported as PASS"
fi

# ── a malformed row is a config error, never a silent skip ───────────────────
printf '%s\n' 'this row has no pipes' > .harness/gates.conf
bash scripts/run-gates.sh quick >/dev/null 2>&1
expect_nonzero "a malformed registry row does not pass" $?
rm -f .harness/gates.conf

assert_same() { if [[ "$2" == "$3" ]]; then ok "$1"; else bad "$1"; fi; }
assert_same "the runner was never edited to do any of this" "$RUNNER_BEFORE" "$(sha_of scripts/run-gates.sh)"
assert_same "and it is still byte-identical to the kit's template" \
  "$(sha_of "$KIT_DIR/templates/full/scripts/run-gates.sh")" "$(sha_of scripts/run-gates.sh)"

# ── the price recorded on 2026-09-15 is paid back ────────────────────────────
# In the kit itself, version-sync is the kit's own gate: losing its script must
# block again, not stand down.
snapshot_kit "$KIT_DIR" "$WORK/kit"
rm -f "$WORK/kit/scripts/verify-version-sync.sh"
( cd "$WORK/kit" && bash scripts/run-gates.sh quick >/dev/null 2>&1 )
expect_nonzero "in the kit, deleting verify-version-sync.sh blocks instead of standing down" $?

finish "F19"
