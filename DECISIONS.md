# Decisions

Architectural and operational decisions, newest first. One entry per decision that a
future session would otherwise re-litigate or accidentally undo.

Record a decision when the answer was not obvious, when you rejected a plausible
alternative, or when the reason lives outside the code. Do not record what the code
already says.

---

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


---

## 2026-09-05 — MIGRATION-01: implement the optional local autonomy pack

**Context.** The hardening audit found that mutable `feature_list.json` and session telemetry do not provide verified journal replay. The owner reviewed the proposed transition and instructed “Implementa todas las mejoras.”

**Decision.** Implement H01–H09 in this repository, preserving the portable legacy kit and adding an explicitly adopted local pack. In adopted consumers, v2 state is derived from verified replay; legacy evidence is retained as `LEGACY_UNVERIFIED` until new verification. Mechanical transformations require deterministic equivalence, while bounded remediation uses an existing scoped grant. Normative changes and baseline acceptance retain explicit human authority.

**Consequences.** Fix known verifier bypasses before expanding capabilities. No new service, external platform, forced consumer migration, consumer deployment or retrospective baseline approval follows from this mandate. Implementation record and compatibility choices: [approved plan](docs/implementation/2026-09-05-harness-hardening/plan.md) and [ledger](docs/implementation/2026-09-05-harness-hardening/ledger.md).


---

## 2026-09-06 — H02: live profiles, protected judges and local evidence boundaries

**Context.** MIGRATION-01 authorizes R10–R12/R14–R22 hardening. Tests of fixture gates did not apply the live policy; consumers inherited a kit-only required gate, status inferred readiness, and local evidence/index operations could report false success.

**Decision.** Version installation applicability explicitly. Full universal gates remain required; kit-only version synchronization is inapplicable to full consumers; minimal is an explicitly limited contract scaffold. Apply live quick gates before the project/pack pipeline without recursion. Protected CI keeps exact base judges/config separate from head targets. Missing compatible protected policy stops adoption and requires an owner-controlled maintenance action; it never allows candidate-selected authority or merging an unverified PR as bootstrap.

Repair guidance is excluded from layer identity, while exact command bytes and every other contract field remain protected. Oracle parsing uses PyYAML==6.0.3 installed in an isolated repository tools environment. Critical/high evidence requires a local content-bound RED receipt, exact current test bytes and resolvable proof history; local receipts do not supply independent authentication. Staged formatting preserves working-tree bytes, rejects symlinks and blocks formatter errors. Infrastructure uses owned processes, OS-assigned ports and bounded readiness. API failures remain indeterminate.

**Consequences.** Full consumers acquire a pinned parser dependency, existing critical oracles need actual witnessed receipts, and old protected bases need explicit policy adoption. Original H01 evidence and F09 blocked receipts remain intact. H02 does not authorize baseline acceptance, branch-rule weakening or product deployment. See the H02 Agent Note and docs/harness-capabilities.md.


---

## 2026-09-06 — H03: typed identity and scoped authority

**Context.** MIGRATION-01 requires proof of mechanical equivalence without turning derived artifacts or agent assertions into authority.

**Decision.** Use one opt-in nested Node package with pinned YAML2.9.0 and Zod4.5.4, strict built-in schemas and per-runtime opaque handles. The operator establishes repository, actual runtime/dependency bundle, schema contract, exact authority digest, enrolled Ed25519 keys, current time/revocation basis and registered file classes. Adoption and baseline receipts bind exact scoped authority and recomputed input manifests. Candidate booleans, callbacks and serialized summaries cannot create authority.

Exact numeric source forms remain distinct. Unsupported schemas, directives, comments and proofs stop. Closed ordinary-data key reorder and source-content digest derivation produce assessments only. Protected authority-source byte changes still require a human; this v1 proof does not rebind their trust anchors. Classification grants neither execution permission nor completed postconditions.

**Consequences.** Initial schemas are deliberately narrow; Node is optional for legacy consumers and dependencies install in the runtime subdirectory. Future contracts extend this same verified boundary. No owner key enrollment, policy adoption, baseline acceptance or deployment authority follows from implementation. See the H03 Agent Note and packs/autonomy/index.md.

---

## 2026-09-06 — H04: journal and mechanical fresh-run recovery

**Context.** Commit/representation changes should not demand another baseline decision or erase spent budget and prior verdicts.

**Decision.** Extend the same runtime with one local journal, closed event/run/checkpoint contracts, exclusive content creation and head CAS. Replay derives state from the complete chain; a mutable HEAD remains only a repairable cache. Reuse H03 authority/context verification and an enrolled, scoped external checkpoint issuer for claims of current witnessed history. Host acquisition adapters provide data, never verification decisions.

Fresh runs re-read the complete final workspace and re-prove mechanical equivalence against the original accepted context. Intent and objective spending precede effects; uncertain outcomes require the original target key. Dead-owner recovery needs exact scoped approval and confirmation that the recorded process is dead. Legacy bytes remain lossless and LEGACY_UNVERIFIED; an adopted-v2 marker blocks direct legacy writes.

**Consequences.** H04 exposes negative terminal states and reservations, with no execution permit or PASS certification. Missing witnesses, uncertain targets, torn tails and interrupted recovery ownership stop. The host owns trusted state/adapter custody; same-UID replacement is outside this guarantee. H09 owns marker adoption. Two nonblocking availability findings are tracked explicitly for H05; no generic synchronization service is introduced.

---

## 2026-09-06 — H05: closed local effects and actual postconditions

**Context.** Mechanical eligibility must not authorize arbitrary writes, accept an unreviewed before state or turn generic target feedback into an effect receipt.

**Decision.** Use two built-in operations on the same runtime: canonical record serialization and one canonical-source/registered-digest batch. Require each output in the exact accepted context and adopted scope, validate the complete projected document set, and bind the exact plan to host-pinned source/dependencies/Node, configuration, workspace, run and authority. Opaque permits and fenced leases separate preparation from use; deny paths and frozen manifests constrain every publication.

Durable intent precedes budget reservation and effects. Private local-capability provenance survives reopening; generic reconciliation cannot settle those intents. Only actual complete postconditions produce the effect receipt and journal outcome. Reconciliation never republishes uncertain writes. H06 will connect reusable approved continuation to these existing operations; no new per-plan approval mechanism is introduced as a substitute for that work.

**Consequences.** The supported mode assumes trusted runtime-exclusive cooperating writers. Partial multi-file effects or interrupted ownership remain incomplete; no atomic batch or malicious same-UID containment is claimed. Unavailable subprocess containment blocks before spawn. The two H04 availability defects are corrected. No baseline, owner key or deployment authorization follows from an effect receipt.

---

## 2026-09-06 — H06: reusable continuation without renewed artifact acceptance

**Context.** Previously approved mechanical correction should continue across changed commit/representation bindings without repeated human signatures or reset review budgets.

**Decision.** Extend the same runtime with one closed signed continuation subject: human gate, AC/defect/rule, complete accepted identity/registry invariants, scoped capabilities, actual positive/negative identity regressions and explicit limits. Re-evaluate authority and scope at effect use; derive private per-plan permission while retaining H05 manifests, leases and actual postconditions. Current and recorded approvals share the real Ed25519 verifier; historical event-time verification never becomes current permission.

Three named review/remediation categories and the shared total derive from journal reservations. The first signed configuration fixes objective limits; fresh runs, new grant IDs and unsuccessful effects never refund them. Monotonic revocation denies future permission without rewriting original approvals. Required public observed-defect data is validated before mutation.

**Consequences.** This continuation proves only the supported record/digest identity contracts. Product regression execution and actual independent review require their own supported capabilities and evidence. A grant permits work, not acceptance of new baseline/golden bytes. Existing journals are not silently reinterpreted under the changed wire binding. The original verification receipts and causal Critical-fix evidence remain preserved; no baseline acceptance or deployment follows.

---

## 2026-09-06 — H07: diagnostic review preparation cannot certify execution

**Context.** Reviewer configuration/schema friction should be repairable without silently changing model, authentication or isolation. This environment cannot perform the required authenticated isolated Codex session.

**Decision.** Reuse the existing approval/runtime boundary for signed ordered model/effort policy, frozen artifact/config/schema pins and data-only protocol descriptions. Construct exact shadows with fixed pinned Git object plumbing under clean configuration/environment, verifying raw commit/tree/blob identities and complete primary/shadow manifests. Treat output as untrusted strict JSON/Zod data, including duplicate-key and exact-location checks.

No fixture catalog, raw output, matching or signed raw receipt creates authenticated independent-review evidence. The current build prepares contracts and shadows, and refuses real execution before budget spending. A supported future launch must implement containment, actual authenticated discovery/session supervision, reservation before start, and receipt/counterexample provenance. H08 cannot consume these diagnostic outputs as review approval.

**Consequences.** Portable preparation/refusal is locally verified; the original real-session acceptance criterion remains unachieved. No sandbox service or hypothetical launch backend is added to mask missing capability. Exact causal evidence closes the primary __proto__ manifest defect. Generated dependencies are reconstructed from pinned lockfiles, not vendored in proof snapshots. Baseline/deployment authority remains separate.

---

## 2026-09-06 — H08: release calculation requires real execution provenance

**Context.** Completing a coding slice must not imply release completion or let raw agent summaries satisfy deployment, smoke or observability obligations.

**Decision.** Add one closed evaluator on the existing runtime. It binds objective, repository, integrated commit, artifact, target and environment; checks ordering/freshness and latest outcomes; retains uncertain intent and rollback invalidation. Runtime replay comes from the actual current journal and revalidates authority. Separate exact approvals describe deploy and rollback authority. Explicit simulations remain non-authoritative and cannot produce a production certificate.

**Consequences.** This portable build consumes zero authenticated release receipts and refuses unavailable operations before spending. Positive production scheduling, target/readback, authenticated receipt issuance/import and live rollback remain unimplemented; actual production acceptance is NOT_EXECUTED. H07 diagnostic output supplies no independent-review approval. No additional backend, service or dependency is introduced. Local tests/review validate this bounded contract, not the original real production success criterion.
