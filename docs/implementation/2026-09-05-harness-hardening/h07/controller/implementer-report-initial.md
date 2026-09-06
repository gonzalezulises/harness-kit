# H07 implementer report — FROZEN

Base: `19851a295fdac9159dad8161f4fd1dbd446c308a` (H06 tree
`2bd8f826d14152f336abbe2443366336333c6f33`). Worktree-only changes; no index,
commit, ref, root state/ledger/DECISIONS or previous H01–H06 evidence edits.

Status: portable contract preparation, exact trusted shadow construction and
safe refusal implemented. **Live reviewer implementation/acceptance remains
NOT_EXECUTED.** No real authenticated Codex catalog/session, reviewer process,
counterexample process, new sandbox or alternate authenticated route was run.
The optional host review field cannot enable a real backend by flag or callback.

## API and shipping scope

Three new package-root modules: `review.mjs`, `review-shadow.mjs`,
`review.schema.mjs`; two-line runtime integration and schema exports in `index.mjs`.
No dependencies, marketplace, service or generic runner. Full contract:
`packs/autonomy/repo-template/scripts/quality-orchestrator/contracts-review-v1.md`.

- `describeReviewPolicy(input)` computes a closed signed subject/scope.
- `preflightReview({policy,approval})` reuses the Ed25519 verifier, pins actual
  artifacts/bundle/config/schema and returns a private frozen binding.
- `inspectReviewBinding(binding)` rechecks all pins and approval freshness.
- `createReviewShadow(binding)` constructs the exact target commit/tree/blobs;
  `inspectReviewShadow(shadow)` recomputes primary/shadow manifests.
- `describeReviewRound(binding,shadow)` supplies fixed data-only protocol fields,
  including repeated model/effort/cwd/approval settings, without launch authority.
- `reviewRun(binding,shadow)` rechecks bindings/manifests and returns
  `BLOCKED_BY_REQUIRED_CAPABILITY`, NOT_EXECUTED execution/acceptance and null
  raw output, execution receipt and budget receipt.
- `validateReview({output,receipt},binding)` performs strict local Zod parsing,
  duplicate-key checks, exact finding-location checks and receipt-binding checks.
  Locally valid output has `independentReviewVerified:false`; matching fabricated
  receipts return `BLOCKED_BY_MISSING_AUTHORITY_BINDING`.

The approved operator model/effort order controls selection; fixture catalog
order does not rank quality. Wrong auth, partial/cancelled observations and
unavailable approved choices block. Missing remote schema changes only transport;
local validation, authentication, model/effort and unavailable containment remain
pinned. Installed 0.153.4 protocol shapes were read locally, with no network call.

Trusted Git plumbing uses pinned `/usr/bin/git` in fixtures (production path is
operator supplied and hash checked). Its allowlisted environment disables global
and system configuration, credential/proxy inheritance, lazy fetch, replace refs
and network protocols. The source is only a verified plain object directory;
its repository config is not Git configuration for these commands. Fixed
`init`, `cat-file` and `rev-parse` operations preserve raw Git object identities,
file bytes and modes without checkout/hooks/filters. Links, submodules, alternates,
unsafe names, dirty target files and changed primary/shadow manifests block.

Per root's concrete ordering ruling, missing availability stops **before** budget
spending. This build cannot start a real attempt and therefore does not call
`spendBudget`. A future supported launch must reserve via that existing API
immediately before the actual start and retain reservation on unsuccessful
execution. No hypothetical backend or unreachable simulated spending path added.

## Executed verification

All commands ran from repository root; logs/exits are under
`docs/implementation/2026-09-05-harness-hardening/h07/`.

| Layer/evidence | Exact command | Observed output |
| --- | --- | --- |
| Static | `bash docs/implementation/2026-09-05-harness-hardening/h07/verify-static.sh` | exit 0; six source/test syntax checks plus integration whitespace PASS |
| Runtime | `node --test packs/autonomy/repo-template/scripts/quality-orchestrator/tests/review.test.mjs` | exit 0; 28 tests, 28 pass, 0 fail; 29712.709907 ms |
| Local e2e | `node --test --test-name-pattern='^e2e' packs/autonomy/repo-template/scripts/quality-orchestrator/tests/review.test.mjs` | exit 0; 3 tests, 3 pass, 0 fail; 6340.520971 ms |
| Actual security RED | `node --test --test-name-pattern=prototype-shaped docs/implementation/2026-09-05-harness-hardening/h07/prototype-red-source/tests/review.test.mjs` | exit 1; 1 pass, 1 assertion failure: primary tampering incorrectly returned REVIEW_SHADOW_BUILT |

The actual High defect was found before freeze: an ordinary-object manifest map
omitted a primary filename named `__proto__`. The exact final test bytes witnessed
post-construction tampering being accepted against preserved pre-fix source
**before** shipping maps changed to null-prototype maps. Final runtime exercises
both primary and shadow cases. `AC-H07.yaml` was written before implementation;
`red-receipt.json` binds the current test bytes, defective snapshot and observed
nonzero log. This is local content consistency, not authenticated review evidence.

Other retained development evidence is labeled separately:

- `api-red.log`: initial missing-API TDD failure, not a security-defect witness.
- `runtime-initial.log`: 25/26; the one failure was test setup mutating an
  intentionally frozen policy. The fixture now clones before forging the wire.
- `causal-red.log`: mutation setup failed on an external dependency symlink;
  it proves no security criterion.
- `causal-red-02.log`: deliberate guard/schema mutation experiments on preserved
  earlier 26-test bytes produced four assertion failures. These are **mutation
  experiments, not observed prior shipping defects and not the oracle's current
  security RED receipt**. No further mutation expansion was performed.

Local e2e cases test blocked launch without budget loss, local findings without
acceptance, and rejection of forged execution receipts. They are not independent
production reviews or real-session acceptance of cases 7/8/9. Full `make check`
and independent review remain root-owned and were not rerun by this worker.

## Exact SHA-256 bindings

All source, contract, oracle and Agent Note hashes are in `source-manifest.json`;
all top-level logs/exits and receipt hashes are in `evidence-manifest.json`.
The RED receipt additionally enumerates exact preserved source/test/schema bytes.

| File | SHA-256 |
| --- | --- |
| `review.mjs` | `3a8760b34063769a1daa99082347db408c393e08a447f38d22a3e7e29b8cb6f8` |
| `review.schema.mjs` | `bfdc0bd9cf4551bac6ce43e41691e3f61aaf7c8b9a468a41893f8a38adcc8dfa` |
| `review-shadow.mjs` | `84221bac483c39e517b288b11910a25e33e8c665e5a3d59faba657e97fef71dd` |
| `classify.mjs` | `d484a4e205ef877f0e02845e95cdcb9de842513c2afa0ffc38d4d5c3ff4f5178` |
| `index.mjs` | `0050a86db0a0202d6f7a273c9f0b6631eb183e52d7d2c10b604ad8c90fe5261e` |
| `tests/review.test.mjs` | `bebe2481b6d12d9b5f0c70cd15b3cd96c16183ebb7d493983d1a77a5697fb741` |
| `runtime-final.log` | `ba19fb9c804b48f745201f21038591894766980e46dbd12204e97ad7ef584685` |
| `e2e-final.log` | `da653600452d31347fdabddbb26575d6bea93f74d542adea202c1d9be87194aa` |
| `prototype-red.log` | `a643588aa122029b9f9d6240203dbf3b3a6dd1e4d702207a451d887fe6cfc004` |
| `red-receipt.json` | `f9333e24467ed5eb3b4cc7fd121ce12fa743b7d02fd3112e8ea845a5b0da8934` |
| `source-manifest.json` | `116ee8602c2394f10dbf5b27ca499e933dfdb84bfb0767aecc7a77f95eabb7ad` |
| `evidence-manifest.json` | `67c1010073ba49cc1c2f1e9e252f672d4f16c7b5052b2266682216afb462bbbf` |

## Remaining limitations and H08 handoff

No unresolved High/Critical is known to this implementer after the causal fix;
independent review has not yet run. This is not a claim of defect absence.

There is no production launch, supported containment backend, authenticated live
catalog discovery, authenticated account/session, counterexample reproduction or
host-supervisor receipt-minting implementation. A future supported host still
needs those concrete implementations, actual bounded egress/MCP/filesystem/process
and secret custody, reservation-before-start accounting and a real accepted
session against the frozen artifacts. Transport descriptions and hashes do not
provide these guarantees. The cancelled account preflight was not retried.

Only SHA-1 Git repositories, plain files/directories and bounded object/manifest
sizes are supported. The shadow is shallow at the exact target and has no
inherited index/history. Host registry completeness, trusted runtime custody and
exclusive cooperating writers remain prerequisites; there is no malicious
same-UID containment or filesystem-race guarantee.

**H08 can consume zero H07 outputs as authenticated independent-review evidence.**
Raw JSON, fixture receipts, signed raw model output, local Zod success, shadow
construction and budget records cannot satisfy independent review or certify
release. Existing H06 product-regression limitations are unchanged.

FROZEN. No further worker edits until explicit fix dispatch.
