#!/usr/bin/env bash
# F18 — the stamp must identify the code that was installed, not the last release.
#
# `.harness/kit-version` exists to answer «which of my repositories still lack
# the fix?». It copies VERSION, and the kit installs from a local checkout — so
# every commit between two releases stamps the same string. On 2026-09-15 a client
# repo read «kit 2.2.5» while running behaviour that only exists after #31, which
# no 2.2.5 tag contains. Two installations with the same stamp had different gates.
#
# The probe installs from a copy of this working tree whose HEAD is one commit past
# anything tagged, and asks for the one thing that makes the question answerable:
# the stamp names that commit. The format is the implementer's to choose
# (`2.2.5+g1a2b3c4`, a second line, …) — semver build metadata is the obvious one.
#
# Usage: bash tests/contract/F18-stamp-identifies-the-code.sh

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_DIR="$(cd "$HERE/../.." && pwd)"
# shellcheck source=tests/contract/lib.sh
. "$HERE/lib.sh"

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
echo "${BOLD}F18 — the stamp identifies the installed code${RESET}"

# A copy of the WORKING TREE (uncommitted work included), moved one commit past
# any tag so the release string alone cannot identify it.
snapshot_kit "$KIT_DIR" "$WORK/kit"
SHA="$(git -C "$WORK/kit" rev-parse --short=7 HEAD)"
VER="$(tr -d '[:space:]' < "$WORK/kit/VERSION")"

new_repo "$WORK/consumer"
printf '%s\n' '{"name":"x","version":"1.0.0","scripts":{"check":"echo ok","dev":"echo dev"}}' > package.json
commit_all "base"
bash "$WORK/kit/bin/harness-init.sh" --target . --level full >/dev/null 2>&1

STAMP="$(cat .harness/kit-version 2>/dev/null || true)"
if [[ -z "${STAMP//[[:space:]]/}" ]]; then
  bad "no stamp was written"
else
  case "$STAMP" in
    *"$VER"*) ok "the stamp still carries the release version ($VER)" ;;
    *)        bad "the stamp lost the release version (got: $STAMP)" ;;
  esac
  case "$STAMP" in
    *"$SHA"*) ok "the stamp names the installed commit ($SHA)" ;;
    *)        bad "the stamp cannot tell this install from any other «$VER» (got: $(printf '%s' "$STAMP" | tr '\n' ' '))" ;;
  esac
fi

# harness-status reads the stamp back. Whatever format was chosen, it must not
# choke on it or report an untagged install as simply «current».
OUT="$(NO_COLOR=1 bash "$WORK/kit/bin/harness-status.sh" --target . 2>&1)"
case "$OUT" in
  *"$SHA"*) ok "harness-status shows which commit this repository runs" ;;
  *)        bad "harness-status does not surface the installed commit" ;;
esac

finish "F18"
