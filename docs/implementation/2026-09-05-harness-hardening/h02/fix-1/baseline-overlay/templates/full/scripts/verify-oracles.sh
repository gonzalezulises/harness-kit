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
JUDGE_ROOT="$ROOT_DIR"
ROOT_DIR="${HARNESS_TARGET_ROOT:-$ROOT_DIR}"
unset HARNESS_TARGET_ROOT
cd "$ROOT_DIR" || exit 3

DIR="${ORACLES_DIR:-.harness/oracles}"
MODE="${1:-gate}"

if [[ ! -t 1 ]] || [[ -n "${NO_COLOR:-}" ]]; then
  RED=""; GREEN=""; RESET=""
else
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; RESET=$'\033[0m'
fi

command -v python3 >/dev/null 2>&1 || { echo "${RED}oracles: needs python3${RESET}" >&2; exit 3; }

ORACLE_PY="python3"
if [[ -x "$JUDGE_ROOT/.harness/tools/oracles-venv/bin/python3" ]]; then
  ORACLE_PY="$JUDGE_ROOT/.harness/tools/oracles-venv/bin/python3"
fi
"$ORACLE_PY" -I -c 'import yaml; assert yaml.__version__ == "6.0.3"' >/dev/null 2>&1 || {
  echo "oracles: TOOL_FAILURE: requires PyYAML==6.0.3; run bash scripts/setup-oracles.sh" >&2; exit 3;
}

# No oracles yet is a real, honest answer: this gate arrives before the criteria
# do, and a repo that has written none has nothing to be stale about.
if [[ ! -d "$DIR" ]] || ! find "$DIR" -name '*.yaml' -o -name '*.yml' 2>/dev/null | grep -q .; then
  echo "${GREEN}oracles: none declared in $DIR${RESET}"
  echo "  Write one when a criterion is critical enough that getting it wrong ships harm."
  exit 0
fi

# The eight questions of V2 §9.3, as the fields that answer them.
export DIR MODE
ORACLE_PY="python3"
if [[ -x "$JUDGE_ROOT/.harness/tools/oracles-venv/bin/python3" ]]; then
  ORACLE_PY="$JUDGE_ROOT/.harness/tools/oracles-venv/bin/python3"
fi
"$ORACLE_PY" -I - <<'PY'
import os, re, subprocess, sys, traceback, json, hashlib
try:
    import yaml
    if yaml.__version__ != "6.0.3": raise ImportError("requires PyYAML==6.0.3")
except ImportError as exc:
    print("oracles: TOOL_FAILURE: " + str(exc) + "; run bash scripts/setup-oracles.sh", file=sys.stderr)
    sys.exit(3)
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

class StrictLoader(yaml.SafeLoader):
    def compose_node(self, parent, index):
        if self.check_event(yaml.AliasEvent):
            raise ValueError("aliases are not supported in oracle contracts")
        event = self.peek_event()
        if getattr(event, "anchor", None): raise ValueError("anchors are not supported")
        return super().compose_node(parent, index)

def mapping(loader, node, deep=False):
    result = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if not isinstance(key, str): raise ValueError("mapping keys must be strings")
        if key in result: raise ValueError("duplicate key: " + key)
        result[key] = loader.construct_object(value_node, deep=deep)
    return result
StrictLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, mapping)

def load_yaml(path):
    data = yaml.load(path.read_text(encoding="utf-8"), Loader=StrictLoader)
    allowed = {"id", "requirement", "criticality", "status", "tests", "falsification"} | {k for k, q in QUESTIONS}
    if not isinstance(data, dict) or set(data) - allowed: raise ValueError("unknown fields or non-object oracle")
    for key in ("id", "requirement", "criticality", "status"):
        if not isinstance(data.get(key), str) or not data[key].strip(): raise ValueError(key + " must be a nonempty string")
    if data['criticality'] not in {'critical','high','medium','low'}: raise ValueError("invalid criticality")
    if 'tests' in data and (not isinstance(data['tests'],list) or any(not isinstance(t,str) or not t.strip() for t in data['tests'])): raise ValueError("tests must be a list of paths")
    if 'falsification' in data and not isinstance(data['falsification'],dict): raise ValueError("falsification must be an object")
    def value(v):
        if isinstance(v,str): return
        if isinstance(v,list):
            for item in v: value(item)
        elif isinstance(v,dict):
            for item in v.values(): value(item)
        else: raise ValueError("answers must contain strings, mappings or lists of strings")
    for key, question in QUESTIONS:
        if key in data: value(data[key])
    return data

def flatten(v):
    """A field answers its question if it holds anything real, at any depth."""
    if isinstance(v, list):
        return [s for item in v for s in flatten(item)]
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

parsed = []
for f in files:
    try:
        o = load_yaml(f)
    except (OSError, UnicodeError, ValueError, yaml.YAMLError) as exc:
        print(f"oracles: {f} unreadable: {exc}", file=sys.stderr)
        sys.exit(2)

    parsed.append((f,o))
if len({o["id"] for f,o in parsed}) != len(parsed):
    print("oracles: duplicate oracle id",file=sys.stderr); sys.exit(2)

for f, o in parsed:
    oid = o["id"]
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
    if not re.fullmatch('[0-9a-f]{40}', proved) or not is_ancestor(proved, "HEAD"):
        problems.append((oid, f"records a proof at {proved[:8]}, which is not in this history", ["Fetch the required history or record the actual witnessed base."]))
        continue
    receipt_path = fal.get("receipt")
    if receipt_path:
        try:
            def strict_json(pairs):
                d = {}
                for k,v in pairs:
                    if k in d: raise ValueError("duplicate receipt key")
                    d[k] = v
                return d
            receipt = json.loads(Path(receipt_path).read_text(), object_pairs_hook=strict_json)
            if not isinstance(receipt,dict) or set(receipt) != {"schema_version","command","exit_code","tests","source","logs"}: raise ValueError("invalid receipt fields")
            if receipt['schema_version'] != 1 or type(receipt['exit_code']) is not int or receipt['exit_code'] <= 0: raise ValueError("receipt must record observed nonzero RED")
            if not isinstance(receipt['command'],list) or not receipt['command'] or any(not isinstance(x,str) or not x for x in receipt['command']): raise ValueError("receipt needs exact argv")
            if not isinstance(receipt['tests'],dict) or set(receipt['tests']) != set(tests): raise ValueError("receipt tests differ from oracle")
            for group in ['tests','source','logs']:
                bindings=receipt[group]
                if not isinstance(bindings,dict) or not bindings: raise ValueError("empty receipt " + group)
                for path,digest in bindings.items():
                    if not isinstance(path,str) or Path(path).is_absolute() or '..' in Path(path).parts: raise ValueError("receipt paths must be repository relative")
                    if not isinstance(digest,str) or not re.fullmatch('[0-9a-f]{64}',digest): raise ValueError("invalid digest")
                    if hashlib.sha256(Path(path).read_bytes()).hexdigest() != digest: raise ValueError("receipt predates its own tests or changed bytes: " + path)
            print(f"  local RED receipt consistent: {oid}; a local receipt is not independent authority")
        except (OSError, ValueError, TypeError, KeyError) as exc:
            problems.append((oid,"invalid or stale RED receipt",[str(exc)]))
        continue
    if not is_ancestor(proved, "HEAD"):
        problems.append((oid, f"records a proof at {proved[:8]}, which is not in this history", [
            "Re-run the falsification here and record the commit."]))
        continue
    problems.append((oid, "has history consistency only, no witnessed RED receipt", ["Record falsification.receipt with command, nonzero exit and hashed tests/source/logs; a SHA alone does not witness RED."]))
    stale = [t for t in tests
             if (c := last_commit_touching(t)) and not is_ancestor(c, proved)]
    for t in tests:
        r = subprocess.run(["git", "show", proved + ":" + t], capture_output=True)
        if r.returncode or r.stdout != Path(t).read_bytes():
            if t not in stale: stale.append(t)
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
