#!/usr/bin/env bash
# F21 — upgrading the kit replaces the judge and never touches the memory.
#
# The upgrade path harness-status recommends is `harness-init.sh --force`. Run on
# 2026-09-19 against a repository with real state, it replaced DECISIONS.md,
# PROGRESS.md, feature_list.json and .harness/arch-rules.json with the templates:
# 0 of 4 project edits survived (all seven owned files are replaced; four were
# measured). The kit denies that very command to its own agent in
# .claude/settings.json, and then recommends it to humans with a one-line warning
# to «review the diff before committing» — after the ledger is already gone.
#
# With no safe upgrade, installations do not upgrade, and every fix the kit ships
# stays in the kit. That is how a client repo ran a blocked gate for days.
#
# Proposed contract: `bin/harness-upgrade.sh --target DIR [--dry-run]`
#   · replaces managed files (F20) with the kit's current version
#   · never writes to an owned file
#   · a managed file edited locally is not silently destroyed: the upgrade refuses,
#     or keeps the local version recoverable, and names the file either way
#   · an installation that predates the lock can still be upgraded
#
# Usage: bash tests/contract/F21-upgrade-preserves-state.sh

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_DIR="$(cd "$HERE/../.." && pwd)"
# shellcheck source=tests/contract/lib.sh
. "$HERE/lib.sh"

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
echo "${BOLD}F21 — an upgrade preserves the repository's state${RESET}"

UPGRADE_REL="bin/harness-upgrade.sh"
if [[ ! -f "$KIT_DIR/$UPGRADE_REL" ]]; then
  bad "$UPGRADE_REL does not exist — the only upgrade path is still --force"
fi

# The kit «moves forward»: a snapshot whose judge differs from what was installed.
snapshot_kit "$KIT_DIR" "$WORK/kit-next"
for f in scripts/verify-claims.sh templates/full/scripts/verify-claims.sh; do
  printf '\n# kit-next: a fix the installation does not have yet\n' >> "$WORK/kit-next/$f"
done

# install_and_live_in <dir> — activate with the CURRENT kit, then use the repo the
# way a project does: decisions taken, features real, rules curated.
install_and_live_in() {
  new_repo "$1"
  printf '%s\n' '{"name":"x","version":"1.0.0","scripts":{"check":"echo ok","dev":"echo dev"}}' > package.json
  commit_all "base"
  bash "$KIT_DIR/bin/harness-init.sh" --target . --level full >/dev/null 2>&1
  commit_all "harness"
  printf '\n## 2026-09-10 — PROBE-DECISION\n\n**Decision.** Tenants are isolated with RLS.\n' >> DECISIONS.md
  printf '\nPROBE-PROGRESS: last verified state of the real project\n' >> PROGRESS.md
  printf '\n# PROBE-MAKEFILE: a project target\n' >> Makefile
  printf '\nPROBE-AGENTS: what this project actually does\n' >> AGENTS.md
  python3 - <<'PYEOF'
import json
p = "feature_list.json"; d = json.load(open(p))
d["features"][0]["behavior"] = "PROBE-FEATURE: a real backlog item"
json.dump(d, open(p, "w"), indent=2)
p = ".harness/arch-rules.json"; d = json.load(open(p))
d["rules"].append({"id": "PROBE-RULE", "check": "true", "expect": "empty", "what": "w", "why": "y", "fix": "f"})
json.dump(d, open(p, "w"), indent=2)
p = ".harness/context-routes.json"; d = json.load(open(p))
d["routes"].append({"paths": ["PROBE-ROUTE/**"], "read": ["DECISIONS.md"], "why": "curated here"})
json.dump(d, open(p, "w"), indent=2)
PYEOF
  commit_all "the project lives here"
}

survives() {
  # survives <label-prefix>
  local missing=""
  grep -q 'PROBE-DECISION' DECISIONS.md 2>/dev/null               || missing="$missing DECISIONS.md"
  grep -q 'PROBE-PROGRESS' PROGRESS.md 2>/dev/null                || missing="$missing PROGRESS.md"
  grep -q 'PROBE-FEATURE'  feature_list.json 2>/dev/null          || missing="$missing feature_list.json"
  grep -q 'PROBE-RULE'     .harness/arch-rules.json 2>/dev/null   || missing="$missing arch-rules.json"
  grep -q 'PROBE-ROUTE'    .harness/context-routes.json 2>/dev/null || missing="$missing context-routes.json"
  grep -q 'PROBE-MAKEFILE' Makefile 2>/dev/null                   || missing="$missing Makefile"
  grep -q 'PROBE-AGENTS'   AGENTS.md 2>/dev/null                  || missing="$missing AGENTS.md"
  if [[ -z "$missing" ]]; then ok "$1: all seven owned files kept the project's edits"
  else bad "$1: the upgrade destroyed project state in:$missing"; fi
}

run_upgrade() { bash "$WORK/kit-next/$UPGRADE_REL" --target . "$@" 2>&1; }

# ── A. a clean installation ──────────────────────────────────────────────────
install_and_live_in "$WORK/a"
OUT="$(run_upgrade --dry-run)"; RC=$?
expect_zero "A: --dry-run succeeds" "$RC"
if [[ -z "$(git status --porcelain 2>/dev/null)" ]]; then ok "A: --dry-run wrote nothing"
else bad "A: --dry-run modified the repository"; fi

OUT="$(run_upgrade)"; RC=$?
expect_zero "A: the upgrade succeeds" "$RC"
survives "A"
if grep -q 'kit-next: a fix' scripts/verify-claims.sh 2>/dev/null; then ok "A: the judge was replaced with the kit's current one"
else bad "A: the fix never reached the installation"; fi

# ── B. someone hot-fixed the judge locally ───────────────────────────────────
install_and_live_in "$WORK/b"
printf '\n# PROBE-LOCAL-HOTFIX\n' >> scripts/verify-claims.sh
commit_all "local hotfix to the judge"
OUT="$(run_upgrade)"; RC=$?
if grep -rq 'PROBE-LOCAL-HOTFIX' . --exclude-dir=.git 2>/dev/null; then ok "B: the local edit is still recoverable from the worktree"
else bad "B: a locally edited managed file was destroyed without a trace"; fi
case "$OUT" in
  *verify-claims.sh*) ok "B: and the upgrade named the file" ;;
  *)                  bad "B: the upgrade said nothing about the drifted file (exit $RC)" ;;
esac
survives "B"

# ── C. an installation that predates the lock ────────────────────────────────
install_and_live_in "$WORK/c"
rm -f .harness/kit-lock.json
echo "2.2.5" > .harness/kit-version
commit_all "simulate a legacy installation"
OUT="$(run_upgrade)"; RC=$?
expect_zero "C: a legacy installation can be upgraded" "$RC"
survives "C"
if [[ -f .harness/kit-lock.json ]]; then ok "C: and it has a lock afterwards"
else bad "C: still no lock after the upgrade — the next one is blind again"; fi

# ── D. the advice that caused this is gone ───────────────────────────────────
if grep -q -- '--force' "$KIT_DIR/bin/harness-status.sh"; then
  bad "D: harness-status still recommends --force as the way to upgrade"
else
  ok "D: harness-status no longer recommends --force"
fi

finish "F21"
