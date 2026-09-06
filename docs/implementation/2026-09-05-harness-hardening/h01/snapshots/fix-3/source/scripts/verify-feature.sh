#!/usr/bin/env bash
# verify-feature.sh — run an active feature's layers and issue a passing receipt.
# Usage: scripts/verify-feature.sh <feature-id> | --ratio

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

MODE="verify"
FEATURE_ID="${1:-}"
if [[ "$FEATURE_ID" == "--ratio" ]]; then MODE="ratio"; FEATURE_ID=""; fi
[[ "$MODE" == "ratio" || -n "$FEATURE_ID" ]] || {
  echo "usage: $0 <feature-id> | --ratio" >&2; exit 64; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Validate the complete document and all state invariants before creating an
# executable command channel. Layer fields are written to separate files so an
# empty or multiline field cannot shift into another field.
set +e
"$PY" - "$FL" "$FEATURE_ID" "$MODE" "$WORK" <<'PYEOF'
import json, os, sys, tempfile
from pathlib import Path

path, fid, mode, work = sys.argv[1:5]
work = Path(work)

def strict_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate object key: " + key)
        result[key] = value
    return result

def safe_text(value, where, *, nonempty=False):
    if not isinstance(value, str) or "\0" in value or (nonempty and not value.strip()):
        reject(where + (" must be a non-empty NUL-free string" if nonempty else " must be a NUL-free string"))

def restore_blocked(feature):
    if feature.get("state") == "blocked":
        return
    feature["state"] = "blocked"
    directory = os.path.dirname(os.path.abspath(path)) or "."
    fd, tmp = tempfile.mkstemp(prefix=".feature-list-", dir=directory, text=True)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            json.dump(data, fh, indent=2, ensure_ascii=False)
            fh.write("\n")
        os.replace(tmp, path)
    except BaseException:
        try: os.unlink(tmp)
        except FileNotFoundError: pass
        raise

def reject(message, code=65):
    print("verify-feature: INVALID_FEATURE_LIST — " + message, file=sys.stderr)
    raise SystemExit(code)

try:
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh, object_pairs_hook=strict_object)
except (OSError, UnicodeError, json.JSONDecodeError, ValueError) as exc:
    reject(str(exc))
if not isinstance(data, dict):
    reject("root must be an object")
features = data.get("features")
if not isinstance(features, list):
    reject("features must be an array")

known_states = {"not_started", "active", "blocked", "passing"}
ids = set()
for i, feature in enumerate(features):
    where = f"features[{i}]"
    if not isinstance(feature, dict):
        reject(where + " must be an object")
    feature_id = feature.get("id")
    safe_text(feature_id, where + ".id", nonempty=True)
    if feature_id in ids:
        reject("duplicate feature id: " + feature_id)
    ids.add(feature_id)
    state = feature.get("state")
    if state not in known_states:
        reject(where + ".state is unknown: " + repr(state))
    evidence = feature.get("evidence", [])
    if not isinstance(evidence, list) or any(not isinstance(v, str) for v in evidence):
        reject(where + ".evidence must be an array of strings")
    layers = feature.get("layers", [])
    if not isinstance(layers, list):
        reject(where + ".layers must be an array")
    for j, layer in enumerate(layers):
        layer_where = f"{where}.layers[{j}]"
        if not isinstance(layer, dict):
            reject(layer_where + " must be an object")
        label = layer.get("label", "layer")
        command = layer.get("cmd")
        repair = layer.get("repair", "No repair guidance recorded.")
        safe_text(label, layer_where + ".label", nonempty=True)
        safe_text(command, layer_where + ".cmd", nonempty=True)
        safe_text(repair, layer_where + ".repair")
    budgets = feature.get("budgets")
    if budgets is not None:
        if not isinstance(budgets, dict):
            reject(where + ".budgets must be an object")
        stop_condition = budgets.get("stop_condition")
        if not isinstance(stop_condition, str) or "\0" in stop_condition or not stop_condition.strip():
            reject(where + ".budgets.stop_condition must be a non-empty NUL-free string", 67)
        for key in ("review_rounds_max", "repeated_blocker_max"):
            if key in budgets:
                value = budgets[key]
                if isinstance(value, bool) or not isinstance(value, int) or value < 0:
                    reject(f"{where}.budgets.{key} must be a non-negative integer")
    if "ledger" in feature:
        ledger = feature["ledger"]
        if not isinstance(ledger, dict) or not {"review_rounds", "blockers"} <= set(ledger):
            reject(where + ".ledger must contain review_rounds and blockers")
        rounds = ledger["review_rounds"]
        blockers = ledger["blockers"]
        if isinstance(rounds, bool) or not isinstance(rounds, int) or rounds < 0:
            reject(where + ".ledger.review_rounds must be a non-negative integer")
        if not isinstance(blockers, list):
            reject(where + ".ledger.blockers must be an array")
        signatures = set()
        blocker_total = 0
        for j, blocker in enumerate(blockers):
            if not isinstance(blocker, dict):
                reject(f"{where}.ledger.blockers[{j}] must be an object")
            signature, count = blocker.get("signature"), blocker.get("count")
            if not isinstance(signature, str) or "\0" in signature or not signature.strip():
                reject(f"{where}.ledger.blockers[{j}].signature must be a non-empty NUL-free string")
            if signature in signatures:
                reject(where + ".ledger has duplicate blocker signatures")
            signatures.add(signature)
            if isinstance(count, bool) or not isinstance(count, int) or count < 1:
                reject(f"{where}.ledger.blockers[{j}].count must be a positive integer")
            blocker_total += count
        if blocker_total != rounds:
            reject(where + ".ledger review_rounds must equal the recorded blocker count")

active = [f for f in features if f["state"] == "active"]
passing = [f for f in features if f["state"] == "passing"]
if mode == "ratio":
    activated = len(active) + len(passing)
    if not activated:
        print("VCR: n/a — no features activated yet")
    else:
        print(f"VCR = {len(passing)}/{activated} = {len(passing) / activated:.2f}")
        for feature in active:
            print(f"  still active: {feature['id']} — {str(feature.get('behavior', ''))[:60]}")
    if len(active) > 1:
        print("WIP=1 VIOLATION: more than one feature is active.")
        raise SystemExit(1)
    raise SystemExit(0)

matches = [(i, f) for i, f in enumerate(features) if f["id"] == fid]
if not matches:
    print(f"verify-feature: no feature with id '{fid}' in {path}", file=sys.stderr)
    raise SystemExit(66)
index, target = matches[0]
layers = target["layers"]
if not layers:
    print(f"verify-feature: feature '{fid}' has no layers defined.", file=sys.stderr)
    print("Add a 'layers' array with label / cmd / repair before verifying.", file=sys.stderr)
    raise SystemExit(65)

budgets = target.get("budgets") or {}
ledger = target.get("ledger") or {}
rounds = ledger.get("review_rounds", 0)
rmax = budgets.get("review_rounds_max", 0)
blockers = ledger.get("blockers", [])
bmax = budgets.get("repeated_blocker_max", 0)
repeated = max((b["count"] for b in blockers), default=0)
if rounds > 0:
    restore_blocked(target)
    print("RECOVERY_AUTHORITY_REQUIRED — recorded failed work cannot be reopened from mutable local state.", file=sys.stderr)
    print("A verified recovery grant is required before another attempt; configured limits and receipts were preserved.", file=sys.stderr)
    raise SystemExit(5)
if rmax and rounds >= rmax:
    restore_blocked(target)
    print(f"BUDGET_EXHAUSTED — {rounds} review rounds spent, budget is {rmax}.", file=sys.stderr)
    print("Stop condition: " + budgets["stop_condition"], file=sys.stderr)
    raise SystemExit(3)
if bmax and repeated >= bmax:
    restore_blocked(target)
    print(f"REPEATED_BLOCKER — blocker occurred {repeated} times, ceiling is {bmax}.", file=sys.stderr)
    print("Stop condition: " + budgets["stop_condition"], file=sys.stderr)
    raise SystemExit(4)
if target["state"] != "active":
    print(f"verify-feature: feature '{fid}' is {target['state']}; activate it before verification", file=sys.stderr)
    raise SystemExit(67)
if len(active) != 1:
    print(f"verify-feature: WIP=1 violation — {len(active)} features are active", file=sys.stderr)
    raise SystemExit(67)

(work / "target-index").write_text(str(index), encoding="utf-8")
(work / "budget-enabled").write_text("1" if budgets else "0", encoding="utf-8")
for i, layer in enumerate(layers):
    prefix = work / f"layer-{i:06d}"
    prefix.with_suffix(".label").write_text(layer.get("label", "layer"), encoding="utf-8")
    prefix.with_suffix(".cmd").write_text(layer["cmd"], encoding="utf-8")
    prefix.with_suffix(".repair").write_text(layer.get("repair", "No repair guidance recorded."), encoding="utf-8")
(work / "layer-count").write_text(str(len(layers)), encoding="utf-8")
PYEOF
PREFLIGHT_RC=$?
set -e
[[ "$PREFLIGHT_RC" -eq 0 ]] || exit "$PREFLIGHT_RC"
[[ "$MODE" == "verify" ]] || exit 0

TARGET_INDEX="$(cat "$WORK/target-index")"
BUDGET_ENABLED="$(cat "$WORK/budget-enabled")"
LAYER_COUNT="$(cat "$WORK/layer-count")"

echo "${BOLD}Verifying $FEATURE_ID${RESET}"
FAILED_LAYER=""
FAILED_REPAIR=""
for ((i=0; i<LAYER_COUNT; i++)); do
  prefix="$WORK/layer-$(printf '%06d' "$i")"
  label="$(cat "$prefix.label"; printf x)"; label="${label%x}"
  cmd="$(cat "$prefix.cmd"; printf x)"; cmd="${cmd%x}"
  repair="$(cat "$prefix.repair"; printf x)"; repair="${repair%x}"
  echo ""
  echo "${BOLD}── Layer: ${label}${RESET}"
  printf '$ %s\n' "$cmd"
  if ( eval "$cmd" ); then
    echo "${GREEN}Layer '${label}' passed.${RESET}"
    continue
  fi

  FAILED_LAYER="$label"
  FAILED_REPAIR="$repair"
  echo ""
  echo "${RED}${BOLD}FAILED at layer: ${FAILED_LAYER}${RESET}"
  echo "${BOLD}How to fix:${RESET} ${FAILED_REPAIR}"

  if [[ "$BUDGET_ENABLED" == "1" ]]; then
    VERDICT="$($PY - "$FL" "$TARGET_INDEX" "$FEATURE_ID" "$FAILED_LAYER" <<'PYEOF'
import json, os, sys, tempfile
path, raw_index, fid, layer = sys.argv[1:5]
index = int(raw_index)
def strict_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result: raise ValueError("duplicate object key: " + key)
        result[key] = value
    return result
with open(path, encoding="utf-8") as fh:
    data = json.load(fh, object_pairs_hook=strict_object)
features = data.get("features")
if not isinstance(features, list) or index >= len(features) or features[index].get("id") != fid:
    print("verify-feature: feature list changed during verification", file=sys.stderr)
    raise SystemExit(65)
f = features[index]
b = f["budgets"]
ledger = f.setdefault("ledger", {"review_rounds": 0, "blockers": []})
ledger["review_rounds"] += 1
signature = "layer:" + layer
for entry in ledger["blockers"]:
    if entry["signature"] == signature:
        entry["count"] += 1
        hits = entry["count"]
        break
else:
    ledger["blockers"].append({"signature": signature, "count": 1})
    hits = 1
rounds = ledger["review_rounds"]
rmax = b.get("review_rounds_max", 0)
bmax = b.get("repeated_blocker_max", 0)
kind, seen, limit = "CONTINUE", rounds, rmax
if rmax and rounds >= rmax:
    kind = "BUDGET_EXHAUSTED"
elif bmax and hits >= bmax:
    kind, seen, limit = "REPEATED_BLOCKER", hits, bmax
f["state"] = "blocked"
directory = os.path.dirname(os.path.abspath(path)) or "."
fd, tmp = tempfile.mkstemp(prefix=".feature-list-", dir=directory, text=True)
try:
    with os.fdopen(fd, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2, ensure_ascii=False)
        fh.write("\n")
    os.replace(tmp, path)
except BaseException:
    try: os.unlink(tmp)
    except FileNotFoundError: pass
    raise
print("|".join((kind, str(seen), str(limit), b["stop_condition"])))
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
      [[ "$KIND" == "BUDGET_EXHAUSTED" ]] && exit 3 || exit 4
    fi
    echo ""
    echo "Review rounds spent: ${SEEN}${LIMIT:+/$LIMIT}."
  fi
  echo ""
  echo "Feature '$FEATURE_ID' stays in its current state. Do not advance to the"
  echo "next layer, and do not mark it passing."
  exit 1
done

COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo "no-git")"
STAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
"$PY" - "$FL" "$TARGET_INDEX" "$FEATURE_ID" "$COMMIT" "$STAMP" <<'PYEOF'
import json, os, sys, tempfile
path, raw_index, fid, commit, stamp = sys.argv[1:6]
index = int(raw_index)
def strict_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result: raise ValueError("duplicate object key: " + key)
        result[key] = value
    return result
with open(path, encoding="utf-8") as fh:
    data = json.load(fh, object_pairs_hook=strict_object)
features = data.get("features")
if not isinstance(features, list) or index >= len(features) or features[index].get("id") != fid:
    print("verify-feature: feature list changed during verification", file=sys.stderr)
    raise SystemExit(65)
feature = features[index]
if feature.get("state") != "active":
    print("verify-feature: feature state changed during verification", file=sys.stderr)
    raise SystemExit(67)
feature["state"] = "passing"
feature.setdefault("evidence", []).append(f"all layers passed — commit {commit}, {stamp}")
data["last_updated"] = stamp[:10]
directory = os.path.dirname(os.path.abspath(path)) or "."
fd, tmp = tempfile.mkstemp(prefix=".feature-list-", dir=directory, text=True)
try:
    with os.fdopen(fd, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2, ensure_ascii=False)
        fh.write("\n")
    os.replace(tmp, path)
except BaseException:
    try: os.unlink(tmp)
    except FileNotFoundError: pass
    raise
PYEOF

echo ""
echo "${GREEN}${BOLD}$FEATURE_ID -> passing${RESET} (evidence recorded in $FL)"
echo "Next: update PROGRESS.md and commit."
