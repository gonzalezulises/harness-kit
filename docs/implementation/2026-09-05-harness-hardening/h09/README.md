# H09 local installation and migration canary

This milestone exercises the installed optional package in a fresh authorized
local consumer fixture. Local installation/canary verification is distinct from
the original real review/production acceptance, which remains NOT_EXECUTED.
The positive H07 reviewer, containment and authenticated receipt backends and H08
production scheduler, target/readback, receipt and live rollback backends are
UNIMPLEMENTED. No real target, baseline or key was authorized by this run.

## Reproduction and exact evidence

Run from the kit root after the pack's documented pinned dependency setup:

```bash
bash docs/implementation/2026-09-05-harness-hardening/h09/verify-static.sh
node --test --test-reporter=tap packs/autonomy/tests/installation.test.mjs
node --test --test-reporter=tap packs/autonomy/tests/canary.test.mjs
```

The first command validates syntax and the exact scoped source manifest; runtime
has four installation boundary tests; e2e has one integration canary. The kit's
existing pack verifier runs both suites after its existing runtime tests.
The canary runs an actual offline `npm ci --ignore-scripts --no-audit --no-fund`
in the installed nested package. A missing cache is an environment failure,
never a skip, implicit network retry or copied node_modules.

Final command argv, exits and elapsed time are in `verification.json`; stdout,
stderr and exit records have `final-static`, `final-runtime` and `final-e2e`
prefixes. `canary/canary.json` records the exact observed results and metrics;
`canary/commands.json` records actual subprocess output and exits, including both
canonical assertion REDs and GREENs. The executed oracle and before, deliberately
reordered and final YAML bytes are retained there. Fixture-only public key,
receipts, authority and full journal/object/capability evidence are retained;
private fixture keys were never written. The temporary consumer itself is
removed after its evidence is copied. No source test or receipt from H01–H08 is
replaced.

`source-manifest.json` lists the exact SHA256 and mode of the selected installers,
status, pack runtime/contracts/schemas/tests, adoption docs, note and static
verifier. It excludes root-owned publication state and generated dependencies.
`evidence-manifest.json` binds every local evidence file except itself, the final
candidate descriptor and external implementer report. `baseline-candidate.json`
binds both manifests as the unsigned **CANDIDATE_NOT_ACCEPTED** delivery subject.
This delivery descriptor is not a runtime baseline approval envelope and contains
no owner acceptance/signature. It deliberately excludes its own/final publication
commit hash; the coordinator supplies that Git commit in final delivery. The
fixture's `describeBaseline` output for record.yaml is a different, explicitly
fixture-scoped subject and never accepts this delivery descriptor.

## Observed flow and limits

Installation preserves the exact v1 feature-list and root package bytes, avoids
node_modules copying, retains an existing runtime unchanged and leaves the v2
marker absent. Missing dependencies and positive capabilities are reported.
Explicit fixture-only adoption exercises the installed legacy writer guard.
Normal YAML fails the local canonical-byte oracle, then an actual scoped write
satisfies it. A real Git commit change creates a fresh run. The runtime builds
an exact local Git shadow, but refuses live review without spending a review
unit or producing authenticated review evidence. Threshold `100` → `99.9`
immediately emits HUMAN_REQUIRED and grants no execution. A deliberate bounded
representation defect fails the same oracle, rejects the stale run, and is
corrected under the original signed continuation after another actual commit
and fresh run. A repeated operation key returns its existing effect receipt.
No new artifact bytes inherit the original baseline approval.

The next slice and production release remain incomplete; local canonical checks
cannot satisfy authenticated review, artifact acceptance, deploy, smoke or
observability. Local rollback stops use, archives/removes only the fixture
marker, restores the original data bytes, and preserves exact v1/package/journal
bytes plus the installed runtime and receipts for replay. It does not execute
or certify production rollback or revoke grants.

Metrics distinguish **0 actual human prompts**, **5 fixture signatures** (one
policy adoption, one initial baseline, three bounded subjects), one emitted
HUMAN_REQUIRED reason code, one stale-run stop, and two availability stops.
One continuation grant covers two actual effects and three fresh runs retain
the objective budget (two spent mechanical units). Authenticated review receipts
and production certificates remain zero. Recovery elapsed milliseconds are the
measured `recoveryElapsedMs` in `canary/canary.json`, from the second deliberate
noncanonical write through observed canonical verification; they are fixture
wall time, not real human recovery time or time saved.

The exact before/after comparison is the same local byte oracle over the same
record: two deliberate representation failures versus two observed canonical
successes. Within these exercised assertions there is no false local canonical
PASS, no semantic change silently allowed, and no unexpected final block.
The intermediate review/release stops are required availability results.
No production-wide friction percentage or real human intervention reduction is
inferred from fixture signatures, aggregate test counts or omitted capabilities.

## RED provenance

`feature-absent.*` and `feature-absent-source/` preserve the original installer/
status sources, exact unchanged installation test, logs and actual exit1 (three
failures). They show missing H09 functionality, not a discovered Critical/High
defect. The symlink boundary case happened to pass because the old option was
absent; it is not claimed as an independently witnessed safety falsification.
The canonical oracle's two nonzero subprocess exits are controlled local fixture
representation REDs, not discovered shipping runtime defects or test mutations.
No optional mutation campaign was performed.

The first canary attempt (`e2e-first.*`) correctly refused a writable workspace
containing Git's read-only object files. The test layout was corrected to put
Git metadata in the parent repository and writable record data in its own
subdirectory. No runtime guard or expectation was loosened. The subsequent
`e2e-second.*` passed. These development logs are retained, while final evidence
binds the current source. No new Critical/High shipping defect was discovered.

## Historical coverage using the audit matrix IDs

| ID | New or preserved executable evidence | Exact coverage status |
| --- | --- | --- |
| HIST-01 | H09 canary canonical oracle/effects; H03 identity tests | Executed local typed YAML canonicalization; no arbitrary document equivalence |
| HIST-02 | H09 canary three actual Git/fresh-run transitions and stale rejection | Executed local freshness; original acceptance and spent budget retained |
| HIST-03 | Preserved H05 `../h05/fix-1/final-runtime.log` and capabilities tests; H09 repeated effect key | Executed H03–H06 local source/digest contracts; H09 adds installed idempotency, not a new derived-chain run |
| HIST-04 | H09 canary same continuation for two effects | Executed bounded local representation correction; no live independent review |
| HIST-05 | Original Aurobalance fixture unavailable; separate H02 timeout logs | Original case NOT_EXECUTED; kit timeout evidence is distinct |
| HIST-06 | Preserved `../h02/concurrency-03.json`, core-a/core-b logs | Actual H02 independent-resource concurrency; not rerun or relabeled as H09 |
| HIST-07 | H09 installed review refusal; preserved H07 review tests/evidence | Local contract only; real Codex/authentication/containment acceptance NOT_EXECUTED, positive backend UNIMPLEMENTED |
| HIST-08 | Preserved H07 strict local output/fallback tests | Local contract only; no real remote-schema/session acceptance |
| HIST-09 | H09 actual Git shadow construction | Exact local Git objects exercised; sandbox/session acceptance NOT_EXECUTED |
| HIST-10 | H09 original acceptance refuses final artifact bytes | Executed local approval separation/continuation; final candidate remains unaccepted |
| HIST-11 | H09 installed release refusal and next unexecuted slice; preserved H08 `../h08/runtime.stdout.log` | H08 local obligation simulations are not deployments; positive production backend UNIMPLEMENTED, real acceptance NOT_EXECUTED |
| HIST-12 | H09 threshold 100 → 99.9 assessment and unchanged workspace | Executed local immediate HUMAN_REQUIRED; execution withheld |

HIST-01/02/03/04/10/12 have local executable coverage across H03–H06. This table
uses the existing audit IDs and adds new references without upgrading historical
or absent fixtures to full PASS. Full integration, independent review, feature
promotion and publication remain the coordinator's gates.
