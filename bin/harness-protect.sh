#!/usr/bin/env bash
# harness-protect.sh — install the rulesets that make the quality gate binding,
# then read them back and prove they are actually active.
#
# Usage:
#   bin/harness-protect.sh <owner/repo> [--repo-dir DIR] [--dry-run]
#
# Why two rulesets:
#
#   required-quality-check      requires the "Required quality" check to pass.
#   required-quality-integrity  forbids pushing to the workflow file at all.
#
# The second one is not optional. GitHub treats a job skipped by its own
# job-level condition as a SUCCESSFUL required check, so a PR that adds
# `if: false` to the job merges green while appearing fully gated. Requiring the
# check name protects the result; only the push restriction protects the
# definition that produces it.
#
# Creating a ruleset is a claim. This script does a GET afterwards and fails if
# the live rule is not `active` with zero bypass actors, so what it prints is a
# receipt.
#
# Requires: gh (authenticated), python3.
# Minimum verified plan for the integrity rule: GitHub Team, organization-owned
# repository. Personal accounts cannot create organization required workflows
# (measured: HTTP 422) and private repos on Free cannot create rulesets (HTTP 403).

set -uo pipefail

if [[ ! -t 1 ]] || [[ -n "${NO_COLOR:-}" ]]; then
  RED=""; GREEN=""; YELLOW=""; BOLD=""; RESET=""
else
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
  BOLD=$'\033[1m'; RESET=$'\033[0m'
fi

REPO=""
REPO_DIR="."
DRYRUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-dir) REPO_DIR="$2"; shift 2 ;;
    --dry-run)  DRYRUN=1; shift ;;
    -h|--help)  sed -n '2,26p' "$0"; exit 0 ;;
    -*)         echo "harness-protect: unknown flag: $1" >&2; exit 64 ;;
    *)          REPO="$1"; shift ;;
  esac
done

[[ -n "$REPO" ]] || { echo "usage: $0 <owner/repo> [--repo-dir DIR] [--dry-run]" >&2; exit 64; }
command -v gh      >/dev/null 2>&1 || { echo "harness-protect: needs the gh CLI" >&2; exit 69; }
command -v python3 >/dev/null 2>&1 || { echo "harness-protect: needs python3" >&2; exit 69; }

RULESET_DIR="$REPO_DIR/.github/rulesets"
[[ -d "$RULESET_DIR" ]] || {
  echo "harness-protect: no $RULESET_DIR — scaffold with harness-init.sh --level full" >&2
  exit 66
}

FAILED=0

install_one() {
  # install_one <payload-path>
  local payload="$1" name body existing method endpoint
  name="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['name'])" "$payload")"

  # The API rejects unknown fields, so the explanatory _comment is stripped here
  # rather than kept out of the file: the file is meant to be read by humans too.
  body="$(python3 - "$payload" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
d.pop("_comment", None)
print(json.dumps(d))
PYEOF
)"

  echo ""
  echo "${BOLD}── $name${RESET}"

  if [[ $DRYRUN -eq 1 ]]; then
    echo "  would install into $REPO"
    return 0
  fi

  # Idempotent: update in place when a ruleset with this name already exists.
  existing="$(gh api "repos/$REPO/rulesets" --jq \
    ".[] | select(.name == \"$name\") | .id" 2>/dev/null | head -1)"

  if [[ -n "$existing" ]]; then
    method=PUT; endpoint="repos/$REPO/rulesets/$existing"
    echo "  updating existing ruleset $existing"
  else
    method=POST; endpoint="repos/$REPO/rulesets"
    echo "  creating"
  fi

  if ! printf '%s' "$body" | gh api -X "$method" "$endpoint" --input - >/dev/null 2>"$RULESET_DIR/.protect-err"; then
    echo "  ${RED}FAILED${RESET} — $(head -3 "$RULESET_DIR/.protect-err" | tr '\n' ' ')"
    echo "  A 403 means the plan does not allow rulesets here; a 422 means the rule"
    echo "  type is unavailable for this owner. Neither is something to work around:"
    echo "  move the repository to an organization on a plan that supports it."
    rm -f "$RULESET_DIR/.protect-err"
    FAILED=$((FAILED + 1))
    return 1
  fi
  rm -f "$RULESET_DIR/.protect-err"

  # ── The receipt: read the live rule back and check it says what we asked for.
  local live
  live="$(gh api "repos/$REPO/rulesets" --jq \
    ".[] | select(.name == \"$name\") | \"\(.id)|\(.enforcement)|\(.target)\"" 2>/dev/null | head -1)"

  if [[ -z "$live" ]]; then
    echo "  ${RED}NOT_VERIFIED${RESET} — the ruleset does not appear in a follow-up GET."
    FAILED=$((FAILED + 1))
    return 1
  fi

  local live_id live_enf live_target bypass
  IFS='|' read -r live_id live_enf live_target <<< "$live"
  bypass="$(gh api "repos/$REPO/rulesets/$live_id" --jq '.bypass_actors | length' 2>/dev/null)"

  if [[ "$live_enf" != "active" ]]; then
    echo "  ${RED}NOT_ACTIVE${RESET} — ruleset $live_id is '$live_enf', not 'active'."
    FAILED=$((FAILED + 1)); return 1
  fi
  if [[ "${bypass:-1}" != "0" ]]; then
    echo "  ${RED}BYPASS_PRESENT${RESET} — ruleset $live_id has $bypass bypass actor(s)."
    echo "  A gate with a bypass actor is a suggestion. Remove them."
    FAILED=$((FAILED + 1)); return 1
  fi

  echo "  ${GREEN}verified${RESET}  id=$live_id  target=$live_target  enforcement=$live_enf  bypass_actors=0"
  return 0
}

echo "${BOLD}Protecting $REPO${RESET}"
for payload in "$RULESET_DIR"/required-quality-check.json \
               "$RULESET_DIR"/required-quality-integrity.json; do
  if [[ -f "$payload" ]]; then
    install_one "$payload"
  else
    echo ""
    echo "${YELLOW}skip${RESET} $(basename "$payload") — not present"
  fi
done

echo ""
if [[ "$FAILED" -gt 0 ]]; then
  echo "${RED}${BOLD}$FAILED ruleset(s) are not verifiably active.${RESET}"
  echo "The gate is NOT binding until both appear above as verified."
  exit 1
fi

if [[ $DRYRUN -eq 1 ]]; then
  echo "${YELLOW}Dry run — nothing was installed.${RESET}"
  exit 0
fi

echo "${GREEN}${BOLD}Both rulesets are active with no bypass actors.${RESET}"
echo "Next: open a PR that breaks a test and confirm it cannot merge."
