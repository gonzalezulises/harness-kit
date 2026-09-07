# GR01 / GR02 / GR04 corrections — independent static review

## Scope and verdicts

PR33 correction source: `/workspace/scratch/adce1c53b293/harness-judge-target`, exact parent `0a51623b5db42951a6091847a179262182abd67d`, plus the five production-file changes identified by the hashes below. These worktree hashes, not an inferred new commit, define the reviewed candidate.

Primary integration: **only** `/workspace/scratch/adce1c53b293/harness-human-interruption/packs/autonomy/repo-template/scripts/quality-orchestrator/journal.mjs`, SHA-256 `b736a6ae3163c85387cbc7c32648c1e33449218b9d54e8ef8567758d64f4e26a`, compared against the exact product.v2 journal at `dfd717b934667b1d6153a8934a657a70b8b0c9e1` and against the corrected PR33 journal. Other changing primary files were outside this review.

- **PR33 spec/quality verdict: CHANGES REQUIRED.** GR01 and GR04 are statically addressed. GR02 adds the needed check after preflight but leaves the request-binding defect H1 below.
- **Primary journal integration verdict: STATIC PASS.** The lock/receipt adaptation is consistent with both source contracts. This does not approve the rest of the primary integration or claim its running regression has passed.
- No additional Medium or Low defect was identified within these five corrections and the journal-only adaptation. This statement does not close any earlier Medium/Low finding elsewhere.
- GR03 and GR05 remain explicitly OPEN and outside these code corrections. This is not whole-branch approval, policy adoption, real-host acceptance or permission to merge.

## H1 — Bind the final owner check to the captured dispatch request (High / P1)

Locations, relative to the PR33 runtime directory:

- `release.mjs:202-205`, where `validateStart` closes over the caller's `wire`.
- `execution.mjs:22-27`, where the execution request/budget and descriptor are captured before the asynchronous preflight.
- `execution.mjs:34-42`, where the callback checks the caller object and the previously captured descriptor is reserved/dispatched.

The new final validation reads `wire.request` again after an await. That is the caller's outer wire object, while `execution.execute` has already parsed/captured the request and descriptor used for dispatch. The outer wire is not frozen or captured as one immutable value at entry. Replacing its `request` property during the preflight does not replace the earlier descriptor.

A concrete source-level causal scenario is an ordinary authorization refresh during preflight. A deployment request containing action approval A is described and passed to execution. A expires while execution awaits the read-only preflight; the separate execution-budget approval remains current. The caller obtains current action approval B, describes the same deployment with B, and replaces the outer `wire.request` with that newly described request. The final callback looks up the B-bearing request in `prepared` and validates it through current `requestFor` checks. The captured descriptor and its signed execution budget still bind the earlier A-bearing request. The journal's backend validation checks that descriptor's budget/request bindings and total limits; it does not independently enforce deployment-action approval. Thus validation of B can be followed by reservation/dispatch of the descriptor containing expired A. This scenario requires no altered signature or approval bypass; the defect is that the refreshed authorization and the actual dispatched descriptor are different inputs.

This is not a signature forgery or a duplicate-dispatch issue. It is a mismatch between the object whose current operation authority is checked and the object actually reserved for execution. The new check must validate the exact captured descriptor request. For example, establish one immutable wire/request snapshot at the closed API boundary and use it for both execution and final validation, or pass the captured request into the internal closed validator and require exact equality to the freshly reconstructed obligation. Keep this private to the owning release/review boundary; do not introduce a caller-selected validator.

Test gap: the eight new expiry cases advance the clock while leaving the caller wire untouched. They demonstrate that the intended final check runs, but do not cover replacement/mutation of the caller wire during asynchronous preflight. Add a focused case for that input change, requiring no reservation or dispatch of the old request, plus an unchanged-wire control. The same immutable-input discipline should be used consistently for release, standalone review and catalog entrypoints, even though the concrete expired-action case above is in release.

This finding is derived from source flow only. No candidate program or probe was run by this reviewer, and no host refusal or real effect was exercised.

## What the corrections establish statically

### GR01: single durable creator owns dispatch

PR33 `journal.mjs:167-184` examines the operation key while holding the existing filesystem lock. Exact idempotent retrieval returns `created:false`; only a new validated durable append returns `created:true`. A mismatched key/request still fails. `execution.mjs:40-42` dispatches only for the creator. Losing identical callers retain the existing operation identity and report local execution as NOT_EXECUTED. Existing early reconciliation paths do not issue another POST. An owner interrupted after reservation leaves the original charged intent for observation-based reconciliation.

The public append API unwraps the original frozen APPENDED receipt, so creator ownership is private metadata rather than a stored schema or public receipt change. Budget reducers, total limits and existing pending-key semantics remain unchanged.

### GR02: current operation checks moved after asynchronous preflight

The new callback executes under journal ownership immediately before a fresh reservation. It rechecks runtime and execution-budget authority. Release reconstructs current objective/action/prerequisite requirements through `owned` and `requestFor`; standalone review reconstructs the approved policy, authenticated catalog and exact shadow; catalog validates its own closed request and pins. All three execution callers supply the private check. The source does not expose it as a new public runtime argument or host capability.

These changes cover the ordinary unchanged-wire expiry path. H1 prevents closing GR02 completely. Independently, a local reservation-time check cannot prove authority at the eventual remote operation: the external supervisor must independently revalidate the applicable objective/action/prerequisite authority immediately before performing that operation. The correction report correctly assigns the contract updates to root and does not claim live supervisor proof.

### GR04: literal output membership is preserved

`capabilities.mjs:58-61` uses a null-prototype output dictionary and checks the exact closed output-key set before creating a permit. Literal names such as `__proto__` are now own entries in both canonical and derived batches. The prior null-prototype inventory is unchanged. Output scope, equivalence, before/after manifests, execution mode, frozen-file checks, delta and postconditions remain in force; no assertion or budget check was weakened.

## Primary journal adaptation

The primary candidate preserves the exact prior product.v2 decoder selection, event versions, runtime-binding definitions, public receipt construction and product reducer call sites. Its change from the prior product.v2 journal is limited to the append helper result split and the private execution-claim entrypoint.

The examined call paths are:

| Caller | Lock acquisition | Result |
|---|---|---|
| Public/internal ordinary `append` | `exclusive`, then `appendOwned` | Original APPENDED receipt |
| `productCustody` | Existing `exclusive`, then caller uses `appendOwned` | Original APPENDED receipt |
| Private `claimExecution` | `exclusive`, then `appendClaimOwned` | Private created flag plus original receipt |
| `appendClaimOwned` | None of its own | Validates/reuses/appends under caller custody |

`appendOwned` only unwraps `.receipt`; it does not lock. `appendClaimOwned` does not lock. Thus the existing product custody path does not acquire a nested lock, while ordinary append and execution claims each acquire exactly one lock. The private claim still requires a backend-owned reserve and a function supplied by the closed owner. Creator detection, current validation ordering, durable publication and idempotency match the PR33 correction. No stored schema, historical event meaning, public return shape or signed-budget reset was introduced by this adaptation.

The integrated regression was reported as running at assignment time. Root subsequently reported the integrated global suite passed 12/12. That is supplied execution evidence, not a test run or independently verified execution by this reviewer; the journal verdict remains static.

## Source and evidence hashes

All paths in the following source table are under `packs/autonomy/repo-template/scripts/quality-orchestrator/` in the PR33 correction worktree.

| File | Examined SHA-256 |
|---|---|
| `journal.mjs` | `af720c59d2afc6bcfd3dd78752729b99b9a532aa4fa539c88541c9373076614b` |
| `execution.mjs` | `0b4d4089e64172f722c10a807b67c255c934534179ae6e03c32321ca6af8b3cf` |
| `release.mjs` | `769c9f37d6d0dba9cda61e8094bd062eb2426c4e58ef5b82926c18e974c13ad8` |
| `review.mjs` | `f284c9ab006fd0cde18bbd541e724922135dad75cef36d89e8bb06ee21663389` |
| `capabilities.mjs` | `a34077e46a1e38e65e3dda989d26d14e8822c14b3a1a388ebfad141ab7b44aa7` |

Current source manifest: `9655863a24b77026c228397161cc581cb2d530cf04a5362f2793e4141da31342`; all five entries match the examined bytes.

Exact prior product.v2 journal at `dfd717b934667b1d6153a8934a657a70b8b0c9e1`: `592c089b7bd6aa7f35301898f51047d471f08858e87a1b7f9369d706b6972af0`.

| Evidence under `docs/implementation/2026-09-07-closure/global-corrections/` | SHA-256 | Checked content bindings |
|---|---|---:|
| `red-receipt.json` | `bc353e1958319e4cdee0a114b1846004886410fbeb21def00dad7145db32d8b7` | 23 |
| `green-receipt.json` | `f9ea4a989289e6e63f2ae2f010c8b699f4ef39243ae37b8f41a7990c853b5177` | 9 |
| `legacy-green-receipt.json` | `277bff02c7e2ea68be7cce4ff4ccad9bdc4e4dcc584729ee909cc38195e12c55` | 11 |
| `literal-frozen-green-receipt.json` | `72b9d58159a5f0b7cb39d4418e1809aaaa7c870f3a32112e4b363ae7ab4b1da9` | 7 |

All 50 receipt test/source/log bindings match their local bytes. The new RED and GREEN receipts bind identical test/helper/worker hashes:

| File under runtime `tests/` | SHA-256 |
|---|---|
| `closure-global-corrections.test.mjs` | `301c899443855c51581fcfa54f29f012fe6e4b36bd64882d2e60eccf0de75dc9` |
| `closure-fixtures.mjs` | `073d1269683de1f1108331ddc3970537e458e98b4a26b0cdb9ddd3d7f28d063a` |
| `closure-process-worker.mjs` | `b2a6ec1547061d3a5c34e5dbde2e1c8350b06e60ea037bfd3e54a51f8b1f2691` |

Oracle `.harness/oracles/AC-closure-supervisor.yaml`: `a4cb055db4891358e0d2f8de8f1e629350350a877b16cd249efb6f37c3773c2c`.

## Evidence limits and disposition

The supplied report and retained receipts record new 12/12, affected legacy 150/150, original literal-filename 2/2 and syntax 5/5 success. I read their source/evidence linkage; I did not independently execute those commands. Test source shows a real two-controller rendezvous around descriptor publication, a process interruption after reservation, eight clock-expiry cases, and exact literal-output byte/scope assertions. These are relevant local engineering cases, not authenticated live execution or deployment evidence.

This review used file/Git reads and reviewer-authored hash comparisons only. No candidate execution, test, probe, network request, credential operation, source mutation or subagent occurred. Only this report was written. No automatic platform rejection occurred during the task.

Address H1 and review its frozen changed bytes before closing GR02. Preserve the tested creator/receipt separation and journal integration. GR03/GR05, the root-owned supervisor contract updates, full integration verification and any live acceptance remain separate outstanding work.
