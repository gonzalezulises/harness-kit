#!/usr/bin/env bash
# check-arch.sh — enforce architectural boundaries mechanically.
#
# Reads .harness/arch-rules.json and runs each rule. A rule that fires prints
# WHAT / WHY / FIX, because "violation in module X" is not actionable to an agent
# but "delete the import on line 12 of src/ui/db.ts" is.
#
# Usage: scripts/check-arch.sh [repo-path]
#
# Every error category caught in code review should become a rule here. A rule
# runs on every commit; a review comment runs once and is forgotten.

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
[[ -n "$PY" ]] || { echo "check-arch: needs python3" >&2; exit 69; }

RULES_TSV="$("$PY" - "$RULES" <<'PYEOF'
import json, sys
try:
    data = json.load(open(sys.argv[1]))
except Exception as e:
    print(f"__PARSE_ERROR__\t{e}\t\t\t\t"); sys.exit(0)
rules = data.get("rules", data if isinstance(data, list) else [])
for r in rules:
    fields = [
        r.get("id", "unnamed"),
        r.get("check", ""),
        r.get("expect", "empty"),
        r.get("what", ""),
        r.get("why", ""),
        r.get("fix", ""),
    ]
    print("\t".join(str(f).replace("\t", " ").replace("\n", " ") for f in fields))
PYEOF
)"

VIOLATIONS=0
CHECKED=0

echo "${BOLD}Architecture Rules${RESET}"

while IFS=$'\t' read -r id check expect what why fix; do
  [[ -z "$id" ]] && continue
  if [[ "$id" == "__PARSE_ERROR__" ]]; then
    echo "${RED}check-arch: $RULES is not valid JSON: $check${RESET}" >&2
    exit 65
  fi
  [[ -z "$check" ]] && continue
  CHECKED=$((CHECKED + 1))

  OUTPUT="$(eval "$check" 2>/dev/null || true)"
  RC=$?

  FIRED=0
  case "$expect" in
    empty)    [[ -n "$OUTPUT" ]] && FIRED=1 ;;
    nonempty) [[ -z "$OUTPUT" ]] && FIRED=1 ;;
    exit0)    [[ $RC -ne 0 ]] && FIRED=1 ;;
    *)        [[ -n "$OUTPUT" ]] && FIRED=1 ;;
  esac

  if [[ $FIRED -eq 1 ]]; then
    VIOLATIONS=$((VIOLATIONS + 1))
    echo ""
    echo "  ${RED}${BOLD}VIOLATION${RESET} [$id]"
    echo "  ${BOLD}WHAT:${RESET} $what"
    echo "  ${BOLD}WHY:${RESET}  $why"
    echo "  ${BOLD}FIX:${RESET}  $fix"
    if [[ -n "$OUTPUT" ]]; then
      echo "  ${BOLD}Offending:${RESET}"
      echo "$OUTPUT" | head -10 | sed 's/^/      /'
    fi
  else
    echo "  ${GREEN}[OK]${RESET} $id"
  fi
done <<< "$RULES_TSV"

echo ""
if [[ $VIOLATIONS -eq 0 ]]; then
  echo "${GREEN}${BOLD}$CHECKED architecture rule(s) hold.${RESET}"
  exit 0
else
  echo "${RED}${BOLD}$VIOLATIONS of $CHECKED architecture rule(s) violated.${RESET}"
  exit 1
fi
