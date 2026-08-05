# PROGRESS.md — harness-kit

The durable memory of this repository. Every session reads this first and writes to it
last. If it disagrees with your recollection, this file wins.

## Current State

- **Last commit:** `2654584` — feat: portable agent harness kit
- **Verification:** `make check` — passing, 65/65 assertions
- **Self-audit:** `make audit` — 74/74, 7/7 critical, VCR 5/5
- **Startup path:** `./init.sh`
- **Active feature:** none — all five features passing
- **Blocker:** none

## In Progress

_Nothing active. All five features are `passing` with recorded evidence._

## Next Steps

1. Roll the kit out to more of the ~173 repositories. Audit first (read-only), harness the
   ones that will see repeated agent sessions.
2. Grow `.harness/arch-rules.json` as patterns repeat — every recurring review finding
   becomes a rule.
3. Consider splitting Aurobalance's 432-line `AGENTS.md` into `docs/` topic files. The
   contract is at the top now, but the entry file is still an encyclopedia (`inst.short`
   is the one recommended check it fails).

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
- **Next best action:** roll out to more repositories, audit-first.

### 2026-08-05 — pilot rollout

- **Goal:** prove the kit works on real repositories, not just fixtures.
- **Completed:** harnessed three pilots — Aurobalance (full, 32→71/74), ADEN-Taller
  (minimal, 10→44/74, plus a real structure verifier for a content repo), and
  BootCampIesav1.0 (full, 13→72/74).
- **Verification run:** `make check` exits 0 in both full pilots — Aurobalance 97 test
  files, BootCamp 47 tests. ADEN's `check-course.sh` exits 0.
- **Bugs the rollout exposed:** `clean-state-check.sh` ran the verify command with `eval`,
  so a `cd frontend && ...` command leaked the working directory and made every later
  check report missing files. Same class of bug as the feature gate. Both now run in a
  subshell, both covered by regression tests. Also downgraded `.DS_Store` from failure to
  note — a gate that cries wolf gets ignored.
- **Known risks:** pilot changes are uncommitted in the three repos, left for review.
