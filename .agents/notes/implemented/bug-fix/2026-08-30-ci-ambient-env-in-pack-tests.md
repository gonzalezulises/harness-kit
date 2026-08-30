# Pack tests must pin the ambient CI environment they assert against

**Decided:** the "no repository" usage-error test runs
`env -u GITHUB_REPOSITORY` around perf-resolve-target.

**Why:** the script deliberately falls back to `GITHUB_REPOSITORY`, which
always exists on GitHub Actions — so on the runner the "missing repo" case
never triggered: the tool proceeded into its 10×20s retry loop against the
real API and returned the wrong exit code (also explaining the layer's
~12-minute runtime). Same family as the portal's e2e-profile CI-flag bug: a
test that asserts an absence must create that absence, not assume it.
Verified both ways locally (with and without the variable: 57/0).

**Superseded diagnosis chain (kept for the pattern):** ESM parse mode →
mawk intervals → summary visibility → this. Each fix was real; only this one
was the runner's remaining failure.
