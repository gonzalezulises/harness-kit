# Spec compliance: Issues found

**Spec verdict: Needs fixes. Quality verdict: Needs fixes. Critical: 0; High: 0; Medium: 3; Low: 0.**

Reviewed H02 against `.superpowers/sdd/migration-plan/task-2-brief.md`, base `fff527b2c7a64fb6d70d60d633a0261e68315169`, frozen tree `45d528d6cdc0bb15032982909cc5b2f19f595c04`, using the supplied source/current-document/receipt diff. The implementation substantially covers the requested files and R10–R12/R14–R22. Three bounded defects remain in setup, timeout ownership and a weakened missing-document check.

## Strengths

- `Makefile:24`, `Makefile:29`, `scripts/run-gates.sh:35`, `scripts/run-gates.sh:49`: integrated verification runs live quick policy before the core pipeline; full aggregation avoids recursion; strict versioned profiles require universal gates and prevent candidate applicability downgrades.
- `.github/workflows/required-quality.yml:130`, `scripts/run-gates.sh:73`, `docs/harness-capabilities.md:19`: base judges/configuration and candidate files are separate, history is fetched, identities/sentinels are recorded, and missing protected adoption stops explicitly. The documented owner maintenance boundary is honest; no remote success is claimed.
- `scripts/verify-claims.sh:255`: only repair prose is excluded from comparison. Commands, inputs and environment remain exact, with executable regression cases in `tests/h02-hardening-regressions.py`.
- `scripts/pre-commit-staged.sh:12`, `scripts/pre-commit-staged.sh:53`, `scripts/pre-commit-staged.sh:57`: the hook snapshots regular index blobs, blocks formatter errors, preserves modes and working-tree bytes, and publishes under an exclusive index lock after checking for concurrent changes. Existing tests exercise partial staging, newline/space filenames, failures and symlinks.
- `scripts/verify-oracles.sh:126`, `scripts/verify-oracles.sh:194`, `scripts/verify-oracles.sh:279`: real YAML parsing, duplicate rejection, whole-collection parsing and current-byte receipts replace the former partial parser/history-only check. `scripts/verify-context-routes.sh:41` includes branch, index, workspace and untracked paths.
- `packs/load-testing/verify-pack.sh:183` and `tests/run-tests.sh:276`: owned dynamic ports/readiness and exclusive backup paths address the concrete concurrency defects. Root/template changed script hunks are synchronized; the setup helper's identical content was also checked.

## Critical

None identified in this task-scoped review.

## High

None identified in this task-scoped review.

## Medium

### M1 — Setup can report success after importing project modules instead of pip/PyYAML

**Locations:** `scripts/setup-oracles.sh:7`, `scripts/setup-oracles.sh:8`; mirrored at `templates/full/scripts/setup-oracles.sh:7` and `:8`.

The first two Python calls use `-I`; the install and verification calls do not. A caller's cwd or PYTHONPATH can therefore provide `pip.py` and `yaml.py`. A scratch probe invoking the unchanged copied helper from a candidate cwd observed both modules execute and the helper return 0, while the resulting venv's isolated `import yaml` failed with ModuleNotFoundError. This is a false successful dependency setup and reintroduces module selection outside the intended isolated parser environment.

The current workflow calls setup from workspace root, with no candidate working-directory default. This probe does **not** demonstrate a remote CI compromise. The documented local setup path and reusable protected helper are still affected. Use isolated Python for both remaining invocations, including the final version assertion; preserve root/template parity and add a focused setup test covering cwd and PYTHONPATH shadowing.

**Observed evidence:** `/workspace/scratch/adce1c53b293/h02-review-probes/setup-import.json`. No package download occurred: the fake local pip module returned directly.

### M2 — Status timeout leaves verification descendants executing

**Location:** `bin/harness-status.sh:27`–`:29`.

`subprocess.run(..., timeout=...)` kills the immediate make process on timeout, but does not own or terminate its recipe process tree. A finite scratch recipe sleeping 0.4 seconds then writing a marker continued after status returned BLOCKED_TOOL in 0.080 seconds with a 0.05-second configured bound. A real hung test/server can therefore remain alive and consume resources or mutate files after the supposedly bounded status operation ends.

Run verification in an owned process group/session and terminate/reap that group on timeout, with a bounded escalation path. Test that a recipe child cannot create a delayed marker after timeout and that unrelated processes remain untouched. This is ordinary child cleanup, not a request for malicious same-UID confinement.

**Observed evidence:** `/workspace/scratch/adce1c53b293/h02-review-probes/status-timeout.json`.

### M3 — An explicitly configured missing delivery document now silently passes

**Locations:** `scripts/verify-delivery-doc.sh:62`–`:67`; identical template hunk.

The old missing-file branch always blocked. The replacement returns 0 unless DELIVERY_DOC_REQUIRED=1, even when the caller explicitly configured DELIVERY_DOC to a custom runbook. A scratch invocation with `DELIVERY_DOC=custom-release-guide.md` and no such file returned 0 with “no declared runbook.” A typo, deletion or move of an explicitly configured document now disables verification. This weakens an existing fail-closed control and undermines preservation of consumer path customizations.

Distinguish an installation with no default runbook from an explicitly configured source that is missing. At minimum, a nonempty explicit DELIVERY_DOC must remain blocking when unreadable/missing. Keep the legitimate no-runbook scaffold case and mirror the fix.

**Observed evidence:** `/workspace/scratch/adce1c53b293/h02-review-probes/delivery-missing.json`.

## Low

None separately raised.

## Evidence checked and limits

Paths below are under `docs/implementation/2026-09-05-harness-hardening/h02/` unless stated otherwise.

- `preflight/red-preflight-02.stderr.log:30`, `:36`, `:116`, `:118`: seven PASS plus missing version-sync and eight causal failures. Initial exploratory runs were not counted as GREEN.
- `red-01.stderr.log`, `expanded-red-02.stderr.log`, `temp-alias-red-04.stderr.log`, `judge-import-red-05.stderr.log`, `status-detail-red-06.stderr.log`: retained failure summaries match the report's 14, 22, 1, 2 subtest and 1 failure claims. `final-red-06.stderr.log:331`, `:333` records 27 tests/23 failures. The saved final RED test file exactly matches the shipping final H02 test bytes.
- Independently hashed all 29 tests/source/log bindings in `h01-red-receipt.json` and `h02-red-receipt.json`: no mismatch. H01 witness output records nonzero outcomes and unchanged source; local content consistency does not establish independent authority.
- `focal-green-06.stderr.log:30`, `:32`: 27 tests, OK. `core-final-06.stdout.log:340`: 286 passed, zero failed. Final core stderr is empty.
- `core-a-03.stdout.log:340` and `core-b-03.stdout.log:340`: each 286/0. `concurrency-03.json:3` onward records overlapping starts and roughly 37-second runs. The concurrent runs used the earlier explicitly identified stable source, not every final post-concurrency correction; the report discloses this and supplies final focused/core checks afterward.
- `pack-a-03.stdout.log:7` and `pack-b-03.stdout.log:7` onward record distinct WORK directories, owned PIDs and OS ports. Both `:89` summaries show 55/0 and exactly two authenticated omissions. The load source hashes match the final source identity. `readiness-timeout-03.exit:1` is 3, its stderr identifies INCOMPLETE, and `concurrency-03.json` records 0.722 seconds during contention.
- `live-gates-final-06.stdout.log:10`: eight PASS, zero blocking. `lint-final-06.exit:1` is 0 with empty stdout/stderr; `static-final-06.json` records successful syntax/workflow parsing; `diff-check-final-06.exit:1` is 0 with empty output. No unexpected warning/noise was identified in these final GREEN streams; the two load omissions remain coverage limitations.
- Review performed three focused scratch probes only. No package/core/concurrency suite rerun, Git/index/ref mutation, source edit, baseline acceptance or remote operation occurred.
- Additional bounded source reads addressed named risks: workflow setup caller cwd/order; whether the newly target-root-aware Makefile/Agent Note gates had unisolated Python imports (they do not); and oracle control flow cut between supplied hunks. Archived source copies were treated as evidence, not additional shipping code.

**Cannot verify here:** actual Bash3.2/Python3.8 execution (the minimum is explicit, but supplied runs used Python3.12); authenticated load cases; remote required-check execution/adoption; controller full make check/feature promotion/pre-commit gate; owner policy action. These remain controller gates or explicitly documented limits. H04/H06 recovery, later H03–H09 implementation, whole-branch integration, production acceptance and historical claim reconsideration are outside H02 review scope.

**Assessment:** Needs fixes for M1–M3. The architecture and evidence are substantially stronger and the supplied GREEN results are real within their stated scope, but dependency setup can falsely succeed, timed-out status work can continue, and explicit missing-runbook configuration can silently bypass its prior failure.
