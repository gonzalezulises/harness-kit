#!/usr/bin/env bash
# install-githooks.sh — opt-in staged-only git hooks for this repo.
#
# Refuses to fight an existing hook manager: if husky (or any core.hooksPath)
# already owns the hooks, it reports that and changes nothing. Fold
# scripts/pre-commit-staged.sh into that manager's pre-commit instead.
set -uo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "not a git repository" >&2; exit 66; }
cd "$ROOT_DIR" || exit 66

current="$(git config core.hooksPath || true)"
if [[ -n "$current" && "$current" != ".githooks" ]]; then
  echo "hooks already managed via core.hooksPath=$current — not touching them."
  echo "Add 'bash scripts/pre-commit-staged.sh' to that manager's pre-commit instead."
  exit 0
fi
if [[ -d .husky && -z "$current" ]]; then
  echo "husky manages this repo's hooks — not touching them."
  echo "Add 'bash scripts/pre-commit-staged.sh' to .husky/pre-commit instead."
  exit 0
fi

mkdir -p .githooks
if [[ ! -f .githooks/pre-commit ]]; then
  printf '#!/usr/bin/env bash\nexec bash scripts/pre-commit-staged.sh\n' > .githooks/pre-commit
fi
chmod +x .githooks/pre-commit
git config core.hooksPath .githooks
echo "installed: core.hooksPath=.githooks (pre-commit → scripts/pre-commit-staged.sh)"
