# Narrow final-fix-1 code-quality review

Review target: correction tree `126ba1e9a89b3781d71587aa76b2782223ce6f1a` from correction base `432c1824db6f509da3f1ded0d04d7c6608e5e080`, using the supplied brief, implementer report, correction diff, and retained outputs. `65c0c6976520ca53b878224e081d042a62853db4` is treated only as the prior publication/support-source reference. This review did not resume the interrupted broad review and did not rerun tests or workflows.

## Verdicts

- **Scope-specific findings: 0** (critical 0, high 0, medium 0, low 0).
- **FR-01: ADDRESSED.**
- **Workflow setup: ADEQUATE by code/static review; actual GitHub Actions execution remains unclaimed.**
- **New breakage in the corrective diff: none identified within the supplied scope.**

## FR-01 assessment

`packs/autonomy/repo-template/scripts/quality-orchestrator/capabilities.mjs:20-29` changes only the inventory accumulator, with the operative correction at line 21 from an ordinary object to `Object.create(null)`. That removes the inherited `__proto__` setter behavior while preserving property assignment, own-key serialization, traversal, entry/byte bounds, mode checks, and the manifest interface. A root file literally named `__proto__` therefore becomes an own inventory entry and participates in the prepared-binding digest.

The new regression is focused and causal:

- `packs/autonomy/repo-template/scripts/quality-orchestrator/tests/literal-filename.test.mjs:9-16` runs the same disposable fixture for an ordinary `frozen.txt` control and literal `__proto__` file.
- Lines 43-48 prepare the capability, acquire its lease, mutate the frozen file after preparation, and then attempt execution.
- Lines 50-58 jointly require `POLICY` / `prepared binding changed`, zero spend, no pending operation, unchanged output bytes, retention of the externally changed frozen bytes, and no effect intent/receipt.

The retained causal RED binds defective source SHA-256 `0084e0f78e233c7dbd4ff751afe07faf839f62f475831d46fb35908960d3c6a6` and unchanged test SHA-256 `1db50a3c4fd5af7d6a238ac12757af61e686fe04488756702b2191692dc0953d`. Its TAP output records the ordinary case passing and the literal-name case failing with `EFFECT_VERIFIED`, spend 1, output mutation, and intent/receipt records. The retained corrected F19 runtime output records 32/0, including both paired cases; its result record reports exit 0. This evidence directly exercises the confirmed failure mode before effects and spending.

## Workflow setup assessment

`.github/workflows/required-quality.yml:152-161` adds exactly two prerequisite steps after the protected gate completes at line 150 and before the existing `make check` step at lines 163-178:

1. The workflow selects Node 22 using commit-pinned `actions/setup-node` and disables automatic package-manager caching.
2. It runs `npm ci` against the existing nested package and lockfile from the checked-out `head`, with scripts, audit, and funding calls disabled. This installs the locked yaml/zod dependencies and populates npm's default cache for the later offline consumer canary in the same job.

The supplied static verifier compares parsed current and preserved-before workflows after removing only these two adjacent steps, and checks their placement between the existing `gates` and `check` step IDs. The retained static/final-consistency results report exit 0. Within this correction, no prior gate, job permission, protected-base judge, failure sentinel, or check body changes.

This is a static/setup assessment only. No clean GitHub runner or remote workflow execution is evidenced, and protected-policy `ADOPTION_REQUIRED` remains unresolved.

## Candidate and evidence preservation

`docs/implementation/2026-09-05-harness-hardening/final-fix-1/baseline-candidate.json:2-4,11-22` keeps owner acceptance/signature null, labels the candidate `UNSIGNED` and `CANDIDATE_NOT_ACCEPTED`, records both live backends as `UNIMPLEMENTED`, records real review/production acceptance as `NOT_EXECUTED`, and leaves publication commit coordination separate. Lines 7-9 and 18-20 bind the new evidence and source manifests without self-reference or a guessed final commit.

`docs/implementation/2026-09-05-harness-hardening/final-fix-1/evidence-manifest.json:52-54` retains explicit hash references to the historical H09 candidate, evidence manifest, and source manifest. `preservation.result.json:2-4` records 3,362 checked prior files with an empty changed-path list. The retained static verifier and final-consistency records report successful hash/mode, RED-receipt, workflow-equivalence, candidate-status, manifest, and whitespace checks. No old evidence replacement is present in the supplied correction.

## Remaining limits

- The broad final review remains **INCOMPLETE** after the automatic control interruption; this narrow result does not approve the whole branch or establish original production acceptance.
- Positive live review and production backends remain **UNIMPLEMENTED**.
- Remote CI execution and protected-policy adoption remain pending.
- Test and static results above are assessments of the supplied retained outputs; they were not rerun during this read-only review. Root-owned final feature/full/startup gates are outside this report.
