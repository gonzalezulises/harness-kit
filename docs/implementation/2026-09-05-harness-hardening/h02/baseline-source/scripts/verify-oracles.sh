#!/usr/bin/env bash
# verify-oracles.sh — a critical criterion needs an oracle, and the oracle needs
# proof it can fail.
#
# ── What this is for ─────────────────────────────────────────────────────────
# AGENTS.md already says it: "una prueba que solo se ha visto pasar no cuenta:
# hay que verla fallar contra el estado defectuoso." It has been a convention,
# which means it held exactly as long as someone remembered it.
#
# The failure that made it worth a gate: a rule was fixed so a supplier list
# reading «8D/D6» matched an «8D» catalogue entry. Unit tests green, full suite
# green, reasoning sound. Then the same rule was run over the live catalogue and
# one line matched two products of opposite polarity — a battery cannot have its
# terminals on both sides. The tests only knew the cases their author imagined,
# and their author was the one who got it wrong.
#
# ── Why the eight questions are not the gate ─────────────────────────────────
# The V2 spec (§9.3) asks eight questions before production code is written, and
# they are good questions: an invented tolerance does not survive «who may change
# this oracle?» — nobody owns numbers nobody agreed to. But eight prose answers
# can be written plausibly without doing any of the work, and a gate that only
# counts filled fields teaches people to fill fields.
#
# So the prose is checked for presence, and one field is checked for truth:
# `falsification`. It records the defect that must make the test fail, and the
# commit at which someone watched it fail. If the test has been edited since that
# commit, the proof no longer covers the test that exists, and the criterion goes
# STALE — the one state this harness exists to stop being read as green.
#
# That check is mechanical, cheap, and not fakeable by accident. It is fakeable
# on purpose, by pasting a SHA. Nothing here pretends otherwise: the gate makes
# the honest path the easy one, it does not make dishonesty impossible.
#
# Usage:
#   bash scripts/verify-oracles.sh
#   bash scripts/verify-oracles.sh --list   # what is DRAFT, what is stale
#
# Config:
#   ORACLES_DIR  where oracles live (default: .harness/oracles)
#
# Exit codes follow the runner's contract:
#   0  PASS            every critical criterion is TEST_READY with a live proof
#   1  FAIL            a criterion is incomplete, or its proof is stale
#   2  NOT_CONFIGURED  an oracle file is malformed
#   3  TOOL_FAILURE    python3 unavailable

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR" || exit 3

DIR="${ORACLES_DIR:-.harness/oracles}"
MODE="${1:-gate}"

if [[ ! -t 1 ]] || [[ -n "${NO_COLOR:-}" ]]; then
  RED=""; GREEN=""; RESET=""
else
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; RESET=$'\033[0m'
fi

command -v python3 >/dev/null 2>&1 || { echo "${RED}oracles: needs python3${RESET}" >&2; exit 3; }

# No oracles yet is a real, honest answer: this gate arrives before the criteria
# do, and a repo that has written none has nothing to be stale about.
if [[ ! -d "$DIR" ]] || ! find "$DIR" -name '*.yaml' -o -name '*.yml' 2>/dev/null | grep -q .; then
  echo "${GREEN}oracles: none declared in $DIR${RESET}"
  echo "  Write one when a criterion is critical enough that getting it wrong ships harm."
  exit 0
fi

# The eight questions of V2 §9.3, as the fields that answer them.
export DIR MODE
python3 - <<'PY'
import os, re, subprocess, sys, traceback
from pathlib import Path

def _crash(exc_type, exc, tb):
    # An unexpected crash is TOOL_FAILURE, not FAIL: the gate broke, the code did
    # not. Letting a traceback exit 1 would tell someone to go fix their code.
    traceback.print_exception(exc_type, exc, tb)
    print("oracles: the gate itself failed — this is not a verdict on the code",
          file=sys.stderr)
    sys.exit(3)

sys.excepthook = _crash

DIR = Path(os.environ["DIR"])
MODE = os.environ["MODE"]

# The eight questions, and the field that answers each one. Kept together so the
# error message can quote the question, not the field name — the question is what
# does the work.
QUESTIONS = [
    ("observable",     "1. What observable behaviour demonstrates compliance?"),
    ("oracle",         "2. What is the expected oracle?"),
    ("cases",          "3. Which positive, negative and boundary cases are required?"),
    ("context",        "4. Which actor, state and initial data are involved?"),
    ("side_effects",   "5. Which side effects must happen, and which must not?"),
    ("false_positive", "6. How would a false positive be detected?"),
    ("owner",          "7. Who may change this oracle?"),
    ("evidence",       "8. What evidence does it produce?"),
]
PLACEHOLDERS = re.compile(r"^\s*(tbd|todo|t\.b\.d\.|xxx|\?+|pending|por definir|-{1,3})\s*$", re.I)

def load_yaml(path):
    """Minimal reader for the flat-ish shape these files use.

    A YAML dependency would be one more thing to install before a gate can run,
    and a gate nobody can run is not a gate. The accepted shape is documented in
    the schema: scalars, lists of scalars, and one level of nesting.
    """
    data = {}
    stack = [(0, data)]
    for raw in path.read_text(encoding="utf-8").splitlines():
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        indent = len(raw) - len(raw.lstrip())
        line = raw.strip()
        while len(stack) > 1 and indent <= stack[-1][0]:
            stack.pop()
        node = stack[-1][1]
        if line.startswith("- "):
            node.setdefault("__list__", []).append(line[2:].strip().strip("\"'"))
            continue
        if ":" not in line:
            continue
        key, _, val = line.partition(":")
        key, val = key.strip(), val.strip().strip("\"'")
        if val:
            node[key] = val
        else:
            child = {}
            node[key] = child
            stack.append((indent, child))
    return data

def flatten(v):
    """A field answers its question if it holds anything real, at any depth."""
    if isinstance(v, dict):
        out = []
        for k, sub in v.items():
            if k == "__list__":
                out.extend(sub)
            else:
                out.extend(flatten(sub))
        return out
    return [str(v)] if v is not None else []

def answered(v):
    vals = [s for s in flatten(v) if s.strip()]
    return bool(vals) and not all(PLACEHOLDERS.match(s) for s in vals)

def last_commit_touching(path):
    r = subprocess.run(["git", "log", "-1", "--format=%H", "--", path],
                       capture_output=True, text=True)
    return r.stdout.strip() or None

def is_ancestor(a, b):
    return subprocess.run(["git", "merge-base", "--is-ancestor", a, b],
                          capture_output=True).returncode == 0

files = sorted(list(DIR.glob("*.yaml")) + list(DIR.glob("*.yml")))
problems, listing = [], []

for f in files:
    try:
        o = load_yaml(f)
    except OSError as exc:
        print(f"oracles: {f} unreadable: {exc}", file=sys.stderr)
        sys.exit(2)

    oid = o.get("id") or f.stem
    status = str(o.get("status", "")).strip()
    crit = str(o.get("criticality", "")).strip().lower()
    if status not in {"DRAFT", "DECISION_REQUIRED", "TEST_READY", "DEFERRED", "RETIRED"}:
        print(f"oracles: {f.name} has no valid status (got «{status or '—'}»)", file=sys.stderr)
        sys.exit(2)

    listing.append((oid, status, crit, f.name))

    # Retired keeps its history; deferred is somebody's explicit decision to wait.
    if status in {"RETIRED", "DEFERRED"}:
        continue

    # A critical criterion that is still a draft is not a failing test — it is
    # unfinished thinking, and shipping code against it is the mistake.
    if crit == "critical" and status != "TEST_READY":
        problems.append((oid, f"is {status} but critical — no production code should rely on it yet",
                         ["Answer the eight questions, or lower its criticality with a reason."]))
        continue
    if status != "TEST_READY":
        continue

    missing = [q for field, q in QUESTIONS if not answered(o.get(field))]
    if missing:
        problems.append((oid, "is TEST_READY but leaves questions unanswered", missing))
        continue

    tests = [t for t in flatten(o.get("tests")) if t.strip()]
    if not tests:
        problems.append((oid, "names no test", ["A criterion nothing executes is a wish."]))
        continue
    absent = [t for t in tests if not Path(t).exists()]
    if absent:
        problems.append((oid, "names tests that do not exist", absent))
        continue

    # The one field checked for truth rather than presence.
    if crit not in {"critical", "high"}:
        continue
    fal = o.get("falsification") or {}
    defect = " ".join(flatten(fal.get("defect")))
    proved = " ".join(flatten(fal.get("proved_sha"))).strip()
    if not answered(fal.get("defect")) or not proved:
        problems.append((oid, "has no proof it can fail", [
            "falsification.defect: the mutation that must make the test fail",
            "falsification.proved_sha: the commit at which you watched it fail",
            "A test only ever seen passing has not been shown to test anything.",
        ]))
        continue
    if not is_ancestor(proved, "HEAD"):
        problems.append((oid, f"records a proof at {proved[:8]}, which is not in this history", [
            "Re-run the falsification here and record the commit."]))
        continue
    stale = [t for t in tests
             if (c := last_commit_touching(t)) and not is_ancestor(c, proved)]
    if stale:
        problems.append((oid, f"proof at {proved[:8]} predates its own tests", [
            *[f"changed since: {t}" for t in stale],
            "The proof no longer covers the test that exists. Break it again and watch it fail.",
        ]))

if MODE == "--list":
    for oid, status, crit, name in listing:
        print(f"  {status:18s} {crit or '—':9s} {oid}  ({name})")
    print(f"\n{len(listing)} oracle(s); {len(problems)} with findings.")
    sys.exit(0)

for oid, status, crit, name in listing:
    bad = any(p[0] == oid for p in problems)
    print(f"  {'FINDING' if bad else 'ok':8s} {status:18s} {oid}")

if not problems:
    print(f"\noracles: {len(listing)} criteria, every critical one proved falsifiable")
    sys.exit(0)

sys.stdout.flush()
print("", file=sys.stderr)
for oid, headline, details in problems:
    print(f"oracles: {oid} {headline}", file=sys.stderr)
    for d in details:
        print(f"    · {d}", file=sys.stderr)
    print("", file=sys.stderr)
print("An oracle records what would prove the code wrong. Weakening it to go green", file=sys.stderr)
print("removes the only thing standing between a plausible answer and a shipped one.", file=sys.stderr)
sys.exit(1)
PY
