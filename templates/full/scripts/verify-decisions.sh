#!/usr/bin/env bash
# verify-decisions.sh — decisions may be added, never quietly rewritten.
#
# Usage:
#   scripts/verify-decisions.sh [base-ref]      # defaults to origin/main, then main
#
# PROGRESS.md carries what is true now. DECISIONS.md carries WHY, and it is the
# one file whose value comes from being append-only. An agent that hits a
# decision blocking its approach can make the obstacle disappear by editing the
# reason it existed — and the next session, reading a tidy ledger, has no way to
# know a constraint was dropped rather than resolved.
#
# Adding a decision is normal. Superseding one is normal too: append a new entry
# that references the old. Editing or deleting an earlier entry is not.
#
# Exit codes:
#   0  every decision recorded in the base is still present, unchanged
#   1  DECISION_REWRITE_FORBIDDEN — an earlier decision was altered or removed
#  66  not a git repository

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR" || { echo "cannot cd to $ROOT_DIR" >&2; exit 66; }

if [[ ! -t 1 ]] || [[ -n "${NO_COLOR:-}" ]]; then
  RED=""; GREEN=""; YELLOW=""; BOLD=""; RESET=""
else
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
  BOLD=$'\033[1m'; RESET=$'\033[0m'
fi

git rev-parse --git-dir >/dev/null 2>&1 || {
  echo "verify-decisions: not a git repository" >&2; exit 66; }

BASE="${1:-}"
if [[ -z "$BASE" ]]; then
  for candidate in origin/main origin/master main master; do
    if git rev-parse --verify --quiet "$candidate" >/dev/null 2>&1; then
      BASE="$candidate"; break
    fi
  done
fi
[[ -n "$BASE" ]] || { echo "verify-decisions: no base ref found; pass one explicitly" >&2; exit 66; }

LEDGER="DECISIONS.md"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# CI checks out the head at depth 1, so the base commit is not in the local
# object store and `git show base:FILE` cannot resolve. DECISIONS_BASE_FILE lets
# the caller hand over the base copy it already checked out instead.
if [[ -n "${DECISIONS_BASE_FILE:-}" ]]; then
  if [[ ! -f "$DECISIONS_BASE_FILE" ]]; then
    echo "${YELLOW}NO_LEDGER${RESET} — no ledger at $DECISIONS_BASE_FILE. Nothing to protect yet."
    exit 0
  fi
  cp "$DECISIONS_BASE_FILE" "$WORK/base.md"
  BASE="$DECISIONS_BASE_FILE"
elif ! git show "$BASE:$LEDGER" > "$WORK/base.md" 2>/dev/null; then
  echo "${YELLOW}NO_LEDGER${RESET} — $LEDGER does not exist at $BASE. Nothing to protect yet."
  exit 0
fi

# ── Split a ledger into one file per '## ' entry, keyed by a slug of its heading
split_entries() {
  # split_entries <markdown-file> <out-dir>
  awk -v out="$2" '
    # A horizontal rule is formatting between entries, not content. Appending a
    # new decision adds one after the previous entry, which would otherwise read
    # as that earlier entry having been modified.
    /^-{3,}[[:space:]]*$/ { next }
    /^## / {
      title = substr($0, 4)
      gsub(/[^a-zA-Z0-9]+/, "-", title)
      file = out "/" title
      n[title]++
      if (n[title] > 1) file = file "-" n[title]
      current = file
      print $0 > current
      next
    }
    current { print $0 > current }
  ' "$1"
}

mkdir -p "$WORK/base" "$WORK/head"
split_entries "$WORK/base.md" "$WORK/base"

if [[ -f "$LEDGER" ]]; then
  split_entries "$LEDGER" "$WORK/head"
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
    echo "  A decision that no longer applies is superseded by a NEW entry that says so."
    echo "  Deleting it destroys the only record that the constraint ever existed."
    VIOLATIONS=$((VIOLATIONS + 1))
    continue
  fi

  # Compare content, ignoring pure whitespace reflow.
  if ! diff -q -b -B "$entry" "$mirror" >/dev/null 2>&1; then
    echo "${RED}${BOLD}DECISION_REWRITE_FORBIDDEN${RESET} — altered: ${BOLD}$heading${RESET}"
    diff -u -b -B "$entry" "$mirror" 2>/dev/null | sed -n '4,12p' | sed 's/^/  /'
    echo "  Append a new decision that supersedes this one instead of editing it."
    VIOLATIONS=$((VIOLATIONS + 1))
  fi
done

echo ""
if [[ "$VIOLATIONS" -gt 0 ]]; then
  echo "${RED}${BOLD}$VIOLATIONS decision(s) from $BASE were rewritten or removed.${RESET}"
  exit 1
fi

ADDED=$(( $(ls -1 "$WORK/head" 2>/dev/null | wc -l) - CHECKED ))
if [[ "$ADDED" -gt 0 ]]; then
  echo "${GREEN}${BOLD}$CHECKED decision(s) intact, $ADDED added.${RESET}"
else
  echo "${GREEN}${BOLD}$CHECKED decision(s) intact.${RESET}"
fi
exit 0
