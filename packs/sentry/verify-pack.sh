#!/usr/bin/env bash
# verify-pack.sh — prove that every failure mode still blocks.
#
# An observability gate earns its place only while each of these cases refuses
# to pass. The dangerous ones are not the loud failures; they are the quiet
# configurations that leave the build green and the project empty: a DSN that is
# still the one from the documentation, a sample rate of zero, an event that the
# ingest endpoint accepts and then drops.
#
# Responses are synthesised rather than fetched, so the pack can be verified
# anywhere bash exists — no Sentry account, no auth token, no network. The live
# path is exercised by bin/sentry-check itself once a project has a real DSN.
#
# Usage: bash packs/sentry/verify-pack.sh

set -uo pipefail

PACK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$PACK_DIR/repo-template/bin/sentry-check"
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

[[ -f "$GATE" ]] || { echo "verify-pack: gate not found at $GATE" >&2; exit 69; }

GOOD_DSN="https://0123456789abcdef0123456789abcdef@o4507.ingest.us.sentry.io/4507"
SANDBOX="$WORK/app"
mkdir -p "$SANDBOX"
STUB_N=0
STUB_DIR=""

# A stub directory stands in for the network. A fixture that is absent means the
# call failed — the same thing the gate must survive when Sentry is unreachable.
stub() {
  STUB_N=$((STUB_N + 1))
  STUB_DIR="$WORK/stub$STUB_N"
  mkdir -p "$STUB_DIR"
}

# assert <label> <expected-exit> <VAR=value...> -- <gate args...>
assert() {
  local label="$1" want="$2" got
  shift 2
  local envs=()
  while [[ $# -gt 0 && "$1" != "--" ]]; do envs+=("$1"); shift; done
  shift
  ( cd "$SANDBOX" && env "${envs[@]}" "$GATE" "$@" ) >/dev/null 2>&1
  got=$?
  if [[ "$got" == "$want" ]]; then ok "$label (exit $got)"
  else bad "$label — expected exit $want, got $got"; fi
}

echo "${BOLD}Sentry pack — failure matrix${RESET}"
echo ""

# ── 1. The honest case must pass, or the gate is just a wall ─────────────────
assert "a real DSN passes preflight" 0 \
  NO_COLOR=1 "SENTRY_DSN=$GOOD_DSN" -- preflight

# ── 2-5. Configurations the SDK accepts and then ignores ─────────────────────
assert "an absent DSN blocks" 1 \
  NO_COLOR=1 SENTRY_DSN= -- preflight

assert "a malformed DSN blocks" 1 \
  NO_COLOR=1 "SENTRY_DSN=not-a-dsn" -- preflight

assert "a non-numeric project id blocks" 1 \
  NO_COLOR=1 "SENTRY_DSN=https://abcdef0123456789@o1.ingest.sentry.io/PROJECT_ID" -- preflight

assert "the placeholder DSN from the docs blocks" 1 \
  NO_COLOR=1 "SENTRY_DSN=https://examplePublicKey@o0.ingest.sentry.io/0" -- preflight

# ── 6. A supported setting that discards every event ─────────────────────────
assert "a sample rate of 0 blocks" 1 \
  NO_COLOR=1 "SENTRY_DSN=$GOOD_DSN" SENTRY_SAMPLE_RATE=0 -- preflight

# ── 7-8. Next.js server errors reach Sentry only via onRequestError ──────────
printf 'export async function register() {}\n' > "$SANDBOX/instrumentation.ts"
assert "instrumentation.ts without onRequestError blocks" 1 \
  NO_COLOR=1 "SENTRY_DSN=$GOOD_DSN" -- preflight

printf 'export const onRequestError = Sentry.captureRequestError;\n' > "$SANDBOX/instrumentation.ts"
assert "instrumentation.ts with onRequestError passes" 0 \
  NO_COLOR=1 "SENTRY_DSN=$GOOD_DSN" -- preflight
rm -f "$SANDBOX/instrumentation.ts"

# ── 9. Ingest refuses the event ──────────────────────────────────────────────
stub
assert "an ingest endpoint that refuses the event blocks" 1 \
  NO_COLOR=1 "SENTRY_DSN=$GOOD_DSN" SENTRY_ORG=acme SENTRY_PROJECT=web \
  SENTRY_AUTH_TOKEN=t "SENTRY_STUB_DIR=$STUB_DIR" -- canary

# ── 10. THE case this pack exists for: accepted, then silently dropped ───────
# Quotas, inbound filters and rate limits all drop events after a 200 response.
stub
touch "$STUB_DIR/ingest-ok"
printf '[]\n' > "$STUB_DIR/issues.json"
assert "an event accepted but never stored blocks as UNCONFIRMED" 2 \
  NO_COLOR=1 "SENTRY_DSN=$GOOD_DSN" SENTRY_ORG=acme SENTRY_PROJECT=web \
  SENTRY_AUTH_TOKEN=t "SENTRY_STUB_DIR=$STUB_DIR" -- canary

# ── 11. The canary is not a wall either: an event read back passes ───────────
stub
touch "$STUB_DIR/ingest-ok"
cat > "$STUB_DIR/issues.json" <<'EOF'
[{"id":"1","title":"canary","culprit":"harness-canary-MARKER"}]
EOF
assert "an event that comes back with its own marker passes" 0 \
  NO_COLOR=1 "SENTRY_DSN=$GOOD_DSN" SENTRY_ORG=acme SENTRY_PROJECT=web \
  SENTRY_AUTH_TOKEN=t "SENTRY_STUB_DIR=$STUB_DIR" \
  SENTRY_CANARY_MARKER=harness-canary-MARKER -- canary

# ── 12. It must match ITS OWN marker, not merely a well-formed issue list ────
stub
touch "$STUB_DIR/ingest-ok"
cat > "$STUB_DIR/issues.json" <<'EOF'
[{"id":"9","title":"an unrelated error","culprit":"somebody-elses-issue"}]
EOF
assert "an issue list without this run's marker blocks" 2 \
  NO_COLOR=1 "SENTRY_DSN=$GOOD_DSN" SENTRY_ORG=acme SENTRY_PROJECT=web \
  SENTRY_AUTH_TOKEN=t "SENTRY_STUB_DIR=$STUB_DIR" \
  SENTRY_CANARY_MARKER=harness-canary-MARKER -- canary

# ── 13. An unreadable response is not a pass ─────────────────────────────────
stub
touch "$STUB_DIR/ingest-ok"
printf '<html>502 Bad Gateway</html>\n' > "$STUB_DIR/issues.json"
assert "a non-JSON response blocks" 3 \
  NO_COLOR=1 "SENTRY_DSN=$GOOD_DSN" SENTRY_ORG=acme SENTRY_PROJECT=web \
  SENTRY_AUTH_TOKEN=t "SENTRY_STUB_DIR=$STUB_DIR" -- canary

# ── 14-15. The canary cannot silently skip its own read-back ─────────────────
stub
touch "$STUB_DIR/ingest-ok"
assert "a canary without SENTRY_ORG blocks instead of skipping" 3 \
  NO_COLOR=1 "SENTRY_DSN=$GOOD_DSN" SENTRY_AUTH_TOKEN=t \
  "SENTRY_STUB_DIR=$STUB_DIR" -- canary

assert "a canary without an auth token blocks instead of skipping" 3 \
  NO_COLOR=1 "SENTRY_DSN=$GOOD_DSN" SENTRY_ORG=acme SENTRY_PROJECT=web \
  "SENTRY_STUB_DIR=$STUB_DIR" -- canary

# ── 16-19. A release without source maps is a notification, not a stack trace ─
stub
assert "a release that does not exist blocks" 1 \
  NO_COLOR=1 SENTRY_ORG=acme SENTRY_AUTH_TOKEN=t \
  "SENTRY_STUB_DIR=$STUB_DIR" -- release v1.0.0

stub
printf '[]\n' > "$STUB_DIR/files.json"
assert "a release with no uploaded files blocks" 1 \
  NO_COLOR=1 SENTRY_ORG=acme SENTRY_AUTH_TOKEN=t \
  "SENTRY_STUB_DIR=$STUB_DIR" -- release v1.0.0

stub
printf '[{"name":"~/app.js"}]\n' > "$STUB_DIR/files.json"
assert "a release with files but no source map blocks" 1 \
  NO_COLOR=1 SENTRY_ORG=acme SENTRY_AUTH_TOKEN=t \
  "SENTRY_STUB_DIR=$STUB_DIR" -- release v1.0.0

stub
printf '[{"name":"~/app.js"},{"name":"~/app.js.map"}]\n' > "$STUB_DIR/files.json"
assert "a release with source maps passes" 0 \
  NO_COLOR=1 SENTRY_ORG=acme SENTRY_AUTH_TOKEN=t \
  "SENTRY_STUB_DIR=$STUB_DIR" -- release v1.0.0

# ── 20-21. Usage errors are not silent successes ─────────────────────────────
assert "an unknown command is a usage error" 64 NO_COLOR=1 -- frobnicate
assert "release without a version is a usage error" 64 NO_COLOR=1 -- release

echo ""
echo "${BOLD}────────────────────────────────────────${RESET}"
echo "${BOLD}$PASS passed, $FAIL failed${RESET}"
if [[ $FAIL -ne 0 ]]; then
  echo "${RED}${BOLD}A failure mode stopped blocking. The gate is not trustworthy until this is green.${RESET}"
  exit 1
fi
echo "${GREEN}${BOLD}Every failure mode blocks.${RESET}"
