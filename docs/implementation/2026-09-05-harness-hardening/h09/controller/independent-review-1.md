# H09 independent review 1

Reviewed scope: H09 only, against base `65c0c6976520ca53b878224e081d042a62853db4` and supplied frozen review tree `bcc8f3972c7e70af8add04d248e1618c656089f6`. This is a read-only source review; this report is the only file written by this reviewer. No index, refs, source, evidence, or tests were changed. No suites were rerun.

## Verdicts

**Spec compliance: APPROVED for the explicitly bounded portable installation/local-canary/delivery-candidate scope. Original real-flow acceptance: NOT ACHIEVED / NOT_EXECUTED.** The brief expressly acknowledges unavailable positive H07/H08 backends and permits the local fixture work while retaining the original real-flow limitation. This approval must not be converted into whole-migration, real-session, deployment, or owner-baseline acceptance.

**Task quality: APPROVED.** The shipping change is small, uses the existing installer/status/runtime surfaces, and adds targeted installation coverage plus one integrated consumer canary. No new runtime implementation, platform, or dependency framework was introduced. The retained evidence supports the bounded claims without silently promoting fixture results into real authority.

Blocking shipping findings: **0**. Critical: 0; High: 0; Medium: 0; Low: 0. No concrete defect requiring correction was identified in the reviewed H09 shipping scope.

## Spec assessment and strengths

| Requirement | Assessment and evidence |
| --- | --- |
| Explicit optional installation and activation | `bin/harness-init.sh` adds explicit `--with autonomy`, validates destination directory boundaries before installation, and copies the single existing nested package excluding node_modules. `bin/harness-activate.sh` recognizes and forwards the option. The default legacy path remains opt-in-free. The activation test exercises dry-run parsing; actual forwarding is clear in the reviewed source, while actual activation/remote effects were not executed by this reviewer. |
| Existing consumer preservation | The destination runtime is retained as a whole, including when `--force` is set; no merge/upgrade branch exists. Existing root package.json and v1 bytes are preserved in the local tests. No adoption marker or keys are installed. The installation suite compares copied runtime files to the source and checks default, dry-run, missing-dependency, rerun, and symlink-parent behavior. |
| Installation status versus authority | `bin/harness-status.sh` explicitly reports `NOT_VERIFIED`, marker presence as unverified, and positive review/production backends as `UNIMPLEMENTED` with acceptance `NOT_EXECUTED`. Its dedicated diagnostic exit zero means successful runtime loading only. The docs repeat this narrow meaning rather than describing it as a readiness gate. |
| Installed runtime and actual local effects | `packs/autonomy/tests/canary.test.mjs` installs through the CLI, performs actual offline nested npm ci, imports the resulting consumer package, and invokes its authority, journal, continuation, effect, shadow, and release APIs. It does not substitute copied node_modules or a helper runtime. Retained subprocess logs show oracle exits 1, 0, 1, 0 and actual distinct Git commits. |
| Reuse, freshness, and semantic stop | The same signed continuation covers two successful canonical effects. Three fresh runs retain the accepted baseline and cumulative two-unit mechanical budget. An old run is rejected after the deliberate representation defect. Threshold 100 to 99.9 is classified `HUMAN_REQUIRED`, with execution unauthorized and the workspace unchanged. This is actual local classification and a closed local capability path, not a real human interaction. |
| Local fixture adoption and rollback | Fixture-only issuer keys and marker are explicit; the installed legacy writer guard returns exit 67. Rollback archives/removes the fixture marker, restores original YAML, preserves exact v1/root-package/journal bytes, retains runtime state, and reopens replay. Documentation correctly requires stopping host use and reconciling pending effects; marker removal is not represented as grant revocation or production rollback. |
| Scoped final candidate | `baseline-candidate.json` binds source and evidence manifest hashes, identifies its exact narrow implementation scope, leaves owner acceptance/signature null, and uses `CANDIDATE_NOT_ACCEPTED`. Final publication commit remains a separate coordinator item. Fixture baseline approval is separate and explicitly fails to accept the final changed artifact bytes. |
| Honest historical coverage and metrics | The H09 README retains HIST-01 through HIST-12 distinctions, including unavailable original HIST-05, separate H02 timeout/concurrency evidence, local H07 contracts/Git shadows, and H08 obligation simulations rather than actual deployment. Metrics separately name 0 human prompts, 5 fixture signatures, 1 human gate, 2 capability stops, 1 stale stop, 2 effects, 3 fresh runs, and fixture elapsed recovery time. No production-wide friction or real human time-saving claim is made. |

The executable canary directly covers local failure/correction, continuation reuse, idempotent retries, freshness, a semantic human gate, and evidence-preserving rollback. Review and release remain refusal paths. In particular, the retained release record still has `verify-slice` for `canonical-local` as its next obligation, zero release history, and all downstream integration/review/acceptance/deploy/smoke/observability obligations unsatisfied. It does not demonstrate completion or progression through a real release slice.

The fixture RED provenance is accurately limited: the pre-feature installation run had three failures; the symlink test passed because the old option was absent. The canonical byte REDs are deliberate representation fixtures. The first development e2e failed on unsupported file mode because Git objects were in the writable scope; the corrected layout isolates Git metadata without changing runtime guards.

## Findings

None at Critical, High, Medium, or Low severity in the bounded H09 shipping changes. No line-specific corrective finding is warranted. Missing real backends and original acceptance are explicit cross-task limitations, not newly introduced H09 implementation defects.

## Checks used

1. Read `.superpowers/sdd/migration-plan/task-9-brief.md` first, then the frozen implementer report and the supplied 969-line H09 diff once in three bounded sections. Did not reread changed shipping files separately.
2. Inspected retained `verification.json`, all final static/runtime/e2e stdout/stderr/exit records, the original feature-absent metadata/log, first e2e development failure, `canary/canary.json`, and recorded subprocess commands.
3. The retained final evidence reports static exit 0, installation 4/4 with no skips, and installed canary 1/1 with no skips. The coordinator separately reported an actual ordered F23 pass, unchanged source, and 4 runtime + 1 e2e tests; that coordinator run was not performed by this reviewer. No full-suite result is inferred.
4. Relied on the coordinator's stated verification of 45 source/mode and 79 evidence hashes and unchanged H01–H08 sources/tests; did not repeat that entire hash sweep or reassess prior task results.
5. Ran one read-only exact-byte probe to resolve the coordinator's named oracle binding question. The executed `node -e` source omits a trailing newline; the retained `.cjs` artifact adds one. All four recorded oracle invocations contain the same executed source, and the saved artifact is exactly that source plus one newline. This is two defined byte inputs, not an evidence discrepancy.

Exact oracle probe result (copied from successful exit-0 output):

```json
{"savedSha256": "d6edf8c5c13ff2b8542620612edbaeb81166d0ff55c83864f715e66351c4b4c5", "executedSha256": ["54c6aa43b8a91e969d2ce50471c915729fe87e5e0a45246d50fca12ec51031c6", "54c6aa43b8a91e969d2ce50471c915729fe87e5e0a45246d50fca12ec51031c6", "54c6aa43b8a91e969d2ce50471c915729fe87e5e0a45246d50fca12ec51031c6", "54c6aa43b8a91e969d2ce50471c915729fe87e5e0a45246d50fca12ec51031c6"], "savedEqualsExecutedPlusNewline": true, "executions": 4}
```

## Cannot verify and acceptance limitations

- H07 positive real reviewer/containment/authenticated session receipts and H08 positive production execution/readback/authenticated receipt/live rollback remain **UNIMPLEMENTED**. Their actual acceptance, the original full H09 real flow, and production certification remain **NOT_EXECUTED**. Fixture signatures cannot satisfy these requirements.
- Original Aurobalance HIST-05 is absent. Preserved prior-task history is appropriately attributed; this H09-only review does not independently recertify H01–H08 or original external fixtures.
- Root-owned feature state, publication/index/refs, final Git subject, full integration, and broad whole-branch review are outside this review. The diff stat mentions root/controller changes, but the supplied shipping diff intentionally does not expose those as H09 implementation work; no approval of those changes is implied.
- Owner acceptance has neither been obtained nor fabricated. The coordinator must finish its gates, supply the exact final publication commit, and present the scoped candidate for the explicit human decision. Until then it remains an unsigned candidate without owner authority.
