# H02 preflight — read-only preparation

Status: READY_FOR_GO. Inspected checkout only; no checkout files, Git index, refs or HEAD changed. All writes and fixture Git operations are under `/workspace/scratch/adce1c53b293/h02-preflight-evidence/`. Controller completed startup and owns publication, integration, state and commits. No broad `make check`, account/API preflight, network retry or subagent was started.

Read: task-2-brief, AGENTS.md, DECISIONS.md, context routes, current quality document, archived findings R10–R12/R14–R22, affected root/template verifier sources, initializer, status, hook, core tests, load pack tests/resolver, required workflow and oracle/Agent Note contracts. TDD skill applied: production fixes must follow witnessed failing assertions.

## Witnessed preparation RED

`python3 h02-preflight-evidence/red-probes.py` (absolute scratch path) exits 1 with **8 assertion failures, no test errors**. Complete subprocess commands/stdout/stderr/exits are in `red-preflight-02/commands.json`; suite streams/exits have the same unique prefix. `source-hashes.json` binds the inspected production files. The suite and fixtures never write inside the live checkout.

1. Configured full scaffold: exactly **7 quick PASS, version-sync NOT_EXECUTED**.
2. `repair` prose changes with identical command: blocked with WEAKENED_VERIFICATION and exit 5.
3. Formatter exit 9: hook exits 0.
4. Partially staged document: unrelated workspace text enters Git index.
5. Uncommitted governed source: routes returns success/no changes.
6. Duplicate oracle `status` key: accepts last RETIRED and exits 0.
7. Harness with failing local check: status still returns READY_LOCAL/0.
8. Deployment statuses API failure: resolver returns 0 and says preview absent.

The first exploratory run (`red-preflight-01`) is retained, not overwritten. Two fixtures were corrected before run 02: setup needed a real recipe to isolate version-sync; the unrelated marker originally contained the formatter's replacement substring. Run 02 is the clean causal RED evidence.

## Complete implementation/testing approach after GO

### Live applicability and protected judgment (R10/R11)

Introduce a versioned installation profile with explicit installation kind and applicability for every registered gate. Kit version synchronization applies to the kit; a full consumer installs every universal full-harness gate. Absence of a required gate blocks. Inapplicable gates report that declared reason, never silently become optional. Minimal installation remains an explicitly limited contract scaffold and must not advertise full local mechanical readiness. Preserve custom paths and existing no-overwrite behavior.

Add quick gate execution to `make check`; separate the fixture/pack target from integrated verification so `full` invokes quick once plus claims and the fixture pipeline, with no `full → make check → full` recursion. Keep target names/legacy shell commands compatible where possible. Add a dedicated profile/runner contract test exercising a real scaffold and live malformed policy.

Required workflow proposal: full-history exact head and exact protected base in physically separate checkouts; invoke base judge scripts against head via an explicit target-root interface. Protected profile/registry/config come from base and head cannot choose a judge or remove required gates. Record base/head/judge identities and add a live-gates observed-zero sentinel. Missing base profile/new typed contract is an explicit adoption stop, never fallback to head. No copying judge scripts over candidate source. Workflow remains a draft-PR proposal; no protection/merge/deploy changes.

Tests: unknown/malformed/missing profile; unknown/inapplicable gate; missing required universal gate; consumer no version-sync requirement; kit version-sync drift; base/head profile downgrade; mutated candidate judge ignored; missing protected adoption contract stops; candidate source remains byte-identical; real live gate failure blocks integrated check; bounded recursion test.

### Verification identity (R12)

Change only layer identity comparison to exclude `repair` guidance while retaining exact command bytes and all other contract inputs/environment fields. Do not introduce caches, benign-command whitelists, normalization, or authority fallback. Validate guidance as text as H01 already requires. Run permanent H01 tests unchanged plus targeted guidance/command/input/environment identity fixtures; mirrors stay identical.

### Isolation and bounded infrastructure (R14)

Move clean-state backup under the existing exclusive `$WORK`. Replace six fixed load-pack ports with servers bound to port 0, publish assigned endpoint only after actual readiness, bounded process-aware readiness polling, and cleanup/wait only owned server PIDs. Keep every existing assertion and threshold. Add controlled readiness failure and kit contention timeout fixtures. Execute two core suites concurrently and two load-pack suites concurrently with complete distinct logs and timings; preserve two explicit authenticated-gh coverage omissions. This is kit contention evidence, not a reproduction of the unavailable historical Aurobalance fixture.

### Staged hook transaction (R15)

Run formatting against an isolated index snapshot. On success update only selected staged blobs, preserving index modes and unrelated/partially staged working-tree bytes; on formatter failure leave index/worktree intact and block with exact mechanical rerun guidance. Use NUL-safe paths and verify index has not changed before replacement. Run index whitespace/Agent Notes checks against the staged snapshot. Cover partially staged files, formatter nonzero after modifying a scratch file, filenames with spaces/newlines, executable mode, and ordinary successful formatting.

### Strict oracle/read-current-workspace gates (R16–R18)

Replace the ad-hoc YAML reader with a strict standard safe YAML parser, duplicate-key rejection, explicit allowed shapes/types and malformed/unknown-tag/multiline handling. Declare the parser dependency truthfully. Validate the complete oracle collection before verdict. For each proof compare actual workspace test bytes to witnessed hashes or the proved tree, including staged/untracked replacements; missing history is INCOMPLETE, never presumed valid. A RED receipt binds actual test/source hashes, command, nonzero exit and stored logs; label its local witness limits explicitly (content consistency is not cryptographic independent authority). Existing preserved H01 evidence can supply its receipt without changing historical logs. Add H02 oracle before source fixes and bind complete RED evidence.

Context routes: validate typed map; collect union of committed branch, index, working-tree and untracked paths with NUL-safe Git results; read current Agent Note bytes; reject unresolved explicit base and Git failures. Replace root business placeholders with actual kit subsystem routes. Consumer templates route only their shipped governance paths, leaving domain additions explicit.

Tests: YAML duplicates, scalars/containers/unknown status/tags, multiline valid standard YAML, missing refs/test files, staged/untracked/current-byte mutation, forged or altered local receipt, positive preserved proof; context tracked/staged/untracked and citation cases, malformed maps and unavailable base.

### Delivery/status/prerequisites/current docs (R19–R22)

Make readiness require an observed successful local check with bounded execution, then separately report remote protection observations. Validate ruleset contents/applicability rather than names; unknown API/auth/access outcomes are indeterminate and non-ready. Local readiness must never say that a bad merge is impossible. Keep CLI compatibility and clear exit states.

Propagate deployment statuses failures across retries: a successful complete query can resolve the state, but an incomplete last attempt cannot claim no preview. Validate retry arguments and retain authenticated omissions. Delivery verifier should use current workspace migration paths, strict version reads, and fail when a required delivery baseline/config cannot be determined. Kit-only version checker must validate its required kit inputs.

Document core versus full prerequisites (bash/Python/parser versus Node/k6 and authenticated optional coverage), `init.sh`'s actual core scope, five bin entrypoints, explicit installed/applicable/observed capabilities, profile adoption stop and local receipt limits. Update current README/architecture/quality/template docs; do not edit archived audit artifacts or F09 contracts/receipts.

## Integration boundary and material choices

No unresolved need for user permission. Before writing production code, the controller must supply GO plus published H01 SHA as requested. The controller owns state/ledger updates, full check, staging and commits. I will provide a short proposed append-only decision text for any profile/YAML/receipt contract choices so the controller can record them; I will not edit DECISIONS.md.

Potential dependency/compatibility costs to document, not conceal: strict YAML needs PyYAML; minimal does not become full mechanically enforced; current protected base lacks the new profile/judge interface, so first adoption is deliberately blocked until trusted policy is adopted; local witnessed receipts cannot authenticate malicious same-UID authors; hook snapshot formatting may leave a reviewed staged formatting diff relative to the working copy while preserving user edits.

Durable final report after GO: `.superpowers/sdd/migration-plan/task-2-report.md`, status, changed files, exact source/test hashes, unique complete RED/GREEN logs, commands/exits and boundaries. Explicit source/test/report freeze before DONE. Controller runs full integration only after independent review.
