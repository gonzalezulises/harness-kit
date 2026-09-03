#!/usr/bin/env bash
# verify-context-routes.sh — a change under governed paths must cite what governs it.
#
# ── The failure this exists to stop ──────────────────────────────────────────
# An external audit reported that a product fiche declared an impossible width.
# The finding was real. The fix implemented for it invented engineering
# tolerances — and `docs/DECISIONS.md` §D2 said, in as many words, that the
# comparator does not invent tolerances. The decision had been taken, written
# down, and was one grep away. It was never opened.
#
# Three more failures in that same session had the same shape: the right answer
# was already written in a file nobody read. `rules/fuentes.md` states the
# precedence in prose. Prose depends on the reader remembering to look, which is
# precisely what failed.
#
# So the map becomes mechanical. `.harness/context-routes.json` says: a change
# under THESE paths is governed by THOSE documents. Touch the paths, cite the
# documents — in a commit message on the branch, or in an Agent Note the change
# carries.
#
# Citing is weak proof of reading, and that is fine: the point is not the string.
# To write «DECISIONS.md §D2» you have to go find §D2, and going to find it is
# the whole intervention. Anyone determined to fake it can, and a harness that
# assumed otherwise would be lying about what it enforces.
#
# Usage:
#   bash scripts/verify-context-routes.sh          # gate: governed changes cite their sources
#   bash scripts/verify-context-routes.sh --list   # advisory: print the reading list, exit 0
#
# Config:
#   CONTEXT_ROUTES  route map          (default: .harness/context-routes.json)
#   ROUTES_BASE     ref to diff from   (default: merge-base with the default branch)
#
# Exit codes follow the runner's contract:
#   0  PASS            every governed change cites a governing document
#   1  FAIL            a governed change cites none
#   2  NOT_CONFIGURED  the route map is missing or malformed
#   3  TOOL_FAILURE    python3 unavailable
#   4  INCOMPLETE      the diff could not be determined — nothing was verified

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR" || exit 3

MAP="${CONTEXT_ROUTES:-.harness/context-routes.json}"
MODE="${1:-gate}"

if [[ ! -t 1 ]] || [[ -n "${NO_COLOR:-}" ]]; then
  RED=""; GREEN=""; YELLOW=""; RESET=""
else
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
  RESET=$'\033[0m'
fi

command -v python3 >/dev/null 2>&1 || { echo "${RED}context-routes: needs python3${RESET}" >&2; exit 3; }

if [[ ! -f "$MAP" ]]; then
  echo "${RED}context-routes: $MAP not found${RESET}" >&2
  echo "  Without a route map this gate cannot know what governs what." >&2
  exit 2
fi

# ── The map is validated before anything else ───────────────────────────────
# It used to be parsed only once a diff existed, so on a commit with nothing
# governed a corrupt map reported PASS. A broken configuration would then sit
# unnoticed until the first governed change — the moment it is needed most.
# Config validation runs always (V2 §12.5).
if ! MAP="$MAP" python3 - <<'VALIDATE'
import json, os, sys
try:
    with open(os.environ["MAP"], encoding="utf-8") as fh:
        cfg = json.load(fh)
except (json.JSONDecodeError, OSError) as exc:
    print(f"context-routes: {os.environ['MAP']} is not readable JSON: {exc}", file=sys.stderr)
    sys.exit(2)
routes = cfg.get("routes")
if not isinstance(routes, list) or not routes:
    print(f"context-routes: {os.environ['MAP']} declares no routes", file=sys.stderr)
    sys.exit(2)
for idx, route in enumerate(routes):
    if not (route.get("paths") and route.get("read")):
        print(f"context-routes: route #{idx} needs both «paths» and «read»", file=sys.stderr)
        sys.exit(2)
VALIDATE
then
  exit 2
fi

# ── Which ref to compare against ────────────────────────────────────────────
# A base that cannot be resolved must stop the run, never report a clean diff:
# "no governed changes" and "could not see the changes" are different answers,
# and only one of them is good news.
BASE="${ROUTES_BASE:-}"
if [[ -z "$BASE" ]]; then
  for candidate in origin/main origin/master main master; do
    if git rev-parse --verify --quiet "$candidate" >/dev/null 2>&1; then
      BASE="$(git merge-base HEAD "$candidate" 2>/dev/null || true)"
      [[ -n "$BASE" ]] && break
    fi
  done
fi
if [[ -z "$BASE" ]]; then
  echo "${YELLOW}context-routes: no base ref to diff against${RESET}" >&2
  echo "  Set ROUTES_BASE. Nothing was verified — this is not a pass." >&2
  exit 4
fi
if ! git rev-parse --verify --quiet "$BASE" >/dev/null 2>&1; then
  echo "${RED}context-routes: ROUTES_BASE «${BASE}» is not a ref here${RESET}" >&2
  exit 2
fi

CHANGED="$(git diff --name-only "$BASE"..HEAD 2>/dev/null)"
# On the base commit itself there is no branch work in flight. That is a real
# clean answer, not a missing one.
if [[ -z "$CHANGED" ]]; then
  echo "${GREEN}context-routes: no changes against ${BASE:0:8} — nothing to govern${RESET}"
  exit 0
fi

# What the change says about itself: commit subjects and bodies on the branch,
# plus the full text of any Agent Note it touches.
EVIDENCE="$(git log --format='%B' "$BASE"..HEAD 2>/dev/null)"
while IFS= read -r f; do
  [[ -n "$f" && -f "$f" ]] || continue
  case "$f" in
    *.agents/notes/*|*AGENT-NOTE*|*agent-note*) EVIDENCE="$EVIDENCE
$(cat "$f")" ;;
  esac
done <<<"$CHANGED"

export MAP MODE CHANGED EVIDENCE
python3 - <<'PY'
import fnmatch, json, os, sys

map_path = os.environ["MAP"]
mode = os.environ["MODE"]
changed = [p for p in os.environ["CHANGED"].splitlines() if p.strip()]
evidence = os.environ["EVIDENCE"]

try:
    with open(map_path, encoding="utf-8") as fh:
        cfg = json.load(fh)
except (json.JSONDecodeError, OSError) as exc:
    print(f"context-routes: {map_path} is not readable JSON: {exc}", file=sys.stderr)
    sys.exit(2)

routes = cfg.get("routes")
if not isinstance(routes, list) or not routes:
    print(f"context-routes: {map_path} declares no routes", file=sys.stderr)
    sys.exit(2)

def matches(path, pattern):
    # «lib/rules/**» must cover lib/rules/a.ts and lib/rules/deep/b.ts alike;
    # fnmatch alone treats * as crossing separators, so normalise the intent.
    if pattern.endswith("/**"):
        return path == pattern[:-3] or path.startswith(pattern[:-2])
    return fnmatch.fnmatch(path, pattern)

triggered = []
for idx, route in enumerate(routes):
    paths = route.get("paths") or []
    read = route.get("read") or []
    if not paths or not read:
        print(f"context-routes: route #{idx} needs both «paths» and «read»", file=sys.stderr)
        sys.exit(2)
    hits = [p for p in changed for pat in paths if matches(p, pat)]
    if hits:
        triggered.append((route, sorted(set(hits))))

if not triggered:
    print("context-routes: this change touches no governed path")
    sys.exit(0)

if mode == "--list":
    print("Read these before changing what this diff changes:\n")
    for route, hits in triggered:
        why = route.get("why", "")
        print(f"  because it touches: {', '.join(hits[:4])}{' …' if len(hits) > 4 else ''}")
        if why:
            print(f"  {why}")
        for doc in route["read"]:
            print(f"    · {doc}")
        print()
    sys.exit(0)

# A citation is the document's own name appearing in what the change says about
# itself. Basename too: «RULES_ENGINE.md §1» is how a person cites it.
def cited(doc):
    return doc in evidence or os.path.basename(doc) in evidence

uncited = []
for route, hits in triggered:
    if not any(cited(d) for d in route["read"]):
        uncited.append((route, hits))

for route, hits in triggered:
    shown = ", ".join(hits[:3]) + (" …" if len(hits) > 3 else "")
    state = "cites" if not any(r is route for r, _ in uncited) else "CITES NOTHING"
    print(f"  {state:14s} {shown}")

if not uncited:
    print("\ncontext-routes: every governed change cites a governing document")
    sys.exit(0)

sys.stdout.flush()  # or the report lands after the diagnosis it explains
print("", file=sys.stderr)
for route, hits in uncited:
    print("context-routes: this change is governed by documents it never mentions.", file=sys.stderr)
    print(f"  changed: {', '.join(hits[:6])}", file=sys.stderr)
    if route.get("why"):
        print(f"  {route['why']}", file=sys.stderr)
    print("  read, then cite whichever one settles it:", file=sys.stderr)
    for doc in route["read"]:
        print(f"    · {doc}", file=sys.stderr)
    print("", file=sys.stderr)
print("Cite it in a commit message on this branch or in the Agent Note the change carries.", file=sys.stderr)
print("If a document forbids what you are doing, it does not stop being in force because", file=sys.stderr)
print("the change looks obviously right — amend it, with an owner and a date, or comply.", file=sys.stderr)
sys.exit(1)
PY
