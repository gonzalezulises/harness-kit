# Consumer distribution — independent increment

User scope: harness-kit only; fixture repositories, never Casabat. Base is the
frozen local PR33 continuation a798c88ad625be2478d24df52c0dc45c51e2d4e4. This
branch is separate from PR33 and P0-PRODUCT-LOOP. No merge, release or production
adoption is authorized. Remote publication currently awaits resolution of an
automatic approval block; do not use another route to publish.

## Smallest supported profile

Implement `autonomy-runtime.v1`: production QO modules, schemas/contracts,
package/lock, the exact yaml/zod dependency closure, and an offline installation
manager/verifier. Preserve the legacy installer and consumer full templates.
Do not replace existing product commands, workflows, authority or policies.
Use Python standard library for the manager; no registry, service, package
manager, plugin framework or arbitrary migration hooks.

The concrete commands may follow the bin CLI convention, but must provide
`consumer plan`, `apply`, `verify`, `upgrade-plan`, `upgrade` and `rollback`.
Add a local reproducible bundle builder and the smallest stable consumer entry
needed to run the installed runtime without this checkout. Do not download in
the builder or during normal consumer operation. Two previously available npm
package archives can be checked against lockfile SHA512 and safely extracted;
missing archives fail MISSING_LOCAL_DEPENDENCY. Generated release bundles and
dependencies are artifacts outside Git, never repository snapshots.

## Provenance and ownership

A strict machine-readable bundle and installation schema bind source repository,
source version/tag, exact Git commit SHA, bundle digest, schema version, profile,
complete per-file paths/hashes/modes, adoption date and receipt. Read source bytes
from the exact Git commit. An optional tag must resolve to that SHA. A local
candidate is not reported as a published upstream release. Identical inputs
produce identical bundle content/digest, without timestamps inside that digest.

Managed files live in an immutable generation below
`.harness/distribution/generations/<bundleDigest>/`; enumerate every file in the
manifest. A fixed bootstrap and an atomic active descriptor select a verified
generation. The manifest and guide must give the exact managed file list and
the exact ownership rule for everything else. Changes to the stable bootstrap
or unknown schema require an explicit compatible migration; unsupported changes
fail MIGRATION_REQUIRED. Do not pretend a loop of file renames is globally atomic.

All existing consumer files outside this namespace remain consumer-owned,
including root AGENTS/Makefile/package/lock, product source, authority, commands,
objectives, allowlists, frozen regions, adapters, gates and custom workflows.
Existing `scripts/quality-orchestrator/` is preserved during legacy adoption;
the new installation is parallel and its entrypoint is explicit. Journals, runs,
oracles, receipts, feature/progress/decision state and markers are never replaced,
rewound or adopted by the installer. Configuration/state paths may not overlap
managed paths. Existing accepted runtime bindings are not silently renewed.

## Plan and transaction

`plan` and `upgrade-plan` are genuinely read-only, including no Git index refresh
or temporary consumer files. Output installed/target versions, create/change
lists, managed drift, migrations, preserved config/state, incompatibilities and
available rollback. Bind target repository/HEAD, before hashes, source SHA and
bundle, profile/config/state schema, allowed writes and rollback target. A stable
plan has a deterministic digest. Caller can save JSON outside the consumer.

`apply`/`upgrade` require the exact supplied plan plus explicit
`--approve-plan <digest>`; no --yes/force. Recompute all bindings under an exclusive
lock before effects. A different bundle/SHA/plan, managed drift, incompatible
version/schema, consumer overwrite, missing migration, unbound required
baseline/evidence, unsuitable working tree or unsafe path blocks before writes.
Drift has the exact state MANAGED_FILE_DRIFT, with no automatic repair.

Prepare an immutable generation, verify every byte and required local dependency,
persist a compact transaction/receipt, then atomically switch one descriptor
with rename/fsync. Before activation, all new entrypoints fail closed if staging
is incomplete. Post-verification failure preserves a failure receipt and restores
the previous verified selection when safe; it never claims success. Resume uses
the same approved plan and durable stages, rechecks before/after bytes and rejects
unreconcilable state. Concurrent consumers cannot execute the same plan twice.

Repeat application is idempotent. Rollback is another explicit digest-approved
plan selecting a still-verified previous generation, preserving current config,
journal and all newer evidence. Do not restore a snapshot of consumer state.
If current state is incompatible with the older runtime, rollback blocks.
No write is allowed outside declared managed/transaction paths. Reject traversal,
symlinks/hardlinks, unexpected archive entries/types, conflicting paths and
changes to product files. No shell subprocesses or executable migration strings.

`verify` runs offline and detects drift for CI. Where authority is asserted it
requires an expected installation/plan digest from a trusted external input or
protected base; a candidate verifier plus candidate manifest cannot certify its
own adoption. Local integrity observation is distinct from adopted authority.
Prepare the adoption/upgrade PR receipt and reproducible Git handoff; ACTIVE
requires the owner's ordinary adoption merge, never an installer declaration.

## Required fixture evidence

Observe clean installation; legacy adoption; repeated installation; managed
file edit; custom consumer configuration; interrupted apply/resume; changed plan
digest; adulterated bundle; incompatible version/schema; rollback preserving
new journal/config; upgrade attempting product-file changes; and actual consumer
operation with upstream and package caches removed/unavailable. Include concrete
postverify failure, unsuitable tree, missing bindings and concurrent apply cases.
Fixtures use local Git repositories and clearly fixture authority, not Casabat.

Write the critical oracle and tests before code. Capture causal RED then GREEN
for the actual defect/feature and preserve current test hashes, minimal source
or patch, command, exit, structured result, short error excerpt and reproduction.
No large logs, duplicate snapshots or generated dependencies in Git. The offline
end-to-end case must load/use the real installed QO with actual pinned packages;
a fixture-only module import or mocked verifier is insufficient.

One implementation task, one independent scoped review, max two bounded fix
rounds. Preserve old tests/receipts, add focused new tests, run affected layers
then the existing required final gate once. Root owns final verification and
bookkeeping; F26 is activated only after F25 leaves active work.

Deliver definitive install/upgrade/rollback commands, schema+manifest, tested
implementation, compact causal/negative evidence, short future Casabat guide and
exact managed versus consumer-owned lists. Do not execute Casabat adoption.
READY_FOR_MULTI_REPO_ADOPTION may be claimed only for the supported profile after
fixture install, upgrade, rollback, drift detection and autonomous offline
execution actually pass. Separate that result from real consumer adoption,
upstream release acceptance and P0_PRODUCT_LOOP_READY; report unsupported
bootstrap/schema migrations and other remaining gaps explicitly.
