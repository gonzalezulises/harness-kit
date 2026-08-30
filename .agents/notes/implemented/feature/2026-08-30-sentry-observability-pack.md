# Observability enters the kit as a gate on proof of arrival, not on configuration

`packs/sentry/` adds the stage the kit was missing: the cycle used to end at
"merge to main", so nothing in it observed what was deployed. The pack's gate,
`bin/sentry-check`, passes only when an event with a unique marker is sent and
then **read back** from the project through the Web API.

The decision that shapes everything else is what counts as proof. Checking that
`@sentry/nextjs` is installed and a DSN string is present would have been a
tenth of the work, and it would have certified precisely the failure this pack
exists to catch: an empty DSN, a documentation placeholder, `sampleRate: 0`, an
exhausted quota and a missing `onRequestError` all leave the application running
normally and the build green while the project stays empty. Configuration
presence is not evidence. It is the same "green on nothing" that
[the load-testing pack](../../../../packs/load-testing/index.md) closes for a k6
script that exits 0 without running, and that `packs/gherkin/` closes for
Cucumber exiting 0 with zero scenarios.

Accepting the ingest response as proof was rejected for the same reason: Sentry
answers `200` and drops the event afterwards when a quota, an inbound filter or
a rate limit applies. So the canary separates exit `2` (`UNCONFIRMED` — could
not prove anything) from exit `1` (a check failed). Both block, but collapsing
them would have hidden the diagnosis that matters.

What this costs: the gate cannot sit in the merge path. Proving an event arrives
needs a live deployment and real secrets, so it runs on `deployment_status`
after production succeeds — a broken observability config can merge and is
caught minutes later rather than before. Moving it earlier would mean gating on
configuration again, which is the thing being rejected. The second cost is
noise: every canary writes a real, marked error event into the production
project. Proof was judged worth the noise; the marker makes the events
filterable and correlates them with the CI run that sent them.

The same standard extends to what the gate covers beyond errors. `release` also
requires associated commits, because without them Sentry can never name the
change that caused an issue and every incident restarts with "which deploy was
this?". `cron` exists because a scheduled job that stops being scheduled raises
nothing at all — silence is the one signal an error tracker is built to ignore,
and an unmonitored job is the longest-lived outage in any system. `triage`
reports rather than gates, but still fails closed when it cannot reach the API:
"no issues" and "could not ask" must never look the same.

A second rule governs the opinionated checks: **a capability may be switched
off, but it must be switched off out loud.** Tracing at zero passes only with
`SENTRY_TRACING_ACKNOWLEDGED=true`, PII collection only with
`SENTRY_PII_ACKNOWLEDGED=true`. The alternative — warn and continue — was
rejected because a warning nobody reads is how half of Sentry ends up disabled
without anyone having decided to disable it. The cost is friction on first
install, paid once, by the person who can still change the answer.

`verify-pack.sh` synthesises API responses through the `SENTRY_STUB_DIR` seam
instead of calling the network, so the 45 failure modes are verifiable on any
machine with `bash` and no Sentry account. A pack whose own verification needs
a paid account and network access is a pack nobody re-verifies.

`bin/sentry-heartbeat` is the one deliberate exception to fail-closed: with no
usable DSN the wrapped job still runs, and the job's exit code always survives
the wrapper. Monitoring that can take down the work it monitors is worse than
no monitoring, so that behaviour is asserted in the failure matrix rather than
left to good intentions.

Revisit if Sentry ships a first-party endpoint that confirms storage without
writing an event, which would remove the noise cost, or if canary events become
a problem in a customer-facing project — the answer then is a dedicated Sentry
project for canaries, not a weaker gate.
