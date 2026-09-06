# H02 implementation report

Status: **DONE_WITH_CONCERNS**. Implementation, tests, current documentation and this report are **FROZEN** for independent review. No implementer changes after the freeze manifest. The controller owns state/ledger/DECISIONS, full integration, staging and commits.

## Source identity and authorization boundary

Baseline: H01 commit `fff527b2c7a64fb6d70d60d633a0261e68315169`, tree `b0ee52e63819994ec08b43942ef5e054cd64c259`. Initial read-only preflight ran against that exact tree before publication, as independently checked by the controller. Never label HEAD9ee as H01 source. Implementation began only after controller GO. No source work changed the live index, refs or HEAD; Git writes were restricted to isolated fixture/clone indexes. Root publication/import was controller-owned.

No broad `make check` was run by this implementer. No remote rule change, merge, baseline acceptance, deployment, account/catalog preflight retry, sandbox weakening or subagent occurred. Pack authenticated coverage was deliberately unavailable through a local failing gh fixture; the two existing omissions remain explicitly reported.

## Implemented scope

- **R10/R11:** explicit v1 kit/full/minimal installation profiles declare every gate. Every full universal gate remains required; kit version synchronization is explicitly inapplicable to consumers. Missing/malformed profiles or required scripts block. Integrated `make check` applies live quick gates and then the project/pack pipeline; full registry calls check-core without recursive full→check→full execution. The workflow proposal has exact full-history base/head checkouts, separate protected judges and policy, explicit judge-contract adoption stop, and a live-gates observed-zero sentinel. Candidate verifier files are never overwritten. Protected parser selection stays in the judge root; isolated Python ignores target cwd/PYTHONPATH/user-site imports.
- **R12:** only repair guidance is excluded from layer identity; exact command bytes and every other field (including inputs/environment) stay compared. H01 schema, budget/state authority and no-cache rules remain in force.
- **R14:** exclusive `$WORK` clean-state backup; load servers bind port0, publish their owned PID/actual port, use bounded readiness, and clean up only their own processes. Existing assertions and thresholds remain.
- **R15:** hook materializes regular index blobs into a scratch snapshot, rejects symlinks before formatter effects, blocks formatter nonzero, preserves executable modes/partial staging/worktree bytes, checks staged notes/whitespace and replaces the index only after verifying no concurrent edit. A resolved scratch root avoids rejecting a legitimate symlinked system TMPDIR. User-visible remediation explains selected formatting/staging without widening commit meaning.
- **R16–R18:** pinned safe PyYAML6.0.3 with duplicate/anchor/alias/tag/type validation; complete collection parsing before verdict; critical/high local RED receipts bind actual current tests, preserved source, argv, nonzero exits and logs; proof history must resolve. Context routes cover committed, staged, unstaged and untracked paths and current note content. Root routes describe the kit, consumer routes only installed governance. H01 original audit tests/logs stay untouched; a fresh exact-legacy-source witness supplies its new receipt.
- **R19–R22:** status requires observed bounded local make-check success, inspects ruleset contents and applicability, and classifies failed/incomplete API responses as indeterminate. Deployment status-query failures propagate through retries. Delivery checks read strict JSON version/current migration paths and require a usable migration baseline. Kit version sources are required. Core/full prerequisites, minimal limits, all five bin entrypoints and current quality/capabilities are documented.
- **Bounded upstream blocker:** fixed H01 remote ShellCheck0.11.0 SC2034 genuinely unused color/output assignments in root/mirrors/tests. The H01 remote run34002096392/job101402668518 stopped at lint; no later remote gate execution is claimed. No suppression or threshold downgrade was introduced.

The appended decision proposal is `docs/implementation/2026-09-05-harness-hardening/h02/decision-proposal.md`; the controller may append it to DECISIONS.md. The H02 oracle materializes the criteria and falsification already recorded in the approved brief, read-only preflight and initial RED fixtures. Current notes/docs explain the compatibility costs and witness limits.

## RED-before-fix and reproducibility

All prefixes below are under `docs/implementation/2026-09-05-harness-hardening/h02/` and preserve separate stdout/stderr/exit files. Nothing overwrites an earlier run.

| Evidence | Command/observation | Result |
|---|---|---|
| `preflight/` | Frozen scratch RED02, independently matched to all11 H01 source hashes | 8 causal failures, no errors; exact7-PASS/missing-version scaffold |
| `red-01.*`, `red-01-tests.py`, `red-01.sha256` | `python3 tests/h02-hardening-regressions.py` before H02 production fixes | 14/14 failures, no errors |
| `expanded-red-02.*` | Exact24-test suite with H02_KIT pointing at frozen fff527b | 22 failures, no errors |
| `temp-alias-red-04.*` | One selected hook test against saved intermediate hook source | 1 causal failure; resolved temp-root correction follows |
| `judge-import-red-05.*` | Selected protected-oracle test with candidate module/interpreter | 2 subtest failures; candidate marker proves execution |
| `judge-import-red-05-snapshot/` | Complete tracked patch plus new files against fff527b | Reconstructs the unpublished intermediate implementation; hashes included |
| `status-detail-red-06.*` | Incomplete ruleset-detail fixture against saved intermediate status source | 1 causal false-absence failure |
| `final-red-06.*`, `final-red-06-tests.py`, `final-red-06-context.json` | Final27-test bytes against frozen fff527b; complete subprocess records | 23 failures, no errors; already-correct and intermediate-only cases are not mislabeled RED |
| `h01-witness-01.*`, `h01-witness-records/`, `h01-legacy-source/` | Stored exact bash argv runs the three unchanged audit probes against exact9ee legacy source | Nonzero observed; all three suites have zero errors; no historical log edited |

`baseline-source/` preserves the pre-H02 affected files. `h01-red-receipt.json` and `h02-red-receipt.json` bind named current test bytes and complete witnessed failure streams to preserved defective sources. Additional context/command files record frozen source checkout paths and environment overrides. They are local content witnesses, not independent cryptographic authority.

An exploratory core run01 exposed24 expected fixture-contract migration failures. Core run02's late output was invalidated by an in-flight edit to the test script and ended with EOF/exit2; it is explicitly **not GREEN evidence**. Final core/concurrency runs used stable source. The original preflight run01 likewise remains exploratory; corrected run02 is the causal preflight witness.

## GREEN and verification limits

| Check | Exact command / evidence prefix | Result |
|---|---|---|
| Final focused behavior | `python3 tests/h02-hardening-regressions.py`; `focal-green-06.*` and command records | **27/27**, exit0 |
| Final core, including unchanged H01 focal suite and final H02 suite | `bash tests/run-tests.sh`; `core-final-06.*` | **286 passed /0 failed**, exit0 |
| Real concurrent core suites | Two `bash tests/run-tests.sh`; `core-a-03.*`, `core-b-03.*` | Both **286/0**, exit0, overlapping ~37s |
| Real concurrent load-pack suites | Two `bash packs/load-testing/verify-pack.sh`; `pack-a-03.*`, `pack-b-03.*` | Both **55/0**, exit0, overlapping ~40s; exactly2 authenticated-gh omissions each |
| Controlled readiness failure during four-suite contention | Same pack with server delay2s/readiness bound0.05s; `readiness-timeout-03.*` | Expected exit3/INCOMPLETE in **0.72s** |
| Concurrency identity/isolation | `concurrency-03.json`, `concurrency-runner-03.py` | Every recorded code/test hash unchanged during those runs; actual owned PIDs/OS ports in streams |
| Live current repository policy | `bash scripts/run-gates.sh quick`; `live-gates-final-06.*` | **8 PASS /0 blocking**, exit0 |
| Pinned static gate | `/workspace/scratch/adce1c53b293/tooling/shellcheck/shellcheck-v0.11.0/shellcheck -S warning bin/harness-init.sh bin/harness-status.sh init.sh scripts/*.sh templates/full/scripts/*.sh tests/run-tests.sh packs/load-testing/verify-pack.sh packs/load-testing/repo-template/bin/perf-resolve-target`; `lint-final-06.*` | Exit0, no warnings |
| Syntax/config | `bash -n` over changed shell files; PyYAML6.0.3 loads both workflows; `static-final-06.json` | All exit0 |
| Diff formatting | `git diff --check`; `diff-check-final-06.*` | Exit0 |

After concurrency, bounded hook portability, protected Python imports and incomplete remote-detail corrections were verified by their causal RED, final focused suite, final core and pinned static checks. Load infrastructure itself did not change, so those concurrent load results retain their exact original source identity and were not redundantly rerun. This is kit contention evidence; the historical Aurobalance timeout is not claimed reproduced without its original fixture.

A write_stdin poll after concurrency returned transport text about an earlier cancelled network approval. All four runs had already completed and persisted exit0, complete logs and the unchanged-source manifest; read-only inspection confirmed them. No network approval was retried or used to reinterpret a test outcome.

## Compatibility and remaining concerns

1. **Protected-policy bootstrap is intentionally not auto-approved.** An old base lacking the new judge/profile interfaces stops ADOPTION_REQUIRED. An owner must adopt the independently reviewed H01/H02 policy artifacts onto protected base through an already authorized maintenance path while preserving required rules, then rerun the PR against that base. If no such path exists, an explicit owner-controlled policy action is required. Merging a failed required check or silently using head policy is not a bootstrap. No such owner action was performed here.
2. Full mechanical verification explicitly supports Bash3.2+ and Python3.8+ with PyYAML6.0.3. Tests here ran the observed Python3.12/Node24.19/k6v2.1.0 host; no claim of executing a separate Bash3.2/Python3.8 runtime is made. The setup helper installs only into an isolated repository venv; current verification used the already available exact pinned parser, not an ambient package mutation.
3. Local RED receipts and ruleset inspection have stated limits. Receipts cannot authenticate a malicious same-UID author; configuration inspection is not an adversarial merge canary. The local hook is not a malicious-formatter sandbox. Staged symlinks require manual handling. Working-tree bytes deliberately remain unchanged after staged formatting.
4. Minimal remains a limited contract scaffold, not full mechanical readiness. Existing consumers must deliberately migrate profiles/parser/receipts; no consumer is silently upgraded. Version-sync remains kit-only.
5. F09's original blocked contract/receipts and all archived review artifacts are unchanged. H04/H06 still own verified recovery. H02 adds no recovery grant and accepts no baseline or product deployment.
6. Independent review, controller full `make check`/feature layers, GitHub required execution, staging and commit remain controller work after this freeze. These local results do not claim remote CI success.

## Exact final source/test hashes and changed files

`final-source-06.sha256` is the complete59-file owned source/current-doc manifest. SHA256 of that manifest: `ca075fd908404fa097405cd9c5a8f2597a71202b985ef2017892fb3f5eaa4621`.

- Final H02 tests: `c3e558b5131dfcdc48b07e2f2dd4c32d97bdbf87000082dc513ce7f926527c89`.
- Final core tests: `bdd265416564568eed513eeb95dcaec9242df74dca38b7da2f1d84200d2728f6`.
- Controller-owned state files are excluded from this freeze; all H02 evidence is covered by `final-evidence-06.sha256`. The immutable controller-owned `preflight/` subtree was never edited.

```text
93e757805a439e1917995e543ba8a8de61f044d4337cd87e7960e225bd6a1870  .agents/notes/implemented/process/2026-09-06-live-gates-and-isolated-evidence.md
1b7cc1634a43d5b7d2a3232cb39fd2e2882d8dc391430af869fa1da0fb04fc73  .github/workflows/required-quality.yml
3173c031c8095a5d9215aefc9a5aac177a479a8765431f5bd71cff097944af87  .gitignore
52b85877304f7693b848701c7e337820201e1bb8389280bafd49a43cd3843e04  .harness/context-routes.json
7e0725363d36238c115f3a019d26ddec2dd61c617d6609db800df18c45dc7b2a  .harness/installation-profile.json
c370c0beee8d258b41e418b3bf6601b81d941b6d65a8e83d3f6055f8eeb4d175  .harness/judge-contract.json
8b5621440f2aee8d5798d846aa1f55a7f3806e3098f8bc906ef6c89ff798fad5  .harness/oracles/AC-H01-fail-closed-verifiers.yaml
0c070391d1714466424b41fdf5872ad722ddbfd84366fde89a425bad377964cc  .harness/oracles/AC-H02.yaml
8f2233fdbae9bcde22bbc49096b29248ba849fc6c2d89b02bd42c5704858c1e8  .harness/oracles/README.md
7a40d184dfc21dd487d08b987608c30aca3db3031d949f0d16617f0385c0b3cc  AGENTS.md
80c500bb3e411ff931a913f35c1fc0afb7d8d42b3a348ea2475fb2f9c4c10551  Makefile
6bcafa5539b8afb67b9baa9d9c0e729cfc7b5c88cd5d2a5aa6ea3bd033e3da1d  README.md
a9a0086c2715c79731355184d7a9bf6c14263d655674a0a81ffe500733c866d1  bin/ARCHITECTURE.md
f4dedd5d2898014c3550361117531c9dde8358e89dbd30c2a2586b5b5f4255ec  bin/harness-init.sh
5dbf7a8aee03b305722f3d6b0343a05c79d23c8d08f0fd022f72a450d092eb53  bin/harness-status.sh
77a71a0c83fd669a6b1bc7178514870496382943c9b09c070264b86233a4e594  docs/harness-capabilities.md
29e26495519bca91a7f9ac9296673cb7738a9bef8547a624a72f91fe55bc8f5e  docs/quality-document.md
ea07e0b0456b46959e9315ffea117718b49fec3fb2be9de7d3a566175973b150  init.sh
2f469f2672b6f22dffd98422eeebdb0dec98de75fc3a05be23c22287a7f20383  packs/load-testing/repo-template/bin/perf-resolve-target
1b907d01c222ed63a97a4a27a6f3562d264cf509b8f7c2832356af9087a581ce  packs/load-testing/verify-pack.sh
0969da99a0bc2a1b71ed50584560f4588a37567ac63af3ddbaf3c4617ca5621a  requirements-harness.txt
92fafa1027f9f5986f48fb03289ad5de62c9f5993c06bf6534d67b63e1b69d35  scripts/check-arch.sh
3990a03b0da1299e08120b3618bbbb2bde5312a01a6991c52eb6e70727dc97a4  scripts/check-prerequisites.sh
5a954d6b5bf259b1fc4c57296b8c012f64ca465443ac6f32444d371ee4bda116  scripts/pre-commit-staged.sh
3d14d653fb87791164b5731c76aae1f61f13c5cc7a59da1830c079194b3d6cf5  scripts/run-gates.sh
5603a52bd11b3c43f51ef4cbe4a6e581b060162d7c1052f79c1c058a280b4288  scripts/setup-oracles.sh
6fcd57c93b6d13de76b18785df99462e6dad71f6e6051ea789fa36c8a6776bac  scripts/verify-agent-notes.sh
f6d79ef008b0fdd330aba8591db66e7c366d47bffcd9146711ff48587b49fd31  scripts/verify-claims.sh
149e3949babc781f380cc11b5431e18a8908accb4ca15ffefc70e6ce4ff6db21  scripts/verify-context-routes.sh
5db9c688d8c18dda30f3bcd5b3c01cc5691abbdebcc749694a95706357bb589d  scripts/verify-decisions.sh
51d5fc9219670f824507534674f2d60c8014143bea49fa492bb681e117c2eb8d  scripts/verify-delivery-doc.sh
f8f0fea40f400e909dd8bd77eca0d0e0666bebf86afe4b3794e83e375b3c5e8e  scripts/verify-feature.sh
bc21976e8419401a8c31311bfa8c5cb600103bcf42a37ca4b7549751a598412a  scripts/verify-makefile-gates.sh
3c9f15bdf0de9bbce668f2e4a68d757b1aa02f65b8ae007d83c1a76ee720eef2  scripts/verify-oracles.sh
25f90255eddbd7726ade57d467633f2fdcc3802d177ab0fd5d408caf9f423ca7  scripts/verify-version-sync.sh
36262ef680e3ed336a504b06b1a3fd7091ed542a68ddb7ef793a80d9a15fdcf0  templates/full/.github/workflows/required-quality.yml
63b0d8d901aae71e3c7b6d4f52c8b41f35326867451cd0df89da0d8fe7324b20  templates/full/.harness/context-routes.json
088412b7836da1e9a9806ed361ec0a8accde2ea4c3a056d7fd35b324d94b4612  templates/full/.harness/installation-profile.json
c370c0beee8d258b41e418b3bf6601b81d941b6d65a8e83d3f6055f8eeb4d175  templates/full/.harness/judge-contract.json
8f2233fdbae9bcde22bbc49096b29248ba849fc6c2d89b02bd42c5704858c1e8  templates/full/.harness/oracles/README.md
def68ef60b8a0e0809acd5fe8726f47202577c681ef44ed80474ddba85438151  templates/full/AGENTS-appendix.md
691730bb9f9f71e69dbb729c1c165a82619aa538771f898c3ecf1b4afe3a5dba  templates/full/Makefile
24e8ca2380c3d8607ea08dd6fb2c0305a7b0e329f24138f32f5e567e88c5a8c9  templates/full/docs/quality-document.md
0969da99a0bc2a1b71ed50584560f4588a37567ac63af3ddbaf3c4617ca5621a  templates/full/requirements-harness.txt
92fafa1027f9f5986f48fb03289ad5de62c9f5993c06bf6534d67b63e1b69d35  templates/full/scripts/check-arch.sh
5a954d6b5bf259b1fc4c57296b8c012f64ca465443ac6f32444d371ee4bda116  templates/full/scripts/pre-commit-staged.sh
3d14d653fb87791164b5731c76aae1f61f13c5cc7a59da1830c079194b3d6cf5  templates/full/scripts/run-gates.sh
5603a52bd11b3c43f51ef4cbe4a6e581b060162d7c1052f79c1c058a280b4288  templates/full/scripts/setup-oracles.sh
6fcd57c93b6d13de76b18785df99462e6dad71f6e6051ea789fa36c8a6776bac  templates/full/scripts/verify-agent-notes.sh
f6d79ef008b0fdd330aba8591db66e7c366d47bffcd9146711ff48587b49fd31  templates/full/scripts/verify-claims.sh
149e3949babc781f380cc11b5431e18a8908accb4ca15ffefc70e6ce4ff6db21  templates/full/scripts/verify-context-routes.sh
5db9c688d8c18dda30f3bcd5b3c01cc5691abbdebcc749694a95706357bb589d  templates/full/scripts/verify-decisions.sh
51d5fc9219670f824507534674f2d60c8014143bea49fa492bb681e117c2eb8d  templates/full/scripts/verify-delivery-doc.sh
f8f0fea40f400e909dd8bd77eca0d0e0666bebf86afe4b3794e83e375b3c5e8e  templates/full/scripts/verify-feature.sh
bc21976e8419401a8c31311bfa8c5cb600103bcf42a37ca4b7549751a598412a  templates/full/scripts/verify-makefile-gates.sh
3c9f15bdf0de9bbce668f2e4a68d757b1aa02f65b8ae007d83c1a76ee720eef2  templates/full/scripts/verify-oracles.sh
1ce07131c17622506116afce58090a01f5eca53db2fda91f232536ff3c46ce0c  templates/minimal/installation-profile.json
c3e558b5131dfcdc48b07e2f2dd4c32d97bdbf87000082dc513ce7f926527c89  tests/h02-hardening-regressions.py
bdd265416564568eed513eeb95dcaec9242df74dca38b7da2f1d84200d2728f6  tests/run-tests.sh
```

Freeze: code, tests, current documents, oracle receipts and this report are final for review. Any further source/test change requires reopening the report and new uniquely named evidence; no unrecorded post-DONE edits.


---

# H02 fix round1 — independent review M1–M3

Status: **DONE_WITH_CONCERNS / FROZEN**, superseding the initial source/report freeze after the controller explicitly reopened this task. Independent review1 reported0 Critical,0 High,3 Medium; all three bounded findings are implemented and locally verified. Re-review and controller full integration remain outstanding. The initial report's exact bytes are preserved in `fix-1/pre-fix/.superpowers/sdd/migration-plan/task-2-report.md`; every old receipt, sealed evidence file and review1 artifact is unchanged.

## Corrections and scope

- **M1, isolated setup:** both venv `pip install` and final PyYAML import/version verification now use Python `-I`, in root and mirror. Four adversarial subcases cover cwd and PYTHONPATH injection separately for pip and final import. Fixtures prohibit package indexes, disable pip configuration and use empty local wheel/cache paths; empty requirements reach the final-import case. Each fixture independently confirms the venv has no real parser, so a reported setup success would be false. No package download occurred.
- **M2, timeout ownership:** status starts its `make check` in a new session/process group. Timeout sends TERM to that group, waits at most0.2s, then sends KILL even when the make parent already exited or descendants closed pipes. Communication/reaping has bounded0.2s steps; an escaped descendant's pipes cannot force an unbounded wait. The direct verifier is reaped. Real recipe children, both normal and TERM-ignoring, cannot write their delayed mutation marker; an unrelated process survives and writes its own marker. This is ordinary owned-descendant cleanup, not malicious same-UID containment or a general process supervisor.
- **M3, explicit delivery source:** missing/non-file/unreadable paths block when a nonempty DELIVERY_DOC is configured, regardless of DELIVERY_DOC_REQUIRED. An absent default scaffold runbook remains permitted. Root/template parity is verified; the regression covers both an explicit missing file and an explicit directory source.

Only the three shipping source files, their two mirrors, the focal tests, current H02 oracle, Agent Note and capability document changed in this round. No index/ref/state/ledger/DECISIONS changes, agents, commits, external account calls, baseline acceptance or deployment occurred. No core/load/concurrency suites were rerun, as directed; their earlier scoped evidence remains immutable.

## Reconstructible RED and final GREEN

All following paths are relative to `docs/implementation/2026-09-05-harness-hardening/h02/fix-1/`.

| Evidence | Command / meaning | Result |
|---|---|---|
| `pre-fix/`, `pre-fix-manifest.json` | Exact three source files, mirrors, original tests/oracle/docs/report saved before edits | Byte snapshots retained |
| `baseline-overlay/`, `baseline-overlay-manifest.json` | Export published fff527b, then apply this59-file overlay | Reconstructs all initially sealed H02 source/current-doc bytes; every hash checked against the initial seal |
| `red-01.*`, `red-01-tests.py` | Final regression bytes selecting the3 new tests, before source corrections |3 tests,8 causal failed subtests,0 errors; exit1 |
| `red-full-02.*`, `red-full-02-tests.py`, `red-full-02-context.json` | Final30-test file with H02_KIT pointed at reconstructed initial H02 |30 tests,8 causal failed subtests,0 errors; exit1 |
| `green-focused-01.*` | Same3 selected tests against corrected source |3/3, exit0 |
| `green-full-02.*` | `python3 tests/h02-hardening-regressions.py` against corrected source |**30/30**, exit0 |
| `lint-02.*` | Pinned ShellCheck0.11.0 `-S warning` over the5 changed shell files | Exit0, no warnings |
| `syntax-parity-02.json` | `bash -n` over the5 changed shell files; root/mirror byte comparison | All zero; both mirrors equal |
| `oracles-02.*` | `bash scripts/verify-oracles.sh` with current oracle and v2 receipt | Exit0; AC-H01 and AC-H02 consistent |
| `diff-check-02.*` | `git diff --check` | Exit0 |

Exact selected test IDs are `Regressions.test_setup_ignores_cwd_and_pythonpath_for_pip_and_final_import`, `Regressions.test_status_timeout_terminates_owned_descendants_only`, and `Regressions.test_explicit_missing_delivery_source_blocks_with_default_absence_allowed`. Full subprocess stdout/stderr/exits and argv are in the corresponding `*-commands.json`; test source records the bounded/offline environment. The new RED receipt `h02-red-receipt-v2.json` binds the actual final30-test bytes, preserved defective source/mirrors and full RED logs/context. `.harness/oracles/AC-H02.yaml` points to this new receipt. The old receipt was never overwritten. Its history anchor stays fff527b; the defective source is explicitly identified as the preserved initial-H02 overlay/review tree, not falsely labeled published H01.

## Final hashes and seal

Current full59-file source/current-doc manifest: `final-source-02.sha256`, SHA256 `1c3217b2abcc991bc2c5b4e814dedeaf075cbb3325c069afc3591b73c0ec0306`. Final30-test SHA256: `17d9dad3160a9271277cfbbe6ec271c40a7c5efc35aad2daf478c03fed5e8815`. The following9 files changed from the initial source freeze:

```text
124a86c483065bc9ae2988b06eb465e495cd5db85d71a9629ed80e0ecc3e52fa  .agents/notes/implemented/process/2026-09-06-live-gates-and-isolated-evidence.md
aaf8e6fe2dcac7602272721ed36d2e415fe0b1f91eb80a55372e14997cea3eb8  .harness/oracles/AC-H02.yaml
ab3cb668202e0f5933596e39a97a98d2fa6519d0d652541fe4df47abb9a729ff  bin/harness-status.sh
d2d1e550c4c0eaf3b98df06d7630d1ec9d74cedac6e431d10f5d42aae4b7138f  docs/harness-capabilities.md
d5ebb1d1fe299a6927492f4c47a5c4b8ed373bb50e92439aa47c80469703b138  scripts/setup-oracles.sh
de1cdf4e2594b43ea1787e2ef246a8624f8465324fcde3cef6353e96e13234e3  scripts/verify-delivery-doc.sh
d5ebb1d1fe299a6927492f4c47a5c4b8ed373bb50e92439aa47c80469703b138  templates/full/scripts/setup-oracles.sh
de1cdf4e2594b43ea1787e2ef246a8624f8465324fcde3cef6353e96e13234e3  templates/full/scripts/verify-delivery-doc.sh
17d9dad3160a9271277cfbbe6ec271c40a7c5efc35aad2daf478c03fed5e8815  tests/h02-hardening-regressions.py

```

`final-evidence-02.sha256` covers this round's complete append-only evidence; `freeze-02.json` binds that manifest, the current source manifest, this report and final tests. A complete copy of this appended report is preserved as `fix-1/implementer-report.md`.

No additional known local blocker remains from M1–M3. The previously stated concerns remain: protected-policy adoption requires the owner-controlled path; remote required-quality success, authenticated load coverage, Bash3.2/Python3.8 runtime execution and controller full integration are not claimed. Current host/pinned dependency and ordinary process ownership limits are unchanged. Source, tests, current oracle/docs and this appended report are now **FROZEN**; any further change requires explicit reopening and new evidence.
