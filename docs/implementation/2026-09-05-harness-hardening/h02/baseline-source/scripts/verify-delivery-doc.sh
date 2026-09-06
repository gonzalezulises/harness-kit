#!/usr/bin/env bash
# verify-delivery-doc.sh — the deployment runbook must describe THIS release.
#
# The kit verifies code with some rigour and, until now, verified delivery not at
# all. That gap has a shape, and it showed up in a real handover: the code was
# green, every gate passed, and the runbook that went to the client's IT still
# described the previous release. It carried `ecr-push-tag v1.2.4` inside a v1.2.5
# pass — a command that would have deployed the wrong image — plus a section
# explaining a migration already applied, and none explaining the one this release
# actually shipped. Two careful readings did not catch it. A grep would have.
#
# Note the irony this script exists to close: `verify-version-sync.sh` already
# lives in this kit, because "the version lives in four places and they must
# agree, and a release that bumps some and not the others ships silently". That
# reasoning was applied to the kit itself and never handed to the repositories the
# kit installs. This is that same gate, pointed at the document a human will
# follow with production in their hands.
#
# Nothing here needs judgement. Every check is a grep or a git diff, which is the
# point: prose review is exactly what already failed.
#
# Usage:
#   bash scripts/verify-delivery-doc.sh
#
# Configure per repo via env (or edit the defaults):
#   DELIVERY_DOC       document holding the runbook          (default: README.md)
#   DELIVERY_HEADING   heading regex marking its section     (default: ^## Desplegar)
#   VERSION_SOURCE     file holding the authoritative version (default: package.json)
#   MIGRATIONS_DIR     migrations to cross-check             (default: supabase/migrations)
#   DELIVERY_BASE      git ref of the last delivery          (default: last tag, else empty)
#   CLIENT_ONLY_PATHS  space-separated paths that exist only downstream
#
# Exit codes (fail-closed):
#   0  the runbook matches this release
#   1  MISMATCH        — a check failed; the document does not describe this release
#   3  NOT_CONFIGURED  — a source this script needs is missing or unreadable

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR" || { echo "verify-delivery-doc: cannot cd to $ROOT_DIR" >&2; exit 3; }

DOC="${DELIVERY_DOC:-README.md}"
HEADING="${DELIVERY_HEADING:-^## Desplegar}"
VERSION_SOURCE="${VERSION_SOURCE:-package.json}"
MIGRATIONS_DIR="${MIGRATIONS_DIR:-supabase/migrations}"
CLIENT_ONLY_PATHS="${CLIENT_ONLY_PATHS:-}"

if [[ ! -t 1 ]] || [[ -n "${NO_COLOR:-}" ]]; then
  RED=""; GREEN=""; YELLOW=""; BOLD=""; RESET=""
else
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
  BOLD=$'\033[1m'; RESET=$'\033[0m'
fi

FAILURES=0
fail() { echo "  ${RED}MISMATCH${RESET} $1"; FAILURES=$((FAILURES+1)); }
ok()   { echo "  ${GREEN}ok${RESET}       $1"; }
skip() { echo "  ${YELLOW}skip${RESET}     $1"; }

[[ -f "$DOC" ]] || { echo "${RED}verify-delivery-doc: $DOC not found${RESET}" >&2; exit 3; }

# ── Does this repository publish a runbook at all? ──────────────────────────
# Not every repo hands a deploy document to someone else, and a gate that fails
# on those is noise that gets silenced — taking the real signal with it. So the
# gate is opt-in by the presence of the heading, and says so out loud when it
# stands down. Set DELIVERY_DOC_REQUIRED=1 in repos that do deliver: there,
# a missing heading is the finding, not a reason to skip.
if ! grep -qE "$HEADING" "$DOC"; then
  if [[ "${DELIVERY_DOC_REQUIRED:-0}" == "1" ]]; then
    echo "${RED}verify-delivery-doc: no «${HEADING}» in $DOC, and this repo declares it delivers one${RESET}" >&2
    exit 1
  fi
  echo "${YELLOW}verify-delivery-doc: skipped${RESET} — no «${HEADING}» section in $DOC."
  echo "  This repo publishes no deploy runbook. If it should, set DELIVERY_DOC_REQUIRED=1."
  exit 0
fi

# ── The version this release actually is ────────────────────────────────────
# Read package.json's "version" without adding a JSON dependency: the field is
# machine-written and the first match at the top level is the package's own.
VERSION=""
if [[ -f "$VERSION_SOURCE" ]]; then
  case "$VERSION_SOURCE" in
    *.json) VERSION="$(sed -n 's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$VERSION_SOURCE" | head -1)" ;;
    *)      VERSION="$(tr -d '[:space:]' < "$VERSION_SOURCE")" ;;
  esac
fi
[[ -n "$VERSION" ]] || { echo "${RED}verify-delivery-doc: no version in $VERSION_SOURCE${RESET}" >&2; exit 3; }

echo "${BOLD}verify-delivery-doc${RESET} — $DOC against version $VERSION"

# The runbook section: from its heading to the next same-level heading.
SECTION="$(awk -v h="$HEADING" '
  $0 ~ h { inside=1; print; next }
  inside && /^## / { exit }
  inside { print }
' "$DOC")"

if [[ -z "$SECTION" ]]; then
  fail "no section matching «${HEADING}» in $DOC — the runbook has no anchor"
  echo ""
  echo "${RED}verify-delivery-doc: 1 mismatch${RESET}"
  exit 1
fi

# ── 1. The heading names this release ───────────────────────────────────────
if grep -qF "$VERSION" <<<"$(head -1 <<<"$SECTION")"; then
  ok "the runbook heading names $VERSION"
else
  fail "the runbook heading does not name $VERSION: $(head -1 <<<"$SECTION")"
fi

# ── 2. Every live version-tagged command uses THIS version ──────────────────
# The failure this catches: several places repeated the tag by hand and went
# stale, one of them a deploy step that would have shipped the wrong image.
#
# Two exclusions, both deliberate. A changelog is a history: each entry citing
# its own tag is correct, so DELIVERY_TAG_DOCS never includes one by default.
# And inside the scanned docs, a line quoted with «>» reads as a record of a past
# release, not an instruction — so blockquoted tags are history too. Everything
# else is a command someone may run today.
read -r -a TAG_DOCS <<<"${DELIVERY_TAG_DOCS:-$DOC ${DELIVERY_EXTRA_DOCS:-}}"
SCANNED=()
for f in "${TAG_DOCS[@]}"; do [[ -f "$f" ]] && SCANNED+=("$f"); done
if [[ "${#SCANNED[@]}" -eq 0 ]]; then
  skip "no delivery docs to scan for version tags"
else
  STALE_TAGS="$(grep -nHE '(ecr-push-tag|docker (build|push)|--tag[= ])[^|]*v?[0-9]+\.[0-9]+\.[0-9]+' "${SCANNED[@]}" 2>/dev/null \
    | grep -vE ':[[:space:]]*>' \
    | grep -vE "v?${VERSION//./\\.}" || true)"
  if [[ -z "$STALE_TAGS" ]]; then
    ok "every live version-tagged command uses $VERSION"
  else
    fail "a version-tagged command does not use $VERSION:"
    while IFS= read -r l; do printf '           %s\n' "$l"; done <<<"$STALE_TAGS"
    echo "           If it documents a past release, quote the line with «>»."
  fi
fi

# ── 3. Each migration new since the last delivery is named in the document ──
BASE="${DELIVERY_BASE:-}"
BASE_WAS_GIVEN=""
[[ -n "$BASE" ]] && BASE_WAS_GIVEN=1
# Preferred source: a receipt written by whatever actually performed the last
# delivery. Guessing the base from commit messages is the kind of inference this
# kit exists to replace — it looks right until the day a message is worded
# differently and the gate silently compares against the wrong point.
if [[ -z "$BASE" ]] && [[ -f .harness/last-delivery ]]; then
  BASE="$(tr -d '[:space:]' < .harness/last-delivery)"
fi
if [[ -z "$BASE" ]]; then
  BASE="$(git describe --tags --abbrev=0 2>/dev/null || true)"
fi
# A base that does not resolve must stop the run, not pass quietly. The first
# version of this gate skipped on an unresolvable ref and reported "no new
# migrations" for a release that shipped one — the exact silence it exists to
# prevent. (A delivery repo's SHA is not a ref here; use a tag or a local SHA.)
if [[ -n "$BASE" ]] && ! git rev-parse --verify --quiet "$BASE" >/dev/null 2>&1; then
  echo "  ${RED}NOT_CONFIGURED${RESET} DELIVERY_BASE «${BASE}» is not a ref in this repository" >&2
  [[ -n "$BASE_WAS_GIVEN" ]] && echo "           A SHA from the delivery repo is not a ref here — use a tag or a local SHA." >&2
  exit 3
fi
if [[ -z "$BASE" ]]; then
  skip "no DELIVERY_BASE and no tag — cannot tell which migrations are new"
elif [[ ! -d "$MIGRATIONS_DIR" ]]; then
  skip "no $MIGRATIONS_DIR — nothing to cross-check"
else
  NEW_MIGRATIONS="$(git diff --name-only --diff-filter=A "$BASE"..HEAD -- "$MIGRATIONS_DIR" 2>/dev/null || true)"
  if [[ -z "$NEW_MIGRATIONS" ]]; then
    ok "no new migrations since $BASE"
  else
    MISSING=""
    while IFS= read -r m; do
      [[ -n "$m" ]] || continue
      # The identifier operators actually type: the leading timestamp.
      id="$(basename "$m" | sed -n 's/^\([0-9]\{6,\}\).*/\1/p')"
      [[ -n "$id" ]] || id="$(basename "$m" .sql)"
      grep -qF "$id" "$DOC" || MISSING="$MISSING $id"
    done <<<"$NEW_MIGRATIONS"
    if [[ -z "$MISSING" ]]; then
      ok "every migration new since $BASE is named in $DOC"
    else
      fail "a migration this release ships is not named in $DOC:$MISSING"
      echo "           Operators run what the document says, not what the folder holds."
    fi
  fi
fi

# ── 4. No section presents an older version as this release ─────────────────
# «### La migración de v1.2.1 (solo si vienen de v1.2.0)» sitting inside a v1.2.5
# runbook reads as current. Past releases belong in a changelog or behind wording
# that dates them.
STALE_SECTIONS="$(grep -nE '^### ' <<<"$SECTION" \
  | grep -E 'v?[0-9]+\.[0-9]+\.[0-9]+' \
  | grep -vF "$VERSION" \
  | grep -viE '^[0-9]+:### (Ya en|Anexo|Histórico|Historico|Previously|Older)' || true)"
if [[ -z "$STALE_SECTIONS" ]]; then
  ok "no subsection presents an older version as this release"
else
  fail "a subsection names another version without dating it as past:"
  while IFS= read -r l; do printf '           %s\n' "$l"; done <<<"$STALE_SECTIONS"
  echo "           Prefix it with «Ya en» / «Previously», or move it to the changelog."
fi

# ── 5. Relative links resolve ───────────────────────────────────────────────
# Excluding paths that exist only in the downstream copy: linking those from here
# is a broken link upstream, which is its own bug and not this one.
BROKEN=""
while IFS= read -r target; do
  [[ -n "$target" ]] || continue
  skip_this=""
  for c in $CLIENT_ONLY_PATHS; do
    case "$target" in "$c"*) skip_this=1 ;; esac
  done
  [[ -n "$skip_this" ]] && continue
  [[ -e "$target" ]] || BROKEN="$BROKEN $target"
done <<<"$(grep -oE '\]\(\./[^)#]+' "$DOC" | sed 's/](\.\///' | sort -u)"
if [[ -z "$BROKEN" ]]; then
  ok "every relative link in $DOC resolves"
else
  fail "a relative link points at nothing:$BROKEN"
fi

echo ""
if [[ "$FAILURES" -eq 0 ]]; then
  echo "${GREEN}verify-delivery-doc: the runbook describes $VERSION${RESET}"
  exit 0
fi
echo "${RED}verify-delivery-doc: $FAILURES mismatch(es)${RESET}"
echo "The document a human follows with production in their hands is out of step"
echo "with the release. Fix the document, not this gate."
exit 1
