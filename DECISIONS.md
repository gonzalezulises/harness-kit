# Decisions

Architectural and operational decisions, newest first. One entry per decision that a
future session would otherwise re-litigate or accidentally undo.

Record a decision when the answer was not obvious, when you rejected a plausible
alternative, or when the reason lives outside the code. Do not record what the code
already says.

---

## 2026-09-19 — The F15 probe is fixed for bash 3.2; its contract is unchanged

**Context.** `tests/contract/F15-packs-expose-nothing.sh` was written on Linux and watched failing
there. On macOS, whose only `bash` is 3.2.57, it never ran: bash 3.2 scans the body of a quoted
heredoc inside `$( )` as shell text, and the Python literal `"${{"` opens a `${` that never closes
— `syntax error near unexpected token '('`, exit 2, before inspecting a file. Its red on this Mac
was a parse error, not a verdict, so `make verify-feature F=F15` could only fail here, whatever the
code. The other nine probes and the 274-case suite parse and pass under 3.2.

**Decision.** Spell the literal `"\x24{{"` in the probe's two Python lines. It is the same
three-character string to Python and gives bash nothing to open. No check, path or message changed.
Watched both ways under bash 3.2.57 and 5.2.37: 1 ok / 5 fail on `9f4e047`, 6 ok / 0 fail after F15.
The owner authorised the edit on 2026-09-19, after the instruction not to touch the probe.

**Alternatives rejected.** Installing bash 5 on this Mac: the probe would stay broken on stock
macOS, and F22, which wires every probe into `make check`, would inherit it. Running
`verify-feature` in a Linux container: the other layers would run without the tools they measure.

**Consequences.** A probe has to parse under bash 3.2 like the rest of the kit. Before F22 wires
probes into `make check`, run `bash -n` under `/bin/bash` over each one.

---

## 2026-09-15 — version-sync is optional in the shared gate registry

**Context.** `version-sync` checks the four copies of the kit's own release version. It was meant
to SKIP wherever its script is absent, so the kit and its installations could share one
`run-gates.sh` (2026-08-31). The 2026-09-03 change "only PASS satisfies a gate" (#31) turned a
missing script into NOT_EXECUTED, which blocks for every `required` gate, and `version-sync` was
registered as required. Since then `make gates` ends blocked in every scaffolded repo; seen on
2026-09-15 in `inno-arq/mallol-costos` (kit 2.2.5), with the other seven gates in PASS.

**Decision.** Register `version-sync` as `optional` in `scripts/run-gates.sh` and in its template,
which stay identical. In the kit the script is present, so the gate runs and must pass; in an
installation it reports "not installed (optional)". Test 20g keeps the template optional.

**Alternatives rejected.** A separate registry for installations: it breaks the in-sync test and the
shared-file decision. Copying `verify-version-sync.sh` into installations: it exits 3 there for lack
of a release manifest. Bringing SKIP back for required gates: it reopens the silent hole #31 closed.

**Consequences.** Deleting `verify-version-sync.sh` from the kit would now stand down instead of
blocking; the release workflow still runs it directly. Installations get the fix on their next kit
upgrade; until then they can mark the entry optional locally, as `mallol-costos` did.

## 2026-09-03 — An oracle must carry proof it can fail

**Context.** `AGENTS.md` already required it — "una prueba que solo se ha visto
pasar no cuenta: hay que verla fallar contra el estado defectuoso" — and it had
been a convention, which means it held exactly as long as someone remembered it.

The failure that made it worth a gate: a rule was fixed so a supplier list
reading «8D/D6» matched an «8D» catalogue entry. Unit tests green, full suite
green, the reasoning sound. Run against the live catalogue, the same rule matched
two products of opposite polarity — a battery cannot have its terminals on both
sides. The tests knew only the cases their author imagined, and their author was
the one who had got it wrong.

**Decision.** `verify-oracles.sh`, a registered gate over `.harness/oracles/`.
A criterion marked critical must be TEST_READY, answer the eight questions of V2
§9.3, name tests that exist, and carry a `falsification` block: the defect that
must make those tests fail, and the commit at which someone watched them fail.

The eight answers are checked for presence. One field is checked for truth: the
gate verifies `proved_sha` is in this history and that **no named test has been
modified since it**. Edit the test after proving it can fail and the proof no
longer covers the test that exists — the criterion goes stale and blocks.

**Alternatives rejected.** Validating the eight answers more strictly, which
would only get better prose; the questions do their work when a person answers
them, and no schema makes that happen. Running the mutation automatically, which
means letting a gate patch the working tree — power this harness should not hold
for a check that runs on every commit. And leaving it as the convention it
already was: it was already written down, and was not followed.

**Consequences.** Oracles need curation or the folder becomes ceremony: one per
critical criterion, not one per requirement. The staleness check will fire on
legitimate test refactors, and the repair is the right one — break it again and
watch it fail. A pasted SHA defeats this gate, and the script says so out loud
rather than implying a guarantee it cannot give.

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
