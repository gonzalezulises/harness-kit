# F27-R1 late reviewer failure recovery — independent static re-review

Date: 2026-09-07. Scope: only the correction to F27-R1 in `/workspace/scratch/adce1c53b293/harness-human-interruption`, following `f27-fixes-review.md`. HEAD remains `dfd717b934667b1d6153a8934a657a70b8b0c9e1`; the verdict applies to the exact uncommitted source hashes below. The comparison base is the preserved first-correction 19-module snapshot under `docs/implementation/2026-09-07-closure/f27-corrections/late-failure/first-correction-source/`, manifest `992b9bc3b19a65f19b05adea44b021d4c70deaf853ecc9ed4ffe624df86d32ac`.

**Spec verdict: PASS for the scoped production correction. Quality verdict: PASS for the scoped production correction.** F27-R1 is addressed; no new Critical, High, Medium or Low production finding was established. In conjunction with the prior review, this closes the remaining local M3/M4 recovery intersection without changing the accepted M1/M2/M5/M6 conclusions. Repository-wide verification, final oracle metadata and parent-branch approval remain separate.

## Source assessment

All short source paths below are relative to `packs/autonomy/repo-template/scripts/quality-orchestrator/`.

`product.schema.mjs:41` adds a strict `REVIEW_CHECKPOINT_RECOVERY` payload with explicit version 1, original key and acknowledgement digest. The existing settled-failure payload and historical TOOL_FAILURE payload retain their schemas. Only `product.mjs` and `product.schema.mjs` differ from the preserved first-correction module snapshot; the other 17 modules match exactly.

`product.mjs:269-277` limits recovery to stage OPERATIONAL_BLOCKED with the precise original `UNCERTAIN_EFFECT_REQUIRES_ORIGINAL_OBSERVATION` cause, a still-pending REVIEW/FOCAL intent, and an acknowledgement with the same kind and binding. A settled failure must pass the existing original-source/binding validation and carry one of the two explicitly supported transient codes without a misalignment indication. An unqualified/unknown/refused result supplies no recovery authority. A completed raw review is eligible only when normalization fails, matching the existing bounded malformed-output handling; a successfully normalizable review uses its ordinary observation path.

Before recovery, prospective retry count must be at most the signed tooling retry allowance, and prospective fingerprint count must remain strictly below the signed no-progress threshold. These comparisons match the subsequent unchanged failure reducers: retries exceeding the allowance or fingerprints reaching the threshold block. The original signed starts and journal total must both have remaining capacity. Recovery does not reset or raise any limit, refund the original attempt, create a new grant, or consume a judgment.

The reducer at `product.mjs:283-288` independently rechecks original pending key, exact retained acknowledgement digest and the full eligibility predicate. It then restores INDEPENDENT_REVIEW for a REVIEW intent or FOCAL for a FOCAL intent. The stage comes from the owned intent; it is not caller-selected. The original pending intent remains intact. The current authority/source/OPEN-run checks already run under product custody before publication, and the event transition retains recorded signed-grant validation.

Publication at `product.mjs:354-364` appends that recovery event under the existing custody lock before completing the original acknowledgement. `TOOL_FAILURE` and `SETTLED_REVIEW_FAILURE` reducer blocks are byte-identical to the first correction. Consequently old events keep their replay meanings; a newly completed malformed output receives the explicit recovery context before the unchanged failure event is published. Historical events are neither rewritten nor reinterpreted.

An interruption after the recovery event but before failure publication leaves the original key pending in the restored stage. Reopen can publish the same retained acknowledgement without another recovery event or effect. After settlement, the new pending-resume branch (`product.mjs:367-370`) returns the projection immediately instead of recursively starting the next operation. A later ordinary driver iteration uses the existing logical retry key and charges the new attempt through the unchanged INTENT checks. A run call may take that next iteration within its own bound; evidence-only settlement itself adds no effect or spend.

Unknown/refused outcomes remain operational diagnoses. Exhausted retry/no-progress/total conditions receive no recovery event and remain blocked after settlement. There is no generalized permission to reopen arbitrary operational checkpoints. Missing acknowledgements retain the original pending key without redispatch.

## Regression and evidence assessment

The two new test files cover five process-reopen cases: late serverOverloaded via resume, late internalServerError via run, late completed malformed output, late cyberPolicy refusal and zero retry allowance. Tests hide and restore the actual retained original acknowledgement, checkpoint while it is absent, and reopen the controller in a separate process. They verify evidence-only settlement, original canonical signed wire equality, an unchanged historical event prefix, unchanged original charge and zero judgment at settlement. Positive cases then require one additional charged reviewer attempt under `review:full:tool:1`; refusal and exhaustion controls require no further attempt or spend.

Current identical test/helper bytes record RED with three causal blocked-stage assertion failures and two passing controls, then GREEN 5/5. Final affected evidence records 9/9 for successful late-ack recovery, A03 diagnosis, durable A06 ingest, absent acknowledgement, v1/v2 publication contention, persistent custody and stale authority after contention. This addresses the diagnosed intersection without claiming a final full-suite run.

All 54 direct late-failure receipt bindings match their local files: 23 RED, 26 GREEN and five current-oracle RED bindings. For RED, source keys resolve to the explicitly preserved first-correction snapshot, not current source. Both 19-module manifests match their respective bytes. The live source hashes match the assigned exact target.

The first-correction RED, 19-case GREEN and A06 receipt files retain the exact hashes recorded in the previous review. The completed first-correction legacy receipt records 104/104 and its 24 test/source/log bindings match; source references resolve to the preserved first-correction snapshot. That result is correctly attributed to earlier source. It is not passed off as final-source full-suite verification.

The final A06 falsification uses the unchanged current human-interruption test, a hook that checks the final product source hash, and the same two durable-read substitutions. Its preserved source/hook/patch/log hashes match the receipt. The log records the expected false PRODUCT_REPLAYED admission assertion, exit 1. Initial representation/setup failures remain separately retained and excluded from current causal proof. These are content-consistent supplied execution records, not independently authenticated executions by this reviewer.

## Exact examined hashes

| Source or test | SHA-256 |
|---|---|
| `product.mjs` | `acc0e4c8402dde24e9c7d88cf168be7744c0b9a4ccc435ef1282bb087ac0b51a` |
| `product.schema.mjs` | `89ae1728629ef5f24a60ff553180d63fdc45a47951aabc9fe5d1d5a8557eebe2` |
| `tests/f27-late-review-failure.test.mjs` | `68dbdd85aeb992fd08d521bc5dc73d03b5195302aa037ee940f8bcb674d358b3` |
| `tests/f27-late-malformed-review.test.mjs` | `9692bfe9bcad84b72285acdb5493be9b441bcecc74052d8d202dbd5228a1b78b` |
| `tests/f27-corrections-fixture.mjs` | `c67d830dda497b47ae54bad1fd2dca70a070b324e551cb22e72834fc6e784aa9` |

| Evidence under `f27-corrections/late-failure/` | SHA-256 |
|---|---|
| `final-source-manifest.json` | `2b0f1b3535f09f19e8df64cb85c9027c820b6054e18586f93ef120b095e08e96` |
| `red-receipt.json` | `8a2dd38fee83fa8cbe246c101f0a2875ca133ec56e9474f7eb67bbabfeda91f6` |
| `green-receipt.json` | `e8e26bf65a1a07c4c2fd5524c7549d07b223b4d63f83b7c62f69c2978e80cc27` |
| `current-oracle-red-receipt.json` | `3a85f18f12f38e3d38ac13672ac116af8d3c41fa406973f946bcf42f8ab39a6a` |

The parent-directory `first-correction-legacy-receipt.json` hash is `5679be5c5d3a272b68801c29ec9d3a43f00cb856e6c3ef5f1b5b90525d9e30a9`.

## Limits and final metadata follow-through

The new process-reopen cases exercise FULL review. FOCAL stage recovery, interruption between the two event appends, exhausted fingerprint/total boundaries and unsupported/misalignment combinations were assessed statically; they are not separately demonstrated by these five tests. The explicit refusal and zero-retry controls provide useful negative coverage. No no-progress, total-budget or historical-event bypass was found in the inspected control flow.

At the last metadata read, `.harness/oracles/AC-HUMAN-INTERRUPTION.yaml:34` still pointed to the first-correction A06 receipt. Root was notified to change the live pointer to `docs/implementation/2026-09-07-closure/f27-corrections/late-failure/current-oracle-red-receipt.json` before final verification. The final receipt itself is ready and hash-consistent. This is an explicitly root-owned pending metadata step, not a claim that the earlier source receipt covers the final module bytes.

This static re-review ran no candidate code, tests, probes, network request, credential operation, source mutation or subagent. Only this report was written. No automatic platform rejection occurred. No live model authentication, containment, real deployment, supervisor acceptance, policy adoption or complete repository verification is claimed. The examined F27-R1 production correction is ready for the parent's ordinary integration and required checks.
