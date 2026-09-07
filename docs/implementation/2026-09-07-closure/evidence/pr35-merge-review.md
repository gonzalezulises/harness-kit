# PR35 mechanical merge conflict review

Date: 2026-09-07. Inspected `/workspace/scratch/adce1c53b293/closure-pr35-integrated`, merging corrected PR33 `65c6e5f7aecd107188f4f164e849d7c8aed91cc3` into original PR35 `dd8a20c1465b3ccd7e9a4d86ed6a11860146e7f7`.

**Journal conflict resolution: spec APPROVED, quality APPROVED. Feature-record union: APPROVED. Requested integrated-source check: NEEDS FIXES.** One Medium integration finding; 0 Critical, 0 High, 0 Low. No whole-branch approval is given.

## Journal resolution

The diff against original PR35 retains product.v1 event/operation decoders, journal runtime bindings, reducer integration and the original productCustody contract. The only adaptation introduces an internal claim result while preserving the public append receipt:

- append acquires the exclusive lock once and calls appendOwned.
- appendOwned unwraps `.receipt` from appendClaimOwned, so ordinary append and productCustody callers still receive the original frozen APPENDED receipt shape.
- productCustody acquires the lock once and passes the already-owned appendOwned callback, avoiding a nested lock acquisition.
- private claimExecution checks for an execution-backed reserve plus a function validator, acquires the lock once, and returns `{created, receipt}` from appendClaimOwned.
- The private core reads the current journal and checks identical operation identity under that lock. Existing entries return created:false; new entries check the expected head, invoke the private current-authority validator and retain the existing transition and durable append procedure before returning created:true.

The imported execution caller dispatches only when the claim reports created:true. The receipt/core block and productCustody/claimExecution lines match the primary adaptation byte-for-byte. Compared with corrected PR33, the retained differences are the original product.v1 integration and the necessary separation between lock-owning and already-owned append paths. No product.v2 schema or event meaning is introduced. Static inspection found no defect in this conflict resolution.

## Feature and merge state

JSON data comparison confirms all 25 original PR35 feature objects F01–F25 are identical, including historical evidence and blocked states. The sole addition is F28, exactly matching corrected PR33. F28 is the sole active feature; F09 and F25 remain blocked. No unmerged index entries or conflict markers remained in the inspected journal, feature list, progress or quality document.

## PR35-MERGE-1 — Medium — Integrated product source omits the approved M1/M3 corrections

The requested confirmation of corrected product bytes fails. Current product.mjs SHA256 is `50a2ec1b54da1c1e5591dd97d0cbb7aae3a5d1d6609cbdbe8dd7963da794a1bc`, identical to the original defective PR35 parent and retained RED source. The approved corrected v1 hash is `5202e4994c008acb08739670a90bd43adb2e5275f8f29f310cd0961701e6e006`.

At product.mjs:202, fatal TextDecoder decoding is still unguarded in the close callback. At lines 236–237, the objects path still derives from `--absolute-git-dir`, not the common Git directory. Thus both known Medium cases remain in this inspected integration tree. The quality document's current product row states that these corrections passed current-byte review; those corrected bytes are not in this tree at inspection. This is a source integration omission, not merely missing new test execution.

Resolution: carry over the already approved two-hunk v1 correction and its applicable acceptance materials into this integrated tree, bind evidence to the resulting frozen source, and recheck the exact product hash. No journal redesign is indicated. Existing broader readiness blocks must remain.

## Exact inspected identities

| Repository-relative file | SHA256 |
|---|---|
| packs/autonomy/repo-template/scripts/quality-orchestrator/journal.mjs | `fdf4d7d59184b78f2dafdee53a863bc8832b8c33ec945e2a7abadbaca0b3c944` |
| packs/autonomy/repo-template/scripts/quality-orchestrator/product.mjs | `50a2ec1b54da1c1e5591dd97d0cbb7aae3a5d1d6609cbdbe8dd7963da794a1bc` |
| feature_list.json | `fe03b74ff80e5829b0794a1c50d624e8984ab2509427eb655329d586cb5f3f00` |
| docs/quality-document.md | `205832a197166017c0d46d7dd93692fd54e00f549cc406176bb9a77c9e58355d` |

Original PR35 journal SHA256: `45d58afff96fbab523b068a392cab39368e2016dc702aa1fca154b31c28fb7ee`.

## Limits

Read-only source/document inspection, Git data comparisons and reviewer-authored hashing only. No candidate code, probes, tests, network, credentials, source writes or agents were used. Full checks for PR35, PR36 and primary were reported running; no passing result is claimed here. The verdict concerns this merge resolution and the expressly requested retained-source identity check, not other imported changes, whole branches, real authenticated acceptance or publication. The product finding records bytes observed before any subsequent controller repair.
