# Release obligations and unavailable execution — H08

H08 extends the existing runtime, signed authority and journal. It adds one
closed obligation evaluator and data-only contracts. No deployment/review
backend, service, arbitrary callback verifier or authenticated receipt import is
implemented. `PRODUCTION_PASS` is unreachable in this build.

| API | Meaning |
| --- | --- |
| `describeReleaseObjective(input,context)` | Binds a proposed production objective to the current accepted context and exact journal commit; grants no permission. |
| `bindReleaseObjective({objective,approval},context)` | Rechecks an exact scoped `bounded-grant` signature and returns a private objective handle. This approves the objective, not artifact acceptance or deployment. |
| `replayRelease(objectiveHandle)` | Reads the existing journal internally and returns a private snapshot handle. |
| `nextObligation(objectiveHandle,replayHandle)` | Rechecks current authority, complete workspace binding, journal head and run; derives a typed obligation/stop. |
| `certifyRelease(objectiveHandle,replayHandle)` | Uses the same evaluator and always reports noncompletion in this build. It accepts no success boolean, raw JSON or serialized replay. |
| `prepareDeployment(objectiveHandle,approval)` | Checks an exact current deployment authorization, then refuses unavailable execution before reservation or side effects. |
| `prepareRollback(objectiveHandle,{deploymentId,previousDeploymentId},approval)` | Checks distinct exact deployment identities and action-specific authorization, then refuses the unavailable rollback capability. |
| `reconcileDeployment(objectiveHandle,operationKey)` | Refuses unavailable authenticated target reconciliation for an existing pending key; never retries or settles it through generic target JSON. |
| `simulateRelease(objective,{provenance:'SIMULATION',now,events})` | Runs the same closed evaluator on strict synthetic wire evidence; always returns `SIMULATION`, `NON_AUTHORITATIVE`, `productionPass:false` and `certification:NOT_EXECUTED` on valid input. |

The description input is exactly `{artifactDigest,target,slices,externalGate,
maxEvidenceAge}`. `target` is the single closed description
`{kind:'deployment.v1',id,environment:'production'}`; it is a target identity,
not a configured or approved execution adapter. `externalGate` is a required
field containing an exact gate ID or `null`; no default disables it. Slice IDs
are unique and nonempty. The runtime supplies repository, authority, accepted
baseline, objective/journal IDs and current integrated commit. The supplied
artifact digest remains a claim pending its independent acceptance/execution
obligations. Signed objective data may be durably stored by its caller and
rebound after reopen; reloading re-verifies the signature and current context.
This module writes no new journal event or competing release-state file.

Objective approval uses `kind:bounded-grant`, `subjectDigest:digestData(objective)`
and `scopeDigest:digestData(objective.scope)`. Deployment approval uses the separate
`deployment-authorization` kind with the same subject and scope digest computed
from `{...objective.scope,action:'deploy'}`. Rollback uses that kind with
`subjectDigest:digestData({objectiveDigest:digestData(objective),action:'rollback',
deploymentId,previousDeploymentId})` and scope `{...objective.scope,action:'rollback'}`.
All use the existing pinned issuer, repository/authority, expiry and revocation
checks. Another artifact/target/commit/action signature fails. A remediation
continuation or Release Please version/release event confers none of these rights.

The evaluator orders slice verification, integration, revalidation of the exact
integrated commit, independent review, artifact acceptance, an external gate if
required, deployment, functional smoke and observability. Evidence binds the
entire objective digest, repository/objective, commit, artifact and target with
its environment. Preview evidence cannot satisfy production. Revalidation must
follow integration, review must follow revalidation, acceptance must follow
review, and deployment must follow those obligations and the configured gate.
Times must be ordered and not future-dated; expiry and the objective's maximum
age are checked each time. A later failed observation invalidates its earlier
success. Smoke and observability bind the current deployment ID and distinct
execution IDs; separate result names do not establish independent execution.

A deployment receipt needs the exact preceding intent key and approval digest.
Uncertain intent takes precedence over new work and retains its key; another
intent before reconciliation returns `INCOMPLETE`. A rollback observation
invalidates the present objective, preserves history and requires remediation
with a newly scoped objective and fresh certification. These success traces are
**contract simulations only**. No simulation can be imported as runtime evidence,
and even `nextObligation.kind:'complete'` is explicitly noncertifying.

The runtime presently has zero authenticated slice/integration/product-test,
independent-review, artifact-execution, deployment, smoke or observability
receipts. In particular H07's validated model output, signed raw JSON and
fixture discovery supply zero authenticated review success. Runtime decisions
therefore retain every required obligation and return
`BLOCKED_BY_REQUIRED_CAPABILITY`; existing pending journal work instead returns
`INCOMPLETE` with its original reconciliation key. A replay handle becomes stale
when the journal head/run or final workspace changes. Changing the integrated
commit requires a freshly described and signed objective. Known unavailable work
never calls `spendBudget`, reserves an intent or changes grants/counters. Existing
H06 category/total reservations remain intact across retries and reopen; their
presence is accounting, not execution evidence.

**Unimplemented:** positive production scheduling/execution, fixed real target
adapter/readback, authenticated release receipt issuance/import, actual
integration/product verification, real smoke/observability, deploy/rollback
reconciliation and authenticated rollback invalidation. H07's authenticated
review backend is also unimplemented. Supporting these requires actual approved
host/target provenance and reservations immediately before actual starts, with
started failures retained; it cannot be enabled by an assertion or fixture flag.
**NOT_EXECUTED:** real release acceptance and live deploy/smoke/observability/
rollback runs. No target or deploy permission was configured for this session.
The local tests demonstrate only calculation, bindings, signature checks,
refusal and local journal/budget integration. Runtime integrity, trusted host
custody and existing local/unwitnessed journal limitations remain unchanged.
