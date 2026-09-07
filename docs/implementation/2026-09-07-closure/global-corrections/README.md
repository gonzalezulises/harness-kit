# GR01 / GR02 / GR04 local correction evidence

This directory records a new bounded corrective wave against the exact PR33
implementation at `0a51623b5db42951a6091847a179262182abd67d`, on the prepared
worktree with the adopted-main merge staged by the controller. Historical tests,
oracles, receipts, bindings and source snapshots are not rewritten.

The new `AC-closure-supervisor` oracle and three test-only files were written
before changing production. `red-source/` preserves every top-level runtime
module plus the exact package manifests from the defective implementation.
`environment-attempt.log` records an initial unavailable `zod` import: it is an
environment failure, **not** the causal RED. The controller then copied the
already installed local yaml/zod dependencies with byte-identical lockfile;
no network fetch or install script ran.

The causal regression uses two actual child controller processes with the same
signed request and real persistent journal. A test-only filesystem rendezvous
holds both after they saw no existing intent and before descriptor publication.
The first proceeds to durable reservation and mocked fixed-HTTPS dispatch; then
the second proceeds. The regression counts emitted POST attempts and independently
replays one journal debit. A second real process case exits after durable intent
and before POST, then resumes the original key without dispatch or a fabricated
observation. No same-process Promise race substitutes for that experiment.

Clock cases expire only the separate action approval, objective approval, review
policy, or prerequisite evidence on the final read-only preflight response. The
execution budget and accepted context stay valid. Assertions require no new
reservation, no spend and no dispatch. The literal output cases exercise real
accepted documents, exact signed grants, leases, changed bytes, complete output
scope, frozen-file preservation, delta, final postconditions and one debit.

All signatures, Git repositories, fixed HTTPS responses, clocks and child
processes here are local engineering fixtures. They do not establish production
supervisor confinement, authenticated remote execution, deployment/readback,
consumer or baseline acceptance. GR03 protected-CI isolation and GR05 integration
ancestry policy are outside this correction's scope and remain untouched.

The correction adds a private `claimExecution` journal operation sharing the
existing filesystem lock and append reducer. It distinguishes newly created
reservations from retrieved receipts without altering the public `APPENDED`
shape, event schemas or journal runtime binding. Only the new reservation's
caller can issue POST; a losing caller reports the existing pending intent and
no local start. A crash leaves the durable intent uncertain as before.

Release and review supply their own closed internal validation to execution.
After asynchronous preflight and descriptor retention, the journal invokes that
validation under ownership only for a new reservation. Release reloads its
objective, action approval and evidence-derived obligation; review reloads its
policy, catalog and shadow binding. The catalog route validates its own pins and
request and does not acquire a fictional release action requirement. No public
wire, host setting, exported index method or arbitrary verifier selector is added.

Capability outputs now use a null-prototype dictionary and must exactly equal
the closed operation's required path set before permit construction. The existing
null-prototype complete workspace inventory and frozen-file regression remain
unchanged.

The controller-side check cannot close the time interval before an actual remote
effect. The operator's pinned supervisor must independently check the specific
action's current authority and prerequisite evidence immediately before that
effect, separately from execution-budget verification. Release descriptors bind
the objective digest and include applicable action approval; the supervisor must
have independently available authoritative objective and prerequisite records.
Catalog discovery has its own bounded catalog/pin contract, not deployment or
artifact-acceptance authority. The root controller owns that contract-document
update, integration notes, full verification and any later publication.

Final scoped verification: new RED 11 failures/1 pass (exit 1), unchanged new
GREEN 12/12, affected legacy 150/150, original frozen-file regression 2/2, and
five production syntax checks all exit 0. All four receipts were rechecked for
current hash consistency after the final run. Exact argv, counts and hashes are
in the receipts and validation-summary.json. Full repository verification and
independent scoped review remain root-owned and are not claimed here.
