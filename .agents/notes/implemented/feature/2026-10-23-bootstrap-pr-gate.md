# The PR that installs the gate can pass it

**Decision.** In `required-quality.yml`, the claim and decision steps fall back to the PR's own
checker only when the base branch has no `.github/workflows/required-quality.yml`. The base checkout
now brings that file so the step can tell.

**Why.** On 2026-10-23, 12 repos got the gate in one PR each. `make check` passed on all 12, and
every `Required quality` ended blocked (exit 126, checker missing on the base). Merging meant
overriding a red check, the habit the gate is there to stop.

**What was given up.** On the installing PR, the checker that judges it comes from that PR. There
is nothing older to trust yet, and no ruleset is active until after it merges. Once the workflow is
on the base, the old rule applies unchanged. F33 has a control for that case.
