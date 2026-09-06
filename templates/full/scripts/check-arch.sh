#!/usr/bin/env bash
# check-arch.sh — enforce architectural boundaries mechanically.
# Usage: scripts/check-arch.sh [repo-path]

set -uo pipefail

REPO="${1:-.}"
REPO="${REPO%/}"
cd "$REPO" || { echo "check-arch: cannot cd to $REPO" >&2; exit 66; }
RULES="${ARCH_RULES_FILE:-.harness/arch-rules.json}"
[[ -f "$RULES" ]] || { echo "check-arch: $RULES not found"; exit 0; }

if [[ ! -t 1 ]] || [[ -n "${NO_COLOR:-}" ]]; then
  RED=""; GREEN=""; BOLD=""; RESET=""
else
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
fi
PY=""
for c in python3 python; do command -v "$c" >/dev/null 2>&1 && { PY="$c"; break; }; done
[[ -n "$PY" ]] || { echo "check-arch: needs python3" >&2; exit 3; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Parse every rule before any check can execute. Typed match_argv checks state
# their legitimate match/no-match exit codes explicitly; legacy shell checks
# remain supported, but every non-zero status is treated as a check failure.
"$PY" -I - "$RULES" "$WORK" <<'PYEOF'
import json, re, sys
from pathlib import Path

path, output = sys.argv[1:3]
output = Path(output)

def strict_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result: raise ValueError("duplicate object key: " + key)
        result[key] = value
    return result

def fail(message):
    print("check-arch: " + message, file=sys.stderr)
    raise SystemExit(2)

def text(value, where, nonempty=True):
    if not isinstance(value, str) or "\0" in value or (nonempty and not value.strip()):
        fail(where + " must be a " + ("non-empty " if nonempty else "") + "NUL-free string")

try:
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh, object_pairs_hook=strict_object)
except (OSError, UnicodeError, json.JSONDecodeError, ValueError) as exc:
    fail(f"{path} is not valid JSON: {exc}")
if not isinstance(data, dict): fail(f"{path} root must be an object")
rules = data.get("rules")
if not isinstance(rules, list): fail(f"{path}.rules must be an array")
ids = set()
for i, rule in enumerate(rules):
    where = f"rules[{i}]"
    if not isinstance(rule, dict): fail(where + " must be an object")
    rid, check, expect = rule.get("id"), rule.get("check"), rule.get("expect", "empty")
    text(rid, where + ".id")
    if rid in ids: fail("duplicate rule id: " + rid)
    ids.add(rid)
    if expect not in {"empty", "nonempty", "exit0"}: fail(f"{where}.expect is unknown: {expect!r}")
    for key in ("what", "why", "fix"):
        text(rule.get(key), where + "." + key)

    if isinstance(check, str):
        text(check, where + ".check")
        normalized = {"type": "legacy_shell", "command": check}
    elif isinstance(check, dict):
        if check.get("type") != "match_argv": fail(where + ".check.type must be match_argv")
        argv = check.get("argv")
        if not isinstance(argv, list) or not argv: fail(where + ".check.argv must be a non-empty array")
        for j, arg in enumerate(argv): text(arg, f"{where}.check.argv[{j}]", nonempty=False)
        match_exit, no_match_exit = check.get("match_exit"), check.get("no_match_exit")
        for name, value in (("match_exit", match_exit), ("no_match_exit", no_match_exit)):
            if isinstance(value, bool) or not isinstance(value, int) or value < 0 or value > 255:
                fail(f"{where}.check.{name} must be an exit status from 0 through 255")
        if match_exit == no_match_exit: fail(where + ".check match and no-match exits must differ")
        filters = check.get("filters", [])
        if not isinstance(filters, list): fail(where + ".check.filters must be an array")
        for j, item in enumerate(filters):
            if not isinstance(item, dict) or set(item) != {"action", "pattern"}:
                fail(f"{where}.check.filters[{j}] must contain only action and pattern")
            if item["action"] not in {"include", "exclude"}: fail(f"{where}.check.filters[{j}].action is unknown")
            text(item["pattern"], f"{where}.check.filters[{j}].pattern")
            try: re.compile(item["pattern"])
            except re.error as exc: fail(f"{where}.check.filters[{j}].pattern is invalid: {exc}")
        normalized = {"type": "match_argv", "argv": argv, "match_exit": match_exit,
                      "no_match_exit": no_match_exit, "filters": filters}
    else:
        fail(where + ".check must be a string or typed object")

    record = output / f"rule-{i:06d}"
    record.mkdir()
    for key, value in (("id", rid), ("expect", expect), ("what", rule["what"]),
                       ("why", rule["why"]), ("fix", rule["fix"])):
        (record / key).write_text(value, encoding="utf-8")
    (record / "check.json").write_text(json.dumps(normalized, ensure_ascii=False), encoding="utf-8")
    if normalized["type"] == "legacy_shell":
        (record / "legacy-command").write_text(normalized["command"], encoding="utf-8")
(output / "rule-count").write_text(str(len(rules)), encoding="utf-8")
PYEOF
PARSE_RC=$?
[[ "$PARSE_RC" -eq 0 ]] || exit "$PARSE_RC"

VIOLATIONS=0
CHECKED=0
RULE_COUNT="$(cat "$WORK/rule-count")"
echo "${BOLD}Architecture Rules${RESET}"
for ((i=0; i<RULE_COUNT; i++)); do
  record="$WORK/rule-$(printf '%06d' "$i")"
  id="$(cat "$record/id"; printf x)"; id="${id%x}"
  expect="$(cat "$record/expect")"
  what="$(cat "$record/what"; printf x)"; what="${what%x}"
  why="$(cat "$record/why"; printf x)"; why="${why%x}"
  fix="$(cat "$record/fix"; printf x)"; fix="${fix%x}"
  CHECKED=$((CHECKED + 1))

  output_file="$WORK/output-$i"
  rc_file="$WORK/rc-$i"
  KIND="$($PY -I - "$record/check.json" <<'PYEOF'
import json, sys
print(json.load(open(sys.argv[1], encoding="utf-8"))["type"])
PYEOF
)"
  if [[ "$KIND" == "legacy_shell" ]]; then
    command="$(cat "$record/legacy-command"; printf x)"; command="${command%x}"
    ( eval "$command" ) >"$output_file" 2>&1
    printf '%s' "$?" > "$rc_file"
  else
    "$PY" -I - "$record/check.json" "$output_file" "$rc_file" <<'PYEOF'
import json, re, subprocess, sys
from pathlib import Path

spec = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
out_path, rc_path = Path(sys.argv[2]), Path(sys.argv[3])
try:
    result = subprocess.run(spec["argv"], stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
except OSError as exc:
    out_path.write_text("could not execute matcher: " + str(exc), encoding="utf-8")
    rc_path.write_text("256", encoding="ascii")
    raise SystemExit(0)
rc_path.write_text(str(result.returncode), encoding="ascii")
if result.returncode == spec["no_match_exit"]:
    out_path.write_bytes(b"")
    raise SystemExit(0)
if result.returncode != spec["match_exit"]:
    out_path.write_bytes(result.stdout)
    raise SystemExit(0)
text = result.stdout.decode("utf-8", "replace")
lines = text.splitlines(keepends=True)
for item in spec["filters"]:
    try: pattern = re.compile(item["pattern"])
    except re.error as exc:
        out_path.write_text("invalid configured filter: " + str(exc), encoding="utf-8")
        rc_path.write_text("256", encoding="ascii")
        raise SystemExit(0)
    if item["action"] == "include": lines = [line for line in lines if pattern.search(line)]
    else: lines = [line for line in lines if not pattern.search(line)]
out_path.write_text("".join(lines), encoding="utf-8")
PYEOF
  fi
  RC="$(cat "$rc_file")"
  OUTPUT="$(cat "$output_file"; printf x)"; OUTPUT="${OUTPUT%x}"
  FIRED=0
  TOOL_ERROR=0
  if [[ "$KIND" == "match_argv" ]]; then
    EXPECTED="$($PY -I - "$record/check.json" <<'PYEOF'
import json, sys
v=json.load(open(sys.argv[1], encoding="utf-8")); print(f'{v["match_exit"]} {v["no_match_exit"]}')
PYEOF
)"
    read -r MATCH_RC NO_MATCH_RC <<< "$EXPECTED"
    if [[ "$RC" -ne "$MATCH_RC" && "$RC" -ne "$NO_MATCH_RC" ]]; then FIRED=1; TOOL_ERROR=1; fi
  elif [[ "$RC" -ne 0 ]]; then
    FIRED=1; TOOL_ERROR=1
  fi
  if [[ "$TOOL_ERROR" -eq 0 ]]; then
    case "$expect" in
      exit0) [[ "$RC" -ne 0 ]] && FIRED=1 ;;
      empty) [[ -n "$OUTPUT" ]] && FIRED=1 ;;
      nonempty) [[ -z "$OUTPUT" ]] && FIRED=1 ;;
    esac
  fi

  if [[ "$FIRED" -eq 1 ]]; then
    VIOLATIONS=$((VIOLATIONS + 1))
    echo ""
    echo "  ${RED}${BOLD}VIOLATION${RESET} [$id]"
    [[ "$TOOL_ERROR" -eq 1 ]] && echo "  ${BOLD}CHECK ERROR:${RESET} command exited $RC outside its declared contract"
    echo "  ${BOLD}WHAT:${RESET} $what"
    echo "  ${BOLD}WHY:${RESET}  $why"
    echo "  ${BOLD}FIX:${RESET}  $fix"
    if [[ -n "$OUTPUT" ]]; then
      echo "  ${BOLD}Offending:${RESET}"
      printf '%s\n' "$OUTPUT" | head -10 | sed 's/^/      /'
    fi
  else
    echo "  ${GREEN}[OK]${RESET} $id"
  fi
done

echo ""
if [[ "$VIOLATIONS" -eq 0 ]]; then
  echo "${GREEN}${BOLD}$CHECKED architecture rule(s) hold.${RESET}"
  exit 0
fi
echo "${RED}${BOLD}$VIOLATIONS of $CHECKED architecture rule(s) violated.${RESET}"
exit 1
