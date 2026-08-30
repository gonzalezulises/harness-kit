#!/usr/bin/env bash
# verify-agent-notes.sh — the Agent Notes tree stays mechanically navigable.
#
# Usage:
#   scripts/verify-agent-notes.sh
#
# An Agent Note records a decision's WHY and what was given up — the parts code
# cannot carry. Its path encodes lifecycle and class, so the tree itself is the
# inventory and no index file exists to rot:
#
#   .agents/notes/{lifecycle}/{class}/yyyy-mm-dd-topic-title.md
#
# Lifecycles: proposed | implemented | rejected
# Classes:    feature | bug-fix | simplification | architecture | process | testing
#
# Exit codes:
#   0  every note is well-placed and well-formed (or there are no notes yet)
#   1  at least one violation
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NOTES="$ROOT_DIR/.agents/notes"

if [[ ! -d "$NOTES" ]]; then
  echo "NO_NOTES — no .agents/notes tree yet. Nothing to verify."
  exit 0
fi

LIFECYCLES="proposed implemented rejected"
CLASSES="feature bug-fix simplification architecture process testing"

violations=0
checked=0

while IFS= read -r f; do
  rel="${f#$NOTES/}"
  base="$(basename "$f")"
  [[ "$base" == "README.md" || "$base" == "AGENTS.md" ]] && continue
  checked=$((checked+1))

  IFS='/' read -r lifecycle klass leaf extra <<< "$rel"
  if [[ -n "${extra:-}" || -z "${leaf:-}" ]]; then
    echo "MISPLACED — $rel (expected {lifecycle}/{class}/yyyy-mm-dd-topic.md)"
    violations=$((violations+1)); continue
  fi
  case " $LIFECYCLES " in *" $lifecycle "*) ;; *)
    echo "BAD_LIFECYCLE — $rel ('$lifecycle' not in: $LIFECYCLES)"
    violations=$((violations+1)); continue ;;
  esac
  case " $CLASSES " in *" $klass "*) ;; *)
    echo "BAD_CLASS — $rel ('$klass' not in: $CLASSES)"
    violations=$((violations+1)); continue ;;
  esac
  if [[ ! "$leaf" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9][a-z0-9-]*\.md$ ]]; then
    echo "BAD_NAME — $rel (expected yyyy-mm-dd-topic-title.md, lowercase)"
    violations=$((violations+1)); continue
  fi
  if [[ ! -s "$f" ]] || ! head -1 "$f" | grep -q '^# '; then
    echo "BAD_FORMAT — $rel (first line must be a '# Title' heading, file non-empty)"
    violations=$((violations+1)); continue
  fi
done < <(find "$NOTES" -type f -name '*.md')

if [[ "$violations" -gt 0 ]]; then
  echo ""
  echo "$violations Agent Note violation(s)."
  exit 1
fi
echo "$checked Agent Note(s) well-formed."
exit 0
