# Releases are automated, and the version's four copies are gated rather than trusted

Cutting a release meant editing `VERSION`, `.harness/kit-version` and
`CHANGELOG.md` by hand and remembering to tag. release-please now derives all of
it from the conventional commits this repo already writes.

The obstacle was not release-please; it was that this kit stores its version in
four places, and only two of them are ones release-please can write. `VERSION`
and `.harness/kit-version` are bare version strings read with
`tr -d '[:space:]'` by `harness-audit.sh`, `harness-status.sh` and
`harness-init.sh`. release-please's generic updater needs an
`x-release-please-version` annotation inside the file it edits, and adding a
comment to either would break every consumer. Changing those consumers to
tolerate comments was rejected: shipping code should not grow a parser to suit a
release tool.

So `.release-please-manifest.json` is the source of truth and
`scripts/sync-version.sh` propagates it, run by a second job inside the release
PR. That leaves an obvious failure: if the sync job silently stops running, a
release ships with the files disagreeing. This is the worst failure mode this
repo can have, because it is invisible — `harness-init.sh` stamps one number
into every scaffolded repository while `harness-status.sh` compares against
another, so downstream repositories are told they are current when they are not.
For a release carrying a security fix that is exactly backwards.

Hence `scripts/verify-version-sync.sh`, registered in the gate registry rather
than left as a convention. Following the registry's own rule — a gate is proven
by making it reject an invalid case before it ships — the test suite asserts
that it rejects a stale `.harness/kit-version` and a manifest that disagrees
with `VERSION`, and that `sync-version.sh` actually produces a state the gate
accepts, so the error message does not send the next session in a circle.

`templates/full/scripts/run-gates.sh` carries the new row too, because the kit
requires the two copies to be byte-identical. Scaffolded repositories have no
`verify-version-sync.sh`, so the row reports SKIP — the behaviour the registry
was designed for, and an affordance: a repository that later adopts
release-please drops the script in and the gate activates.

Revisit if release-please gains an updater for un-annotated plain-text version
files, which would remove the sync job and leave only the gate.
