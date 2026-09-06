### Finding Verdicts

- **Important 1 — Deployment reconciliation returns a key the backend cannot resume.** — **ADDRESSED.** Deployment outcomes now retain the real journal intent in `intentKey`, while only the evidence event gets the derived `outcome:<digest>` identifier (`packs/autonomy/repo-template/scripts/quality-orchestrator/release.mjs:157-163`). Terminal FAIL and stale/superseded evidence become `revalidate-deployment` with that real key (`packs/autonomy/repo-template/scripts/quality-orchestrator/release.mjs:26-33`, `:54-60`); a separately authorized readback binds the original key, evidence digest, deployment identity, objective, and target (`packs/autonomy/repo-template/scripts/quality-orchestrator/release.mjs:103-123`, `:150-155`, `:179-183`). Pending effects still take precedence and reconcile their original key (`packs/autonomy/repo-template/scripts/quality-orchestrator/release.mjs:65-68`). The public tests cover terminal FAIL and expiry, immutable original-key resume without spend/redispatch, exactly one deploy, separately authorized readback, and fresh smoke/observability (`packs/autonomy/repo-template/scripts/quality-orchestrator/tests/execution-backend.test.mjs:245-258`).

- **Important 2 — Missing supervisor enrollment is discovered only after budget spend and dispatch.** — **ADDRESSED.** The authority boundary checks specifically for an issuer with role `execution-supervisor` and kind `execution-observation` (`packs/autonomy/repo-template/scripts/quality-orchestrator/authority.mjs:82-83`), and every describe/execute capability check invokes it before reservation or dispatch (`packs/autonomy/repo-template/scripts/quality-orchestrator/execution.mjs:14-17`, `:22-40`). The focused test requires a blocked description, zero HTTP requests, zero dispatches, and zero budget spent (`packs/autonomy/repo-template/scripts/quality-orchestrator/tests/execution-backend.test.mjs:223-225`).

- **Important 3 — A catalog expiring after dispatch prevents verification of the original standalone review.** — **ADDRESSED.** Execution records expose the reservation event time and a review reconciliation reconstructs the frozen request against that time, then checks the review observation's own current expiry separately (`packs/autonomy/repo-template/scripts/quality-orchestrator/execution.mjs:54-60`; `packs/autonomy/repo-template/scripts/quality-orchestrator/review.mjs:45-51`, `:68`). A second catalog-currentness check occurs after transport preflight and before the reservation (`packs/autonomy/repo-template/scripts/quality-orchestrator/execution.mjs:32-39`). The focused test dispatches under a valid catalog, resumes successfully after catalog expiry, blocks a new review start, and independently rejects the later-expired review observation (`packs/autonomy/repo-template/scripts/quality-orchestrator/tests/execution-backend.test.mjs:227-232`).

- **Important 4 — The worker corrupts valid Unicode when a UTF-8 character spans stdout chunks.** — **ADDRESSED.** Worker stdout now passes chunks through one fatal streaming `TextDecoder`, flushes it at EOF, and rejects both incomplete UTF-8 and incomplete final frames while preserving the existing byte/frame bounds (`packs/autonomy/repo-template/scripts/quality-orchestrator/codex-worker.mjs:37-56`). The fixture splits `é` across actual writes and asserts exact `café 🐈` plus its digest; a separate case rejects a truncated terminal sequence (`packs/autonomy/repo-template/scripts/quality-orchestrator/tests/execution-backend.test.mjs:234-238`).

### New Breakage in the Fix Diff

- **None.** The readback event has a strict schema (`packs/autonomy/repo-template/scripts/quality-orchestrator/release.schema.mjs:12-20`), the evaluator requires its original known deployment identity and orders new smoke/observability after it (`packs/autonomy/repo-template/scripts/quality-orchestrator/release.mjs:31-33`, `:56-60`), and the operator contract explicitly requires the workflow's readback action to avoid deploy fallback (`packs/autonomy/repo-template/scripts/quality-orchestrator/contracts-execution-v1.md:169-192`).

### Out-of-Scope Observations

- **Unchanged boundary:** Real GitHub execution, authenticated Codex containment, the consumer target adapter/readback, and live deployment acceptance remain operator-supplied and NOT_EXECUTED (`.superpowers/sdd/plan/task-1-report.md:244-249`). This is non-blocking for the scoped functional fix review.

- **Unchanged review status:** The interrupted whole-branch cybersecurity review remains INCOMPLETE and was neither resumed nor replaced (`.superpowers/sdd/plan/task-1-brief.md:16-20`).

### Checks

- **Evidence inspected, not rerun:** The fix report records causal RED 0/6, GREEN 4/4 for findings 2-4, GREEN 2/2 for the deployment recovery paths, and GREEN 54/54 for unchanged review/release compatibility (`.superpowers/sdd/plan/task-1-report.md:217-240`). Per the scoped re-review contract and controller instruction, no suite was rerun.

### Verdict

**Fix round:** **All findings addressed, no new Critical/Important breakage.** Open findings: none.
