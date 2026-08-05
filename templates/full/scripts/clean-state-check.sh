#!/usr/bin/env bash
# clean-state-check.sh — the clock-out gate. Idempotent: safe to run repeatedly.
#
# Checks the five clean-state dimensions and exits 0 only when all pass.
# Usage: scripts/clean-state-check.sh [repo-path]

set -uo pipefail

REPO="${1:-.}"
REPO="${REPO%/}"
cd "$REPO"

if [[ ! -t 1 ]] || [[ -n "${NO_COLOR:-}" ]]; then
  RED=""; GREEN=""; YELLOW=""; BOLD=""; RESET=""
else
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
  BOLD=$'\033[1m'; RESET=$'\033[0m'
fi

FAILURES=0
ok()   { echo "  ${GREEN}[OK]${RESET}   $1"; }
bad()  { echo "  ${RED}[FAIL]${RESET} $1"; FAILURES=$((FAILURES+1)); }
note() { echo "  ${YELLOW}[NOTE]${RESET} $1"; }

echo "${BOLD}Clean State Check${RESET}"

# 1 ── Build / verification passes ────────────────────────────────────────────
echo ""
echo "${BOLD}1. Verification${RESET}"
VERIFY_CMD="{{VERIFY_CMD}}"
if [[ -n "$VERIFY_CMD" ]]; then
  if eval "$VERIFY_CMD" >/tmp/clean-state-verify.log 2>&1; then
    ok "\`$VERIFY_CMD\` exits 0"
  else
    bad "\`$VERIFY_CMD\` failed — see /tmp/clean-state-verify.log"
  fi
else
  bad "no verification command configured in this script"
fi

# 2 ── Startup path works ─────────────────────────────────────────────────────
echo ""
echo "${BOLD}2. Startup path${RESET}"
if [[ -f "init.sh" ]]; then
  if [[ -x "init.sh" ]]; then
    ok "init.sh present and executable"
  else
    bad "init.sh is not executable — run: chmod +x init.sh"
  fi
else
  bad "init.sh missing — the next session has no standard startup path"
fi

# 3 ── PROGRESS.md is current ─────────────────────────────────────────────────
echo ""
echo "${BOLD}3. Progress record${RESET}"
if [[ -f "PROGRESS.md" ]]; then
  if grep -qiE '(last commit|current state)' PROGRESS.md; then
    ok "PROGRESS.md has a Current State block"
  else
    bad "PROGRESS.md has no Current State block"
  fi
  if git rev-parse --git-dir >/dev/null 2>&1; then
    HEAD_SHORT="$(git rev-parse --short HEAD 2>/dev/null || echo "")"
    if [[ -n "$HEAD_SHORT" ]] && grep -q "$HEAD_SHORT" PROGRESS.md; then
      ok "PROGRESS.md references the current commit ($HEAD_SHORT)"
    else
      note "PROGRESS.md does not name the current commit — update it before committing"
    fi
  fi
else
  bad "PROGRESS.md missing"
fi

# 4 ── Feature list is honest ─────────────────────────────────────────────────
echo ""
echo "${BOLD}4. Feature list honesty${RESET}"
if [[ -f "feature_list.json" ]]; then
  PY=""
  for c in python3 python; do command -v "$c" >/dev/null 2>&1 && { PY="$c"; break; }; done
  if [[ -n "$PY" ]]; then
    RESULT="$("$PY" - feature_list.json <<'PYEOF'
import json, sys
try:
    data = json.load(open(sys.argv[1]))
except Exception as e:
    print(f"PARSE_ERROR::{e}"); sys.exit(0)
feats = data.get("features", [])
problems = []
active = [f for f in feats if f.get("state") == "active"]
if len(active) > 1:
    problems.append(f"WIP=1 violated: {len(active)} features are active ({', '.join(f.get('id','?') for f in active)})")
for f in feats:
    if f.get("state") == "passing" and not f.get("evidence"):
        problems.append(f"{f.get('id','?')} is 'passing' with no evidence recorded")
print("OK" if not problems else "\n".join(problems))
PYEOF
)"
    if [[ "$RESULT" == "OK" ]]; then
      ok "no false 'passing' entries, WIP=1 respected"
    elif [[ "$RESULT" == PARSE_ERROR::* ]]; then
      bad "feature_list.json is not valid JSON: ${RESULT#PARSE_ERROR::}"
    else
      while IFS= read -r line; do bad "$line"; done <<< "$RESULT"
    fi
  else
    note "python3 unavailable — skipping feature list validation"
  fi
else
  bad "feature_list.json missing"
fi

# 5 ── No debug artifacts ─────────────────────────────────────────────────────
echo ""
echo "${BOLD}5. Debug artifacts${RESET}"
ARTIFACTS="$(find . \
  -not -path './.git/*' -not -path './node_modules/*' -not -path './.next/*' \
  -not -path './dist/*' -not -path './build/*' -not -path './.venv/*' \
  \( -name '*.orig' -o -name '*.rej' -o -name '*.bak' -o -name '.DS_Store' \) \
  2>/dev/null | head -20)"
if [[ -z "$ARTIFACTS" ]]; then
  ok "no merge/backup artifacts in the tree"
else
  bad "stray artifacts found:"
  echo "$ARTIFACTS" | sed 's/^/        /'
fi

if git rev-parse --git-dir >/dev/null 2>&1; then
  UNTRACKED="$(git status --porcelain 2>/dev/null | grep -c '^??' || true)"
  UNTRACKED="$(echo "$UNTRACKED" | tr -d ' \n')"
  if [[ "${UNTRACKED:-0}" -gt 0 ]]; then
    note "$UNTRACKED untracked file(s) — commit them or add them to .gitignore"
  else
    ok "no untracked files"
  fi
fi

# ── Verdict ──────────────────────────────────────────────────────────────────
echo ""
echo "${BOLD}────────────────────────────────────────${RESET}"
if [[ $FAILURES -eq 0 ]]; then
  echo "${GREEN}${BOLD}Clean state. Safe to end the session.${RESET}"
  exit 0
else
  echo "${RED}${BOLD}$FAILURES clean-state failure(s). Do not end the session here.${RESET}"
  echo "Either fix them, or record them in PROGRESS.md -> Blockers so the next"
  echo "session inherits the problem knowingly instead of discovering it."
  exit 1
fi
