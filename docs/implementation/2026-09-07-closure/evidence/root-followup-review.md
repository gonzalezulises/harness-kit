# Independent root follow-up review

Date: 2026-09-07. Reviewer scope: the primary worktree `/workspace/scratch/adce1c53b293/harness-human-interruption`, product M1/M3 acceptance follow-up and the `bin/harness-consumer.py` integration diff from `43e32833945a1fbb0cdd9dca2d582a428209d4fc`. No other global corrections are covered.

| Scope | Spec verdict | Quality verdict | Open findings |
|---|---|---|---|
| Product M1/M3 acceptance follow-up | APPROVED | APPROVED | 0 |
| Distribution inventory integration fix | APPROVED within existing profile and migration limits | APPROVED | 0 |

Finding counts for this follow-up: 0 Critical, 0 High, 0 Medium, 0 Low. Prior product evidence findings PF-E1 and PF-E2 are resolved by the new evidence and explicit historical erratum. Broader GR01–GR05 findings are not closed by this report.

## Product acceptance follow-up

The production `product.mjs` hash is unchanged from the previous scoped review. Only the new tests/helper have been strengthened.

The linked-worktree test now snapshots source index bytes, refs including HEAD, and frozen file bytes/tree entry before the full product run. It checks HANDOFF_PREPARED, reads the changed product from the actual private commit, resolves its actual parent to the authorized base, compares the frozen mode/blob tree entry, and checks source bytes/index/refs/HEAD afterward. These assertions cover the previously missing linked-worktree invariants through the public runtime.

The malformed verifier fixture appends an observable `call` record before emitting invalid bytes. Its test obtains the structured BLOCKED_TOOL_FAILURE result, then really calls `resumeProductStep`. It requires INCOMPLETE, exactly one invocation in total, unchanged journal spend, and identical pending state. This observes the existing conservative no-redispatch behavior rather than treating replay as resume. A passing Node test process also supplies evidence that the decoder failure did not become an uncaught exception.

The retained pre-fix runtime and new tests have causal RED receipts: the linked case fails on the old `.git/worktrees/source/objects` lookup; the malformed case fails with uncaught ERR_ENCODING_INVALID_ENCODED_DATA. The current-source GREEN log reports 2 passed, 0 failed, 0 skipped. The first-round tests remain under `product-corrections/first-round-tests`; all three hashes match the bytes reviewed previously. The verification record explicitly corrects the omitted `6c` in the historical UTF-8 test hash without silently replacing the historical record.

## Distribution integration correction

The complete diff adds `production_runtime_path` and uses it both when selecting Git source blobs and when validating manifest generation entries. REQUIRED_RUNTIME is byte-for-byte unchanged and remains a mandatory minimum at bundle construction and validation.

The added admission rule permits bounded filename forms for top-level `.mjs` modules and `contracts-*.md`. Slash-containing paths do not match those extensions; existing enumerated nested schemas remain admitted through REQUIRED_RUNTIME. The test subtree is excluded, as are top-level module names ending `.test.mjs` or `.fixture.mjs`. The rule is a filename/layout convention, not a semantic determination that arbitrary source text is production code. Future nested production modules or other resource types will still need explicit support.

This includes `product.schema.mjs` and the other current top-level production modules imported by the integrated runtime. The old fixed list omitted product.schema.mjs: the retained full-check log shows exactly that missing-module error in the existing fresh-clone E2E, with one failure among 33 distribution tests. The unchanged test now passes in the supplied 33/33 GREEN run. That E2E creates and commits a consumer installation, clones it, makes source and bundle directories unavailable, and invokes the installed bootstrap with vendored dependencies. The result is fixture identification, not enrolled real-host acceptance.

No loss of the existing restrictions is visible in this diff:

- Bundle bytes still come from exact resolved Git commit objects, with per-file content/mode hashes and a digest over the manifest inventory. Source identity remains explicitly DECLARED_NOT_REMOTE_VERIFIED; local integrity is not promoted to external source authentication.
- Manifest validation still requires the exact profile, schema, complete stable inventory, required minimum runtime/dependencies, normalized allowed inventory locations, declared source paths, and exact payload contents. The new source modules must appear explicitly in the bundle and approved plan.
- Target suitability, protected consumer-state snapshots, private generation placement, stable-file collision checks, managed drift/link checks, exact plan approval and live target/bundle revalidation remain unchanged. The admission rule does not grant overwrite rights to consumer product files or preserved authority/journal paths.
- Adoption stays NOT_ADOPTED; explicit external expectation checks remain distinct from local integrity. No authority or readiness promotion was added.

**Compatibility limit:** the manager itself is stable payload. This correction changes its SHA256, so an installation made with the previous stable manager cannot use the existing ordinary upgrade/rollback flow to transition across those differing stable signatures. Planning and live validation still reject that case as MIGRATION_REQUIRED; an old validator may also reject the expanded inventory before that point. No automatic manager migration was added. Fresh installs and runtime transitions whose stable payload signatures match are the supported cases evidenced here. The unchanged suite explicitly tests rejection of changed stable manager bytes; its 33/33 result must not be presented as an old-manager-to-new-manager migration demonstration.

## Exact reviewed bytes

All paths are relative to the primary worktree stated above.

| Source or test | SHA256 |
|---|---|
| packs/autonomy/repo-template/scripts/quality-orchestrator/product.mjs | `3a6497d7f81e9a10a53d5b20108ab190e2aa04de55f43cd5e7db9c3f9115ad2a` |
| packs/autonomy/repo-template/scripts/quality-orchestrator/tests/product-corrections-fixture.mjs | `e57fa5d6b9b8d24148c9a0df83247ba89fcd819d96521a2a1aa118a65de0ce41` |
| packs/autonomy/repo-template/scripts/quality-orchestrator/tests/product-linked-worktree.test.mjs | `b254805a85b53076553f77cc115228f70e71a21faa46ba3955b83506ed805682` |
| packs/autonomy/repo-template/scripts/quality-orchestrator/tests/product-verifier-utf8.test.mjs | `b700c75b47c465222ae8c30f6e99ef6db7d5baf2a158dcf7f8a963e03677571b` |
| bin/harness-consumer.py | `c204ad219c3137157e8edf7721392cb2554c1bc17edd1623f42dbfb96089264c` |
| tests/consumer-distribution.test.py | `3651818b4be511ac88f8c96aead84c962d8e3ff714004393d109613a5199c76a` |

Retained pre-fix product SHA256: `4e7213881c760a7283db74d1d8126efd4308b0fb0ef2ca50ffd4b9a67e8f8a9d`.

Baseline and retained defective manager SHA256: `35d4e2ca41c3a3585ee4edb13def46596a6336dc1d61451ffd5363ae16c56b73`. The distribution test is byte-identical to commit `43e32833945a1fbb0cdd9dca2d582a428209d4fc`.

## Evidence verification and coverage limits

Independently compared all 23 source/test/log hash references in the product follow-up verification and two RED receipts, plus distribution RED/GREEN receipts: 23 matched, 0 mismatched. Inspected the corresponding logs, test implementations, first-round retained test hashes, source changes and relevant unchanged approval/preservation/migration paths. Test outcome and process-exit observations come from those supplied receipts/logs; hashes establish current content consistency, not independent authentication of historical execution.

This was read-only static source/document and hash/data review. No candidate code, tests, build, verifier, worker or manager was executed; no network, credentials, repository mutation or subagents were used. The product causal cases use product.v1 and fixture containment. No fresh full-suite execution, product.v2 causal run, deployed consumer migration, real authenticated product pilot, protected-judge adoption, PR publication or global integration acceptance is certified. Current global corrections in the other worktree were deliberately excluded.
