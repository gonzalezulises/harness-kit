#!/usr/bin/env bash
# verify-ceremony.sh — the paperwork must not outweigh the work it governs.
#
# Usage:
#   scripts/verify-ceremony.sh [repo-path]
#
# "Least bureaucracy" enforced mechanically, not as a slogan. The ceremony
# footprint — Markdown narrative plus the feature state file — may not exceed a
# ceiling share of the repository's tracked lines. Detail lives in docs/, but a
# repo whose prose outweighs its code is carrying overhead, not governance.
#
# Exit codes:
#   0  ceremony footprint is under the ceiling
#   1  CEREMONY_OVER_BUDGET — prose exceeds the ceiling share
#  66  not a git repository, or nothing tracked
set -uo pipefail

REPO="${1:-.}"
MAX="${CEREMONY_MAX_PERCENT:-35}"
cd "$REPO" 2>/dev/null || { echo "verify-ceremony: cannot cd to $REPO" >&2; exit 66; }

git rev-parse --git-dir >/dev/null 2>&1 || { echo "verify-ceremony: not a git repository" >&2; exit 66; }

FILES="$(mktemp)"; CER="$(mktemp)"; trap 'rm -f "$FILES" "$CER"' EXIT
git ls-files > "$FILES"
grep -E '\.(md|markdown)$|(^|/)feature_list\.json$' "$FILES" > "$CER" || true

CEREMONY=0; TOTAL=0
while IFS= read -r f; do
  [[ -f "$f" ]] || continue
  TOTAL=$((TOTAL + $(wc -l < "$f" | tr -d ' ')))
done < "$FILES"

while IFS= read -r f; do
  [[ -f "$f" ]] || continue
  CEREMONY=$((CEREMONY + $(wc -l < "$f" | tr -d ' ')))
done < "$CER"

if [[ "$TOTAL" -eq 0 ]]; then
  echo "verify-ceremony: nothing tracked to measure." >&2; exit 66
fi

PCT=$(( CEREMONY * 100 / TOTAL ))
echo "verify-ceremony: $CEREMONY ceremony lines vs $TOTAL total ($PCT%, ceiling ${MAX}%)."

if [[ "$PCT" -gt "$MAX" ]]; then
  echo "CEREMONY_OVER_BUDGET: prose is $PCT% of the repository — above the ${MAX}% ceiling."
  echo "Largest ceremony files:"
  sort -u "$CER" | while IFS= read -r f; do
    [[ -f "$f" ]] && printf '%7d  %s\n' "$(wc -l < "$f" | tr -d ' ')" "$f"
  done | sort -rn | head -10
  echo "Delete self-report artifacts, fold detail into docs/, or split the repo."
  exit 1
fi
exit 0
