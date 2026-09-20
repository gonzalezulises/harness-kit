# Acceptance probes for the consumer contract, written before the features they judge

An external review on 2026-09-19 (kit at `9f4e047`) found that the suite proves each
script works against fixtures and never plays the consumer: activate a repository,
run its gates, upgrade it. Every defect that reached a real repository in the last
three weeks lived in that gap — `version-sync` blocking every installation from
2026-09-03 to 2026-09-15, a scaffold born red on four of seven detected stacks, an
upgrade path that replaces `DECISIONS.md`.

The decision: `tests/contract/` holds one probe per backlog feature F15–F25. Each
was written before its feature and run against `9f4e047`, where all ten are red for
the reason their feature names; `tests/contract/run.sh` prints the board. They are
the `contract` layer of those features in `feature_list.json`, so
`make verify-feature F=Fnn` cannot promote one until its probe turns green. They are
not part of `make check` yet — a suite that is red on purpose teaches people to skim
it — and F22 wires them in once F15–F21 are green.

A probe that can never pass is as useless as a test that can never fail, so each body
was exercised both ways. F15 is red on `main` and, on
`fix/sentry-pack-security-hardening`, its Sentry half turns green while
`packs/load-testing` `perf.yml` stays red: the branch repaired one pack, not the
class. F17, F20, F24 and F25 went fully green against throwaway implementations
(8/8, 14/14, 9/9, 8/8), and F21 caught a fake upgrade that called `--force`,
reporting all seven owned files destroyed. Those implementations were discarded on
purpose: the author of an oracle should not also be the author of the code it
judges, or the cases imagined are the ones the code already passes.

Alternatives rejected. Adding these as new sections of `tests/run-tests.sh` — that
suite must stay green on every commit, so red-on-purpose cases cannot live there
until their feature lands. Writing one `.harness/oracles/` file per probe — oracles
carry a `proved_sha` for a test that exists and has been seen failing against a
defect; several of these judge scripts that do not exist yet, and the folder is
meant to stay small. Shipping the features in the same change — it would have
skipped WIP=1, the receipts and the separation above.

What was given up. Four probes fix an interface before the implementer has seen the
problem: `.harness/gates.conf` (F19), `.harness/kit-lock.json` (F20),
`bin/harness-upgrade.sh --target --dry-run` (F21) and the two new gate script names
(F24, F25). Each header marks the shape as proposed. Changing a shape is legitimate;
it is done by editing the probe in its own commit with a `DECISIONS.md` entry, never
in the commit that makes it pass. F23 is static and says so: wiring is not
enforcement, and its feature demands a canary receipt.

F19 reopens an alternative rejected on 2026-09-15 (a separate registry for
installations). It must not start until a `DECISIONS.md` entry supersedes that
rejection or rejects F19; the evidence offered is in the feature's notes.

Revisit when F22 lands: the probes either fold into `tests/run-tests.sh` as numbered
sections or stay as a second suite, and this note moves to `implemented/`.
