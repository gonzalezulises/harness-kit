# Optional autonomy runtime pack

H03 supplies pure typed identity, scoped cryptographic approval verification and
conservative batch classification. It does not execute effects, run commands,
issue permits or certify a release. H04 adds journal/replay, objective budget
reservations, mechanical fresh runs and lossless legacy migration. H05 adds
closed canonical/source-digest writes with scoped permits, exclusive leases and
actual postcondition receipts. Subprocess effects remain blocked by unavailable
required containment. H06 adds signed reusable continuation, durable closed identity
regressions, revocation and three objective budget categories plus a total cap.
H07 adds exact local Git shadows, frozen review bindings and strict local output
validation. F24 implements a closed GitHub Actions dispatch/reconciliation
backend, authenticated catalog and private verified-review provenance, plus a
fixed Codex app-server stdio worker for operator-supplied tested containment.
H08 consumes those journal records and executes one approved release obligation
at a time, including exact target readback, separate smoke/observability,
explicit artifact acceptance and deploy/rollback authorization. See
`contracts-execution-v1.md` in the runtime directory for configuration, workflow
contract, bounds and a controller example. No scheduler or target provider is
invented. OS containment and actual consumer workflow/target code remain operator
prerequisites. Live review/production acceptance remains NOT_EXECUTED.
Archived policy proposals remain inactive and unchanged.

The single installable package is `repo-template/scripts/quality-orchestrator/`.
Install it explicitly with the existing local installer:

```bash
bash bin/harness-init.sh --target /path/to/consumer --level full --with autonomy
```

`harness-activate.sh --with autonomy` forwards the same option when coordinating
full activation; its existing remote protection actions still require their own
authorization. `--dry-run` writes nothing. Ordinary installs without the option
remain legacy. The nested directory contains its own package.json, lockfile,
sources, schemas and tests. Existing runtime directories are retained intact,
even with `--force`; no version merge or automatic upgrade occurs. Root
package.json is never replaced. Generated node_modules are never copied.

From a fresh kit checkout, with Node >=22 and npm available:

```bash
npm ci --prefix packs/autonomy/repo-template/scripts/quality-orchestrator --ignore-scripts --no-audit --no-fund
bash packs/autonomy/verify-pack.sh
```

After copying into a consumer:

```bash
npm ci --prefix scripts/quality-orchestrator --ignore-scripts --no-audit --no-fund
npm test --prefix scripts/quality-orchestrator
```

From the kit, inspect the installed package with
`bash bin/harness-status.sh --target /path/to/consumer --autonomy`.
This bounded, read-only diagnostic loads the runtime and reports missing
dependencies, marker presence and unavailable capabilities. Exit zero means only
that the installed runtime loaded. It does not run consumer verification or
verify authority, baseline acceptance, readiness or release certification.
The ordinary status path still runs `make check` and inspects remote protection.

YAML 2.9.0 and Zod 4.5.4 are exact dependencies with SHA512 package integrity in
the one lockfile. No lifecycle hooks run during documented setup. Installation
requires registry access or a populated npm cache; inability to fetch is an
environment failure. `verify-pack.sh` fails with exit69 for missing/wrong runtime
dependencies; it never downloads packages or skips its tests. The kit's full
`make check` already discovers pack verifiers, so kit maintainers explicitly
install these optional dependencies before that aggregate command. Legacy
minimal/full scaffolds do not receive this package or a new Node prerequisite.

Read `repo-template/scripts/quality-orchestrator/contracts-v1.md` and
`contracts-journal-v1.md`, `contracts-capabilities-v1.md` and `contracts-continuation-v1.md` in that directory before embedding
this runtime. Host trust is operator-established, not selected by request JSON.
No CLI generates an owner key, adopts policy, or accepts a baseline. Installation
does not create `.harness/autonomy-v2.json`. Test keys exist only in fixture code
and do not enroll production authority.

For real adoption, the operator must establish trusted host custody and approved
runtime/dependency bytes, authority sources, public issuer keys, current time and
revocation basis. Present the exact `describeBaseline` subject to the enrolled
human approval channel, then verify the scoped adoption and baseline receipts
through `loadAuthority` and `verifyContext`. Only after that explicit decision may
the host create the v2 marker that disables direct legacy writers. The marker is
a writer guard, never an approval receipt. The implementation mandate and the
unsigned delivery candidate grant none of these authorities. The current
selected-asset candidate is
`docs/implementation/2026-09-05-harness-hardening/final-fix-1/baseline-candidate.json`;
the original H09 candidate remains historical.

Rollback stops v2 effects, retains the installed version/lockfile and all original
v1 bytes, journals, objects and receipts, and archives the marker before an
explicit operator removal. Restore only the known v1 snapshot; do not project
v2 effects or legacy receipts into newly accepted authority. Pending effects must
be reconciled by their original key before further work. Removing a marker does
not revoke issued grants; host access/use must remain disabled. There is no
automatic rollback command or live production rollback backend.

The executable local integration canary is
`node --test packs/autonomy/tests/canary.test.mjs`. It installs via the CLI and
uses offline `npm ci` in a fresh consumer, requiring the pinned package cache
populated by the setup above. Its ephemeral fixture issuer and fixture marker
are explicitly labeled. It preserves v1, performs two actual canonical effects
under one continuation, changes real Git commits, refuses a threshold change,
constructs a local review shadow, observes unavailable review/release, and tests
local rollback while retaining evidence. It does not measure real human time
saved or certify Codex, containment or production. Current correction evidence is
in `docs/implementation/2026-09-05-harness-hardening/final-fix-1/README.md`;
historical canary evidence and coverage limits remain in
`docs/implementation/2026-09-05-harness-hardening/h09/README.md`.

The bounded product controller is an opt-in `product.v1` journal contract; see
`scripts/quality-orchestrator/contracts-product-v1.md` in the installed runtime.
It connects a signed outcome to functional RED, data-only patch authoring,
verification, independent review, at most two fixes and an isolated local PR
commit/title/body receipt. Existing journal contracts are unchanged. The CLI
supports `--autonomy --json` for offline installation observations; missing
runtime/dependencies exit nonzero. Fixture completion and local PR preparation
do not establish real model authentication, host containment, a remote PR or
P0_PRODUCT_LOOP_READY.
