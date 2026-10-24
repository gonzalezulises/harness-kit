#!/usr/bin/env bash
# gen-feature-list.sh — derive feature_list.json from the executable specification.
#
# Usage:
#   scripts/gen-feature-list.sh [--dir features] [--out feature_list.json] [--dry-run]
#
# The spec is the source of truth; the state is DERIVED from it. Each Gherkin
# scenario becomes a feature entry whose verification is `bin/gherkin-check
# --expect N` — the absolute counter that fails when scenarios silently drop.
# Existing states are preserved so regeneration never resets progress. With no
# features/ directory it is a no-op that says so, rather than guessing.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SPEC_DIR="features"
OUT="feature_list.json"
DRYRUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)      SPEC_DIR="${2:-features}"; shift 2 ;;
    --out)      OUT="${2:-feature_list.json}"; shift 2 ;;
    --dry-run)  DRYRUN=1; shift ;;
    -h|--help)  sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 64 ;;
  esac
done

PY=""
for c in python3 python; do command -v "$c" >/dev/null 2>&1 && { PY="$c"; break; }; done
[[ -n "$PY" ]] || { echo "gen-feature-list: needs python3" >&2; exit 69; }

if [[ ! -d "$SPEC_DIR" ]]; then
  echo "gen-feature-list: no '$SPEC_DIR/' directory — write Gherkin .feature specs"
  echo "first, or keep the hand-maintained feature_list.json."
  exit 0
fi

SPEC_DIR="$SPEC_DIR" OUT="$OUT" DRYRUN="$DRYRUN" "$PY" - <<'PYEOF'
import sys, glob, re, json, os, datetime
spec_dir = os.environ["SPEC_DIR"]
out = os.environ["OUT"]
dryrun = os.environ["DRYRUN"] == "1"

scenarios = []
paths = sorted(set(glob.glob(spec_dir + "/*.feature")) | set(glob.glob(spec_dir + "/**/*.feature", recursive=True)))
for path in paths:
    text = open(path, encoding="utf-8").read()
    for m in re.finditer(r'^\s*Scenario(?: Outline)?:\s*(.+)$', text, re.M):
        scenarios.append(m.group(1).strip())

if not scenarios:
    print("gen-feature-list: no scenarios found under '%s/'. Nothing to derive." % spec_dir)
    sys.exit(0)

if dryrun:
    print("gen-feature-list: would derive %d scenario(s) from '%s/' into %s." % (len(scenarios), spec_dir, out))
    sys.exit(0)

old = {}
if os.path.exists(out):
    try:
        for f in json.load(open(out)).get("features", []):
            old[f.get("id")] = f.get("state", "not_started")
    except Exception:
        pass

expect = len(scenarios)
features = []
for i, title in enumerate(scenarios, 1):
    fid = "F%02d" % i
    features.append({
        "id": fid, "priority": i, "area": "spec", "behavior": title,
        "state": old.get(fid, "not_started"),
        "verification": ["bin/gherkin-check --expect %d" % expect],
        "layers": [{"label": "gherkin", "cmd": "bin/gherkin-check --expect %d" % expect,
                    "repair": "ZERO_EXECUTION means the runner found no scenarios; check the features/ path and import config before touching steps."}],
        "evidence": [],
    })

data = {"project": os.path.basename(os.getcwd()),
        "last_updated": datetime.date.today().isoformat(),
        "features": features}
with open(out, "w") as fh:
    json.dump(data, fh, indent=2, ensure_ascii=False)
    fh.write("\n")
print("gen-feature-list: derived %d feature(s) from '%s/' into %s (existing states preserved)."
      % (len(features), spec_dir, out))
PYEOF
