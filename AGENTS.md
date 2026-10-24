# AGENTS.md — harness-kit

This repo is a portable harness kit: it scaffolds and audits the instruction, state,
verification, scope and lifecycle subsystems that keep AI coding agents reliable across
sessions. This file is a router, not a manual — details live in `docs/`.

## Startup (clock-in)

1. Confirm the working directory with `pwd`.
2. Read `PROGRESS.md`, then `feature_list.json`, and pick the top unfinished feature.
3. Review `git log --oneline -5`, then run `./init.sh`.

## Verification

- **Before every commit:** `make check-fast` (syntax + JSON, seconds).
- **Before clock-out and PR:** `make check` (full suite + pack matrices).

CI runs `make check`, plus `verify-claims` and `verify-decisions`, on a runner an
agent cannot edit.

## Working rules

- **Evidence before done.** Done means Layers 1 (static), 2 (runtime) and 3 (e2e,
  when a change crosses boundaries) each ran and produced output — never "code was
  written" or "I am confident".
- **State machine** — `not_started → active → claimed → passing`. No skipping.
  Local `verify-feature.sh` records `claimed`; only CI (`verify-claims.sh`) writes
  `passing`. A hand-written state is a claim; a CI re-run is the receipt.
- **WIP=1 by default** — relax it per area or worktree with explicit ownership when
  conflict risk is demonstrably low.
- **Stay in scope, repo over chat, no stale docs, atomic commits** that explain WHY.
- **Never edit `.github/workflows/required-quality.yml`** — a skipped job counts as a
  passing check. `DECISIONS.md` is append-only. Never commit secrets.

## Definition of Done

1. Layers 1, 2 and 3 (when required) all green.
2. Evidence recorded in `feature_list.json`.
3. `make check`, `verify-coverage` and `verify-ceremony` all exit 0.

## Session end (clock-out)

Run `make check`, update `PROGRESS.md` + `feature_list.json`, walk
`clean-state-checklist.md`, commit. Low on context? Stop, write state, commit a
clean checkpoint — a rushed finish costs more than an unfinished feature.

## Deeper docs

- `docs/quality-document.md` — module health · `docs/decisions/` — rationale
- `docs/method-map.md` — failure mode → artifact · `docs/startup-flow.md`
- `templates/sprint-contract.md` — scope before work · `templates/evaluator-rubric.md` — after
