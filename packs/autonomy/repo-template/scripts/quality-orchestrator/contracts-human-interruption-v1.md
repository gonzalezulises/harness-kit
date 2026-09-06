# Human interruption contract v1 (product.v2 opt-in)

The owner-approved scope is recorded in
`docs/implementation/2026-09-06-human-interruption/plan.md`.
Select `journal.contract: product.v2` and version 2 product inputs. Existing
product.v1, review.v1 and journal-v1 contracts and their historical evidence keep
their meanings. The v2 journal uses a distinct event/runtime binding. Runtime
source custody includes every sibling .mjs, including the modified Codex worker.
There are no additional dependencies, providers or services.

Existing `openRuntime` product entrypoints describe, bind, execute, resume and
run v2 objectives. The new `describeProductRemediation` and
`applyProductRemediation` methods are available only on v2. All use the same
journal, original signed objective, trusted clock, source scope and containment
capabilities. Fixtures are visibly FIXTURE and never establish real model or
production readiness.

## Judgment and infrastructure

The v2 worker supplies version 2 review output. Severity, description, source
selection and the meaning of its approved counterexample remain reviewer
judgment. The harness resolves only unambiguous manifest paths/lines and
registered regression case IDs. It derives finding and durable test IDs from
the objective and judgment/case, ignoring model infrastructure IDs. Unknown
references and unsupported counterexamples fail validation; normalization does
not invent evidence or alter severity, rationale or domain meaning.

The normalized payload is `harness.normalized-review.v1`, without a self-hash.
The real controller validates output, normalizes it, uses journal.putObject,
appends NORMALIZED with the external digest, rereads with getObject and ingests
only that verified object. OBSERVATION checks the same object again. Thus:
`sha256(canonical persisted payload) == ledger digest == ingestedBytesDigest`.
A lost object cannot be ingested from memory. Resume can reconstruct and persist
identical bytes from the original retained completed worker acknowledgement,
then reread; it does not repeat the worker operation.

Every attempt reserves signed resources before execution. FULL and FIX counters
count valid independent FULL/FOCAL judgments after durable ingest; author fix
proposals have a separate counter bounded at two. A reviewer turn explicitly reported failed with matching IDs, unchanged source
and clean process termination yields a retained transport-failure acknowledgement.
Only this v2 reviewer result permits a new durable attempt. Premature exit,
timeout, ambiguous protocol, source mutation and author failures stay uncertain.
Known completed malformed
review output uses durable per-step retry counts and failure fingerprints. It
cannot consume a judgment, reset the signed total resource limit or reuse a
session as independent review. Retry exhaustion produces OPERATIONAL_BLOCKED,
with evidence and counters retained. An uncertain effect retains its original
key and pending intent; missing acknowledgement does not authorize redispatch.

## Remediation and decisions

The closed `canonical-record.v1` rule names three distinct, originally mutable
paths. At description time it signs the original typed record semantic digest,
before hashes and exact canonical source/golden/corpus outputs. Application
recomputes that transformation, checks all other source bytes and current
unexpired authority, then reserves an intent under journal custody before
writing only those bytes. Both description and the intent transition require
the current OPEN run. No boolean equivalence claim, new rule added later or
signature renewal authorizes a delta. A mechanically equivalent normative run
can be replaced through the existing append-only replacement API, retaining
objective authority and all counters.

HUMAN_DECISION_REQUIRED has ten closed categories and four supported answers:
missing decision, uncovered authority, actual alternatives and consequences.
The reached semantic-delta and baseline-promotion paths derive those answers
from the original grant and observed source/reference. Mechanical recovery is
AUTO_REMEDIABLE. Unknown capability/authorization causes remain operational
diagnoses rather than invented Product Owner decisions. Prepared handoff merge
is NOT_EXECUTED; a local prepared commit is not a published PR or merge grant.
The implementation does not provide a general diagnosis or repair engine for
all ten human-decision categories.

## Authorized release continuity and limits

`runRelease(handle, {authorizedExecutions, authorizedActions, maxSteps})` drives
existing release APIs only. Supplied exact signed wires are matched to the next
obligation, re-described and verified. Pending operations reconcile their
original keys. Missing/invalid inputs stop as OPERATIONAL_BLOCKED with
OPERATIONAL_DIAGNOSIS; they never become execution authority. Exact later
inputs may be supplied on a subsequent call without restarting the objective.
Review digests and deployment IDs learned during execution cannot be signed in
advance by this driver. It neither creates signatures nor publishes/deploys by
itself. The local signed fixture reaches production evidence with nine distinct
effects across supplied batches and repeats without additional effects.

Ten Aurobalance-style cases use synthetic protocol subprocesses and local
repositories; Aurobalance itself is not executed or modified. A03 first reports a synthetic adapter rejection of a credential-shaped
infrastructure ID, cleanly terminates that reviewer attempt, then observes a
valid independent attempt and deterministic ID replacement. No real credential
detector is exercised; this test does not certify secret detection or permit
sensitive judgment/evidence. Missing real authentication, containment and production
observations remain explicit NOT_EXECUTED limitations. Historical blocked F09
and P0 evidence is not recertified.

## Retained observation publication

Both product versions reconcile a retained acknowledgement after transient
publication contention. At most three custody acquisitions are attempted,
with bounded 250/1000 ms yields; no effect or resource reservation is repeated.
After acquiring custody, the controller rereads current state and authority,
checks the current source and OPEN run, and publishes the retained result only
if the original intent still owns that key. Another completed publication is
reused. Persistent contention returns BLOCKED_BY_OWNERSHIP with the ack and
pending intent preserved; only the existing owner may release its lock.
