# Final-fix-1 implementer report — FROZEN

Completed the assigned bounded local correction. FR-01 now uses `Object.create(null)` for the filesystem inventory; that is the only capabilities.mjs change. The existing workflow prerequisite omission is corrected with two setup steps. No broader review was repeated. No staging, commits, refs, remote changes, permissions changes, baseline acceptance, optional mutation campaign or subagents were used. Root retains state/index/publication and actual final feature/full/startup gates.

## FR-01 and causal RED

Before editing the runtime, created the new `packs/autonomy/repo-template/scripts/quality-orchestrator/tests/literal-filename.test.mjs` and `.harness/oracles/AC-FR01-literal-filename.yaml`. The regression uses only disposable local fixtures, the existing signing helper, and public preparation/lease/execution APIs. It compares a denied frozen root `frozen.txt` with a literal `__proto__` after preparation. Both must reject with `POLICY` / `prepared binding changed`, zero budget spend, unchanged output bytes, no pending operation, and no effect intent/receipt. It also checks the externally changed frozen bytes are retained.

Actual unchanged-source RED command:

```bash
node --test --test-reporter=tap packs/autonomy/repo-template/scripts/quality-orchestrator/tests/literal-filename.test.mjs
```

Observed **exit 1, one pass / one assertion failure**. The ordinary control passed. The literal filename failed with `ERR_ASSERTION`: `EFFECT_VERIFIED`, canonical output mutation, effect intent/receipt and spend 1. This is causal RED; the earlier exit-zero diagnostic probe is not counted. The test was not edited after witnessing RED. Its exact bytes are additionally retained in `literal-filename.red.test.mjs`.

| RED binding | SHA-256 |
|---|---|
| Before capabilities.mjs | `0084e0f78e233c7dbd4ff751afe07faf839f62f475831d46fb35908960d3c6a6` |
| Current unchanged regression | `1db50a3c4fd5af7d6a238ac12757af61e686fe04488756702b2191692dc0953d` |
| RED stdout | `fa70b3ab776f1f5fd35c0268add3c25d241553f501ad8570cc92bd25ef21cd16` |
| RED stderr (empty) | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| RED receipt | `f796821c46f7c007eb8eeb89e5b1bf4c397e68717c6777537565849e44a527c2` |
| Fixed capabilities.mjs | `12730d65dcfd2c93742c9b1417bfc9147dd769549ac02ddb31472e88a688d61a` |

Before source is under `docs/implementation/2026-09-05-harness-hardening/final-fix-1/before/packs/autonomy/repo-template/scripts/quality-orchestrator/capabilities.mjs`. Unchanged support files remain identified by the historical H09 source manifest and existing HEAD `65c0c6976520ca53b878224e081d042a62853db4`; there is no duplicate runtime snapshot. The repository oracle gate validates the current receipt as TEST_READY.

## Existing build prerequisite

Confirmed: `.github/workflows/required-quality.yml` invoked `make check` without installing the nested runtime, while `packs/autonomy/verify-pack.sh` requires Node >=22 and exact yaml 2.9.0 / zod 4.5.4. The canary performs offline npm ci in a fresh consumer and relies on the existing npm cache.

Added only (1) official `actions/setup-node@820762786026740c76f36085b0efc47a31fe5020` (v7.0.0), `node-version: '22'`, `package-manager-cache: false`, and (2) `npm ci --prefix packs/autonomy/repo-template/scripts/quality-orchestrator --ignore-scripts --no-audit --no-fund`, working-directory `head`. These sit after the protected gate and before the existing pipeline. npm ci installs the unchanged locked dependencies and warms the default cache used by the offline canary; no cross-run cache configuration or dependency framework is added.

Official documentation consulted: [setup-node at the pinned commit](https://github.com/actions/setup-node/tree/820762786026740c76f36085b0efc47a31fe5020), [v7.0.0 release](https://github.com/actions/setup-node/releases/tag/v7.0.0). Static validation parses both workflow versions, removes only these two new steps, and asserts the entire remainder equals the preserved before workflow. Thus all existing gate bodies, judge identities, permissions and fail-closed sentinels remain unchanged.

**Static workflow/prerequisite validation is not actual CI execution.** No GitHub action or clean GitHub runner was executed here. Local tests ran Node v24.19.0 / npm 11.9.0; CI selects supported Node 22. The existing local canary passed its fresh-consumer offline install with the existing default cache. Actual remote CI acceptance remains pending, and protected-policy ADOPTION_REQUIRED remains unresolved.

## Exact verification commands and results

All commands ran from `/workspace/scratch/adce1c53b293/harness-kit`. After the first prerequisite diagnostic, the existing controller environment was used:

```bash
export PATH=/workspace/scratch/adce1c53b293/tooling/k6-v2.1.0-linux-amd64:/workspace/scratch/adce1c53b293/tooling/shellcheck/shellcheck-v0.11.0:$PATH
export NO_COLOR=1 PYTHONDONTWRITEBYTECODE=1 K6_NO_USAGE_REPORT=true
```

Each named run has exact `.command.json`, `.stdout.log`, `.stderr.log`, `.exit` and `.result.json` under final-fix-1. Result JSON records elapsed time and stdout/stderr hashes. The initial RED additionally has `red-command.json` / `red-receipt.json`.

- **static-before-runtime**: exit 2, 0.005 s. `bash -c 'make lint && bash docs/implementation/2026-09-05-harness-hardening/h05/verify-static.sh && node --check packs/autonomy/repo-template/scripts/quality-orchestrator/tests/literal-filename.test.mjs && node --check packs/autonomy/tests/installation.test.mjs && node --check packs/autonomy/tests/canary.test.mjs'`
- **static-ready**: exit 0, 3.975 s. `bash -c 'make lint && bash docs/implementation/2026-09-05-harness-hardening/final-fix-1/verify-static.sh'`
- **oracle-static**: exit 0, 0.108 s. `bash scripts/verify-oracles.sh`
- **f19-runtime**: exit 0, 24.496 s. `node --test --test-reporter=tap --test-skip-pattern=e2e: packs/autonomy/repo-template/scripts/quality-orchestrator/tests/capabilities.test.mjs packs/autonomy/repo-template/scripts/quality-orchestrator/tests/literal-filename.test.mjs`
- **f23-runtime**: exit 0, 1.21 s. `node --test --test-reporter=tap packs/autonomy/tests/installation.test.mjs`
- **f19-e2e**: exit 0, 6.999 s. `node --test --test-reporter=tap '--test-name-pattern=^e2e:' packs/autonomy/repo-template/scripts/quality-orchestrator/tests/capabilities.test.mjs`
- **f23-e2e**: exit 0, 7.333 s. `node --test --test-reporter=tap packs/autonomy/tests/canary.test.mjs`
- **final-consistency**: exit 0, 4.028 s. `bash -c 'make lint && shellcheck -S warning docs/implementation/2026-09-05-harness-hardening/final-fix-1/verify-static.sh && bash docs/implementation/2026-09-05-harness-hardening/final-fix-1/verify-static.sh && git diff --check'`

The first static attempt stopped at missing shellcheck in this subagent PATH (make exit 2 / tool exit 127); no runtime advanced before static passed. The exact failure remains preserved. Restoring the controller tool PATH was the sole environment correction. `static-ready` validated the current selected sources, receipt and initial pre-runtime candidate; after runtime/e2e evidence was added, `final-consistency` revalidated the final manifests and candidate, plus lint, the new verifier shellcheck and diff whitespace.

Runtime/e2e results: **F19 runtime 32/0 (30 old + 2 new), F19 e2e 3/0, F23 installation 4/0, F23 local canary 1/0**. Both runtime commands completed before the two independent e2e commands. No root `make check`, feature gate or startup gate ran here.

## Current evidence and candidate

| Artifact | SHA-256 |
|---|---|
| `docs/implementation/2026-09-05-harness-hardening/final-fix-1/source-manifest.json` | `939b55a47eaa66fef6368b09aa1f2b7d4943203207b2ebd4692dd3f1416dbe3a` |
| `docs/implementation/2026-09-05-harness-hardening/final-fix-1/evidence-manifest.json` | `7138970a0405bea2c780dd7bed6d2c529d8043f7470809c4e9bde6488a7a6a44` |
| `docs/implementation/2026-09-05-harness-hardening/final-fix-1/baseline-candidate.json` | `d6a38414da35b66831454a2440cb5ae2ad18d5d1a26ca26f7e1e97adfecd573d` |

Candidate subject SHA-256: `a499dcbdcb5fb194e7c203d008081ba72912fbcb2ff6ba77af529ec6dcabd151`. It is explicitly **UNSIGNED / CANDIDATE_NOT_ACCEPTED** with null owner acceptance/signature; publication commit is supplied separately by the coordinator. No self-reference or guessed final commit is present. The 49-file current source manifest covers selected current installer/runtime/tests/adoption assets plus this workflow/oracle correction. The evidence manifest binds 52 evidence/reference files. Final consistency logs are deliberately outside that candidate manifest and have their own result hashes.

Original H01–H09 tests, receipts, raw logs, source snapshots, manifests and candidate files were preserved. A before/after local hash comparison covered 3,362 pre-existing H01–H09 files plus packs tests and oracles and found zero changed paths (`preservation.result.json`). The historical H09 manifest/candidate themselves remain byte-identical; changed current adoption-doc before bytes are retained under final-fix-1/before/. Current adoption docs point to the new candidate; the old H09 static verification remains historical. New Agent Note: `.agents/notes/implemented/bug-fix/2026-09-06-literal-filename-inventory.md`, citing AGENTS.md, DECISIONS.md, bin/ARCHITECTURE.md and docs/quality-document.md.

## Proposed current F19/F23 layers for root

F19 static:
```bash
make lint && bash docs/implementation/2026-09-05-harness-hardening/final-fix-1/verify-static.sh
```
F19 runtime:
```bash
node --test --test-reporter=tap --test-skip-pattern='e2e:' packs/autonomy/repo-template/scripts/quality-orchestrator/tests/capabilities.test.mjs packs/autonomy/repo-template/scripts/quality-orchestrator/tests/literal-filename.test.mjs
```
F19 e2e:
```bash
node --test --test-reporter=tap --test-name-pattern='^e2e:' packs/autonomy/repo-template/scripts/quality-orchestrator/tests/capabilities.test.mjs
```
F23 static:
```bash
make lint && bash docs/implementation/2026-09-05-harness-hardening/final-fix-1/verify-static.sh
```
F23 runtime (unchanged):
```bash
node --test --test-reporter=tap packs/autonomy/tests/installation.test.mjs
```
F23 e2e (unchanged):
```bash
node --test --test-reporter=tap packs/autonomy/tests/canary.test.mjs
```

Root owns updating F19/F23 layers and state through the required feature gate, append-only state/ledger/decisions, final full check/startup and any publication. `packs/autonomy/verify-pack.sh` already includes the new test through its existing glob. Expected integrated assertion count increases by two relative to prior 638, but no new full-gate pass is claimed by this report.

## Remaining limits and freeze

The interrupted whole-branch review remains **INCOMPLETE**; this task did not resume it or establish broad code-quality approval. Only the concrete correction and prerequisite path were addressed. Positive live review/release backends remain UNIMPLEMENTED, original real-flow/production acceptance NOT_EXECUTED, and remote required CI remains blocked by protected-policy adoption. No owner key, baseline acceptance, production authority or measured human-friction savings follows from these local fixtures.

**FROZEN.** All selected source and evidence writes are complete. Root can run the bounded corrective review and required final gates against the new manifest/candidate.
