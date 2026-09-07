# CI fixture and merge follow-up review

Date: 2026-09-07. Read-only review of the specified fixture-runner change and restored-source claims in three worktrees under `/workspace/scratch/adce1c53b293`.

| Scope | Spec verdict | Quality verdict | Open findings |
|---|---|---|---|
| PR33 fixture environment isolation | APPROVED statically | APPROVED; full verification pending | 0 |
| PR35 integrated product restoration | NEEDS FIXES: approved bytes absent | Journal resolution remains APPROVED; product restoration not present | 1 Medium, retained PR35-MERGE-1 |
| PR36 integrated manager restoration | NEEDS FIXES: approved bytes absent | Approved correction not present in this tree | 1 Medium |

Total: 0 Critical, 0 High, 2 Medium, 0 Low. The prior omissions remain recorded and cannot be closed from the inspected bytes. The controller was notified of the discrepancies during review.

## Fixture environment change

The diff to `harness-judge-target/tests/run-tests.sh` is exactly five inserted lines: three explanatory comments, `unset ROUTES_BASE DELIVERY_BASE`, and a blank line. Removing those added lines recreates the retained RED runner exactly. No assertion, test, gate, exit check or other environment setting changes.

The suite constructs independent temporary Git histories. Its activation, delivery and route cases use fixture branches/commits; inheriting the source repository's comparison SHA makes those fixture checks fail with an unavailable base. The explicit adverse tests that assign ROUTES_BASE=deadbeef and DELIVERY_BASE=deadbeef remain and continue to require nonpassing outcomes. Clearing the incoming values at fixture-shell startup does not change those later test assignments.

The current Makefile invokes the suite through `bash tests/run-tests.sh` in a child process. Quick gates run separately before check-core. The required-quality workflow explicitly supplies the protected base SHA to the protected quick gate and separately to make check; the fixture child's unset cannot modify its parent environment or later workflow steps. The workflow's protected-base checker paths, judge-contract requirement, observed exit checks and final claims/decisions checks remain unchanged. There is no protected-policy weakening in this scoped change. This statement does not close any broader CI trust/isolation finding.

The retained remote log for run 34074937651/job 101599089897 and local reproduction both show 268 passed, 18 failed, including invalid ROUTES_BASE in independent scaffold histories. The local receipt records its exact inherited base values and exit 1; the remote pipeline exits 2. All three retained source/log bindings match. This reviewer did not fetch or authenticate remote results independently and did not execute GREEN. CI-environment full verification remains pending.

## PR35 restoration discrepancy — PR35-MERGE-1 remains open

Direct reads show `closure-pr35-integrated/product.mjs` still has original defective SHA256 `50a2ec1b54da1c1e5591dd97d0cbb7aae3a5d1d6609cbdbe8dd7963da794a1bc`. It still decodes strict UTF-8 unguarded in the child close callback and uses the per-worktree `--absolute-git-dir` objects path. The approved original-v1 correction remains available in `closure-pr35` with SHA256 `5202e4994c008acb08739670a90bd43adb2e5275f8f29f310cd0961701e6e006`.

The integrated v1 contract also differs from the named source: integrated hash `f6a61be90ea3568ad98a61b1a74132a360d98c67b31b764152d838009bff3269`, versus `closure-pr35` hash `dec94f24ee4d7793c133c9e604931e2553dd05f08fa87ecf3e3f00558ad59be1`. Thus the claimed source/contract copy is not present in the inspected paths. The journal remains exactly the previously approved merge hash `fdf4d7d59184b78f2dafdee53a863bc8832b8c33ec945e2a7abadbaca0b3c944`; its conflict approval stands.

The preserved omission-full-check.log matches its receipt hash and shows both targeted failures, including uncaughtException for malformed UTF-8, ending make check with exit 2. The receipt's corrected_product_sha256 field names the intended approved source; it does not match current product bytes. Carry over the approved v1 source/contract and recheck identities before claiming restoration. This is an observed source omission, not merely unexecuted testing.

## PR36 restoration discrepancy — Medium

`closure-pr36-integrated/bin/harness-consumer.py` still has baseline SHA256 `35d4e2ca41c3a3585ee4edb13def46596a6336dc1d61451ffd5363ae16c56b73`. It lacks production_runtime_path. The primary approved manager is `c204ad219c3137157e8edf7721392cb2554c1bc17edd1623f42dbfb96089264c`, as independently read and recorded in root-followup-review.md. Consequently the fixed top-level production inventory behavior has not been transplanted to this inspected tree. Restore that approved exact source before claiming the omission closed.

The established compatibility limit remains: manager bytes are stable payload, and ordinary upgrade/rollback rejects differing stable signatures with MIGRATION_REQUIRED. Once the approved fix is present, it supports fresh installation and transitions whose stable manager signatures match; it does not add automatic old-manager migration. No overwrite, adoption, profile or authority relaxation is authorized by this review.

## Exact observed identities

| Worktree | Repository-relative file | SHA256 |
|---|---|---|
| harness-judge-target | tests/run-tests.sh | `2427fe61ce005711b6a11627d8d8d716cfcc0bd90d8e2dfb872d9d36a77b68c7` |
| harness-judge-target | .github/workflows/required-quality.yml | `78edb63f69c734f362c6ffd28441a71f50ac7bc7251e04eeaf3e0147815af2b8` |
| closure-pr35-integrated | packs/autonomy/repo-template/scripts/quality-orchestrator/product.mjs | `50a2ec1b54da1c1e5591dd97d0cbb7aae3a5d1d6609cbdbe8dd7963da794a1bc` |
| closure-pr35-integrated | packs/autonomy/repo-template/scripts/quality-orchestrator/journal.mjs | `fdf4d7d59184b78f2dafdee53a863bc8832b8c33ec945e2a7abadbaca0b3c944` |
| closure-pr35-integrated | packs/autonomy/repo-template/scripts/quality-orchestrator/contracts-product-v1.md | `f6a61be90ea3568ad98a61b1a74132a360d98c67b31b764152d838009bff3269` |
| closure-pr36-integrated | bin/harness-consumer.py | `35d4e2ca41c3a3585ee4edb13def46596a6336dc1d61451ffd5363ae16c56b73` |

## Evidence limits

Static reads and reviewer-authored hash/data comparison only. No candidate execution, probes, network, credentials, source edits, staging, commits or subagents. All outcomes are bounded to the observed source hashes; later controller repairs require a fresh identity check. No repeat full-check success for PR35/PR36/primary or CI, whole-branch approval, live authenticated acceptance, merge completion or publication is certified. Earlier failure logs and omission findings are preserved rather than overwritten.


## Follow-up readback — 2026-09-07T02:20:44.888284+00:00

**Both integration omissions are now CLOSED. Current scoped spec and quality verdicts: APPROVED. Open findings in this follow-up: 0 Critical, 0 High, 0 Medium, 0 Low.** The earlier observations and failed verification runs above remain an accurate historical record; this dated section supersedes their current-source verdict only.

A new independent tool call read the actual destination bytes after the controller's persistence repair and compared them directly with the approved source files:

| Destination | Current SHA256 | Comparison |
|---|---|---|
| closure-pr35-integrated product.mjs | `5202e4994c008acb08739670a90bd43adb2e5275f8f29f310cd0961701e6e006` | Byte-identical to approved closure-pr35 source |
| closure-pr35-integrated contracts-product-v1.md | `dec94f24ee4d7793c133c9e604931e2553dd05f08fa87ecf3e3f00558ad59be1` | Byte-identical to closure-pr35 contract |
| closure-pr36-integrated bin/harness-consumer.py | `c204ad219c3137157e8edf7721392cb2554c1bc17edd1623f42dbfb96089264c` | Byte-identical to approved primary manager |

The original-v1 product diff contains precisely the previously approved caught strict UTF-8 decode and common Git-directory fixes. The contract adds accurate prose for controlled malformed output, preserved pending/resume behavior and local linked-worktree handoff. The manager diff is exactly the approved production_runtime_path admission change in bundle construction and manifest validation; the required minimum and stable-manager migration restriction remain. The PR35 journal is unchanged at `fdf4d7d59184b78f2dafdee53a863bc8832b8c33ec945e2a7abadbaca0b3c944`, retaining its earlier conflict-resolution approval.

This closes PR35-MERGE-1 and the PR36 restoration omission on directly observed current bytes. It does not establish the implementation details of the controller's filesystem persistence repair. No test was run, no repository file was changed, and no repeat full check is certified. CI fixture approval remains the earlier static scoped approval; automatic migration, whole-branch acceptance and live authenticated acceptance remain outside scope.
