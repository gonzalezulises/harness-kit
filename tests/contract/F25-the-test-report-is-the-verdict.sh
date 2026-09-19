#!/usr/bin/env bash
# F25 — a test run is judged by its report, not by its exit code.
#
# The kit learned this twice and encoded it per tool: Cucumber exits 0 with zero
# scenarios (packs/gherkin → ZERO_EXECUTION), k6 exits 0 on a broken script. The
# same hole is open for every other runner a consumer uses: a renamed directory, a
# filter that matches nothing, a config that excludes everything — `npm test` and
# `pytest` exit 0 and `make check` reports a verification that never happened.
#
# Generalised here over JUnit XML, which vitest, jest, pytest, go-junit-report and
# Playwright can all emit. The floor is a receipt: `.harness/test-baseline.json` is
# written by the harness on a green run, never by hand, and the count may only go
# down through F24's ledger entry.
#
# Proposed contract: `scripts/verify-test-report.sh <junit.xml>`
#   0 PASS · 1 FAIL (failures, or fewer tests than the baseline)
#   2 ZERO_EXECUTION / skipped present · 4 INCOMPLETE (no report to read)
#
# Usage: bash tests/contract/F25-the-test-report-is-the-verdict.sh

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_DIR="$(cd "$HERE/../.." && pwd)"
# shellcheck source=tests/contract/lib.sh
. "$HERE/lib.sh"

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
echo "${BOLD}F25 — the test report is the verdict${RESET}"

GATE="$KIT_DIR/templates/full/scripts/verify-test-report.sh"
if [[ ! -f "$GATE" ]]; then
  bad "templates/full/scripts/verify-test-report.sh does not exist — exit codes are still trusted"
  finish "F25"
fi

new_repo "$WORK/repo"; mkdir -p scripts .harness reports
cp "$GATE" scripts/verify-test-report.sh

junit() { # junit <file> <tests> <failures> <skipped>
  { printf '<?xml version="1.0"?>\n<testsuites tests="%s" failures="%s" skipped="%s">\n' "$2" "$3" "$4"
    printf '  <testsuite name="s" tests="%s" failures="%s" skipped="%s">\n' "$2" "$3" "$4"
    i=0; while [[ $i -lt $2 ]]; do printf '    <testcase classname="s" name="t%s"/>\n' "$i"; i=$((i+1)); done
    printf '  </testsuite>\n</testsuites>\n'; } > "$1"
}
gate() { bash scripts/verify-test-report.sh "$1" >/dev/null 2>&1; }

junit reports/green.xml 12 0 0
gate reports/green.xml;   expect_zero    "control: 12 executed, 0 failed, 0 skipped passes" $?

junit reports/zero.xml 0 0 0
gate reports/zero.xml;    expect_nonzero "zero tests executed blocks, whatever the runner exited with" $?

junit reports/skipped.xml 12 0 3
gate reports/skipped.xml; expect_nonzero "skipped tests block — they verified nothing" $?

junit reports/failed.xml 12 1 0
gate reports/failed.xml;  expect_nonzero "a failure in the report blocks even if the runner exited 0" $?

gate reports/missing.xml; expect_nonzero "no report to read is INCOMPLETE, never a pass" $?

echo '<testsuites tests="12"' > reports/broken.xml
gate reports/broken.xml;  expect_nonzero "an unparseable report does not pass" $?

# ── the floor: fewer tests than the last green run ───────────────────────────
printf '%s\n' '{"tests": 12, "written_by": "harness"}' > .harness/test-baseline.json
junit reports/shrunk.xml 9 0 0
gate reports/shrunk.xml;  expect_nonzero "fewer tests than the recorded baseline blocks" $?
junit reports/grown.xml 15 0 0
gate reports/grown.xml;   expect_zero    "more tests than the baseline passes" $?

finish "F25"
