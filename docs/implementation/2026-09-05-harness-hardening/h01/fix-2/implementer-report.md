# Independent review fix round 2

### Status

DONE_WITH_CONCERNS. The three High findings in
`/workspace/scratch/adce1c53b293/h01-re-review-1.md` are repaired with focused
pre-effect regressions. The controller's frozen pre-round index is
`f1fa81c07241f1759203d2890e43c84520cc3484`. This round did not stage or alter
that index, feature state, or controller files.

### Changed files in this round

- `scripts/verify-feature.sh`
- `scripts/verify-claims.sh`
- `scripts/verify-decisions.sh`
- `scripts/check-arch.sh`
- `templates/full/scripts/verify-feature.sh`
- `templates/full/scripts/verify-claims.sh`
- `templates/full/scripts/verify-decisions.sh`
- `templates/full/scripts/check-arch.sh`
- `tests/h01-hardening-regressions.py`
- `.superpowers/sdd/migration-plan/task-1-report.md`

### Repairs and permanent coverage

- A ledger's `review_rounds` must now equal the sum of its blocker counts. This
  rejects `review_rounds: 0` with positive blocker history, and every other
  inconsistent accounting record, before execution. The same invariant is
  applied by feature preflight, claims head validation, and claims authority
  validation. The permanent test asserts no feature or claim marker effect.
- Every typed architecture filter is compiled while the entire rules document
  is being validated. An invalid regex returns configuration exit 2 before any
  rule runs, including when the invalid rule follows an earlier marker rule or
  its matcher would return the declared no-match exit. Runtime filtering keeps
  the same command and diagnostic semantics.
- Decision append validation searches for the new heading in the combined head
  bytes, starting after the exact protected prefix. A suffix beginning `##`
  cannot masquerade as a heading when the protected base lacks a final newline.
  A newline/horizontal-rule-separated append remains valid while every base
  byte stays unchanged.

### RED evidence

Evidence is outside the repository at
`/workspace/scratch/adce1c53b293/h01-evidence/review-round2`.

| Command | Result | Logs |
|---|---:|---|
| `PYTHONDONTWRITEBYTECODE=1 python3 tests/h01-hardening-regressions.py` after adding the three initial permanent methods and before source edits | exit 1; 28 tests, 3 assertion failures, 0 errors | `focal-red.stdout.log`, `focal-red.stderr.log`, `focal-red.exit` |
| `H01_SCRIPT_ROOT="$OLD" PYTHONDONTWRITEBYTECODE=1 python3 tests/h01-hardening-regressions.py`, with `$OLD` extracted from frozen tree `f1fa81c...`, after splitting every affected reader/path into an independent method | exit 1; 31 tests, 6 assertion failures, 0 errors | `expanded-frozen-tree-red.stdout.log`, `expanded-frozen-tree-red.stderr.log`, `expanded-frozen-tree-red.exit`, `expanded-frozen-tree-red.sha256` |

`pre-fix.sha256` records the initial test and four root verifier bytes. The expanded frozen-tree run independently exposes feature, claims-head, claims-authority, later-invalid-filter, no-match-filter, and decision-boundary failures against the exact pre-fix tree. There were no runner, import, timeout, or fixture errors.

### GREEN evidence

| Command | Result | Logs |
|---|---:|---|
| `PYTHONDONTWRITEBYTECODE=1 python3 tests/h01-hardening-regressions.py` | exit 0; 31/31 tests; test SHA-256 `3754ec927d52c3d4e051e5e8a5b63a6c76dae5fc357173d85ed3c12b487d8f47` | `freeze-bedd36caa4274691a841ff3e615d211d.json` (atomic command/output capture) |
| shell syntax plus `cmp` for the four changed root/template verifier pairs | exit 0; 9/9 syntax, 4/4 mirrors | `syntax-mirrors-final.log`, `final.sha256` |
| `PYTHONDONTWRITEBYTECODE=1 NO_COLOR=1 make gates` | exit 0; 8 pass, 0 blocking | `make-gates-final.stdout.log`, `make-gates-final.stderr.log`, `make-gates-final.exit` |

The core suite was not rerun because this round added focused contract
validation without changing an existing core interface assertion, as directed
by the controller. The controller owns the next full check.

### Scope and self-review

The changes preserve the round-1 recovery policy, typed argv execution,
filtering results, decision diagnostics, and valid separated append behavior.
They add no authority mechanism, bypass, caller-trust input, installer work, or
repair-only behavior. R11/R12 remain H02; external-witness history resistance
remains H04. `git diff --check` is clean, all changed script mirrors are exact,
and no review bytecode directory was generated.
