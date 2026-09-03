# Decisions

Architectural and operational decisions, newest first. One entry per decision that a
future session would otherwise re-litigate or accidentally undo.

Record a decision when the answer was not obvious, when you rejected a plausible
alternative, or when the reason lives outside the code. Do not record what the code
already says.

---

## 2026-09-03 — Only PASS satisfies a gate, and a governed change must cite what governs it

**Context.** Two gaps left by the delivery-doc work, both drawn from the same
post-mortem.

The runner knew two answers: exit zero, or everything else as FAIL. A gate whose
script was absent reported SKIP, which never failed the run. Both collapses hide
the state that matters most — the gate that never checked anything. That is not
hypothetical: `verify-delivery-doc.sh` shipped with a branch that, handed a ref it
could not resolve, printed "no new migrations" for a release that shipped one. A
green line for work never done.

Separately, four failures in that session had one shape: the right answer was
already written in a file nobody opened. A fix invented engineering tolerances
while `DECISIONS.md` §D2 forbade exactly that, one grep away. `rules/fuentes.md`
now states the precedence in prose, and prose depends on the reader remembering
to look, which is precisely what failed.

**Decision.** Two changes.

- `run-gates.sh` reports one of PASS, FAIL, NOT_CONFIGURED, TOOL_FAILURE,
  INCOMPLETE, POLICY, UNKNOWN or NOT_EXECUTED, mapped from the V2 exit-code
  contract, and **only PASS lets the run go green**. FAIL and TOOL_FAILURE both
  block but stay distinct, because one says fix your code and the other says fix
  your machine; sending people to the wrong one wastes the diagnosis. Each gate
  now declares itself `required` or `optional`: a required gate that is missing is
  NOT_EXECUTED and blocks, so a gate cannot go absent quietly.
- `verify-context-routes.sh` reads `.harness/context-routes.json` — which
  documents govern which paths — and fails a change under governed paths that
  cites none of them, in a commit message on the branch or in an Agent Note it
  carries. Config is validated before the diff is computed: the first draft parsed
  the map only when a diff existed, so a corrupt map passed on a commit with
  nothing governed, which is the same silence.

**Alternatives rejected.** For the runner, keeping FAIL as the single non-pass
state and documenting the nuance — the nuance was already documented and still
produced a false green. For the routes, a checklist in `AGENTS.md` asking the
agent to consult the sources: that is what `fuentes.md` is, and it depends on
memory. Also rejected: making the citation prove reading. It cannot. To write
«DECISIONS.md §D2» you must go find §D2, and going to find it is the whole
intervention; claiming more would be lying about what the gate enforces.

**Consequences.** A gate can no longer be silently absent or silently
inconclusive, which will surface half-installed harnesses that used to look
green. Route maps need per-repo curation: a route that never matches is dead
weight, and one that fires on every change trains people to paste the citation
without reading — so they are kept few and narrow, added only when the mistake
they prevent can be named.

---

## 2026-09-03 — Verify the delivery, not only the code

**Context.** A release went out with green code and a runbook that described the *previous*
release. It carried `ecr-push-tag v1.2.4` inside a v1.2.5 pass — a command that would have
deployed the wrong image — a section explaining a migration already applied, and none
explaining the one being shipped. Every gate passed. Two careful readings missed it, and the
error was found only because an unrelated sync check aborted.

The post-mortem found nine failures in that session with three roots, and one pattern that
matters more than any of them: **wherever an executable verifier existed, it worked** —
`make check`, the gates, the sync's alignment check, an improvised impact script, even the
punctuation hook. Every one of the nine happened in the zone the kit does not verify: prose,
delivery documents, and claims about external systems.

The irony that settled it: `verify-version-sync.sh` already exists here, reasoning that "the
version lives in four places and they must agree, and a release that bumps some and not the
others ships silently". That reasoning was applied to the kit and never handed to the
repositories the kit installs.

**Decision.** Three additions, each closing one root.

- `verify-delivery-doc.sh`, a registered gate: the deploy runbook's heading names the current
  version; every live version-tagged command uses it; every migration new since the last
  delivery is named in the document; no subsection presents an older version as this release;
  relative links resolve. Fail-closed, including an unresolvable `DELIVERY_BASE` — the first
  draft skipped on one and reported "no new migrations" for a release that shipped one.
- `rules/fuentes.md`: which source wins when two disagree. Repo documentation outranks an
  external report; a deployment's own record outranks a README. A black-box audit describes
  symptoms, and the cause it proposes is its hypothesis, not authority.
- `verify-impact.template.mjs`: a rule change ships with a run against real data listing which
  verdicts flip, read permissive-side first. This is what caught a rule that was correct in
  general and wrong in a specific, shippable way — after the unit tests were green.

**Alternatives rejected.** More review, longer checklists, an auditor subagent. None would have
caught any of the nine: the stale tag survived two readings of the table it sat in. Prose
review is precisely what failed, so more of it is not the repair.

**Consequences.** Delivery documents are now gated like code, which means a stale runbook fails
a build instead of reaching an operator. The gate needs per-repo configuration
(`DELIVERY_BASE`, `DELIVERY_EXTRA_DOCS`, `CLIENT_ONLY_PATHS`); unconfigured it skips loudly
rather than passing quietly. And `verify-impact` is deliberately a template, not a gate: what
counts as an acceptable flip is judgement, and a gate that pretends otherwise would be
rubber-stamped.

Longer decisions get their own file in `docs/decisions/`.

---

## 2026-08-31 — A declared gate must be able to fail

**Context.** `harness-init.sh` defaulted `E2E_CMD` to `echo 'TODO: ...'` with no `; false`,
while AGENTS.md declares layer 3 mandatory for changes crossing component boundaries. Three
scaffolded repos carried a mandatory e2e layer that exited 0 without opening a browser. The
neighbouring line, `VERIFY_CMD`, had `; false` all along — it was a one-line omission the kit
could not notice.

**Decision.** The e2e default fails closed; `scripts/verify-makefile-gates.sh` rejects any
target that announces a TODO and still exits 0, registered in `make gates`; and the suite
asserts every registered template script actually reaches the scaffolded repo. Detail in
[the Agent Note](.agents/notes/implemented/process/2026-08-31-una-puerta-declarada-debe-poder-fallar.md).

**Alternatives rejected.** Turning run-gates' SKIP into FAIL — it is the mechanism that lets the
kit and its installations share one run-gates.sh (`verify-version-sync.sh` is the kit's own), and
it would have failed every new repo. Writing the checker as a stack test — the kit installs into
Node, Rust and Go repos, so its own verifiers must be bash.

**Consequences.** A freshly scaffolded `make e2e` fails until someone implements it. That is the
difference between a visible TODO and a phantom verification.

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
