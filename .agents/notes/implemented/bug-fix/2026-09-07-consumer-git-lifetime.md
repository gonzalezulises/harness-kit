# Await Git maintenance before a temporary consumer repository is removed

- Date: 2026-09-07
- Owner: harness-kit maintainers under the authorized PR33–37 closure
- Context: `AGENTS.md`; `DECISIONS.md`; `docs/quality-document.md`

PR36 Required quality passed its repository pipeline, then failed F26 e2e
cleanup with ENOTEMPTY in .git. Its log does not identify the writer. A separate
real-Git diagnostic and two causal regressions demonstrate that the fixture
helper returns before automatic packing finishes, for both gc and commit.

Set maintenance.autoDetach=false and gc.autoDetach=false on fixture Git commands.
Maintenance still runs; its normal exit is awaited. Do not suppress rmtree
errors, disable maintenance, change production policy, or claim the original
remote interleaving has been proved. This may increase fixture command latency
within the existing60-second timeout. Both regressions changed from RED to GREEN.

Because this changes the exact critical test file, retain the original test and
receipt. Reobserve its approval falsification using the current test bytes and
only the same two approval-guard deletions on published b567669f source. The new
receipt records that overlay, controller HEAD6677e997 and MERGE_HEADb567669f.
Neither commit is claimed to contain the unpublished test/mutant. Original
F26-F1-M3 missing input and F09 blocked status remain unchanged.

Independent review CG-L1 found a direct Git commit in the intentional HEAD-drift
injection. Apply the same foreground options there. Keep the first review and
reproof unchanged; the followup receipt binds the final test and another observed
approval RED. The six focused followup cases passed; final combined verification
and re-review are separate requirements.
