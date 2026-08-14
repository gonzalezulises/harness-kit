#!/usr/bin/env bash
# verify-feature.sh — the gate between "I wrote code" and "the feature passes".
#
# Usage:
#   scripts/verify-feature.sh F01     # run every layer, gate to passing on success
#   scripts/verify-feature.sh --ratio # print the Verified Completion Ratio
#
# This script is the ONLY thing allowed to set a feature's state to "passing".
# Agents must never hand-edit that field: a state written by hand is a claim,
# a state written here is a receipt.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR" || { echo "cannot cd to $ROOT_DIR" >&2; exit 66; }

FL="feature_list.json"
[[ -f "$FL" ]] || { echo "verify-feature: $FL not found in $ROOT_DIR" >&2; exit 66; }

if [[ ! -t 1 ]] || [[ -n "${NO_COLOR:-}" ]]; then
  RED=""; GREEN=""; YELLOW=""; BOLD=""; RESET=""
else
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
  BOLD=$'\033[1m'; RESET=$'\033[0m'
fi

PY=""
for c in python3 python; do
  command -v "$c" >/dev/null 2>&1 && { PY="$c"; break; }
done
[[ -n "$PY" ]] || { echo "verify-feature: needs python3 (or jq-based rewrite)" >&2; exit 69; }

# ── Verified Completion Ratio ────────────────────────────────────────────────
if [[ "${1:-}" == "--ratio" ]]; then
  "$PY" - "$FL" <<'PYEOF'
import json, sys
data = json.load(open(sys.argv[1]))
feats = data.get("features", [])
active  = [f for f in feats if f.get("state") == "active"]
passing = [f for f in feats if f.get("state") == "passing"]
activated = len(active) + len(passing)
if activated == 0:
    print("VCR: n/a — no features activated yet")
else:
    ratio = len(passing) / activated
    print(f"VCR = {len(passing)}/{activated} = {ratio:.2f}")
    for f in active:
        print(f"  still active: {f.get('id')} — {f.get('behavior','')[:60]}")
if len(active) > 1:
    print("WIP=1 VIOLATION: more than one feature is active.")
    sys.exit(1)
PYEOF
  exit $?
fi

FEATURE_ID="${1:-}"
[[ -n "$FEATURE_ID" ]] || { echo "usage: $0 <feature-id> | --ratio" >&2; exit 64; }

# ── Load the feature's layers ────────────────────────────────────────────────
LAYERS_TSV="$("$PY" - "$FL" "$FEATURE_ID" <<'PYEOF'
import json, sys
data = json.load(open(sys.argv[1]))
fid = sys.argv[2]
for f in data.get("features", []):
    if f.get("id") == fid:
        layers = f.get("layers") or []
        if not layers:
            print("__NOLAYERS__")
            sys.exit(0)
        for l in layers:
            label  = (l.get("label")  or "layer").replace("\t", " ")
            cmd    = (l.get("cmd")    or "").replace("\t", " ")
            repair = (l.get("repair") or "No repair guidance recorded.").replace("\t", " ")
            print(f"{label}\t{cmd}\t{repair}")
        sys.exit(0)
print("__NOTFOUND__")
PYEOF
)"

if [[ "$LAYERS_TSV" == "__NOTFOUND__" ]]; then
  echo "${RED}verify-feature: no feature with id '$FEATURE_ID' in $FL${RESET}" >&2
  exit 66
fi
if [[ "$LAYERS_TSV" == "__NOLAYERS__" ]]; then
  echo "${RED}verify-feature: feature '$FEATURE_ID' has no layers defined.${RESET}" >&2
  echo "Add a 'layers' array with label / cmd / repair before verifying." >&2
  exit 65
fi

# ── Budget preflight ─────────────────────────────────────────────────────────
# A feature that declares budgets must also declare what makes the work stop.
# Without that, "out of budget" has no answer and the loop restarts forever.
BUDGET_CHECK="$("$PY" - "$FL" "$FEATURE_ID" <<'PYEOF'
import json, sys
data = json.load(open(sys.argv[1]))
for f in data.get("features", []):
    if f.get("id") == sys.argv[2]:
        b = f.get("budgets")
        if not b:
            print("NOBUDGET")
        elif not str(b.get("stop_condition") or "").strip():
            print("NOSTOP")
        else:
            print("OK")
        sys.exit(0)
print("NOBUDGET")
PYEOF
)"

if [[ "$BUDGET_CHECK" == "NOSTOP" ]]; then
  echo "${RED}STOP_CONDITION_REQUIRED: feature '$FEATURE_ID' declares budgets but no stop_condition.${RESET}" >&2
  echo "Add budgets.stop_condition describing what ends the work — who is told, and" >&2
  echo "what happens next — before this feature can be verified." >&2
  exit 67
fi

# ── Run each layer in order; stop at the first failure ───────────────────────
echo "${BOLD}Verifying $FEATURE_ID${RESET}"
FAILED_LAYER=""
FAILED_REPAIR=""

run_layer() {
  local label="$1" cmd="$2" repair="$3"
  echo ""
  echo "${BOLD}── Layer: ${label}${RESET}"
  echo "\$ $cmd"
  if [[ -z "$cmd" ]]; then
    echo "${YELLOW}(no command for this layer — treated as a failure)${RESET}"
    FAILED_LAYER="$label"; FAILED_REPAIR="$repair"
    return 1
  fi
  # Run in a subshell: a layer command that calls `exit` must not kill this script
  # before it can print the repair guidance.
  if ( eval "$cmd" ); then
    echo "${GREEN}Layer '${label}' passed.${RESET}"
    return 0
  else
    FAILED_LAYER="$label"; FAILED_REPAIR="$repair"
    return 1
  fi
}

while IFS=$'\t' read -r label cmd repair; do
  [[ -z "$label" ]] && continue
  if ! run_layer "$label" "$cmd" "$repair"; then
    echo ""
    echo "${RED}${BOLD}FAILED at layer: ${FAILED_LAYER}${RESET}"
    echo "${BOLD}How to fix:${RESET} ${FAILED_REPAIR}"

    # A failure spends budget. The ledger is written here, never by hand, so the
    # count of attempts is a receipt rather than something an agent can forget.
    if [[ "$BUDGET_CHECK" == "OK" ]]; then
      VERDICT="$("$PY" - "$FL" "$FEATURE_ID" "$FAILED_LAYER" <<'PYEOF'
import json, sys
path, fid, layer = sys.argv[1:4]
data = json.load(open(path))
for f in data.get("features", []):
    if f.get("id") != fid:
        continue
    b = f.get("budgets", {})
    ledger = f.setdefault("ledger", {"review_rounds": 0, "blockers": []})
    ledger["review_rounds"] = ledger.get("review_rounds", 0) + 1

    signature = "layer:%s" % layer
    for entry in ledger.setdefault("blockers", []):
        if entry.get("signature") == signature:
            entry["count"] = entry.get("count", 0) + 1
            hits = entry["count"]
            break
    else:
        ledger["blockers"].append({"signature": signature, "count": 1})
        hits = 1

    rounds = ledger["review_rounds"]
    rmax = int(b.get("review_rounds_max", 0) or 0)
    bmax = int(b.get("repeated_blocker_max", 0) or 0)
    stop = str(b.get("stop_condition") or "").strip()

    verdict = "CONTINUE|%d|%d|%s" % (rounds, rmax, stop)
    if rmax and rounds >= rmax:
        verdict = "BUDGET_EXHAUSTED|%d|%d|%s" % (rounds, rmax, stop)
    elif bmax and hits >= bmax:
        verdict = "REPEATED_BLOCKER|%d|%d|%s" % (hits, bmax, stop)

    if not verdict.startswith("CONTINUE"):
        f["state"] = "blocked"

    with open(path, "w") as fh:
        json.dump(data, fh, indent=2, ensure_ascii=False)
        fh.write("\n")
    print(verdict)
    sys.exit(0)
print("CONTINUE")
PYEOF
)"
      IFS='|' read -r KIND SEEN LIMIT STOP_TEXT <<< "$VERDICT"
      if [[ "$KIND" == "BUDGET_EXHAUSTED" || "$KIND" == "REPEATED_BLOCKER" ]]; then
        echo ""
        if [[ "$KIND" == "BUDGET_EXHAUSTED" ]]; then
          echo "${RED}${BOLD}BUDGET_EXHAUSTED${RESET} — $SEEN review rounds spent, budget is $LIMIT."
        else
          echo "${RED}${BOLD}REPEATED_BLOCKER${RESET} — layer '${FAILED_LAYER}' failed $SEEN times, ceiling is $LIMIT."
        fi
        echo "${BOLD}Stop condition:${RESET} $STOP_TEXT"
        echo ""
        echo "$FEATURE_ID is now ${BOLD}blocked${RESET}. Stop working on it."
        echo "Do not retry, do not refactor around it, do not open a new approach."
        echo "Escalate to a human, or split the feature into something smaller."
        [[ "$KIND" == "BUDGET_EXHAUSTED" ]] && exit 3 || exit 4
      fi
      echo ""
      echo "Review rounds spent: ${SEEN}${LIMIT:+/$LIMIT}."
    fi

    echo ""
    echo "Feature '$FEATURE_ID' stays in its current state. Do not advance to the"
    echo "next layer, and do not mark it passing."
    exit 1
  fi
done <<< "$LAYERS_TSV"

# ── All layers green: gate the state to passing, with evidence ───────────────
COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo "no-git")"
STAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

"$PY" - "$FL" "$FEATURE_ID" "$COMMIT" "$STAMP" <<'PYEOF'
import json, sys
path, fid, commit, stamp = sys.argv[1:5]
data = json.load(open(path))
for f in data.get("features", []):
    if f.get("id") == fid:
        f["state"] = "passing"
        f.setdefault("evidence", []).append(
            f"all layers passed — commit {commit}, {stamp}"
        )
        # Green run: the budget measures the current attempt, not repo history.
        if "ledger" in f:
            f["ledger"] = {"review_rounds": 0, "blockers": []}
data["last_updated"] = stamp[:10]
with open(path, "w") as fh:
    json.dump(data, fh, indent=2, ensure_ascii=False)
    fh.write("\n")
PYEOF

echo ""
echo "${GREEN}${BOLD}$FEATURE_ID -> passing${RESET} (evidence recorded in $FL)"
echo "Next: update PROGRESS.md and commit."
