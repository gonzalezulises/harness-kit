# PR33 independent whole-branch defensive review

Reviewed range: `88ea1e6c45faf5b5db9e29935eef6e25e50f633b` → `0a51623b5db42951a6091847a179262182abd67d`.

**Specification verdict: NEEDS FIXES. Code-quality/security verdict: NEEDS FIXES. Merge recommendation: DO NOT MERGE this head.** New findings: **0 Critical, 4 High, 1 Medium**. The findings below come from source/control-flow inspection and read-only ancestry comparisons, not newly executed reproduction. The original FR-01 inventory correction remains closed; finding GR-04 concerns a different dictionary and postcondition path.

This is a completed review under the reduced read-only brief, with the coverage limits below. It is not a claim that every archived byte or every possible defect was independently examined. No candidate programs, tests, shell scripts, network operations, credentials, repository mutations or subagents were used. Reviewer-authored file/hash comparisons and read-only Git inspection were used. Only this report was written.

## Findings

### GR-01 — High: an idempotent journal append does not establish sole dispatch ownership

**Location:** `packs/autonomy/repo-template/scripts/quality-orchestrator/execution.mjs:35–40`; supporting behavior at `journal.mjs:169–179`.

The execution path checks whether an intent exists, writes the descriptor, calls `journal.append`, and then unconditionally dispatches. Journal append intentionally returns the original successful receipt when an identical key/request already exists, before comparing the caller's expected head. Consequently, two cooperating controller processes can both observe absence at line 35; the first appends and releases the journal lock, and the second receives the same successful receipt for that existing reservation. Both then reach dispatch. One journal debit can therefore represent two external workflow executions. The immutable acknowledgement can reject the second distinct run only after both effects have been started.

The runtime's journal supports multiple processes and the Actions contract explicitly promises one dispatch for concurrent identical requests. This interleaving does not require a hostile same-UID writer, changed runtime, or permission expansion. The current concurrency test (`tests/execution-backend.test.mjs:220–222`) uses two promises in one JavaScript process, whose synchronous reservation section cannot exercise this cross-process gap.

**Correction:** make acquisition of the right to issue the original dispatch an atomic, durable operation under journal ownership. Distinguish a newly created reservation from idempotent retrieval; only the creator may dispatch, while other callers reconcile the original key. Preserve the conservative no-redispatch behavior after a creator crash. Add a bounded two-process regression that coordinates the pre-reservation interleaving and proves one start and one debit. Do not solve this by automatically retrying uncertain requests.

### GR-02 — High: operation authority can expire during asynchronous transport preflight

**Location:** `packs/autonomy/repo-template/scripts/quality-orchestrator/execution.mjs:34–40`; callers at `release.mjs:119–123,200–204` and `review.mjs:45–51,95`.

Release execution checks the objective and its separate action approval while constructing/checking the request. Review similarly checks its signed review policy. The shared backend subsequently awaits network preflight. After that await it rechecks the execution-budget approval and, for reviews, catalog freshness, but does not recheck the distinct deployment/rollback/artifact approval, release-objective approval, or review-policy approval. A short-lived deployment authorization can be valid when the public call begins and expired when the reservation and dispatch occur, while the independent execution budget and accepted context remain valid. Expiring prerequisite release evidence can likewise make the earlier derived next obligation stale.

The backend is explicitly designed to keep execution-budget authority separate from permission for the actual action. Rechecking only that budget is insufficient. Rejecting a later observation because the action approval was stale does not undo an already-started operation. The operator workflow must also enforce its action boundary, but the shipped controller cannot promise current authority while allowing this start.

**Correction:** after asynchronous preflight, revalidate all approval handles and operation-specific prerequisites used to authorize this exact start, immediately before the atomic reservation/dispatch ownership decision. Preserve original-key reconciliation semantics for work already started. Keep this a closed internal operation check, not a candidate-supplied validation callback. Require the supervisor contract to repeat action-specific authority checks before the actual remote effect. Add deterministic clock-advance cases where only the action/policy or prerequisite evidence expires during preflight; they must stop without a new reservation or dispatch.

### GR-03 — High: the protected CI judge remains writable by candidate programs in the same job

**Location:** `.github/workflows/required-quality.yml:68–74,101–115,146–150,163–195`; the consumer analogue is `templates/full/.github/workflows/required-quality.yml` around its candidate pipeline and protected claims steps.

Exact base checkout and literal protected-base paths establish initial provenance, but not ongoing protection. Both checkouts, the installed parser, and the sentinels occupy the same job filesystem. The workflow executes the head's Gherkin program before invoking the base judge, then executes the head's verification pipeline before the base claim/decision checks. No process/filesystem boundary prevents those candidate programs from changing the base judge or its policy before it is used. `persist-credentials: false` and API `contents: read` restrict credentials/API writes, not local filesystem writes by those processes.

Thus a candidate-controlled program can affect the code/policy subsequently described as the protected judge, despite using the correct base path and preserving the workflow file itself. This is a gap in the advertised CI authority boundary, not the separately disclosed inability to certify production or resist replacement of an operator-owned local autonomy runtime. The relocation regression (`tests/protected-workflow-regression.py:94–105`) verifies a present base bundle and absent-base/head-only refusal; it does not exercise candidate execution alongside the judge.

**Correction:** keep judge policy, runtime, verdict channels and observed-zero evidence outside the write authority of candidate execution. Use an actual isolated execution boundary or separate trusted supervisor/job that reads the exact target as data and supervises isolated candidate commands. Merely reordering steps, putting files in another writable directory, or rechecking an equally writable hash file does not supply this property. Retain the existing exact-commit and required-check semantics. Add a bounded isolation regression in the authorized corrective cycle; no such probe was run in this review.

### GR-04 — Medium: a literal output filename can produce a verified no-op

**Location:** `packs/autonomy/repo-template/scripts/quality-orchestrator/capabilities.mjs:58–66,73–75`.

The repaired workspace inventory uses a null-prototype dictionary, but the capability's `outputs` accumulator is still `{}`. The path schema permits the literal root filename `__proto__`. For canonical writes, assigning the computed string to that inherited setter does not create an own output entry. The subsequent membership validation, projected changes, expected-after mutation and publication all enumerate own entries. They therefore process no output for this request. With an otherwise valid accepted record, exact grant and lease, the unchanged workspace matches the incorrectly unchanged expected manifest and the completion path labels the operation `EFFECT_VERIFIED`, `execution: EXECUTED`, and `postconditions: VERIFIED`, charging a unit without canonicalizing the requested file.

This is a functional false-success result, not evidence of an arbitrary write or the old frozen-file inventory omission. The current literal-name regression covers a denied, non-output filename; it does not cover a requested output with that name.

**Correction:** use a null-prototype dictionary or Map for every path-keyed output accumulator, and verify that the output key set is exactly the closed capability's required targets before preparing a permit. Add a literal-output canonicalization case that checks actual bytes, exact output scope, delta and accounting; also retain the original frozen-file regression unchanged.

### GR-05 — High: permitted integration methods sever the oracle proof ancestry required by the adopted judge

**Location:** `scripts/verify-oracles.sh:256–258`, its identical full-template check, and `.harness/protected-judge/v1/scripts/verify-oracles.sh:256–258` at adopted main `2fb86f02d4de83eeb7496c32f01070fd547da8bb`; current `.harness/oracles/*.yaml` proof references.

The controller supplied current repository settings: merge commits disabled, squash and rebase merging enabled. I did not query or change those settings. Read-only Git comparisons establish that all twelve current oracle `proved_sha` references are ancestors of exact PR33 head and none is an ancestor of adopted main. The adopted protected verifier requires that original proof commit be an ancestor of the target HEAD, and rejects before examining the content-bound receipt.

A squash integration omits those branch commits; a rebase integration that rewrites them also loses the exact referenced identities. Thus the pre-merge branch can satisfy ancestry while the resulting main tree fails its live oracle gate and future protected-base checks. Retaining source snapshots and matching log hashes does not satisfy the existing ancestry rule. This is an integration-policy incompatibility, not proof that the historical receipts were fabricated.

**Correction:** establish an explicitly authorized integration path that preserves the required original commit ancestry, or design and independently approve a versioned proof-policy migration that retains exact historical evidence and meaningful provenance across the permitted history transformation. Resolve that choice before merging, and verify the proposed integrated graph against every current and adopted-base proof reference. Do not silently disable the ancestry check, change repository merge policy, rewrite old proof identities, or substitute the future integration SHA without a valid corresponding witness.

## Scope and evidence examined

The source checkout was clean when inspected, and `HEAD^{tree}` and exact PR33 head both resolved to `e8d1478bac30de53ae02a0cabd23fcd6cfe37457`. Findings use that tree's current paths and line numbers. No branch or HEAD was moved.

Primary governing material read: `AGENTS.md`, `DECISIONS.md`, the hardening plan and ledger, runtime-boundary preflight, execution-backend plan and review scope, `docs/quality-document.md`, `docs/harness-capabilities.md`, `packs/autonomy/index.md`, all seven runtime contracts, current installation/judge/architecture/context profiles, and relevant README/template/current-state changes. Earlier review/release contracts are interpreted with their explicit superseding execution contract, not as proof that positive code remains absent.

Mechanism review covered:

- All installed autonomy `.mjs` modules: typed identity, approval verification, classification, journal/recovery/witness, capabilities/leases/manifests, continuation/budgets, Actions transport and schemas, Codex worker, review/shadows, release obligations and public exports; package/lock and descriptive schemas.
- Active legacy verifier changes: feature/claim parsing, command framing, state/budget guards, decision prefix preservation, typed architecture checks, live gate registry, oracle receipts/parser, context routing, delivery/version checks, staged hook, prerequisites and setup.
- Installer/activation/status changes, full/minimal profiles and templates, both required workflows, Makefile/startup wiring, load-target query handling, fixture port/readiness/isolation changes and pack verification integration.
- Relevant regression bodies for literal filenames, Actions concurrency/freshness/recovery, installed-runtime canary/installation and protected-workflow relocation; changed core test behavior and named historical review dispositions. Test implementations were selectively inspected, not all reread line by line.
- Both supplied diff packages and the inventory were used for scope reconciliation. The full package's archival sections were inventoried; their source snapshots were not all rereviewed.

Read-only data comparisons established:

- The 1,543-path inventory exactly matches the requested Git range. The effective inventory contains 121 paths; the full patch has 1,578 sections including 1,422 non-effective archival sections. These are different counts, not interchangeable measures of review coverage.
- All 69 file-content hashes in `docs/implementation/2026-09-06-execution-backends/final/source-manifest.json` match current files. This does not assert equality of non-executable filesystem permission bits discarded by Git.
- All 12 current oracle receipt references resolve; all 183 `tests`/`source`/`logs` hash entries match their retained files, and the receipts record nonzero exits. These checks establish local content consistency, not authenticated execution or that every recorded failure was causally adequate.
- The original fourteen feature records are unchanged except F09's authorized `state` change to `blocked`. The current decision ledger retains the exact base-byte prefix.
- Changed mirrored root/full verifier scripts match; the distinct `clean-state-check.sh` pair is outside this change and was not treated as new drift.

Package SHA-256 values: effective diff `d13901a201a42ef1f176d1c8276b587d5a938c0ce1a0d23fed3d1400ea2d50c9`; full diff `ebfe48d8604407881f1d735733e21b7d7aa7dfd92bf0a609f7b93d8f08a59814`; inventory `ed733f7dfd106f2b1514997c2fa5854808b4e5f815856c5916bf13c47de71826`.

## Historical dispositions

H01's reviewed fixes and H03's directive/stale-constructor corrections are retained, not reopened merely because old reports contain findings. H02's three Medium corrections are present: isolated parser setup, owned timeout cleanup, and explicit missing-delivery-source rejection. H04's two Medium availability findings are corrected in current source: the internal outcome key allows 210 characters and an observed intermediate witness is retained before successor publication. H05 accepted-output membership and H06's actual crypto-verifier/missing-observation corrections remain present.

The H07 historical empty static log and H08 mutation-receipt wording discrepancies remain disclosed in their READMEs; those historical Low notes are not counted as new open defects. The four scoped F24 fixes remain present: enrollment before spending, original deployment key/readback recovery, original-time catalog comparison on resumed review, and streaming fatal UTF-8 decoding. FR-01's null-prototype inventory fix and original causal receipt remain intact. These narrow closures do not establish correctness of the separate paths in GR-01–GR-04.

## Acceptance limits and closure decision

The final F24 verification JSON records local full-check 669, startup 286, eight quick gates and two authenticated-GitHub omissions. This review did not rerun them. That JSON explicitly says its diagnostic streams were not distributed; their hashes cannot independently reconstruct or authenticate those missing streams. Earlier retained receipts and scoped review reports were inspected selectively. Not all archival logs, historical source snapshots, test bodies, original inactive proposals, dependency implementations, minimum-version environments or remote execution behavior were independently reviewed.

Per the review brief, PR34's exact policy was ordinarily merged. This report treats that as the supplied adoption event, not a fixture accomplishment. A later controller update identified exact adopted main `2fb86f02d4de83eeb7496c32f01070fd547da8bb` and the squash/rebase-only settings; I inspected that available object's ancestry and oracle verifier for GR-05. I did not independently authenticate the remote ref/settings, query GitHub, or verify the remote required-check outcome, actual host confinement, issuer custody, external witness, authenticated Codex session, consumer target/readback, smoke/observability or deployment/rollback acceptance. Those remain separate operational evidence requirements. The previous automatically interrupted review remains historical; this read-only report neither reconstructs its unfinished coverage nor claims its probes passed.

The implemented branch cannot currently merge under the specified zero-open-High/Critical gate because GR-01–GR-03 and GR-05 remain open. GR-04 is a bounded Medium correction and does not independently claim broad authority compromise. After correction, causal evidence, scoped independent re-review and the actual required checks against the adopted base and proposed integrated history are necessary before an ordinary merge. Preserve historical receipts and append new dispositions. Even a later merge-ready judgment must remain distinct from P0 readiness, signed baseline acceptance and real review/release/production acceptance.
