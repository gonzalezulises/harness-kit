# Evaluator Rubric

Score a completed session across six dimensions. Every dimension must reach **B or
above** to accept the work.

| Grade | Meaning |
|---|---|
| A | Meets the standard with evidence |
| B | Meets the standard, minor gaps that do not block |
| C | Needs revision before it can be accepted |
| D | Fundamental problems; block and rework |

## Dimensions

### 1. Correctness
Does the implementation match the target behavior in `feature_list.json`?

- **A** — behavior matches exactly; edge cases handled
- **C** — happy path only, or behavior drifted from the spec without renegotiation

### 2. Verification
Were the required checks actually run, with output recorded?

- **A** — all three layers ran; evidence recorded with commit and timestamp
- **C** — claimed verified, no evidence; or only Layer 1 ran
- **D** — marked `passing` without running anything

### 3. Scope discipline
Did the session stay inside the active feature?

- **A** — only the expected files changed
- **C** — unrelated refactors bundled in
- **D** — multiple features touched at once (WIP=1 violated)

### 4. Reliability
Does the result survive a restart or a re-run?

- **A** — `./init.sh` works from a clean checkout; result reproduces
- **C** — works only in the current dirty state

### 5. Maintainability
Can the next session read this?

- **A** — code and docs are clear; decisions recorded in `docs/decisions/`
- **C** — works, but the reasoning lives only in the diff

### 6. Handoff readiness
Can a fresh session continue from repo artifacts alone, with no chat history?

- **A** — `PROGRESS.md` names the state, next action, and blockers
- **D** — the next session must reconstruct context by reading code

## Verdict

- **Accept** — every dimension B or above
- **Revise** — one or more at C; list required fixes
- **Block** — any D

---

## Calibrating this rubric

**Out of the box, agents are poor self-judges** — they identify problems and then talk
themselves into a passing grade. Expect to tune this:

1. Run the evaluator on a completed sprint.
2. Compare its grades against your own judgement.
3. Where they diverge, make the pass/fail criteria for that dimension more specific.
4. Re-run and check alignment.

Plan 3–5 rounds. Record each change so you can tell which edit improved agreement.
An uncalibrated rubric produces confident grades that mean nothing.
