#!/usr/bin/env bash
# pre-commit-staged.sh — fast, staged-only local checkpoint.
#
# Design rules (in order of importance):
#   1. STAGED FILES ONLY. CI owns the exhaustive matrix; this must stay fast.
#   2. REGENERATE RATHER THAN REJECT. When a formatter is available it fixes
#      the staged files and re-stages them instead of failing the commit.
#   3. FAIL LOUD WITH THE FIX. Missing tooling names the exact command to run;
#      it never half-runs and never fails with a bare ENOENT.
#
# Installed as a git hook by `make hooks-install` (opt-in — it refuses to fight
# an existing hook manager such as husky).
set -uo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "$ROOT_DIR" || exit 0

# Portable read (macOS ships bash 3.2: no mapfile).
STAGED=()
while IFS= read -r line; do STAGED+=("$line"); done < <(git diff --cached --name-only --diff-filter=ACM)
[[ ${#STAGED[@]} -eq 0 ]] && exit 0

fail=0

# 1. Whitespace errors in what is about to be committed.
if ! git diff --cached --check; then
  echo "pre-commit: fix the whitespace errors above (git diff --cached --check)." >&2
  fail=1
fi

# 2. Formatting — autofix and re-stage, never just complain.
if [[ -f .prettierrc || -f .prettierrc.json || -f prettier.config.js || -f .prettierrc.js ]]; then
  FMT=()
  for f in "${STAGED[@]}"; do
    case "$f" in *.json|*.md|*.css|*.yml|*.yaml) [[ -f "$f" ]] && FMT+=("$f") ;; esac
  done
  if [[ ${#FMT[@]} -gt 0 ]]; then
    if [[ -x node_modules/.bin/prettier ]]; then
      node_modules/.bin/prettier --write "${FMT[@]}" >/dev/null 2>&1 && git add "${FMT[@]}"
    else
      echo "pre-commit: this repo formats with prettier but node_modules is missing." >&2
      echo "            Run 'make setup' first — the hook will not half-run." >&2
      fail=1
    fi
  fi
fi

# 3. Agent Notes staged? Verify the tree before it lands.
for f in "${STAGED[@]}"; do
  case "$f" in .agents/notes/*)
    bash scripts/verify-agent-notes.sh || fail=1
    break ;;
  esac
done

exit "$fail"
