# A 403 on the read-back looked exactly like a dropped event

**Decided:** every Sentry API read in `sentry-check` and `sentry-to-issues`
captures the HTTP status with `curl -w '%{http_code}'`. A non-2xx answer prints
`HTTP <code> en <path>`, which names the API path and never the token, and exits
3. The canary reports *la lectura falló* and exits 3 when its read fails. When
the read works but the event is not there, it reports *el evento no apareció*
and exits 2. Triage and the backlog bridge query
`is:unresolved !message:harness-canary*`. The workflow template's preflight step
now receives `SENTRY_ENVIRONMENT`.

**Why:** in Aurobalance, `SENTRY_AUTH_TOKEN` was an org token (scope `org:ci`)
that may not read issues. `curl --fail ... 2>/dev/null` turned every 403 into an
empty answer. The canary waited out its timeout and blamed storage for an event
it was never allowed to see. In stub mode triage did worse: a permission error
body has no `shortId`, so it reported *no unresolved issues*. That is the exact
"no issues" vs "could not ask" confusion this gate exists to prevent. The fix
was a token swap. The defect was that the gate could not say so.

The canary's own issue is unresolved by design, because every run adds an
event. Left in the query, it was the first line of every triage, and
`sentry-to-issues --apply` would have filed a test signal as a defect.

The preflight gap has the same shape: `preflight` fails without an environment,
and the template never passed one, so every activated repo began red. That was
found by comparing Aurobalance's patched copy with the template.

**Rejected:** treating 404 as "does not exist" (exit 1) and only other statuses
as unreadable. Each reader would then need its own reading of each status, and
the message already names the code. Both exits block.

**Given up:** a real 404 in `release`, `health` or `cron` now exits 3, not 1.
Stub mode keeps "absent fixture = the call failed" (exit 1), so the existing
cases still mean what they meant. `<fixture>.http` is the new seam for statuses.
The negated query was checked live against `rizoma-di/aurobalance` on
2026-10-23. If Sentry changes its search syntax, the exclusion silently stops
working, and only a live run would show it.

Related: [the canary DSN lost in a subshell](2026-08-31-canary-dsn-lost-in-a-subshell.md).
