# Independent review fix round 3

### Status

DONE_WITH_CONCERNS. The sole remaining High finding in
`/workspace/scratch/adce1c53b293/h01-re-review-2.md` is repaired. The exact
pre-fix index tree was `c54d3abddcca748b74ecddd30084330201fa936a`.
This round changed no feature state, controller file, index entry, or commit.

### Changed files in this round

- `scripts/verify-decisions.sh`
- `templates/full/scripts/verify-decisions.sh`
- `tests/h01-hardening-regressions.py`
- `.superpowers/sdd/migration-plan/task-1-report.md`

### Structural repair

The verifier still requires the complete authority ledger as an exact byte
prefix. It now adds a boundary rule before parsing separators: when a nonempty
protected base does not end in LF (including CRLF), any nonempty suffix must
itself begin with LF or CRLF. Therefore no dash, space, tab, or other separator
byte can extend the protected final line. Separator and heading checks run only
after that document boundary is established.

This is not a dash blacklist. The same condition rejects every first byte that
is not a supported line ending at this boundary. A base that already ends in a
line ending may be followed directly by separator content on the new line. A
base without a final newline may be followed by an LF- or CRLF-prefixed
separator and new level-two decision. All protected base bytes remain exact.

### Permanent test coverage

`test_decision_append_requires_real_line_boundary` now covers:

- direct heading concatenation after a nonterminated base;
- horizontal-rule dashes concatenated to the protected final line;
- spaces/tabs before the suffix's first line ending;
- indented dashes before the first line ending;
- valid LF-prefixed and CRLF-prefixed separated decisions; and
- valid separator content after an already newline-terminated base.

### RED/GREEN chronology and evidence

Every round-three test/gate output uses a new filename inside the unique,
previously unused directory
`/workspace/scratch/adce1c53b293/h01-evidence/review-round3-e356f951049343be8caf753a26c76ab3`.
No earlier evidence file was overwritten.

| Phase / command | Result | Evidence |
|---|---:|---|
| RED: `PYTHONDONTWRITEBYTECODE=1 python3 tests/h01-hardening-regressions.py`, after permanent variants and before source edit | exit 1; 31 tests, 3 assertion/subtest failures, 0 errors | `red.stdout.log`, `red.stderr.log`, `red.exit`, `red-evidence.sha256`, `pre-fix.sha256` |
| GREEN: same focal command after structural repair | exit 0; 31/31 tests | `green-v2.stdout.log`, `green-v2.stderr.log`, `green-v2.exit`, `green-v2-evidence.sha256` |
| shell syntax for nine scripts plus `cmp` of the changed verifier/mirror | exit 0; 9/9 syntax, exact mirror | `syntax-mirror-v1.stdout.log`, `syntax-mirror-v1.stderr.log`, `syntax-mirror-v1.exit` |
| `PYTHONDONTWRITEBYTECODE=1 NO_COLOR=1 make gates` | exit 0; 8 pass, 0 blocking | `gates-v1.stdout.log`, `gates-v1.stderr.log`, `gates-v1.exit` |
| `git diff --check` | exit 0 | `diff-check-v1.stdout.log`, `diff-check-v1.stderr.log`, `diff-check-v1.exit` |

A first GREEN wrapper command contained an unmatched shell quote and stopped
before launching the runner. It produced no test result and was not treated as
RED or GREEN. `wrapper-error-v1.observation.txt` records the exact observed
wrapper error; the corrected invocation used the untouched `green-v2.*` names.

Final artifact hashes:

- permanent test: `643119db4c33129246270813bad647c2e21a175d4b58140e7a96d604d29c0e21`
- root decision verifier: `a3b10de295e4839995cc4300e0d15e028da937c54b86b46727211aa5e24644f0`
- full-template mirror: `a3b10de295e4839995cc4300e0d15e028da937c54b86b46727211aa5e24644f0`

The full hashes are retained in `final-artifacts-v1.sha256`. No core, load, k6,
or full-suite run was performed, as directed; the controller owns full-check
verification.

### Remaining limitations

This round changes only append-boundary recognition. It does not add support
for bare-CR line endings; the supported boundaries are LF and CRLF. H02
installer/re-earning work, H04 external history authority, H06 recovery grants,
historical F09 interpretation, and external consumer rollout remain unchanged
and outside this round. No generated review `__pycache__` exists.
