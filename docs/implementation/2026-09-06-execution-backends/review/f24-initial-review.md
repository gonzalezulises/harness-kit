### Spec Compliance

- ❌ Issues found: the new execution bridge does not preserve usable deployment reconciliation across failure/expiry, and it spends before detecting absent supervisor enrollment. Standalone review resumption also depends on catalog freshness after dispatch. See Important findings 1–3.
- ⚠️ Cannot verify from this diff: real GitHub execution, authenticated Codex containment, operator workflow execution/signing, consumer target/readback and live deployment acceptance. They are explicitly NOT_EXECUTED/operator-supplied in `packs/autonomy/repo-template/scripts/quality-orchestrator/contracts-execution-v1.md:105` and `:161`. Historical H07/H08 acceptance requirements and the whole-branch cybersecurity review were not re-audited; that interrupted review remains INCOMPLETE.

### Strengths

- `packs/autonomy/repo-template/scripts/quality-orchestrator/execution.mjs:29` and `:38`: descriptors are persisted before reservation, reservation precedes the sole dispatch, and a repeated key reconciles its original intent. The concurrent-request recheck is narrowly placed after preflight.
- `packs/autonomy/repo-template/scripts/quality-orchestrator/execution.mjs:42`: observation verification binds the enrolled execution role, descriptor, workflow, original run/attempt and output digest using the existing approval machinery.
- `packs/autonomy/repo-template/scripts/quality-orchestrator/github-actions.mjs:65`: the fixed artifact redirect path omits GitHub credentials; unsupported redirects stop.
- `packs/autonomy/repo-template/scripts/quality-orchestrator/tests/execution-backend.test.mjs:1`: new tests exercise the public API, journal reopen, signed observations and actual local worker processes without changing historical tests. The evidence manifest reports 21 runtime, 2 e2e and 114 compatibility passes.

### Issues

#### Critical (Must Fix)

- None identified in this scoped functional review.

#### Important (Should Fix)

1. **Deployment reconciliation returns a key the backend cannot resume.** `packs/autonomy/repo-template/scripts/quality-orchestrator/release.mjs:138` fabricates `intent:<digest>` as the deployment evidence intent key. The unchanged evaluator returns that key for both a terminal FAIL deployment (its intent is never cleared) and expired/superseded deployment evidence (`release.mjs:28`, `:52`, `:61`). However, the new `resumeReleaseExecution` forwards it directly to `execution.resume` (`release.mjs:179`), which requires an actual journal intent (`execution.mjs:63`). Thus a valid signed failed deployment leaves a permanently unresolvable obligation, while expired deployment evidence likewise offers no usable continuation. Resuming the real operation key only returns the already-completed immutable record. Define a bounded recovery path that retains the original execution identity, distinguishes terminal failure from uncertainty, and supports fresh authorized readback/revalidation without redispatching the uncertain original effect. Add focused cases for terminal FAIL and deployment expiry through the public API; the current full-chain expiry assertion only checks loss of PASS.

2. **Missing supervisor enrollment is discovered only after budget spend and dispatch.** `packs/autonomy/repo-template/scripts/quality-orchestrator/execution.mjs:14` checks operation/target registration but not whether the host has an enrolled `execution-supervisor` issuer for `execution-observation`; `:38` then reserves and dispatches. The added test at `tests/execution-backend.test.mjs:217` removes that issuer and explicitly expects one dispatch before reconciliation refuses the observation. This violates the binding requirement that missing host capability stops before spending and starts work that this configured runtime cannot authenticate. Add a narrow host-authority capability check before reservation/preflight dispatch, retaining role/kind restrictions; change this negative case to require zero dispatches and zero spending.

3. **A catalog expiring after dispatch prevents verification of the original standalone review.** `packs/autonomy/repo-template/scripts/quality-orchestrator/review.mjs:68` first reconciles and stores the signed review, then calls `reviewRequest` to compare its original binding; `reviewRequest` rejects an expired catalog at `:47`. A review started while the catalog was valid can therefore never return `REVIEW_VERIFIED` once that catalog expires, even when its own observation and review approval remain fresh. Refreshing the catalog changes the binding/request digest, so it cannot repair the original request. Separate start-time catalog capability checks from reconciliation of the frozen descriptor; validate the catalog at the appropriate recorded time and validate the review's own freshness independently. Cover dispatch before catalog expiry and resume afterward, with a still-valid review observation.

4. **The worker corrupts valid Unicode when a UTF-8 character spans stdout chunks.** `packs/autonomy/repo-template/scripts/quality-orchestrator/codex-worker.mjs:49` calls `chunk.toString('utf8')` independently for each stream chunk. Node stream chunks need not align with character boundaries: a split accented character or emoji becomes replacement characters before JSON parsing. Review descriptions, source paths and final-output digests can therefore be corrupted or spuriously rejected on a valid Codex response. Decode incrementally with a UTF-8 `StringDecoder` or streaming `TextDecoder`, preserving byte/frame limits and rejecting an incomplete final sequence. Add one protocol fixture that deliberately splits a multibyte character between writes.

#### Minor (Nice to Have)

- `packs/autonomy/repo-template/scripts/quality-orchestrator/release.mjs:88`: the unchanged comment still says there is no authenticated execution/receipt importer immediately above the newly implemented positive path. Update it to describe the current boundary.

### Assessment

**Task quality: Needs fixes.**

**Reasoning:** The transport, signed provenance and persistence structure are coherent and remain within the intended single-backend scope. The positive tests establish useful coverage, but the concrete recovery, capability and stream-decoding defects above prevent approval of the new functionality.

**Checks performed:** Read the supplied diff once in seven bounded chunks, the task brief, implementer report, reviewer method and verified `results.json`; inspected existing final log summaries for warnings/errors without rerunning any tests. No actual warnings/errors appeared in those final logs (the lint command's `-S warning` option is not a warning).

**Focused integration reads:** The diff omitted the middle of `obligations`, so inspected that function to check the named synthetic-deployment-key recovery risk, plus the unchanged `release.schema.mjs` receipt shape. Checked the locally pinned Codex `ThreadStartResponse`, `ThreadStartParams` and `TurnStartParams` schema fields for the named worker protocol-compatibility risk; the inspected sandbox/model/parameter shapes agree with the new worker. No broader source scan, network access, credential access, dispatch, test execution, checkout/index/ref mutation or subagent dispatch occurred. Only this report was written.
