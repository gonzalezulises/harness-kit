# The release PR arrives with its required check never having run

**Decided:** a release-please PR is unblocked by closing and reopening it, not
by `gh pr merge --admin`. Recorded here because the obstacle recurs on every
release and its cause is invisible from the PR page.

**Why:** v2.2.0, the first automated release, sat at `MERGEABLE · BLOCKED` with
only GitGuardian reporting. `Required quality` had never run, so branch
protection had nothing to approve. The cause is GitHub's anti-recursion rule:
events raised by the built-in `GITHUB_TOKEN` do not trigger workflows, and
`required-quality.yml` listens on `pull_request: [opened, synchronize,
reopened]`. release-please opens the PR with that token, so the `opened` event
is swallowed. Every future release PR arrives the same way.

`reopened` is in the trigger list, and a close/reopen performed by a person
carries their identity rather than the Actions token — the check runs, and the
verdict is real. It ran in 3m23s and passed, exercising the pack matrices in CI
for the first time (179 + 15 + 55 + 60).

**Given up:** `--admin` would have merged in one command. Rejected: this repo's
whole claim is that a gate is not decoration, and an untested release is exactly
the artefact it should refuse to ship. The durable fix is a PAT or a GitHub App
token for release-please, so the `opened` event triggers checks like any other
PR — not done here because it trades a 10-second manual step for a credential to
store and rotate, and the step is now written down. Revisit when releases become
frequent enough that the step is forgotten rather than followed.
