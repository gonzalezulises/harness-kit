# AGENTS.md — harness-kit

This project is a portable harness kit: it scaffolds and audits the instruction, state, verification, scope and lifecycle subsystems that keep AI coding agents reliable across sessions.

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
make check
```

The repo is in a consistent state when that command exits 0. Run it before every
commit and at every clock-out.

## Working rules

- **WIP=1** — only one feature may be `active` at a time. Finish it, verify it, then
  activate the next. why: parallel half-finished features leave no verifiable state.
- **Evidence before done** — never mark a feature `passing` because code was written.
  Mark it passing only after the verification command actually ran and produced output.
- **Feature granularity** — each feature must be completable in one session. If it
  spans sessions, split it.
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
5. `make check` exits 0.

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

1. Run `make check` and record the result.
2. Update `PROGRESS.md`: current state, what changed, next best action.
3. Update `feature_list.json` states and evidence.
4. Walk `clean-state-checklist.md`.
5. Commit. Leave the repo restartable from `./init.sh`.

**If you are running low on context, do NOT rush to finish.** Stop, write the state
down, commit a clean checkpoint. A rushed finish that skips verification costs the next
session more than an unfinished feature does.

Beyond the per-session cleanup above, do a periodic (weekly or monthly) sweep for
structural drift: dead files, stale docs, features stuck in `active`.

---

# Full harness

This repo runs the full harness. Everything above still applies; the sections below add
the mechanical gates.

## Commands

| Command | Purpose |
|---|---|
| `make check` | Full verification pipeline. Must exit 0 before every commit. |
| `make verify-feature F=F01` | Run a feature's layers and gate it to `passing`. |
| `make vcr` | Verified Completion Ratio — passing / activated. |
| `make check-arch` | Enforce architectural boundaries. |
| `make clean-check` | Clock-out gate. |
| `make e2e` | End-to-end suite. |
| `make session-start` / `session-end` | Open and close the session trace. |
| `make gates` (`A=full` for everything) | Run the gate registry — every mechanically checkable convention lives there. |
| `make verify-agent-notes` | Agent Notes tree/format gate. |
| `make hooks-install` | Opt-in staged-only git hooks with formatter autofix. |

## Agent Notes

Every non-trivial change adds or updates an Agent Note in the same PR —
`.agents/notes/{lifecycle}/{class}/yyyy-mm-dd-topic.md` records the decision's
WHY and what was given up ([rules](.agents/notes/README.md)). A note is never
edited into a different decision: supersede and cross-link. `make gates`
enforces the tree.

## Feature list rules

**Never set `state` to `passing` by hand.** Run `make verify-feature F=<id>`. The script
runs every layer in order and only writes `passing` after all of them produce output.
A state written by hand is a claim; a state written by the harness is a receipt.

## Architecture boundaries

Layer dependency rules live in `.harness/arch-rules.json` and are enforced by
`make check-arch`. Each rule reports WHAT was violated, WHY the rule exists, and the exact
FIX — because "boundary violation in module X" is not actionable, and "delete the import
on line 12 of src/ui/db.ts" is.

**Promotion principle:** every new error category caught in code review becomes a rule in
`.harness/arch-rules.json`. A review comment fires once and is forgotten; a rule fires on
every commit forever. If you find yourself explaining the same mistake twice, you owe the
repo a rule.

**Layer 3 (e2e) is required whenever a change crosses component or domain boundaries.**
Within a single module, Layers 1 and 2 are enough.

## Observability

- **Before a feature:** fill `templates/sprint-contract.md` — scope, exclusions,
  definition of done. Scope disagreements should surface before work, not at review.
- **During:** `make session-start` opens a trace; `scripts/session-trace.sh event <name>`
  records verification runs and failures to `.harness/traces/traces.jsonl`.
- **After:** score the session against `templates/evaluator-rubric.md`. Every dimension
  must reach B or above. The rubric needs calibration against your own judgement before
  its grades mean anything — see the notes at the bottom of that file.

## Quality tracking

`docs/quality-document.md` grades each module A–D. Read it at clock-in to see where the
codebase is weakest; update it at clock-out for any module you changed materially.

The rubric scores a session. The quality document scores the project. Use both — a run of
A-graded sessions can still leave a codebase drifting downward if every session takes the
cheap path.

## Deeper docs

- `docs/quality-document.md` — module health over time
- `docs/decisions/` — architectural decisions and their rationale
- `templates/sprint-contract.md` — pre-feature scope negotiation
- `templates/evaluator-rubric.md` — post-session scoring
