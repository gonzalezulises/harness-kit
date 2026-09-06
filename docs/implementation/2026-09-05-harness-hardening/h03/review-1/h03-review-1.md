# H03 independent specification and code-quality review

Review target: base `29445190ae94fd85771d5b41223104f8e1d1c011` through frozen tree `f508b942704143a5d58c45b7eb4fdbd0180f096a`. Scope is the H03 pure identity, classifier and cryptographic authority package, its current contracts/setup, tests and evidence. Primary review package: `.superpowers/sdd/migration-plan/h03-review-source-1.diff`. Historical source/log captures were treated as evidence, not additional shipping implementations. The working shipping pack had no diff against the frozen tree when checked.

**Specification verdict: CHANGES_REQUESTED. Code-quality verdict: CHANGES_REQUESTED.** Two Medium findings; zero Critical, High or Low findings. Both findings have narrowly reproduced behavior on the shipping modules. Neither demonstrates forged authority or execution authorization. The first violates the declared supported YAML boundary; the second violates structured failure and opaque handle return contracts at an expiry boundary.

Preserved reproduction artifacts beside this report: `h03-review-1-probes.mjs`, `h03-review-1-probes.stdout.log`, and `h03-review-1-probes.stderr.log`. Actual command: `node /workspace/scratch/adce1c53b293/h03-review-1-probes.mjs`, exit 0; stderr is empty. The command is an observation probe, not a passing requirements test. Its stdout binds the three source module SHA-256 values and records exact directive input, clock sequences and observed failures. Each final clock probe uses a separate fixture and monotonic time within that runtime.

## Findings

### H03-R1 — Medium — Explicit `%TAG !!` directives evade the unsupported-directive check

Location: `packs/autonomy/repo-template/scripts/quality-orchestrator/identity.mjs:53`; downstream eligibility at `classify.mjs:58`. Contract: `contracts-v1.md:54–58` says directives are rejected, and the brief requires unsupported YAML/schema forms to stop rather than gaining an unregistered normalization rule.

The parser's tag mapping contains the default `!!` handle. The guard rejects only tag-map keys other than `!!`, so it cannot distinguish the implicit default from an explicit `%TAG !! tag:yaml.org,2002:` directive. Prefixing the accepted sample with the following text returns IDENTIFIED and the same canonical and semantic hashes as the original:

```text
%TAG !! tag:yaml.org,2002:
---
```

With the ordinary fixture's signed accepted baseline, `classifyChange({changes:[{path:'record.yaml',after:bytes(prefix+sample)}]}, context)` returns `MECHANICAL_ELIGIBLE` and proof kind `canonical-reorder.v1`. This is an unsupported directive addition being certified through the canonical-reorder path. `executionAuthorized` remains false. A control with a trailing human comment on the directive correctly returned UNKNOWN; this review does not claim a reproduced comment-erasure bypass here.

The existing directive regression exercises `%YAML 1.2` only (`tests/identity.test.mjs`, test “human comments and directives are unsupported instead of silently erased”), so its GREEN does not cover this case.

Requested correction: distinguish actual directive tokens from implicit parser defaults and reject explicit directives under the current v1 contract. Add focused identity and classifier regressions for default-handle `%TAG` declarations. Preserve the legitimate plain key-reorder positive case. Do not broaden the normalization contract just to match this accidental acceptance.

### H03-R2 — Medium — Expiry during construction returns an approval handle instead of the required stop

Locations: `packs/autonomy/repo-template/scripts/quality-orchestrator/authority.mjs:64–66` and `classify.mjs:35–37`. Relevant contract: `contracts-v1.md:15–23,81–82,94–116`; the preflight defines `VerifiedAuthority | Stop` and `VerifiedContext | Stop`, with current authority/time prerequisites checked by the runtime.

Both constructors call `verifyApproval`, which performs a freshness inspection, and then inspect the returned approval again. If time crosses expiry between those calls, the second inspection returns `BLOCKED_BY_STALE_AUTHORITY`, but each constructor returns the original approval handle (`return approval` / `return acceptance`). The caller receives an empty opaque handle with no stop status, and it belongs to the approval WeakMap rather than the promised authority/context WeakMap.

Narrow probes used the existing signed fixture (receipt expiry 1500, checkpoint expiry 2000) with controlled trusted clock readings. For `loadAuthority`, successive readings were 1000,1600. For `verifyContext`, they were 1000,1000,1600 (including the initial adopted-authority inspection). Time stayed at 1600 after each boundary crossing. Observed output:

```json
{"operation":"loadAuthority","returnedStatus":null,"authorityInspection":"UNKNOWN","approvalInspection":"BLOCKED_BY_STALE_AUTHORITY"}
{"operation":"verifyContext","returnedStatus":null,"contextInspection":"UNKNOWN","approvalInspection":"BLOCKED_BY_STALE_AUTHORITY"}
```

Here null is the probe's rendering of the absent `status` property. Correctly inspecting the resulting handle as authority/context still fails, so the current classifier does not gain permission. Nevertheless this breaks the published return union, hides the actionable freshness stop, and creates the appearance of a successfully returned opaque result for H04 consumers. The same control-flow issue can occur when the trusted clock becomes unavailable on the second inspection.

Requested correction: return the failed inspection result, preserving its status/reason. Keep propagation of an original `verifyApproval` stop correct as well. Add focused regressions for an expiry boundary between verification and constructor reinspection in both public APIs.

## Requirements coverage and interpretations

| Requirement | Assessment and evidence |
| --- | --- |
| Strict typed identity and complete value binding | Substantially satisfied. `identity.mjs:17–43,54–57` keeps parser-private exact numeric tokens, validates strict built-in Zod shapes and hashes the complete value with repository/schema/normalizer bindings. The explicit directive gap is R1. |
| Exact numeric distinctions, human text, scalar types | Source and current tests cover 100/99.9, large integers, near decimals, signed zero, exponent and decimal spelling, whitespace and enum changes; quoted numbers and boolean/string substitutions reject. Numeric mappings cannot construct the private ExactNumeric class. |
| Alias/tag/duplicate/unknown/UTF-8 rejection | Node/key traversal, strict parser errors/warnings, strict schemas and fatal UTF-8 decoding support the advertised rejection. The overbroad directive claim needs R1 fixed. |
| Candidate cannot choose trust roots/judge/schema/adapter | `openRuntime` consumes host configuration; request/context/change objects are strict. Built-in schema registry and closed proof implementation are not callback dispatch. Host construction must remain outside candidate control, as documented. |
| Real host-pinned cryptographic authority | `authority.mjs:9–15,18–29,45–66` verifies domain-separated Ed25519 receipts against pinned keys, issuer role/kinds, repository, exact subject/scope/authority and runtime contract. Canonical JSON rejects duplicate/noncanonical authority encodings. No production key generation was introduced. |
| Current time and revocation; opaque handles | Per-instance WeakMaps and repeated time/checkpoint/receipt checks are implemented. Forged/copied/foreign handles fail. Checkpoint freshness/custody is explicitly a host responsibility. Constructor failure propagation needs R2 fixed. |
| Accepted-before binding | `classify.mjs:18–43,50–55` hashes recomputed exact document identities and requires signed baseline acceptance. Classification uses retained immutable accepted identities, not a supplied before object or same-semantics flags. Partial inputs do not imply whole-repository acceptance. |
| Functional canonical and closed derived transformations | `classify.mjs:56–81` implements positive equivalence and a nonrecursive source-content digest rule. It checks the accepted source relation, unchanged source path, new source relation and source eligibility. Current tests include positive derivation, source substitution and adverse batch-source handling. |
| Protected changes and mixed batches | `classify.mjs:56–59,83` preserves identical bytes, requires a human for changed protected-class bytes, and aggregates UNKNOWN before HUMAN_REQUIRED before MECHANICAL_ELIGIBLE. The protected-byte restriction is the explicit conservative authority-source boundary in this brief/preflight, not an implementation defect. Canonical equivalence for ordinary registered data remains functional. No proof in this v1 contract overrides protected-source handling. |
| Assessments never confer permission | Every classification uses the common assessment constructor (`classify.mjs:8`) with `executionAuthorized:false`, recomputed assurance and `postconditions:NOT_EXECUTED`. H04 onward effects, witnesses, replay, grants and production acceptance are absent and not misrepresented as implemented. |
| Narrow schemas and reusable shared package | `contracts-v1.md:42–46,144–147` clearly limits v1 to record/digest contracts and excludes generic YAML/program equivalence. Shipping source has one home; future schemas/proofs require versioned implementation rather than candidate extension hooks. |
| Fresh install and optional compatibility | Exact yaml 2.9.0/zod 4.5.4 package/lock and integrity are present under the dedicated runtime directory. Setup uses `npm ci --ignore-scripts`; the verifier explicitly diagnoses missing dependencies and Node prerequisites with exit 69. Copy instructions preserve the consumer root package and defer `--with autonomy` to H09. |

## Evidence assessment

The implementer report and `h03/evidence-guide.md` make materially correct distinctions between requirement tests written before source, missing-module capability absence, initial fixture/signing-helper failures, executable assertion REDs, and subsequent GREEN. I inspected the current tests/modules, final RED receipt/command information and logs, final GREEN command metadata, integration-command evidence, seal and current documentation. The controller separately verified all 154 manifest entries and the seal; this review relies on that supplied hash verification rather than rerunning the entire manifest check.

The final RED log reports 54 tests, 48 passing and six assertion failures: unavailable-clock handling, positive derivation, adverse derived-source handling, locale ordering, comments/directives and mapping-shaped numeric tokens. Its source is explicitly an overlay of captured real module versions with current tests. It is **not** a historical commit snapshot, and the `fff527...` oracle history anchor does not claim those modules existed at that commit. This reconstruction is legitimate local falsification evidence for those named regressions, subject to the stated provenance limits; it does not prove the full contract or cover R1/R2.

The recorded current GREEN is 54/54. The copied consumer record shows a dependency-absent verifier exit 69, offline lockfile installation success, 54/54 consumer tests and an unchanged root package hash. Offline setup demonstrates reproducibility with the populated cache; the documentation correctly says a fresh environment needs registry access or a populated cache. Recorded static, oracle and note checks are exit 0. I did not rerun these suites because source and retained evidence resolved their claims. Only the narrow directive and clock-boundary probes above were executed during review; no product/source/index/ref changes were made.

## Limits and disposition

These two fixes should be reviewed before promoting H03. The architecture remains a small, useful pure trust boundary; the findings do not call for a second schema engine, broader proof authority or an effect runtime. Full `make check`, feature promotion, branch review and publication remain controller responsibilities.

This review does not establish real human issuer enrollment, latest remote revocation discovery, same-UID runtime protection, external witness custody, OS containment, authenticated Codex acceptance or production execution. Those are documented host/H04+ obligations. Test fixture signatures prove verifier behavior with fixture keys, not real operator approval. No baseline or policy adoption was performed by this review.
