# A case that did not run must say so in the summary, not only in the log

**Decided:** `packs/load-testing/verify-pack.sh` counts omissions and prints
them after the verdict: `55 correctos, 0 fallidos, 2 omitidos`, each named with
what it needed. All three environment guards report through it — authenticated
`gh`, `node`, `python3`/PyYAML — including the two that said nothing at all.

**Why:** CI reported `55 correctos, 0 fallidos` while the same pack reported 57
locally. Nothing in the summary explained the gap, so the honest readings are
"we lost coverage" and "something broke", and both cost a session to rule out —
this one included. The information existed: the `gh` guard did print a note
mid-log, and it did reach the CI log. But a note buried above a summary that
says "0 fallidos" is not a signal; the summary is the line people read, and it
was quietly claiming more than it had checked. The `node` and PyYAML guards
printed nothing whatsoever, so on a machine without them the count would drop
again with no trace at all.

This is the distinction the kit argues for everywhere else and had not applied
here: `sentry-check triage` fails closed precisely so "no issues" and "could
not ask" never look alike, and `run-gates.sh` already prints SKIP for a gate
whose script is absent. A pack that omits silently makes the same claim it
tells its users not to make.

Omissions do not change the exit code — they are coverage this machine could
not provide, not a failure. Verified three ways: everything present (57/0/0),
`gh` unauthenticated as on the runner (55/0/2), and no `node` with a PyYAML-less
`python3` (55/0/2), each naming the right cases.

**Given up:** the two network cases still do not run in CI. Making them run
needs a token with user scope on the runner, which buys two assertions for a
credential to store and rotate — not worth it. What was wrong was never the
omission; it was the silence about it.
