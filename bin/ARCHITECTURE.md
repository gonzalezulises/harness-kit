# bin/ — architecture

Two executables, no shared library. They are deliberately independent: the auditor must
run standalone over `curl | bash` in a repository that has never seen this kit, so it
cannot source anything.

## harness-audit.sh

Read-only. Never writes to the target repository.

**Check registry.** Six parallel arrays (`CHK_ID`, `CHK_SEV`, `CHK_GROUP`, `CHK_DESC`,
`CHK_RES`, `CHK_FIX`) instead of one array of structs. why: bash 3.2 ships on macOS and
has no associative arrays. The same constraint rules out `${var,,}` and `local -n`.

**Stable denominator.** Every `critical`/`recommended` call is unconditional. A check whose
prerequisite is missing records `fail`, it does not skip. why: the upstream script skipped
checks, so its totals drifted between 65 and 70 and two repos could not be compared. If you
add a check inside an `if`, you break score comparability — record it in both branches.

**Predicates never fail the script.** `set -e` is on, so every predicate ends in
`&& echo pass || echo fail` and returns 0. A predicate that exits non-zero kills the audit
halfway through and reports a falsely low score.

**`routed_contains`** searches the entry file *and* `docs/**.md`. why: the kit tells users
to keep `AGENTS.md` short and link out; penalising them for doing so would be incoherent.

## harness-init.sh

Writes. Guarded by `--dry-run` and by never overwriting without `--force`.

**Template rendering** substitutes `{{PLACEHOLDER}}` tokens via python3, falling back to
`sed`. why: purposes and commands can contain characters that break `sed` delimiters.

**Command detection** reads the real project manifest — `package.json` scripts, `uv.lock`
vs `poetry.lock`, `Cargo.toml`, `go.mod` — rather than assuming. A harness whose verify
command is wrong is worse than no harness: agents will run it, watch it fail, and learn to
ignore it.

**The full level composes AGENTS.md** from `templates/minimal/AGENTS.md` plus
`templates/full/AGENTS-appendix.md`. why: one source of truth for the base contract. Do not
fork a second full copy — they will drift.
