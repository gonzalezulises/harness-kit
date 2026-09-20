# PROGRESS.md — harness-kit

The durable memory of this repository. Every session reads this first and writes to it
last. If it disagrees with your recollection, this file wins.

## Current state — 2026-09-20 (F15 merged, 2.3.0 released, no open PRs)

F15 is `passing` and on `main`: PR #40 rebase-merged, VCR 15/15. It was promoted by
`verify-feature.sh` on the first round — contract 6/0, Sentry pack 75/0, load-testing pack 57/0,
suite 274/0 — and on `main` after the release `make check` exits 0 and `make gates` gives 8 pass,
0 blocking. The three commits of `fix/sentry-pack-security-hardening` landed by cherry-pick after
19 days unmerged, and `packs/load-testing` `perf.yml` now passes its inputs through `env:` as well.

**Release `v2.3.0` is published** — tag and GitHub Release, 2026-09-20T20:25:15Z, `VERSION` and
`.harness/kit-version` both 2.3.0. The close-and-reopen ritual was needed again: the release-please
PR arrived with `Required quality` never run, and reopening is what queued it.

**No pull request is open.** The four autonomy drafts (#33, #35, #36, #37) were closed by owner
decision — the branches stay on the remote and `gh pr reopen <n>` brings each back. Dependabot #28
(`actions/checkout` 4→7) and #29 (`release-please-action` 4→5) were updated onto `main` and merged
once green; the release workflow then ran on `b83c20c` under the v5 action and completed `success`,
which is the only thing that proves that bump.

**Next: F16.** No feature is active.

- **The F15 probe had never run on this Mac.** bash 3.2 cannot parse `"${{"` in a heredoc inside
  `$( )`, so it died before inspecting anything. Fixed in a separate commit with the owner's
  authorisation — see `DECISIONS.md` 2026-09-19. Before F22 wires probes into `make check`, run
  `bash -n` under `/bin/bash` over every probe.
- **The installed repo that still carried it is fixed too.** `casabat-comparador-cliente` shipped
  the same `perf.yml` (kit 2.1.0) and, in `deploy-production.yml`, the same shape around a job
  exporting `VERCEL_TOKEN`. Both moved to `env:` in that repo's PR #207, where the `smoke` job — the
  very step rewritten — ran green on GitHub Actions. It is merged there too, as PR #208.
  `Aurobalance` (`82ae8e3`) and `portal-expediente-kyc` (`34645ae`) already carried the scrubber
  and the `env:` workflow. `casabat`'s three `Sentry.init` have no scrubber, but they do not come
  from the Sentry pack.
- **A PR inherits whatever the local branch point carried.** #207 was cut from a `casabat` `main`
  that held an unpushed "Auto-save" commit, so it dragged 15 files of someone else's in-flight work
  behind a two-file fix. It was closed and reopened as #208 from `origin/main`. Branch from the
  remote, or read `git log origin/main..HEAD` before opening the PR.
- CI on PR #40, at `2dd1ad1`: `Required quality` pass, GitGuardian pass, Cursor Security Reviewer
  pass. That run is the probe's first green on Linux and bash 5 inside this repo's own pipeline.
- `make check` no longer needs `env -u SENTRY_AUTH_TOKEN`. The Sentry pack's "canary without an
  auth token" case assumed the token was absent and failed 74/1 wherever the CLI is authenticated;
  it now creates the absence and passes 75/0 with the token exported or unset.

Verification, with `SENTRY_AUTH_TOKEN` exported as this Mac normally has it: `make check` exit 0 —
core 274/0, Gherkin 15/0, CI-flow 57/0, Sentry 75/0; `make gates` 8 pass, 0 blocking;
`make verify-claims` re-verified all 15; `make clean-check` exit 0; `bash tests/contract/run.sh`
1 green (F15), 9 red.

## Current state — 2026-09-19 (backlog)

The F15–F30 backlog from the 2026-09-19 external review is on branch `backlog/f15-f30` (PR #39):
sixteen features in `feature_list.json`, all `not_started`, and ten acceptance probes under
`tests/contract/` for F15–F21 and F23–F25, written before the features they judge. The review's
patch was applied unedited with `git am`. `bash tests/contract/run.sh` reports 0 green, 10 red — red
on purpose; the probes stay out of `make check` until F22 wires them in.

**No feature is active. Next: F15**, then by priority; F15, F16 and F17 each fit one session. Iterate
against the feature's probe (`bash tests/contract/F15-packs-expose-nothing.sh`) without editing it,
and run `make verify-feature F=F15` only once the probe is green — every failed `verify-feature`
spends one of the feature's two review rounds.

- **F19 must not be activated** until the owner writes the `DECISIONS.md` entry that supersedes or
  confirms the 2026-09-15 rejection of a separate gate registry. That entry is the owner's, not an
  agent's.
- **Outside the list — owner decisions and rituals, not features:** publish release 2.3.0 before
  F18; return the repo to private; freeze the autonomy branch; version the skills inside the kit.

Verification: `make check` exit 0 — core suite 274/0, Gherkin pack 15/0, CI-flow pack 57/0, Sentry
pack 68/0 (with `env -u SENTRY_AUTH_TOKEN`, see below); `make gates` 8 pass, 0 blocking.

This Mac holds two `gh` accounts. A push here as `inno-arq` gets 403: run
`gh auth switch -u gonzalezulises` first, and `gh auth switch -u inno-arq` before the Mallol repos.

Merged since the entry below: #38.

## Current state — 2026-09-15

`version-sync` is registered as `optional` in `scripts/run-gates.sh` and its template (branch
`fix/version-sync-optional-in-installations`). Since #31 a missing `required` script blocks, and an
installation never ships `verify-version-sync.sh`, so every scaffolded repo's `make gates` ended
blocked on it (found in `inno-arq/mallol-costos`, kit 2.2.5). In the kit the gate still runs and
passes: `make gates` gives 8 pass, 0 blocking. Test 20g keeps the template optional and fails against
`2fb86f0`.

Verification: core suite 274/0, Gherkin pack 15/0, the CI-flow pack 57/0 and the Sentry pack 68/0.
On this Mac `make check` reports one Sentry failure only because the shell exports
`SENTRY_AUTH_TOKEN`; with `env -u SENTRY_AUTH_TOKEN` that pack passes.

Merged since the entry below: #34 (adopt versioned protected judge).

## Current proposal — 2026-09-06

Prepared an additive30-file protected judge snapshot from local PR33 continuation
a798c88ad625be2478d24df52c0dc45c51e2d4e4. The source manifest binds exact bytes
and modes. Live relocated quick gates passed8/0 against that exact isolated
target. Current main verification passed411/0 (two authenticated-gh load cases
explicitly omitted); startup passed273/0. The only active-code change disables
k6 usage telemetry for local fixtures; its behavior was independently reviewed.
Workflow, root judge scripts, feature_list and DECISIONS remain unchanged.

No new feature is active or claimed. This is a policy proposal, not adoption.
Remote publication of the source was blocked by automatic approval review, so
this separate proposal is retained locally for a later draft PR. No merge,
ruleset change or owner/baseline acceptance occurred. See
`docs/protected-judge-adoption.md` and its compact verification receipt.

## Previous state — retained as history

- **Last commit:** `b8c2ceb` — Merge pull request #12 (release 2.2.0)
- **Released:** `v2.2.0` — first release cut by release-please, tag and GitHub
  Release published, `VERSION` / `.harness/kit-version` / manifest all in sync.
- **Verification:** `make check` — passing, 311 assertions locally · `make gates`
  4 pass. `make check` now runs the packs' own failure matrices; linting them
  was never the same as running them. CI ran them for the first time on the
  release PR: 179 + 15 + 55 + 60, all green — the 55 is `load-testing` omitting
  two cases that need an authenticated `gh`, which the summary now says out loud.
- **Merge policy:** merge commits are disabled. Use `gh pr merge --rebase`;
  a merge commit duplicates every conventional PR title in the CHANGELOG.
- **Release ritual:** a release-please PR arrives with its required check never
  run. Close and reopen it to trigger the check, then merge. Never `--admin`.
- **Pack verification:** `packs/load-testing/` 57/57 · `packs/gherkin/` 15/15 ·
  `packs/sentry/` 75/75, exit 0
- **Audit:** rubric v2, 84 checks. The kit scores **84/84** against itself.
- **Startup path:** `./init.sh` — activation for other repos: `bin/harness-activate.sh`
- **Active feature:** none — all fourteen features passing (VCR 14/14)
- **Blocker:** none

## In Progress

_Nothing active. F01–F15 are `passing`, each promoted by `verify-feature.sh` with
recorded evidence — none set by hand. F16–F30 are `not_started`; the next is F16._

## Session log — 2026-08-31 (the pack itself had never been audited)

A security review on the first real installation found three holes the pack
opened in every repository it touched. All three verified against the code
rather than taken on the reviewer's word.

**Capability tokens were leaking to Sentry.** `sendDefaultPii: false` does not
filter the URL — Sentry sends the request URL, transaction name, Referer and
every navigation breadcrumb verbatim. The target repo carries tokens in the
path (`/mi-perfil/<token>`, `/encuesta/<token>`, `/encuesta-evaluacion/<token>`
— the review saw one, the code has three), so the first error on a client's page
would hand that client's live token to a third party. It is a wellbeing app.
`sentry-scrub.ts` now redacts them, wired through `beforeSend` and
`beforeSendTransaction` in all three inits; 17 cases pin it against the real
routes.

**Command injection in the workflow.** GitHub substitutes `${{ inputs.release }}`
before bash reads the line, so the quotes bound nothing and anyone able to
dispatch the workflow could inject into a job exporting `SENTRY_AUTH_TOKEN`.
Inputs moved to `env:`.

**Unauthenticated writes into a private tracker.** The client DSN is public, so
anyone can create a Sentry issue with a title they control, and
`sentry-to-issues` copied it into GitHub Issues where `@mentions` notify people.
Titles are sanitised and a run is capped.

**Worth keeping:** 68 failure cases could not have caught any of these, because
every one measured whether the gate detects failure — never what the gate
exposes by being installed. Matrix 68 → 75. Reasoning in
[the Agent Note](.agents/notes/implemented/bug-fix/2026-08-31-the-pack-had-to-be-audited-too.md).

## Session log — 2026-08-31 (installed in two real repos; the canary had never worked)

The Sentry CLI was installed and authenticated, which unblocked what the MCP
could not do: `sentry project create` succeeded where the MCP returned 403, so
the CLI carries the user's own permissions and the MCP does not. Two projects
created, `aurobalance` and `portal-expediente-kyc`.

**The canary had never once reached a real Sentry.** `cmd_canary` resolved the
DSN with `dsn="$(resolve_dsn)"`, and `parse_dsn` sets its three values as
globals — the command substitution ran it in a subshell, so they came back empty
and `ingest_send` composed `https:///api//envelope/?sentry_key=`. curl refused
it every time and the gate blamed the server. The one command whose job is to
prove errors arrive could not send one.

**Sixty-four cases missed it because the stub skipped the URL entirely** — the
only line that could be wrong was the only line never exercised. `ingest_send`
now builds the URL before the stub branch and records it; four cases assert its
shape. Reasoning in
[the Agent Note](.agents/notes/implemented/bug-fix/2026-08-31-canary-dsn-lost-in-a-subshell.md).
Matrix: 64 → 68.

Both projects now report `event confirmed stored`, exit 0 — the canary's full
cycle against a live Sentry, for the first time.

**Two gaps the pack has, found by installing it for real:** it ships no
`withSentryConfig` (so no source maps) and says nothing about CSP — both target
repos had a `connect-src` that would have blocked every SDK request silently.
Both were fixed by hand in those repos; the pack still does not carry them.

## Session log — 2026-08-31 (the live path finally ran, and it failed)

The DSN came from the Sentry MCP rather than from the user — `find_dsns` returns
it, so nothing had to be pasted into a chat. That closed the gap this file has
carried since the pack was written.

**`preflight` passed against the real DSN.** Nine checks, exit 0.

**`canary` was broken, and broken in the shape hardest to notice.** Its
`event_id` was `printf '%032d' 0 | tr '0' 'a'` — thirty-two literal `a`s,
identical on every run everywhere. Sentry deduplicates by `event_id`, so only
the first canary a project ever received was stored; every later one was
accepted with HTTP 200, dropped silently, and the gate reported UNCONFIRMED
against a healthy Sentry. It passes the first time you try it, which is the only
time anyone tests a new gate. The command whose whole argument is *accepted is
not stored* was making that error while sending its own probe.

Proven against `rizoma-di`, not reasoned about: two events with the constant id
left **one** issue; two with generated ids left **two**. The three canary issues
were resolved afterwards, so the project was left as found. Fix and costs in
[the Agent Note](.agents/notes/implemented/bug-fix/2026-08-31-canary-event-id-must-be-unique.md).
Matrix: 60 → 64.

**Still not verified:** release health. The org reports no session data, so
`json_field_deep`'s single-project assumption remains untested. Everything else
in the pack has now run against a real project.

## Session log — 2026-08-31 (the entry point was lying too)

**`--with sentry` installed nothing and said nothing.** The flag parser matched
only `gherkin` and let everything else fall through with no branch, no message
and a zero exit: the repo scaffolded, no pack landed, and a success banner
printed. Found while updating the `harness-creator` skill, where it was about to
be written down as a warning to work around. It now exits 64 naming the pack.
Three regression cases pin it. Reasoning in
[the Agent Note](.agents/notes/implemented/bug-fix/2026-08-31-unknown-pack-must-fail-loudly.md).

**Figures in living docs.** `tests/run-tests.sh` printed a score out of 74 when
the rubric has 84; README and `packs/sentry/index.md` quoted assertion counts
that had drifted four separate times in one day. Corrected where the number
carries signal, deleted where it only ages — `make check` prints the real count
every run, and a figure repeated from memory is how all four went stale.
Historical entries below and in `CHANGELOG.md` were left untouched: they are
records of what was true then, not claims about now.

**The auditor was scoring this repo wrong.** `grep -c` prints `0` and exits 1
when nothing matches, so `$(grep -c … || echo 0)` appended a second zero: the
variable held `"0\n0"` and every arithmetic comparison using it blew up. Five
call sites were affected — the VCR pair and the three budget counters. Effect:
`enf.stopcond` was unpassable for any repo without a `budget_defaults` block no
matter how complete its budgets were, and told the user to add `stop_condition`
to blocks that already had one. This repo had been at a true **84/84** while
reporting 83. Counters now go through one helper that returns an integer.
Reasoning in
[the Agent Note](.agents/notes/implemented/bug-fix/2026-08-31-audit-counters-must-return-an-integer.md).

**Outside the repo:** the `harness-creator` skill was pointing at
`harness-init.sh` (files only) instead of `harness-activate.sh` (files, remote,
CI ruleset, and a closing list of what is still the user's to do). It also cited
65 assertions and a 74-check rubric. Updated, and told to quote what the auditor
prints rather than a remembered number. It now defers day-zero client repos to
`nuevo-repo-cliente`, which already calls activate.

## Session log — 2026-08-30 (the two loose ends from the release)

**Skipped cases now reach the summary.** CI reported `55 correctos, 0 fallidos`
for `packs/load-testing/` where local reported 57, with nothing in the summary
explaining the gap — so the honest readings were "we lost coverage" and
"something broke", and ruling that out cost a session. Three environment guards
(authenticated `gh`, `node`, `python3`/PyYAML) now report through `omitir()`:
the summary reads `55 correctos, 0 fallidos, 2 omitidos` and names each one.
Omissions never change the exit code. Reasoning in
[the Agent Note](.agents/notes/implemented/bug-fix/2026-08-30-skipped-cases-must-reach-the-summary.md).

**Merge commits disabled on the repo.** GitHub puts the PR title in the merge
commit's body, so release-please read every conventional PR title twice and the
2.2.0 CHANGELOG listed three entries in duplicate. Rebase and squash stay
enabled; neither duplicates. Rebase is the one to use — it keeps the atomic
commits this repo requires, which squash would collapse. Nothing already
published was rewritten.

## Session log — 2026-08-30 (v2.2.0 shipped)

Both open PRs merged in order: #14 (the depth fix) first, so release-please
regenerated #12 and the fix landed in the 2.2.0 changelog before it shipped.

**The release PR was blocked by a check that had never run.** `Required quality`
reported nothing on #12, so branch protection had nothing to approve. Cause:
GitHub does not trigger workflows from events raised by the built-in
`GITHUB_TOKEN`, and release-please opens its PR with it. Closing and reopening
the PR by hand raises `reopened` under a human identity and the check runs —
3m23s, pass. `--admin` was available and refused: an untested release is the
artefact this repo exists to block. Recurs on every release; recorded in
[the Agent Note](.agents/notes/implemented/process/2026-08-30-release-pr-needs-reopen-to-run-checks.md).

`v2.2.0` is tagged and published. CHANGELOG lists the fix twice — once for the
commit, once for the merge commit — a cosmetic artefact of merging rather than
squashing, visible on earlier entries too. Not addressed here.

## Session log — 2026-08-30 (Sentry contracts, read against the live org)

The Sentry MCP was connected to the `rizoma-di` org, which replaced the pending DSN as the
way to check the pack's contracts: reading the real API needs no token pasted into a chat.
Three of the four shapes flagged as least certain above were checked against live data.

**The cron check was passing monitors nobody was watching.** `json_field` matched the first
occurrence of a key at any nesting depth. Sentry's monitor response carries a per-environment
`status` next to the monitor's own, and when the environment list serialises first, a
`disabled` monitor read as `ok` — `sentry-check cron` printed a pass and exited 0 for an
unwatched scheduled job. Same class of bug in the commit count, which counted each commit's
nested `author.id` and reported double. Both confirmed by running the gate itself, not a
reimplementation of its functions. Fix and costs in
[the Agent Note](.agents/notes/implemented/bug-fix/2026-08-30-json-readers-must-honour-depth.md).
Five regression cases now pin the real nested shapes (55 → 60); four of them fail against the
previous readers, which is what makes them worth having.

**Why the stubs never caught it:** every fixture in the matrix was a flat object. The live org
is why the real shape came to light — and it also explains why the gap survived: `rizoma-di`
has no cron monitors at all, and all 25 of its releases carry zero associated commits, so
nothing in production was exercising those paths.

**`make check` now runs the packs.** The Makefile linted `packs/*/verify-pack.sh` but never
executed them: 132 failure modes sat outside the gate that is supposed to guard every commit,
so a pack could regress with the repo green. Now `check` runs each matrix and propagates the
failure.

Still not closed: the ingest path (`canary`) and release health have not run against a real
project — the org reports no release health data, so `json_field_deep`'s single-project
assumption stays unverified. That one still needs a DSN.

## Session log — 2026-08-30 (observability)

Added `packs/sentry/`: an observability gate that passes only when a marked event is sent
and read back from the project. Rationale and costs in
[the Agent Note](.agents/notes/implemented/feature/2026-08-30-sentry-observability-pack.md).
`docs/ciclo-desarrollo-harness.drawio` now carries the stage that motivated it — production
signal returning to the backlog, which is what turns the cycle from a line into a loop.

Extended the same session to the rest of the product: source maps AND associated commits
per release, crash-free rate, cron monitors, and a triage command that turns unresolved
issues into backlog candidates. Plus the Next.js instrumentation templates, so the pack
installs Sentry rather than only inspecting it. 45 failure modes, all blocking.

Not done, and deliberately: the pack's live path has never run against a real Sentry
project. The 45 failure modes are verified through the `SENTRY_STUB_DIR` seam, which proves
the gate's logic but not the ingest and API contracts — in particular the exact response
shapes for monitors, release health and commits are the least certain part of this pack.
First real DSN closes that gap.

`.env.sentry.example` is deliberately NOT tracked. The agent cannot read or write `.env.*`
(global permission rules; narrowing the read deny was refused by the safety classifier), and
committing a file it cannot read would mean shipping unverified content. The full contents
live in `packs/sentry/index.md`, which is the file the pack's readers actually consult.

Releases are now cut by release-please from the conventional commits this repo already
writes. The version lives in four files and only two are ones release-please can write, so
`scripts/sync-version.sh` propagates the manifest inside the release PR and
`scripts/verify-version-sync.sh` — registered in the gate registry — fails the build if the
four ever disagree. Rationale in
[the Agent Note](.agents/notes/implemented/process/2026-08-30-release-please-with-a-version-sync-gate.md).

## Next Steps

1. **BLOCKED — enable "Allow GitHub Actions to create and approve pull requests".**
   The Release workflow ran on the merge of #10 (run 33323634694) and got everything right:
   it computed `2.2.0` from the conventional commits, generated the CHANGELOG with the
   configured Spanish sections, and pushed the branch
   `release-please--branches--main--components--harness-kit`. It then failed on the last
   step with `GitHub Actions is not permitted to create or approve pull requests`.

   That is a repository setting, not a code defect. A human enables it in
   Settings → Actions → General → Workflow permissions, or with:

   ```bash
   gh api -X PUT repos/gonzalezulises/harness-kit/actions/permissions/workflow \
     -f default_workflow_permissions=read -F can_approve_pull_request_reviews=true
   ```

   Trade-off worth stating: the same flag also lets a workflow approve pull requests. This
   repo's ruleset requires a passing `Required quality` check rather than a human approval,
   so enabling it does not open a review bypass here — but it would in a repo that gates on
   approvals.

   Still unproven after that: the `sync-version.sh` job. Its `pr_branch` expression and its
   push into the release PR have never run, because the PR was never created. The release
   that follows enabling the flag is the real test.
2. Run `packs/sentry/` against a real project once, and record the evidence. Until then the
   pack is verified in logic only.
2. Use it on a real delivery repository. `bin/harness-activate.sh` handles the mechanics;
   the step that decides whether this is real or decoration is replacing the placeholder
   features with the actual backlog.
2. Roll out to more of the ~173 repositories. Audit first (read-only), harness the ones
   that will see repeated agent sessions.
3. Grow `.harness/arch-rules.json` as patterns repeat — every recurring review finding
   becomes a rule.
4. Consider splitting Aurobalance's 432-line `AGENTS.md` into `docs/` topic files
   (`inst.short` is the one recommended check it fails).
5. Still unverified in `packs/load-testing/`: the Vercel-bypass and IAP auth paths are
   implemented and checked against **simulated** responses only.

## Blockers

_(none)_

---

## Session Log

Newest first. One entry per session.

### 2026-08-14 — governance layer: budgets, claims, the gate, Gherkin, decisions (F09-F14)

Built the layer that makes the harness binding rather than advisory, grafting the designs
worth keeping from `ai-software-factory` (now archived — it scored 26/74 against this
auditor while never producing a governed repository).

- **F09 budgets** — a failed verification spends a review round, written to the feature's
  ledger by the script. Exhaustion sets `blocked` and exits 3/4. Taken from the Control
  Plane plan, which specified these limits and never implemented them.
- **F10 verify-claims** — every `passing` is re-run from the protected base branch.
  `FALSE_CLAIM` on disagreement, `NOT_VERIFIABLE` when a claim cannot be checked at all.
- **F11 the gate protects itself** — GitHub counts a job skipped by its own condition as a
  PASSING required check, so requiring the check name protects the result but not the
  definition. Closed with a push ruleset over the workflow path; `harness-protect.sh`
  installs both rulesets and GETs them back before claiming anything.
- **F12 packs/gherkin** — Cucumber exits 0 with zero scenarios executed. The gate reads the
  messages report instead, with `--expect N` as an absolute counter.
- **F13 verify-decisions** — `DECISIONS.md` is append-only; rewriting an earlier entry is
  rejected.
- **F14 activate/status** — eight manual steps became one command, and three honest states
  (`READY_DUAL` / `READY_PARTIAL` / `READY_LOCAL`) replaced a yes/no that was never true.

**Measured against GitHub, replacing an earlier assumption:** `required_status_checks` DOES
work on a private personal repo (id 20860227, active). Push rules do not — 422 "Only
org-owned repos can have push rules". The old note that this needed Team was about
`required_workflows`, which this design never used. So personal repos get a real gate that
cannot protect itself: `READY_PARTIAL`.

**Evidence:** `docs/evidence/2026-08-14-gate-canary.md` — four PRs in an org canary, one
merged and three blocked, including a push rejected for touching the workflow.

**Trap worth remembering:** `scripts/X` and `templates/full/scripts/X` are the same file in
two places and the suite runs the template copy. Editing only the root one fails with no
visible cause. There is now a drift check, and it immediately found real drift: the subshell
fix from `84e8c71` had never reached the kit's own `clean-state-check.sh`.

### 2026-08-07 — end-user session and route discovery (F08)

- **Goal:** measure the routes that actually matter, and stop leaving "what is measurable"
  to whoever configures the gate that day.
- **Completed:** `lib/session.js` (Supabase end-user session), `lib/abort.js` (own module,
  breaks an import cycle), `PERF_AUTH=supabase`, and `bin/perf-discover`. `verify-pack.sh`
  grew from 45 to 55 cases. A thin routing skill lives at
  `~/.agents/skills/medir-rendimiento` — it implements nothing, it points here.
- **Verification run:** `make verify-feature F=F08` passed both layers; `make check` 65/65;
  VCR 8/8; `verify-pack.sh` 55/55.
- **What measuring a real project taught us.** Against casabat-comparador-cliente (Next 16 +
  Supabase, 36 routes): 27 routes redirect to /login, and `/` serves a shell whose entire
  visible text is "Comparador de Precios — Casabat Cargando…". Measuring `/` would have
  reported an excellent p(95) over an empty page. The load profile on what IS measurable
  (`/login` SSR + `/api/health`) gave p(50) 16.2 ms, p(95) 62.4 ms, p(99) 73.1 ms, 0 % errors
  over 24 067 requests — **on a local Mac, not comparable to production**.
- **Cookie format, read from the installed @supabase/ssr 0.12.4 rather than from docs:**
  name `sb-<project-ref>-auth-token`, value `"base64-"` + base64url(JSON), and
  `stringToBase64URL` emits NO padding — which matches k6's `b64encode(s,'rawurl')` and NOT
  `'url'`. Verified by round-trip: k6 encodes, Supabase's own `stringFromBase64URL` decodes,
  10/10 field checks including multibyte UTF-8.
- **Design constraint found the hard way:** k6 forbids HTTP in the init context, so the
  session cannot be minted where `resolveTarget()` runs. It is minted in `setup()`, which
  also let the guard run WITH the session applied. That forced `abortWithReason` into its own
  module to break the target↔session import cycle.
- **Bugs my own verifier caught:** perf-discover proposed a marker extracted from one route
  while pointing the guard at another (that config aborts on first run); it proposed a phrase
  formed by gluing the title to the body, which exists nowhere in the HTML — now every marker
  is checked against the served body before being suggested; and the shell heuristic
  ("under 60 visible chars") misclassified a legitimately minimal page, so it now requires
  either a loader keyword or thin-text-plus-heavy-markup.
- **Still unverified:** that a real Supabase session is ACCEPTED by an app and returns 200 on
  a protected route. Everything up to that point is verified (variable validation, the real
  400 from Supabase on bad credentials, cookie format). Closing it needs a test user.
- **Next best action:** get a test user for one project and measure the routes that matter.

### 2026-08-07 — installer and enforceable gate (F07)

- **Goal:** make the gate installable in one command and actually enforcing, instead of a
  set of files to copy plus a manual step everyone forgets.
- **Completed:** `bin/perf-init.sh` (copies files, updates `.gitignore`, detects stack and
  routes, sets repo variables, registers the required check, `--dry-run`, idempotent,
  `--account` for multi-account setups), `bin/perf-resolve-target`, and a redesigned
  `perf.yml`. `verify-pack.sh` grew from 14 to 45 cases.
- **Verification run:** `make verify-feature F=F07` — static and e2e passed, promoted by
  the harness. `make check` 65/65. `make audit` 74/74. VCR 7/7.
- **The design error this session fixed:** the previous workflow triggered only on
  `deployment_status`. Marking that check as required would deadlock any PR that produces
  no preview — the check never reports, so the PR can never merge, and the only escape is
  disabling the rule. Now it triggers on `pull_request` and resolves the preview itself;
  when there is nothing to measure it says so and passes. Not measuring is not the same as
  measuring badly.
- **Platform limit, measured by creating and deleting real rulesets:** required status
  checks need rulesets, and GitHub returns `403 Upgrade to GitHub Pro or make this
  repository public` for **private repos on a Free personal account**. Public personal
  repos work (created a ruleset with `enforcement=active` requiring `smoke`, then deleted
  it). Org repos with a paid plan appear to work — the endpoint returns without a plan
  error — but that was NOT verified by writing. So in a private client repo the gate runs
  and publishes evidence but cannot block; the installer detects this and says so instead
  of pretending it configured something.
- **Multi-account trap worth remembering:** `gh auth status` reported `gonzalezulises` as
  the active account while the API answered as `inno-arq`. Permissions differ sharply
  between them (`admin=false` vs `admin=true` on the same repo), so the installer now
  resolves identity via `gh api user`, reports it, and accepts `--account` to pin it
  without touching the global active account.
- **Bugs the real-repo dry run exposed that fixtures could not:** an API error response was
  captured as a ruleset id, so the 403 was reported as "the rule already exists" — the
  worst possible outcome, hiding the real problem; and route detection left
  `/ahorro/page.tsx` because `\?` is not a quantifier in macOS BSD `sed`. Both are covered
  by cases now.
- **Next best action:** decide where the first enforcing gate lives (org repo vs public vs
  GitHub Pro), then run the installer for real there.

### 2026-08-07 — performance gate pack (F06)

- **Goal:** make a performance gate part of every delivery, not a per-project afterthought.
- **Completed:** `packs/load-testing/` — target/auth resolution for four platform types
  (local, public API, Vercel preview bypass, Cloud Run behind IAP), a guard that proves the
  application answered before anything is measured, a fail-closed `bin/perf-check`, a
  blocking smoke profile, an on-demand load profile, a committed drift baseline, Markdown
  delivery evidence, a CI workflow, and `verify-pack.sh` (14 cases).
- **Verification run:** `make verify-feature F=F06` — static and e2e layers passed, F06
  promoted by the harness. `make check` — 65/65. `verify-pack.sh` — 14/14, exit 0.
- **What the measurements changed:** k6 v2.1.0 exit codes were measured, not assumed —
  thresholds crossed 99, `test.abort()` 108, and **a runtime error in the default function
  exits 0**. A `checks: ['rate==1.0']` threshold does not catch that, because a rate
  threshold over a metric with no samples evaluates as passing; the iteration counter does
  not either, since it counts failed iterations as completed. Only a custom counter with an
  absolute `count>=N` threshold does. That single finding is why `lib/metrics.js` exists in
  the shape it does. Also found: `--no-summary` was removed in k6 v2, so any gate copied
  from a pre-v2 tutorial fails to start.
- **Bugs found in my own work by the pack's verifier:** the evidence report advertised a
  p(99) column that k6 leaves empty unless `summaryTrendStats` declares it; the drift
  failure message printed before the numbers it referred to (unflushed stdout against
  unbuffered stderr); `perf-check` carried three `|| true` escapes that were harmless but
  indistinguishable from real ones, now replaced by an explicit function so the file
  contains zero exit-code escapes; and the verifier's own escape check fired on the
  comments that warn against `|| true`.
- **Known risks:** the two authenticated paths are verified against **simulated** platform
  responses (302 to an auth host, 200 serving a login page, 401), not against a live Vercel
  preview or a live IAP-protected service. The first real adoption should confirm both.
  The load profile is deliberately excluded from the merge path — see the SOP for why
  a flaky gate is worse than no gate.
- **Next best action:** adopt the pack in one real delivery target and confirm the
  Vercel and IAP paths against the live platforms.

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

## 2026-08-30 — Gate proof
D12-D14 merged to main; this PR exercises the full gate with the new claims output visible from base.
