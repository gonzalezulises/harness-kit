#!/usr/bin/env bash
# verify-pack.sh — prove that every failure mode still blocks.
#
# The gate is only worth having while each of these cases refuses to pass. This
# script builds a report for each one and asserts the exact exit code, so a
# regression that turns a blocked case green shows up here rather than in a
# delivery.
#
# Reports are synthesised rather than produced by running Cucumber, so the pack
# can be verified anywhere node exists — no npm install, no browser, no network.
# The live path (bin/gherkin-check) is exercised separately when Cucumber is
# available.
#
# Usage: bash packs/gherkin/verify-pack.sh

set -uo pipefail

PACK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE="$PACK_DIR/repo-template/bin/gherkin-validate.mjs"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if [[ ! -t 1 ]] || [[ -n "${NO_COLOR:-}" ]]; then
  RED=""; GREEN=""; BOLD=""; RESET=""
else
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
fi

PASS=0; FAIL=0
ok()  { echo "  ${GREEN}ok${RESET}   $1"; PASS=$((PASS+1)); }
bad() { echo "  ${RED}FAIL${RESET} $1"; FAIL=$((FAIL+1)); }

command -v node >/dev/null 2>&1 || { echo "verify-pack: needs node on PATH" >&2; exit 69; }

# ── Report builders ──────────────────────────────────────────────────────────
step()  { printf '{"testStepFinished":{"testStepResult":{"status":"%s"}}}\n' "$1"; }
case_()  { printf '{"testCaseFinished":{"testCaseStartedId":"%s"}}\n' "$1"; }
pickle() { printf '{"pickle":{"id":"%s","name":"%s","tags":[{"name":"%s"}]}}\n' "$1" "$2" "$3"; }
finish() { printf '{"testRunFinished":{"success":%s}}\n' "${1:-true}"; }

# assert_case <label> <expected-exit> <report-file> [extra args...]
assert_case() {
  local label="$1" want="$2" report="$3"; shift 3
  node "$VALIDATE" "$report" "$@" >/dev/null 2>&1
  local got=$?
  if [[ "$got" == "$want" ]]; then ok "$label (exit $got)"
  else bad "$label — expected exit $want, got $got"; fi
}

echo "${BOLD}Gherkin pack — failure matrix${RESET}"
echo ""

# ── 1. The honest case must pass, or the gate is just a wall ─────────────────
{ pickle p1 "cobra el carrito" "@SCN-001"; step PASSED; step PASSED; case_ t1; finish; } > "$WORK/valid.ndjson"
assert_case "valid run passes" 0 "$WORK/valid.ndjson"
assert_case "valid run passes with a matching --expect" 0 "$WORK/valid.ndjson" --expect 1

# ── 2. Nothing ran, and Cucumber would have exited 0 ─────────────────────────
{ finish; } > "$WORK/zero.ndjson"
assert_case "zero execution blocks" 2 "$WORK/zero.ndjson"

# ── 3. Fewer scenarios than declared — the absolute counter ──────────────────
{ pickle p1 "uno" "@SCN-001"; step PASSED; case_ t1; finish; } > "$WORK/short.ndjson"
assert_case "executing fewer scenarios than declared blocks" 2 "$WORK/short.ndjson" --expect 3

# ── 4-8. Statuses that are not passes ────────────────────────────────────────
for status in FAILED UNDEFINED AMBIGUOUS PENDING SKIPPED; do
  { pickle p1 "s" "@SCN-001"; step PASSED; step "$status"; case_ t1; finish; } > "$WORK/$status.ndjson"
  assert_case "$status blocks" 1 "$WORK/$status.ndjson"
done

# ── 9. Two scenarios claiming the same identity ──────────────────────────────
{ pickle p1 "a" "@SCN-001"; pickle p2 "b" "@SCN-001"; step PASSED; case_ t1; case_ t2; finish; } \
  > "$WORK/dup.ndjson"
assert_case "duplicate scenario id blocks" 1 "$WORK/dup.ndjson"

# ── 10. Malformed report ─────────────────────────────────────────────────────
{ pickle p1 "a" "@SCN-001"; echo '{"testStepFinished": BROKEN'; finish; } > "$WORK/malformed.ndjson"
assert_case "malformed report blocks" 3 "$WORK/malformed.ndjson"

# ── 11. Truncated report: the run died mid-flight ────────────────────────────
{ pickle p1 "a" "@SCN-001"; step PASSED; case_ t1; } > "$WORK/truncated.ndjson"
assert_case "truncated report blocks" 3 "$WORK/truncated.ndjson"

# ── 12. No report at all ─────────────────────────────────────────────────────
assert_case "missing report blocks" 3 "$WORK/does-not-exist.ndjson"

# ── 13. A green report cannot be waved through with a bad expectation ────────
assert_case "--expect rejects a non-numeric argument" 64 "$WORK/valid.ndjson" --expect zero

# ── 14. The validator must run inside an ESM repo, not just a CommonJS one ───
# A bare .js validator parses as ESM under "type": "module" and dies on require().
mkdir -p "$WORK/esm/bin"
cp "$VALIDATE" "$WORK/esm/bin/"
cp "$WORK/valid.ndjson" "$WORK/esm/"
printf '{"name":"esm-host","type":"module"}\n' > "$WORK/esm/package.json"
( cd "$WORK/esm" && node bin/$(basename "$VALIDATE") valid.ndjson >/dev/null 2>&1 )
if [[ $? -eq 0 ]]; then ok "validator runs inside a \"type\": \"module\" repo"
else bad "validator breaks inside an ESM repo (exit $?)"; fi

echo ""
echo "${BOLD}────────────────────────────────────────${RESET}"
echo "${BOLD}$PASS passed, $FAIL failed${RESET}"
if [[ $FAIL -ne 0 ]]; then
  echo "${RED}${BOLD}A failure mode stopped blocking. The gate is not trustworthy until this is green.${RESET}"
  exit 1
fi
echo "${GREEN}${BOLD}Every failure mode blocks.${RESET}"
