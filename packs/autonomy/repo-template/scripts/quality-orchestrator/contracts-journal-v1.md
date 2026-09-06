# Journal and run contract v1 — H04

H04 extends `openRuntime(host)` with optional operator-only `host.journal`.
The candidate never constructs this host binding. No service, database, execution
adapter or new dependency is introduced. H04 records reservations and negative
outcomes; it cannot issue a permit, execute an effect or certify PASS.

## Host binding and storage

The exact journal settings are `{directory, objectiveId, journalId, actorId,
budgetLimit, readFinalBinding, readLatestWitness?, compareAndAppendWitness?,
reconcileOperation?}`. The directory is absolute and belongs to the trusted
supervisor; objective budget is an integer fixed for the entire journal. Readers
are synchronous host acquisition adapters, never candidate callbacks. The final
binding reader returns `{commit, documents:[{path,bytes}]}` from the actual current
workspace. Every document must cover exactly the original accepted context.

`eventSchema`, `runSchema` and `witnessSchema` are closed built-in Zod contracts
in `journal.mjs`. `JOURNAL_RUNTIME_BINDING` binds their protocol/schema descriptions
and H03's `RUNTIME_BINDING`; neither digest replaces host approval of the actual
source and dependency bundle. Historical events bind repository, objective,
journal, runtime, authority, host actor, sequence, previous digest, exact typed
operation, request digest and host time. Event documents retain exact bytes as
canonical base64. SHA256 content objects are exclusive creations; existing bytes
must match exactly. `events.jsonl` is the ordered chain, while `HEAD` is only a
repairable cache. Local files use restrictive modes, fsync and exclusive ownership.
These controls do not defeat a same-UID actor replacing the trusted runtime or
its local state; that threat is outside this local boundary.

`LOCK` is created with exclusive ownership before read/CAS/write. A durable
content object precedes a durable complete log line, followed by atomic HEAD
publication. No timeout grants takeover. Torn log tails and altered/missing
objects return INCOMPLETE with their bytes retained. A complete chain repairs a
stale HEAD under ownership. An orphan object from a pre-log crash is not an event.
A partial append is never silently discarded or retried.

## Public methods

Every state method takes this runtime's opaque, freshly inspected H03 context.
Reopening requires re-verifying the original accepted documents and receipts;
serialized context summaries cannot become authority. Replay recomputes each run
manifest and its closed mechanical equivalence against that accepted context.

| Method | Result and boundary |
| --- | --- |
| `journal.start(context, operationKey)` | Creates objective genesis and OPEN run from host-read final bytes. |
| `journal.appendEvent(expectedHead, operation, context)` | Candidate operations are only strict `reserve` or `close-run` records. |
| `journal.replaceStaleRun(expectedHead, oldRunId, operationKey, context)` | Re-reads/revalidates the complete final commit and manifest, retains the accepted baseline and links a new OPEN run to the current run. |
| `journal.reconcile(expectedHead, intentKey, context)` | Asks the fixed host target reader about the original immutable intent key; candidate outcome objects are unsupported. |
| `journal.replay(context, {requireWitness?:boolean})` | Deterministic reconstructed state, labeled local or freshly externally witnessed. |
| `journal.publishCheckpoint(context)` | Fetches/verifies latest signed prefix, uses host witness CAS, verifies signed response, then reads latest again. |
| `journal.describeRecovery(context)` | Describes exact lock bytes/current head and recovery scope; description grants nothing. |
| `journal.recoverLock(context, approvalReceipt)` | Reuses H03 recovery verification; only an authenticated exact recovery binding and a locally confirmed dead PID can remove the recorded owner. |
| `journal.importLegacy(expectedHead, operationKey, bytes, context)` | Imports one lossless, at-most-1MiB legacy feature-list snapshot. |
| `journal.readLegacy(context)` | Returns exact original bytes, including old evidence. |
| `journal.projectLegacy(context)` | Returns a frozen, read-only diagnostic projection with journal/head/source provenance. |

`reserve` contains `{kind:'reserve',operationKey,runId,units,inputDigest}`.
Reservations require the current OPEN run, its exact still-current host workspace
binding, no pending intent, and sufficient remaining objective budget. Reservation
and immutable inputs precede any future effect. H04 never performs that effect.
Same operation key and same request digest returns its original receipt even if
HEAD advanced; a different request with the same key is POLICY. New operations
must match expected HEAD under exclusive ownership. The `reconcile:` key prefix
is reserved for runtime outcomes and rejected for every candidate-created event.

The host reconciliation reader receives the original intent binding and returns
exactly `{status:'COMPLETED'|'NOT_APPLIED'|'UNKNOWN',outputDigest}`. COMPLETED
requires a digest; NOT_APPLIED requires null. UNKNOWN, unavailable target or
uncertain response leaves the intent pending and blocks a new reservation or
fresh run. Outcomes consume no further budget and never refund spent units.
No target adapter means INCOMPLETE, never blind repetition. H05 and later adapters
must enforce the same idempotency key at the actual effect boundary.

`close-run` contains `{kind:'close-run',operationKey,runId,verdict}` with only
STALE, FAILED or INCOMPLETE allowed. A terminal verdict cannot be rewritten.
Fresh-run lineage preserves every prior record, including an older OPEN verdict;
only the final lineage node is current. Fresh runs do not reset objective budget
or copy candidate equivalence booleans. Byte representation/commit changes need
no new acceptance when the runtime re-proves accepted semantics; semantic changes,
missing inputs and revoked/expired acceptance block. No PASS vocabulary is added
until authenticated verification results have their own implemented contract.

## Witness and recovery guarantees

Checkpoint fields are exactly `{version:1,repositoryId,objectiveId,journalId,
sequence,headDigest,previousWitnessDigest,authorityDigest,runtimeDigest,issuedAt}`.
Wire data is `{checkpoint,receipt}`. Receipt kind is the newly closed
`journal-checkpoint`; subject is `digestData(checkpoint)` and scope is
`digestData({objectiveId,journalId})`. H03's existing Ed25519 verifier checks issuer,
role, kind, repository, authority, signature and current time/revocation. Checkpoint
and receipt issuedAt must match. The host enrolls an external checkpoint issuer;
an in-candidate key or local signature does not establish an external witness.

`readLatestWitness(repositoryId,objectiveId)` must be a host-authenticated current
read outside candidate write access. A manual imported prefix is insufficient
for that setting. Every strong replay calls it anew and requires exact sequence
and head equality with the complete local chain. The locally retained WITNESS
floor rejects older genuine signed checkpoints or conflicting same-sequence
checkpoints across reopening. Advancing checkpoints must link the previously
observed witness digest. Missing intermediate witness links fail closed; the
minimal protocol does not invent a generic remote history synchronization layer.

`compareAndAppendWitness(expectedWitnessDigest,checkpoint)` atomically appends
only after matching the external latest digest and returns signed wire data. It
must implement CAS outside candidate write access. Runtime verification decides
whether the response is valid. An uncertain append requires another latest read
before retry. No configured witness yields LOCAL_UNWITNESSED diagnostic replay;
it cannot satisfy a policy requiring EXTERNALLY_WITNESSED_CURRENT authority.
Tests use ephemeral issuers and simulated transport, not a deployed witness.

Crash after durable append but before HEAD publication preserves the intent and
spent units. Explicit recovery binds exact LOCK bytes, complete head and journal
scope, rechecks approval freshness, and confirms the recorded local PID is dead.
An alive/reused/uncheckable PID blocks. An interrupted RECOVERY owner or damaged
log needs operator investigation; H04 does not implement unsafe automatic repair.
Recovery approval does not waive target reconciliation or authorize a new effect.

## Legacy compatibility and adoption

Original migration bytes remain immutable and retain their historical claims.
Projection maps each imported feature to legacy-readable `state:'blocked'` plus
`verificationStatus:'LEGACY_UNVERIFIED'`; it never maps an old receipt to new PASS.
The existing `--ratio` reader can consume this projection. Provenance and frozen
objects are evidence descriptions, never context or authority handles.

An explicitly adopted consumer must have the host-owned
`.harness/autonomy-v2.json` marker. Root and full-template `verify-feature.sh`
refuse direct legacy verification/writes when that marker exists, even if malformed
or a symlink; read-only `--ratio` remains available. H09 owns installation/adoption
wiring and protected marker custody. The marker is a compatibility guard, not an
independent trust anchor. H04 does not create an adoption or acceptance receipt.
Unadopted v1 consumers retain their existing behavior and prerequisites.
Rollback restores the separately preserved original v1 snapshot under operator
control, disables adoption, and retains the journal for later inspection; editing
a projection cannot certify any historical v2 verdict.

H06 adds closed signed continuation registration, monotonic grant revocation and
categorized attempt events. The versioned event schema/runtime binding advances
explicitly. Replay derives three category counters and a total; old reservations
count as mechanical attempts and fresh runs never reset them. See
`contracts-continuation-v1.md` for signed limits and compatibility boundaries.
