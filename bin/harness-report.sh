#!/usr/bin/env bash
# harness-report.sh — the outcome metrics the structure score cannot produce.
#
# Usage:
#   bin/harness-report.sh [repo-path] [--json]
#
# Aggregates, per repo, the numbers that answer "is this harness improving the
# software?" rather than "does the repo have the files?":
#   requirement_coverage  — features with a real, non-vacuous verification layer
#   verified completion   — passing / (active + claimed + passing)
#   false-claim share     — passing/claimed features whose check proves nothing
#
# It is read-only and always exits 0: it reports, it never blocks.
set -uo pipefail

REPO="${1:-.}"
cd "$REPO" 2>/dev/null || { echo "harness-report: cannot cd to $REPO" >&2; exit 66; }

PY=""
for c in python3 python; do command -v "$c" >/dev/null 2>&1 && { PY="$c"; break; }; done
[[ -n "$PY" ]] || { echo "harness-report: needs python3" >&2; exit 69; }

AS_JSON=0
[[ "${2:-}" == "--json" ]] && AS_JSON=1

"$PY" - "$AS_JSON" <<'PYEOF'
import json, sys, os, re
as_json = sys.argv[1] == "1"

fl = {}
if os.path.exists("feature_list.json"):
    try: fl = json.load(open("feature_list.json"))
    except Exception: pass
feats = fl.get("features", [])

NOOP = re.compile(r'^\s*(true|:|exit\s+0|echo(\s.*)?)\s*$')

def real(layers):
    cmds = [l.get("cmd", "") or "" for l in (layers or [])]
    return any(c.strip() and not NOOP.match(c) for c in cmds)

covered = sum(1 for f in feats if real(f.get("layers")))
claimed = sum(1 for f in feats if f.get("state") == "claimed")
passing = sum(1 for f in feats if f.get("state") == "passing")
active  = sum(1 for f in feats if f.get("state") == "active")
blocked = sum(1 for f in feats if f.get("state") == "blocked")
activated = active + claimed + passing

# A "false claim" here: a feature marked passing/claimed whose only verification
# is a no-op — it claims proof its check cannot produce. CI's verify-claims.sh is
# the authoritative re-run; this is the static, always-cheap proxy for it.
false_claims = sum(1 for f in feats if f.get("state") in ("passing", "claimed") and not real(f.get("layers")))

report = {
    "repo": os.path.basename(os.getcwd()),
    "features": len(feats),
    "requirement_coverage": covered,
    "requirement_coverage_ratio": round(covered / len(feats), 3) if feats else None,
    "state": {"active": active, "claimed": claimed, "passing": passing, "blocked": blocked},
    "verified_completion_ratio": round(passing / activated, 3) if activated else None,
    "false_claim_share": round(false_claims / (claimed + passing), 3) if (claimed + passing) else None,
}

if as_json:
    print(json.dumps(report, indent=2, ensure_ascii=False))
else:
    print("harness-report for %s" % report["repo"])
    print("  features:             %d" % report["features"])
    if report["requirement_coverage_ratio"] is not None:
        print("  requirement coverage: %d/%d (%.0f%%)" % (covered, len(feats), 100 * report["requirement_coverage_ratio"]))
    print("  states:               active=%d claimed=%d passing=%d blocked=%d" % (active, claimed, passing, blocked))
    if report["verified_completion_ratio"] is not None:
        print("  verified completion:  %.0f%%" % (100 * report["verified_completion_ratio"]))
    if report["false_claim_share"] is not None:
        print("  false-claim share:    %.0f%%" % (100 * report["false_claim_share"]))
PYEOF
