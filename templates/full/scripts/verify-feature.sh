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
cd "$ROOT_DIR"

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
data["last_updated"] = stamp[:10]
with open(path, "w") as fh:
    json.dump(data, fh, indent=2, ensure_ascii=False)
    fh.write("\n")
PYEOF

echo ""
echo "${GREEN}${BOLD}$FEATURE_ID -> passing${RESET} (evidence recorded in $FL)"
echo "Next: update PROGRESS.md and commit."
