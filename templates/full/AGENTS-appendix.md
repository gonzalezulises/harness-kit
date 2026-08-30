
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
