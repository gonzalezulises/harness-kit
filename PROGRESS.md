# PROGRESS.md — harness-kit

The durable memory of this repository. Every session reads this first and writes to it
last. If it disagrees with your recollection, this file wins.

## Current State

- **Last commit:** `7dfcd14` — fix: correct invalid deny rule pattern in project settings
- **Verification:** `make check` — passing, 175/175 assertions · `make gates` 3 pass
- **Pack verification:** `packs/load-testing/` 57/57 · `packs/gherkin/` 15/15 ·
  `packs/sentry/` 45/45, exit 0
- **Audit:** rubric v2, 84 checks. The kit scores 77/84 against itself.
- **Startup path:** `./init.sh` — activation for other repos: `bin/harness-activate.sh`
- **Active feature:** none — all fourteen features passing (VCR 14/14)
- **Blocker:** none

## In Progress

_Nothing active. All fourteen features are `passing`, each promoted by
`verify-feature.sh` with recorded evidence — none set by hand._

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

`.env.sentry.example` could not be written by the agent: the global permission rules deny
reads of `.env.*`, and narrowing that deny was refused by the safety classifier. The file's
content lives in `packs/sentry/index.md`; a human creates it in one command.

## Next Steps

1. Run `packs/sentry/` against a real project once, and record the evidence. Until then the
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
