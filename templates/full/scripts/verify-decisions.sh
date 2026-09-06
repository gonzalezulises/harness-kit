#!/usr/bin/env bash
# verify-decisions.sh — protect the append-only decision ledger.
# Exit: 0 intact/proven absent, 1 rewrite, 2 invalid authority, 3 tool failure,
# 66 no repository or no discoverable base.

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT_DIR="${HARNESS_TARGET_ROOT:-$ROOT_DIR}"
unset HARNESS_TARGET_ROOT
cd "$ROOT_DIR" || { echo "cannot cd to $ROOT_DIR" >&2; exit 66; }
git rev-parse --git-dir >/dev/null 2>&1 || {
  echo "verify-decisions: not a git repository" >&2; exit 66; }

if [[ ! -t 1 ]] || [[ -n "${NO_COLOR:-}" ]]; then
  YELLOW=""; RESET=""
else
  YELLOW=$'\033[1;33m'
  RESET=$'\033[0m'
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

# Protect the authority ledger as an exact byte prefix. This avoids Markdown
# parsing aliases and newline normalization: every authority byte is normative,
# while a syntactically separate level-two decision may be appended.
"$PY" -I - "$WORK/base.md" "$LEDGER" "$BASE_LABEL" <<'PYEOF'
import re, sys
from pathlib import Path

base_path, head_path = Path(sys.argv[1]), Path(sys.argv[2])
try:
    base = base_path.read_bytes()
except OSError as exc:
    print("verify-decisions: could not read authority ledger: " + str(exc), file=sys.stderr)
    raise SystemExit(3)
try:
    head = head_path.read_bytes()
except OSError as exc:
    print("verify-decisions: unreadable head ledger: " + str(exc), file=sys.stderr)
    raise SystemExit(2)

base_count = len(re.findall(rb"(?m)^## ", base))
head_count = len(re.findall(rb"(?m)^## ", head))
if not head.startswith(base):
    print("DECISION_REWRITE_FORBIDDEN — authority bytes were altered or removed.", file=sys.stderr)
    common = 0
    for left, right in zip(base, head):
        if left != right: break
        common += 1
    headings = [match for match in re.finditer(rb"(?m)^## ([^\r\n]+)", base)
                if match.start() <= common]
    if headings:
        print("Affected authority decision: " + headings[-1].group(1).decode("utf-8", "replace"), file=sys.stderr)
    print("Append a new decision that supersedes the old one instead of editing it.", file=sys.stderr)
    raise SystemExit(1)

suffix = head[len(base):]
if suffix:
    if base and not base.endswith(b"\n") and not (
            suffix.startswith(b"\n") or suffix.startswith(b"\r\n")):
        print("DECISION_REWRITE_FORBIDDEN — appended content must begin after a real line boundary.", file=sys.stderr)
        raise SystemExit(1)
    heading_pattern = re.compile(rb"(?m)^## ")
    heading = heading_pattern.search(head, len(base))
    if heading is None:
        print("DECISION_REWRITE_FORBIDDEN — appended bytes do not contain a new decision.", file=sys.stderr)
        raise SystemExit(1)
    separator = head[len(base):heading.start()]
    for line in separator.splitlines():
        if line.strip() and not re.fullmatch(rb"[ \t]*---+[ \t]*", line):
            print("DECISION_REWRITE_FORBIDDEN — append a separate level-two decision.", file=sys.stderr)
            raise SystemExit(1)

added = head_count - base_count
if added > 0:
    print(f"{base_count} decision(s) intact, {added} added.")
else:
    print(f"{base_count} decision(s) intact.")
PYEOF
exit $?
