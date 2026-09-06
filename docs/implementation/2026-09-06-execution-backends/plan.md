# Execution backends — continuation of H07/H08

## Authorization and scope

The owner requested **“desarrolla lo faltante”** on 2026-09-06 after delivery
of cca4b16. This continues the approved optional-pack implementation and the
explicit constraint against overengineering. The existing branch is isolated
from main and clean; startup completed with286 passing core assertions.

Implement one closed GitHub Actions connection for operator-owned review and
release workflows. Reuse the existing runtime, typed approvals, budget reducer,
Git shadow, release obligations and append-only journal. No service, provider
framework, database, arbitrary shell capability or mandatory legacy dependency.
The controller retains its existing persistent journal; Actions executes work.

Actual deployment remains an explicitly authorized consumer operation. Do not
invent a consumer target, enroll keys, copy credentials, accept a baseline or
merge this branch. The cancelled authenticated Codex preflight is not retried.
The interrupted whole-branch review remains INCOMPLETE and is not resumed by
this work. Review of the new implementation is limited to its corrective scope.

## Global constraints

- WIP=1. Keep historical contracts, receipts, candidates and decisions intact.
- Preserve eventSchema and JOURNAL_RUNTIME_BINDING so old journals still replay.
- Persist intent before an external effect; reserve once, never refund or
  redispatch an uncertain request. Reconcile its original operation key.
- Candidate data cannot select credentials, trust roots, workflow code,
  arbitrary endpoints, callbacks or proof factories. Host bootstrap pins them.
- Receipt authenticity requires an enrolled execution-specific issuer and exact
  request/workflow/run/output bindings; a workflow success or raw JSON is not proof.
- Missing host capability stops before budget spending. Fixture tests are not
  evidence of live Codex containment or a production deployment.
- A standalone operation uses its own narrowly signed execution budget; do not
  fabricate a canonical-record defect or broaden an old remediation grant.
- The operator's configured workflow must actually execute and attest its
  registered operation. A signing helper cannot turn an input PASS into observed
  execution. Deploy requires real target readback and separate smoke/observation.
- Existing tests remain unchanged unless a real compatibility requirement is
  documented. New critical criteria get actual assertion RED before code.
- Focused ordered validation, one required full check, one task review. Repeat
  only to resolve a concrete defect or required gate. No new broad audit.

## Task 1 — F24 — Connect approved executions and their evidence

Read the existing runtime boundary document and the original H07/H08 acceptance
requirements. Deliver the smallest coherent positive path:

1. A fixed bounded HTTPS GitHub transport for dispatch, exact run/attempt and
   supervisor output retrieval. No caller-selected fetch/verifier or production
   fixture mode. Keep acknowledgement identity; timeout/no acknowledgement is
   INCOMPLETE and never causes another dispatch. Approved immutable workflow ref
   and actual run SHA/identity must agree. Never send credentials on redirects.
2. Private content-addressed descriptors/observations anchored by existing
   reserve/outcome events. Expose only the narrow internal object operations
   needed from journal. Generic reconciliation must refuse backend-owned intents.
   Reopen must preserve pending effects and category/total spending. Verify an
   execution-specific Ed25519 envelope with existing crypto machinery.
3. H07 authenticated catalog/pinned model flow, exact shadow and prompt binding,
   remote review dispatch/reconciliation, strict local output/finding validation,
   private verified review provenance. Preserve portable diagnostic/refusal APIs.
   Provide the concrete fixed Codex transport/worker integration where it can
   obey the approved host boundary. Unsupported containment stays explicit.
4. H08 consumes only observations derived from these verified journal records.
   Expose one-obligation execution/resumption through a fixed approved workflow;
   no new scheduler. Preserve ordering/freshness, exact integrated commit/artifact,
   deployment identity, separate smoke/observability, explicit artifact acceptance
   and deploy/rollback authorization. Missing target stays unconfigured.
5. Document the exact operator-owned workflow contract and a small usable
   integration example, including what execution/containment/readback must be
   supplied and what the shipped code does. Do not ship runnable placeholders
   that emit fabricated successful evidence.

Expected paths: packs/autonomy/repo-template/scripts/quality-orchestrator/
{authority,classify,index,journal,review,review.schema,release,release.schema}.mjs,
at most a few focused new backend/schema/worker modules and corresponding tests;
packs/autonomy/index.md, bin/harness-status.sh if capability wording changes,
docs/harness-capabilities.md, one Agent Note and necessary oracle/evidence here.
Root owns feature_list.json, PROGRESS.md, DECISIONS.md, quality status and Git refs.

Verification: syntax/lint first; focused positive/negative runtime cases then
public API end-to-end contract tests, including crash/reopen and no redispatch.
Use actual local HTTP/protocol fixtures or test-only transport interception;
do not add an injectable production proof/runner. Preserve exact logs, exits,
current test/source hashes once. Real external acceptance is separately reported.

## Task 2 — F24 CI integration, adoption proposal and delivery

Prepare an exact independently reviewable protected-policy adoption packet from
the already implemented judge, with no main write or weakening of checks. Check
whether an ordinary separate base-policy PR can be validated under current main
rules; do not claim that a proposal constitutes adoption. Publish the new backend
code and local evidence to draft PR33, retaining the global-review interruption,
real-host acceptance and protected-base requirements as explicit outstanding gates.

The CI integration selects `.harness/protected-judge/v1` only from the exact
protected base checkout for contract, parser, gates, claim contracts and decisions.
Preserve all workflow steps, pinned dependencies and observed-zero sentinels.
A focused before/after workflow execution test covers the relocated judge and
head-only rejection. A new current static check retains historical receipt
integrity without requiring new code to equal the old unsigned source snapshot.
F19/F23 remain blocked until their static layers are rebound and their existing
runtime/e2e contracts reverified by the harness. This is required integration of
the active F24 work, with no additional feature record. The separate adoption
proposal retains main enforcement and carries the existing k6 telemetry opt-out.

## Preflight interface scan and rulings

| Work | Producer / consumer | Finding |
|---|---|---|
| Task1 journal → review/release | Existing reserve/outcome → private verified observations | Preserve schemas; a new event would strand existing runtime bindings. |
| Task1 budget → execution | Typed signed limits → durable reservation | Use a separate bounded execution subject, not a fictional defect grant. |
| Task1 transport → review/release | Authenticated host observation → strict local validation | Workflow green alone is insufficient. |
| Task1 ↔ Task2 | Local implementation → protected CI adoption | Local passing checks do not adopt protected policy. |
| Task1 internal consistency | Positive integration vs unavailable local containment | Implement inactive configurable code; distinguish external-host integration from real acceptance. |
| Task2 internal consistency | Adoption packet vs permission to merge | Prepare a concrete packet; do not perform the authority transition. |

Ruling: use existing GitHub Actions as the single execution transport and an
operator-enrolled execution issuer. This implements the already approved host
boundary without inventing a service or consumer target. Cost if wrong: the
operator must adapt an existing workflow contract before live acceptance.

Ruling: keep global review INCOMPLETE. A scoped review of newly developed code
does not replace or retry the automatically interrupted assessment. Cost if
wrong: merge remains blocked despite passing new local tests.
