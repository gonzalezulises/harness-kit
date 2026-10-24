#!/usr/bin/env bash
# F33 — the PR that installs the gate can pass it, and no later PR can use the same door.
#
# On 2026-10-23, 12 Mallol repos got the lite gate in one PR each. `make check` passed in
# all 12, yet every `Required quality` ended blocked: the claim checker is read from the
# base branch, and on the installing PR the base has none yet (exit 126). The only way to
# merge was overriding a red check, which is the habit the gate exists to remove.
#
# The fix uses the PR's own checker only while the base carries no gate workflow at all.
# The control keeps it honest: with the workflow on the base and its checker gone, the
# step must still refuse with NOT_EXECUTED.
#
# The steps run here are the ones in the template, extracted from the YAML, not a copy,
# under the runner's own shell (`bash -e -o pipefail`): without -e the first version passed
# here and failed in CI on `cp` copying the checker onto itself.
#
# Usage: bash tests/contract/F33-bootstrap-pr-can-pass-the-gate.sh

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_DIR="$(cd "$HERE/../.." && pwd)"
# shellcheck source=tests/contract/lib.sh
. "$HERE/lib.sh"

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
echo "${BOLD}F33 — the bootstrap PR can pass the gate${RESET}"

WF="$KIT_DIR/templates/full/.github/workflows/required-quality.yml"
for id in claims decisions; do
  python3 - "$WF" "$id" > "$WORK/$id.sh" <<'PY' || bad "step '$id' not found in the template"
import sys, yaml
steps = yaml.safe_load(open(sys.argv[1]))["jobs"]["required-quality"]["steps"]
print(next(s["run"] for s in steps if s.get("id") == sys.argv[2]))
PY
done

if grep -q '\.github/workflows/required-quality\.yml' <(python3 -c '
import sys, yaml
steps = yaml.safe_load(open(sys.argv[1]))["jobs"]["required-quality"]["steps"]
print(next(s["with"]["sparse-checkout"] for s in steps if s.get("with", {}).get("path") == "base"))' "$WF"); then
  ok "the base checkout brings the workflow, so the step can tell a bootstrap apart"
else
  bad "the base checkout does not bring the workflow — the bootstrap test reads nothing"
fi

# A workspace laid out like the runner's: head/ is the PR, base/ the sparse base checkout.
layout() {  # layout <dir> <base-has-workflow 0|1> <base-has-checkers 0|1>
  local w="$1"; rm -rf "$w"; mkdir -p "$w/head/scripts" "$w/base/scripts" "$w/tmp"
  cp "$KIT_DIR/templates/full/scripts/verify-claims.sh" "$KIT_DIR/templates/full/scripts/verify-decisions.sh" "$w/head/scripts/"
  printf '%s\n' '{"version":1,"features":[]}' > "$w/head/feature_list.json"
  printf '%s\n' '# Decisions' > "$w/head/DECISIONS.md"
  git -C "$w/head" init -q
  if [[ "$2" == 1 ]]; then mkdir -p "$w/base/.github/workflows"; : > "$w/base/.github/workflows/required-quality.yml"; fi
  if [[ "$3" == 1 ]]; then cp "$w/head/scripts/"*.sh "$w/base/scripts/"; cp "$w/head/feature_list.json" "$w/head/DECISIONS.md" "$w/base/"; fi
}
run_step() {  # run_step <dir> <claims|decisions>
  ( cd "$1" && GITHUB_WORKSPACE="$1" GITHUB_OUTPUT="$1/out" RUNNER_TEMP="$1/tmp" \
      CLAIMS_BASE_FILE="$1/base/feature_list.json" DECISIONS_BASE_FILE="$1/base/DECISIONS.md" \
      bash --noprofile --norc -e -o pipefail "$WORK/$2.sh" 2>&1 )  # the runner's shell
}

for id in claims decisions; do
  layout "$WORK/boot" 0 0
  O="$(run_step "$WORK/boot" "$id")"; RC=$?
  if [[ $RC -eq 0 ]] && [[ "$O" == *BOOTSTRAP* ]]; then ok "$id: a PR installing the gate passes, and says it is a bootstrap"
  else bad "$id: the installing PR is still blocked (exit $RC): ${O:0:160}"; fi

  layout "$WORK/gone" 1 0
  O="$(run_step "$WORK/gone" "$id")"; RC=$?
  if [[ $RC -eq 126 ]] && [[ "$O" == *NOT_EXECUTED* ]] && [[ "$O" != *BOOTSTRAP* ]]; then
    ok "$id: with the gate on the base, a missing checker is still NOT_EXECUTED (control)"
  else bad "$id: a governed base with no checker let the PR use its own (exit $RC)"; fi

  layout "$WORK/norm" 1 1
  O="$(run_step "$WORK/norm" "$id")"; RC=$?
  if [[ $RC -eq 0 ]] && [[ "$O" != *BOOTSTRAP* ]]; then ok "$id: a normal PR uses the protected base checker"
  else bad "$id: a normal PR did not pass on the base checker (exit $RC): ${O:0:160}"; fi
done

finish "F33"
