# Task 1 report — H01 fail closed before effects

## Status

DONE_WITH_CONCERNS. H01 closes the selected R01–R09 and R13 regressions. R11
(full installer wiring) and R12 (repair-only re-earning) remain deliberately
RED for H02. No H02 behavior, autonomy pack, deployment, feature state, or
controller ledger was changed here.

Base observed before implementation:
`9ee4eaaf6b19ded4b5e32349d77ba8fdaf6af79e` on
`review/harness-hardening-autonomy`.

## Changed files

- `scripts/verify-feature.sh`
- `scripts/verify-claims.sh`
- `scripts/verify-decisions.sh`
- `scripts/check-arch.sh`
- `templates/full/scripts/verify-feature.sh`
- `templates/full/scripts/verify-claims.sh`
- `templates/full/scripts/verify-decisions.sh`
- `templates/full/scripts/check-arch.sh`
- `tests/h01-hardening-regressions.py`
- `tests/run-tests.sh`
- `.harness/oracles/AC-H01-fail-closed-verifiers.yaml`
- `.agents/notes/implemented/bug-fix/2026-09-05-verifiers-fail-before-effects.md`
- `.superpowers/sdd/migration-plan/task-1-report.md`

The controller-owned `DECISIONS.md`, `PROGRESS.md`, `feature_list.json`,
`docs/implementation/`, task brief, and task plan were read but not edited by
this task.

## Implementation

- `verify-feature` validates the complete feature-list root, feature and layer
  objects, unique non-empty IDs, known states, evidence arrays, non-empty
  commands, budget integer bounds, stop conditions, and ledger records before
  creating executable layer records. It requires exactly one active feature.
- Layer label, command, and repair values travel in separate files rather than
  TSV. Multiline commands remain intact and repair text has no execution path.
- Blocked or exhausted work stops before a layer. Editing `blocked` to `active`
  with an exhausted ledger restores `blocked`, preserves the ledger, and exits
  with the existing budget code. A later valid success preserves prior attempt
  receipts rather than erasing them.
- `verify-claims` validates head and explicit base inputs before layers. An
  absent base is accepted only after a resolved Git tree proves
  `feature_list.json` did not exist there. Each declared command executes at its
  point in sequence; no arbitrary command result is cached by text.
- `verify-decisions` rejects missing/unresolvable explicit authority, proves
  genuine ledger absence from a resolved tree, and compares prior decision
  entry bytes exactly except for the separator after an entry. Indentation,
  tables, code, and prose whitespace are therefore protected.
- `check-arch` validates the complete root/rules contract before execution,
  rejects duplicate IDs and unknown expectations, preserves each real command
  exit, and maps invalid configuration to `NOT_CONFIGURED` (exit 2).
- All four template mirrors are byte-identical to the root scripts.
- The permanent H01 runner selects only R01–R09/R13 from the immutable review
  probes. The critical oracle cites their committed bytes and the actually
  observed RED commit; its `proved_sha` was not synthesized from a later green.

## RED evidence

All evidence is outside the repository under
`/workspace/scratch/adce1c53b293/h01-evidence`.

| Command | Exit / assertions | Log or result |
|---|---:|---|
| `python3 docs/reviews/2026-09-05-harness-hardening/red_regressions.py --repo . --output /workspace/scratch/adce1c53b293/h01-evidence/review-red` | 1; 8 methods, 11 assertion failures, 0 errors | `review-red.stdout.log`, `review-red/results.json` |
| `python3 docs/reviews/2026-09-05-harness-hardening/local_red_regressions.py --repo . --output /workspace/scratch/adce1c53b293/h01-evidence/local-red` | 1; 3 methods, 3 assertion failures, 0 errors | `local-red.stdout.log`, `local-red/results.json` |
| `python3 docs/reviews/2026-09-05-harness-hardening/supplemental_state_red.py --repo . --output /workspace/scratch/adce1c53b293/h01-evidence/state-red` | 1; 3 methods, 3 assertion failures, 0 errors | `state-red.stdout.log`, `state-red/results.json` |
| `python3 tests/h01-hardening-regressions.py` before verifier edits | 1; 12 selected methods, 15 assertion failures, 0 errors | `focal-red.stderr.log` |
| `NO_COLOR=1 bash tests/run-tests.sh` after adding blocked→active assertion and before its repair | 1; 280 passed, 1 assertion failure | `core-reopen-red.log` |

`pre-source.sha256` records all three review-test hashes and all four unchanged
verifier hashes before the first RED commands. `focal-tests-preimplementation.sha256`
records the permanent runner and oracle bytes before verifier implementation.

## GREEN evidence

| Command | Exit / assertions | Log or result |
|---|---:|---|
| `PYTHONDONTWRITEBYTECODE=1 python3 tests/h01-hardening-regressions.py` | 0; 12/12 selected methods | `focal-green-final.stderr.log` |
| `PYTHONDONTWRITEBYTECODE=1 NO_COLOR=1 bash tests/run-tests.sh` | 0; 281 passed, 0 failed | `core-green-final.log` |
| `PYTHONDONTWRITEBYTECODE=1 python3 docs/reviews/2026-09-05-harness-hardening/supplemental_state_red.py --repo . --output /workspace/scratch/adce1c53b293/h01-evidence/state-post-h01` | 0; 3 methods, 0 failures/errors | `state-post-h01/results.json` |
| `PYTHONDONTWRITEBYTECODE=1 NO_COLOR=1 make gates` | 0; 8 PASS, 0 blocking | `make-gates.log` |
| shell syntax plus `cmp` for all four root/template pairs | 0; four mirrors exact | command output empty |

The full post-H01 review runner exits 1 with only
`test_08_repair_only_change_can_reearn_identical_commands` failing
(`review-post-h01/results.json`). The full local runner exits 1 with only
`test_11_full_scaffold_must_supply_its_required_gates` failing
(`local-post-h01/results.json`). These are the expected H02 residuals, not H01
failures. All post-run error counts are zero.

Focused gate evidence in `focused-gates.log`: 8 historical decisions intact
and one appended, 4 architecture rules hold, 17 Agent Notes well formed, and
AC-H01 is TEST_READY with a live falsification proof.

## Existing expectations updated

- The budget fixture now removes unrelated active fixture state before adding
  its test feature, so WIP=1 is satisfied and each budget assertion isolates the
  intended behavior.
- A successful run after one failed attempt expects the ledger to retain one
  spent review round. Erasing it contradicted the reviewed persistence rule.
- Three identical claim declarations now expect three executions. Command text
  does not identify mutable filesystem or environment inputs.
- A multiline valid layer and a non-executable repair marker were added. No
  prior assertion was removed or skipped.

## Spec and quality self-review

The implementation keeps the existing CLI forms and successful behavior for
valid active features, valid claims, append-only decisions, and valid
architecture rules. Configuration and authority failures now use registry
states where the scripts participate in `run-gates`; no bypass flag or trusted
caller boolean was added. Writes to feature state use an atomic same-directory
replace.

The main compatibility cost is intentional: callers with malformed legacy JSON
must repair it before any partial verification, exact duplicate claim commands
run repeatedly, and whitespace edits to protected decision content require an
appended superseding entry. The legacy scripts still execute declared commands
with `eval`; replacing the execution model belongs to later closed-capability
milestones.

The load/k6 portion of `make check` was not run here, per task instruction. The
controller will run the full check and independent review before commit. The
generated review `__pycache__` directory was removed, and the permanent runner
sets `sys.dont_write_bytecode`.
