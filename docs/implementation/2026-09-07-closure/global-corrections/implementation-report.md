# Scoped GR01 / GR02 / GR04 correction report

Worktree: `/workspace/scratch/adce1c53b293/harness-judge-target`.
Exact source parent and observed RED HEAD: `0a51623b5db42951a6091847a179262182abd67d`.
The root-owned adopted-main merge/index/ref was not changed. No commit, staging,
network access, real credential operation, subagent or full `make check` was run.
This report concerns bounded local correction evidence, not full acceptance.

## Production changes

All production changes are confined to
`packs/autonomy/repo-template/scripts/quality-orchestrator/`:

- `journal.mjs`: private `claimExecution` uses the existing filesystem lock and
  reducer and returns created/retrieved distinction. The public append wrapper
  still returns exactly the original frozen `APPENDED` receipt. Stored schemas
  and `JOURNAL_RUNTIME_BINDING` are unchanged.
- `execution.mjs`: only the creator of the durable reservation dispatches. A
  losing identical caller returns the existing pending identity with local
  `execution: NOT_EXECUTED`; it does not invent an observation. An interrupted
  owner retains the original charged uncertain key and never redispatches.
- `release.mjs`: an internal closed validation reloads objective approval,
  applicable action approval and prerequisite-derived next obligation after
  asynchronous preflight, under ownership immediately before fresh reservation.
- `review.mjs`: standalone and release review validate policy/catalog/shadow
  through their own closed owner checks. Catalog checks its own request/pins.
  No public caller-selected or host-supplied verification callback was added.
- `capabilities.mjs`: output accumulation uses a null-prototype dictionary and
  requires the exact closed operation output-key set before constructing a
  permit. The original null-prototype inventory/frozen-file fix is unchanged.

Current source hashes: `docs/implementation/2026-09-07-closure/global-corrections/source-manifest.json`.

## New test/oracle files

- `packs/autonomy/repo-template/scripts/quality-orchestrator/tests/closure-global-corrections.test.mjs`
- `packs/autonomy/repo-template/scripts/quality-orchestrator/tests/closure-fixtures.mjs`
- `packs/autonomy/repo-template/scripts/quality-orchestrator/tests/closure-process-worker.mjs`
- `.harness/oracles/AC-closure-supervisor.yaml`

The oracle and tests were written before production changes. No existing test,
oracle, historical receipt, preserved snapshot or binding was edited. The three
new test/helper/worker files have identical hashes in RED and GREEN receipts.

The cross-process case starts two real child controllers sharing the exact
signed request and real journal. Both pause after seeing absence and before
object publication. Releasing one then the other reproduced two POST attempts
against one debit on defective code and one POST against one debit after the fix.
A separate real-process death at the durable-intent-before-POST boundary retains
uncertainty, with zero POST attempts on original-key resume.

Eight deterministic expiry cases cover deploy, rollback, readback,
artifact-acceptance, release objective, standalone and release review policies,
and prerequisite slice evidence. Only that evidence expires during the final
preflight response, while the execution budget and accepted context stay valid.
The two literal-output cases cover canonical and derived batches with real byte
changes, exact output sets, complete file/frozen scope, delta, postconditions and
one category/total debit.

## Executed validation

Exact new-suite command, run first RED then unchanged GREEN:

```sh
node --test packs/autonomy/repo-template/scripts/quality-orchestrator/tests/closure-global-corrections.test.mjs
```

- RED: observed exit 1; 12 tests, 11 failed and 1 passed; 159425.718255 ms.
  Failures are causal assertions: two starts/one debit, eight expired-authority
  starts, literal canonical verified no-op, and omitted derived literal target.
- GREEN: observed exit 0; 12 tests, 12 passed and 0 failed; 179164.053738 ms.
- Syntax: `node --check` on each of the five production files above; 5/5 exits 0.
  Exact argv/results are in `docs/implementation/2026-09-07-closure/global-corrections/syntax.json`, with `docs/implementation/2026-09-07-closure/global-corrections/syntax.log`.
- Affected legacy suites: observed exit 0; 150 tests, 150 passed and 0 failed;
  317837.459938 ms. They ran serially because the existing capabilities suite
  temporarily changes/restores dependency bytes for runtime-binding verification.
- Original unchanged frozen-filename regression: observed exit 0; 2 tests,
  2 passed and 0 failed; 3174.520026 ms. Exact command:
  `node --test packs/autonomy/repo-template/scripts/quality-orchestrator/tests/literal-filename.test.mjs`.
- Total post-fix runtime regressions: 164 passed, 0 failed, 0 skipped. This is
  scoped verification, not a full repository check.

Exact legacy command:

```sh
node --test --test-concurrency=1 packs/autonomy/repo-template/scripts/quality-orchestrator/tests/journal.test.mjs packs/autonomy/repo-template/scripts/quality-orchestrator/tests/execution-backend.test.mjs packs/autonomy/repo-template/scripts/quality-orchestrator/tests/release.test.mjs packs/autonomy/repo-template/scripts/quality-orchestrator/tests/review.test.mjs packs/autonomy/repo-template/scripts/quality-orchestrator/tests/capabilities.test.mjs
```

Initial dependency import failure is retained separately in
`docs/implementation/2026-09-07-closure/global-corrections/environment-attempt.log`; it is not the causal RED. Root provisioned
existing local yaml/zod dependencies from the exact byte-matching lockfile,
without network or install scripts, before the actual RED command.

## Receipts and hashes

- RED receipt: `docs/implementation/2026-09-07-closure/global-corrections/red-receipt.json`
  SHA256 `bc353e1958319e4cdee0a114b1846004886410fbeb21def00dad7145db32d8b7`.
- RED log: `docs/implementation/2026-09-07-closure/global-corrections/red.log`
  SHA256 `4ad8c73b55c0f8640fe750ce473b410b65b4ed2868fef02ceccdfcdc1539d67d`.
- Defective source: `docs/implementation/2026-09-07-closure/global-corrections/red-source/`;
  all 19 preserved module/package-file hashes are bound in the RED receipt.
- GREEN receipt: `docs/implementation/2026-09-07-closure/global-corrections/green-receipt.json`
  SHA256 `f9ea4a989289e6e63f2ae2f010c8b699f4ef39243ae37b8f41a7990c853b5177`.
- GREEN log: `docs/implementation/2026-09-07-closure/global-corrections/green.log`
  SHA256 `95b34f657c43762d782c82714eb43eb0836359853c027d79dc867a2f9f2e604c`.
- Current source manifest: `docs/implementation/2026-09-07-closure/global-corrections/source-manifest.json`
  SHA256 `9655863a24b77026c228397161cc581cb2d530cf04a5362f2793e4141da31342`.

- Legacy GREEN receipt: `docs/implementation/2026-09-07-closure/global-corrections/legacy-green-receipt.json`
  SHA256 `277bff02c7e2ea68be7cce4ff4ccad9bdc4e4dcc584729ee909cc38195e12c55`.
- Legacy GREEN log: `docs/implementation/2026-09-07-closure/global-corrections/legacy-green.log`
  SHA256 `d7a43e11fb565b2250581d8d3b673cc012be97be3a9b81aa2e49df80b32bc51d`.
- Original frozen-file GREEN receipt: `docs/implementation/2026-09-07-closure/global-corrections/literal-frozen-green-receipt.json`
  SHA256 `72b9d58159a5f0b7cb39d4418e1809aaaa7c870f3a32112e4b363ae7ab4b1da9`.
- Original frozen-file GREEN log: `docs/implementation/2026-09-07-closure/global-corrections/literal-frozen-green.log`
  SHA256 `f8604e2f5f2f7735ab2511e5575bdabff2b5b83038dc9f5bd5db8bba2cfb0706`.
- Validation summary: `docs/implementation/2026-09-07-closure/global-corrections/validation-summary.json`.
- Existing-test byte integrity: `docs/implementation/2026-09-07-closure/global-corrections/legacy-test-integrity.json`;
  all six affected legacy test files match exact PR33 bytes.

All four receipts' test/source/log hashes were rechecked after final verification
and match. RED source/test/log hashes remain identical to the pre-fix receipt.
These receipts establish local content consistency; they are not independently
authenticated execution authority.

## Required root-owned documentation and limits

The supervisor contract must require action-specific authority/prerequisite
revalidation immediately before the actual remote effect, separate from its
execution budget. Release descriptors bind objective identity and applicable
action approval; they do not contain the objective approval envelope or all
prerequisite records. The supervisor must have independently authoritative
access to those records. Review requires its policy/catalog/exact binding;
readback has distinct original-deployment authorization; catalog does not acquire
a release/deployment approval requirement. Root owns the contract/doc updates,
Agent Note, integration, feature state, full verification and any publication.

GR03 protected CI isolation and GR05 integration/proof ancestry policy are
explicitly untouched and are not closed by these tests. All fixtures are local
engineering evidence only. No live supervisor, authenticated Codex execution,
actual deployment/readback, smoke/observability, consumer acceptance, signed
baseline acceptance or production readiness is claimed. Independent scoped
re-review and the root's full verification remain outstanding.
