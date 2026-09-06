# H08 implementer report — FROZEN

Review base: `c8988acc87a18441e310e8f78e9015b3107d9341`; tree
`d0db2152be4e82526a7e58f5fc9d28f7d9f0c52a`. Worktree-only; no index/commit/ref,
root state/PROGRESS/DECISIONS/ledger, prior evidence or prior tests edited by this
worker. No authentication, network or external operation performed.

## Scope and API

Implemented the smallest local extension: `release.mjs`, `release.schema.mjs`,
runtime registration, schema/diagnostic exports, 26 new tests, contract and note.
One closed evaluator serves both runtime decisions and explicit simulations;
no service, runner, provider callback, second state store, journal wire change
or new dependency exists. Read AGENTS.md, governed docs, H06/H07 contracts and
runtime-boundary-review.md, especially section 6. Root owns full verification,
independent review, state publication and feature promotion.

- `describeReleaseObjective(input,context)` computes a closed objective bound to
  current repository/authority/accepted baseline/objective/journal/commit.
- `bindReleaseObjective({objective,approval},context)` verifies the exact existing
  bounded-grant signature and returns a private objective handle. It does not
  accept the artifact or authorize deployment.
- `replayRelease(handle)` obtains actual journal state internally; `nextObligation`
  and `certifyRelease` require its private handle and recheck current authority,
  final workspace binding, run and head. Raw/serialized/foreign objects fail.
- `prepareDeployment(handle,approval)` verifies separate artifact/commit/target/
  action-scoped deployment authorization, then refuses unavailable execution.
- `prepareRollback(handle,request,approval)` similarly checks exact distinct
  current/previous deployment IDs and rollback authorization before refusal.
- `reconcileDeployment(handle,key)` retains existing pending keys without target
  calls, settlement, repeated effects, spending or erased history.
- `simulateRelease(objective,{provenance:'SIMULATION',now,events})` exercises the
  same evaluator on closed nonauthoritative evidence. Its terminal calculated
  `complete` obligation still has `productionPass:false`,
  `certification:NOT_EXECUTED` and `execution:NOT_EXECUTED`.

Exact wire/API is in `contracts-release-v1.md`. Evidence binds complete objective,
repository/objective, integrated commit, artifact, target/environment, operation,
approval, deployment and observation execution identities. Latest failed results,
expiry and changed ordering invalidate prior success. Functional smoke and
observability remain separate. Pending intent takes precedence and uses its
original key. Rollback simulation preserves history and requires remediation.
Required external gates and artifact acceptance remain separate from permission.
Release Please remains only a version manager.

## Verification (actual commands/results)

All commands ran from repository root; evidence prefix is
`docs/implementation/2026-09-05-harness-hardening/h08/`.

| Evidence | Exact command | Result |
| --- | --- | --- |
| Static | `bash docs/implementation/2026-09-05-harness-hardening/h08/verify-static.sh` | exit 0; five syntax checks, tracked diff whitespace |
| Focused runtime | `node --test packs/autonomy/repo-template/scripts/quality-orchestrator/tests/release.test.mjs` | exit 0; 26 pass, 0 fail |
| Local e2e | `node --test --test-name-pattern=^e2e packs/autonomy/repo-template/scripts/quality-orchestrator/tests/release.test.mjs` | exit 0; 2 pass, 0 fail |
| Controlled falsification | `node --test docs/implementation/2026-09-05-harness-hardening/h08/mutation-source/tests/release.test.mjs` | exit 1; 19 pass, 7 binding assertion failures |

Static completed before final runtime, and runtime passed before local e2e.
Local e2e crosses real signature/context/journal/continuation/budget boundaries,
including reopen and preservation of already reserved units. It does not execute
production, reviewer, smoke or observability operations. Full/startup suites were
not rerun by this worker as instructed.

**RED distinction:** the oracle was written before code. Initial feature RED
was absent runtime APIs, not a discovered security defect. The one isolated
**MUTATION_EXPERIMENT** deliberately removes the binding comparison *after initial
implementation* and demonstrates seven actual assertion failures on exact final
tests. Shipping code was never mutated. It is controlled falsification, not
causal RED-before-fix or a discovered prior High/Critical vulnerability. No such
production defect is claimed. `AC-H08.yaml` and `mutation-receipt.json` explicitly
record this distinction. Root review may assess the sufficiency of this evidence.

The first mutation setup used an external dependency symlink and failed the
existing bundle guard before running assertions; its separate logs are retained
and prove no H08 criterion. The valid subsequent run used temporary copied
dependencies, now removed. Only one compact source snapshot and pinned lockfile
are retained; no generated node_modules is in the evidence tree. Earlier feature
and initial-run logs are labeled development diagnostics, not final-byte proof.

## Current source hashes

`source-manifest.json` binds all changed source/contracts/oracle/note/static
script plus unchanged package/lockfile. `evidence-manifest.json` binds logs,
exit records, source manifest and controlled-falsification receipt. The receipt
also enumerates every exact preserved snapshot file and current test hash.

| File | SHA-256 |
| --- | --- |
| `release.mjs` | `70825c5ee7f951a0ab7f111255bf0f11680b402e4496fcdc3e08ffb05359c7e3` |
| `release.schema.mjs` | `c6d15eca811695e31ac537cfb1bbe349bfd7e8878164a251330ad9f3234201af` |
| `classify.mjs` | `86e64dde393314232c5bac0304fd88003ba652d474d20b26f125938f896d18a8` |
| `index.mjs` | `69f5c687ca4cef260d360f9c12356af62360c99f9921ffc20248c82afd392d5a` |
| `tests/release.test.mjs` | `a5bd6cc0b4a1c6987398365b9c95dd4fa58d9a4af6ab1b7b16c5ed942b29152a` |
| `contracts-release-v1.md` | `187f8aa8bc5cc050bb27f77a120cf93cae0882fede9d8a57aa030f8ce4a04941` |

## Limits and remaining work

Implemented: closed portable obligation/provenance calculation, strict schema
validation, exact current authorization checks, opaque replay/objective binding,
budget/grant preservation and truthful unavailable/refusal paths.

**Unimplemented:** positive production scheduler/execution, approved fixed real
target adapter/readback, authenticated release receipt issuance/import, actual
integration/product verification, real smoke/observability, deploy/rollback
reconciliation and production rollback invalidation. H07's actual authenticated
review/containment backend also remains unimplemented. This build can consume
**zero** H07 diagnostic outputs as authenticated review evidence. Simulations and
signatures over raw model JSON cannot satisfy that obligation.

**NOT_EXECUTED:** real production release acceptance and actual deployment,
smoke, observability, rollback or authenticated review. No real production target
or deployment permission was configured. These live acceptance limitations are
in addition to, and must not obscure, the unimplemented positive backend work.

Runtime certification always blocks; all required release obligations remain
unsatisfied here. Known missing capability stops before a budget reservation or
intent. Existing H06 category/total units are preserved across retries/reopen;
a grant is permission for its exact closed work, never artifact acceptance or
deploy authority. Runtime integrity and trusted local journal custody remain
assumptions; local hashes do not establish external authentication.

Status: **FROZEN** pending root review. Stop edits until explicit fix dispatch.
