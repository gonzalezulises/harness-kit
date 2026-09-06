#!/usr/bin/env bash
# verify-claims.sh — re-run every feature the repo claims is passing.
# Exit: 0 verified/no claims, 1 false claim, 2 invalid/unverifiable contract,
# 3 tool failure, 5 changed verification, 66 missing feature list, 69 no Python.

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR" || { echo "cannot cd to $ROOT_DIR" >&2; exit 66; }
FL="feature_list.json"
[[ -f "$FL" ]] || { echo "verify-claims: $FL not found in $ROOT_DIR" >&2; exit 66; }

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
[[ -n "$PY" ]] || { echo "verify-claims: needs python3" >&2; exit 69; }

WORK_CLAIMS="$(mktemp -d)"
trap 'rm -rf "$WORK_CLAIMS"' EXIT

# Parse and validate the whole head before emitting any executable record.
"$PY" - "$FL" "$WORK_CLAIMS/head" <<'PYEOF'
import json, sys
from pathlib import Path

path, output = sys.argv[1:3]
output = Path(output)
output.mkdir()

def strict_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result: raise ValueError("duplicate object key: " + key)
        result[key] = value
    return result

def safe_text(value, where, *, nonempty=False):
    if not isinstance(value, str) or "\0" in value or (nonempty and not value.strip()):
        reject(where + (" must be a non-empty NUL-free string" if nonempty else " must be a NUL-free string"))

def reject(message):
    print("verify-claims: INVALID_FEATURE_LIST — " + message, file=sys.stderr)
    raise SystemExit(2)

try:
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh, object_pairs_hook=strict_object)
except (OSError, UnicodeError, json.JSONDecodeError, ValueError) as exc:
    reject(str(exc))
if not isinstance(data, dict): reject("root must be an object")
features = data.get("features")
if not isinstance(features, list): reject("features must be an array")
states, ids = {"not_started", "active", "blocked", "passing"}, set()
passing = []
for i, feature in enumerate(features):
    where = f"features[{i}]"
    if not isinstance(feature, dict): reject(where + " must be an object")
    fid = feature.get("id")
    safe_text(fid, where + ".id", nonempty=True)
    if fid in ids: reject("duplicate feature id: " + fid)
    ids.add(fid)
    if feature.get("state") not in states: reject(where + ".state is unknown")
    evidence = feature.get("evidence", [])
    if not isinstance(evidence, list) or any(not isinstance(v, str) for v in evidence):
        reject(where + ".evidence must be an array of strings")
    layers = feature.get("layers", [])
    if not isinstance(layers, list): reject(where + ".layers must be an array")
    for j, layer in enumerate(layers):
        lw = f"{where}.layers[{j}]"
        if not isinstance(layer, dict): reject(lw + " must be an object")
        safe_text(layer.get("label", "layer"), lw + ".label", nonempty=True)
        safe_text(layer.get("cmd"), lw + ".cmd", nonempty=True)
        safe_text(layer.get("repair", "No repair guidance recorded."), lw + ".repair")
    budgets = feature.get("budgets")
    if budgets is not None:
        if not isinstance(budgets, dict): reject(where + ".budgets must be an object")
        stop_condition = budgets.get("stop_condition")
        if not isinstance(stop_condition, str) or "\0" in stop_condition or not stop_condition.strip():
            reject(where + ".budgets.stop_condition must be a non-empty NUL-free string")
        for key in ("review_rounds_max", "repeated_blocker_max"):
            if key in budgets:
                value = budgets[key]
                if isinstance(value, bool) or not isinstance(value, int) or value < 0:
                    reject(f"{where}.budgets.{key} must be a non-negative integer")
    if "ledger" in feature:
        ledger = feature["ledger"]
        if not isinstance(ledger, dict) or not {"review_rounds", "blockers"} <= set(ledger):
            reject(where + ".ledger must contain review_rounds and blockers")
        rounds, blockers = ledger["review_rounds"], ledger["blockers"]
        if isinstance(rounds, bool) or not isinstance(rounds, int) or rounds < 0:
            reject(where + ".ledger.review_rounds must be a non-negative integer")
        if not isinstance(blockers, list): reject(where + ".ledger.blockers must be an array")
        signatures = set()
        blocker_total = 0
        for j, blocker in enumerate(blockers):
            bw = f"{where}.ledger.blockers[{j}]"
            if not isinstance(blocker, dict): reject(bw + " must be an object")
            signature, count = blocker.get("signature"), blocker.get("count")
            if not isinstance(signature, str) or "\0" in signature or not signature.strip(): reject(bw + ".signature must be non-empty and NUL-free")
            if signature in signatures: reject(where + ".ledger has duplicate blocker signatures")
            signatures.add(signature)
            if isinstance(count, bool) or not isinstance(count, int) or count < 1:
                reject(bw + ".count must be a positive integer")
            blocker_total += count
        if blocker_total != rounds:
            reject(where + ".ledger review_rounds must equal the recorded blocker count")
    if feature["state"] == "passing": passing.append(feature)

(output / "claim-count").write_text(str(len(passing)), encoding="utf-8")
for i, feature in enumerate(passing):
    record = output / f"claim-{i:06d}"
    record.mkdir()
    (record / "id").write_text(feature["id"], encoding="utf-8")
    layers = feature.get("layers", [])
    problem = "NO_LAYERS" if not layers else ("NO_EVIDENCE" if not feature.get("evidence") else "OK")
    (record / "problem").write_text(problem, encoding="utf-8")
    (record / "layer-count").write_text(str(len(layers) if problem == "OK" else 0), encoding="utf-8")
    if problem == "OK":
        for j, layer in enumerate(layers):
            layer_record = record / f"layer-{j:06d}"
            layer_record.mkdir()
            (layer_record / "label").write_text(layer.get("label", "layer"), encoding="utf-8")
            (layer_record / "cmd").write_text(layer["cmd"], encoding="utf-8")
PYEOF
HEAD_RC=$?
[[ "$HEAD_RC" -eq 0 ]] || exit "$HEAD_RC"

# Resolve authority. An explicitly declared source must be readable and valid.
# A bootstrap without a base is allowed only when a resolved commit proves the
# feature list did not exist there.
BASE_FL=""
BASE_LABEL=""
if [[ -n "${CLAIMS_BASE_FILE:-}" ]]; then
  [[ -f "$CLAIMS_BASE_FILE" ]] || {
    echo "${RED}verify-claims: declared authority file is missing: $CLAIMS_BASE_FILE${RESET}" >&2
    exit 2
  }
  BASE_FL="$CLAIMS_BASE_FILE"
  BASE_LABEL="$CLAIMS_BASE_FILE"
else
  for candidate in origin/main origin/master main master; do
    git rev-parse --verify --quiet "$candidate^{commit}" >/dev/null 2>&1 || continue
    BASE_LABEL="$candidate"
    TREE_RESULT="$(git ls-tree -r --name-only "$candidate" -- "$FL" 2>/dev/null)"
    TREE_RC=$?
    [[ "$TREE_RC" -eq 0 ]] || {
      echo "verify-claims: could not read authority tree at $candidate" >&2; exit 3; }
    if [[ "$TREE_RESULT" == "$FL" ]]; then
      git show "$candidate:$FL" > "$WORK_CLAIMS/base.json" 2>/dev/null || {
        echo "verify-claims: could not read $FL at $candidate" >&2; exit 3; }
      BASE_FL="$WORK_CLAIMS/base.json"
    fi
    break
  done
  [[ -n "$BASE_LABEL" ]] || {
    echo "verify-claims: no authority base found; configure CLAIMS_BASE_FILE or a main ref" >&2
    exit 2
  }
fi

if [[ -n "$BASE_FL" ]]; then
  "$PY" - "$BASE_FL" "$FL" <<'PYEOF'
import json, sys

def strict_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result: raise ValueError("duplicate object key: " + key)
        result[key] = value
    return result

def load(path, role):
    try:
        with open(path, encoding="utf-8") as fh: data = json.load(fh, object_pairs_hook=strict_object)
    except (OSError, UnicodeError, json.JSONDecodeError, ValueError) as exc:
        print(f"verify-claims: invalid {role} authority: {exc}", file=sys.stderr); raise SystemExit(2)
    if not isinstance(data, dict) or not isinstance(data.get("features"), list):
        print(f"verify-claims: invalid {role} authority feature list shape", file=sys.stderr); raise SystemExit(2)
    ids = set()
    for i, feature in enumerate(data["features"]):
        where = f"{role}.features[{i}]"
        if not isinstance(feature, dict):
            print(f"verify-claims: invalid {where}", file=sys.stderr); raise SystemExit(2)
        fid = feature.get("id")
        if not isinstance(fid, str) or "\0" in fid or not fid.strip() or fid in ids:
            print(f"verify-claims: invalid or duplicate id in {role}", file=sys.stderr); raise SystemExit(2)
        ids.add(fid)
        if feature.get("state") not in {"not_started", "active", "blocked", "passing"}:
            print(f"verify-claims: invalid state in {role}", file=sys.stderr); raise SystemExit(2)
        evidence = feature.get("evidence", [])
        if not isinstance(evidence, list) or any(not isinstance(v, str) for v in evidence):
            print(f"verify-claims: invalid evidence in {where}", file=sys.stderr); raise SystemExit(2)
        layers = feature.get("layers", [])
        if not isinstance(layers, list):
            print(f"verify-claims: invalid layers in {role}", file=sys.stderr); raise SystemExit(2)
        for j, layer in enumerate(layers):
            if (not isinstance(layer, dict)
                    or not isinstance(layer.get("label", "layer"), str)
                    or "\0" in layer.get("label", "layer")
                    or not layer.get("label", "layer").strip()
                    or not isinstance(layer.get("cmd"), str)
                    or "\0" in layer.get("cmd", "")
                    or not layer["cmd"].strip()
                    or not isinstance(layer.get("repair", "No repair guidance recorded."), str)
                    or "\0" in layer.get("repair", "No repair guidance recorded.")):
                print(f"verify-claims: invalid layer command in {role}", file=sys.stderr); raise SystemExit(2)
        budgets = feature.get("budgets")
        if budgets is not None:
            if (not isinstance(budgets, dict)
                    or not isinstance(budgets.get("stop_condition"), str)
                    or "\0" in budgets.get("stop_condition", "")
                    or not budgets["stop_condition"].strip()):
                print(f"verify-claims: invalid budgets in {where}", file=sys.stderr); raise SystemExit(2)
            for key in ("review_rounds_max", "repeated_blocker_max"):
                if key in budgets:
                    value = budgets[key]
                    if isinstance(value, bool) or not isinstance(value, int) or value < 0:
                        print(f"verify-claims: invalid {key} in {where}", file=sys.stderr); raise SystemExit(2)
        if "ledger" in feature:
            ledger = feature["ledger"]
            if not isinstance(ledger, dict) or not {"review_rounds", "blockers"} <= set(ledger):
                print(f"verify-claims: invalid ledger in {where}", file=sys.stderr); raise SystemExit(2)
            rounds, blockers = ledger["review_rounds"], ledger["blockers"]
            if isinstance(rounds, bool) or not isinstance(rounds, int) or rounds < 0 or not isinstance(blockers, list):
                print(f"verify-claims: invalid ledger in {where}", file=sys.stderr); raise SystemExit(2)
            signatures = set()
            blocker_total = 0
            for blocker in blockers:
                if not isinstance(blocker, dict):
                    print(f"verify-claims: invalid blocker in {where}", file=sys.stderr); raise SystemExit(2)
                signature, count = blocker.get("signature"), blocker.get("count")
                if (not isinstance(signature, str) or "\0" in signature or not signature.strip() or signature in signatures
                        or isinstance(count, bool) or not isinstance(count, int) or count < 1):
                    print(f"verify-claims: invalid blocker in {where}", file=sys.stderr); raise SystemExit(2)
                signatures.add(signature)
                blocker_total += count
            if blocker_total != rounds:
                print(f"verify-claims: inconsistent ledger in {where}", file=sys.stderr); raise SystemExit(2)
    return data

base, head = load(sys.argv[1], "base"), load(sys.argv[2], "head")
base_passing = {f["id"]: f.get("layers", []) for f in base["features"] if f["state"] == "passing"}
head_passing = {f["id"]: f.get("layers", []) for f in head["features"] if f["state"] == "passing"}
changed = []
for fid, layers in base_passing.items():
    if fid in head_passing and layers != head_passing[fid]:
        changed.append((fid, layers, head_passing[fid]))
if changed:
    print("WEAKENED_VERIFICATION", file=sys.stderr)
    for fid, old, new in changed:
        was = " | ".join(str(v.get("cmd", "")) for v in old) or "(none)"
        now = " | ".join(str(v.get("cmd", "")) for v in new) or "(none)"
        print(f"  {fid} is still marked passing, but its verification changed.", file=sys.stderr)
        print("    was: " + was, file=sys.stderr)
        print("    now: " + now, file=sys.stderr)
    raise SystemExit(5)
PYEOF
  AUTHORITY_RC=$?
  [[ "$AUTHORITY_RC" -eq 0 ]] || exit "$AUTHORITY_RC"
fi

CLAIM_COUNT="$(cat "$WORK_CLAIMS/head/claim-count")"
if [[ "$CLAIM_COUNT" -eq 0 ]]; then
  echo "${YELLOW}NO_CLAIMS${RESET} — no feature is marked passing, so there was nothing to re-verify."
  echo "This is not a pass: it means the repo claims nothing yet."
  exit 0
fi

echo "${BOLD}Re-verifying claimed features${RESET}"
CHECKED=0
FAILED=0
UNVERIFIABLE=0
for ((i=0; i<CLAIM_COUNT; i++)); do
  record="$WORK_CLAIMS/head/claim-$(printf '%06d' "$i")"
  fid="$(cat "$record/id"; printf x)"; fid="${fid%x}"
  problem="$(cat "$record/problem")"
  if [[ "$problem" != "OK" ]]; then
    echo ""
    echo "${RED}${BOLD}NOT_VERIFIABLE${RESET} — $fid is marked passing but $problem."
    UNVERIFIABLE=$((UNVERIFIABLE + 1))
    continue
  fi
  echo ""
  echo "${BOLD}── $fid${RESET}"
  CHECKED=$((CHECKED + 1))
  layer_count="$(cat "$record/layer-count")"
  for ((j=0; j<layer_count; j++)); do
    layer="$record/layer-$(printf '%06d' "$j")"
    label="$(cat "$layer/label"; printf x)"; label="${label%x}"
    cmd="$(cat "$layer/cmd"; printf x)"; cmd="${cmd%x}"
    log="$WORK_CLAIMS/claim-$i-layer-$j.log"
    ( eval "$cmd" >"$log" 2>&1 )
    rc=$?
    if [[ "$rc" -eq 0 ]]; then
      echo "  ${GREEN}ok${RESET}   $label"
    else
      echo "  ${RED}FAIL${RESET} $label  \$ $cmd"
      if [[ -s "$log" ]]; then
        echo "  ${BOLD}last output:${RESET}"
        tail -15 "$log" | sed 's/^/    /'
      else
        echo "    (the command produced no output)"
      fi
      FAILED=$((FAILED + 1))
    fi
  done
done

echo ""
if [[ "$UNVERIFIABLE" -gt 0 ]]; then
  echo "${RED}${BOLD}NOT_VERIFIABLE: $UNVERIFIABLE claim(s) cannot be checked.${RESET}"
  echo "Fail-closed: an unverifiable claim is never a pass."
  exit 2
fi
if [[ "$FAILED" -gt 0 ]]; then
  echo "${RED}${BOLD}FALSE_CLAIM: $FAILED layer(s) failed across features marked passing.${RESET}"
  echo "Reset those features to active and re-run scripts/verify-feature.sh."
  exit 1
fi
if [[ "$CHECKED" -eq 0 ]]; then
  echo "${RED}${BOLD}NOT_VERIFIABLE: claims were listed but none executed.${RESET}"
  exit 2
fi
echo "${GREEN}${BOLD}$CHECKED claimed feature(s) re-verified.${RESET} Every passing state is backed by a run."
exit 0
