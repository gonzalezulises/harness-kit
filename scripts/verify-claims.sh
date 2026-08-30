#!/usr/bin/env bash
# verify-claims.sh — re-run every feature the repo claims is already passing.
#
# Usage:
#   scripts/verify-claims.sh
#
# verify-feature.sh is the gate an honest agent walks through. This is the gate
# nobody walks through voluntarily: it assumes every "passing" in feature_list.json
# is a claim until the layers behind it run again and agree.
#
# Run it in CI, on a runner the agent does not control. A state written by hand is
# a claim; a state that survives this is a receipt.
#
# Exit codes (fail-closed — only an observed green run exits 0):
#   0  every claim re-verified, or there were no claims (stated out loud)
#   1  FALSE_CLAIM     — a feature marked passing whose layers do not pass
#   2  NOT_VERIFIABLE  — a claim that cannot be checked at all (no layers, no evidence)
#   5  WEAKENED_VERIFICATION — a passing feature changed how it is verified
#  66  feature_list.json missing
#  69  no python available

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

# ── Was the verification itself weakened? ────────────────────────────────────
# This script is taken from the protected base, but the commands it runs come
# from the pull request. Re-running a layer proves nothing if the layer was
# swapped for `true` in the same change: the state stays `passing` and the
# receipt now certifies a command that does no work.
#
# So a feature that was already `passing` at the base and is still `passing` here
# must carry the same layers. Changing how something is verified invalidates the
# earlier receipt — set the feature back to `active` and earn it again.
WORK_CLAIMS="$(mktemp -d)"
trap 'rm -rf "$WORK_CLAIMS"' EXIT

BASE_FL=""
if [[ -n "${CLAIMS_BASE_FILE:-}" ]]; then
  # CI checks the head out at depth 1, so `git show <base>:FILE` cannot resolve.
  [[ -f "$CLAIMS_BASE_FILE" ]] && BASE_FL="$CLAIMS_BASE_FILE"
else
  for candidate in origin/main origin/master main master; do
    git rev-parse --verify --quiet "$candidate" >/dev/null 2>&1 || continue
    if git show "$candidate:$FL" > "$WORK_CLAIMS/base.json" 2>/dev/null; then
      BASE_FL="$WORK_CLAIMS/base.json"
    fi
    break
  done
fi

if [[ -n "$BASE_FL" ]]; then
  WEAKENED="$("$PY" - "$BASE_FL" "$FL" <<'PYEOF'
import json, sys

def passing_layers(path):
    try:
        data = json.load(open(path))
    except Exception:
        return {}
    out = {}
    for f in data.get("features", []):
        if f.get("state") == "passing":
            out[f.get("id")] = f.get("layers") or []
    return out

base, head = passing_layers(sys.argv[1]), passing_layers(sys.argv[2])
for fid, base_layers in base.items():
    if fid not in head:
        continue  # dropped, or moved back to active: both are legitimate
    if json.dumps(base_layers, sort_keys=True) == json.dumps(head[fid], sort_keys=True):
        continue
    was = " | ".join(l.get("cmd", "") for l in base_layers) or "(none)"
    now = " | ".join(l.get("cmd", "") for l in head[fid]) or "(none)"
    print("%s\t%s\t%s" % (fid, was, now))
PYEOF
)"

  if [[ -n "${WEAKENED//[$'\n'[:space:]]/}" ]]; then
    echo "${RED}${BOLD}WEAKENED_VERIFICATION${RESET}" >&2
    while IFS=$'\t' read -r fid was now; do
      [[ -z "$fid" ]] && continue
      echo "  ${BOLD}$fid${RESET} is still marked passing, but its verification changed." >&2
      echo "    was: $was" >&2
      echo "    now: $now" >&2
    done <<< "$WEAKENED"
    echo "" >&2
    echo "The recorded evidence certifies the command that ran at the time. Changing" >&2
    echo "the command invalidates it. Set the feature back to 'active' and re-run" >&2
    echo "scripts/verify-feature.sh so the new command earns its own receipt." >&2
    exit 5
  fi
fi

# ── Collect the claims ───────────────────────────────────────────────────────
# One line per claimed feature: id \t problem \t label \t cmd
# `problem` is OK, or names why the claim is unverifiable before anything runs.
# Every field carries a token: consecutive tabs collapse under IFS whitespace
# splitting, so an empty middle field would silently shift the columns left.
CLAIMS_TSV="$("$PY" - "$FL" <<'PYEOF'
import json, sys
data = json.load(open(sys.argv[1]))
for f in data.get("features", []):
    if f.get("state") != "passing":
        continue
    fid = f.get("id", "?")
    layers = f.get("layers") or []
    if not layers:
        print("%s\tNO_LAYERS\t-\t-" % fid); continue
    if not (f.get("evidence") or []):
        print("%s\tNO_EVIDENCE\t-\t-" % fid); continue
    for l in layers:
        label = (l.get("label") or "layer").replace("\t", " ")
        cmd = (l.get("cmd") or "").replace("\t", " ")
        print("%s\tOK\t%s\t%s" % (fid, label, cmd))
PYEOF
)"

if [[ -z "${CLAIMS_TSV//[$'\n'[:space:]]/}" ]]; then
  echo "${YELLOW}NO_CLAIMS${RESET} — no feature is marked passing, so there was nothing to re-verify."
  echo "This is not a pass: it means the repo claims nothing yet."
  exit 0
fi

# ── Re-run every claim ───────────────────────────────────────────────────────
echo "${BOLD}Re-verifying claimed features${RESET}"
CHECKED=0
FAILED=0
UNVERIFIABLE=0
LAST_ID=""

while IFS=$'\t' read -r fid problem label cmd; do
  [[ -z "$fid" ]] && continue

  if [[ "$problem" != "OK" ]]; then
    echo ""
    echo "${RED}${BOLD}NOT_VERIFIABLE${RESET} — $fid is marked passing but $problem."
    case "$problem" in
      NO_LAYERS)   echo "  A claim with no layers cannot be checked by anyone. Add layers or drop the claim." ;;
      NO_EVIDENCE) echo "  NO_EVIDENCE: passing requires recorded evidence. Re-run scripts/verify-feature.sh $fid." ;;
    esac
    UNVERIFIABLE=$((UNVERIFIABLE + 1))
    continue
  fi

  if [[ "$fid" != "$LAST_ID" ]]; then
    echo ""
    echo "${BOLD}── $fid${RESET}"
    CHECKED=$((CHECKED + 1))
    LAST_ID="$fid"
  fi

  if [[ -z "$cmd" ]]; then
    echo "  ${RED}layer '$label' has no command — a claim that runs nothing is not a claim.${RESET}"
    FAILED=$((FAILED + 1))
    continue
  fi

  # Subshell: a layer command calling `exit` must not take this script with it.
  # Output is captured rather than discarded: a failure whose reason you cannot
  # see is a failure you cannot act on, and in CI there is no way to re-run it by
  # hand. Only the tail is shown, so a passing run stays quiet.
  LAYER_LOG="$WORK_CLAIMS/layer.log"
  if ( eval "$cmd" >"$LAYER_LOG" 2>&1 ); then
    echo "  ${GREEN}ok${RESET}   $label"
  else
    echo "  ${RED}FAIL${RESET} $label  \$ $cmd"
    if [[ -s "$LAYER_LOG" ]]; then
      echo "  ${BOLD}last output:${RESET}"
      tail -15 "$LAYER_LOG" | sed 's/^/    /'
    else
      echo "    (the command produced no output)"
    fi
    FAILED=$((FAILED + 1))
  fi
done <<< "$CLAIMS_TSV"

# ── Verdict ──────────────────────────────────────────────────────────────────
echo ""
if [[ "$UNVERIFIABLE" -gt 0 ]]; then
  echo "${RED}${BOLD}NOT_VERIFIABLE: $UNVERIFIABLE claim(s) cannot be checked.${RESET}"
  echo "Fail-closed: an unverifiable claim is never a pass."
  exit 2
fi

if [[ "$FAILED" -gt 0 ]]; then
  echo "${RED}${BOLD}FALSE_CLAIM: $FAILED layer(s) failed across features marked passing.${RESET}"
  echo "Someone wrote 'passing' without the layers agreeing. Reset those features to"
  echo "active and re-run scripts/verify-feature.sh so the state becomes a receipt."
  exit 1
fi

# Sentinel: reaching this line with nothing actually executed would be a silent
# pass, which is the exact failure this script exists to prevent.
if [[ "$CHECKED" -eq 0 ]]; then
  echo "${RED}${BOLD}NOT_VERIFIABLE: claims were listed but none executed.${RESET}"
  exit 2
fi

echo "${GREEN}${BOLD}$CHECKED claimed feature(s) re-verified.${RESET} Every passing state is backed by a run."
exit 0
