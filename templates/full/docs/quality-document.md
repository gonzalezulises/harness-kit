# Quality Document — {{PROJECT_NAME}}

Health of the **codebase**, not of any one session. Read it before starting work to see
where the project is weakest; update it after any session that changed a module
materially.

The evaluator rubric answers "did the agent do a good job this session?"
This document answers "is the project getting stronger or weaker over time?"

Last updated: {{DATE}}

## Product domains

| Domain | Verification | Agent-readability | Test stability | Key gap |
|---|---|---|---|---|
| _(e.g. auth)_ | C | B | C | no e2e coverage |
| | | | | |

## Architectural layers

| Layer | Boundary enforcement | Agent-readability | Notes |
|---|---|---|---|
| _(e.g. services)_ | C | B | boundaries documented but not machine-checked |
| | | | |

Grades: **A** solid · **B** adequate · **C** needs work · **D** actively harmful

## Update triggers

- After any session that materially changed a module
- Before a benchmark comparison
- After a cleanup or simplification pass
- When onboarding a new agent or model to the project

## Using this to simplify the harness

Every harness component encodes an assumption about what the model cannot do on its own.
Models improve; some of those assumptions expire. To test whether a component still earns
its place:

1. Snapshot this document.
2. Remove one harness component.
3. Run the benchmark task set.
4. Snapshot again.
5. Compare. If grades held, the component was overhead — leave it out. If they dropped,
   restore it.

A harness that only ever grows becomes the thing agents skim past. Removing a component
that has stopped paying rent is maintenance, not regression.
