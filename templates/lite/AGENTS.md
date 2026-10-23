# AGENTS.md — {{PROJECT_NAME}}

This project is {{PROJECT_PURPOSE}}.

This file is the operating contract for any coding agent working in this repo
(Codex, Claude Code, Cursor, OpenCode, or a human). The harness here is `lite`: it
protects the merge and stays out of the way of the work.

## Before you start

1. Confirm the working directory with `pwd` and read `git log --oneline -5`.
2. If `~/GitHub/harness-kit/bin/harness-wiring.sh` exists, check the wiring once per
   session: `bash ~/GitHub/harness-kit/bin/harness-wiring.sh --quick`. A `NOT_WIRED` line names
   the integration that is missing; fix it or report it before building on top of it.

## Verification

The single command that proves this repo is consistent:

```bash
{{VERIFY_CMD}}
```

It must exit 0 before every commit. CI runs it as the `Required quality` check, and the
branch rules block any merge without it.

## Rules

- **Evidence before done.** Do not call a change done until the verification command
  ran and you saw its output. For anything user-visible, exercise it the way a user would.
- **Never touch `.github/workflows/required-quality.yml`.** GitHub counts a job skipped by
  its own condition as a successful required check, so weakening that file makes a pull
  request merge green while appearing gated. If it must change, a human records why in
  `DECISIONS.md`.
- **`DECISIONS.md` is append-only.** Add new decisions; supersede an old one with a new
  entry that references it. CI rejects edits to earlier entries.
- **Stay in scope.** Touch only what the task needs, and update docs in the same commit.
- **Never commit secrets.** Credentials belong in `.env` (gitignored) or the OS keychain.

## Scaling up

`feature_list.json` is intentionally empty: this repo carries no feature ceremony. When
the project grows into multi-session work that needs WIP=1, budgets and evidence ledgers,
re-run `harness-init.sh --level full`.
