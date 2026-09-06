# H09 implementer report — FROZEN

Status: implemented and locally verified, ready for coordinator integration and independent review. Source checkout base HEAD is `65c0c6976520ca53b878224e081d042a62853db4` (H08 published tree `6e71baf35be436d6c0e77ffa53a02d4ed45520f7`). No source-checkout index, commits, refs, root feature_list.json/PROGRESS.md/DECISIONS.md/ledger/quality-document edits were made by this worker. Git commits in the disposable canary repository are deliberate tested fixture actions only. Existing H01–H08 runtime sources, tests, receipts and v1 bytes are unchanged. No generated node_modules is retained in source/evidence.

## Changed files and interfaces

- `bin/harness-init.sh`: explicit `--with autonomy`, optional Python-backed copy of the existing nested runtime; excludes node_modules, refuses symlink/nondirectory destination parents, retains an existing runtime intact (even with --force), preserves root package.json and creates no adoption marker or keys.
- `bin/harness-activate.sh`: accepts/forwards the same option, names installation-only authority and dependency setup. Its existing authorized remote-protection behavior is unchanged; the local canary uses the local init entrypoint and does not grant remote authority.
- `bin/harness-status.sh`: `--autonomy` bounded installation diagnostic, missing runtime/dependency status, unverified marker/authority and explicit UNIMPLEMENTED positive review/production backend labels. Zero means only the installed module loaded, not readiness, baseline acceptance or release PASS. Ordinary status retains local verification/remote inspection and adds optional package diagnostics.
- `packs/autonomy/tests/installation.test.mjs`: four targeted installer/status boundary tests.
- `packs/autonomy/tests/canary.test.mjs`: one actual fresh consumer integration flow with installed runtime and real offline npm ci. No second runtime/helper framework or generic backend was added.
- `packs/autonomy/verify-pack.sh`: retains its entire prior runtime suite, then runs the new installation/canary tests through the existing full-check discovery path.
- `packs/autonomy/index.md`, `docs/harness-capabilities.md`: current installation, host adoption, rollback and backend limitations.
- `.agents/notes/implemented/feature/2026-09-06-local-autonomy-installation-canary.md`: compatibility, authority and bounded-scope decision, with governing routes cited.
- `docs/implementation/2026-09-05-harness-hardening/h09/`: exact RED/development/final logs, source/evidence manifests, fixture evidence, static verifier, historical coverage matrix and unsigned final delivery candidate.

The canary reuses `openRuntime`, `loadAuthority`, `describeBaseline`, `verifyContext`, journal start/import/replay/replaceStaleRun/readLegacy/projectLegacy, describe/evaluateContinuation, prepare/execute/release capability and lease APIs, actual review shadow construction/refusal, and describe/bind/replay/next/certifyRelease. No installed runtime API or dependency changed. Its runtime-owned state is disjoint from writable product files; Git metadata lives in their parent repository so read-only objects are not inside the writable capability scope.

## Actual verification and suggested F23 layers

All commands run from kit root, in this order:

| Layer | Exact command | Actual result |
| --- | --- | --- |
| static | `bash docs/implementation/2026-09-05-harness-hardening/h09/verify-static.sh` | exit 0; shell/Node syntax and exact 45-file scoped source manifest |
| runtime | `node --test --test-reporter=tap packs/autonomy/tests/installation.test.mjs` | exit 0; 4 pass, 0 fail, 0 skipped |
| e2e | `node --test --test-reporter=tap packs/autonomy/tests/canary.test.mjs` | exit 0; 1 pass, 0 fail, 0 skipped |

These are the precise proposed F23 commands. Evidence is `verification.json` and `final-static.*`, `final-runtime.*`, `final-e2e.*` under `docs/implementation/2026-09-05-harness-hardening/h09/`. Final e2e used `H09_EVIDENCE_DIR` pointing at `h09/canary` to retain fixture artifacts; ordinary F23 execution needs no output variable and does not overwrite evidence. The canary executes the same child byte oracle twice RED and twice GREEN; the canary test itself passes by asserting those actual exits and the entire bounded flow.

Source/evidence/candidate hash integrity and scoped tracked whitespace were also checked after producing the candidate (exit 0). No baseline/full suite or root make check was rerun: root owns those gates and final feature promotion. Broad independent review has not been performed by this worker; no findings are claimed closed through self-review. No newly discovered Critical/High shipping defect remains known to this worker.

## RED provenance and development correction

`feature-absent.json`, logs, actual exit1 and `feature-absent-source/` bind the original three entrypoint files and the unchanged final installation test. Three expectations failed because explicit installation/status functionality was absent. This is FEATURE_ABSENT_RED, not a discovered prior security defect. The fourth symlink case passed because the old option failed early; it does not constitute an independently observed symlink falsification. Existing authority/guard safety proof remains in H03–H08 preserved evidence; no optional mutation campaign was performed.

The two nonzero canonical subprocess assertions concern deliberately supplied noncanonical local fixture representations. They are CONTROLLED_LOCAL_FIXTURE_RED, not actual shipping runtime defects. Their source bytes, exact oracle, logs/exits and current test hashes are preserved in `canary/`. The first e2e development attempt (`e2e-first.*`) correctly returned POLICY for Git read-only objects inside the writable root. The fixture layout was corrected; no production source/guard changed. `e2e-second.*` preserves the first green development run. Detached objects left by that earlier evidence copy are retained separately in `development-object-residue/`; final `canary/FIXTURE_ONLY-state/objects` contains only the final ten-event chain's objects.

## Observed outcome and honest metrics

The installed package preserves v1/root package bytes and starts without adoption. Explicit fixture-only adoption activates the installed legacy writer guard (exit67). Actual canonical writes satisfy the local byte oracle; same-key retries return the existing receipt. Three fresh runs follow actual Git commit changes, preserving the original acceptance and two mechanical budget units. The same continuation covers both effects. A threshold 100→99.9 change emits HUMAN_REQUIRED without executing mutation. The original baseline receipt rejects the exact final canonical artifact bytes as a new accepted baseline.

Actual local Git shadow construction succeeds. Installed review refuses before spending or receipt creation. The next slice/release remains unexecuted and certification remains false/NOT_EXECUTED. Local rollback archives/removes the fixture marker, restores original data bytes, retains v1/package/journal/installed-runtime bytes, and successfully reopens replay. Removing a marker does not revoke grants; adoption docs require disabling host use and preserving/reconciling evidence.

- Actual human prompts: 0.
- Fixture signatures: 5 (one policy adoption, one baseline, three distinct bounded subjects); these are not human intervention observations.
- Emitted human-gate reason codes: HUMAN_REQUIRED = 1.
- Distinct availability stops: BLOCKED_BY_REQUIRED_CAPABILITY = 2 (review and release); stale-run stop = 1.
- Reused continuation grants: 1; actual effect runs: 2; fresh runs: 3; spent budget: 2.
- Observed local recovery elapsed time: 1718.457812 ms, from deliberate representation defect through actual canonical verification. No real human time-saved/friction percentage is inferred.
- Authenticated review receipts: 0; production certificates: 0.

The exact before/after comparison is one byte oracle over one fixture record. There is no false local canonical PASS, allowed threshold mutation or unexpected final block in those exercised assertions. Historical coverage uses the existing HIST-01 through HIST-12 IDs in the evidence README. HIST-05's original Aurobalance fixture is unavailable; H02's kit timeout is separate. HIST-06 retains actual independent-resource concurrency. H07 contract/shadow evidence does not certify Codex/sandbox/session acceptance. H08 simulations for HIST-11 are not deployments. These are not twelve newly executed full-PASS rows.

## Source, test and evidence hashes

Source manifest: `acdbc8c8a05e73b9fafb8cda37ea2e763b302b851ba2283a3ca8bc79b2e9ccb5` (45 scoped files with exact bytes/modes).

Evidence manifest: `72499db2472bf5f7cf987353df4ac6b0301587770127e132989d1a09f7c5263f` (79 files).

Final installation test SHA256: `4efebb188e833093badc5695e0ae7a3ed8cc3aa0cc3671ae31ba232e3af5f8c3`.

Final canary test SHA256: `756b015abf47031442b1f8b1f64fb95572b7ccea885a4f0ae3e6f8c1f7c38833`.

Unsigned candidate file SHA256: `a694431cb8005bc93324e0f37c9c514b7ae0479bf6dfaa5140d9063e86247604`.

Exact delivery subject SHA256: `0924aafaf6d00edfc3d050154ebb77a592c28c894dfe867831ed86923f8a9913`.

All paths and per-file hashes are enumerated by those manifests; the source manifest includes the unchanged runtime package and pinned package/lockfile, never generated dependencies. The evidence manifest intentionally excludes itself, candidate descriptor and this external report to avoid self-reference. The candidate binds both exact manifests, not a guessed final commit hash. The coordinator must attach the final publication commit separately after all gates.

## Remaining limits / coordinator actions

H07 live reviewer/containment/authenticated receipt backend and H08 positive production scheduler/target/readback/authenticated receipt/live rollback backend are **UNIMPLEMENTED**, beyond merely NOT_EXECUTED. The original real-flow H09 PASS criterion is not achieved here. No new platform or speculative backend was added. No cancelled authenticated preflight was retried and no external target, deploy or owner-key enrollment was attempted.

`baseline-candidate.json` is explicitly unsigned **CANDIDATE_NOT_ACCEPTED** with null owner acceptance/signature, separate from fixture runtime baseline receipts. It proposes review of the exact selected implementation assets; it cannot establish whole-repository or runtime owner authority. Root should complete independent review, full integration, exact publication/state receipts, and present this candidate plus final Git commit to the owner once. Any owner acceptance remains an explicit future action, never something this canary or install auto-produces.

FROZEN: no further edits until coordinator resumes this worker.
