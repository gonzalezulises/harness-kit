# Bounded continuation and objective budgets — H06

Continuation extends the existing journal and H05 capabilities. It requires an
operator-bound journal, accepted context and the existing signature verifier.
It creates no issuer keys or approvals. Existing v1 approvals without this
explicit continuation subject acquire no reusable permission.

| Public method | Contract |
| --- | --- |
| `describeContinuation(input,context)` | Computes a closed `remediationGrantSchema` subject for external approval; grants no permission. |
| `evaluateContinuation({grant,approval},observedDefect,context)` | Revalidates the signed subject, accepted invariants, closed regression cases and current run; durably records the original signed wire once and returns an opaque continuation handle. |
| `prepareCapability(id,args,context,continuation)` | Existing H05 preparation accepts that handle and privately binds permission to its exact recomputed plan. |
| `executeCapability(permit,lease)` | Rechecks authority, grant revocation, allowed capability/output paths and budgets at use. Existing exact manifest, lease and postcondition checks remain required. |
| `spendBudget(kind,objectiveId,operationKey)` | Reserves one attempt against the most recently successfully evaluated continuation in this runtime; journals the category and grant digest. It executes no review or product test. |
| `revokeContinuation(grantDigest,operationKey,context)` | Records a monotonic denial for a known grant. Cannot restore permission or alter the original grant/acceptance. |

The strict input to description contains `acId`, `paths`, `capabilities`,
`regressions` and `limits`. There are no budget defaults. The externally signed
`bounded-grant` receipt subject is `digestData(grant)` and its scope digest is
`digestData(grant.scope)`. The closed schema separates the human gate from
permission: AC, `canonical-record-representation` defect class,
`canonical-record.v1` violated rule, accepted baseline/authority and invariant
digest bind the signed human decision. The invariant digest covers the complete
accepted identity records and host file registry, including security,
architecture and normative classes. Fresh runs must preserve the original
accepted semantics and every protected byte; registry, scope or authority changes
cannot be asserted away through `same_*` candidate fields.

`observedDefect` is exactly `{gateDigest,path}`. The runtime resolves the signed
gate and recomputes a noncanonical ordinary `record.v1` representation at that
path from the current verified binding. A supplied defect name or boolean is not
proof. A changed AC/rule requires a distinct signed subject. Supported effects
remain only canonical record and closed source/digest writes; every output must
be in both the accepted context and continuation scope.

Each durable regression is exactly `{path,afterBase64,expected}`. The original
accepted bytes are durably retained by the journal's initial binding. For every
ordinary source in the grant, coverage requires both a representation-changing
case that preserves canonical and semantic identity and a semantic counterexample
classified `HUMAN_REQUIRED`. The runtime re-runs the closed identity classifier
and compares the signed expectation. Identical accepted bytes cannot substitute
for exercising the representation invariant. Missing coverage, changed expected
results, arbitrary callbacks and unknown proof contracts block. This proves only
these closed identity/classification contracts. Product behavioral regressions,
independent model review and arbitrary subprocess tests remain unavailable;
unsupported requested capabilities return `BLOCKED_BY_REQUIRED_CAPABILITY` with
`execution:NOT_EXECUTED`.

Signed limits contain exactly `product-semantic-review`,
`harness-implementation-review`, `mechanical-remediation-verification`, and
`total`, all nonnegative safe integers. `total` must equal the existing
operator-configured journal cap. The first recorded continuation fixes category
limits for the whole objective journal; later grants cannot increase or reset
them. Earlier H04/H05 reservations count as mechanical units. Every subsequent
reservation needs a category; public generic reservation input cannot supply
private categories or grant provenance. H05 exact-plan approvals still work,
consume mechanical/category and total budgets, and grant no continuation.

All counters derive from replay, including attempts with no successful effect.
`budget-spend` keys are idempotent for the same category and grant; changed inputs
with a reused key are policy errors. Effect reservations retain private
`local-capability.v1` provenance and the continuation digest. Fresh runs,
NOT_APPLIED outcomes, new grant IDs and reopen do not refund units. Budget events
are attempt accounting, not execution evidence or review acceptance. An existing
effect intent is reconciled without another reservation; generic target
reconciliation cannot settle it. Explicit H05 reconciliation may establish actual
postconditions of already reserved work after grant expiry/revocation, but never
republishes bytes or grants future permission.

Replay rechecks original signed grant envelopes at their recorded event time
using the same signature verifier. Historical expiry/revocation does not rewrite
past accepted events. Current permission use separately checks the current host
time/revocation checkpoint and recorded revocations. Replay remains explicitly
local/unwitnessed unless the existing external witness contract is satisfied.
Host journal custody and runtime integrity remain prerequisites; there is no
same-UID hostile writer guarantee or automatic authority recovery.

Artifact acceptance stays separate. Permission to generate/remediate/review does
not accept new artifact bytes: an old baseline-acceptance receipt cannot verify
a new golden/baseline digest. This H06 wire changes the journal runtime binding;
old contract journals are not silently upgraded, reinterpreted or certified.
