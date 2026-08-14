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
assert_file() {
  [[ -f "$2" ]] && ok "$1" || bad "$1 (no such file: $2)"
}

make_fixture() {
  # make_fixture <dir>  — a minimal node project with a green check
  local d="$1"
  mkdir -p "$d" && cd "$d" && git init -q
  cat > package.json <<'EOF'
{ "name":"fixture","version":"1.0.0",
  "scripts":{"check":"echo static-ok","test":"echo tests-ok","dev":"echo dev"} }
EOF
  echo '{}' > package-lock.json
  echo "20" > .nvmrc
  git add -A && git -c user.email=t@t -c user.name=t commit -qm "base" >/dev/null
  cd - >/dev/null
}

echo "${BOLD}harness-kit test suite${RESET}"

# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo "${BOLD}1. Syntax${RESET}"
for f in "$KIT_DIR"/bin/*.sh "$KIT_DIR"/templates/full/scripts/*.sh "$KIT_DIR"/tests/*.sh; do
  if bash -n "$f" 2>/dev/null; then ok "syntax $(basename "$f")"
  else bad "syntax $(basename "$f")"; fi
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
[[ "$FULL_SCORE" -ge 70 ]] && ok "full harness scores >= 70/74 (got $FULL_SCORE)" \
                           || bad "full harness scored only $FULL_SCORE/74"

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
cd "$FULL"

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
assert_eq "failing feature is NOT promoted" "active" "$STATE2"

# 8c — a layer command that calls `exit` must not kill the script silently
python3 - <<'PYEOF'
import json
d = json.load(open("feature_list.json"))
d["features"][1]["layers"] = [{"label":"static","cmd":"exit 3","repair":"EXIT-MARKER"}]
json.dump(d, open("feature_list.json","w"), indent=2)
PYEOF
OUT3="$(bash scripts/verify-feature.sh F02 2>&1)"
assert_contains "layer calling exit still prints repair" "$OUT3" "EXIT-MARKER"

# 8d — unknown feature id
bash scripts/verify-feature.sh NOPE >/dev/null 2>&1
assert_eq "unknown feature id exits 66" "66" "$?"

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
cp scripts/clean-state-check.sh /tmp/csc-backup.sh
mkdir -p sub && echo '{}' > sub/marker.json
sed -i.bak 's|^VERIFY_CMD=.*|VERIFY_CMD="cd sub \&\& true"|' scripts/clean-state-check.sh
rm -f scripts/clean-state-check.sh.bak
OUT_CD="$(bash scripts/clean-state-check.sh . 2>&1)"
case "$OUT_CD" in
  *"PROGRESS.md missing"*) bad "cd in verify command breaks later checks (cwd leaked)" ;;
  *) ok "verify command that cd's does not leak the working directory" ;;
esac
cp /tmp/csc-backup.sh scripts/clean-state-check.sh
rm -rf sub /tmp/csc-backup.sh

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
mkdir -p src
printf 'export const cfg = { api_key: "sk_live_9fJ2xQ7mNp4RtY8wZ1aB3cD5" };\n' > src/leak.ts
git add -A >/dev/null 2>&1
OUT6="$(bash scripts/check-arch.sh . 2>&1)"
ARCH_RC=$?
assert_eq "committed secret trips a rule" "1" "$ARCH_RC"
assert_contains "violation reports WHAT" "$OUT6" "WHAT:"
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
echo "${BOLD}13. budgets — the anti-loop gate${RESET}"
cd "$FULL"

# Install a feature FB1 with the given budgets and a single layer command.
# Usage: fb1 <cmd> <review_rounds_max> <repeated_blocker_max> <stop_condition>
fb1() {
  CMD="$1" RMAX="$2" BMAX="$3" STOP="$4" python3 - <<'PYEOF'
import json, os
d = json.load(open("feature_list.json"))
d["features"] = [f for f in d["features"] if f.get("id") != "FB1"]
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

# 13c — exhausting the review budget stops the loop and escalates
OUTC="$(bash scripts/verify-feature.sh FB1 2>&1)"; RCC=$?
assert_eq "exhausted review budget exits 3" "3" "$RCC"
assert_contains "exhaustion is named" "$OUTC" "BUDGET_EXHAUSTED"
assert_contains "exhaustion prints the stop condition" "$OUTC" "escalate to a human"
STC="$(python3 -c "
import json
for f in json.load(open('feature_list.json'))['features']:
    if f.get('id')=='FB1': print(f['state'])
")"
assert_eq "exhausted feature is never promoted" "blocked" "$STC"

# 13d — the same blocker recurring hits its own ceiling
fb1 "false" 99 2 "stop and ask for help"
bash scripts/verify-feature.sh FB1 >/dev/null 2>&1
OUTD="$(bash scripts/verify-feature.sh FB1 2>&1)"; RCD=$?
assert_eq "repeated blocker exits 4" "4" "$RCD"
assert_contains "repeated blocker is named" "$OUTD" "REPEATED_BLOCKER"

# 13e — a green run resets the ledger, so budgets measure the current attempt
fb1 "false" 9 9 "stop"
bash scripts/verify-feature.sh FB1 >/dev/null 2>&1
assert_eq "ledger accumulated before success" "1" "$(fb1_rounds)"
python3 - <<'PYEOF'
import json
d = json.load(open("feature_list.json"))
for f in d["features"]:
    if f.get("id") == "FB1":
        f["layers"] = [{"label": "static", "cmd": "true", "repair": "n/a"}]
json.dump(d, open("feature_list.json", "w"), indent=2)
PYEOF
bash scripts/verify-feature.sh FB1 >/dev/null 2>&1
assert_eq "success promotes despite prior failures" "0" "$?"
assert_eq "success resets the review ledger" "0" "$(fb1_rounds)"

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
cd "$CLAIMS"

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

cd "$KIT_DIR"

# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo "${BOLD}────────────────────────────────────────${RESET}"
echo "${BOLD}$PASS passed, $FAIL failed${RESET}"
[[ $FAIL -eq 0 ]] || exit 1
echo "${GREEN}${BOLD}All tests passed.${RESET}"
