# PR37 six Medium corrections — implementation record

Status: scoped implementation and verification complete. Root owns final focused re-review, integrated full checks, metadata, and commits; no independent approval or full-repository completion is claimed here.

Workspace: `/workspace/scratch/adce1c53b293/harness-human-interruption`.
HEAD remains `dfd717b934667b1d6153a8934a657a70b8b0c9e1`; the actual baseline includes root's uncommitted PR36/global corrections and prior product fixes. Exact baseline sibling modules are preserved in `docs/implementation/2026-09-07-closure/f27-corrections/red-source/` with `red-source-manifest.json`. This is not a claim that clean HEAD contained those integrated corrections.

## Scoped changes

Production files, relative to `packs/autonomy/repo-template/scripts/quality-orchestrator/`:

- `product.mjs`: M1 signed base HEAD precondition and repeated remediation preflight under custody; M2 exact inventory path-set and modes plus unrelated-byte checks before reservation/writes; M6 exact unresolved proof ownership before any second-rule write, preserving original-intent reconciliation; M3 pending acknowledgement reconciliation before operational checkpoint returns; M4 current settled reviewer outcome ingestion with closed causal retry classification.
- `codex-worker.mjs`: retain only bounded protocol code, source digest, session ID and misalignment-presence boolean for a settled failed product.v2 reviewer. No free-form error message/details are retained and no message substring grants recovery. Matching IDs, unchanged source and clean process termination still apply.
- `product.schema.mjs`: additive `SETTLED_REVIEW_FAILURE` payload with explicit version 1 and a strict version-1 causal record. Existing `TOOL_FAILURE`, including historical `REVIEW_TRANSPORT_REJECTED`, retain their replay semantics. An old unqualified retained acknowledgement, if newly reconciled, establishes no retry authority.
- `release.mjs`: only `runRelease` candidate selection changes. It tries supplied unspent candidates until complete next-request AND budget equality hold, including slice/action/deployment-specific bindings; existing exact signature APIs remain authoritative. Root's `executeReleaseObligation` custody/preflight guard is unchanged.

Only exact `serverOverloaded` and `internalServerError` string codes, with no misalignment indication, qualify for already-authorized bounded retry. Unknown/missing/unsupported structured causes, authorization and safety refusals remain operational diagnosis. Refused attempts retain their original charged start/key in immutable journal history and never generate a new retry reservation. No real refusal is relabeled or retried.

## Tests and causal evidence

New `tests/f27-corrections.test.mjs` and `tests/f27-corrections-fixture.mjs` contain 19 cases: M1/M2/M6, M3 late original ack after a checkpoint with separate Node process reopen through both resume and run, nine M4 diagnostic codes, two separate explicit mechanical controls, reversed two-slice release wires, readback-shaped input before exact fresh deployment, and fresh-deployment input before an exact authorized readback of a known failed original deployment.

Current-byte RED commands (run from workspace):

```
node --test --test-name-pattern='F27 M[1236]' packs/autonomy/repo-template/scripts/quality-orchestrator/tests/f27-corrections.test.mjs
node --test --test-name-pattern='F27 M4' packs/autonomy/repo-template/scripts/quality-orchestrator/tests/f27-corrections.test.mjs
node --test --test-name-pattern='F27 M5' packs/autonomy/repo-template/scripts/quality-orchestrator/tests/f27-corrections.test.mjs
```

Results: 5 fail/0 pass, 9 fail/2 positive-control pass, 3 fail/0 pass; every command exit 1. All 17 current failures are reviewed-control-flow assertion failures. Source hashes remained equal to the preserved baseline. `red-receipt.json` binds commands, current test/helper bytes and logs. GREEN uses these exact same test/helper bytes and command groups.

New test SHA-256: `a1d87fbaea4deba6ca215432047ba2a6d937a9916e1d90e054564ac485d84685`.
New fixture SHA-256: `c67d830dda497b47ae54bad1fd2dca70a070b324e551cb22e72834fc6e784aa9`.

Initial test construction failures are retained separately: duplicate local input name (syntax), and M3 child authority JSON encoding (canonical JSON was required). The first full RED run had 19 cases, 17 failures and two controls, but its M3 failures were setup errors and are NOT causal proof. M2 was also strengthened to apply its post-deletion description, proving unwanted effects rather than only erroneous description admission. Corrected current bytes were then re-witnessed in all three groups before primary production edits. `initial-tests.mjs`, `red.log`, and setup/context logs preserve this history.

## Authorized correction to current A03 contract

The original A03 emits only an unqualified string about a credential-shaped infrastructure ID. Its payload is unchanged. The current test expectation is corrected to require `OPERATIONAL_DIAGNOSIS`, no reviewer judgment, no ingest, one charged reviewer attempt and no retry. It is not relabeled as server overload. Separate new fixtures emit the actual explicit supported transient codes for positive bounded retry.

Prior exact `human-interruption.test.mjs`, `AC-HUMAN-INTERRUPTION.yaml`, and publication-recovery `red-receipt.json` are copied under `preserved-history/`, with original paths/hashes in its manifest. Original historical receipts are untouched. This changes the current fixture contract and does NOT assert unchanged A03 compatibility.

Current human-interruption test SHA-256: `8573cf58825e60da5b85abb017b7283e533f73f24ebdf303e49c8545fe58b8e3`.

Affected current critical oracle is freshly witnessed against these current unchanged test bytes:

```
node --import ./docs/implementation/2026-09-07-closure/f27-corrections/current-durable-ingest-mutation.mjs --test --test-name-pattern=A06 packs/autonomy/repo-template/scripts/quality-orchestrator/tests/human-interruption.test.mjs
```

Result: one causal assertion failure, exit 1, because replacing durable reads with ephemeral reconstruction falsely returns `PRODUCT_REPLAYED` after object loss. `current-oracle-red-receipt.json` binds the current test, exact first-correction source snapshot, checked mutation hook, mutation patch and log. This first-correction re-witness is preserved. The final-source re-witness below supersedes its use for current source without changing historical evidence. Root owns the live oracle pointer/wording and contract metadata update.

## Independent review correction: late reviewer retry intersection

The independent first-correction review (`closure-review/f27-fixes-review.md`) accepted M1/M2/M5/M6 and causal classification/history separation, but found F27-R1 Medium: a late supported reviewer failure or completed malformed output settled its original key while retaining the operational stage forever. First-correction source and every receipt are preserved. In particular the full affected legacy command below passed **104/104**, exit 0, in 503.749s on unchanged first-correction source; it is not misrepresented as a run of later source:

```
node --test packs/autonomy/repo-template/scripts/quality-orchestrator/tests/human-interruption.test.mjs packs/autonomy/repo-template/scripts/quality-orchestrator/tests/product-loop.test.mjs packs/autonomy/repo-template/scripts/quality-orchestrator/tests/review.test.mjs packs/autonomy/repo-template/scripts/quality-orchestrator/tests/release.test.mjs
```

`first-correction-legacy-receipt.json` binds its full command, test/source hashes and log. First-correction new GREEN was 19/19 (5 core, 11 classification, 3 release), each group exit 0. Four module syntax checks and scoped `git diff --check` also exited 0.

The final correction adds only `REVIEW_CHECKPOINT_RECOVERY` with explicit version 1 in product.schema.mjs and its product.mjs reduction/publication logic. It applies exclusively to the original `UNCERTAIN_EFFECT_REQUIRES_ORIGINAL_OBSERVATION` checkpoint with a still-owned FULL/FOCAL intent, exact retained acknowledgement digest/kind/binding, and either a supported settled transient cause or completed malformed review output. It checks prospective retry/fingerprint limits and remaining original signed starts/journal total. It keeps the original pending intent and restores the stage derived from that authoritative intent kind. It charges nothing. Existing historical `TOOL_FAILURE` reduction is unchanged; the explicit new transition restores the appropriate context before newly publishing the old-shaped malformed-output outcome. Unknown/refused/exhausted outcomes receive no recovery transition.

Pending resume now publishes the original evidence and returns without starting a new operation. A subsequent ordinary driver step may use the already authorized logical retry key. This also handles interruption between recovery-event append and outcome publication because the original intent remains pending throughout.

Two new files add five cases: `tests/f27-late-review-failure.test.mjs` covers late serverOverloaded via resume, late internalServerError via run, late cyberPolicy refusal, and zero retry allowance; `tests/f27-late-malformed-review.test.mjs` covers late completed malformed output. Each reopens in a separate Node process, compares exact original canonical signed wire bytes and immutable event prefix, and checks evidence-only settlement followed by at most the allowed original logical retry. Their first setup controls compared JSON-transported plain objects to null-prototype objects; that representation-only comparison was corrected to exact canonical signed bytes and initial tests/logs retained. Current unchanged bytes were then witnessed RED before final code edits.

```
node --test packs/autonomy/repo-template/scripts/quality-orchestrator/tests/f27-late-review-failure.test.mjs packs/autonomy/repo-template/scripts/quality-orchestrator/tests/f27-late-malformed-review.test.mjs
```

RED: 3 causal blocked-stage assertion failures, 2 passing refusal/exhaustion controls, exit 1 (106.804s). Final GREEN: **5/5**, exit 0 (117.279s), on identical test/helper bytes.

```
node --test --test-name-pattern='F27 M3|A03|A06|pending effect|publication' packs/autonomy/repo-template/scripts/quality-orchestrator/tests/f27-corrections.test.mjs packs/autonomy/repo-template/scripts/quality-orchestrator/tests/human-interruption.test.mjs
```

Final affected GREEN: **9/9**, exit 0 (89.299s): both original successful-late-ack process-reopen cases, corrected A03, A06 durable resume, absent pending acknowledgement, v1/v2 custody contention, persistent custody lock, and stale authority after lock release. Two final modified-module syntax checks and scoped `git diff --check` exited 0.

Final current-oracle RED, using the unchanged current human-interruption test bytes, is freshly re-witnessed again:

```
node --import ./docs/implementation/2026-09-07-closure/f27-corrections/late-failure/current-durable-ingest-mutation.mjs --test --test-name-pattern=A06 packs/autonomy/repo-template/scripts/quality-orchestrator/tests/human-interruption.test.mjs
```

Result: one causal `ERR_ASSERTION`, exit 1, for the false `PRODUCT_REPLAYED` admission. Final receipt: `docs/implementation/2026-09-07-closure/f27-corrections/late-failure/current-oracle-red-receipt.json`. This is the receipt intended for the live oracle pointer. All first-correction oracle receipts remain exact.

Final second-round causal receipts, exact first-correction source snapshots, final source manifest, minimal patch and GREEN logs are under `docs/implementation/2026-09-07-closure/f27-corrections/late-failure/`. The final GREEN receipt binds all 19 sibling module hashes and the five relevant test/helper files. All stayed unchanged during the final runs. Original 19-case evidence and the 104-case legacy result are explicitly first-correction evidence; final focused coverage resolves the new intersection without claiming an unperformed final full-suite run.

## Authority, budget and scope limits

No source-repository staging, commits, network, credentials, subagents or full `make check` were performed by this implementer. Temporary fixture Git commits and ephemeral signed fixture approvals are local test setup. Root owns final full verification, metadata and commits. The original grants, original pending keys, maxSteps and journal caps remain unchanged; denied remediation cases reserve nothing, M6 settles only its first intent without another charge, and late acknowledgements publish once without new effect or charge. Release effects run once in required order under their supplied original keys, and wrong candidates are never dispatched.

These are controlled fixture results, not real model authentication, host containment, independently authenticated evidence, actual release/deployment, owner adoption or acceptance. No historical blocked review status or F27 acceptance status is changed here.

## Exact final hashes

| File (runtime-relative) | SHA-256 |
|---|---|
| `product.mjs` | `acc0e4c8402dde24e9c7d88cf168be7744c0b9a4ccc435ef1282bb087ac0b51a` |
| `product.schema.mjs` | `89ae1728629ef5f24a60ff553180d63fdc45a47951aabc9fe5d1d5a8557eebe2` |
| `codex-worker.mjs` | `836883f95330f0a38aefa6f31de44a004622dac825fa59748591eea9bbf7e18f` |
| `release.mjs` | `0341925547850d952bd96df3f5e0110bcabe4afd85c57366c4b34cce2ec90377` |
| `tests/f27-late-review-failure.test.mjs` | `68dbdd85aeb992fd08d521bc5dc73d03b5195302aa037ee940f8bcb674d358b3` |
| `tests/f27-late-malformed-review.test.mjs` | `9692bfe9bcad84b72285acdb5493be9b441bcecc74052d8d202dbd5228a1b78b` |
