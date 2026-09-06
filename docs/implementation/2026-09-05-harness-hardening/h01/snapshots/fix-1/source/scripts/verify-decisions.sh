#!/usr/bin/env bash
# verify-decisions.sh — protect the append-only decision ledger.
# Exit: 0 intact/proven absent, 1 rewrite, 2 invalid authority, 3 tool failure,
# 66 no repository or no discoverable base.

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR" || { echo "cannot cd to $ROOT_DIR" >&2; exit 66; }
git rev-parse --git-dir >/dev/null 2>&1 || {
  echo "verify-decisions: not a git repository" >&2; exit 66; }

if [[ ! -t 1 ]] || [[ -n "${NO_COLOR:-}" ]]; then
  RED=""; GREEN=""; YELLOW=""; BOLD=""; RESET=""
else
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
  BOLD=$'\033[1m'; RESET=$'\033[0m'
fi

PY=""
for c in python3 python; do command -v "$c" >/dev/null 2>&1 && { PY="$c"; break; }; done
[[ -n "$PY" ]] || { echo "verify-decisions: needs python3" >&2; exit 3; }

LEDGER="DECISIONS.md"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
BASE="${1:-}"
BASE_LABEL=""
BASE_PRESENT=0

# A CI-provided file is an explicit authority declaration. Missing is an error,
# never evidence that the protected ledger did not exist.
if [[ -n "${DECISIONS_BASE_FILE:-}" ]]; then
  [[ -f "$DECISIONS_BASE_FILE" ]] || {
    echo "verify-decisions: declared base file is missing: $DECISIONS_BASE_FILE" >&2
    exit 2
  }
  cp "$DECISIONS_BASE_FILE" "$WORK/base.md" || exit 3
  BASE_LABEL="$DECISIONS_BASE_FILE"
  BASE_PRESENT=1
else
  if [[ -z "$BASE" ]]; then
    for candidate in origin/main origin/master main master; do
      if git rev-parse --verify --quiet "$candidate^{commit}" >/dev/null 2>&1; then
        BASE="$candidate"; break
      fi
    done
  fi
  [[ -n "$BASE" ]] || {
    echo "verify-decisions: no base ref found; pass one explicitly" >&2; exit 66; }
  git rev-parse --verify --quiet "$BASE^{commit}" >/dev/null 2>&1 || {
    echo "verify-decisions: base ref does not resolve to a commit: $BASE" >&2; exit 2; }
  BASE_LABEL="$BASE"
  TREE_RESULT="$(git ls-tree -r --name-only "$BASE" -- "$LEDGER" 2>/dev/null)"
  TREE_RC=$?
  [[ "$TREE_RC" -eq 0 ]] || {
    echo "verify-decisions: could not inspect base tree: $BASE" >&2; exit 3; }
  if [[ "$TREE_RESULT" == "$LEDGER" ]]; then
    git show "$BASE:$LEDGER" > "$WORK/base.md" 2>/dev/null || {
      echo "verify-decisions: could not read $LEDGER at $BASE" >&2; exit 3; }
    BASE_PRESENT=1
  fi
fi

if [[ "$BASE_PRESENT" -eq 0 ]]; then
  echo "${YELLOW}NO_LEDGER${RESET} — $LEDGER is proven absent at $BASE_LABEL. Nothing to protect yet."
  exit 0
fi

# Split at Markdown level-two headings. The only normalization removes the
# blank/horizontal-rule separator after an entry; every byte inside the entry,
# including indentation and table spacing, remains normative.
mkdir -p "$WORK/base" "$WORK/head"
"$PY" - "$WORK/base.md" "$WORK/base" <<'PYEOF'
import re, sys
from pathlib import Path

source, output = Path(sys.argv[1]), Path(sys.argv[2])
lines = source.read_text(encoding="utf-8").splitlines(keepends=True)
entries, current = [], None
for line in lines:
    if line.startswith("## "):
        if current is not None: entries.append(current)
        current = [line]
    elif current is not None:
        current.append(line)
if current is not None: entries.append(current)
counts = {}
for entry in entries:
    while len(entry) > 1 and (not entry[-1].strip() or re.fullmatch(r"---+", entry[-1].strip())):
        entry.pop()
    heading = entry[0][3:].strip()
    slug = re.sub(r"[^A-Za-z0-9]+", "-", heading).strip("-") or "decision"
    counts[slug] = counts.get(slug, 0) + 1
    name = slug if counts[slug] == 1 else f"{slug}-{counts[slug]}"
    (output / name).write_text("".join(entry), encoding="utf-8")
PYEOF
SPLIT_RC=$?
[[ "$SPLIT_RC" -eq 0 ]] || exit 2

if [[ -f "$LEDGER" ]]; then
  "$PY" - "$LEDGER" "$WORK/head" <<'PYEOF'
import re, sys
from pathlib import Path

source, output = Path(sys.argv[1]), Path(sys.argv[2])
try: lines = source.read_text(encoding="utf-8").splitlines(keepends=True)
except (OSError, UnicodeError) as exc:
    print("verify-decisions: unreadable head ledger: " + str(exc), file=sys.stderr); raise SystemExit(2)
entries, current = [], None
for line in lines:
    if line.startswith("## "):
        if current is not None: entries.append(current)
        current = [line]
    elif current is not None:
        current.append(line)
if current is not None: entries.append(current)
counts = {}
for entry in entries:
    while len(entry) > 1 and (not entry[-1].strip() or re.fullmatch(r"---+", entry[-1].strip())):
        entry.pop()
    heading = entry[0][3:].strip()
    slug = re.sub(r"[^A-Za-z0-9]+", "-", heading).strip("-") or "decision"
    counts[slug] = counts.get(slug, 0) + 1
    name = slug if counts[slug] == 1 else f"{slug}-{counts[slug]}"
    (output / name).write_text("".join(entry), encoding="utf-8")
PYEOF
  SPLIT_RC=$?
  [[ "$SPLIT_RC" -eq 0 ]] || exit "$SPLIT_RC"
fi

VIOLATIONS=0
CHECKED=0
for entry in "$WORK/base"/*; do
  [[ -e "$entry" ]] || continue
  CHECKED=$((CHECKED + 1))
  name="$(basename "$entry")"
  heading="$(head -1 "$entry" | sed 's/^## //')"
  mirror="$WORK/head/$name"
  if [[ ! -f "$mirror" ]]; then
    echo "${RED}${BOLD}DECISION_REWRITE_FORBIDDEN${RESET} — removed: ${BOLD}$heading${RESET}"
    VIOLATIONS=$((VIOLATIONS + 1))
    continue
  fi
  if ! cmp -s "$entry" "$mirror"; then
    echo "${RED}${BOLD}DECISION_REWRITE_FORBIDDEN${RESET} — altered: ${BOLD}$heading${RESET}"
    diff -u "$entry" "$mirror" 2>/dev/null | sed -n '4,12p' | sed 's/^/  /'
    echo "  Append a new decision that supersedes this one instead of editing it."
    VIOLATIONS=$((VIOLATIONS + 1))
  fi
done

echo ""
if [[ "$VIOLATIONS" -gt 0 ]]; then
  echo "${RED}${BOLD}$VIOLATIONS decision(s) from $BASE_LABEL were rewritten or removed.${RESET}"
  exit 1
fi
HEAD_COUNT="$(find "$WORK/head" -type f | wc -l | tr -d '[:space:]')"
ADDED=$((HEAD_COUNT - CHECKED))
if [[ "$ADDED" -gt 0 ]]; then
  echo "${GREEN}${BOLD}$CHECKED decision(s) intact, $ADDED added.${RESET}"
else
  echo "${GREEN}${BOLD}$CHECKED decision(s) intact.${RESET}"
fi
exit 0
