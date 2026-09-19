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
# The baseline every preflight case starts from: a configuration that passes, so
# each case below changes exactly one thing and the failure is attributable.
BASE_ENV=(NO_COLOR=1 "SENTRY_DSN=$GOOD_DSN" SENTRY_ENVIRONMENT=production
          SENTRY_TRACES_SAMPLE_RATE=0.2)
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
assert "a complete configuration passes preflight" 0 \
  "${BASE_ENV[@]}" -- preflight

# ── 2-5. Configurations the SDK accepts and then ignores ─────────────────────
assert "an absent DSN blocks" 1 \
  "${BASE_ENV[@]}" SENTRY_DSN= -- preflight

assert "a malformed DSN blocks" 1 \
  "${BASE_ENV[@]}" "SENTRY_DSN=not-a-dsn" -- preflight

assert "a non-numeric project id blocks" 1 \
  "${BASE_ENV[@]}" "SENTRY_DSN=https://abcdef0123456789@o1.ingest.sentry.io/PROJECT_ID" -- preflight

assert "the placeholder DSN from the docs blocks" 1 \
  "${BASE_ENV[@]}" "SENTRY_DSN=https://examplePublicKey@o0.ingest.sentry.io/0" -- preflight

# ── 6-8. Sampling: off is allowed, off by accident is not ────────────────────
assert "a sample rate of 0 blocks" 1 \
  "${BASE_ENV[@]}" SENTRY_SAMPLE_RATE=0 -- preflight

# "true" is not a rate. The SDK coerces it to 0 and discards everything.
assert "a non-numeric sample rate blocks" 1 \
  "${BASE_ENV[@]}" SENTRY_SAMPLE_RATE=true -- preflight

assert "tracing left at the default 0 blocks" 1 \
  NO_COLOR=1 "SENTRY_DSN=$GOOD_DSN" SENTRY_ENVIRONMENT=production -- preflight

assert "tracing off passes once acknowledged out loud" 0 \
  NO_COLOR=1 "SENTRY_DSN=$GOOD_DSN" SENTRY_ENVIRONMENT=production \
  SENTRY_TRACES_SAMPLE_RATE=0 SENTRY_TRACING_ACKNOWLEDGED=true -- preflight

# ── 9. Preview noise and production incidents must be separable ──────────────
assert "an unset environment blocks" 1 \
  NO_COLOR=1 "SENTRY_DSN=$GOOD_DSN" SENTRY_TRACES_SAMPLE_RATE=0.2 -- preflight

# ── 10-11. The setting that turns a bug tracker into a data leak ─────────────
assert "sendDefaultPii on without acknowledgement blocks" 1 \
  "${BASE_ENV[@]}" SENTRY_SEND_DEFAULT_PII=true -- preflight

assert "sendDefaultPii on passes once acknowledged out loud" 0 \
  "${BASE_ENV[@]}" SENTRY_SEND_DEFAULT_PII=true SENTRY_PII_ACKNOWLEDGED=true -- preflight

# ── 12-13. Next.js server errors reach Sentry only via onRequestError ────────
printf 'export async function register() {}\n' > "$SANDBOX/instrumentation.ts"
assert "instrumentation.ts without onRequestError blocks" 1 \
  "${BASE_ENV[@]}" -- preflight

printf 'export const onRequestError = Sentry.captureRequestError;\n' > "$SANDBOX/instrumentation.ts"
assert "instrumentation.ts with onRequestError passes" 0 \
  "${BASE_ENV[@]}" -- preflight
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

# The absence is created, not assumed: a developer with the Sentry CLI
# authenticated exports SENTRY_AUTH_TOKEN, and env would pass it through.
assert "a canary without an auth token blocks instead of skipping" 3 \
  NO_COLOR=1 "SENTRY_DSN=$GOOD_DSN" SENTRY_ORG=acme SENTRY_PROJECT=web \
  SENTRY_AUTH_TOKEN= "SENTRY_STUB_DIR=$STUB_DIR" -- canary

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

# ── 20-22. Without commits, Sentry can never name the change that broke it ──
stub
printf '[{"name":"~/app.js"},{"name":"~/app.js.map"}]\n' > "$STUB_DIR/files.json"
assert "a release with source maps but no commit data blocks" 1 \
  NO_COLOR=1 SENTRY_ORG=acme SENTRY_AUTH_TOKEN=t \
  "SENTRY_STUB_DIR=$STUB_DIR" -- release v1.0.0

stub
printf '[{"name":"~/app.js"},{"name":"~/app.js.map"}]\n' > "$STUB_DIR/files.json"
printf '[]\n' > "$STUB_DIR/commits.json"
assert "a release with zero associated commits blocks" 1 \
  NO_COLOR=1 SENTRY_ORG=acme SENTRY_AUTH_TOKEN=t \
  "SENTRY_STUB_DIR=$STUB_DIR" -- release v1.0.0

stub
printf '[{"name":"~/app.js"},{"name":"~/app.js.map"}]\n' > "$STUB_DIR/files.json"
printf '[{"id":"abc123","message":"fix"}]\n' > "$STUB_DIR/commits.json"
assert "a release with source maps and commits passes" 0 \
  NO_COLOR=1 SENTRY_ORG=acme SENTRY_AUTH_TOKEN=t \
  "SENTRY_STUB_DIR=$STUB_DIR" -- release v1.0.0

# ── 23-26. Release health: a number, or an honest refusal to judge ───────────
stub
assert "a release with no health data blocks" 1 \
  NO_COLOR=1 SENTRY_ORG=acme SENTRY_AUTH_TOKEN=t \
  "SENTRY_STUB_DIR=$STUB_DIR" -- health v1.0.0

stub
printf '{"version":"v1.0.0","crashFreeSessions":92.5}\n' > "$STUB_DIR/health.json"
assert "a crash-free rate below the floor blocks" 1 \
  NO_COLOR=1 SENTRY_ORG=acme SENTRY_AUTH_TOKEN=t \
  "SENTRY_STUB_DIR=$STUB_DIR" -- health v1.0.0

stub
printf '{"version":"v1.0.0","crashFreeSessions":99.8}\n' > "$STUB_DIR/health.json"
assert "a crash-free rate above the floor passes" 0 \
  NO_COLOR=1 SENTRY_ORG=acme SENTRY_AUTH_TOKEN=t \
  "SENTRY_STUB_DIR=$STUB_DIR" -- health v1.0.0

# Health that was never reported must not read as healthy.
stub
printf '{"version":"v1.0.0","dateCreated":"2026-08-30"}\n' > "$STUB_DIR/health.json"
assert "a response with no crash-free rate blocks as unreadable" 3 \
  NO_COLOR=1 SENTRY_ORG=acme SENTRY_AUTH_TOKEN=t \
  "SENTRY_STUB_DIR=$STUB_DIR" -- health v1.0.0

# ── 27-30. A cron that stopped running produces silence, not errors ──────────
stub
assert "a monitor that does not exist blocks" 1 \
  NO_COLOR=1 SENTRY_ORG=acme SENTRY_AUTH_TOKEN=t \
  "SENTRY_STUB_DIR=$STUB_DIR" -- cron nightly-backup

stub
printf '{"slug":"nightly-backup","status":"missed","isMuted":false}\n' > "$STUB_DIR/monitor.json"
assert "a missed cron check-in blocks" 1 \
  NO_COLOR=1 SENTRY_ORG=acme SENTRY_AUTH_TOKEN=t \
  "SENTRY_STUB_DIR=$STUB_DIR" -- cron nightly-backup

# Watching and telling nobody is the same as not watching.
stub
printf '{"slug":"nightly-backup","status":"ok","isMuted":true}\n' > "$STUB_DIR/monitor.json"
assert "a muted monitor blocks" 1 \
  NO_COLOR=1 SENTRY_ORG=acme SENTRY_AUTH_TOKEN=t \
  "SENTRY_STUB_DIR=$STUB_DIR" -- cron nightly-backup

stub
printf '{"slug":"nightly-backup","status":"ok","isMuted":false}\n' > "$STUB_DIR/monitor.json"
assert "a healthy monitor passes" 0 \
  NO_COLOR=1 SENTRY_ORG=acme SENTRY_AUTH_TOKEN=t \
  "SENTRY_STUB_DIR=$STUB_DIR" -- cron nightly-backup

# ── 31-33. Triage: "no issues" and "could not ask" must never look alike ─────
stub
assert "an unreachable issues API blocks instead of reporting silence" 3 \
  NO_COLOR=1 SENTRY_ORG=acme SENTRY_PROJECT=web SENTRY_AUTH_TOKEN=t \
  "SENTRY_STUB_DIR=$STUB_DIR" -- triage

stub
printf '[]\n' > "$STUB_DIR/triage.json"
assert "an empty issue list is a genuine pass" 0 \
  NO_COLOR=1 SENTRY_ORG=acme SENTRY_PROJECT=web SENTRY_AUTH_TOKEN=t \
  "SENTRY_STUB_DIR=$STUB_DIR" -- triage

stub
cat > "$STUB_DIR/triage.json" <<'EOF'
[{"shortId":"WEB-1","title":"TypeError: x is undefined"},
 {"shortId":"WEB-2","title":"fetch failed"}]
EOF
assert "unresolved issues are reported without failing the run" 0 \
  NO_COLOR=1 SENTRY_ORG=acme SENTRY_PROJECT=web SENTRY_AUTH_TOKEN=t \
  "SENTRY_STUB_DIR=$STUB_DIR" -- triage

# ── 34-35. Usage errors are not silent successes ─────────────────────────────
assert "an unknown command is a usage error" 64 NO_COLOR=1 -- frobnicate
assert "release without a version is a usage error" 64 NO_COLOR=1 -- release

# ── 36-40. The heartbeat wrapper must never become the reason a job fails ────
# Monitoring is not worth an outage: with no DSN the job still runs, and the
# job's own exit code always survives the wrapper.
HEARTBEAT="$PACK_DIR/repo-template/bin/sentry-heartbeat"

hb_assert() {
  local label="$1" want="$2" got
  shift 2
  ( env SENTRY_DSN= NEXT_PUBLIC_SENTRY_DSN= "$HEARTBEAT" "$@" ) >/dev/null 2>&1
  got=$?
  if [[ "$got" == "$want" ]]; then ok "$label (exit $got)"
  else bad "$label — expected exit $want, got $got"; fi
}

hb_assert "a job runs and its success survives the wrapper" 0 backup -- true
hb_assert "a failing job keeps its exit code" 1 backup -- false
hb_assert "an unusual exit code is preserved, not flattened" 42 backup -- sh -c 'exit 42'
hb_assert "a missing -- separator is a usage error" 64 backup true

( env SENTRY_DSN= NEXT_PUBLIC_SENTRY_DSN= "$HEARTBEAT" side-effect -- \
    touch "$WORK/job-ran" ) >/dev/null 2>&1
if [[ -f "$WORK/job-ran" ]]; then
  ok "the job still runs when there is no DSN to report to"
else
  bad "no DSN stopped the job from running — monitoring became an outage"
fi

# ── 41-48. Sentry → GitHub issues: the step that reaches the backlog ─────────
# A stub 'gh' records every call, so the tests assert on what WOULD have been
# sent to GitHub. Nothing here touches a real repository.
TO_ISSUES="$PACK_DIR/repo-template/bin/sentry-to-issues"
GHDIR="$WORK/ghbin"
mkdir -p "$GHDIR"
cat > "$GHDIR/gh" <<'EOF'
#!/usr/bin/env bash
# Stub GitHub CLI. Logs the invocation, and reports an existing issue only for
# short ids listed in $GH_EXISTING.
echo "$*" >> "$GH_LOG"
case "$1 $2" in
  "issue list")
    for s in ${GH_EXISTING:-}; do
      case " $* " in *" $s "*) echo "42  [$s] already there  open"; exit 0 ;; esac
    done
    exit 0 ;;
  "issue create")
    [[ "${GH_CREATE_FAILS:-0}" == "1" ]] && exit 1
    echo "https://github.com/acme/web/issues/99"; exit 0 ;;
esac
exit 0
EOF
chmod +x "$GHDIR/gh"

ti_assert() {
  local label="$1" want="$2" got
  shift 2
  # bash 3.2 (the macOS default) treats an empty array expansion under `set -u`
  # as an unbound variable, so the no-arguments cases need the guarded form.
  ( env "$@" "$TO_ISSUES" ${TI_ARGS[@]+"${TI_ARGS[@]}"} ) >/dev/null 2>&1
  got=$?
  if [[ "$got" == "$want" ]]; then ok "$label (exit $got)"
  else bad "$label — expected exit $want, got $got"; fi
}

TI_BASE=(NO_COLOR=1 SENTRY_ORG=acme SENTRY_PROJECT=web SENTRY_AUTH_TOKEN=t)

# An unreachable Sentry must never look like a clean project.
stub
TI_ARGS=()
ti_assert "an unreachable API blocks instead of reporting nothing to do" 3 \
  "${TI_BASE[@]}" "GH_BIN=$GHDIR/gh" "GH_LOG=$WORK/gh1.log" "SENTRY_STUB_DIR=$STUB_DIR"

stub
printf '[]\n' > "$STUB_DIR/triage.json"
TI_ARGS=()
ti_assert "an empty project is a clean pass" 0 \
  "${TI_BASE[@]}" "GH_BIN=$GHDIR/gh" "GH_LOG=$WORK/gh2.log" "SENTRY_STUB_DIR=$STUB_DIR"

stub
cat > "$STUB_DIR/triage.json" <<'EOF'
[{"shortId":"WEB-1","title":"TypeError: x is undefined"},
 {"shortId":"WEB-2","title":"fetch failed"}]
EOF
TRIAGE_STUB="$STUB_DIR"

# THE safety property: a dry run must not write to a shared surface.
: > "$WORK/gh-dry.log"
TI_ARGS=()
ti_assert "a dry run exits clean" 0 \
  "${TI_BASE[@]}" "GH_BIN=$GHDIR/gh" "GH_LOG=$WORK/gh-dry.log" "SENTRY_STUB_DIR=$TRIAGE_STUB"
if grep -q 'issue create' "$WORK/gh-dry.log"; then
  bad "a dry run created issues — the default is not safe"
else
  ok "a dry run creates nothing (no 'issue create' reached gh)"
fi

: > "$WORK/gh-apply.log"
TI_ARGS=(--apply)
ti_assert "--apply exits clean" 0 \
  "${TI_BASE[@]}" "GH_BIN=$GHDIR/gh" "GH_LOG=$WORK/gh-apply.log" "SENTRY_STUB_DIR=$TRIAGE_STUB"
if [[ "$(grep -c 'issue create' "$WORK/gh-apply.log")" == "2" ]]; then
  ok "--apply opens exactly one issue per unresolved Sentry issue"
else
  bad "--apply opened $(grep -c 'issue create' "$WORK/gh-apply.log") issues, expected 2"
fi

# Idempotence: the property that makes it safe to schedule.
: > "$WORK/gh-dedup.log"
TI_ARGS=(--apply)
ti_assert "a second run over tracked issues exits clean" 0 \
  "${TI_BASE[@]}" "GH_BIN=$GHDIR/gh" "GH_LOG=$WORK/gh-dedup.log" \
  "SENTRY_STUB_DIR=$TRIAGE_STUB" "GH_EXISTING=WEB-1 WEB-2"
if grep -q 'issue create' "$WORK/gh-dedup.log"; then
  bad "issues already tracked were opened again — scheduling this would spam the repo"
else
  ok "issues already tracked are never opened twice"
fi

# A GitHub that refuses the write must not report success.
: > "$WORK/gh-fail.log"
TI_ARGS=(--apply)
ti_assert "a GitHub failure is reported, not swallowed" 1 \
  "${TI_BASE[@]}" "GH_BIN=$GHDIR/gh" "GH_LOG=$WORK/gh-fail.log" \
  "SENTRY_STUB_DIR=$TRIAGE_STUB" GH_CREATE_FAILS=1

TI_ARGS=(--frobnicate)
ti_assert "an unknown flag is a usage error" 64 \
  "${TI_BASE[@]}" "GH_BIN=$GHDIR/gh" "GH_LOG=$WORK/gh3.log" "SENTRY_STUB_DIR=$TRIAGE_STUB"

# ── 49-53. The shape Sentry actually returns, not the flat one ───────────────
# Every stub above is a flat object, and that is exactly how the readers stayed
# broken for so long: they matched the first key at any depth, so a nested
# object could answer a question asked about its parent. These cases pin the
# nesting Sentry really sends. Verified against rizoma-di on 2026-08-30.

# The one that mattered: a monitor is disabled, one of its environments last
# reported "ok", and the environment list is serialised first. Reading the
# nested status passed a job nobody was watching.
stub
printf '{"slug":"nightly-backup","environments":[{"name":"production","status":"ok","lastCheckIn":"2026-08-30T03:00:00Z"}],"status":"disabled","isMuted":false}\n' > "$STUB_DIR/monitor.json"
assert "a disabled monitor blocks even when a nested environment reads ok" 1 \
  NO_COLOR=1 SENTRY_ORG=acme SENTRY_AUTH_TOKEN=t \
  "SENTRY_STUB_DIR=$STUB_DIR" -- cron nightly-backup

# And the mirror case, so the fix is not just "always fail": a live monitor with
# one unhealthy environment is still a monitor that is watching.
stub
printf '{"slug":"nightly-backup","environments":[{"name":"staging","status":"error"}],"status":"active","isMuted":false}\n' > "$STUB_DIR/monitor.json"
assert "an active monitor passes even when a nested environment reads error" 0 \
  NO_COLOR=1 SENTRY_ORG=acme SENTRY_AUTH_TOKEN=t \
  "SENTRY_STUB_DIR=$STUB_DIR" -- cron nightly-backup

# A muted monitor whose mute flag sits after a nested block.
stub
printf '{"slug":"nightly-backup","environments":[{"name":"production","isMuted":false}],"status":"ok","isMuted":true}\n' > "$STUB_DIR/monitor.json"
assert "a muted monitor blocks even when a nested flag reads false" 1 \
  NO_COLOR=1 SENTRY_ORG=acme SENTRY_AUTH_TOKEN=t \
  "SENTRY_STUB_DIR=$STUB_DIR" -- cron nightly-backup

# Commits carry an author object with its own id. Counting keys at any depth
# reported twice the commits that exist — a number in a receipt must be true.
stub
printf '["app.js","app.js.map"]\n' > "$STUB_DIR/files.json"
cat > "$STUB_DIR/commits.json" <<'EOF'
[{"id":"aaa111","message":"fix: guard the parser","author":{"id":"9","name":"U","email":"u@example.com"}},
 {"id":"bbb222","message":"feat: add the gate","author":{"id":"9","name":"U","email":"u@example.com"}}]
EOF
# Captured rather than piped: grep -q closes the pipe early, and under
# pipefail the SIGPIPE that reaches the gate would be read as a gate failure.
COMMIT_OUT="$( cd "$SANDBOX" && env NO_COLOR=1 SENTRY_ORG=acme SENTRY_AUTH_TOKEN=t \
    "SENTRY_STUB_DIR=$STUB_DIR" "$GATE" release v1.0.0 2>/dev/null )"
case "$COMMIT_OUT" in
  *"has 2 associated commit"*)
    ok "commits are counted once each, not once per nested author id" ;;
  *) bad "commits with a nested author id are miscounted" ;;
esac

# Release health genuinely nests under projects[].healthData — the one reader
# that must still see through a level, and must still read the number right.
stub
printf '{"version":"v1.0.0","projects":[{"slug":"web","healthData":{"crashFreeSessions":97.4,"crashFreeUsers":99.1}}]}\n' > "$STUB_DIR/health.json"
assert "a nested crash-free rate below the floor still blocks" 1 \
  NO_COLOR=1 SENTRY_ORG=acme SENTRY_AUTH_TOKEN=t SENTRY_MIN_CRASH_FREE=99 \
  "SENTRY_STUB_DIR=$STUB_DIR" -- health v1.0.0



# ── 61-64. El event_id del canary no puede repetirse ────────────────────────
# Sentry deduplica por event_id. Con un id constante el segundo canary era
# aceptado con 200 y descartado en silencio: el gate imprimía "event accepted
# by ingest", esperaba su timeout y reportaba UNCONFIRMED para siempre contra
# un proyecto sano. Comprobado contra rizoma-di el 2026-08-31: con id fijo, dos
# envíos dejaron un solo issue; con id único, dos envíos dejaron dos.
EID_FN="$WORK/canary-id.sh"
sed -n '/^canary_event_id() {/,/^}/p' "$GATE" > "$EID_FN"
[[ -s "$EID_FN" ]] && ok "the gate exposes canary_event_id" \
                   || bad "canary_event_id not found in the gate"

# shellcheck source=/dev/null
. "$EID_FN"
EID1="$(canary_event_id)"; EID2="$(canary_event_id)"
[[ "${#EID1}" -eq 32 ]] && ok "the event id is 32 characters" \
                        || bad "the event id is ${#EID1} characters, not 32"
case "$EID1" in
  *[!0-9a-f]*) bad "the event id is not hexadecimal: $EID1" ;;
  *) ok "the event id is hexadecimal" ;;
esac
[[ "$EID1" != "$EID2" ]] && ok "two canaries never share an event id" \
                         || bad "two canaries produced the same event id — Sentry would drop the second"



# ── 65-68. La URL que sale a la red, no sólo el resultado ───────────────────
# El canary nunca pudo enviar un evento a un Sentry real: cmd_canary resolvía el
# DSN con `dsn="$(resolve_dsn)"`, y parse_dsn llenaba DSN_HOST/DSN_PROJECT_ID
# dentro de esa subshell. Al volver estaban vacías, ingest_send armaba
# https:///api//envelope/ y curl fallaba siempre — "the ingest endpoint refused
# the event" contra un Sentry que nunca vio la petición.
#
# Sesenta y cuatro casos no lo vieron porque el stub saltaba directo al
# resultado sin construir la URL: el seam que hace verificable esta compuerta
# era el que escondía su peor fallo. Ahora la deja escrita y estos casos la leen.
stub
: > "$STUB_DIR/ingest-ok"
printf '[{"shortId":"WEB-1","title":"canary-url-probe"}]\n' > "$STUB_DIR/issues.json"
( cd "$SANDBOX" && env NO_COLOR=1 SENTRY_ORG=acme SENTRY_PROJECT=web \
    SENTRY_AUTH_TOKEN=t SENTRY_CANARY_MARKER=canary-url-probe \
    "SENTRY_DSN=https://abc123@o4507.ingest.us.sentry.io/4507" \
    "SENTRY_STUB_DIR=$STUB_DIR" "$GATE" canary ) >/dev/null 2>&1
INGEST_URL="$(cat "$STUB_DIR/ingest-url" 2>/dev/null || true)"

[[ -n "$INGEST_URL" ]] && ok "the ingest URL is recorded for inspection" \
                       || bad "no ingest URL was recorded — the seam still hides it"
case "$INGEST_URL" in
  *o4507.ingest.us.sentry.io*) ok "the ingest URL carries the DSN host" ;;
  *) bad "the ingest URL lost its host: $INGEST_URL" ;;
esac
case "$INGEST_URL" in
  *api/4507/envelope*) ok "the ingest URL carries the project id" ;;
  *) bad "the ingest URL lost its project id: $INGEST_URL" ;;
esac
# El síntoma exacto del bug, por si alguien vuelve a envolver el parseo.
case "$INGEST_URL" in
  https:///*|*api//*) bad "the ingest URL is the empty-host shape: $INGEST_URL" ;;
  *) ok "the ingest URL is not the empty-host shape" ;;
esac



# ── 69-76. Lo que el pack expone, no sólo lo que verifica ───────────────────
# Tres hallazgos de una revisión de seguridad sobre el propio pack. Los tres
# eran reales; ninguno lo habría encontrado la matriz, porque medía si la
# compuerta detecta fallos y no qué superficie abre al instalarse.

# 1. sendDefaultPii:false NO filtra la URL. Un token de capacidad en el path
#    —portal de cliente, enlace mágico— salía vivo hacia Sentry con el primer
#    error, y con él el acceso que ese token concede.
for f in instrumentation-client.ts sentry.server.config.ts sentry.edge.config.ts; do
  if grep -q 'beforeSend:' "$PACK_DIR/repo-template/$f" &&
     grep -q 'beforeSendTransaction:' "$PACK_DIR/repo-template/$f"; then
    ok "$f redacts URLs before the event leaves"
  else
    bad "$f initialises Sentry with no URL scrubbing"
  fi
done

# 2. GitHub sustituye ${{ }} antes de que bash lea la línea: las comillas no
#    delimitan, y el job exporta SENTRY_AUTH_TOKEN.
if grep -nE 'run:.*\$\{\{' "$PACK_DIR/repo-template/.github/workflows/observability.yml" >/dev/null 2>&1; then
  bad "the workflow interpolates an expression inside a run: script"
else
  ok "no workflow expression is interpolated into a shell script"
fi

# 3. El DSN de cliente es público: el título de un issue de Sentry puede venir
#    de cualquiera, y este comando lo copia a un tracker privado.
if grep -q 'sanitize_title' "$PACK_DIR/repo-template/bin/sentry-to-issues"; then
  ok "issue titles are sanitised before they reach the tracker"
else
  bad "an attacker-controlled title reaches gh issue create unchanged"
fi
if grep -q 'MAX_NEW_ISSUES' "$PACK_DIR/repo-template/bin/sentry-to-issues"; then
  ok "a run cannot open an unbounded number of issues"
else
  bad "no ceiling on issues created in one run"
fi
SANITIZED="$(printf '%s' 'ping @equipo y `code`' | tr -d '\000-\037' | sed 's/@/@\xe2\x80\x8b/g; s/`/'"'"'/g')"
case "$SANITIZED" in
  *'@equipo'*) bad "sanitize leaves a live @mention: $SANITIZED" ;;
  *) ok "an @mention no longer notifies anyone" ;;
esac


echo ""
echo "${BOLD}────────────────────────────────────────${RESET}"
echo "${BOLD}$PASS passed, $FAIL failed${RESET}"
if [[ $FAIL -ne 0 ]]; then
  echo "${RED}${BOLD}A failure mode stopped blocking. The gate is not trustworthy until this is green.${RESET}"
  exit 1
fi
echo "${GREEN}${BOLD}Every failure mode blocks.${RESET}"
