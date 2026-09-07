# H1 immutable dispatch binding follow-up: independent static review

Date: 2026-09-07. Scope: the H1 follow-up to GR02 in `/workspace/scratch/adce1c53b293/harness-judge-target`. The worktree HEAD remains `0a51623b5db42951a6091847a179262182abd67d`; this verdict applies to the uncommitted production bytes identified below, not to that commit alone. The immediate comparison base is the preserved first GR01/GR02/GR04 correction state in `docs/implementation/2026-09-07-closure/request-binding/red-source/`, as examined in `global-fixes-review.md`. It is not the original PR33 commit.

**Spec verdict: PASS within the local reservation/dispatch boundary.** H1 is addressed and no additional local GR02 gap was found in this focused follow-up.

**Quality verdict: PASS for the examined follow-up.** No new Critical, High, Medium or Low findings. The four snapshot additions preserve existing ownership, budget and reconciliation control flow. This is a static review disposition, not a complete repository verification or live acceptance verdict.

## Source-level assessment

All source references below are relative to `packs/autonomy/repo-template/scripts/quality-orchestrator/`.

| Entry point | Snapshot location | Final validation binding |
|---|---|---|
| Release `executeReleaseObligation` | `release.mjs:201` | The callback at line 204 closes over the local cloned wire, looks up that exact request digest, and compares it to the currently reconstructed obligation under the original handle. |
| Catalog `executeReviewCatalog` | `review.mjs:65` | The callback closes over the local cloned wire and checks the current closed catalog request and pins. |
| Standalone `reviewRun` | `review.mjs:95` | The callback closes over the local cloned wire and checks the current owned policy, catalog, exact shadow and signed operation/budget scope. |
| Private `execution.execute` | `execution.mjs:23` | The descriptor and execution-budget approval are derived from a second private snapshot of the same captured input. |

Each site uses `freeze(structuredClone(wire))` before its first asynchronous yield. `executionAsync` invokes its callback immediately; it does not defer snapshot creation. `identity.mjs:7-9` recursively freezes object values. For the schema-supported plain data wire, caller-owned nested request, budget and approval objects are detached as well as frozen. Public validation and private descriptor construction therefore consume equivalent captured data; they do not retain the caller's replaceable outer request reference. No public callback or authority override was added.

The original causal defect is closed. If action approval A expires while the original execution awaits preflight, replacing the caller wire with a newly described request bearing approval B cannot change the captured request or its prepared lookup. The callback must reconstruct and validate A's original request at current time, so expired A cannot borrow B's validity. Likewise, if a prerequisite expires and the currently required operation changes from merge to slice, replacement of the caller wire with a fresh slice request cannot authorize the captured merge descriptor. A current replacement requires its own separate valid execution invocation.

The private backend still checks the captured execution-budget approval after preflight and again within the journal claim callback (`execution.mjs:35,41`). Closed operation validation remains inside claim ownership before a fresh reservation. Only the durable creator reaches `transport.dispatch` (`execution.mjs:42-43`). Existing intents still require matching descriptor digests and original-key reconciliation; this follow-up introduces no extra reservation, budget reset, new grant or duplicate dispatch path.

Comparing all 19 preserved RED source files with the current runtime found differences only in `execution.mjs`, `release.mjs` and `review.mjs`: exactly one snapshot addition in each of the first two files and two in the third. The other 16 files match byte-for-byte, including the previously reviewed journal creator/receipt implementation and literal-output correction. No schema or public receipt change is part of this follow-up.

## Regression and receipt integrity

The new test at `tests/closure-request-binding.test.mjs:5-21` expires a previously accepted slice observation inside the real awaited fixture preflight, describes the newly required slice, and replaces the original caller wire's request. It requires rejection of the captured obsolete merge before any additional dispatch, spend or pending intent. It also confirms the expected current obligation. The unchanged-current-input control at lines 23-29 requires exactly one dispatch and reservation, the expected pending key, and the exact described request in the descriptor.

The retained RED log records this causal test failing because the old implementation returned EXECUTION_PENDING, with the unchanged-input control passing. The GREEN log records both tests passing. RED and GREEN bind identical test and helper bytes; the helper also matches the earlier correction review. Thus the evidence distinguishes the diagnosed failure from a blanket execution refusal. These are supplied execution records checked for content consistency; this reviewer did not rerun them or independently authenticate their execution.

All 28 referenced local content bindings match: 22 in the RED receipt (two tests/helpers, 19 preserved source files, one log) and six in the GREEN receipt (two tests/helpers, three changed source files, one log). The 16 unchanged runtime files bridge the narrower GREEN source list to the preserved RED runtime snapshot. The five first-correction production hashes in RED match the previously examined correction state. `verification.json` accurately labels that preserved state and confines its claim to local fixtures.

| Examined current source | SHA-256 |
|---|---|
| `execution.mjs` | `2c11cde8830a16dfdd056e5c4f755bf9de944f1459e8fc21b7af3bcf03ecefdc` |
| `release.mjs` | `1aea5226e9f5d95c5e15284d67fbf4087541126efe7e9fff2b4d3b3cc122013d` |
| `review.mjs` | `984ba2cc87373df71958ade81bc738b55fca4b6aba4f721c061c961e0964a68d` |

| Evidence | SHA-256 |
|---|---|
| `closure-request-binding.test.mjs` | `f178077389f4da8a8694d9178c015481bec95b598b9babe62b87f1ca6d662f36` |
| `closure-fixtures.mjs` | `073d1269683de1f1108331ddc3970537e458e98b4a26b0cdb9ddd3d7f28d063a` |
| `request-binding/red-receipt.json` | `f435296b5671f602618a239a930c7959881468a7a8f6640ef7605e4cdc857b08` |
| `request-binding/green-receipt.json` | `831179b395b49551cf498d3fd4a853dad05b27da8b74496588e8eb6bb9a12ef5` |
| `request-binding/red.log` | `21fae64eba443a57df7110e82eba04ed26217fb95f0edaf9ca241c89a0347152` |
| `request-binding/green.log` | `5023a5bf2e3f1578deea6eb8d1f286576ae9b63477f4cb70d4cbc29186db0c98` |
| `request-binding/verification.json` at inspection | `ebd6d2e0b584958a749d50c3e876efe95b29a015e4dd486eb5a7498b1a5c074e` |

Evidence paths beginning `request-binding/` are under `docs/implementation/2026-09-07-closure/`. Documentation may subsequently update its review status; production hashes above define this review's exact target.

## Remaining limits and disposition

The new regression exercises release prerequisite/request substitution. It does not separately execute action-approval substitution, catalog mutation, standalone-review mutation or arbitrary nested mutations; those cases were assessed through the consistent snapshot and closed-validation control flow. No candidate programs, tests, probes, network calls, credentials, repository mutations or subagents were used. Only this report was written. No automatic platform rejection occurred.

This report closes H1 for the examined local implementation and completes the local GR02 correction review when read with the prior current-authority checks. It does not establish independent test-run authentication, real supervisor refusal, authority freshness at the eventual remote effect, repository-wide checks, integration into a different worktree, or live supervisor acceptance. GR03/GR05 and unrelated prior findings are outside this follow-up; their disposition is unchanged. The reviewed H1 follow-up is ready for the parent's ordinary integration and verification process, without bypassing required checks.
