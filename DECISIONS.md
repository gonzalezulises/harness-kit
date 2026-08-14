# Decisions

Architectural and operational decisions, newest first. One entry per decision that a
future session would otherwise re-litigate or accidentally undo.

Record a decision when the answer was not obvious, when you rejected a plausible
alternative, or when the reason lives outside the code. Do not record what the code
already says.

Longer decisions get their own file in `docs/decisions/`.

---

## 2026-08-14 — Build the governance layer here, not in a new repository

**Context.** `ai-software-factory` was started to be the system that governs how AI builds
software. In six days it produced 11,411 lines of governance documentation, 104 lines of
product code, zero governed repositories, and two CI runs that both failed. Measured with
this repository's own auditor it scored 26/74 with 3/7 critical checks — the repository
meant to govern development did not govern itself. It was also the third attempt at the same
problem in five days (`repo-assurance` 3 Aug, `harness-kit` 5 Aug, `ai-software-factory`
7 Aug), each started from scratch.

**Decision.** `harness-kit` is the base. Graft the four designs from the factory that were
worth keeping — anti-loop budgets, the fail-closed gate, the Gherkin failure matrix, the
decision ledger — and archive it.

**Alternatives rejected.**

- *Resume `ai-software-factory`.* Restarting it means reviving the mission machinery that
  caused the problem, starting from a broken CI and self-invalidated evidence.
- *Adopt an external base (`spec-kit`, 128k stars; BMAD; `superpowers`).* The ecosystem
  solved the **specification** half. The **execution-control** half — budgets, WIP=1,
  evidence as receipt, a gate nobody can hand-write past — is barely addressed, and that
  half already worked here. Adopting one would have been the fourth start from scratch.

**Consequences.** The verdict now lives outside the agent's reach, which means the harness
can refuse work rather than advise against it. It also means the gate has a real dependency
on GitHub plan capabilities: push rules are organization-only, so a personal repository can
reach `READY_PARTIAL` but not `READY_DUAL`. That limitation is reported rather than hidden.

---

## 2026-08-05 — Adopt the harness

**Context.** Agent sessions were starting from zero: rediscovering how to build, what was
half-finished, and what "done" meant.

**Decision.** Adopt the harness: `AGENTS.md` as the operating contract, `feature_list.json`
for scoped state, `PROGRESS.md` for cross-session memory, `init.sh` as the one startup path.

**Alternatives rejected.** A longer README — it documents the project for humans but does
not constrain agent behavior or carry state between sessions.

**Consequences.** Every session now starts by reading `PROGRESS.md` and ends by updating
it. Features cannot be marked done without recorded evidence.
