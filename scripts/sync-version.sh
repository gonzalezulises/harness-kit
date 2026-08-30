#!/usr/bin/env bash
# sync-version.sh — propagate the released version to the files that carry it.
#
# release-please owns .release-please-manifest.json and CHANGELOG.md. It cannot
# update VERSION or .harness/kit-version, because both are bare version strings
# read with `tr -d '[:space:]'` and its generic updater needs an annotation
# comment those files cannot carry without breaking every consumer.
#
# So the manifest is the source of truth and this script propagates it. The
# release workflow runs it inside the release PR; verify-version-sync.sh fails
# the build if it ever did not.
#
# Usage: bash scripts/sync-version.sh
# Exit: 0 written (or already correct) · 3 the manifest is missing or unreadable

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR" || exit 3

[[ -f .release-please-manifest.json ]] \
  || { echo "sync-version: .release-please-manifest.json is missing" >&2; exit 3; }

VERSION="$(sed -n 's/.*"\."[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
  .release-please-manifest.json | head -1)"

case "$VERSION" in
  [0-9]*.[0-9]*.[0-9]*) ;;
  *) echo "sync-version: no semver under the \".\" key of the manifest" >&2; exit 3 ;;
esac

printf '%s\n' "$VERSION" > VERSION
mkdir -p .harness
printf '%s\n' "$VERSION" > .harness/kit-version

echo "version synced to $VERSION (VERSION, .harness/kit-version)"
