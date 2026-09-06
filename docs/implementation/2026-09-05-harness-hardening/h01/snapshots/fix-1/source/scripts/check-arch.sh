#!/usr/bin/env bash
# check-arch.sh — enforce architectural boundaries mechanically.
# Usage: scripts/check-arch.sh [repo-path]

set -uo pipefail

REPO="${1:-.}"
REPO="${REPO%/}"
cd "$REPO" || { echo "check-arch: cannot cd to $REPO" >&2; exit 66; }
RULES=".harness/arch-rules.json"
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

# Parse every rule before any check can execute. Separate files keep multiline
# commands and empty diagnostic prose from changing record boundaries.
"$PY" - "$RULES" "$WORK" <<'PYEOF'
import json, sys
from pathlib import Path

path, output = sys.argv[1:3]
output = Path(output)
try:
    with open(path, encoding="utf-8") as fh: data = json.load(fh)
except (OSError, UnicodeError, json.JSONDecodeError) as exc:
    print(f"check-arch: {path} is not valid JSON: {exc}", file=sys.stderr); raise SystemExit(2)
if not isinstance(data, dict):
    print(f"check-arch: {path} root must be an object", file=sys.stderr); raise SystemExit(2)
rules = data.get("rules")
if not isinstance(rules, list):
    print(f"check-arch: {path}.rules must be an array", file=sys.stderr); raise SystemExit(2)
ids = set()
for i, rule in enumerate(rules):
    where = f"rules[{i}]"
    if not isinstance(rule, dict):
        print(f"check-arch: {where} must be an object", file=sys.stderr); raise SystemExit(2)
    rid, check, expect = rule.get("id"), rule.get("check"), rule.get("expect", "empty")
    if not isinstance(rid, str) or not rid.strip():
        print(f"check-arch: {where}.id must be non-empty", file=sys.stderr); raise SystemExit(2)
    if rid in ids:
        print(f"check-arch: duplicate rule id: {rid}", file=sys.stderr); raise SystemExit(2)
    ids.add(rid)
    if not isinstance(check, str) or not check.strip():
        print(f"check-arch: {where}.check must be non-empty", file=sys.stderr); raise SystemExit(2)
    if expect not in {"empty", "nonempty", "exit0"}:
        print(f"check-arch: {where}.expect is unknown: {expect!r}", file=sys.stderr); raise SystemExit(2)
    for key in ("what", "why", "fix"):
        if not isinstance(rule.get(key), str) or not rule[key].strip():
            print(f"check-arch: {where}.{key} must be a non-empty string", file=sys.stderr); raise SystemExit(2)
    record = output / f"rule-{i:06d}"
    record.mkdir()
    for key, value in (("id", rid), ("check", check), ("expect", expect),
                       ("what", rule["what"]), ("why", rule["why"]), ("fix", rule["fix"])):
        (record / key).write_text(value, encoding="utf-8")
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
  check="$(cat "$record/check"; printf x)"; check="${check%x}"
  expect="$(cat "$record/expect")"
  what="$(cat "$record/what"; printf x)"; what="${what%x}"
  why="$(cat "$record/why"; printf x)"; why="${why%x}"
  fix="$(cat "$record/fix"; printf x)"; fix="${fix%x}"
  CHECKED=$((CHECKED + 1))

  output_file="$WORK/output-$i"
  ( eval "$check" ) >"$output_file" 2>&1
  RC=$?
  OUTPUT="$(cat "$output_file"; printf x)"; OUTPUT="${OUTPUT%x}"
  FIRED=0
  TOOL_ERROR=0
  case "$expect" in
    exit0)
      [[ "$RC" -ne 0 ]] && FIRED=1
      ;;
    empty)
      if [[ "$RC" -gt 1 ]]; then
        FIRED=1; TOOL_ERROR=1
      elif [[ "$RC" -eq 1 && "$check" != *grep* ]]; then
        FIRED=1; TOOL_ERROR=1
      elif [[ -n "$OUTPUT" ]]; then
        FIRED=1
      fi
      ;;
    nonempty)
      if [[ "$RC" -gt 1 ]]; then
        FIRED=1; TOOL_ERROR=1
      elif [[ -z "$OUTPUT" ]]; then
        FIRED=1
      fi
      ;;
  esac

  if [[ "$FIRED" -eq 1 ]]; then
    VIOLATIONS=$((VIOLATIONS + 1))
    echo ""
    echo "  ${RED}${BOLD}VIOLATION${RESET} [$id]"
    [[ "$TOOL_ERROR" -eq 1 ]] && echo "  ${BOLD}CHECK ERROR:${RESET} command exited $RC; this is not a grep no-match"
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
