# PROGRESS.md — harness-kit

The durable memory of this repository. Every session reads this first and writes to it
last. If it disagrees with your recollection, this file wins.

## Current State

- **Last commit:** _(initial commit — see `git log --oneline -1`)_
- **Verification:** `make check` — passing, 62/62 assertions
- **Self-audit:** `make audit` — 73/74, 7/7 critical
- **Startup path:** `./init.sh`
- **Active feature:** F05 (adoption — pilot rollout)
- **Blocker:** none

## In Progress

**F05 — adoption.** Applying the kit to real repositories and recording before/after audit
scores. Four of five features are `passing`; F05 stays `active` until the pilot repos are
harnessed and their scores recorded.

This is why `make audit` reports 73/74 rather than 74/74: the VCR check correctly reports
one activated feature that is not yet passing. That is an honest signal, not a defect.

## Next Steps

1. Finish the pilot rollout and record before/after scores in F05's evidence.
2. Run `make verify-feature F=F05` to promote it — do not hand-edit the state.
3. Decide whether `.harness/arch-rules.json` should grow project-specific rules as the kit
   is applied to more repos (every recurring review finding becomes a rule).

## Blockers

_(none)_

---

## Session Log

Newest first. One entry per session.

### 2026-08-05 — build the kit

- **Goal:** turn the analysis of `learn-harness-engineering` into a portable, agent-agnostic
  kit that works for Codex and Cursor, not only Claude Code.
- **Completed:** `harness-audit.sh` (74 checks, stable denominator, `--json`, bilingual
  patterns); `harness-init.sh` (minimal/full, command detection, clobber protection);
  the four gate scripts the upstream auditor demanded but never shipped; minimal and full
  template sets; `tests/run-tests.sh` with 62 assertions; the kit's own harness.
- **Verification run:** `make check` — 62/62 passed. `make audit` — 73/74, 7/7 critical.
- **Evidence recorded:** F01–F04 promoted to `passing` with test-section references.
- **Known risks:** the audit measures *structure*, not effectiveness. A repo can score
  74/74 and still host bad sessions. Real proof needs before/after agent runs on
  representative tasks, which this kit does not attempt to measure.
- **Bugs found and fixed while porting:** `make help` hid targets containing digits;
  `eval` in the feature gate let a layer's `exit` kill the script before it printed repair
  guidance; the seed secret rule could not fire because its regex did not survive the
  JSON → shell round-trip. All three are covered by tests now.
- **Next best action:** apply to pilot repositories, record scores, promote F05.
