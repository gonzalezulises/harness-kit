# PR34 protected judge adoption — independent read-only review

Examined proposal base: `88ea1e6c45faf5b5db9e29935eef6e25e50f633b`.
Examined proposal head: `b6b93e4fd8241298471e9cfc4356ecca47412f43`.
Examined snapshot source: `a798c88ad625be2478d24df52c0dc45c51e2d4e4`.
Object store: `/workspace/scratch/adce1c53b293/harness-kit`.

**Spec verdict: PASS for the bounded additive adoption proposal. Code-quality verdict: PASS with one nonblocking documentation finding. Ready to merge: YES for this exact head through ordinary required checks, based on the supplied exact-head CI result and authorization. No protection bypass is justified.** This verdict does not adopt or approve PR33, certify a deployment, or waive its remaining review and acceptance gates.

## Findings

- **P3 / low — publication status is stale:** `docs/protected-judge-adoption.md:37-42`, with the same status in `PROGRESS.md:18-22` and `docs/protected-judge-verification.json:47-48`, describes the proposal as local, awaiting a draft PR, and remote CI as not executed. The review assignment supplies an existing PR34 and successful exact-head Required quality run. The receipt is useful as historical evidence, but the prose does not clearly date its local-only status. Preserve the historical receipt and record the later publication/check/adoption events in the closure record. This does not weaken the judge or block the authorized exact-head adoption.

No P0, P1, or P2 finding was identified in this scoped review.

## Independently verified local evidence

- The supplied `judge-diff.patch` exactly equals `git diff --unified=5` between the examined base and head. Head tree identity also equals local commit `8d81df9`.
- All 30 manifest entries have identical source and snapshot bytes, identical source and snapshot Git modes, and matching SHA-256 values. Manifest file and mode key sets agree. Bundle inventory contains precisely these 30 files plus `SOURCE.json`; there are no unmanifested payload files.
- `SOURCE.json` SHA-256 is `81099c812e9c094ed6210b877f44b4317aadf0f8ec2c98cf26163285b5026143`, matching `docs/protected-judge-verification.json`.
- The 12 copied oracle definitions point to receipts present at the exact source commit. All 163 test/source/log hash bindings in those receipts match source-commit objects. This establishes internal byte consistency, not independent witnessing of RED execution or authenticated acceptance.
- The proposal leaves `.github/`, root `scripts/`, `AGENTS.md`, root `DECISIONS.md`, root `feature_list.json`, and `Makefile` unchanged. Its sole active-code edit is the unconditional `K6_NO_USAGE_REPORT=true` export in `packs/load-testing/verify-pack.sh:15-16`; no assertion, threshold, exit handling, or fixture omission was added by that edit.

## Spec and compatibility assessment

The exact-head AGENTS contract, adoption procedure, receipt, DECISIONS, architecture document, and proposed Agent Note were read. The change is explicitly a derived policy snapshot, and does not promote a root feature state. The proposed note cites its governing documents and explains the authority transition and duplication tradeoff.

The unchanged Required quality workflow still checks out the exact base and head, takes claim and decision checkers from the base, and requires observed exits and sentinels. This PR does not switch its own evaluation to the new bundle. No ruleset or privilege mutation appears in the diff; live settings were not queried.

The source continuation's consumer workflow was inspected for compatibility only. It requires `base/.harness/protected-judge/v1`, installs its parser from that base bundle, invokes the base runner with an explicit candidate target, and selects its claim contracts and decision ledger from the same base bundle. A missing contract or checker blocks; no candidate-judge fallback is present in those paths.

Within the copied runner, script resolution stays below its own judge root, while candidate data is addressed via `HARNESS_TARGET_ROOT`. Protected architecture rules, routes, oracle definitions, feature contracts, and ledger paths are explicitly passed to child checks. The contract and installation profile are checked before gates run. Required missing scripts and nonzero child exits block. All invoked quick-gate scripts exist in the snapshot. Non-executable modes on some shell files are preserved correctly because consumers invoke them with `bash`.

Parser setup derives its virtual environment and pinned `PyYAML==6.0.3` requirement from the relocated judge root. The oracle verifier chooses that judge environment and uses isolated Python execution. Oracle test and receipt paths intentionally resolve against candidate data, explaining why their evidence payloads are not duplicated into the snapshot. The source-commit hash checks above substantiate that linkage.

## Evidence limits and remaining conditions

The assignment reports Required quality run `34051386295` completed successfully on exact head `b6b93e4fd8241298471e9cfc4356ecca47412f43`, and no PR review threads. These are supplied host observations, not independently authenticated by this reviewer. The committed receipt separately reports 411 full assertions, 273 startup assertions, eight passing quick gates, and two authenticated-gh omissions; raw execution streams are not distributed. I did not rerun those programs or infer coverage of the omitted authenticated cases.

This review used Git object reads/diffs and reviewer-authored data comparisons only. No candidate program, installer, network request, credential operation, repository mutation, or subagent was executed. The only file written is this report.

The snapshot is a complete bundle for the inspected consumer, not an organization-enforced trust boundary. Full claim verification and repository tests can execute candidate commands and must continue to run without deployment or signer credentials. Fixture success and source hashes do not constitute owner adoption, real-host acceptance, or proof that the complete hardening feature is finished. The ordinary merge of the expressly authorized exact head is the adoption event; any changed head needs renewed checks appropriate to that head.
