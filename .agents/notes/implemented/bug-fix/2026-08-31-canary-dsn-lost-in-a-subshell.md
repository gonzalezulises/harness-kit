# The canary never once reached a real Sentry, and the test seam is why

**Decided:** `cmd_canary` parses the DSN in its own shell instead of through
`dsn="$(resolve_dsn)"`, and `ingest_send` builds the URL before the stub branch
and writes it to `$STUB/ingest-url`. Four cases read that URL.

**Why:** `parse_dsn` sets `DSN_KEY`, `DSN_HOST` and `DSN_PROJECT_ID` as globals.
A command substitution runs it in a subshell, so the three came back empty and
`ingest_send` composed `https:///api//envelope/?sentry_key=&sentry_version=7`.
curl refused it every time, and the gate reported *the ingest endpoint refused
the event* — about a Sentry that had never seen the request. The one command
whose job is to prove errors arrive could not send one, and it blamed the
server.

**Sixty-four cases missed it, and the reason matters more than the bug.** In
stub mode `ingest_send` jumped straight to its verdict without composing the
URL, so the only line that could be wrong was the only line never exercised.
The seam that makes this gate verifiable offline was hiding its worst failure.
A test double has to run what goes to the network, not stand in for it — the
URL is now built first and recorded, and the cases assert on its shape,
including the exact empty-host string, so re-wrapping the parse fails loudly.

Found by installing the pack into two real repositories and running the canary
against live projects for the first time. `preflight` passed throughout, because
it calls `parse_dsn` directly. Both projects now report
`event confirmed stored`, exit 0.

**Given up:** `resolve_dsn` stays, unused by the canary, since it is still the
honest way to ask for a DSN where the globals do not matter. Deleting it was
tempting; leaving one caller and one non-caller is the smaller change, and the
regression cases now describe which is which.
