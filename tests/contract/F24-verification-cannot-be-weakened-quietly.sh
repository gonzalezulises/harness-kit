#!/usr/bin/env bash
# F24 — weakening what verifies the code is a visible, deliberate act.
#
# verify-claims.sh already refuses a `passing` feature whose layer COMMAND changed
# (WEAKENED_VERIFICATION). The protection stops at the string. If the layer is
# `npm test`, then deleting the test, marking it `.skip`, pointing the `test`
# script at `true`, or dropping an architecture rule all leave the string intact —
# and `make check` runs from the pull request's head, so CI certifies whatever is
# left. The cheapest way for an agent to turn a red build green is one level below
# where the harness looks.
#
# Path routes are the wrong tool: a route on tests/** fires on every honest change
# and trains people to paste the citation (DECISIONS 2026-09-03 says so). This gate
# looks at the DIFF for weakening only, and lets it through when the same change
# appends an entry to DECISIONS.md — the ledger is where a lowered bar belongs.
#
# Proposed contract: `scripts/verify-no-weakening.sh`, diffing from the merge-base
# with the default branch like verify-context-routes.sh. 0 PASS · 5 POLICY.
#
# Usage: bash tests/contract/F24-verification-cannot-be-weakened-quietly.sh

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_DIR="$(cd "$HERE/../.." && pwd)"
# shellcheck source=tests/contract/lib.sh
. "$HERE/lib.sh"

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
echo "${BOLD}F24 — verification cannot be weakened quietly${RESET}"

GATE_REL="scripts/verify-no-weakening.sh"
if [[ ! -f "$KIT_DIR/templates/full/$GATE_REL" ]]; then
  bad "templates/full/$GATE_REL does not exist — nothing looks below the layer command"
  finish "F24"
fi

new_repo "$WORK/repo"
cat > package.json <<'JSON'
{ "name": "x", "version": "1.0.0",
  "scripts": { "check": "node --test", "test": "node --test", "dev": "echo dev" } }
JSON
mkdir -p tests src
printf '%s\n' "const test = require('node:test');" "test('adds', () => {});" > tests/a.test.js
printf '%s\n' "const test = require('node:test');" "test('subtracts', () => {});" > tests/b.test.js
echo 'module.exports = 1' > src/index.js
commit_all "base"
bash "$KIT_DIR/bin/harness-init.sh" --target . --level full >/dev/null 2>&1
commit_all "harness"

# on_branch <name> — a fresh branch off main for one case.
on_branch() { git checkout -q main && git checkout -q -b "$1"; }
gate()      { bash "$GATE_REL" >/dev/null 2>&1; }

# ── controls: honest work is never nagged ────────────────────────────────────
on_branch c1; printf '%s\n' "const test = require('node:test');" "test('multiplies', () => {});" > tests/c.test.js
commit_all "add a test"; gate; expect_zero "control: adding a test passes" $?

on_branch c2; echo 'module.exports = 2' > src/index.js
commit_all "change production code"; gate; expect_zero "control: changing production code passes" $?

# ── the quiet ways to turn red into green ────────────────────────────────────
on_branch w1; git rm -q tests/b.test.js
commit_all "tidy"; gate; expect_nonzero "deleting a test file blocks" $?

on_branch w2; printf '%s\n' "const test = require('node:test');" "test.skip('adds', () => {});" > tests/a.test.js
commit_all "stabilise"; gate; expect_nonzero "marking a test .skip blocks" $?

on_branch w3; python3 - <<'PYEOF'
import json
d = json.load(open("package.json")); d["scripts"]["test"] = "true"
json.dump(d, open("package.json", "w"), indent=2)
PYEOF
commit_all "speed up ci"; gate; expect_nonzero "repointing the test script blocks" $?

on_branch w4; python3 - <<'PYEOF'
import re
s = open("Makefile", encoding="utf-8").read()
s = re.sub(r"(?m)^(check:.*\n)\t.*$", r"\1\t@true", s, count=1)
open("Makefile", "w", encoding="utf-8").write(s)
PYEOF
commit_all "simplify"; gate; expect_nonzero "hollowing out \`make check\` blocks" $?

on_branch w5; python3 - <<'PYEOF'
import json
p = ".harness/arch-rules.json"; d = json.load(open(p)); d["rules"] = d["rules"][1:]
json.dump(d, open(p, "w"), indent=2)
PYEOF
commit_all "cleanup"; gate; expect_nonzero "removing an architecture rule blocks" $?

on_branch w6; printf '%s\n' '// eslint-disable-next-line' '// @ts-ignore' 'module.exports = 1' > src/index.js
commit_all "fix lint"; gate; expect_nonzero "adding a lint/type suppression blocks" $?

# ── the deliberate way through ───────────────────────────────────────────────
on_branch d1; git rm -q tests/b.test.js
printf '\n## 2026-09-19 — Drop the subtraction test\n\n**Decision.** The module was removed; its test goes with it.\n' >> DECISIONS.md
commit_all "remove subtraction, recorded in the ledger"; gate
expect_zero "the same deletion passes when the change appends a decision" $?

finish "F24"
