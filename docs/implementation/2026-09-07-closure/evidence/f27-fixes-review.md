# F27 six Medium corrections — independent static re-review

Date: 2026-09-07. Worktree: `/workspace/scratch/adce1c53b293/harness-human-interruption`. Original reviewed PR37 range: `dd8a20c1465b3ccd7e9a4d86ed6a11860146e7f7..dfd717b934667b1d6153a8934a657a70b8b0c9e1`. The worktree HEAD remains `dfd717b934667b1d6153a8934a657a70b8b0c9e1`; its examined uncommitted correction bytes are identified below.

The immediate correction baseline is the 19-module preserved snapshot under `docs/implementation/2026-09-07-closure/f27-corrections/red-source/`, manifest SHA-256 `70758e7ea1739a041fb6c2145a7c1540bfd8f6cf2c0c4435b245119ee8f64f7e`. It includes earlier integrated changes and is not represented as clean PR37 HEAD. This re-review covers the four changed production modules and their relevant tests/contracts/evidence only. The release scope is `runRelease`; the unchanged `executeReleaseObligation` guard and pending H1 integration are not certified by this report.

**Spec verdict: CHANGES REQUIRED. Quality verdict: CHANGES REQUIRED.** One Medium/P2 recovery gap remains at the intersection of M3 and M4. The first correction wave is not ready to close all six findings. No new Critical, High or Low finding was established in this bounded review.

## Remaining finding: F27-R1 — Late retryable reviewer acknowledgement retains the operational checkpoint (Medium / P2)

Location: `packs/autonomy/repo-template/scripts/quality-orchestrator/product.mjs:274-281`, with the checkpoint at line 287 and early returns at lines 349-352 and 364.

A reviewer starts under its original durable intent. Another resume sees no acknowledgement yet and appends `OPERATIONAL_BLOCK`, setting stage to `OPERATIONAL_BLOCKED` while preserving that pending intent. The original worker subsequently settles with matching IDs, unchanged source, clean termination and explicit `serverOverloaded` or `internalServerError`, then retains its acknowledgement before an interruption prevents publication. The signed grant, source, run and retry allowance remain current.

The corrected resume path now reaches that exact retained result and publishes `SETTLED_REVIEW_FAILURE`. Its mechanical branch increments the existing retry/fingerprint counters and clears `pending`, but never restores the reviewer stage from the earlier operational checkpoint. It therefore leaves stage `OPERATIONAL_BLOCKED` even when neither retry nor no-progress limits are exhausted. `completeV2` returns false; `executeV2` returns the blocked projection. Subsequent run/resume calls immediately return because stage remains blocked and there is no pending intent. The same supported transient outcome that retries normally with prompt acknowledgement becomes permanently blocked solely because its acknowledgement arrived late.

This does not duplicate the uncertain effect or reset a budget. It is an avoidable interruption after the original effect has become known and the existing grant expressly permits its bounded recovery. Thus M3 is only partially closed despite successful publication of the late result; the new M4 classification exposes an unhandled transition from the recovered checkpoint. A late completed malformed reviewer output has the analogous stage-retention issue through `TOOL_FAILURE`; its historical reducer semantics must not simply be rewritten as a fix.

Required correction: make recovery from the specific original uncertain-ack checkpoint explicit and durable, restoring only the appropriate owned FULL/FOCAL stage when the now-settled outcome supports an already-authorized retry. Keep unknown/refused causes and exhausted retry/no-progress budgets blocked, retain the original charged intent/history, and preserve historical `TOOL_FAILURE`/`REVIEW_TRANSPORT_REJECTED` replay semantics. Do not treat arbitrary operational blocks as retry permission.

Test gap: M3's two new process-reopen cases retain a successful functional RED acknowledgement, whose OBSERVATION explicitly advances stage to IMPLEMENT. The two M4 transient controls publish promptly before an operational checkpoint exists. Their combination is missing. A focused delayed supported-transient case should prove one original settlement followed only by the allowed charged retry, with unchanged signed authority and original event prefix; a denied/exhausted control should remain blocked. This finding is based on static control flow. This reviewer ran no candidate test or probe.

## Disposition of the original six findings

All short source paths below are relative to `packs/autonomy/repo-template/scripts/quality-orchestrator/`.

| Original finding | Re-review disposition | Source/evidence assessment |
|---|---|---|
| M1 — signed base before correction | Addressed | `product.mjs:300-310` checks actual HEAD against the signed base in description and repeats the full description under custody before intent/writes. Existing context, grant, expiry and OPEN-run checks remain. The changed-HEAD case compares correction bytes, original signature, starts/spend and pending state before/after refusal. |
| M2 — deleted frozen inventory | Addressed | Description now compares complete sorted path sets, every file mode, and complete metadata for unrelated paths. It runs again under custody. The regression deletes an unrelated frozen file, attempts both fresh description and apply, and requires unchanged correction bytes/counters with no pending correction. |
| M3 — late original ack | Partially addressed | A pending original key reaches acknowledgement reconciliation before the operational-stage return, including reopen through resume and run; absent acknowledgement does not redispatch or append repeated identical checkpoints. A successful observation advances state once without another charge. F27-R1 remains for retryable late reviewer outcomes. |
| M4 — undifferentiated failed reviews | Causal classification addressed; recovery intersection remains | `codex-worker.mjs:76-82`, `product.schema.mjs:33-40` and `product.mjs:262-285,324-325` retain bounded versioned causal data and use a closed retry set. F27-R1 does not undermine the refusal/no-retry classification, but prevents complete closure of the combined recovery behavior. |
| M5 — first operation-type candidate | Addressed | `release.mjs:201-212` considers later unspent candidates until both complete request and budget equal a fresh description of the current obligation. Reverse two-slice order, readback-before-deploy and deploy-before-readback cases check actual captured requests/keys and spend; wrong candidates never dispatch. Existing signature verification remains authoritative. |
| M6 — second correction under first intent | Addressed | `product.mjs:301,309` rejects ordinary pending work and mismatched pending proof ownership before effects. The new case interrupts after the first correction intent, rejects the second proof before its writes/spend, then settles only the first without another charge. |

## Classification, historical meaning and resource invariants

The worker only admits a settled failed product.v2 reviewer after the existing thread/turn identity, unchanged-source and clean-termination checks. It extracts an enumerated protocol discriminator when the error envelope has a string message. Unsupported/non-string/missing classification becomes `unknown`; message content never grants retry. Raw message/details are not retained in the causal payload. Any non-null misalignment indication prevents mechanical classification. Only `serverOverloaded` and `internalServerError` without that indication enter the already signed tooling limits. Unknown, authentication/authorization, policy/refusal, budget/usage and unsupported causes become `OPERATIONAL_DIAGNOSIS`, clear the settled pending attempt and cannot trigger another reviewer attempt.

`SETTLED_REVIEW_FAILURE` is additive with explicit payload version 1 and strict failure-record version 1. It validates original pending key, kind/binding, source digest and equality to the retained acknowledgement before reduction. Existing `TOOL_FAILURE` schema and reducer remain unchanged, preserving already-published historical `REVIEW_TRANSPORT_REJECTED` semantics and counters. A newly reconciled old unqualified acknowledgement is conservatively mapped to `unknown`; it cannot acquire fresh retry authority. This distinction is accurately documented.

INTENT still charges both original signed starts and journal total before the effect. Settling a failed reviewer does not consume a valid FULL/FOCAL judgment; successful durable ingestion still does. No grant renewal, resource reset, history rewrite, new authority or relaxed remediation scope was introduced by the examined correction delta. The remaining finding concerns stage recovery, not excess spending or refusal bypass.

The explicitly authorized A03 expectation change is honest: only its test name/assertions change; its original unqualified credential-shaped rejection payload is unchanged. The new expectation requires diagnosis, zero judgment/ingest and no retry. Separate explicit-code controls demonstrate the permitted transient path. The original test, oracle and publication-recovery receipt are preserved byte-for-byte and match their exact PR37 Git objects. This is a current contract correction with preserved history, not a claim that the former A03 success expectation remained compatible.

## Evidence integrity and useful coverage

All 19 RED module hashes match the preserved source; all 19 GREEN hashes match current production. Only `product.mjs`, `product.schema.mjs`, `codex-worker.mjs` and the specified `runRelease` region differ between those snapshots. The GREEN receipt covers those current modules and unchanged siblings. There are no dependencies or schema changes beyond the inspected additive product payload in this correction delta.

All direct content references match: five test/log bindings in `red-receipt.json`, 24 test/source/log bindings in `green-receipt.json`, and five in `current-oracle-red-receipt.json`. RED's manifest hash matches its preserved 19-file inventory. RED and GREEN use identical current test/helper hashes. The grouped logs record 17 causal assertion failures plus two passing transient controls before the fixes, then 19/19 passing across the same three groups. The initial setup failures are separately retained and explicitly excluded from the current causal witness.

The current A06 oracle points to the fresh current-test receipt. Its mutation hook checks the exact corrected product source hash, replaces both durable reads with ephemeral reconstruction, and its recorded failure is the false PRODUCT_REPLAYED assertion after object loss. The preserved source, hook, patch and log match their receipt hashes. This is local content-consistent falsification evidence, not independently authenticated execution. The oracle's historical commit anchor alone does not identify these uncommitted bytes; the current receipt/snapshot supplies that binding.

At inspection, `affected-legacy-green.log` was still accumulating individual passes and had no final summary. Accordingly this report makes no affected-legacy completion claim. It does not require rerunning unrelated suites to establish the static finding.

| Examined production file | SHA-256 |
|---|---|
| `product.mjs` | `874ab1c50540c4ec592283ad5bb577f4e8f12204cc43c29db0ce31e8fa53de75` |
| `product.schema.mjs` | `7566f536152014f412da0080ccddd3b5109b426180d6a9d179cc37e81cd635fa` |
| `codex-worker.mjs` | `836883f95330f0a38aefa6f31de44a004622dac825fa59748591eea9bbf7e18f` |
| `release.mjs` | `0341925547850d952bd96df3f5e0110bcabe4afd85c57366c4b34cce2ec90377` |

| Evidence | SHA-256 |
|---|---|
| `tests/f27-corrections.test.mjs` | `a1d87fbaea4deba6ca215432047ba2a6d937a9916e1d90e054564ac485d84685` |
| `tests/f27-corrections-fixture.mjs` | `c67d830dda497b47ae54bad1fd2dca70a070b324e551cb22e72834fc6e784aa9` |
| `tests/human-interruption.test.mjs` current | `8573cf58825e60da5b85abb017b7283e533f73f24ebdf303e49c8545fe58b8e3` |
| `red-receipt.json` | `5be62434c1795124293c1b2e10478fbfd70afe277b1a6d2a0f8c96ed9327bf3b` |
| `green-receipt.json` | `0a86a516d8b02ca902ffa7d3d81705a8f8fd3c529a3f764300bdf03417a24753` |
| `green-source-manifest.json` | `992b9bc3b19a65f19b05adea44b021d4c70deaf853ecc9ed4ffe624df86d32ac` |
| `current-oracle-red-receipt.json` | `f2917d7c6692d3743baaff3562982d2a791dfa6815efdfa2ddb4114ddf130cc7` |

Evidence basenames in the table are under `docs/implementation/2026-09-07-closure/f27-corrections/`; test paths are under the runtime directory.

## Coverage limits and next disposition

The new cases cover the concrete six reported paths and useful positive controls, including source preservation, charging, original signatures, process reopen, captured deployment identity and durable causal logs. They do not cover the late-ack/retry intersection in F27-R1; additional combinations such as explicit transient code with misalignment presence were assessed statically rather than demonstrated by this new suite. Historical event behavior was compared in source and preserved artifacts, not re-executed here.

This review used filesystem/Git reads and reviewer-authored hash/diff comparisons only. No candidate programs/tests/probes, network, credentials, source mutation or subagents were used; only this report was written. No platform rejection occurred. It does not certify real model authentication, containment, actual deployment, owner adoption, live supervisor acceptance, full repository checks, unrelated publication features or complete parent-branch approval. Preserve this first-wave source/evidence when correcting F27-R1, then re-review the focused new bytes and causal regression through the permitted workflow.
