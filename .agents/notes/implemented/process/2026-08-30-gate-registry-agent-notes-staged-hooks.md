# Gate registry, Agent Notes lifecycle, and staged-only hooks

Three mechanisms adopted after studying deepseek-ai/deepseek-harness (203k
stars, created 2026-08), whose repository governance independently converged on
this kit's design (CLAUDE.md symlinked to AGENTS.md, policy in text before
hooks, hard gates in CI).

**Decided:**

1. `scripts/run-gates.sh` — a single registry of every mechanically checkable
   convention, with `quick` (static, mid-work safe) and `full` aggregates.
   Rule: a convention without a gate is a suggestion; a new gate ships only
   after rejecting an invalid case.
2. `.agents/notes/{lifecycle}/{class}/yyyy-mm-dd-topic.md` — decisions carry
   lifecycle (proposed/implemented/rejected) and a closed class set, enforced
   by `scripts/verify-agent-notes.sh`. Every non-trivial change adds or updates
   a note in the same PR. `DECISIONS.md` stays the short append-only ledger;
   entries link to notes. Deliberately no index file: the tree is the inventory.
3. `scripts/pre-commit-staged.sh` + `install-githooks.sh` — staged-only local
   checkpoints that regenerate rather than reject (formatter autofix + restage)
   and fail loud with the exact fix when tooling is missing. Opt-in: the
   installer refuses to fight husky or an existing core.hooksPath.

**Rejected:** porting deepseek-harness's bilingual sidecars, frozen archive
tree, and word-budget gates — right for a 46-gate monorepo, noise at this
kit's scale. Revisit the archive tree when active notes exceed ~30.

**Given up:** the pre-commit hook is opt-in, so repos that never run
`make hooks-install` only meet these gates in CI.
