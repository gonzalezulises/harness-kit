# Approved GitHub Actions executions — F24

This extension implements the positive H07/H08 controller path. The earlier
`contracts-review-v1.md` and `contracts-release-v1.md` describe the preserved
unconfigured/diagnostic interfaces. Their former positive-backend gaps are
superseded here. The controller keeps its existing persistent journal; GitHub
Actions executes one registered operation. There is no scheduler or provider
framework. Installation and offline fixtures confer no live acceptance.

## Operator bootstrap and authority

`openRuntime({...host, actions})` accepts a host-only binding validated by
`actionsProfileSchema`, plus `token`. Pin owner/repository and numeric repository
ID, workflow ID/path, an operator-protected immutable **lightweight tag**, its
exact commit SHA, the supervisor contract digest, registered operation kinds,
one target or `null`, and, for Codex, the worker/protocol/containment digests.
Candidate request data cannot change these fields or choose URLs, credentials,
JavaScript callbacks, verifier modules or signing keys. Keep the token and
supervisor signing key outside candidate and Codex access. Enroll the Ed25519
observation issuer with role `execution-supervisor` and kind
`execution-observation`. Enroll owner issuers separately for `execution-budget`,
`artifact-acceptance` and `deployment-authorization` as appropriate. No keys or
credentials are generated, discovered or copied by this package.

The workflow must be available for `workflow_dispatch` on the repository's
default branch and at the approved tag. The tag must resolve directly to the
pinned commit. Controller preflight reads repository identity, workflow identity
and tag resolution before any spend. GitHub API version `2026-03-10` dispatch
returns HTTP200 with `workflow_run_id`, `run_url` and `html_url`; all three are
checked. This contract is documented in the [GitHub workflow dispatch REST
reference](https://docs.github.com/en/rest/actions/workflows#create-a-workflow-dispatch-event).

Before describing or dispatching work, the authority boundary must have an
enrolled `execution-supervisor` issuer for `execution-observation`; missing
enrollment stops before HTTP requests, reservation or budget spending.

A public API accepts only described requests and externally signed budgets.
Every standalone execution has a fresh, narrowly scoped `execution-budget`
subject with exact objective/journal/run/key/category, request/profile digests,
baseline and immutable objective/category limits. It does not manufacture a
canonical-record defect or reuse a remediation grant. `describe*` grants no
permission; the external owner signs its returned `budget` using
`approvalSigningBytes`, kind `execution-budget`, subject `digestData(budget)`
and scope `digestData(budget.scope)`.

## Current operation authority at the dispatch boundary

The closed release, review and catalog entrypoints take one immutable data
snapshot of the caller wire before the asynchronous preflight. The same captured
request is used to reconstruct the current obligation and construct the signed
execution descriptor. Replacing caller data while preflight awaits cannot lend
fresh authority to an older descriptor. Immediately before a new reservation,
under journal ownership, the controller rechecks runtime pins, owner/objective
and action-specific approval, review policy/catalog/shadow and prerequisite
freshness as applicable. This is separate from the execution-budget check.

The private journal claim returns fresh dispatch ownership only to the process
that creates the durable reservation. An idempotent public APPENDED receipt is
not that ownership. A second process uses original-key reconciliation, with no
second POST or charge. Owner interruption after reservation leaves uncertainty
in the original history rather than transferring a new dispatch right.

The external supervisor must independently validate the exact descriptor's
current objective, applicable action approval, review policy and prerequisites
immediately before performing the operation, as well as its execution budget
and fixed profile. The controller's earlier check cannot establish authority at
a later remote start. Local fixture evidence exercises the controller boundary;
no currently enrolled live supervisor or accepted isolated host is claimed.

## Durable dispatch and observations

Before dispatch, canonical descriptor bytes are fsynced under their content
hash, then the existing journal `reserve` transition atomically charges one unit
and records that hash. `eventSchema` and `JOURNAL_RUNTIME_BINDING` are unchanged.
Private descriptor/observation objects and the immutable acknowledgement are not
candidate append APIs. The journal reducer verifies the narrow budget on replay
and preserves total/category spending. Concurrent identical requests dispatch
once. Failed, cancelled, timed-out and uncertain starts never refund units.

A successful dispatch returns `EXECUTION_PENDING`. A request error or lost
acknowledgement returns `INCOMPLETE`; it never retries POST. Resume uses the
recorded original run. If no acknowledgement survived, the workflow's exact
`run-name` must be `harness:${{ inputs.descriptor_digest }}`. The controller sends
`descriptor` and its separately computed `descriptor_digest` inputs; the
supervisor rehashes descriptor bytes and verifies their equality before work. Bounded authenticated run search
requires exactly one such run, then the signed observation must bind its same
original descriptor. Zero, ambiguous or truncated searches stay `INCOMPLETE`.
Only attempt1 is supported: reruns are separate effects and cannot replace it.

The fixed HTTPS transport checks repository/workflow/ref/SHA/run/attempt and
retrieves exactly one artifact named `harness-observation-<runId>-1`. Its ZIP
contains exactly `observation.json`. Bounded stored/deflated ZIP decoding never
extracts paths or executes files. Only an HTTPS Azure Blob artifact redirect is
supported, without the GitHub Authorization header; arbitrary redirects stop.
Each request has a 15-second deadline and responses/decompression are capped at
2MiB. The complete descriptor must fit60,000 UTF-8 bytes. Larger repositories
need a separately reviewed object transfer extension and currently fail before
spend; this version does not silently fetch an unbound source checkout.

`observation.json` contains `{observation,approval}`. `observationSchema` fixes
its domain/version, descriptor and output digests, operation key, numeric
repository/workflow/run/attempt, workflow path/SHA, supervisor contract digest,
output and issue/expiry times. Sign the whole observation with the existing
Ed25519 envelope machinery using kind `execution-observation`, subject
`digestData(observation)`, scope
`digestData({descriptorDigest,runId,runAttempt:1})`, and matching issue/expiry
times. Generic workflow success, raw model JSON and signatures of unrelated
outputs are insufficient. Only the actual enrolled supervisor can attest its
registered execution. The controller stores the envelope by content digest and
anchors it in the existing `outcome` event; each replay re-verifies provenance.
Generic `journal.reconcile` refuses these backend-owned intents.

## H07 and the concrete Codex worker

For authenticated discovery, call `describeReviewCatalog({operationKey,
authMode,limits},context)`, sign its budget, `executeReviewCatalog(wire,context)`
and `resumeReviewCatalog(key,context)`. A complete authenticated catalog from the
pinned worker replaces the fixture only when host `actions.review` is configured.
`preflightReview({policy,approval},context)` freezes the first compatible pair in
the owner's approved model/effort order. Missing/incomplete/stale catalog,
unsupported auth, duplicate models or missing containment registration block.

Build the existing exact Git shadow, then
`describeReviewExecution(binding,shadow,{limits})`, sign the budget and call
`reviewRun(binding,shadow,wire)`. `resumeReview(binding,shadow)` produces
`REVIEW_VERIFIED` only after authenticated run/output bindings, strict local JSON
and finding-location validation, and a fresh primary/shadow manifest check.
Raw `validateReview` retains its diagnostic behavior and never grants provenance.
Review counterexamples remain unexecuted data. Catalog capability is checked
at the durable reservation time. Reconciliation compares the original frozen
descriptor using that recorded time; later catalog expiry does not invalidate
an already-started review. The review observation's own freshness is checked
independently. Worker stdout uses a streaming fatal UTF-8 decoder, preserving
characters across chunk boundaries and rejecting incomplete final sequences.

`runCodexWorker(hostConfig,request)` is a concrete fixed **host-side** helper for
a pinned Codex app-server executable. It validates its own bytes and the pinned
binary/protocol, checks exact source files/modes, starts only `app-server --listen
stdio://`, uses a fresh allowlisted environment, reads `account/read`, follows
all `model/list` pages, repeats model/effort/cwd/approval parameters in thread and
turn, disables dynamic tools and external environments, and observes one final
answer plus the matching completed turn. It rejects changed parameters, protocol
approval requests, failures, missing/ambiguous output, source changes and output/
deadline overruns. It requires a clean process exit and kills the original process
group. It never reads credential bytes or signs receipts. Its result is
`WORKER_OBSERVED`, not verified controller evidence.

The operator must launch the helper in its **tested actual Linux isolation**:
read-only exact source, scratch-only writes, isolated HOME with narrowly scoped
model authentication and no inherited configuration, no MCP/plugin discovery,
restricted model-only egress, no host sockets/mounts, no signer/GitHub/deployment
credentials, and complete descendant cleanup including namespace/process-group
escape prevention. These properties cannot be established by `shell:false`,
Codex's read-only flag or the worker's cleanup alone. The controller pins the
operator's containment contract; this package does not implement a portable OS
sandbox. The operator also pins the complete dependency image/artifact registry;
the helper checks binary/protocol/self bytes, not arbitrary transitive native
loader state. Unsupported containment must remain unconfigured.

The protocol path supplied to the helper is the pinned Codex0.153.4
`v2/TurnStartParams.json` (or its identical generated location), whose
`properties.outputSchema` establishes schema transport support. The isolated
source root contains exactly the descriptor's files with original modes; it
must be materialized from those bytes by the supervisor before the worker is
launched, then mounted read-only. The controller already verified that those
files belong to the exact Git target. The worker does not checkout candidate
code or create fake commits.

## H08 one-obligation execution

`describeReleaseExecution(objective,{operationKey,limits,...options})` derives
the next registered operation. Sign the returned budget, then call
`executeReleaseObligation(objective,wire)` and
`resumeReleaseExecution(objective,key)`. No loop or scheduler is added. On reopen,
rebind the signed objective and resume the original key; do not describe a new
operation to recover a pending effect.

For independent review, `options` supplies the opaque `reviewBinding` and
`reviewShadow` built in that same context. The operation key must match its signed
review policy. H08 obtains findings/provenance privately from the journal; a
caller cannot import simulated release events or a success boolean.

For artifact acceptance, `describeReleaseApproval(objective,'accept-artifact')`
returns the exact signing expectation, including the latest verified review's
evidence digest. The fresh owner approval must be issued at/after that review.
Supply it as `actionApproval` when describing the execution. Deployment uses
`describeReleaseApproval(objective,'deploy')` and a separate scoped deployment
authorization. Rollback uses `describeReleaseApproval(objective,'rollback',
{deploymentId,previousDeploymentId})` and the same exact identities in the
`rollback` option. A successful rollback invalidates this objective and preserves
history. Missing target or registration blocks before reservation.

A signed terminal deployment FAIL is a known result, not an uncertain intent.
Both that result and expired/superseded deployment evidence yield
`revalidate-deployment` with the **real original journal operation key**.
`resumeReleaseExecution` on that key returns its immutable known result without
spending or redispatch. A still-pending effect continues to return its original
`reconcile-operation` obligation and cannot start readback or other work.

To revalidate a known deployment, use
`describeReleaseApproval(objective,'readback',{operationKey:originalKey})`.
The separate `deployment-authorization` binds original operation, original
verified evidence digest, deployment ID and the exact objective/target; it must
be issued at or after that original result. Supply this approval to
`describeReleaseExecution` with a **new** readback operation key and sign its own
narrow execution budget. The fixed deployment workflow receives
`operation:'deployment', action:'readback'` plus the original identity. This
branch must only perform authenticated target readback; it must never run the
deploy command. The operator's pinned workflow contract must implement this
explicit action. Unknown actions must fail rather than fall through to deploy.

A successful signed readback adds an immutable `deployment-readback` observation
and requires new separate smoke and observability executions after it. It does
not overwrite the original failed/expired receipt. Fresh deployment authority
and a newly scoped objective remain necessary for a different deployment effect;
this recovery path never re-executes the original deployment.

The registered workflow must actually execute each operation and supply:

| Operation | Observed output |
| --- | --- |
| slice, merge, integrated-verification, external-gate, artifact-acceptance | `{result:'PASS'|'FAIL'}` from its registered execution, bound to the exact descriptor |
| catalog | Complete authenticated auth/model/schema catalog and exact worker pins |
| review, independent-review | Actual worker `{output,receipt}`; the controller parses output/findings locally |
| deployment, or deployment with `action:'readback'` | Result, deployment ID and authenticated target `readback` containing exact integrated commit, artifact digest, target and deployment ID |
| smoke, observability | Result, current deployment ID and distinct `executionId` equal to that operation's GitHub run ID |
| rollback | Result, current/previous deployment IDs and authenticated readback identifying the restored previous deployment and target |

A consumer must supply the actual target adapter, product/integration checks and
separate smoke/observability executions in the pinned workflow. The library does
not invent a service target, commands or provider-specific deployment. The
supervisor must observe those operations itself; a generic signing utility that
signs a supplied PASS is not an implementation of this contract. No runnable
placeholder workflow emitting successful evidence is shipped.

Only fresh ordered evidence for the exact objective/commit/artifact/target can
produce `PRODUCTION_PASS`. Deployment must follow verification, review,
acceptance and any external gate; smoke and observability must follow deployment
with distinct execution IDs. A later failure invalidates an earlier success.
Current local journal assurance remains explicitly `LOCAL_UNWITNESSED` unless
an external checkpoint was independently established; authenticated execution
provenance does not turn a mutable local journal into a witnessed audit log.

## Small controller integration example

The operator bootstrap supplies `host`, accepted `context`, and the existing
signed `objectiveWire`. The external approval channel returns a real signed
budget; it is not implemented by the controller or candidate.

```js
import {openRuntime} from './scripts/quality-orchestrator/index.mjs';
const runtime = openRuntime(host);
const objective = runtime.bindReleaseObjective(objectiveWire, context);
const proposed = runtime.describeReleaseExecution(objective, {
  operationKey: 'verify-slice-2026-09-06',
  limits: approvedObjectiveLimits
});
// Present proposed.budget to the existing external owner approval channel.
const started = await runtime.executeReleaseObligation(objective, {
  request: proposed.request, budget: proposed.budget, approval: signedBudget
});
// Later, including after controller reopen and objective rebind:
const observed = await runtime.resumeReleaseExecution(objective, started.operationKey);
const next = runtime.nextObligation(objective, runtime.replayRelease(objective));
```

The operator workflow reads the descriptor **as data**, verifies its enrolled
budget and fixed profile before work, uses the `descriptor_digest` input for its exact
`run-name`, and independently signs the observed output only
after its registered execution and cleanup. Use GitHub expression inputs via a
trusted parser/environment file, never shell interpolation of the descriptor.
Run candidate/Codex work in a distinct isolated worker without supervisor keys.
Keep signing and artifact publication in that trusted supervisor. A single job
with candidate code and signing/deployment credentials is not this boundary.

Offline tests exercise actual local protocol processes and test-only interception
of the fixed HTTPS transport. No live GitHub dispatch, authenticated Codex call,
deployment, smoke, observability or rollback was executed in this development
session. The cancelled Codex preflight and earlier interrupted broad-review
receipt remain historical. The 2026-09-07 permitted independent static global
review completed with findings retained in the closure inventory; it does not
retroactively change either historical outcome or establish a live pilot.
