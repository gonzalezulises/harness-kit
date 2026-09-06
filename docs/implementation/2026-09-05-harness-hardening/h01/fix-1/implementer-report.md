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

---

## Independent review fix round 1

### Status

DONE_WITH_CONCERNS. All six High findings in
`/workspace/scratch/adce1c53b293/h01-review-1.md` are repaired within H01, with
permanent marker regressions and no H02 implementation. The reviewed pre-fix
source is the frozen index tree
`0ca1ec165e699b155ed4498e6743cf8f4191874b`; the working-tree implementation
below is intentionally left unstaged for controller review.

### Round-1 changed files

- `scripts/verify-feature.sh`
- `scripts/verify-claims.sh`
- `scripts/verify-decisions.sh`
- `scripts/check-arch.sh`
- `templates/full/scripts/verify-feature.sh`
- `templates/full/scripts/verify-claims.sh`
- `templates/full/scripts/verify-decisions.sh`
- `templates/full/scripts/check-arch.sh`
- `.harness/arch-rules.json`
- `templates/full/.harness/arch-rules.json`
- `tests/h01-hardening-regressions.py`
- `tests/run-tests.sh`
- `.harness/oracles/AC-H01-fail-closed-verifiers.yaml`
- `.agents/notes/implemented/bug-fix/2026-09-05-verifiers-fail-before-effects.md`
- `.superpowers/sdd/migration-plan/task-1-report.md`

The controller-owned feature state, `DECISIONS.md`, `PROGRESS.md`, plan/ledger,
and implementation index were not edited by this fix round. The rollout
inventory below was supplied by the controller and was read only.

### Repairs

1. `verify-feature` now treats any positive recorded review-round count as
   insufficient recovery authority. It restores `blocked`, exits policy code 5
   with `RECOVERY_AUTHORITY_REQUIRED`, preserves configured maxima and every
   receipt, and performs no layer effect. This holds after `blocked -> active`,
   raised maxima, or removed budgets. A fresh budgeted first run still works.
2. Explicit ledgers in feature and claims inputs must be non-null mappings
   containing both `review_rounds` and `blockers`. Empty, partial, and null
   ledgers fail complete preflight before marker execution.
3. All three command readers reject NUL-bearing strings before producing an
   execution channel. Feature label/command/repair reads now use the same
   trailing-newline sentinel as claims and architecture metadata.
4. Decision authority is protected as an exact byte prefix. The verifier no
   longer generates lossy slug filenames, normalizes CRLF, or removes
   syntax-blind trailing separators; collision and newline conversions fail.
5. `check-arch` no longer infers grep behavior from a substring. Legacy Bash
   command strings require exit 0. The explicit `match_argv` object declares
   `match_exit` and `no_match_exit`, executes argv without shell parsing, and
   can apply ordered include/exclude regex filters. The shipped rules use this
   typed contract instead of shell pipelines ending in `|| true`.
6. Every JSON reader uses a duplicate-detecting `object_pairs_hook`, including
   feature writers and claims authority input. Permanent marker cases cover
   root, feature, layer, budget, ledger, and blocker depths plus both claims
   readers and architecture rules.
7. The integrated focal runner keeps its temporary output and prints it on
   failure, so a failed regression is no longer reduced to a group label.

### RED-before-source-fix evidence

Evidence is outside the repository under
`/workspace/scratch/adce1c53b293/h01-evidence/review-round1`.

| Command | Exit / assertions | Logs |
|---|---:|---|
| `PYTHONDONTWRITEBYTECODE=1 python3 tests/h01-hardening-regressions.py` against unchanged round-0 working source, before the six repairs | 1; 24 tests, 17 assertion failures, 0 errors | `focal-red-all-readers.stdout.log`, `focal-red-all-readers.stderr.log`, `focal-red-all-readers.exit` |
| `for f in verify-feature.sh verify-claims.sh verify-decisions.sh check-arch.sh; do git show ":scripts/$f" > "$OLD/scripts/$f"; done` then `H01_SCRIPT_ROOT="$OLD" PYTHONDONTWRITEBYTECODE=1 python3 tests/h01-hardening-regressions.py` against the frozen reviewed index source | 1; 25 tests, 26 assertion/subtest failures, 0 errors | `permanent-suite-frozen-index-red.stdout.log`, `permanent-suite-frozen-index-red.stderr.log`, `permanent-suite-frozen-index-red.exit`, `frozen-index-source-2.sha256` |

A final direct typed-matcher launch probe was then added before its repair: `PYTHONDONTWRITEBYTECODE=1 python3 tests/h01-hardening-regressions.py` exited 1 with 25 tests, 1 assertion failure, and 0 errors (`typed-launch-red.stdout.log`, `typed-launch-red.stderr.log`, `typed-launch-red.exit`). It proved that a missing executable could otherwise leave the declared exit contract without a result.

The second run is the final permanent suite, including all duplicate-key depths
and partial/null claim-ledger cases, executed against the exact pre-fix script
bytes extracted from the frozen index. Failures are real unittest assertions;
there are no import, runner, or fixture errors.

### GREEN evidence

| Command | Exit / assertions | Logs |
|---|---:|---|
| `PYTHONDONTWRITEBYTECODE=1 python3 tests/h01-hardening-regressions.py` | 0; 25/25 tests | `focal-green-final.stdout.log`, `focal-green-final.stderr.log`, `focal-green-final.exit` |
| `PYTHONDONTWRITEBYTECODE=1 NO_COLOR=1 bash tests/run-tests.sh` | 0; 283 passed, 0 failed | `core-green-final2.stdout.log`, `core-green-final2.stderr.log`, `core-green-final2.exit` |
| shell syntax for nine scripts plus `cmp` for four verifier mirrors and the architecture config mirror | 0; 9/9 syntax, 5/5 exact mirrors | `syntax-mirrors-final.log`, `final-artifacts.sha256` |
| `PYTHONDONTWRITEBYTECODE=1 NO_COLOR=1 make gates` | 0; 8 pass, 0 blocking | `make-gates-final2.stdout.log`, `make-gates-final2.stderr.log`, `make-gates-final2.exit` |

No load/k6 suite was run in this round; the controller owns the full check.

### Existing expectations replaced

- A first budgeted failure now leaves the feature `blocked`. A second local
  invocation expects exit 5 and `RECOVERY_AUTHORITY_REQUIRED`; it no longer
  expects the portable verifier to consume a second attempt and reach the
  review-round ceiling without a verifiable grant.
- The blocked-state edit test now also raises the maximum and still expects no
  marker effect, unchanged receipts, restored `blocked`, and policy exit 5.
- The repeated-blocker ceiling is tested when the current valid first attempt
  reaches a configured ceiling of one. This preserves observable ceiling
  behavior without granting an untrusted retry.
- The old “success after a failed attempt” fixture now asserts that editing the
  command and state cannot manufacture a green recovery. The fresh first-run
  success case remains explicit.
- The general failure fixture now expects a budgeted first failure to become
  blocked. Its separate `exit 3` command case clears the fixture ledger and
  reactivates it so the original assertion still tests that repair guidance is
  printed after a real first-run command exit.
- Decision tests still require the affected heading in diagnostics; exact-byte
  comparison derives that heading only for explanation and never for identity.

The historical F09 text/evidence describes two legacy attempts reaching a
ceiling. That receipt remains immutable but does not certify H01's conservative
recovery rule. The new behavior belongs to F15. Neither this suite update nor a
future H06 runtime grant retroactively authorizes the v1 retry recorded by F09.

### Rollout and compatibility evidence

`docs/implementation/2026-09-05-harness-hardening/h01/rollout-inventory.json`
records the current kit worktree (`feature_list.json`: 23 features) and the only
feature-list template (`templates/minimal/feature_list.json`: 2 features).
Both have zero duplicate IDs and zero multiline layers. There is no separate
`templates/full/feature_list.json`, and no external consumer was inventoried;
this is targeted kit/template evidence, not a blanket migration claim.

The root and full-template verifier bytes are exact mirrors. The live root and
full-template architecture configs are also exact and both use `match_argv`.
This pairing matters to H02: a judge copied from protected base bytes and a live
installed configuration must understand the same structured rule contract.
H01 supplies the matching source/template artifacts; it does not implement or
claim H02 installer wiring.

### Known boundary and self-review

The compatibility cost of the approved conservative choice is explicit:
legacy budgeted retries stop after their first recorded failure until a verified
recovery grant exists. Remaining budget is not reported as exhaustion. Local
hashes, edited state, edited maxima, or removed budgets do not grant authority.
H04/H06 may restore bounded continuation through the adopted verified runtime,
but do not retroactively authorize this portable v1 path.

H01 cannot detect total erasure or replacement of untrusted local history. A
stronger anti-tamper statement requires H04's external authority/witness. No
local hash/grant, bypass flag, trust boolean, or replacement state platform was
added.

R11 full-installer behavior and R12 repair-only re-earning remain H02 scope and
were not claimed green. The implementation retains valid CLI forms and Bash
semantics for legacy architecture strings, while requiring a structured exit
contract where nonzero is a legitimate matcher result. `git diff --check`,
syntax, mirrors, focal tests, core tests, and quick gates are clean. No generated
review `__pycache__` remains.
