#!/usr/bin/env bash
# run-tests.sh — end-to-end verification of the kit.
#
# Scaffolds throwaway repos in a temp dir, runs the real scripts against them, and
# asserts on observable behaviour. No mocks: if this passes, the kit works.
#
# Usage: tests/run-tests.sh

set -uo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if [[ ! -t 1 ]] || [[ -n "${NO_COLOR:-}" ]]; then
  RED=""; GREEN=""; BOLD=""; RESET=""
else
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
fi

PASS=0; FAIL=0
ok()   { echo "  ${GREEN}ok${RESET}   $1"; PASS=$((PASS+1)); }
bad()  { echo "  ${RED}FAIL${RESET} $1"; FAIL=$((FAIL+1)); }

assert_eq() {
  # assert_eq <label> <expected> <actual>
  if [[ "$2" == "$3" ]]; then ok "$1"; else bad "$1 (expected '$2', got '$3')"; fi
}
assert_contains() {
  # assert_contains <label> <haystack> <needle>
  case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (missing '$3')" ;; esac
}
assert_not_contains() {
  # assert_not_contains <label> <haystack> <needle>
  case "$2" in *"$3"*) bad "$1 (unexpected '$3')" ;; *) ok "$1" ;; esac
}
assert_file() {
  [[ -f "$2" ]] && ok "$1" || bad "$1 (no such file: $2)"
}

make_fixture() {
  # make_fixture <dir>  — a minimal node project with a green check
  local d="$1"
  mkdir -p "$d" && cd "$d" || exit 1
  git init -q
  cat > package.json <<'EOF'
{ "name":"fixture","version":"1.0.0",
  "scripts":{"check":"echo static-ok","test":"echo tests-ok","dev":"echo dev"} }
EOF
  echo '{}' > package-lock.json
  echo "20" > .nvmrc
  git add -A && git -c user.email=t@t -c user.name=t commit -qm "base" >/dev/null
  cd - >/dev/null || exit 1
}

echo "${BOLD}harness-kit test suite${RESET}"

H01_FOCAL_LOG="$WORK/h01-focal.log"
if python3 "$KIT_DIR/tests/h01-hardening-regressions.py" >"$H01_FOCAL_LOG" 2>&1; then
  ok "H01 verifier hardening regressions"
else
  bad "H01 verifier hardening regressions"
  sed 's/^/    /' "$H01_FOCAL_LOG"
fi

# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo "${BOLD}1. Syntax${RESET}"
for f in "$KIT_DIR"/bin/*.sh "$KIT_DIR"/templates/full/scripts/*.sh "$KIT_DIR"/tests/*.sh; do
  if bash -n "$f" 2>/dev/null; then ok "syntax $(basename "$f")"
  else bad "syntax $(basename "$f")"; fi
done

# The kit dogfoods its own scripts: scripts/X and templates/full/scripts/X are the
# same file in two places. The suite runs the template copy, so editing only the
# root one produces failures with no visible cause. Catch the drift instead.
# The protected judge runs separately; compare the actual shipped workspace bytes.
root_content() { cat "$KIT_DIR/scripts/$1"; }

for f in "$KIT_DIR"/templates/full/scripts/*.sh; do
  base="$(basename "$f")"
  root="$KIT_DIR/scripts/$base"
  [[ -f "$root" ]] || continue
  # The kit's own copy is the rendered one, so placeholders are substituted with
  # the values the kit itself uses before comparing.
  if diff -q <(sed 's/{{VERIFY_CMD}}/make check/g; s/{{E2E_CMD}}/make e2e/g' "$f") \
             <(root_content "$base") >/dev/null 2>&1; then
    ok "in sync: scripts/$base"
  else
    bad "DRIFT: scripts/$base differs from templates/full/scripts/$base — copy it across"
  fi
done

# JSON templates must parse
for j in "$KIT_DIR"/templates/minimal/feature_list.json "$KIT_DIR"/templates/full/.harness/arch-rules.json; do
  if python3 -c "import json,sys;json.load(open(sys.argv[1]))" "$j" 2>/dev/null; then
    ok "valid json $(basename "$j")"
  else bad "valid json $(basename "$j")"; fi
done

# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo "${BOLD}2. Audit on a bare repo${RESET}"
BARE="$WORK/bare"; make_fixture "$BARE"
BARE_JSON="$(bash "$KIT_DIR/bin/harness-audit.sh" "$BARE" --json 2>/dev/null)"
BARE_CRIT="$(echo "$BARE_JSON" | python3 -c "import json,sys;print(json.load(sys.stdin)['score']['critical_passed'])")"
BARE_TOTAL="$(echo "$BARE_JSON" | python3 -c "import json,sys;print(json.load(sys.stdin)['score']['total'])")"
[[ "$BARE_CRIT" -lt 7 ]] && ok "bare repo fails critical checks ($BARE_CRIT/7)" \
                         || bad "bare repo should fail critical checks, got $BARE_CRIT/7"

bash "$KIT_DIR/bin/harness-audit.sh" "$BARE" >/dev/null 2>&1
assert_eq "audit exits 1 when critical checks fail" "1" "$?"

# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo "${BOLD}3. Stable denominator${RESET}"
EMPTY="$WORK/empty"; mkdir -p "$EMPTY"
EMPTY_TOTAL="$(bash "$KIT_DIR/bin/harness-audit.sh" "$EMPTY" --json 2>/dev/null \
  | python3 -c "import json,sys;print(json.load(sys.stdin)['score']['total'])")"
assert_eq "same total for empty and bare repo (comparable scores)" "$BARE_TOTAL" "$EMPTY_TOTAL"

# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo "${BOLD}4. init --dry-run writes nothing${RESET}"
DRY="$WORK/dry"; make_fixture "$DRY"
bash "$KIT_DIR/bin/harness-init.sh" --target "$DRY" --level full --dry-run >/dev/null 2>&1
[[ ! -f "$DRY/AGENTS.md" ]] && ok "dry run left no AGENTS.md" || bad "dry run wrote files"

# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo "${BOLD}5. init --level minimal${RESET}"
MIN="$WORK/min"; make_fixture "$MIN"
bash "$KIT_DIR/bin/harness-init.sh" --target "$MIN" --level minimal >/dev/null 2>&1
for f in AGENTS.md CLAUDE.md init.sh PROGRESS.md feature_list.json \
         clean-state-checklist.md DECISIONS.md docs/decisions/README.md; do
  assert_file "minimal wrote $f" "$MIN/$f"
done
[[ -x "$MIN/init.sh" ]] && ok "init.sh is executable" || bad "init.sh not executable"
grep -q '{{' "$MIN/AGENTS.md" && bad "AGENTS.md still has placeholders" \
                              || ok "all placeholders substituted in AGENTS.md"
grep -q 'npm run check' "$MIN/AGENTS.md" && ok "detected the real verify command" \
                                         || bad "verify command not detected"

MIN_CRIT="$(bash "$KIT_DIR/bin/harness-audit.sh" "$MIN" --json 2>/dev/null \
  | python3 -c "import json,sys;print(json.load(sys.stdin)['score']['critical_passed'])")"
assert_eq "minimal harness passes all 7 critical checks" "7" "$MIN_CRIT"

# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo "${BOLD}6. init --level full${RESET}"
FULL="$WORK/full"; make_fixture "$FULL"
bash "$KIT_DIR/bin/harness-init.sh" --target "$FULL" --level full >/dev/null 2>&1
for f in Makefile scripts/verify-feature.sh scripts/check-arch.sh \
         scripts/clean-state-check.sh scripts/session-trace.sh \
         .harness/arch-rules.json templates/sprint-contract.md \
         templates/evaluator-rubric.md docs/quality-document.md; do
  assert_file "full wrote $f" "$FULL/$f"
done

FULL_SCORE="$(bash "$KIT_DIR/bin/harness-audit.sh" "$FULL" --json 2>/dev/null \
  | python3 -c "import json,sys;d=json.load(sys.stdin);print(d['score']['passed'])")"
[[ "$FULL_SCORE" -ge 70 ]] && ok "full harness scores >= 70/84 (got $FULL_SCORE)" \
                           || bad "full harness scored only $FULL_SCORE/84"

grep -q 'traces.jsonl' "$FULL/.gitignore" && ok "gitignored the trace artifact" \
                                          || bad "traces.jsonl not gitignored"

# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo "${BOLD}7. init never clobbers without --force${RESET}"
echo "PRECIOUS" > "$FULL/AGENTS.md"
bash "$KIT_DIR/bin/harness-init.sh" --target "$FULL" --level full >/dev/null 2>&1
assert_eq "existing AGENTS.md preserved" "PRECIOUS" "$(cat "$FULL/AGENTS.md")"
bash "$KIT_DIR/bin/harness-init.sh" --target "$FULL" --level full --force >/dev/null 2>&1
[[ "$(cat "$FULL/AGENTS.md")" != "PRECIOUS" ]] && ok "--force does overwrite" \
                                               || bad "--force failed to overwrite"

# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo "${BOLD}8. verify-feature gate${RESET}"
cd "$FULL" || exit 1

# 8a — happy path promotes to passing with evidence
python3 - <<'PYEOF'
import json
d = json.load(open("feature_list.json"))
d["features"][0]["state"] = "active"
d["features"][0]["layers"] = [{"label":"static","cmd":"true","repair":"n/a"}]
json.dump(d, open("feature_list.json","w"), indent=2)
PYEOF
bash scripts/verify-feature.sh F01 >/dev/null 2>&1
STATE="$(python3 -c "import json;print(json.load(open('feature_list.json'))['features'][0]['state'])")"
assert_eq "passing layers promote the feature" "passing" "$STATE"
EV="$(python3 -c "import json;print(len(json.load(open('feature_list.json'))['features'][0]['evidence']))")"
[[ "$EV" -gt 0 ]] && ok "evidence recorded on promotion" || bad "no evidence recorded"

# 8b — a failing layer must NOT promote, and must print repair guidance
python3 - <<'PYEOF'
import json
d = json.load(open("feature_list.json"))
f = d["features"][1]
f["state"] = "active"
f["layers"] = [{"label":"static","cmd":"false","repair":"FIX-ME-MARKER"}]
json.dump(d, open("feature_list.json","w"), indent=2)
PYEOF
OUT="$(bash scripts/verify-feature.sh F02 2>&1)"
RC=$?
assert_eq "failing layer exits non-zero" "1" "$RC"
assert_contains "failure prints repair guidance" "$OUT" "FIX-ME-MARKER"
assert_contains "failure names the layer" "$OUT" "FAILED at layer"
STATE2="$(python3 -c "import json;print(json.load(open('feature_list.json'))['features'][1]['state'])")"
assert_eq "budgeted failure is blocked pending recovery authority" "blocked" "$STATE2"

# 8c — a layer command that calls `exit` must not kill the script silently
python3 - <<'PYEOF'
import json
d = json.load(open("feature_list.json"))
f = d["features"][1]
f["state"] = "active"
f.pop("ledger", None)
f["layers"] = [{"label":"static","cmd":"exit 3","repair":"EXIT-MARKER"}]
json.dump(d, open("feature_list.json","w"), indent=2)
PYEOF
OUT3="$(bash scripts/verify-feature.sh F02 2>&1)"
assert_contains "layer calling exit still prints repair" "$OUT3" "EXIT-MARKER"

# 8d — unknown feature id
bash scripts/verify-feature.sh NOPE >/dev/null 2>&1
assert_eq "unknown feature id exits 66" "66" "$?"

# 8e — multiline commands retain their record boundary and execute as one layer
python3 - <<'PYEOF'
import json
d = json.load(open("feature_list.json"))
d["features"] = [f for f in d["features"] if f.get("id") != "FML"]
for feature in d["features"]:
    if feature.get("state") == "active":
        feature["state"] = "not_started"
d["features"].append({"id": "FML", "state": "active", "evidence": [], "layers": [{
    "label": "multiline",
    "cmd": "printf 'first\\n' > multiline-executed\nprintf 'second\\n' >> multiline-executed",
    "repair": "printf repair > repair-must-not-run",
}]})
json.dump(d, open("feature_list.json", "w"), indent=2)
PYEOF
bash scripts/verify-feature.sh FML >/dev/null 2>&1
assert_eq "multiline layer command passes" "0" "$?"
assert_eq "multiline layer keeps both commands" $'first\nsecond' "$(cat multiline-executed)"
[[ ! -e repair-must-not-run ]] && ok "repair prose never enters the execution channel" \
                              || bad "repair prose executed as a layer"
rm -f multiline-executed repair-must-not-run

# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo "${BOLD}9. clean-state-check${RESET}"
python3 - <<'PYEOF'
import json
d = json.load(open("feature_list.json"))
d["features"][1]["state"] = "not_started"
json.dump(d, open("feature_list.json","w"), indent=2)
PYEOF
sed -i.bak 's/{{VERIFY_CMD}}/true/' scripts/clean-state-check.sh 2>/dev/null || true
rm -f scripts/clean-state-check.sh.bak

bash scripts/clean-state-check.sh . >/dev/null 2>&1
CLEAN_RC=$?
assert_eq "clean tree passes the clock-out gate" "0" "$CLEAN_RC"

touch stray.orig
bash scripts/clean-state-check.sh . >/dev/null 2>&1
assert_eq "stray .orig file fails the gate" "1" "$?"
rm -f stray.orig

# OS noise alone must NOT fail the gate — a gate that cries wolf gets ignored
touch .DS_Store
bash scripts/clean-state-check.sh . >/dev/null 2>&1
assert_eq ".DS_Store alone does not fail the gate" "0" "$?"
OUT_NOISE="$(bash scripts/clean-state-check.sh . 2>&1)"
assert_contains ".DS_Store is reported as a note" "$OUT_NOISE" "OS noise present"
rm -f .DS_Store

# Regression: a verify command that cd's must not move the cwd for later checks
cp scripts/clean-state-check.sh $WORK/csc-backup.sh
mkdir -p sub && echo '{}' > sub/marker.json
sed -i.bak 's|^VERIFY_CMD=.*|VERIFY_CMD="cd sub \&\& true"|' scripts/clean-state-check.sh
rm -f scripts/clean-state-check.sh.bak
OUT_CD="$(bash scripts/clean-state-check.sh . 2>&1)"
case "$OUT_CD" in
  *"PROGRESS.md missing"*) bad "cd in verify command breaks later checks (cwd leaked)" ;;
  *) ok "verify command that cd's does not leak the working directory" ;;
esac
cp $WORK/csc-backup.sh scripts/clean-state-check.sh
rm -rf sub $WORK/csc-backup.sh

# a feature marked passing with no evidence must fail the honesty check
python3 - <<'PYEOF'
import json
d = json.load(open("feature_list.json"))
d["features"][1]["state"] = "passing"
d["features"][1]["evidence"] = []
json.dump(d, open("feature_list.json","w"), indent=2)
PYEOF
OUT4="$(bash scripts/clean-state-check.sh . 2>&1)"
assert_contains "passing-without-evidence is caught" "$OUT4" "no evidence recorded"

# two active features must trip WIP=1
python3 - <<'PYEOF'
import json
d = json.load(open("feature_list.json"))
d["features"][0]["state"] = "active"
d["features"][1]["state"] = "active"
d["features"][1]["evidence"] = []
json.dump(d, open("feature_list.json","w"), indent=2)
PYEOF
OUT5="$(bash scripts/clean-state-check.sh . 2>&1)"
assert_contains "WIP=1 violation is caught" "$OUT5" "WIP=1 violated"

# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo "${BOLD}10. check-arch${RESET}"
bash scripts/check-arch.sh . >/dev/null 2>&1
assert_eq "clean repo passes arch rules" "0" "$?"

# A realistic hardcoded credential, as it would actually appear in source.
# Composed at runtime so this test file itself never matches the scanner
# pattern it exercises (the kit runs its own gates repo-wide).
mkdir -p src
FAKE_KEY="sk_live_9fJ2xQ7m""Np4RtY8wZ1aB3cD5"
printf 'export const cfg = { api_key: "%s" };\n' "$FAKE_KEY" > src/leak.ts
git add -A >/dev/null 2>&1
OUT6="$(bash scripts/check-arch.sh . 2>&1)"
ARCH_RC=$?
assert_eq "committed secret trips a rule" "1" "$ARCH_RC"
assert_contains "violation reports WHAT" "$OUT6" "WHAT:"

# Regression: healthy code the scanner used to flag must pass. A $VAR
# reference is not a credential, and neither is a function call (no digits).
rm src/leak.ts
printf 'curl -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" "$url"\n' > src/env-ref.sh
printf 'const secret = requireWebhookSecret()\n' > src/fn-call.ts
printf 'const password = "test-password-integration-1";\n' > src/fixture.ts
git add -A >/dev/null 2>&1
bash scripts/check-arch.sh . >/dev/null 2>&1
assert_eq "env-var reference and function call are not flagged" "0" "$?"
rm src/env-ref.sh src/fn-call.ts src/fixture.ts
git add -A >/dev/null 2>&1
assert_contains "violation reports WHY"  "$OUT6" "WHY:"
assert_contains "violation reports FIX"  "$OUT6" "FIX:"
assert_contains "violation names the offending file" "$OUT6" "src/leak.ts"
git rm -q --cached src/leak.ts >/dev/null 2>&1; rm -rf src

# conflict markers must also trip
mkdir -p src && printf '<<<<<<< HEAD\nlet a = 1;\n=======\nlet a = 2;\n>>>>>>> other\n' > src/conflict.ts
git add -A >/dev/null 2>&1
OUT7="$(bash scripts/check-arch.sh . 2>&1)"
assert_contains "conflict markers trip a rule" "$OUT7" "no-merge-conflict-markers"
git rm -q --cached src/conflict.ts >/dev/null 2>&1; rm -rf src

# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo "${BOLD}11. session-trace${RESET}"
bash scripts/session-trace.sh start >/dev/null 2>&1
bash scripts/session-trace.sh event "verify" "F01 passed" >/dev/null 2>&1
bash scripts/session-trace.sh end >/dev/null 2>&1
assert_file "trace file written" "$FULL/.harness/traces/traces.jsonl"
LINES="$(wc -l < .harness/traces/traces.jsonl | tr -d ' ')"
assert_eq "three events recorded" "3" "$LINES"
if python3 -c "
import json,sys
for line in open('.harness/traces/traces.jsonl'):
    json.loads(line)
" 2>/dev/null; then ok "every trace line is valid JSON"; else bad "trace lines are not valid JSON"; fi

# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo "${BOLD}12. NO_COLOR and JSON hygiene${RESET}"
RAW="$(NO_COLOR=1 bash "$KIT_DIR/bin/harness-audit.sh" "$FULL" 2>&1)"
case "$RAW" in *$'\033'*) bad "NO_COLOR still emitted ANSI codes" ;; *) ok "NO_COLOR suppresses ANSI codes" ;; esac

if bash "$KIT_DIR/bin/harness-audit.sh" "$FULL" --json 2>/dev/null | python3 -c "import json,sys;json.load(sys.stdin)" 2>/dev/null; then
  ok "--json emits parseable JSON"
else
  bad "--json output is not parseable"
fi

# ═════════════════════════════════════════════════════════════════════════════
echo ""
# 12z — the auditor's own counters must survive a zero match.
# `grep -c` prints "0" AND exits 1 when nothing matches, so the old
# `$(grep -c … || echo 0)` produced a two-line "0\n0": every arithmetic
# comparison using it blew up, the check failed for a reason that was not its
# own, and its repair text told the user to fix something already correct.
# A repo with complete budgets and no budget_defaults could never pass.
AUD="$WORK/audit-counters"; make_fixture "$AUD"
bash "$KIT_DIR/bin/harness-activate.sh" --target "$AUD" --yes >/dev/null 2>&1
python3 - "$AUD/feature_list.json" <<'PYEOF'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
if isinstance(d, dict):
    d.pop("budget_defaults", None)          # the shape that used to break
fs = d["features"] if isinstance(d, dict) and "features" in d else d
for f in fs:
    f["budgets"] = {"review_rounds_max": 2, "repeated_blocker_max": 3,
                    "stop_condition": "Stop and escalate to a human."}
json.dump(d, open(p, "w"), indent=2)
PYEOF
[[ "$(grep -c '"budget_defaults"' "$AUD/feature_list.json")" == "0" ]]   && ok "fixture has no budget_defaults (the case that used to break)"   || bad "fixture unexpectedly carries budget_defaults"
AUD_JSON="$(bash "$KIT_DIR/bin/harness-audit.sh" "$AUD" --json 2>/dev/null)"
STOPCOND="$(printf '%s' "$AUD_JSON" | python3 -c "
import json,sys
for c in json.load(sys.stdin)['checks']:
    if c.get('id') == 'enf.stopcond': print(c.get('status') or c.get('result') or c)
")"
case "$STOPCOND" in
  *pass*|*PASS*) ok "complete budgets pass enf.stopcond without budget_defaults" ;;
  *) bad "enf.stopcond reported '$STOPCOND' for budgets that are complete" ;;
esac

echo "${BOLD}13. budgets — the anti-loop gate${RESET}"
cd "$FULL" || exit 1

# Install a feature FB1 with the given budgets and a single layer command.
# Usage: fb1 <cmd> <review_rounds_max> <repeated_blocker_max> <stop_condition>
fb1() {
  CMD="$1" RMAX="$2" BMAX="$3" STOP="$4" python3 - <<'PYEOF'
import json, os
d = json.load(open("feature_list.json"))
d["features"] = [f for f in d["features"] if f.get("id") != "FB1"]
for feature in d["features"]:
    if feature.get("state") == "active":
        feature["state"] = "not_started"
budgets = {
    "review_rounds_max": int(os.environ["RMAX"]),
    "repeated_blocker_max": int(os.environ["BMAX"]),
}
if os.environ["STOP"]:
    budgets["stop_condition"] = os.environ["STOP"]
d["features"].append({
    "id": "FB1", "priority": 99, "area": "budget-test",
    "behavior": "budget fixture", "state": "active",
    "verification": ["n/a"],
    "budgets": budgets,
    "layers": [{"label": "static", "cmd": os.environ["CMD"], "repair": "REPAIR-MARKER"}],
    "evidence": [],
})
json.dump(d, open("feature_list.json", "w"), indent=2)
PYEOF
}
fb1_rounds() { python3 -c "
import json
for f in json.load(open('feature_list.json'))['features']:
    if f.get('id')=='FB1': print(f.get('ledger',{}).get('review_rounds',0))
"; }

# 13a — budgets without a stop condition are refused outright
fb1 "false" 2 3 ""
bash scripts/verify-feature.sh FB1 >/dev/null 2>&1
assert_eq "missing stop_condition exits 67" "67" "$?"

# 13b — the first failure consumes exactly one review round
fb1 "false" 2 9 "escalate to a human after two failed rounds"
OUTB="$(bash scripts/verify-feature.sh FB1 2>&1)"; RCB=$?
assert_eq "first failure still exits 1" "1" "$RCB"
assert_eq "first failure consumes one round" "1" "$(fb1_rounds)"
assert_contains "first failure still prints repair" "$OUTB" "REPAIR-MARKER"
assert_contains "first failure reports budget spent" "$OUTB" "Review rounds spent: 1/2"

# 13c — a recorded failure requires verified recovery authority before retry
OUTC="$(bash scripts/verify-feature.sh FB1 2>&1)"; RCC=$?
assert_eq "ungranted retry exits policy code 5" "5" "$RCC"
assert_contains "recovery authority requirement is named" "$OUTC" "RECOVERY_AUTHORITY_REQUIRED"
assert_not_contains "remaining budget is not relabelled exhausted" "$OUTC" "BUDGET_EXHAUSTED"
STC="$(python3 -c "
import json
for f in json.load(open('feature_list.json'))['features']:
    if f.get('id')=='FB1': print(f['state'])
")"
assert_eq "failed feature remains blocked" "blocked" "$STC"

# Editing blocked back to active and raising the maximum are not authorization
# grants. The verifier restores the conservative stop state without effects.
python3 - <<'PYEOF'
import json
d = json.load(open("feature_list.json"))
for f in d["features"]:
    if f.get("id") == "FB1":
        f["state"] = "active"
        f["budgets"]["review_rounds_max"] = 99
        f["layers"] = [{"label": "static", "cmd": "printf ran > reopened-executed", "repair": "n/a"}]
json.dump(d, open("feature_list.json", "w"), indent=2)
PYEOF
bash scripts/verify-feature.sh FB1 >/dev/null 2>&1; RC_REOPEN=$?
assert_eq "state edit and raised maximum do not grant recovery" "5" "$RC_REOPEN"
[[ ! -e reopened-executed ]] && ok "ungranted recovery rejects before layer effects" \
                              || bad "failed feature executed after local policy edits"
ST_REOPEN="$(python3 -c "
import json
print(next(f['state'] for f in json.load(open('feature_list.json'))['features'] if f.get('id')=='FB1'))
")"
assert_eq "failed ledger restores blocked state" "blocked" "$ST_REOPEN"
assert_eq "rejected recovery preserves spent rounds" "1" "$(fb1_rounds)"

# 13d — a blocker ceiling reached by the current authorized attempt still stops
fb1 "false" 99 1 "stop and ask for help"
OUTD="$(bash scripts/verify-feature.sh FB1 2>&1)"; RCD=$?
assert_eq "repeated blocker exits 4" "4" "$RCD"
assert_contains "repeated blocker is named" "$OUTD" "REPEATED_BLOCKER"

# 13e — changing a failed command locally cannot manufacture a green retry
fb1 "false" 9 9 "stop"
bash scripts/verify-feature.sh FB1 >/dev/null 2>&1
assert_eq "ledger accumulated before attempted recovery" "1" "$(fb1_rounds)"
python3 - <<'PYEOF'
import json
d = json.load(open("feature_list.json"))
for f in d["features"]:
    if f.get("id") == "FB1":
        f["state"] = "active"
        f["layers"] = [{"label": "static", "cmd": "touch ungranted-green", "repair": "n/a"}]
json.dump(d, open("feature_list.json", "w"), indent=2)
PYEOF
OUTE="$(bash scripts/verify-feature.sh FB1 2>&1)"; RCE=$?
assert_eq "edited command still needs recovery authority" "5" "$RCE"
assert_contains "edited command reports recovery requirement" "$OUTE" "RECOVERY_AUTHORITY_REQUIRED"
[[ ! -e ungranted-green ]] && ok "edited command does not execute without recovery authority" \
                           || bad "edited command executed without recovery authority"
assert_eq "rejected recovery preserves prior review rounds" "1" "$(fb1_rounds)"

# 13f — features without budgets keep working exactly as before
python3 - <<'PYEOF'
import json
d = json.load(open("feature_list.json"))
for f in d["features"]:
    if f.get("id") == "FB1":
        f.pop("budgets", None); f.pop("ledger", None)
        f["state"] = "active"
        f["layers"] = [{"label": "static", "cmd": "false", "repair": "LEGACY-MARKER"}]
json.dump(d, open("feature_list.json", "w"), indent=2)
PYEOF
OUTF="$(bash scripts/verify-feature.sh FB1 2>&1)"; RCF=$?
assert_eq "no budgets means unchanged exit 1" "1" "$RCF"
assert_contains "no budgets still prints repair" "$OUTF" "LEGACY-MARKER"

# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo "${BOLD}14. verify-claims — re-check what the repo claims is passing${RESET}"
CLAIMS="$WORK/claims"; make_fixture "$CLAIMS"
bash "$KIT_DIR/bin/harness-init.sh" --target "$CLAIMS" --level full >/dev/null 2>&1
cd "$CLAIMS" || exit 1

# Replace the feature list with exactly the claims under test.
# Usage: claims <json-array-of-features>
claims() {
  FEATS="$1" python3 - <<'PYEOF'
import json, os
d = json.load(open("feature_list.json"))
d["features"] = json.loads(os.environ["FEATS"])
json.dump(d, open("feature_list.json", "w"), indent=2)
PYEOF
}
CLAIM_OK='[{"id":"C1","state":"passing","behavior":"b","evidence":["ran"],"layers":[{"label":"unit","cmd":"true","repair":"r"}]}]'
CLAIM_LIE='[{"id":"C1","state":"passing","behavior":"b","evidence":["ran"],"layers":[{"label":"unit","cmd":"false","repair":"r"}]}]'

# 14a — an honest claim survives re-verification
claims "$CLAIM_OK"
OUT14="$(bash scripts/verify-claims.sh 2>&1)"; RC14=$?
assert_eq "honest passing claim exits 0" "0" "$RC14"
assert_contains "reports how many claims were re-verified" "$OUT14" "1"

# 14b — a hand-written passing state does NOT survive
claims "$CLAIM_LIE"
OUTL="$(bash scripts/verify-claims.sh 2>&1)"; RCL=$?
assert_eq "false claim exits 1" "1" "$RCL"
assert_contains "false claim is named FALSE_CLAIM" "$OUTL" "FALSE_CLAIM"
assert_contains "false claim names the feature" "$OUTL" "C1"

# 14c — passing with no layers cannot be verified, so it cannot pass
claims '[{"id":"C1","state":"passing","behavior":"b","evidence":["ran"],"layers":[]}]'
bash scripts/verify-claims.sh >/dev/null 2>&1
assert_eq "unverifiable claim exits 2" "2" "$?"

# 14d — passing with no evidence is fail-closed too
claims '[{"id":"C1","state":"passing","behavior":"b","evidence":[],
          "layers":[{"label":"unit","cmd":"true","repair":"r"}]}]'
OUTE="$(bash scripts/verify-claims.sh 2>&1)"; RCE=$?
assert_eq "claim without evidence exits 2" "2" "$RCE"
assert_contains "missing evidence is named" "$OUTE" "NO_EVIDENCE"

# 14e — non-passing features are not re-run and never block
claims '[{"id":"C1","state":"active","behavior":"b","evidence":[],
          "layers":[{"label":"unit","cmd":"false","repair":"r"}]},
         {"id":"C2","state":"blocked","behavior":"b","evidence":[],
          "layers":[{"label":"unit","cmd":"false","repair":"r"}]}]'
bash scripts/verify-claims.sh >/dev/null 2>&1
assert_eq "unclaimed features do not block" "0" "$?"

# 14f — nothing claimed must say so out loud, not pass in silence
claims '[{"id":"C1","state":"not_started","behavior":"b","evidence":[],"layers":[]}]'
OUTN="$(bash scripts/verify-claims.sh 2>&1)"; RCN=$?
assert_eq "no claims still exits 0" "0" "$RCN"
assert_contains "no claims is stated, not silent" "$OUTN" "NO_CLAIMS"

# 14g — the CI workflow that runs this gate ships with the full level
assert_file "required-quality workflow is scaffolded" \
  "$CLAIMS/.github/workflows/required-quality.yml"

# ── 14h-14l — weakening the verification is not a green path ─────────────────
# The script is taken from the protected base, but the commands it runs come from
# the PR. Without this, swapping a real command for `true` passes as "verified".
BASEFL="$WORK/base-feature-list.json"
claim_base() {
  FEATS="$1" python3 - "$BASEFL" <<'PYEOF'
import json, os, sys
json.dump({"features": json.loads(os.environ["FEATS"])}, open(sys.argv[1], "w"), indent=2)
PYEOF
}
REAL='[{"id":"C1","state":"passing","behavior":"b","evidence":["ran"],"layers":[{"label":"unit","cmd":"node tests/checkout.test.js","repair":"r"}]}]'
WEAK='[{"id":"C1","state":"passing","behavior":"b","evidence":["ran"],"layers":[{"label":"unit","cmd":"true","repair":"r"}]}]'

# 14h — the attack: same passing state, weaker command
claim_base "$REAL"
claims "$WEAK"
OUTW="$(CLAIMS_BASE_FILE="$BASEFL" bash scripts/verify-claims.sh 2>&1)"; RCW=$?
assert_eq "weakened verification exits 5" "5" "$RCW"
assert_contains "the weakening is named" "$OUTW" "WEAKENED_VERIFICATION"
assert_contains "it names the feature" "$OUTW" "C1"
assert_contains "it shows the command that was there before" "$OUTW" "checkout.test.js"

# 14i — the legitimate path: change the command AND re-earn the state
claims '[{"id":"C1","state":"active","behavior":"b","evidence":[],"layers":[{"label":"unit","cmd":"true","repair":"r"}]}]'
CLAIMS_BASE_FILE="$BASEFL" bash scripts/verify-claims.sh >/dev/null 2>&1
assert_eq "changing the command while going back to active is allowed" "0" "$?"

# 14j — an unchanged claim still passes with a base present
claim_base "$CLAIM_OK"
claims "$CLAIM_OK"
CLAIMS_BASE_FILE="$BASEFL" bash scripts/verify-claims.sh >/dev/null 2>&1
assert_eq "unchanged layers pass against a base" "0" "$?"

# 14k — a brand new passing feature has nothing to compare against
claim_base '[]'
claims "$CLAIM_OK"
CLAIMS_BASE_FILE="$BASEFL" bash scripts/verify-claims.sh >/dev/null 2>&1
assert_eq "a new feature is not a weakening" "0" "$?"

# 14l — with no base at all, behaviour is unchanged
claims "$CLAIM_LIE"
bash scripts/verify-claims.sh >/dev/null 2>&1
assert_eq "no base still falls back to FALSE_CLAIM" "1" "$?"

# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo "${BOLD}15. workflow integrity — the gate must protect its own definition${RESET}"
WF="$CLAIMS/.github/workflows/required-quality.yml"

# 15a — every external action is pinned to a 40-hex SHA. A tag can be moved.
UNPINNED="$(grep -E '^\s*uses:' "$WF" | grep -vE 'uses:\s*\S+@[0-9a-f]{40}\s*(#.*)?$' || true)"
assert_eq "every action is pinned to a 40-hex SHA" "" "$UNPINNED"

# 15b/c/d — the integrity ruleset payload ships, and it is the strict one.
RS="$CLAIMS/.github/rulesets/required-quality-integrity.json"
assert_file "integrity ruleset payload is scaffolded" "$RS"
if [[ -f "$RS" ]]; then
  RSJSON="$(python3 - "$RS" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
rules = d.get("rules", [])
paths = []
for r in rules:
    if r.get("type") == "file_path_restriction":
        paths = r.get("parameters", {}).get("restricted_file_paths", [])
print("%s|%s|%s|%s" % (d.get("target"), d.get("enforcement"),
                       len(d.get("bypass_actors", [])), ",".join(paths)))
PYEOF
)"
  IFS='|' read -r RS_TARGET RS_ENF RS_BYPASS RS_PATHS <<< "$RSJSON"
  assert_eq "integrity ruleset targets push" "push" "$RS_TARGET"
  assert_eq "integrity ruleset is active" "active" "$RS_ENF"
  assert_eq "integrity ruleset has no bypass actors" "0" "$RS_BYPASS"
  assert_eq "integrity ruleset restricts the workflow path" \
    ".github/workflows/required-quality.yml" "$RS_PATHS"
fi

# 15e — the required-check ruleset payload ships too
assert_file "required-check ruleset payload is scaffolded" \
  "$CLAIMS/.github/rulesets/required-quality-check.json"

# 15f — the installer exists and is syntactically sound
assert_file "harness-protect.sh exists" "$KIT_DIR/bin/harness-protect.sh"
bash -n "$KIT_DIR/bin/harness-protect.sh" 2>/dev/null \
  && ok "harness-protect.sh parses" || bad "harness-protect.sh has a syntax error"

# 15g — the invariant is written where agents read it
grep -q "skipped" "$CLAIMS/AGENTS.md" \
  && ok "AGENTS.md documents the skipped-job bypass" \
  || bad "AGENTS.md does not document the skipped-job bypass"

# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo "${BOLD}16. audit rubric v2 — the score measures what is now enforced${RESET}"

# A fresh scaffold: the claims fixture above deliberately left mangled features
# behind, which would score as missing budgets and hide a real regression.
AUD="$WORK/audit"; make_fixture "$AUD"
bash "$KIT_DIR/bin/harness-init.sh" --target "$AUD" --level full >/dev/null 2>&1
CLAIMS="$AUD"

AJSON="$(bash "$KIT_DIR/bin/harness-audit.sh" "$CLAIMS" --json 2>/dev/null)"

# 16a — the rubric version is machine-readable, so old scores stay interpretable
RUBRIC="$(echo "$AJSON" | python3 -c "
import json,sys
print(json.load(sys.stdin).get('rubric_version','MISSING'))" 2>/dev/null)"
assert_eq "json declares the rubric version" "v2" "$RUBRIC"

# 16b — and visible in the human output
TXT="$(NO_COLOR=1 bash "$KIT_DIR/bin/harness-audit.sh" "$CLAIMS" 2>&1)"
assert_contains "text output names the rubric" "$TXT" "rubric v2"

# 16c — enforcement checks exist and pass on a fully scaffolded repo
ENF="$(echo "$AJSON" | python3 -c "
import json,sys
ch=[c for c in json.load(sys.stdin)['checks'] if c['id'].startswith('enf.')]
print('%d %d' % (len(ch), sum(1 for c in ch if c['result']=='pass')))" 2>/dev/null)"
ENF_N="${ENF% *}"; ENF_PASS="${ENF#* }"
[[ "${ENF_N:-0}" -ge 5 ]] && ok "rubric adds enforcement checks (${ENF_N:-0})" \
                          || bad "expected >= 5 enforcement checks, got ${ENF_N:-0}"
assert_eq "full scaffold passes every enforcement check" "$ENF_N" "$ENF_PASS"

# 16d — remove the claim checker and the rubric must notice
mv "$CLAIMS/scripts/verify-claims.sh" "$CLAIMS/scripts/verify-claims.sh.bak"
GONE="$(bash "$KIT_DIR/bin/harness-audit.sh" "$CLAIMS" --json 2>/dev/null | python3 -c "
import json,sys
print(next(c['result'] for c in json.load(sys.stdin)['checks'] if c['id']=='enf.claims'))" 2>/dev/null)"
assert_eq "missing verify-claims.sh is caught" "fail" "$GONE"
mv "$CLAIMS/scripts/verify-claims.sh.bak" "$CLAIMS/scripts/verify-claims.sh"

# 16e — an unpinned action in the workflow is caught
python3 - "$CLAIMS/.github/workflows/required-quality.yml" <<'PYEOF'
import re, sys
p = sys.argv[1]
s = open(p).read()
open(p + ".bak", "w").write(s)
open(p, "w").write(re.sub(r'uses: (\S+)@[0-9a-f]{40}[^\n]*', r'uses: \1@v4', s))
PYEOF
UNPIN="$(bash "$KIT_DIR/bin/harness-audit.sh" "$CLAIMS" --json 2>/dev/null | python3 -c "
import json,sys
print(next(c['result'] for c in json.load(sys.stdin)['checks'] if c['id']=='enf.pinned'))" 2>/dev/null)"
assert_eq "unpinned action is caught" "fail" "$UNPIN"
mv "$CLAIMS/.github/workflows/required-quality.yml.bak" "$CLAIMS/.github/workflows/required-quality.yml"

# 16f — a feature declaring budgets without a stop condition is caught
python3 - "$CLAIMS/feature_list.json" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
d["features"] = [{"id":"C1","state":"active","behavior":"b","evidence":[],
                  "budgets":{"review_rounds_max":2,"repeated_blocker_max":3},
                  "layers":[{"label":"unit","cmd":"true","repair":"r"}]}]
json.dump(d, open(sys.argv[1], "w"), indent=2)
PYEOF
NOSTOP="$(bash "$KIT_DIR/bin/harness-audit.sh" "$CLAIMS" --json 2>/dev/null | python3 -c "
import json,sys
print(next(c['result'] for c in json.load(sys.stdin)['checks'] if c['id']=='enf.stopcond'))" 2>/dev/null)"
assert_eq "budgets without stop_condition is caught" "fail" "$NOSTOP"

# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo "${BOLD}17. verify-decisions — the record of WHY cannot be rewritten${RESET}"
DEC="$WORK/decisions"; make_fixture "$DEC"
bash "$KIT_DIR/bin/harness-init.sh" --target "$DEC" --level full >/dev/null 2>&1
cd "$DEC" || exit 1

cat > DECISIONS.md <<'EOF'
# Decisions

---

## 2026-08-01 — Postgres over SQLite

**Context.** Two services needed the same data.

**Decision.** Postgres.

**Consequences.** A container in local dev.

---

## 2026-08-02 — No ORM

**Context.** Queries were simple and shaped by reporting needs.

**Decision.** Raw parameterised SQL.

**Consequences.** More typing, no hidden N+1.
EOF
git add -A && git -c user.email=t@t -c user.name=t commit -qm "decisions baseline" >/dev/null
BASE="$(git rev-parse HEAD)"

# 17a — an untouched ledger passes
bash scripts/verify-decisions.sh "$BASE" >/dev/null 2>&1
assert_eq "unchanged ledger passes" "0" "$?"

# 17b — appending a new decision is the normal, allowed path
cat >> DECISIONS.md <<'EOF'

---

## 2026-08-14 — Adopt the required-quality gate

**Context.** A hand-written passing state was never re-checked.

**Decision.** Re-verify claims in CI.

**Consequences.** A PR cannot merge on a claim alone.
EOF
git add -A && git -c user.email=t@t -c user.name=t commit -qm "add decision" >/dev/null
bash scripts/verify-decisions.sh "$BASE" >/dev/null 2>&1
assert_eq "appending a decision is allowed" "0" "$?"

# 17c — editing an earlier decision is the thing this exists to stop
python3 - <<'PYEOF'
s = open("DECISIONS.md").read()
s = s.replace("**Decision.** Raw parameterised SQL.", "**Decision.** Use an ORM after all.")
open("DECISIONS.md", "w").write(s)
PYEOF
git add -A && git -c user.email=t@t -c user.name=t commit -qm "revise decision" >/dev/null
OUTD="$(bash scripts/verify-decisions.sh "$BASE" 2>&1)"; RCD=$?
assert_eq "rewriting an earlier decision exits 1" "1" "$RCD"
assert_contains "the rewrite is named" "$OUTD" "DECISION_REWRITE_FORBIDDEN"
assert_contains "the altered decision is identified" "$OUTD" "No ORM"

# 17d — deleting one is equally forbidden
git checkout -q HEAD~1 -- DECISIONS.md 2>/dev/null
python3 - <<'PYEOF'
s = open("DECISIONS.md").read()
i = s.find("## 2026-08-01 — Postgres over SQLite")
j = s.find("## 2026-08-02")
open("DECISIONS.md", "w").write(s[:i] + s[j:])
PYEOF
git add -A && git -c user.email=t@t -c user.name=t commit -qm "drop decision" >/dev/null
OUTX="$(bash scripts/verify-decisions.sh "$BASE" 2>&1)"; RCX=$?
assert_eq "deleting an earlier decision exits 1" "1" "$RCX"
assert_contains "the deleted decision is identified" "$OUTX" "Postgres"

# 17e-bis — the CI path: base handed over as a file, because a depth-1 checkout
# cannot resolve `git show <base>:FILE`.
git show "$BASE:DECISIONS.md" > "$WORK/base-ledger.md" 2>/dev/null
DECISIONS_BASE_FILE="$WORK/base-ledger.md" bash scripts/verify-decisions.sh >/dev/null 2>&1
assert_eq "DECISIONS_BASE_FILE path catches the rewrite too" "1" "$?"
git checkout -q "$BASE" -- DECISIONS.md
DECISIONS_BASE_FILE="$WORK/base-ledger.md" bash scripts/verify-decisions.sh >/dev/null 2>&1
assert_eq "DECISIONS_BASE_FILE path passes an intact ledger" "0" "$?"
git add -A && git -c user.email=t@t -c user.name=t commit -qm "restore ledger" >/dev/null

# 17e — a repo with no ledger in the base has nothing to protect yet
git checkout -q HEAD~2 -- DECISIONS.md 2>/dev/null || true
rm -f DECISIONS.md
git add -A && git -c user.email=t@t -c user.name=t commit -qm "no ledger" >/dev/null
EMPTYBASE="$(git rev-parse HEAD)"
bash scripts/verify-decisions.sh "$EMPTYBASE" >/dev/null 2>&1
assert_eq "absent ledger in base is not an error" "0" "$?"

# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo "${BOLD}18. activate / status — one command, and an honest answer${RESET}"
ACT="$WORK/activate"; make_fixture "$ACT"

# 18a — status on a bare repo says so instead of guessing
OUTS="$(bash "$KIT_DIR/bin/harness-status.sh" --target "$ACT" 2>&1)"; RCS=$?
assert_contains "status reports NOT_ACTIVATED before anything exists" "$OUTS" "NOT_ACTIVATED"
assert_eq "status exits non-zero when not activated" "1" "$RCS"

# 18b — dry run writes nothing
bash "$KIT_DIR/bin/harness-activate.sh" --target "$ACT" --yes --dry-run >/dev/null 2>&1
[[ ! -f "$ACT/AGENTS.md" ]] && ok "activate --dry-run wrote nothing" \
                            || bad "activate --dry-run created files"

# 18c — one command leaves a governed repo
OUTA="$(bash "$KIT_DIR/bin/harness-activate.sh" --target "$ACT" --yes 2>&1)"; RCA=$?
assert_eq "activate exits 0 on a local repo" "0" "$RCA"
for f in AGENTS.md feature_list.json Makefile scripts/verify-claims.sh \
         scripts/verify-decisions.sh .github/workflows/required-quality.yml; do
  assert_file "activate installed $f" "$ACT/$f"
done

# 18d — it reports the stack it detected, not a generic success
assert_contains "activate names the detected verify command" "$OUTA" "npm run check"

# 18e — with no remote, the honest state is local-only, and it says why
assert_contains "activate reports READY_LOCAL without a remote" "$OUTA" "READY_LOCAL"
OUTS2="$(bash "$KIT_DIR/bin/harness-status.sh" --target "$ACT" 2>&1)"; RCS2=$?
assert_contains "status agrees after activation" "$OUTS2" "READY_LOCAL"
assert_eq "status exits 0 when activated" "0" "$RCS2"

# 18f — running it twice must not damage a configured repo
echo "PRECIOUS PURPOSE" > "$ACT/AGENTS.md"
bash "$KIT_DIR/bin/harness-activate.sh" --target "$ACT" --yes >/dev/null 2>&1
assert_eq "activate is idempotent and never clobbers" "PRECIOUS PURPOSE" "$(cat "$ACT/AGENTS.md")"

# 18g — the Gherkin pack is opt-in, and opting in actually installs it
ACT2="$WORK/activate-gherkin"; make_fixture "$ACT2"
bash "$KIT_DIR/bin/harness-activate.sh" --target "$ACT2" --yes --with gherkin >/dev/null 2>&1
assert_file "--with gherkin installs the runner" "$ACT2/bin/gherkin-check"
assert_file "--with gherkin installs the validator" "$ACT2/bin/gherkin-validate.mjs"
[[ ! -f "$ACT/bin/gherkin-check" ]] && ok "gherkin stays opt-in when not requested" \
                                    || bad "gherkin was installed without being asked for"

# 18h — an unknown pack must fail loudly. It used to be discarded in silence, so
# `--with sentry` installed nothing and said nothing: the user walked away
# believing the pack was in place. A flag that is quietly ignored is worse than
# one that does not exist.
ACT3="$WORK/activate-badpack"; make_fixture "$ACT3"
bash "$KIT_DIR/bin/harness-activate.sh" --target "$ACT3" --yes --with sentry >/dev/null 2>&1
BADPACK=$?
[[ "$BADPACK" -eq 64 ]] && ok "an unknown pack is a usage error (exit 64)" \
                        || bad "--with sentry exited $BADPACK instead of 64 — it was ignored"
BADPACK_MSG="$(bash "$KIT_DIR/bin/harness-activate.sh" --target "$ACT3" --yes --with sentry 2>&1)"
case "$BADPACK_MSG" in
  *"pack desconocido"*sentry*) ok "the unknown pack is named in the error" ;;
  *) bad "the error does not name the pack the user asked for" ;;
esac
[[ ! -f "$ACT3/AGENTS.md" ]] && ok "a rejected --with installs nothing" \
                             || bad "activate scaffolded despite rejecting the flag"

# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo "${BOLD}19. version and fleet drift${RESET}"

# 19a — a single source of truth for the version
assert_file "VERSION file exists" "$KIT_DIR/VERSION"
KITVER="$(tr -d '[:space:]' < "$KIT_DIR/VERSION" 2>/dev/null)"
case "$KITVER" in
  [0-9]*.[0-9]*.[0-9]*) ok "VERSION is semver ($KITVER)" ;;
  *) bad "VERSION is not semver: '$KITVER'" ;;
esac

# 19b — the auditor reports it rather than carrying its own copy
AUDVER="$(bash "$KIT_DIR/bin/harness-audit.sh" "$ACT" --json 2>/dev/null \
  | python3 -c "import json,sys;print(json.load(sys.stdin)['version'])" 2>/dev/null)"
assert_eq "audit reports the VERSION file" "$KITVER" "$AUDVER"

# 19c — the scaffolded repo records which kit built it
assert_file "target records the kit version" "$ACT/.harness/kit-version"
assert_eq "recorded version matches the kit" "$KITVER" \
  "$(tr -d '[:space:]' < "$ACT/.harness/kit-version" 2>/dev/null)"

# 19d — a current repo is not nagged
OUTV="$(bash "$KIT_DIR/bin/harness-status.sh" --target "$ACT" 2>&1)"
assert_contains "status shows the kit version" "$OUTV" "$KITVER"
case "$OUTV" in *"desactualizado"*) bad "an up-to-date repo was reported as stale" ;;
                *) ok "an up-to-date repo is not reported as stale" ;; esac

# 19e — a repo built by an older kit is told, because that is how you answer
# "which of my repositories still lack the security fix?"
echo "1.0.0" > "$ACT/.harness/kit-version"
OUTV2="$(bash "$KIT_DIR/bin/harness-status.sh" --target "$ACT" 2>&1)"
assert_contains "a stale repo is reported" "$OUTV2" "desactualizado"
assert_contains "the stale report names both versions" "$OUTV2" "1.0.0"

cd "$KIT_DIR" || exit 1

# 19f-19i — the version-sync gate. A release that bumps some copies of the
# version and not the others ships silently: the scaffolder stamps one number
# and harness-status.sh compares against another, so downstream repositories are
# told they are current when they are not. The gate is only worth having while
# it rejects that, so the rejection is asserted here rather than assumed.
VSYNC="$WORK/vsync"
rm -rf "$VSYNC"; mkdir -p "$VSYNC/scripts" "$VSYNC/.harness"
cp "$KIT_DIR/scripts/verify-version-sync.sh" "$KIT_DIR/scripts/sync-version.sh" "$VSYNC/scripts/"

vsync_fixture() {  # <VERSION> <kit-version> <manifest> <changelog>
  printf '%s\n' "$1" > "$VSYNC/VERSION"
  printf '%s\n' "$2" > "$VSYNC/.harness/kit-version"
  printf '{\n  ".": "%s"\n}\n' "$3" > "$VSYNC/.release-please-manifest.json"
  printf '# Changelog\n\n## [%s] — 2026-08-30\n' "$4" > "$VSYNC/CHANGELOG.md"
}

vsync_fixture 3.0.0 3.0.0 3.0.0 3.0.0
if ( cd "$VSYNC" && NO_COLOR=1 bash scripts/verify-version-sync.sh >/dev/null 2>&1 ); then
  ok "version-sync passes when every copy agrees"
else
  bad "version-sync rejected a consistent repository"
fi

vsync_fixture 3.0.0 2.1.0 3.0.0 3.0.0
if ( cd "$VSYNC" && NO_COLOR=1 bash scripts/verify-version-sync.sh >/dev/null 2>&1 ); then
  bad "a stale .harness/kit-version was accepted — downstream repos would be told they are current"
else
  ok "version-sync rejects a stale .harness/kit-version"
fi

vsync_fixture 3.0.0 3.0.0 2.1.0 3.0.0
if ( cd "$VSYNC" && NO_COLOR=1 bash scripts/verify-version-sync.sh >/dev/null 2>&1 ); then
  bad "a manifest that disagrees with VERSION was accepted"
else
  ok "version-sync rejects a manifest that disagrees with VERSION"
fi

# sync-version.sh is the documented fix, so it has to actually produce a state
# the gate accepts — otherwise the error message sends the next session in a loop.
vsync_fixture 1.0.0 1.0.0 3.0.0 3.0.0
( cd "$VSYNC" && bash scripts/sync-version.sh >/dev/null 2>&1 )
if ( cd "$VSYNC" && NO_COLOR=1 bash scripts/verify-version-sync.sh >/dev/null 2>&1 ); then
  ok "sync-version.sh repairs the drift its own error message points at"
else
  bad "sync-version.sh did not produce a state the gate accepts"
fi

# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo "${BOLD}20. Declared gates must do real work${RESET}"
# A target that announces what it would do exits 0, and the contract counts a
# verification that never ran. `make e2e` shipped as `echo 'TODO: ...'` and three
# repos inherited a mandatory layer that could not fail.

GATES="$WORK/gates"; make_fixture "$GATES"
bash "$KIT_DIR/bin/harness-init.sh" --target "$GATES" --level full >/dev/null 2>&1
cd "$GATES" || exit 1

# 20a — the fixture has no e2e script, so init had to choose a default
if make e2e >/dev/null 2>&1; then
  bad "scaffolded e2e without a command must FAIL, not pass silently"
else
  ok "scaffolded e2e without a command fails closed"
fi

# 20b — and it must say what to do about it
OUT20="$(make e2e 2>&1)"
assert_contains "the empty e2e explains itself" "$OUT20" "e2e"

# 20c — the gate that catches this class for every target
cat > Makefile.broken <<'MKEOF'
.PHONY: real
real:
	pnpm test

.PHONY: empty
empty:
	echo 'TODO: set the end-to-end command'
MKEOF
OUTB="$(MAKEFILE_UNDER_TEST=Makefile.broken bash scripts/verify-makefile-gates.sh 2>&1)"; RCB=$?
assert_eq "a placeholder target is rejected" "1" "$RCB"
assert_contains "the offending target is named" "$OUTB" "empty"

# 20d — and a healthy Makefile is accepted
cat > Makefile.ok <<'MKEOF'
.PHONY: real
real:
	pnpm test
MKEOF
MAKEFILE_UNDER_TEST=Makefile.ok bash scripts/verify-makefile-gates.sh >/dev/null 2>&1
assert_eq "a Makefile whose targets all work is accepted" "0" "$?"
rm -f Makefile.broken Makefile.ok

# 20f — a template script the installer forgets is a gate that SKIPs forever.
# run-gates.sh skips a gate whose script is missing (deliberate: version-sync is the
# kit's own and must not run in scaffolded repos), so the omission is silent by design.
for tpl in "$KIT_DIR"/templates/full/scripts/*.sh; do
  base="$(basename "$tpl")"
  # Registered gates are the ones that must travel; helpers are pulled in by name elsewhere.
  grep -q "bash scripts/$base" "$KIT_DIR/templates/full/scripts/run-gates.sh" || continue
  assert_file "installed: scripts/$base" "$GATES/scripts/$base"
done

# 20e — the gate is registered, or nobody ever runs it
assert_contains "makefile-gates is a registered gate" \
  "$(cat "$KIT_DIR/scripts/run-gates.sh")" "makefile-gates"

# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo "${BOLD}21. verify-claims observes every declared execution${RESET}"
# Equal command text does not prove equal inputs: a previous layer may mutate
# the filesystem or environment. Each declaration therefore earns its own run.

DEDUP="$WORK/dedup"; make_fixture "$DEDUP"
bash "$KIT_DIR/bin/harness-init.sh" --target "$DEDUP" --level full >/dev/null 2>&1
cd "$DEDUP" || exit 1

dedup_claims() {
  FEATS="$1" python3 - <<'PYEOF2'
import json, os
d = json.load(open("feature_list.json"))
d["features"] = json.loads(os.environ["FEATS"])
json.dump(d, open("feature_list.json", "w"), indent=2)
PYEOF2
}

COUNTER="$DEDUP/counter.txt"
SHARED='{"label":"suite","cmd":"printf x >> \"$COUNTER\"","repair":"r"}'

# 21a — three features, one shared command, three observed executions
: > "$COUNTER"
dedup_claims "[{\"id\":\"D1\",\"state\":\"passing\",\"behavior\":\"b\",\"evidence\":[\"e\"],\"layers\":[$SHARED]},
               {\"id\":\"D2\",\"state\":\"passing\",\"behavior\":\"b\",\"evidence\":[\"e\"],\"layers\":[$SHARED]},
               {\"id\":\"D3\",\"state\":\"passing\",\"behavior\":\"b\",\"evidence\":[\"e\"],\"layers\":[$SHARED]}]"
OUT21="$(COUNTER="$COUNTER" bash scripts/verify-claims.sh 2>&1)"; RC21=$?
assert_eq "shared-layer claims still exit 0" "0" "$RC21"
assert_eq "an identical command runs for every declaration" "3" "$(wc -c < "$COUNTER" | tr -d ' ')"

# 21b — every independently observed feature remains visible in the report
assert_contains "every feature is still reported" "$OUT21" "D3"

# 21c — genuinely different commands are genuinely different verifications
: > "$COUNTER"
dedup_claims "[{\"id\":\"D1\",\"state\":\"passing\",\"behavior\":\"b\",\"evidence\":[\"e\"],\"layers\":[{\"label\":\"a\",\"cmd\":\"printf x >> \\\"\$COUNTER\\\"\",\"repair\":\"r\"}]},
               {\"id\":\"D2\",\"state\":\"passing\",\"behavior\":\"b\",\"evidence\":[\"e\"],\"layers\":[{\"label\":\"b\",\"cmd\":\"printf y >> \\\"\$COUNTER\\\"\",\"repair\":\"r\"}]}]"
COUNTER="$COUNTER" bash scripts/verify-claims.sh >/dev/null 2>&1
assert_eq "two distinct commands both run" "2" "$(wc -c < "$COUNTER" | tr -d ' ')"

# 21d — each feature depending on a shared failure remains a failed claim
dedup_claims '[{"id":"D1","state":"passing","behavior":"b","evidence":["e"],"layers":[{"label":"s","cmd":"false","repair":"r"}]},
               {"id":"D2","state":"passing","behavior":"b","evidence":["e"],"layers":[{"label":"s","cmd":"false","repair":"r"}]}]'
OUTF="$(bash scripts/verify-claims.sh 2>&1)"; RCF=$?
assert_eq "a shared failing command still fails" "1" "$RCF"
assert_contains "it fails once per feature that declares it" "$OUTF" "2 layer(s) failed"

# ── 15 — verify-delivery-doc: the runbook must describe THIS release ─────────
# Fixture reproduces the real handover that motivated the gate: a v1.2.5 pass
# whose runbook still carried a v1.2.4 deploy command, a section about an
# already-applied migration, no mention of the one being shipped, and a dead link.
echo ""
echo "${BOLD}15 — verify-delivery-doc${RESET}"

DD="$WORK/delivery"; mkdir -p "$DD/scripts" "$DD/supabase/migrations"
cd "$DD" || exit 1
git init -q . && git config user.email t@t && git config user.name t
cp "$KIT_DIR/templates/full/scripts/verify-delivery-doc.sh" scripts/
printf '{\n  "version": "1.2.5"\n}\n' > package.json
cat > README.md <<'DOC'
# X

## Desplegar v1.2.5

```bash
just ecr-push-tag v1.2.5
```

### La migración de v1.2.1 (solo si vienen de v1.2.0)

| Hacer | No hacer |
|---|---|
| Los pasos | `just ecr-push-tag v1.2.4` |

Ver [`GUIA.md`](./GUIA.md).
DOC
printf -- '-- vieja\n' > supabase/migrations/20260916120000_a.sql
git add -A >/dev/null && git commit -qm base && git tag v1.2.4
printf -- '-- nueva\n' > supabase/migrations/20260917120000_b.sql
git add -A >/dev/null && git commit -qm nueva

OUT15="$(bash scripts/verify-delivery-doc.sh 2>&1)"; RC15=$?
assert_eq "a runbook describing the previous release fails" "1" "$RC15"
assert_contains "it names the stale deploy tag"        "$OUT15" "ecr-push-tag v1.2.4"
assert_contains "it names the unmentioned migration"   "$OUT15" "20260917120000"
assert_contains "it flags the section about an older version" "$OUT15" "v1.2.1"
assert_contains "it flags the dead relative link"      "$OUT15" "GUIA.md"

# A base that does not resolve must stop the run, never pass quietly: reporting
# "no new migrations" for a release that ships one is the silence this prevents.
DELIVERY_BASE=deadbeef bash scripts/verify-delivery-doc.sh >/dev/null 2>&1
assert_eq "an unresolvable DELIVERY_BASE is NOT_CONFIGURED, not a pass" "3" "$?"

# The same document, corrected, is the green path.
cat > README.md <<'DOC'
# X

## Desplegar v1.2.5

```bash
just ecr-push-tag v1.2.5
```

Migración de este pase: `20260917120000`.

### Ya en v1.2.1: lo que trajo aquel pase

Histórico.
DOC
touch GUIA.md && git add -A >/dev/null && git commit -qm fix
OUT15B="$(bash scripts/verify-delivery-doc.sh 2>&1)"; RC15B=$?
assert_eq "the corrected runbook passes" "0" "$RC15B"
assert_contains "and says which release it describes" "$OUT15B" "1.2.5"

# A changelog citing each release's own tag is history, not a stale command.
printf '# CHANGELOG\n\n- v1.2.4: `just ecr-push-tag v1.2.4`\n' > CHANGELOG.md
git add -A >/dev/null && git commit -qm changelog
bash scripts/verify-delivery-doc.sh >/dev/null 2>&1
assert_eq "a changelog's own tags are not flagged" "0" "$?"

# A repo that publishes no runbook stands down loudly instead of failing: a gate
# that cries wolf on those gets silenced, and takes the real signal with it.
rm -f README.md && printf '# X\n\nNo runbook here.\n' > README.md
git add -A >/dev/null && git commit -qm noheading
OUT15C="$(bash scripts/verify-delivery-doc.sh 2>&1)"
assert_eq "no runbook heading is a skip, not a failure" "0" "$?"
assert_contains "and the skip says why"  "$OUT15C" "publishes no deploy runbook"

# Unless the repo declares it does deliver one — then the missing heading is the finding.
DELIVERY_DOC_REQUIRED=1 bash scripts/verify-delivery-doc.sh >/dev/null 2>&1
assert_eq "a delivering repo cannot lose its runbook silently" "1" "$?"

cd "$KIT_DIR" || exit 1

# ── 16 — run-gates: only PASS satisfies a gate ───────────────────────────────
# The runner used to know two answers, so a gate that could not check anything
# looked the same as one that checked and was clean. verify-delivery-doc shipped
# with exactly that hole: handed an unresolvable ref, it printed "no new
# migrations" for a release that shipped one.
echo ""
echo "${BOLD}16 — run-gates state machine${RESET}"

RG="$WORK/rungates"; mkdir -p "$RG/scripts"
cd "$RG" || exit 1
cp "$KIT_DIR/templates/full/scripts/run-gates.sh" scripts/
mk_gate() { printf '#!/usr/bin/env bash\nexit %s\n' "$2" > "scripts/$1"; chmod +x "scripts/$1"; }
reg() { python3 - "$@" <<'PYX'
import re, sys, pathlib
p = pathlib.Path("scripts/run-gates.sh"); t = p.read_text()
rows = "\n".join(f'  "{r}"' for r in sys.argv[1:])
t = re.sub(r"GATES=\(\n.*?\n\)", f"GATES=(\n{rows}\n)", t, count=1, flags=re.S)
p.write_text(t)
import json
pathlib.Path('.harness').mkdir(exist_ok=True)
rows=[r.split('|') for r in sys.argv[1:]]
kind='full' if any(r[2]=='optional' for r in rows) else 'kit'
pathlib.Path('.harness/installation-profile.json').write_text(json.dumps({'schema_version':1,'installation':kind,'gates':{r[0]:{'applicable':r[2]!='optional','reason':'Kit release metadata only' if r[2]=='optional' else 'required fixture gate'} for r in rows}}))
PYX
}

mk_gate g-pass.sh 0
mk_gate g-fail.sh 1
mk_gate g-config.sh 2
mk_gate g-tool.sh 3
mk_gate g-incomplete.sh 4
mk_gate g-policy.sh 5
mk_gate g-weird.sh 42

reg "only-pass|quick|required|bash scripts/g-pass.sh"
OUT16="$(bash scripts/run-gates.sh quick 2>&1)"
assert_eq "a passing gate exits 0" "0" "$?"
assert_contains "and reports PASS" "$OUT16" "PASS"

# Each non-zero code keeps its own name, because each sends you somewhere else:
# FAIL means fix the code, TOOL_FAILURE means fix the machine.
for pair in "g-fail.sh:FAIL" "g-config.sh:NOT_CONFIGURED" "g-tool.sh:TOOL_FAILURE" \
            "g-incomplete.sh:INCOMPLETE" "g-policy.sh:POLICY" "g-weird.sh:UNKNOWN"; do
  s="${pair%%:*}"; want="${pair##*:}"
  reg "probe|quick|required|bash scripts/$s"
  O="$(bash scripts/run-gates.sh quick 2>&1)"; RC=$?
  assert_eq "$want blocks the run" "1" "$RC"
  assert_contains "$want is reported by name" "$O" "$want"
done

# An unknown exit code must never be read as success — that is the whole point.
reg "probe|quick|required|bash scripts/g-weird.sh"
assert_contains "an unknown state says nothing was verified" \
  "$(bash scripts/run-gates.sh quick 2>&1)" "not verified"

# A required gate that is simply absent is a finding, not a skip.
reg "ghost|quick|required|bash scripts/does-not-exist.sh"
O16B="$(bash scripts/run-gates.sh quick 2>&1)"; RC16B=$?
assert_eq "a missing REQUIRED gate blocks" "1" "$RC16B"
assert_contains "and is named NOT_EXECUTED" "$O16B" "NOT_EXECUTED"

# Optional is the only way to stand a gate down, and it has to be declared.
reg "version-sync|quick|optional|bash scripts/does-not-exist.sh"
O16C="$(bash scripts/run-gates.sh quick 2>&1)"
assert_eq "a declared inapplicable kit-only gate does not block" "0" "$?"
assert_contains "and states explicit applicability" "$O16C" "NOT_APPLICABLE"

# Mixed run: one clean gate cannot carry a broken one.
reg "ok|quick|required|bash scripts/g-pass.sh" "broken|quick|required|bash scripts/g-tool.sh"
bash scripts/run-gates.sh quick >/dev/null 2>&1
assert_eq "a passing gate does not offset a blocking one" "1" "$?"

cd "$KIT_DIR" || exit 1

# ── 17 — verify-context-routes: a governed change must cite what governs it ───
# Reproduces the real failure: a fix that invented engineering tolerances while
# DECISIONS.md §D2 forbade exactly that, one grep away and never opened.
echo ""
echo "${BOLD}17 — verify-context-routes${RESET}"

CR="$WORK/routes"; mkdir -p "$CR/scripts" "$CR/.harness" "$CR/lib/rules" "$CR/docs"
cd "$CR" || exit 1
git init -q . && git config user.email t@t && git config user.name t
cp "$KIT_DIR/templates/full/scripts/verify-context-routes.sh" scripts/
# Domain routes belong to this fixture, never to the generic consumer template.
cat > .harness/context-routes.json <<'ROUTES'
{"routes":[{"paths":["lib/rules/**"],"read":["docs/DECISIONS.md"],"why":"An external report does not repeal a decision"}]}
ROUTES
printf '# D2\nEl comparador no inventa tolerancias.\n' > docs/DECISIONS.md
printf 'export const x = 1;\n' > lib/rules/base.ts
git add -A >/dev/null && git commit -qm base && git branch -M main

git checkout -qb feat/tolerances
printf 'export const WIDTH_MIN = 80;\n' > lib/rules/spec-plausibility.ts
git add -A >/dev/null && git commit -qm "feat: valida rangos fisicos del ancho"
O17="$(bash scripts/verify-context-routes.sh 2>&1)"; RC17=$?
assert_eq "a governed change citing nothing fails" "1" "$RC17"
assert_contains "it names the documents that govern it" "$O17" "DECISIONS.md"
assert_contains "and says why they govern"             "$O17" "does not repeal a decision"

git commit -q --amend -m "feat: rangos por compatibility_rules

DECISIONS.md D2 prohibe inventar tolerancias, asi que los rangos los aporta
Compras y no el codigo."
assert_eq "the same change, citing its source, passes" "0" \
  "$(bash scripts/verify-context-routes.sh >/dev/null 2>&1; echo $?)"

# An Agent Note carries the citation just as well as a commit message.
git checkout -q main && git checkout -qb feat/via-note
mkdir -p .agents/notes/implemented/bug-fix
printf 'export const z = 3;\n' > lib/rules/other.ts
printf '# Why\n\nGoverned by DECISIONS.md and left in force.\n' \
  > .agents/notes/implemented/bug-fix/note.md
git add -A >/dev/null && git commit -qm "fix: something"
assert_eq "a citation inside an Agent Note counts" "0" \
  "$(bash scripts/verify-context-routes.sh >/dev/null 2>&1; echo $?)"

# Ungoverned paths must not be nagged: a gate that fires on everything gets
# silenced, and takes the real signal with it.
git checkout -q main && git checkout -qb docs/only
printf 'hola\n' > LEEME.md && git add -A >/dev/null && git commit -qm "docs: nota"
assert_eq "an ungoverned change is not nagged" "0" \
  "$(bash scripts/verify-context-routes.sh >/dev/null 2>&1; echo $?)"

# The advisory mode reads the same map but never blocks.
git checkout -q main && git checkout -qb feat/list
printf 'export const w = 4;\n' > lib/rules/more.ts
git add -A >/dev/null && git commit -qm wip
O17L="$(bash scripts/verify-context-routes.sh --list 2>&1)"
assert_eq "--list advises without blocking" "0" "$?"
assert_contains "and prints the reading list" "$O17L" "DECISIONS.md"

# Neither a bad base nor a missing map may look clean.
git checkout -q main
ROUTES_BASE=deadbeef bash scripts/verify-context-routes.sh >/dev/null 2>&1
assert_eq "an unresolvable base never passes" "2" "$?"
CONTEXT_ROUTES=.harness/nope.json bash scripts/verify-context-routes.sh >/dev/null 2>&1
assert_eq "a missing route map is NOT_CONFIGURED" "2" "$?"
printf 'not json at all' > .harness/broken.json
CONTEXT_ROUTES=.harness/broken.json bash scripts/verify-context-routes.sh >/dev/null 2>&1
assert_eq "a malformed route map is NOT_CONFIGURED" "2" "$?"

cd "$KIT_DIR" || exit 1

# ── 18 — verify-oracles: a critical criterion must be proved falsifiable ─────
# AGENTS.md already required it: a test only ever seen passing does not count.
# This is that convention with a gate behind it.
echo ""
echo "${BOLD}18 — verify-oracles${RESET}"

OR="$WORK/oracles"; mkdir -p "$OR/scripts" "$OR/.harness/oracles" "$OR/test"
cd "$OR" || exit 1
git init -q . && git config user.email t@t && git config user.name t
cp "$KIT_DIR/templates/full/scripts/verify-oracles.sh" scripts/
printf 'assert False, "fixture defect"\n' > test/rule.test.ts
git add -A >/dev/null && git commit -qm base

# An empty folder is an honest answer, not a silence: the gate arrives before
# the criteria do.
rm -rf .harness/oracles && mkdir -p .harness/oracles
assert_eq "no oracles is a pass, stated out loud" "0" \
  "$(bash scripts/verify-oracles.sh >/dev/null 2>&1; echo $?)"

write_oracle() { cat > .harness/oracles/AC-001.yaml; }

# TEST_READY with unanswered questions must not pass — that is the form-filling
# this gate exists to refuse.
write_oracle <<'YML'
id: AC-001
requirement: "Opposite polarity never matches"
criticality: critical
status: TEST_READY
observable: "The offer is excluded"
oracle:
  expected: "mismatch"
cases:
  negative:
    - "25 against 35"
context: "A catalogue entry in group 25"
side_effects:
  must_not:
    - "no other verdict changes"
false_positive: "TBD"
owner: "Compras"
evidence:
  formats: ["junit"]
tests:
  - "test/rule.test.ts"
YML
O18="$(bash scripts/verify-oracles.sh 2>&1)"; RC18=$?
assert_eq "an unanswered question blocks TEST_READY" "1" "$RC18"
assert_contains "and the message quotes the question" "$O18" "false positive"

# A placeholder is not an answer.
assert_contains "«TBD» does not count as answered" "$O18" "AC-001"

# All eight answered, but no proof it can fail.
write_oracle <<'YML'
id: AC-001
requirement: "Opposite polarity never matches"
criticality: critical
status: TEST_READY
observable: "The offer is excluded from the ranking"
oracle:
  expected: "mismatch"
cases:
  positive:
    - "25 against 25"
  negative:
    - "25 against 35"
context: "A catalogue entry in group 25"
side_effects:
  must_not:
    - "no other verdict changes"
false_positive: "It would pass if the test asserted on its own fixture"
owner: "Compras"
evidence:
  formats: ["junit"]
tests:
  - "test/rule.test.ts"
YML
O18B="$(bash scripts/verify-oracles.sh 2>&1)"
assert_eq "a critical criterion with no falsification blocks" "1" "$?"
assert_contains "and says what a test only seen passing proves" "$O18B" "has not been shown to test anything"

add_falsification() {
  cat >> .harness/oracles/AC-001.yaml <<YML
falsification:
  defect: "Compare with string equality again"
  proved_sha: "$1"
  receipt: "red-receipt.json"
YML
  python3 test/rule.test.ts > red.log 2>&1
  local red_exit=$?
  python3 - "$red_exit" <<'RECEIPT'
import hashlib,json,sys
from pathlib import Path
h=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
Path('red-receipt.json').write_text(json.dumps({'schema_version':1,'command':['python3','test/rule.test.ts'],'exit_code':int(sys.argv[1]),'tests':{'test/rule.test.ts':h('test/rule.test.ts')},'source':{'test/rule.test.ts':h('test/rule.test.ts')},'logs':{'red.log':h('red.log')}}))
RECEIPT
}

git add -A >/dev/null && git commit -qm "oracle"
SHA_OK="$(git rev-parse HEAD)"
add_falsification "$SHA_OK"
git add -A >/dev/null && git commit -qm "prove"
assert_eq "a proved criterion passes" "0" \
  "$(bash scripts/verify-oracles.sh >/dev/null 2>&1; echo $?)"

# ── The case this gate exists for ────────────────────────────────────────────
# Editing the test after proving it can fail leaves a proof that no longer covers
# the test that exists. That is STALE, and STALE is not green.
printf 'it("works", () => { expect(1).toBe(1); });\n' > test/rule.test.ts
git add -A >/dev/null && git commit -qm "loosen the test"
O18C="$(bash scripts/verify-oracles.sh 2>&1)"; RC18C=$?
assert_eq "editing the test after the proof goes stale" "1" "$RC18C"
assert_contains "and names the test that moved" "$O18C" "test/rule.test.ts"
assert_contains "and says the proof no longer covers it" "$O18C" "predates its own tests"

# A SHA from nowhere is not a proof either.
sed -i.bak "s/proved_sha: .*/proved_sha: \"deadbeefdeadbeefdeadbeefdeadbeefdeadbeef\"/" .harness/oracles/AC-001.yaml
rm -f .harness/oracles/AC-001.yaml.bak
O18D="$(bash scripts/verify-oracles.sh 2>&1)"
assert_eq "a SHA outside this history blocks" "1" "$?"
assert_contains "and says so plainly" "$O18D" "not in this history"

# A named test that does not exist is a wish, not a criterion.
git checkout -q -- test/rule.test.ts 2>/dev/null
sed -i.bak "s|proved_sha: .*|proved_sha: \"$SHA_OK\"|" .harness/oracles/AC-001.yaml
sed -i.bak "s|- \"test/rule.test.ts\"|- \"test/does-not-exist.ts\"|" .harness/oracles/AC-001.yaml
rm -f .harness/oracles/AC-001.yaml.bak
assert_eq "a test that does not exist blocks" "1" \
  "$(bash scripts/verify-oracles.sh >/dev/null 2>&1; echo $?)"

# A critical criterion still in DRAFT is unfinished thinking, not a failing test.
sed -i.bak 's/status: TEST_READY/status: DRAFT/' .harness/oracles/AC-001.yaml
rm -f .harness/oracles/AC-001.yaml.bak
O18E="$(bash scripts/verify-oracles.sh 2>&1)"
assert_eq "a critical DRAFT blocks" "1" "$?"
assert_contains "and says no code should rely on it yet" "$O18E" "no production code should rely on it"

# RETIRED keeps its history without being enforced.
sed -i.bak 's/status: DRAFT/status: RETIRED/' .harness/oracles/AC-001.yaml
rm -f .harness/oracles/AC-001.yaml.bak
assert_eq "a retired criterion is not enforced" "0" \
  "$(bash scripts/verify-oracles.sh >/dev/null 2>&1; echo $?)"

# --list reports without blocking.
O18F="$(bash scripts/verify-oracles.sh --list 2>&1)"
assert_eq "--list never blocks" "0" "$?"
assert_contains "and shows the status" "$O18F" "RETIRED"

cd "$KIT_DIR" || exit 1

H02_FOCAL_LOG="$WORK/h02-focal.log"
if python3 "$KIT_DIR/tests/h02-hardening-regressions.py" >"$H02_FOCAL_LOG" 2>&1; then
  ok "H02 live gates, profile, hook, oracle and status regression matrix"
else
  cat "$H02_FOCAL_LOG"
  bad "H02 hardening regressions"
fi

# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo "${BOLD}────────────────────────────────────────${RESET}"
echo "${BOLD}$PASS passed, $FAIL failed${RESET}"
[[ $FAIL -eq 0 ]] || exit 1
echo "${GREEN}${BOLD}All tests passed.${RESET}"
