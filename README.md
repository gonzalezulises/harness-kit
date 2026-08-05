# harness-kit

Scaffold and audit the harness that keeps AI coding agents reliable across sessions.

Agent-agnostic by design: everything it produces is plain shell, Make and Markdown, so
Codex, Cursor, Claude Code, Windsurf and CI all read the same contract. There is no
dependency on any single agent's plugin system.

```bash
# Score an existing repo — read-only, changes nothing
bin/harness-audit.sh /path/to/repo

# Scaffold a harness (dry run first)
bin/harness-init.sh --target /path/to/repo --level full --dry-run
bin/harness-init.sh --target /path/to/repo --level full
```

## Why

A capable model still fails on long-running work for reasons that have nothing to do with
capability: it starts each session blind, drifts out of scope, and declares victory before
anything ran. Those are properties of the *repository*, not the model — so they are fixed
in the repository.

Five subsystems carry that weight:

| Subsystem | Artifact | Answers |
|---|---|---|
| Instructions | `AGENTS.md` | How do I start, and what are the rules? |
| State | `feature_list.json`, `PROGRESS.md` | What is done, active, and next? |
| Verification | `init.sh`, `make check` | How do I prove it works? |
| Scope | Feature states, WIP=1 | What am I allowed to touch? |
| Lifecycle | `clean-state-checklist.md` | How do I leave this for the next session? |

## Levels

**`--level minimal`** — 8 files, no build system assumptions. The operating contract,
a startup path, feature state, progress memory, and a clock-out checklist. Scores about
40/74 on a fresh repo, and passes all 7 critical checks.

**`--level full`** — adds the mechanical gates: a `Makefile` front door, `verify-feature.sh`
(the only thing allowed to mark a feature `passing`), `check-arch.sh` with a rule registry,
`clean-state-check.sh`, and session tracing. Scores about 72/74.

Start minimal. Move to full when the project is big enough that "the agent remembers"
stops being true.

## The gate that matters

`verify-feature.sh` is the difference between a harness and a document. A feature's state
moves to `passing` only after every layer in its `layers` array actually ran:

```bash
make verify-feature F=F01
```

If a layer fails, the script prints that layer's `repair` instruction and stops. It does
not advance, and it does not promote. **A state written by hand is a claim; a state written
by the harness is a receipt.**

## Auditing

```bash
bin/harness-audit.sh .              # human-readable
bin/harness-audit.sh . --json       # machine-readable, for CI
bin/harness-audit.sh . --strict     # exit 2 if any recommended check fails
```

74 checks with a **stable denominator** — every check is always recorded, so scores from
two different repos are directly comparable. Exit 1 when any critical check fails.

Instruction files are recognised in English *or* Spanish, and rules documented in linked
`docs/` files count toward the score — the entry file is meant to stay short.

## Requirements

`bash` 3.2+ (stock macOS works) and `git`. `python3` is needed for the full level only.
No npm install, no runtime, nothing to keep up to date.

## Layout

```
bin/harness-audit.sh      74-check auditor, zero dependencies
bin/harness-init.sh       scaffolder (--level minimal|full)
templates/minimal/        the base contract and state files
templates/full/           Makefile, gate scripts, arch rules, rubrics
packs/openai-advanced/    heavier repo structure for large codebases
docs/                     method map, initializer playbook, prompt calibration, SOPs
tests/run-tests.sh        end-to-end verification of this kit
```

## Verifying the kit

```bash
make check
```

62 assertions against real scaffolded repos — no mocks. It builds throwaway projects,
runs the actual scripts, and asserts on behavior: that a failing layer does not promote
a feature, that `--force` is required to overwrite, that a committed secret trips a rule.

## Credits

Derived from [learn-harness-engineering](https://github.com/walkinglabs/learn-harness-engineering)
by WalkingLab (MIT). See [CREDITS.md](CREDITS.md) for what was adopted and what changed.
