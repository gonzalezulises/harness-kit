# Decisions

Architectural and operational decisions, newest first. One entry per decision that a
future session would otherwise re-litigate or accidentally undo.

Record a decision when the answer was not obvious, when you rejected a plausible
alternative, or when the reason lives outside the code. Do not record what the code
already says.

Longer decisions get their own file in `docs/decisions/`.

---

## 2026-08-30 — release-please cuts releases; a gate guards the version's four copies

**Context.** Releases were manual: edit `VERSION`, `.harness/kit-version` and `CHANGELOG.md`,
then remember to tag. The kit already writes conventional commits, so the release notes were
being derived by hand from data that was already structured.

**Decision.** Adopt release-please with `.release-please-manifest.json` as the source of
truth, propagate it with `scripts/sync-version.sh` inside the release PR, and register
`scripts/verify-version-sync.sh` in the gate registry. Full rationale in
[the Agent Note](.agents/notes/implemented/process/2026-08-30-release-please-with-a-version-sync-gate.md).

**Alternatives rejected.** Letting release-please write `VERSION` directly — its generic
updater needs an annotation comment inside the file, and `VERSION` is parsed with
`tr -d '[:space:]'` by three scripts. Teaching those scripts to skip comments was rejected:
shipping code should not grow a parser to suit a release tool.

**Consequences.** A release now needs no manual edits, but it depends on a second job
running inside the release PR. That job failing silently would ship a repository whose
version files disagree — so the gate exists, and the test suite asserts it rejects that
case rather than trusting it. `templates/full/scripts/run-gates.sh` gains a row that reports
SKIP in scaffolded repositories, which is what the registry's SKIP was designed for.

---

## 2026-08-30 — Observability gates on proof of arrival, not on configuration

**Context.** The cycle ended at "merge to main": nothing in the kit observed what was
deployed. Adding Sentry raised the question of what the gate should assert.

**Decision.** `packs/sentry/` passes only when a uniquely marked event is sent and then read
back from the project through the Web API. Configuration presence is not evidence, and the
ingest `200` is not either — Sentry accepts and then drops on quota, inbound filters and
rate limits. Full rationale in
[the Agent Note](.agents/notes/implemented/feature/2026-08-30-sentry-observability-pack.md).

**Alternatives rejected.** Asserting that the SDK is installed and a DSN is set — a tenth of
the work, and it certifies the exact failure the pack exists to catch: an empty DSN, a
documentation placeholder or `sampleRate: 0` all leave the build green and the project empty.

**Consequences.** The gate cannot sit in the merge path: proving arrival needs a live
deployment and real secrets, so it runs on `deployment_status` after production succeeds. A
broken observability config can merge and is caught minutes later. Every canary also writes
a real marked error event into the production project — noise traded for proof.

---

## 2026-08-14 — Build the governance layer here, not in a new repository

**Context.** `ai-software-factory` was started to be the system that governs how AI builds
software. In six days it produced 11,411 lines of governance documentation, 104 lines of
product code, zero governed repositories, and two CI runs that both failed. Measured with
this repository's own auditor it scored 26/74 with 3/7 critical checks — the repository
meant to govern development did not govern itself. It was also the third attempt at the same
problem in five days (`repo-assurance` 3 Aug, `harness-kit` 5 Aug, `ai-software-factory`
7 Aug), each started from scratch.

**Decision.** `harness-kit` is the base. Graft the four designs from the factory that were
worth keeping — anti-loop budgets, the fail-closed gate, the Gherkin failure matrix, the
decision ledger — and archive it.

**Alternatives rejected.**

- *Resume `ai-software-factory`.* Restarting it means reviving the mission machinery that
  caused the problem, starting from a broken CI and self-invalidated evidence.
- *Adopt an external base (`spec-kit`, 128k stars; BMAD; `superpowers`).* The ecosystem
  solved the **specification** half. The **execution-control** half — budgets, WIP=1,
  evidence as receipt, a gate nobody can hand-write past — is barely addressed, and that
  half already worked here. Adopting one would have been the fourth start from scratch.

**Consequences.** The verdict now lives outside the agent's reach, which means the harness
can refuse work rather than advise against it. It also means the gate has a real dependency
on GitHub plan capabilities: push rules are organization-only, so a personal repository can
reach `READY_PARTIAL` but not `READY_DUAL`. That limitation is reported rather than hidden.

---

## 2026-08-05 — Adopt the harness

**Context.** Agent sessions were starting from zero: rediscovering how to build, what was
half-finished, and what "done" meant.

**Decision.** Adopt the harness: `AGENTS.md` as the operating contract, `feature_list.json`
for scoped state, `PROGRESS.md` for cross-session memory, `init.sh` as the one startup path.

**Alternatives rejected.** A longer README — it documents the project for humans but does
not constrain agent behavior or carry state between sessions.

**Consequences.** Every session now starts by reading `PROGRESS.md` and ends by updating
it. Features cannot be marked done without recorded evidence.
