# P0-PRODUCT-LOOP — independent increment

Owner request: a previously authorized functional objective advances through
OBJECTIVE_READY, AUTHORITY_BOUND, SCOPED, RED, IMPLEMENT, VERIFY,
INDEPENDENT_REVIEW, BOUNDED_REMEDIATION, PASS and HUMAN_MERGE without human
copy/paste between steps. Preserve fail-closed and the existing harness.

Base: local PR33 continuation a798c88ad625be2478d24df52c0dc45c51e2d4e4.
This branch is independent of PR33 and consumer distribution. Casabat supplies
lessons only: no access, changes, copied business rules or dependency on it.
PR33 code is frozen; its remote publication is blocked by automatic approval
review. No alternate publication route is authorized by this plan.

## Coverage before implementation

The same matrix was delivered to the owner before implementation. Covered means
tested current mechanism, not acceptance of the real product loop.

| REQUIREMENT | COVERED | PARTIAL | MISSING | CURRENT_EVIDENCE | NEXT_CHANGE |
|---|:---:|:---:|:---:|---|---|
| Authority and baseline | yes | — | — | H03 signatures and contexts | Bounded product objective; reuse authority |
| Journal/replay/budgets | yes | — | — | H04–H06 concurrency and persistence | Reuse without rewriting history |
| Positive execution backend | — | yes | — | F24 transport/worker and28 tests | Closed product operations and real host |
| Isolated authoring worktree | — | yes | — | H07 review shadows | Bounded authoring workspace |
| Visible outcome and functional ACs | — | — | yes | No P0 contract | Strict objective contract |
| Complete loop without copy/paste | — | — | yes | Exact authorization per execution | Bounded grant and controller |
| Product RED and functional change | — | — | yes | Harness RED only | Small real CLI objective |
| CONTROL/DELIVERY and cycle limit2 | — | — | yes | No value counter | Durable VALUE_PROGRESS_BLOCKED |
| desired/observed/verified/reported | — | yes | — | Typed receipts, no product projection | Canonical four-part state |
| Known difference blocks four advances | — | — | yes | No shared product condition | Block approval/PASS/next/baseline |
| Invariant×surface×principal | — | yes | — | Local guards and negative tests | Pilot matrix and justified N/A |
| Independent real review | — | yes | — | H07/F24; real sessions not accepted | One FULL, focal re-review |
| Max2 fixes; Medium/Low backlog | — | yes | — | Existing budgets | Product policy and AC blockers |
| Finding→counterexample→RED/GREEN→regression | — | yes | — | Causal fixes during development | Automated durable links |
| Exact gate reuse | — | yes | — | Bound observations/reconciliation | Complete evidence key and resume |
| argv/environment/containment/nonce | — | yes | — | Guards/locks, host containment absent | Reuse and test new effects |
| Eight Casabat-derived replays | — | yes | — | Underlying mechanisms separately tested | Small lifecycle fixtures |
| PR receipt, human merge | — | yes | — | Manual connector delivery | Bounded PR preparation/effect |
| Minimal evidence and metrics | — | yes | — | Hashes and compact receipts | Per-objective metrics |
| Real pilot and P0_PRODUCT_LOOP_READY | — | — | yes | Host/auth/authority outstanding | Actual permitted-host execution |

## Single implementation task

Extend the existing runtime with a strict product contract and reducer. Reuse
Ed25519 verification, private handles, persistent objects, journal lock/replay,
Actions transport and independent review. Add only the closed operations needed
for RED, patch proposal/application, verification and review handoff. No service,
scheduler, provider framework, generic shell runner or production operations.
Keep old schemas/receipts/tests and their historical meaning intact. If a new
journal contract is necessary, make it explicit for new P0 journals, preserving
the old decoder/bindings. Never relabel a product change as H06 equivalence.

Bind the initial bounded product grant to accepted normative authority and
baseline, outcome/ACs, exact repository/base SHA, scope/frozen paths, threat
model, commands, toolchain/lock/config/verifier capability, expiry and budgets.
Derived child operations may not broaden it. No signing key, owner acceptance
or real baseline is manufactured by the controller. Code files have a separate
product manifest; the accepted normative documents stay protected.

Persist desired_state, observed_state, verified_state and reported_state
separately. Claims are OBSERVED, VERIFIED, INFERRED, REPORTED or UNKNOWN. Agent
prose and Markdown cannot promote lifecycle. Text checks do not certify runtime,
semantic consistency or production. A known unresolved difference blocks slice
approval, PASS, next slice and baseline promotion simultaneously.

Count CONTROL_PROGRESS and DELIVERY_PROGRESS. After two control/documentation
cycles without product RED or functional change, block VALUE_PROGRESS_BLOCKED.
Run one independent full review, at most two remediation rounds and focal
re-reviews of changed findings. Critical/High block; Medium/Low go to backlog
unless cumulatively invalidating an AC. Expected RED, local errors, bounded fixes
and necessary retests do not trigger human approval. Human decisions are limited
to new norms/authority/domain/architecture, scope/security expansion, unresolved
C/H outside the AC, budget exhaustion, baseline acceptance, final merge/release
and external or production-only evidence.

Every reproducible C/H needs a counterexample, observed RED on defective bytes,
GREEN on the correction, durable regression and original finding link. Reuse
evidence only with identical source SHA, authority, scope, toolchain/lock,
configuration, argv and real verifier capability. Run affected tests first and
then the required final gate; resume must not repeat still-valid gates.

Each invariant maps mutation path, principal, negative test and observed result.
Inventory UI, API/server action, RPC, direct DML/PostgREST, batch/sync, Storage,
triggers, migrations and privileged clients; unsupported pilot surfaces need
an explicit justified N/A, never an invented semantic proof.

Effects use argv without shell, allowlisted environment, independent sessions,
realpath containment, no symlinks/traversal, append-only journal with lock,
atomic nonce consumption and live SHA revalidation immediately before effects.
Reject force/mirror/+ref and equivalent forms; never git add dot/all. A host
without real containment remains blocked, not downgraded to an unsafe fallback.

Prepare a PR and compact evidence receipt, stop before merge/deploy/production.
The chosen real product pilot is a bounded `harness-status --autonomy --json`
diagnostic: parseable JSON, truthful loaded/unavailable states, missing dependency
nonzero, no false READY, no upstream/network requirement. The fixture loop must
exercise actual processes, RED/product bytes/GREEN, separate review session
identity, remediation and interrupted resume. Fixtures are not real model proof.

## Required causal replays

1. Text checker green with semantic HIGH.
2. Known difference attempts next slice and the other three promotions.
3. Direct mutation path bypasses the happy-path wrapper.
4. SHA change invalidates review and authorization before effect.
5. Two actual processes compete for one nonce.
6. Interruption/resume avoids a still-valid gate.
7. Green required checks with open Critical/High.
8. Health200 without version/migration identity evidence.

Write tests and a critical oracle first. Preserve only exact test/source hashes,
minimal causal patch or source, argv, exit, structured result, short error excerpt
and reproduction instructions. No new repository snapshots, verbose stdout,
duplicated reports or generated dependencies in Git. Full raw streams stay in
scratch. Existing historical evidence is not rewritten to fit new code.

## Review, verification and real limits

Use one independent scoped review of this increment and at most two fix/re-review
rounds. The previous automatically interrupted whole-branch review is not rerun
or replaced. Run the existing required final gate once after affected layers.
Record interventions/objective, time to first functional RED, time to PR-ready,
duplicate gate minutes avoided, findings after false-ready, C/H regression rate
and completed autonomous objectives. Unmeasured metrics remain UNKNOWN.

No P0_PRODUCT_LOOP_READY without an actual real implementer, independent real
review, product RED/change, green gates, zero C/H, causal regressions, proven
resume, zero known differences and an actual prepared PR. Earlier authenticated
Codex preflight was cancelled; OS containment is unavailable on this host and
real P0 authority is not enrolled. Do not retry those blocked capabilities by
another route. Finish useful implementation/fixtures and clearly report the real
pilot as blocked until those prerequisites are provided in an authorized host.
