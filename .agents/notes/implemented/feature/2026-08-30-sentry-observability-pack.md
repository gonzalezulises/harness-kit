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

`verify-pack.sh` synthesises API responses through the `SENTRY_STUB_DIR` seam
instead of calling the network, so the 21 failure modes are verifiable on any
machine with `bash` and no Sentry account. A pack whose own verification needs
a paid account and network access is a pack nobody re-verifies.

Revisit if Sentry ships a first-party endpoint that confirms storage without
writing an event, which would remove the noise cost, or if canary events become
a problem in a customer-facing project — the answer then is a dedicated Sentry
project for canaries, not a weaker gate.
