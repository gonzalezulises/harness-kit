# Credits and attribution

This kit is derived from **[learn-harness-engineering](https://github.com/walkinglabs/learn-harness-engineering)**
by WalkingLab, MIT licensed, © 2025. Course site:
<https://walkinglabs.github.io/learn-harness-engineering/es/>

The original `tools/audit-harness.sh` was written by
[Stephen Kimoi](https://github.com/Stephen-Kimoi/harness-engineering-template).

Cloned and analysed 2026-08-05 from `main`.

## Adopted as-is

- The five-subsystem model (instructions, state, verification, scope, lifecycle)
- The L03–L12 check taxonomy that structures `harness-audit.sh`
- The clean-state, evaluator-rubric and quality-document concepts
- `packs/openai-advanced/` — the repo template and SOPs, translated in the upstream repo
  from OpenAI's "Harness engineering: leveraging Codex in an agent-first world"
- `docs/method-map.md`, `docs/initializer-playbook.md`, `docs/prompt-calibration.md`

## Changed, and why

**Stable denominator.** The upstream auditor skipped checks when a prerequisite file was
missing, so totals drifted between 65 and 70 and two repos could not be compared. Every
check is now always recorded. Same denominator, comparable scores.

**Machine-readable output.** Added `--json` so the audit can gate CI and be aggregated
across many repositories. Added `--strict` and `--quiet`.

**Colour hygiene.** ANSI codes are suppressed when output is not a TTY, when `NO_COLOR`
is set, and always in JSON mode. The upstream script emitted escape codes into log files.

**Bilingual patterns.** Instruction files written in Spanish now match the same checks as
English ones.

**Routed matching.** Rules documented in linked `docs/*.md` count toward the score. The
upstream script only searched the entry file, which penalised exactly the split-file
structure it recommends elsewhere.

**No-dependency repos.** A repo with no dependency manifest passes the lockfile check
instead of failing it — there is nothing to lock, and installs are already reproducible.

**The missing implementations.** This is the substantive gap. The upstream auditor checks
for `scripts/verify-feature.sh`, `scripts/check-arch.sh`, `scripts/clean-state-check.sh`,
`scripts/session-trace.sh`, `.harness/arch-rules.json`, `templates/sprint-contract.md` and
a `Makefile` with ten specific targets — but ships none of them, pointing users to a
third-party repository instead. All of them are implemented here, tested, and installed by
`harness-init.sh --level full`.

**Two levels.** `minimal` and `full`, because a one-day dashboard and a long-lived
production service do not need the same harness.

**A test suite.** `tests/run-tests.sh` verifies the kit end-to-end against real scaffolded
repositories: that a failing layer does not promote a feature, that a layer command calling
`exit` still prints its repair guidance, that `--force` is required to overwrite, that a
committed secret trips a rule.

## Bugs found while porting

- `make help` used `^[a-zA-Z_-]+:` and silently hid every target containing a digit — the
  `e2e` target never appeared.
- `eval "$cmd"` in the feature gate ran layer commands in the current shell, so a layer
  that called `exit` terminated the script *before* it could print repair guidance. The
  feature was correctly not promoted, but the agent was told nothing about why. Layer
  commands now run in a subshell.
- The seed secret-detection rule could not fire: its regex embedded both single and double
  quotes, and did not survive the JSON → shell round-trip. Rules now avoid nested quoting
  entirely.

## Licence

MIT, inherited from the upstream project. See [LICENSE](LICENSE).
