# AGENTS.md — {{PROJECT_NAME}}

This project is {{PROJECT_PURPOSE}}.

This file is the operating contract for any coding agent working in this repo
(Codex, Claude Code, Cursor, Windsurf, or a human). It is a router, not a manual:
it states the startup path, the rules, and what "done" means. Details live in `docs/`.

## Startup (clock-in)

Before touching code, in this order:

1. Confirm the working directory with `pwd`.
2. Read `PROGRESS.md` — it holds the last verified state and the next step.
3. Read `feature_list.json` and pick the highest-priority unfinished feature.
4. Review recent history: `git log --oneline -5`.
5. Run `./init.sh` to install and verify the baseline.

If baseline verification is already failing, repair it first. MUST NOT stack new
feature work on a broken baseline — a red baseline makes every later result unreadable.

## Verification

The single command that proves this repo is consistent:

```bash
{{VERIFY_CMD}}
```

The repo is in a consistent state when that command exits 0. Run it before every
commit and at every clock-out.

## Working rules

- **WIP=1** — only one feature may be `active` at a time. Finish it, verify it, then
  activate the next. why: parallel half-finished features leave no verifiable state.
- **Evidence before done** — never mark a feature `passing` because code was written.
  Mark it passing only after the verification command actually ran and produced output.
- **`passing` is not yours to write** — only `scripts/verify-feature.sh` may set it. CI
  re-runs every claimed feature with `scripts/verify-claims.sh`, using the copy from the
  base branch, and a state whose layers do not pass comes back as `FALSE_CLAIM`. why: a
  state written by hand is a claim; a state that survives re-verification is a receipt.
- **`DECISIONS.md` is append-only** — record new decisions freely, and supersede an old one
  by adding an entry that references it. Never edit or delete an earlier entry; CI rejects
  that as `DECISION_REWRITE_FORBIDDEN`. why: when a past decision blocks your approach, the
  cheapest move is to erase the reason it existed — and the next session reads a tidy ledger
  with no way to tell a constraint was dropped rather than resolved.
- **Never touch `.github/workflows/required-quality.yml`** — not to add a condition, a
  paths filter, a rename, or a "temporary" skip. GitHub counts a job **skipped** by its
  own job-level condition as a **successful** required check, so weakening that file makes
  a pull request merge green while appearing fully gated. The push ruleset installed by
  `bin/harness-protect.sh` rejects such a push outright. If the workflow genuinely must
  change, that is a human decision recorded in `DECISIONS.md`, not an agent edit.
- **Feature granularity** — each feature must be completable in one session. If it
  spans sessions, split it.
- **Budgets are hard limits** — every feature declares `budgets`: `review_rounds_max`,
  `repeated_blocker_max`, and a `stop_condition`. Each failed verification spends one
  round, written to the feature's `ledger` by the harness. When a budget runs out the
  feature is set to `blocked` and work on it MUST stop — do not retry, do not refactor
  around the failure, do not open a new approach. Escalate to a human or split the
  feature. why: an agent with no spending limit will loop on the same blocker until the
  session dies, producing motion instead of software.
- **State machine** — `not_started` → `active` → `passing`. No skipping states.
- **Stay in scope** — do not modify files unrelated to the active feature. A blocking
  fix is allowed, but record it in `PROGRESS.md`.
- **Repo over chat** — durable repo artifacts beat chat summaries. The next session
  will not have your context window.
- **No stale docs** — update docs in the same commit as the code change.
- **Atomic commits** — one logical change per commit; the repo stays consistent after
  each one. Commit messages explain WHY the change was made, not just what changed.

## Definition of Done

A feature is done only when all of these are true:

1. **Layer 1 — static.** Types/lint/build pass.
2. **Layer 2 — runtime.** The code actually runs and produces the target behavior:
   the app reaches its ready state, side effects are correct, no debug artifacts remain.
3. **Layer 3 — end-to-end.** The user-visible behavior described in
   `user_visible_behavior` was exercised the way a real user would.
4. Evidence is recorded in `feature_list.json`.
5. `{{VERIFY_CMD}}` exits 0.

Do not proceed to Layer N+1 while Layer N fails. Layer 3 is required whenever a change
crosses component or domain boundaries.

Writing code is not done. Being confident is not done. Runtime evidence is done.

## State files

| File | Holds |
|---|---|
| `PROGRESS.md` | Current verified state, session log, next step |
| `feature_list.json` | Every feature, its state, verification steps, evidence |
| `docs/decisions/` | Architectural decisions and why they were made |
| `clean-state-checklist.md` | The checklist to clear before ending a session |

## Tools and permissions

Tool access is scoped by the agent's own config (`.claude/settings.json`, `.mcp.json`,
`.cursor/`, or equivalent). Agents MUST NOT widen their own permissions to complete a
task — if a task needs a capability that is not granted, stop and say so.

Never commit secrets. Credentials belong in `.env` (gitignored) or the OS keychain.

## Session end (clock-out)

Before closing a session:

1. Run `{{VERIFY_CMD}}` and record the result.
2. Update `PROGRESS.md`: current state, what changed, next best action.
3. Update `feature_list.json` states and evidence.
4. Walk `clean-state-checklist.md`.
5. Commit. Leave the repo restartable from `./init.sh`.

**If you are running low on context, do NOT rush to finish.** Stop, write the state
down, commit a clean checkpoint. A rushed finish that skips verification costs the next
session more than an unfinished feature does.

Beyond the per-session cleanup above, do a periodic (weekly or monthly) sweep for
structural drift: dead files, stale docs, features stuck in `active`.
