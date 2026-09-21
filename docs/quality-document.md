# Quality Document — harness-kit

Health of the **codebase**, not of any one session. Read it before starting work to see
where the project is weakest; update it after any session that changed a module
materially.

The evaluator rubric answers "did the agent do a good job this session?"
This document answers "is the project getting stronger or weaker over time?"

Last updated: 2026-09-20 — first entry with real rows. It had carried the template's example
rows since 2026-08-05, which means fourteen features shipped without anyone grading a module.

## Product domains

| Domain | Verification | Agent-readability | Test stability | Key gap |
|---|---|---|---|---|
| `packs/sentry` | B | A | B | 75 cases, and until 2026-08-31 every one measured whether the gate detects failure, never what the pack exposes by being installed. Two cases assumed an ambient variable was absent instead of creating that absence; one was fixed 2026-09-20, the class was not swept. The canary's live path needs a real Sentry, so CI never runs it. |
| `packs/load-testing` | C | A | B | 57 cases and not one reads the workflow it ships. The `${{ }}`-inside-`run:` hole lived there for 19 days after the same hole was closed in the Sentry pack, and what caught it was the kit-level F15 probe, not this pack's matrix. A pack should judge its own shipped surface. |
| `tests/contract` | C | A | — | Ten probes, one green. They are not in `make check` until F22, so nothing runs them on a schedule; nine have never been executed in CI. Until 2026-09-20 the F15 probe could not even parse under macOS bash 3.2 and nobody knew, because its crash looked like a red verdict. |

## Architectural layers

| Layer | Boundary enforcement | Agent-readability | Notes |
|---|---|---|---|
| `packs/**` templates | C | A | The kit ships workflows and SDK config into other repos, and `check-arch` says nothing about that surface. The rule that governs it lives in one probe outside the gate registry. |
| `scripts/**` gates | A | A | `make gates` fails closed, states every non-PASS, and `verify-feature` is the only writer of `passing`. The strongest layer in the repo. |

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
