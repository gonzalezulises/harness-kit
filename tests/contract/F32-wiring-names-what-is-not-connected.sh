#!/usr/bin/env bash
# F32 — harness-wiring names the integration that is missing, on the cases that cost real
#       time on 2026-10-23, without touching the network.
#
# Every one of these looked fine from inside the repo:
#   · Dependabot alerts off (235 repositories)
#   · a Vercel project with no Git link: merges published nothing (mallol-comfy-connector)
#   · `"lint": "next lint"`, a command Next 16 removed: the lint checked nothing
#   · Supabase signup open over `USING true` policies: anyone could register and read
#     every row, and the Security Advisor reported nothing (Aurobalance)
#
# gh, vercel, security and curl are replaced by stubs on PATH, and the Supabase
# Management API by a local server, so each case is the exact answer those tools gave.
# The control keeps the test honest: a fully wired fixture must not fail.
#
# Usage: bash tests/contract/F32-wiring-names-what-is-not-connected.sh

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_DIR="$(cd "$HERE/../.." && pwd)"
# shellcheck source=tests/contract/lib.sh
. "$HERE/lib.sh"

WORK="$(mktemp -d)"
SERVER_PID=""
cleanup() { [[ -n "$SERVER_PID" ]] && { kill "$SERVER_PID" 2>/dev/null; wait "$SERVER_PID" 2>/dev/null; }; rm -rf "$WORK"; }
assert_contains() { if [[ "$2" == *"$3"* ]]; then ok "$1"; else bad "$1 (no contiene: $3)"; fi; }
trap cleanup EXIT
echo "${BOLD}F32 — wiring names what is not connected${RESET}"

STUBS="$WORK/stubs"; mkdir -p "$STUBS" "$WORK/profiles"
printf 'GIT_EMAIL="dev@acme.test"\nGH_USER="acme"\nGCP_PROJECT=""\nSUPABASE_KEYCHAIN_ITEMS="Supabase CLI"\n' \
  > "$WORK/profiles/acme.profile"

# Each case sets these, and the stubs read them.
export F32_ALERTS F32_LINK F32_SIGNUP F32_OPEN_POLICIES
export F32_REQ=on F32_ARCHIVED=false

cat > "$STUBS/gh" <<'SH'
#!/usr/bin/env bash
args="$*"
case "$args" in
  "auth token --user acme") echo "tok" ;;
  "api repos/acme/app") echo "{\"default_branch\":\"main\",\"archived\":$F32_ARCHIVED,\"permissions\":{\"admin\":true}}" ;;
  "api repos/acme/app/vulnerability-alerts") [[ "$F32_ALERTS" == on ]] || exit 1 ;;
  "api repos/acme/app/automated-security-fixes --jq .enabled") echo true ;;
  "api repos/acme/app/rules/branches/main --jq"*) [[ "$F32_REQ" == on ]] && echo "required_status_checks" || echo "" ;;
  "api repos/acme/app/commits/main --jq .sha") echo "abc1234def" ;;
  *) exit 1 ;;
esac
SH
cat > "$STUBS/vercel" <<'SH'
#!/usr/bin/env bash
case "$2" in
  */env*) echo '{"envs":[{"key":"NEXT_PUBLIC_SUPABASE_URL","target":["production"]},{"key":"SENTRY_DSN","target":["production"]}]}' ;;
  *) if [[ "$F32_LINK" == linked ]]; then
       echo '{"link":{"org":"acme","repo":"app"},"targets":{"production":{"meta":{"githubCommitSha":"abc1234def"}}},"alias":[{"domain":"app.acme.test"}]}'
     else
       echo '{"link":null,"targets":{"production":{"meta":{}}},"alias":[{"domain":"app.acme.test"}]}'
     fi ;;
esac
SH
cat > "$STUBS/security" <<'SH'
#!/usr/bin/env bash
echo "sbp_test"
SH
cat > "$STUBS/curl" <<'SH'
#!/usr/bin/env bash
for a in "$@"; do case "$a" in http://127.0.0.1*) exec /usr/bin/curl "$@" ;; esac; done
echo "200 "
SH
chmod +x "$STUBS"/*

# The Supabase Management API: auth config and the open-policy count, per case.
# The server reads the case from this file, so it must exist in its environment first.
export F32_STATE="$WORK/state.json"
PORT=$(( 20000 + RANDOM % 20000 ))
python3 - "$PORT" <<'PY' &
import http.server, json, os, sys
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def reply(self, obj):
        b = json.dumps(obj).encode(); self.send_response(200)
        self.send_header("Content-Type", "application/json"); self.end_headers(); self.wfile.write(b)
    def state(self):
        return json.load(open(os.environ.get("F32_STATE", "/dev/null"))) if os.path.exists(os.environ.get("F32_STATE", "")) else {}
    def do_GET(self):
        s = self.state()
        if self.path.endswith("/config/auth"):
            self.reply({"disable_signup": s.get("signup") == "closed", "password_hibp_enabled": True})
        else:
            self.reply({"ref": "abcdefghijklmnopqrst"})
    def do_POST(self):
        self.reply([{"n": self.state().get("open_policies", 0)}])
http.server.HTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
PY
SERVER_PID=$!
sleep 1

new_repo "$WORK/app"
git remote add origin "https://github.com/acme/app.git"
git config user.email "dev@acme.test"
mkdir -p .github/workflows src .vercel
echo 'name: ci' > .github/workflows/ci.yml
echo 'export const url = "https://abcdefghijklmnopqrst.supabase.co";' > src/db.ts
echo '{"projectId":"prj_app","orgId":"team_acme"}' > .vercel/project.json
write_pkg() { printf '{"name":"app","scripts":{"lint":"%s"},"dependencies":{"@sentry/nextjs":"1"}}\n' "$1" > package.json; }
write_pkg "eslint ."
commit_all "app"

# run_case <alerts on|off> <link linked|unlinked> <lint> <signup open|closed> <open policies>
run_case() {
  F32_ALERTS="$1"; F32_LINK="$2"
  write_pkg "$3"; git add -A >/dev/null; git -c user.email=t@t -c user.name=t commit -qm case >/dev/null 2>&1
  printf '{"signup":"%s","open_policies":%s}\n' "$4" "$5" > "$F32_STATE"
  OUT="$(PATH="$STUBS:$PATH" HARNESS_PROFILES_DIR="$WORK/profiles" HARNESS_WIRING_CACHE="$WORK/cache" \
         HARNESS_SUPABASE_API="http://127.0.0.1:$PORT" NO_COLOR=1 \
         bash "$KIT_DIR/bin/harness-wiring.sh" --target "$WORK/app" 2>&1)"
  RC=$?
}

run_case on linked "eslint ." closed 0
expect_zero "control: a fully wired repo does not fail" $RC
assert_contains "control: no FAIL line when everything is connected" "$(printf '%s' "$OUT" | grep -c 'FAIL' | sed 's/^0$/none/')" "none"

run_case off linked "eslint ." closed 0
expect_nonzero "Dependabot alerts off is NOT_WIRED" $RC
assert_contains "and names it" "$OUT" "alertas de Dependabot — apagadas"

run_case on unlinked "eslint ." closed 0
expect_nonzero "a Vercel project without Git is NOT_WIRED" $RC
assert_contains "and says a merge publishes nothing" "$OUT" "un merge no publica nada"

run_case on linked "next lint" closed 0
expect_nonzero "a lint script that is next lint is NOT_WIRED" $RC
assert_contains "and says Next 16 removed it" "$OUT" "Next 16 eliminó"

run_case on linked "eslint ." open 28
expect_nonzero "open signup over 28 USING true policies is NOT_WIRED" $RC
assert_contains "and says anyone can register and read" "$OUT" "cualquiera se registra y lee"

run_case on linked "eslint ." open 0
expect_zero "open signup with no USING true policy is not a failure" $RC

# D10 scope: the merge gate is required where there is production, not everywhere.
F32_REQ=off
run_case on linked "eslint ." closed 0
expect_nonzero "no required check on a repo that deploys is NOT_WIRED" $RC
assert_contains "and says it deploys to production" "$OUT" "despliega a producción y nada impide"
mv "$WORK/app/.vercel" "$WORK/vercel.off"
run_case on linked "eslint ." closed 0
expect_zero "no required check and no production is only a note" $RC
mv "$WORK/vercel.off" "$WORK/app/.vercel"
F32_REQ=on

F32_ARCHIVED=true
run_case off unlinked "next lint" open 28
expect_zero "an archived repo is out of scope, whatever its state" $RC
assert_contains "and says it is archived" "$OUT" "ARCHIVED"
F32_ARCHIVED=false

finish "F32"
