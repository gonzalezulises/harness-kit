# version-sync is optional in the shared gate registry

`version-sync` is registered as `optional` in `scripts/run-gates.sh` and in
`templates/full/scripts/run-gates.sh`, which must stay byte-identical (the in-sync test). In the kit
the script is present, so the gate still runs and still has to pass; in a scaffolded repo there is
no `verify-version-sync.sh` and no release manifest, so the gate reports "not installed (optional)"
and stands down. Test 20g asserts the template keeps it that way. The ledger entry is in
`DECISIONS.md` (2026-09-15); `scripts/run-gates.sh` is a governed path under `AGENTS.md` and
`DECISIONS.md`.

This restores what [the 2026-08-31 note](../process/2026-08-31-una-puerta-declarada-debe-poder-fallar.md)
already stated: `verify-version-sync.sh` belongs to the kit and must not run in an installation, and
a missing script was the mechanism that let both share one registry. When #31 made a missing
`required` script NOT_EXECUTED and blocking, that mechanism stopped covering `version-sync`, and
every installation's `make gates` ended blocked on a gate that cannot apply there. It was found on
2026-09-15 in `inno-arq/mallol-costos` (kit 2.2.5), with the other seven gates passing.

Rejected: a second registry for installations, which breaks the in-sync test and the shared-file
decision; copying the verifier into installations, which exits 3 there for lack of a manifest; and
letting required gates SKIP again, which reopens the silent hole #31 closed.

Given up: if someone deletes `verify-version-sync.sh` from the kit, `make gates` now stands down on
it instead of blocking. The release workflow keeps running the verifier directly (see
[the release-please note](../process/2026-08-30-release-please-with-a-version-sync-gate.md)), so a
release still cannot ship with its versions out of step.

Revisit if the kit gains a way to tell "the kit's own repo" from "an installation" inside the
registry, or if another kit-only gate appears: at that point a declared scope beats a list of
optional exceptions.
