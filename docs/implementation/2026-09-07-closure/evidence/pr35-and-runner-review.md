# Scoped PR35 transplant and PR33 runner review

Date: 2026-09-07. Static inspection only. PR35 worktree: `/workspace/scratch/adce1c53b293/closure-pr35`; original published parent: `dd8a20c1465b3ccd7e9a4d86ed6a11860146e7f7`. Runner worktree: `/workspace/scratch/adce1c53b293/harness-judge-target`.

| Scope | Spec verdict | Quality verdict | Findings |
|---|---|---|---|
| PR35 product.v1 M1/M3 transplant and causal evidence | APPROVED | APPROVED | 0 |
| PR33 test-runner ordering correction | APPROVED statically | APPROVED statically; repeat full check pending | 0 |

Counts: 0 Critical, 0 High, 0 Medium, 0 Low. These are bounded change verdicts, not whole-branch, protected-judge, merge or live-acceptance approval.

## PR35 transplant

The entire `product.mjs` diff from the stated parent is two hunks: strict UTF-8 decode is caught inside the child close callback and rejects its promise with BLOCKED_TOOL_FAILURE; PR preparation resolves `rev-parse --path-format=absolute --git-common-dir` before using the common objects directory. No later product.v2 implementation was transplanted. A byte comparison of all existing tracked runtime files against the parent found only product.mjs changed; existing tests, schemas, runtime modules and contracts are unchanged.

The original v1 public safeAsync boundary handles the rejected promise. Its pending-operation resume still requires an acknowledgement and returns INCOMPLETE without redispatch when no acknowledgement exists. The original v1 scope, signed budget, nonce, authority, source freshness, frozen-input and readiness controls remain. PR preparation continues to write trees and commits to a private bare repository using the signed base as parent, with realpath/newline checks and disabled hooks unchanged.

The three new test/helper hashes equal the shared acceptance bytes approved in `root-followup-review.md`. Those tests inspect the actual prepared parent and frozen Git tree entry, changed functional bytes, preserved source frozen bytes/index/refs/HEAD, and an actual resume call following malformed UTF-8 with one verifier invocation and unchanged spend/pending state.

The new PR35-specific evidence correctly uses the original v1 pre-fix source, SHA256 `50a2ec1b54da1c1e5591dd97d0cbb7aae3a5d1d6609cbdbe8dd7963da794a1bc`, rather than the later branch's different defective product file. This retained source equals the published parent's product.mjs. The RED log shows 2 failures at the intended causes: nonexistent per-worktree objects directory and uncaught ERR_ENCODING_INVALID_ENCODED_DATA. The GREEN log shows 2 passed, 0 failed, no skips. All 10 source/test/log references across the two receipts match current retained bytes. Receipt command, exit fields and observed log contents agree. These are fresh local fixture observations, not a live authenticated pilot.

The new `.harness/oracles/AC-product-closure.yaml` describes those same assertions, lists precisely the three receipt-bound test/helper paths, points to the new RED receipt and names the actual pre-fix published parent as proved_sha. Read-only Git ancestry inspection confirms that parent is an ancestor of the inspected HEAD. The record fits the existing local RED-receipt contract; no oracle verifier was executed during this review. The tracked diff against the parent changes product.mjs and progress prose only; the new acceptance materials are additions, preserving historical tracked receipt contents.

## PR33 runner ordering

The current `packs/autonomy/verify-pack.sh` is byte-for-byte identical to the published PR35 parent's runner. Compared with the retained failing runner, the only behavior change is running `capabilities.test.mjs` to completion first, then building the remaining runtime test-file array and executing it, followed by the same pack-level suite.

`capabilities.test.mjs:107–110` temporarily appends to the installed yaml package.json and restores its bytes in finally. Other runtime tests bind hashes of that shared dependency. The supplied failing full-check log reports 253 runtime tests, 250 passed, 3 failed; each failure is an unexpected BLOCKED_BY_RUNTIME_BINDING in a global correction, execution-backend or review case. That pattern and the inspected shared mutation support the reported ordering race. The new sequential invocation removes the identified overlap within this runner. This does not claim isolation between independently launched concurrent verification jobs.

No tests or gates are removed: capabilities runs exactly once in the first invocation, the array contains every other matching runtime test file exactly once, and both pack test files still run. The inspected tree has 13 runtime `*.test.mjs` files, partitioned as 1 plus 12, and 2 pack `*.test.mjs` files. Node/version/dependency prerequisites, TAP reporting and `set -euo pipefail` remain. A failure in the first group still fails the runner. The capabilities test matches HEAD byte-for-byte, and the tracked test-directory diff is empty. New closure tests already present in this worktree are included by the same glob, not excluded by the correction.

All three runner source/log hash bindings in test-isolation/verification.json match. The retained failing runner hash is `ee5a270804915d44a976bc1fcb62d482c7de4e6dd6aa76a687bf4221a24e9b03`. **The repeat full check was reported running and has not been certified here.** Static approval of the ordering change does not substitute for its completion or erase the retained failed run.

## Frozen source and test identities

| Scope | Repository-relative path | SHA256 |
|---|---|---|
| PR35 | packs/autonomy/repo-template/scripts/quality-orchestrator/product.mjs | `5202e4994c008acb08739670a90bd43adb2e5275f8f29f310cd0961701e6e006` |
| PR35 | packs/autonomy/repo-template/scripts/quality-orchestrator/tests/product-corrections-fixture.mjs | `e57fa5d6b9b8d24148c9a0df83247ba89fcd819d96521a2a1aa118a65de0ce41` |
| PR35 | packs/autonomy/repo-template/scripts/quality-orchestrator/tests/product-linked-worktree.test.mjs | `b254805a85b53076553f77cc115228f70e71a21faa46ba3955b83506ed805682` |
| PR35 | packs/autonomy/repo-template/scripts/quality-orchestrator/tests/product-verifier-utf8.test.mjs | `b700c75b47c465222ae8c30f6e99ef6db7d5baf2a158dcf7f8a963e03677571b` |
| PR33 | packs/autonomy/verify-pack.sh | `51e6b0751c06420b2877086451827dfb4d4d70f894b98e9f7f3da10ce0dc2077` |
| PR33 | packs/autonomy/repo-template/scripts/quality-orchestrator/tests/capabilities.test.mjs | `95ed2f3d23416629e8226ffbdd15cb28139e83b7abbe588a6d52e7ff03db291b` |

Evidence identities at inspection:

- PR35 oracle: `492302f543df2ae97bef978ad002b773be3d9692dbfc279706386eb075919241`.
- PR35 RED receipt: `96f521bf83cd5dae974eb97e64120e92a1f4cdffd48ed96ffbce4867b3c8386f`.
- PR35 GREEN receipt: `4544f9e160ecf8b843d2d08e1e48e3c64970e34128a338926c06669e7bf7a97f`.
- PR33 runner verification record: `b8cd7b5b3fd4a8756088bde28175b5854f640c9d3cf2ddb36fbdd82d18704479`.

## Limits

Only source, documentation, logs, receipt data and read-only Git comparisons were inspected. No candidate execution, test run, probe, network, credential access, source edit or delegation occurred. Observed test outcomes are supplied-log evidence, not reviewer-run execution. Original product.v1 behavior outside the two hunks was preserved by byte comparison, not re-certified globally. No full PR35 regression pass, completed PR33 repeat full check, whole-branch safety, authenticated host/model acceptance or publication is asserted.
