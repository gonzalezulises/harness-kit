# H06 implementer report — FROZEN

H06 worktree implementation is complete against H05 publication
`589a4e3efe924264825c0f3de4b3820d83b196be` (tree
`cdc5681307062bd22d74bd928e200729217111f7`). No index, ref, commit, original
H01–H05 evidence, root feature state, ledger or decisions were changed by this
worker. Root owns independent review, full integration, state and publication.

## Contract and implementation

The smallest extension of the current runtime is two modules, `continuation.mjs`
and `budget.mjs`, plus existing authority/journal/capability integration. No new
dependency, engine, service, dynamic capability registry or signature verifier.

- `humanGateSchema` and `remediationGrantSchema` are closed v1 schemas. A signed
  `bounded-grant` binds exact human-gate AC, canonical representation defect/rule,
  original accepted authority/baseline, complete identity/registry invariant
  digest, durable regression bytes/expectations, scope and explicit budget values.
- `describeContinuation` grants no permission. `evaluateContinuation` checks the
  current accepted/run binding, resolves the exact gate reference and recomputes
  the observed ordinary-record representation defect. It durably records the
  original signed wire and returns an opaque runtime-local handle. H05 preparation
  uses that handle to derive private per-plan permission without another signature.
- Use rechecks grant freshness/revocation, capability/output scope and category /
  total budget. Original H05 manifests, private local-effect provenance, leases
  and postconditions remain required. Effect reservations retain the grant digest.
- Signed positive cases must change representation while preserving canonical and
  semantic identity; signed negative cases must produce HUMAN_REQUIRED. Every
  ordinary source needs both. The accepted original bytes are already durable in
  journal genesis. Missing coverage, identical-byte substitutes, false expected
  results and callbacks block. Product proof/subprocess execution stays unsupported.
- Three categories are exactly `product-semantic-review`,
  `harness-implementation-review`, `mechanical-remediation-verification`, plus
  `total`. No defaults or operational maxima were invented. All values come from
  the signed grant and total must match the operator journal cap. First registration
  fixes category limits objective-wide; prior reservations count as mechanical.
- `spendBudget(kind,objectiveId,operationKey)` reserves one journal attempt using
  the last successfully evaluated continuation. It performs no review/test and
  claims no PASS. Same category/grant/key returns the original event; changed
  inputs block. Run rebinding/reopening/new grant IDs do not reset counts. Generic
  candidate reservations cannot bypass category accounting or forge private tags.
- `revokeContinuation` is a monotonic self-restriction event for an existing grant;
  no new authority is needed to deny future permission. Original approval bytes
  remain intact. Historical signed envelopes are checked at recorded event time
  through the existing verifier; current use independently checks freshness and
  revocation. No recovery authority is reconstructed from a summary.
- Acceptance is separate: the e2e case generates different bytes and demonstrates
  that the original baseline receipt cannot accept them. Old v1 approvals gain no
  continuation. Journal event/runtime bindings explicitly advance; old journals
  are not silently upgraded or retrospectively certified.

Current contracts are in `contracts-continuation-v1.md`; H05/journal contracts and
pack index link it. A governed Agent Note cites AGENTS.md, DECISIONS.md MIGRATION-01
and docs/quality-document.md. Root may update the current quality row to record
H06's 17 focused cases after independent review.

## Exact executed verification

1. Static: `bash docs/implementation/2026-09-05-harness-hardening/h06/verify-static.sh`
   → exit 0, all seven changed runtime/integration modules and focal test syntax.
2. Runtime: `node --test --test-skip-pattern='e2e:' packs/autonomy/repo-template/scripts/quality-orchestrator/tests/continuation.test.mjs`
   → exit 0, 15 / 15. Signed invariants, actual closed regressions, unsupported proof
   refusal, expiry at use, revocation/reopen, immutable categories, shared total,
   idempotent keys, use-time budget exhaustion, foreign handles, changed workspace /
   registry, legacy/generic bypass and actual counterexample coverage.
3. E2E: `node --test --test-name-pattern='^e2e:' packs/autonomy/repo-template/scripts/quality-orchestrator/tests/continuation.test.mjs`
   → exit 0, 2 / 2. Actual signed and leased local writes over two mechanically
   rebound runs with one grant; artifact acceptance rejection; exhausted retry and
   reopened postcondition reconciliation retaining one spend and grant provenance.
4. Causal RED: `bash docs/implementation/2026-09-05-harness-hardening/h06/reproduce-red.sh`
   → observed exit 1, 2 assertion failures on the preserved initial H06 source.
   High regression-coverage defect: identical accepted bytes falsely counted as
   evidence of representation change. The unchanged test observed
   CONTINUATION_DESCRIBED instead of POLICY. A second availability defect blocked
   exhausted effect retry as stale; it now reconciles without spending again.
   Exact source/current-test bytes and both original/reproduction logs are retained
   once under `h06/`; no artificial mutation or missing-API failure is used as the
   security receipt. The initial missing-API run remains development evidence only.

AC-H06 was written before implementation and now binds the witnessed current-test
receipt. All 14 final source-manifest entries and 23 evidence-manifest entries were
checked by SHA256; preserved snapshot test equals current focal test byte-for-byte.
No full/startup suite was repeated; root owns the broad gate.

## SHA256 bindings

| Artifact | SHA256 |
| --- | --- |
| Current focal test | `73748aef967814045b3961f3eae2e00675eca0f50d1530257a2418b520a14bf3` |
| source-manifest.json | `1dba863f2ebc0efad675b88ef9c2e0f20635cab65c232890cd2b19d3d63202b8` |
| evidence-manifest.json | `3fb9e1aeccf3b3d94a99f3c50dcb4be6058c1a40e8b3adf300bef2d94864d8c9` |
| red-receipt.json | `996d05203289b251229bcd99ad7802b140144fc71720357a82d4e0bd03cefa09` |
| causal-red.log | `c55a0f04bbe0a6759cd843bed37d01b9e8b89b008bc5ea3a28daaaeddd6b46af` |
| final-static.log | `4f380a754e7609c12c33e22211f0cac7bd19f68f1b7f35158debaf961f037883` |
| final-runtime.log | `a1bd6ab140ad486c926671f490e3646f0ec62e16f13365fc22c3bc463d531f0b` |
| final-e2e.log | `5947686c1560165244a5e3077b5caf070d32bb39eee9f518b7c54177969711b1` |

## Honest limits and concerns

No known remaining High/Critical H06 issue. Independent review is still required.
Tests certify fixture contract handling, not real issuer custody, externally
witnessed current history, malicious same-UID containment, product behavior,
independent model review or deployment. Those unavailable capabilities remain
BLOCKED_BY_REQUIRED_CAPABILITY / NOT_EXECUTED. Standalone budget reservations are
attempt accounting, never evidence that review or regression execution occurred.
The operator must retain the objective's trusted journal; replacing trusted state
or host configuration is outside the candidate-input boundary. No new journal
recovery, grant restoration, baseline acceptance, account/auth/network action or
deployment was performed. Interrupted local effects use H05 actual postcondition
reconciliation and may still require operator investigation; no rollback or
multi-file atomicity is promised. This intentionally narrow continuation supports
closed record/digest effects, not arbitrary code remediation or proof equivalence.

FROZEN. No additional edits after this handoff until a concrete fix dispatch.
