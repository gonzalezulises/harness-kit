# bin/ — architecture

Six executables with separate responsibilities. The auditor remains independent: the auditor must
run standalone over `curl | bash` in a repository that has never seen this kit, so it
cannot source anything.

## harness-consumer.py

Builds and inspects the single `autonomy-runtime.v1` offline bundle, then creates
read-only plans and applies exact digest-approved install, upgrade, verify and
rollback operations inside `.harness/distribution/`. Source identity is declared
separately from observed Git lineage; local candidates never assert publication or
human adoption. Exact plans also declare the effective Git-dir lock path; apply uses
that unlinked regular file for process ownership and revalidates before selection.
CI authority must execute this checker from a protected source
outside the candidate checkout.

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

## harness-activate.sh

Coordinates scaffold installation and optional authorized protection setup; a successful install is separate from observed readiness. It preserves files unless explicit force is requested.

## harness-protect.sh

Writes GitHub rulesets for the resolved repository when authorized and reports platform/account limits. Local configuration files alone do not activate remote enforcement.

## harness-status.sh

Runs `make check` within a bounded timeout, then queries actual ruleset details. Filenames or ruleset names do not establish readiness. Remote API errors are indeterminate; observed protection remains configuration evidence rather than an adversarial merge proof. See `docs/harness-capabilities.md` for profiles, prerequisites and the protected-policy bootstrap boundary.
