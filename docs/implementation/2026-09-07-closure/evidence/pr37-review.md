# PR37 Human Interruption Reduction — independent static review

## Exact scope and verdict

- Base: `dd8a20c1465b3ccd7e9a4d86ed6a11860146e7f7`.
- Head: `dfd717b934667b1d6153a8934a657a70b8b0c9e1`.
- Object store: `/workspace/scratch/adce1c53b293/harness-kit`.
- Scope: the full effective 35-file increment between those commits, including product.v2 normalization, resource accounting, remediation, run replacement, the release driver, and the shared v1/v2 retained-ack publication change. Unchanged supporting reducers/contracts were read where needed. The mutable closure worktree was not used as source authority.

**Spec verdict: CHANGES REQUIRED. Quality verdict: CHANGES REQUIRED. This exact head is not ready for approval or merge from this review.** Six medium-severity findings follow. No Critical/High finding or signed-total reset was established by this bounded static review. Absence of such a finding is not a general security certification.

This is a completed static review under the newly authorized read-only scope. It does not convert the earlier interrupted review into a completed review, replace its historical status, or claim that active probes ran successfully.

## Findings

All source paths below are relative to `packs/autonomy/repo-template/scripts/quality-orchestrator/` unless otherwise stated. Line numbers refer to the exact head.

### M1 — Check the signed base commit before remediation writes (Medium / P2)

Location: `product.mjs:284-295`; related guards at `product.mjs:58-63` and recovery order at `product.mjs:298-305`.

`describeProductRemediation` and `applyProductRemediation` call `loaded`, which checks current context, approval, expiry and pinned executables, but does not compare the source HEAD to `objective.baseCommit`. Their own preflight checks the journal run ID/OPEN state and the allowed transform, but also omits that commit comparison. `applyRemediation` can consequently reserve a new intent and truncate/write the three approved paths after the source HEAD changes. In the automatic path, `recoverV2` performs remediation first and calls `fresh` only at its end; `fresh` then detects the changed HEAD after the write. The direct apply API can return a successful projection without that check at all.

The grant binds an exact base commit. Representation equivalence does not waive that binding. Validate the unchanged commit and other invariant authority bindings before reserving or writing, while allowing only the expressly permitted representation differences.

Test gap: the new suite checks expired approval and a terminal run, but has no changed-HEAD remediation case asserting unchanged files and zero new spend. This finding follows from source control flow; no such case was executed here.

### M2 — Deleted frozen files evade remediation preflight (Medium / P2)

Location: `product.mjs:288-295`, with the late rejection at `product.mjs:280-281`.

The comparison of unrelated files iterates only `Object.entries(now.files)`. A file removed from the signed/current inventory is absent from that loop, so its deletion is not rejected at description time. If an unrelated frozen file disappears while the approved three remediation paths remain valid, description succeeds and apply charges a remediation intent and writes the three paths. Only the later `REMEDIATION_OBSERVATION` comparison notices that the after-manifest lacks the deleted file, rejects publication, and leaves an unresolved remediation intent.

The contract promises that all other source bytes remain unchanged before correction. Compare the complete path set as well as each retained file's metadata before effects. The existing after-manifest check is useful but occurs too late to provide that precondition.

Test gap: the out-of-scope test asks to remediate a frozen path; it does not remove an unrelated frozen path and then request an otherwise valid correction. Add a pre-effect assertion for that case, including unchanged correction files and counters.

### M3 — A late retained acknowledgement cannot resume an operational checkpoint (Medium / P2)

Location: `product.mjs:333-336` and `product.mjs:347-348`; state change at `product.mjs:271`.

When a pending step has no acknowledgement, resume appends `OPERATIONAL_BLOCK` while retaining the original pending intent. Subsequent `executeV2` calls return immediately for `stage === OPERATIONAL_BLOCKED`, before reaching the branch that reads and publishes the pending acknowledgement. `runV2` likewise returns at that stage. If the original operation later retains its exact acknowledgement but stops before publishing its observation, the normal resume API can never ingest that newly available result. This can occur when one caller checks an in-flight operation before its original worker has finished, followed by interruption between retention and publication.

Keeping the original key and refusing redispatch is correct; treating the diagnostic checkpoint as permanently terminal prevents the promised evidence-only recovery. Allow reconciliation of the original pending key before the terminal operational-stage return, with the existing authority/source/custody checks and no new effect or reservation.

Test gap: the pending-effect negative checks that an absent acknowledgement does not redispatch. A06 covers a missing normalized object after an acknowledgement already exists. Neither covers an acknowledgement arriving after an OPERATIONAL_BLOCK checkpoint and surviving a reopen/resume.

### M4 — Terminal reviewer failures are classified as mechanical without their cause (Medium / P2)

Location: `codex-worker.mjs:75-77`; `product.mjs:225`, `product.mjs:267-271`, and `product.mjs:307-311`.

For every v2 reviewer turn with matching IDs, `status === failed`, any truthy error, unchanged source and clean process exit, the worker discards the error and returns the generic `REVIEW_TRANSPORT_REJECTED` acknowledgement. The controller records it as AUTO_REMEDIABLE and automatically starts another reviewer attempt within the retry allowance. Matching IDs and clean termination establish that the attempt is settled; they do not establish why it failed or that the cause is mechanical. Unknown causes, an authorization refusal, and a safety-related refusal take the same path as a packaging or transport failure.

The scope plan explicitly says unknown causes remain fail-closed operational diagnosis, and the contract says unknown authorization/capability causes remain diagnostic. Preserve bounded error provenance and use a closed, supported classification for retryable mechanical failures. Unknown/refused causes should remain operational checkpoints unless the original authority actually supports their recovery; do not fabricate a Product Owner decision either.

Test gap: A03 emits one synthetic error whose text already calls it an infrastructure-ID rejection. It does not distinguish that case from a terminal unknown or authorization-related error. No real credential detector is exercised, as the contract correctly acknowledges. The finding is about the unconditional classification and retry branch, not a claim that an actual host refusal was bypassed during this review.

### M5 — The release driver selects by operation type instead of the next exact obligation (Medium / P2)

Location: `release.mjs:200-206`.

The driver picks the first unspent supplied wire matching `request.operation` and the common release binding. It does not match slice identity or other obligation-specific fields before selecting. For a release with multiple slices, a valid wire for slice B placed before the valid wire for next slice A matches the initial predicate. The subsequent re-description produces the slice-A request, the equality assertion fails, and the driver stops even though the exact authorized input is present later in the supplied array. A similar mismatch is possible between fresh deployment/readback requests sharing the same operation type.

No incorrect effect is dispatched—the exact comparison prevents that—but ordinary input ordering causes an avoidable interruption. Select the complete next-obligation request, or consider later candidates after a nonmatching description, without accepting weaker signatures or changing the obligation order.

Test gap: both new release fixtures use one slice and supply matching inputs in execution order. Cover at least two slices with the supplied exact wires in the reverse order, plus deployment/readback candidates, while asserting each effect executes once under its original key.

### M6 — A different correction can write while an earlier correction is unresolved (Medium / P2)

Location: `product.mjs:291-295`; expected ownership is checked only later at `product.mjs:280-281`.

`applyRemediation` skips creating an intent whenever `s.remediationPending` is truthy. It does not first require that the pending intent's proof index equals the requested `clean.proofIndex`. With two originally permitted remediation rules and an interruption after the first intent is recorded but before its files change, a direct call for the second rule can pass its description and write the second rule's files under the first rule's unresolved intent. `REMEDIATION_OBSERVATION` then rejects the mismatched proof index, after those writes. The automatic recovery path stops when remediation is pending, but the public apply API reaches this path.

Require an exact pending-intent/proof match before touching any file; otherwise retain the original intent and refuse a second correction. Reusing an already approved rule does not authorize attaching its writes to another unresolved operation.

Test gap: the setup uses a single remediation rule, and no test interrupts one correction then asks the direct API to apply a different approved rule. Verify refusal before second-rule writes or spend and separately verify reconciliation of the original rule.

## Invariants that are supported by the inspected source

- Product.v2 is explicitly selected through `journal.contract` and version-2 inputs. Its event version/runtime binding is distinct. The shared retained-ack publication change also affects v1 and was included in this review.
- The original signed objective is retained in `state.product.wire`. Run rebinding changes `activeRunId` and appends lineage; it does not replace the signed objective, clear counters, renew expiry, or rewrite old events. `BOUND`, `INTENT` and `REMEDIATION_INTENT` enforce the signed `maxSteps` and the journal total cap. No increase/reset of the original total was identified.
- FULL/FOCAL judgment counts are incremented only after durable normalized ingestion in v2. Started resource costs remain charged for malformed/failed attempts. Author fix proposals remain separately bounded. These are product counters, not a silent reinterpretation of the existing continuation category ledger.
- Normalization derives finding/test identifiers from the objective and approved cases, validates source references, retains reviewer severity/description/counterexample meaning, and places the digest outside the normalized payload. `putObject`, NORMALIZED, `getObject` and OBSERVATION enforce the persisted/ledger/ingested digest relationship. This is local content consistency, not independent attestation.
- Normal publication retries acquire custody at most three times, recheck current authority and source under custody, and publish retained evidence without repeating the effect. The code does not remove another owner's lock.
- Critical/High findings and findings with executable counterexamples remain blocking. The unchanged base behavior preserves Medium/Low findings without such counterexamples in the handoff backlog, including across focal omission. Normalization preserves severity. The v2 fixture exercises High findings, not a new explicit Medium/Low normalization-and-backlog matrix; inherited semantics were assessed statically and should not be described as newly demonstrated by those v2 fixtures.
- Semantic-change and baseline-promotion responses derive concrete human-decision answers from the actual grant and reference. A prepared handoff reports no published PR and `merge: NOT_EXECUTED`. Neither local fixture PASS nor the release driver's simulated production trace constitutes owner adoption or real-host acceptance.
- The release driver delegates verification to the existing exact-wire APIs, reuses pending operation keys, and does not create signatures. Its signature checks prevent the mismatched selection in M5 from becoming an incorrect dispatch.

## Evidence and scope checks performed

Read the exact-head AGENTS contract, scope plan, new human-interruption contract and oracle, Agent Note, product contract, historical independent-review record, compatibility failure, controller verification and publication-recovery evidence. Also inspected all eight modified runtime/schema files and the entire new fixture file, with unchanged journal/continuation/release helpers where needed.

Reviewer-authored read-only hash comparisons confirmed:

- All 50 entries of `evidence/verified-sources.json` match exact-head Git objects. Its SHA-256 is `445db95ad6d343796bf04d2bca867c464a536210af8ce697a7f9b7607c6e29a7`, matching the controller receipt.
- All four bindings in the current publication-recovery RED receipt match exact-head objects, including the current test hash `1165badb6a2ddd4e9d9c0cf6c521aa850ac22ebc68e7757270e85b89253726ea`.
- All 13 historical runtime test/helper files and all 25 prior feature records remain byte/content-equivalent to base. F27 remains `blocked`.
- `.github`, AGENTS, DECISIONS and root verifier scripts are unchanged in this increment. This review performed no live protection inspection.

The historical controller record reports final `make check` and startup success, with 25 new cases and explicitly limited fixture evidence. It also preserves the earlier compatibility failure and says its original process interleaving is unknown. The prior independent-review record remains INCOMPLETE / approval NOT_OBTAINED / findings UNKNOWN because the platform interrupted that attempt. These records were read as historical evidence, not as fresh executions or approval.

## Limits and required disposition

This review used exact-commit Git reads/diffs and reviewer-authored static data/hash comparisons only. It ran no candidate code, test, mutation, active probe, installer, network request, credential operation or subagent. It made no repository changes. Only this report was written. No platform rejection occurred during this bounded review.

The six findings are source-level control-flow conclusions; runtime reproduction was intentionally outside authorization for this reviewer. Fixes should be accompanied by focused cases covering the listed gaps through a permitted mechanism, then reviewed at their new exact head. Preserve the original signed total, original pending keys and historical review/verification records. Keep F27 blocked while findings remain. Do not infer authenticated model operation, containment, successful deployment, branch-policy adoption or complete parent-branch approval from this report or the fixture receipts.
