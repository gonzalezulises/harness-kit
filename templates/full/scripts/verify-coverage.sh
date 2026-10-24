#!/usr/bin/env bash
# verify-coverage.sh — no requirement ships without a real, non-vacuous check.
#
# Usage:
#   scripts/verify-coverage.sh [feature_list.json]
#
# Traceability gate: every feature must declare acceptance criteria
# (`verification`) and at least one layer whose command actually runs something.
# A layer that is empty or a no-op (`true`, `:`, `echo …`, `exit 0`) proves
# nothing — "100% passing" with zero requirements covered is what this catches.
#
# Exit codes:
#   0  every feature has a real verification
#   1  UNCOVERED_REQUIREMENT — no acceptance criteria or no layers
#   2  VACUOUS_ASSERTION     — the only verification is a no-op command
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

FL="${1:-feature_list.json}"
[[ -f "$FL" ]] || { echo "verify-coverage: $FL not found" >&2; exit 66; }

PY=""
for c in python3 python; do command -v "$c" >/dev/null 2>&1 && { PY="$c"; break; }; done
[[ -n "$PY" ]] || { echo "verify-coverage: needs python3" >&2; exit 69; }

"$PY" - "$FL" <<'PYEOF'
import json, sys, re
data = json.load(open(sys.argv[1]))
feats = data.get("features", [])
NOOP = re.compile(r'^\s*(true|:|exit\s+0|echo(\s.*)?)\s*$')

uncovered, vacuous = [], []
for f in feats:
    fid = f.get("id", "?")
    if not (f.get("verification") or []):
        uncovered.append(fid); continue
    layers = f.get("layers") or []
    if not layers:
        uncovered.append(fid); continue
    if all(NOOP.match(l.get("cmd", "") or "") for l in layers):
        vacuous.append(fid)

for fid in uncovered:
    print("UNCOVERED_REQUIREMENT: %s has no acceptance criteria or no verification layers" % fid)
for fid in vacuous:
    print("VACUOUS_ASSERTION: %s's verification layers are all no-ops (true/: /echo/exit 0)" % fid)

if uncovered:
    print("Fail-closed: %d requirement(s) with nothing to check." % len(uncovered))
    sys.exit(1)
if vacuous:
    print("Fail-closed: %d feature(s) whose check proves nothing." % len(vacuous))
    sys.exit(2)
print("verify-coverage: %d feature(s) each carry a real, non-vacuous verification." % len(feats))
sys.exit(0)
PYEOF
