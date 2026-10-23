# lite is the default level; the feature ceremony is opt-in

**Decision.** `harness-init` and `harness-activate` default to `--level lite`.

**What lite installs:** the pieces that catch real failures. That is the `Required quality`
workflow, both rulesets, `verify-claims`, `verify-decisions`, `Makefile check` and a short
`AGENTS.md`. `harness-activate` also turns Dependabot alerts and security updates on through the
API and reads them back.

**What lite leaves out:** `PROGRESS.md`, session files, `init.sh` and the feature state machine.
`feature_list.json` ships empty, so `verify-claims` reports `NO_CLAIMS` and keeps its deletion
guard (exit 66 when the file is missing).

**Fast lane:** `minimal` and `full` gain one. Dependency, config, CI and docs changes, and small
changes with no new behaviour, skip the ceremony but never `make check`.

**Why.** On 2026-10-23 `pr_cost.py` measured the last 30 merged PRs of 11 repos.
- CI was not the cost: the median run took 1–6 minutes and PRs merged within minutes.
- The cost was bookkeeping. In `full` repos, 11–35 % of the files each PR touched were process
  files, against 0 % in ungoverned repos.
- The root was that `harness-activate`, the path every new client repo takes, always installed
  `full`, and the merge gate itself shipped only with `full`.
- The failures that cost real time that day were outside the repo, and no gate here caught them:
  Dependabot off in 235 repos, four sites that did not deploy themselves, and Supabase signup
  open over `USING true` policies.

**Alternatives rejected.**
- *Strip the ceremony out of `full`.* Long-lived, multi-session projects, this kit included,
  do benefit from WIP=1 and budgets. The defect was making it the default.
- *A separate lite workflow.* A second required workflow is a second thing to protect. Lite
  reuses the exact `full` workflow and passes it trivially with an empty feature list.
- *A `dependabot.yml` template.* Version-update PRs every week are noise. Dependabot is enabled
  by repository setting instead, and a wiring check is meant to fail if it is off.

**Given up.** A lite repo has no cross-session memory file and no evidence ledger. An agent
working on long multi-session work there must re-derive state from git history, or the repo
should move to `full`.

**Revisit when** the harness exceeds its own budget, measured monthly with `pr_cost.py`: a median
CI over 5 minutes, more than 10 % of a PR's files in process files, or any manual step for a
non-destructive change. Revisit also when a lite repo ships a defect that the feature ceremony
would have caught.
