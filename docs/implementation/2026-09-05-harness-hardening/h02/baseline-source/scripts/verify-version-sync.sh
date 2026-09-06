#!/usr/bin/env bash
# verify-version-sync.sh — the version lives in four places; they must agree.
#
# Releases are automated by release-please, which owns CHANGELOG.md and
# .release-please-manifest.json. But this kit also carries VERSION (read by the
# auditor, the status command and the scaffolder) and .harness/kit-version (the
# record a scaffolded repository compares itself against to learn it is stale).
#
# A release that bumps some of those and not the others is the worst kind of
# failure this repo has: it ships silently. The scaffolder stamps one number,
# harness-status.sh compares against another, and every downstream repository is
# told it is current when it is not — including when the release carried a
# security fix. Hence a gate rather than a habit.
#
# Usage: bash scripts/verify-version-sync.sh
# Exit: 0 all four agree · 1 they disagree · 3 a source is missing or unreadable

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR" || exit 3

if [[ ! -t 1 ]] || [[ -n "${NO_COLOR:-}" ]]; then
  RED=""; GREEN=""; BOLD=""; RESET=""
else
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
fi

read_or_die() {
  [[ -f "$1" ]] || { echo "${RED}version-sync: missing $1${RESET}" >&2; exit 3; }
  tr -d '[:space:]' < "$1"
}

VERSION_FILE="$(read_or_die VERSION)"
KIT_VERSION="$(read_or_die .harness/kit-version)"

# The manifest is release-please's own record. Read the "." key without adding a
# JSON dependency: the file is machine-written and single-keyed.
MANIFEST=""
if [[ -f .release-please-manifest.json ]]; then
  MANIFEST="$(sed -n 's/.*"\."[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
    .release-please-manifest.json | head -1)"
fi

# The newest released heading in the changelog, in either the Keep a Changelog
# form written by hand or the plain form release-please emits.
CHANGELOG="$(grep -m1 -oE '^#+ \[?[0-9]+\.[0-9]+\.[0-9]+\]?' CHANGELOG.md 2>/dev/null \
  | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"

FAILED=0
report() {
  if [[ "$2" == "$VERSION_FILE" ]]; then
    echo "  ${GREEN}ok${RESET}   $1 = $2"
  else
    echo "  ${RED}FAIL${RESET} $1 = ${2:-<absent>}, but VERSION = $VERSION_FILE"
    FAILED=1
  fi
}

echo "${BOLD}version sync${RESET}"
case "$VERSION_FILE" in
  [0-9]*.[0-9]*.[0-9]*) echo "  ${GREEN}ok${RESET}   VERSION = $VERSION_FILE" ;;
  *) echo "  ${RED}FAIL${RESET} VERSION is not semver: '$VERSION_FILE'"; FAILED=1 ;;
esac
report ".harness/kit-version" "$KIT_VERSION"
[[ -n "$MANIFEST" ]] && report ".release-please-manifest.json" "$MANIFEST"
[[ -n "$CHANGELOG" ]] && report "CHANGELOG.md (newest entry)" "$CHANGELOG"

echo ""
if [[ $FAILED -ne 0 ]]; then
  cat >&2 <<EOF
${RED}${BOLD}The version is inconsistent across the repository.${RESET}

WHAT  The files above disagree about which version this kit is.
WHY   harness-init.sh stamps VERSION into every scaffolded repo, and
      harness-status.sh compares that stamp to decide whether a repository is
      stale. Disagreement means downstream repos are told they are current when
      they are not — the exact failure a security release must not have.
FIX   Run: bash scripts/sync-version.sh
      It rewrites VERSION and .harness/kit-version from the release-please
      manifest, which is the single source of truth once a release is cut.
EOF
  exit 1
fi
echo "${GREEN}${BOLD}Every copy of the version agrees.${RESET}"
