# Minimal product publication design

Design assistance only. Source inspected with `git show dfd717b9:<path>` in `/workspace/scratch/adce1c53b293/harness-human-interruption`; no source edits, candidate execution, network, credentials, or tests were performed. All module paths below are relative to `packs/autonomy/repo-template/scripts/quality-orchestrator/`. This note does not approve a deployment or certify real authentication/isolation.

## Recommendation

Add one closed GitHub publication boundary, callable only through the private product controller after `HANDOFF_PREPARED`. Use a new opt-in journal contract and a separately signed exact publication budget. Retain the current product v1/v2 objectives, payload schemas, journal bindings, and local handoff behavior unchanged. Publish Git objects through fixed GitHub Git Database routes, then create one new ref and one PR. Do not add generic HTTP, shell, push, merge, deployment, or callback execution.

Every mutating HTTP request has its own durable intent before its sole POST attempt. Resume is GET-only for a request that already has an intent but no result. A later, previously unattempted request may proceed after positive reconciliation and renewed freshness checks. Zero matches never justify another POST for the uncertain request.

## Existing API facts that constrain the change

- `classify.mjs:openRuntime(host)` constructs private `journalInternal`, optional `executionBoundary(host.actions,auth,journalInternal)`, then `productBoundary(host.product,runtime,auth,journalInternal)`. The Actions execution object is not itself added to the public runtime. Follow this pattern.
- `product.mjs:productBoundary` owns a `WeakMap` of objective handles. Its `loaded`, `fresh`, `read`, `coverage`, `openFindings`, and `persist` functions are private. Do not accept a projected handoff as authority or introduce a second public product-handle registry.
- `preparePR` creates a private bare repository under `config.sessions`, builds a complete tree from `manifest().files`, and creates a commit whose single parent is the objective base. Its handoff contains `repository`, `baseCommit`, `headCommit`, `treeDigest`, `productManifestDigest`, `title`, and `body`. Its repository uses an alternate for source base objects. It currently has `prCreated:false` and `publication:'NOT_EXECUTED'`.
- The product `OBSERVATION` reducer sets `HANDOFF_PREPARED`; `runProduct` stops there. The projected handoff says there is no actual PR and retains `NOT_P0_READY`. Do not change those historical assertions merely because a new backend exists.
- `journal.mjs` has separate event versions 1, 2, and 3, with `product.v1`/`product.v2` using versions 2/3. `productCustody(fn)` is synchronous: it releases its filesystem lock as soon as `fn` returns. Passing an async function does not protect an awaited operation.
- `putObject`/`getObject`, `retainAcknowledgement`/`readAcknowledgement`, and `append` already provide content-addressed, fsynced retention and CAS event append. Acknowledgements are keyed by a supplied digest and are immutable. `append` can return a prior idempotent receipt: receiving an append receipt alone does not prove this caller owns a new effect.
- Generic `journal.reconcile` accepts only the old reservation model and rejects Actions-owned descriptors via `backendOwned`. A publication must never be cleared through `host.journal.reconcileOperation`.
- `executionBudgetSchema`, `descriptorSchema`, and the Actions profile are closed existing schemas. The only old budget categories are product semantic review, harness implementation review, and mechanical remediation verification. Publication is none of these. Do not add `publish` to the old Actions operation enum or relabel it a review to reuse an existing signature.
- `authorityBoundary` already verifies `execution-budget` and `execution-observation` envelopes, including domain, subject/scope digests, issuer kinds, revocation checkpoint, and freshness. New signed subject domains can use these existing envelope kinds without changing the old authority schema or `RUNTIME_BINDING`.
- `github-actions.mjs` provides a useful transport pattern: fixed `api.github.com` URLs, direct `node:https`, deadlines, bounded responses, and no POST retry. Its helper is private and expects Actions-specific response statuses; copying a small closed request helper into a new module is safer than broadening it into a general adapter.

## Exact minimal interface and integration

New host field `host.productPublication`, separate from `host.product` and `host.actions`:

```js
{
  owner, repository, repositoryId, // strict GitHub segments and positive numeric ID
  baseBranch, branchPrefix,       // validated ref names; no arbitrary route fragments
  actorId,                       // pinned positive numeric GitHub user ID
  token,                         // operator supplied, never in the profile digest
  containment: {
    status: 'OPERATOR_ATTESTED',
    digest,
    approval                     // execution-supervisor observation envelope
  }
}
```

The first version supports a user token that can be checked against `GET https://api.github.com/user`; do not claim generic GitHub App token compatibility. The credential needs Git object/ref and PR creation rights only. A configured identity is not proof of credential isolation.

Add `product-publication.schema.mjs`, `product-publication.mjs`, and `github-product.mjs`:

```js
// Private constructor; not exported from index.mjs.
productPublicationBoundary(host, runtime, auth, journal)
// Returns private describe(binding, options, ctx), publish(wire, binding, ctx),
// resume(publicationKey, binding, ctx), records(ctx).

// Public methods returned by productBoundary; all start by resolving its WeakMap.
runtime.describeProductPublication(productHandle, { operationKey, limits })
runtime.publishProduct(productHandle, { descriptor, budget, approval })
runtime.resumeProductPublication(productHandle, operationKey)
```

`classify.mjs` privately constructs this boundary only when `host.productPublication` and the new journal contract are present, then passes it as a fifth argument to `productBoundary`. `productBoundary` supplies an internal binding made from its verified objective and current state. The backend does not accept a caller-selected root, raw source, handoff path, repository, title/body override, URL, token, script, or transport function.

`describeProductPublication` is local-only and prepares the exact signable descriptor from the controller's handoff. It returns data, not a capability. Calling `publishProduct` recomputes/checks every binding and verifies the separate signature; edited descriptions fail. The private boundary may expose a narrow internal synchronous guard callback supplied by `productBoundary` to re-read/validate the same private handle immediately before reservations and after awaits. That callback is repository implementation, never a host/candidate importer.

Keep `runProduct` unchanged initially: the explicit authorized `publishProduct` call follows its local handoff. This completes actual remote publication without changing the meaning of historical objectives or inserting authority acquisition into the product loop. A caller can run local work, obtain/sign the concrete publication descriptor using the existing enrolled authority, then call publication.

## Descriptor, authority, and bounded resources

Use new strict schemas with explicit domains:

- `productPublicationDescriptorSchema`: `version:1`, `domain:'harness.product-publication.v1'`, operation key, a persisted random 256-bit nonce, profile excluding token/approval, repository logical ID and numeric GitHub ID, authority/baseline/journal/objective/run IDs, objective digest, **prepared product state digest**, product config and installed-bundle digests, source manifest digest, exact file inventory, base commit, prepared head commit, tree SHA, canonical commit metadata, title/body, review/full-review/coverage/current-green-evidence digests, and exact ref/PR request fields. Include a content-addressed immutable object-upload plan, with byte digests and totals. Bound all strings, files, arrays, and bytes.
- `productPublicationBudgetSchema`: `version:1`, `domain:'harness.product-publication-budget.v1'`, repository/authority/baseline IDs, `scope:{objectiveId,journalId,runId,operationKey,objectiveDigest,descriptorDigest}`, `profileDigest`, `expiresAt`, and `limits:{objectiveTotal,publicationStarts:1,mutationRequests,readRequests,requestBytes,responseBytes,elapsedMs}`. Resource values are positive safe integers with implementation maximums; zero can be allowed for exhausted remaining resources, never treated as unlimited.
- Approval expectation: `{kind:'execution-budget',subjectDigest:digestData(budget),scopeDigest:digestData(budget.scope),authorityDigest:auth.authorityDigest}`. Reuse `auth.verifyApproval`/`inspectApproval` before effects and `auth.verifyRecordedApproval` at each intent's recorded timestamp during replay. The original bounded product grant remains required as well. An old local product grant alone cannot authorize publication.
- Signed containment observation: bind publication profile digest, product `configDigest`, worker/verifier pins, containment digest, installed bundle digest, and the statement that worker/candidate processes cannot access the publication credential, journal, or uploader memory. Require the enrolled `execution-supervisor` role and a current `execution-observation` envelope. No receipt must contain the token or its value-derived hash. Existing product-only containment approval does not establish this new isolation claim.

The signed publication start consumes **one** remaining original product `maxSteps` start and **one** `state.budget.spent` unit. `limits.objectiveTotal` must equal the existing immutable journal total, including any installed signed total. Subrequests consume the new publication request/byte/time counters; they do not masquerade as old review-category expenditure. This explicit new domain is necessary because 200 blob uploads cannot reasonably fit the old 30 product-step ceiling. Total product expenditure remains capped, and the separately signed publication resource envelope explicitly authorizes the compound operation. Never reset these counters on resume or a new process.

The plan's maximum POST count is known: one per distinct missing blob, one tree, one commit, one ref, one PR. Either choose the complete conservative plan before signing or sign its upper bound; read-only existence checks may save uploads but cannot increase the signed bound. Bound GET retries, pagination, aggregate bytes, each request deadline, and the publication expiration. Charge a request's maximum permitted response bytes before dispatch and reconcile actual usage without refunding the attempted request count. No unbounded automatic polling.

Freshness checks must require: current verified context and approval handles; installed bundle unchanged; original source HEAD/base and manifest unchanged; exact prepared commit/tree/files unchanged; current OPEN run with accepted normative binding; no local product pending/remediation intent; no known difference; no open blocking finding; applicable coverage observed; current exact-source gate and review evidence. A terminal run, stale run, source edit, changed profile, revoked receipt, exhausted budget, or a new difference stops new mutations. API success may still be retained as an observation after such a race; it does not restore readiness or authorize a next request.

## Journal contract and concurrency

Add `contract:'product.v2.publication.v1'` using a new event version 4 and `PRODUCT_PUBLICATION_JOURNAL_RUNTIME_BINDING`, derived from the prior product-v2 binding plus the new closed publication event schema. `productVersion` remains 2 for the existing reducer. New `publicationContract:true` and `publicationTransition` internals are separate from `productTransition`; old product schemas and digests remain byte-for-byte unchanged. No in-place conversion/relabeling of an existing v1/v2 journal.

New operation `kind:'product-publication-step'`, with operation key, previous publication digest, and payload digest. New payloads are a small closed union:

1. `BOUND`: descriptor, budget, approval. No network yet.
2. `START`: consumes the one product/journal start and initializes publication counters and stage.
3. `REQUEST_INTENT`: request ID, exact method/closed route kind, canonical body digest, expected response identity, reserved bounds, predecessor result digest. Replay independently verifies sequence, budget, and recorded authority.
4. `REQUEST_OBSERVATION`: request ID, sanitized typed response/result digest, status and remote identity; must bind the matching intent and retained acknowledgement.
5. `COMPLETE`: final verified repository/ref/commit/PR readback digests.

State lives in `state.productPublication`, leaving `state.product.stage==='HANDOFF_PREPARED'` intact. Publication state includes descriptor/budget/approval digests, one active publication per product, counters, all request intents/results, and stages `BOUND`, `UPLOADING`, `REF_OBSERVED`, `PR_OBSERVED`, `COMPLETE`, `INCOMPLETE`, `CONFLICT`. Stage names do not substitute for checks. A projected `remotePublication` supplements the local handoff and never overwrites its historical preparation observation.

For each new request, use synchronous `journal.productCustody(appendOwned => ...)`: re-read state, run the private product guard, validate authority/bounds, append intent, and return a private newly-created ownership flag. Dispatch only if that flag says this caller created the intent. An already-existing intent leads to reconciliation, never dispatch. Do not derive ownership from an idempotent append receipt.

Use a boundary-private `Map<descriptorDigest,Promise>` to coalesce concurrent `publish`/`resume` calls in one runtime; clear it in `finally`. The durable intent and the filesystem lock provide the cross-runtime exclusion, including when two runtimes in one process have different maps. Never hold `productCustody` across an await. New product mutation/remediation/run-rebinding entrypoints must reject an active publication, and publication must reject ordinary journal pending work; conversely new ordinary capability reservations and run replacement/closure must respect active publication custody. `reportProductDifference` may record a difference while publication is in flight: retain the response and block the next effect/completion claim.

Acknowledgement key example: `digestData({domain:'harness.product-publication-request.v1',descriptorDigest,requestId})`. Retain a validated, bounded result before appending its observation. Once an intent is durable, a crash before the actual socket write is still uncertain. Losing the local journal cannot be remedied by making a new branch/PR under the same objective; require recovery of the authoritative retained journal. Preserve `LOCAL_UNWITNESSED`; these files do not provide anti-rollback protection against a privileged host restoring an older filesystem snapshot.

Because publication uses its own operation kind, public `appendEvent` and generic `reconcileOperation` have no authority to append, settle, or invent its result. Add reducer checks to prevent any generic recovery/outcome mechanism from clearing its custody indirectly. The signed `recoverLock` path remains applicable to a dead local lock; it does not reset a request attempt or authorize a duplicate POST.

## Exact remote protocol

`github-product.mjs:githubProduct(profile,token)` returns only named closed operations. It uses `node:https` directly, fixed origin `https://api.github.com`, strict route construction/encoding, explicit expected statuses (GET 200, creates 201), UTF-8/JSON checks, request/response bounds, deadlines, and **no redirects or automatic retries**. Never follow response URLs or `Link` targets blindly. No external dependency is needed.

1. Preflight: GET repository, authenticated user, base ref, base commit. Verify exact numeric repository ID and full name, actor ID, base branch SHA equal to the signed base commit, and commit identity. GET the proposed head ref and require absent before its first creation. Check that no prior PR matches that head before the first PR POST. All these observations are bounded and retained.
2. Read the prepared private repository using pinned Git with a minimal environment and no credential. Re-read raw commit and complete tree and every blob. Verify single parent equals base, tree SHA equals handoff, exact path/mode set and SHA-256 file bytes equal the reviewed manifest, and frozen paths preserved. Reading from a caller-supplied handoff path is forbidden. Do not upload mutable worktree contents after a preflight check; upload the immutable, digest-checked planned blobs.
3. POST missing blobs at `/repos/{owner}/{repo}/git/blobs` with base64 bytes. Verify each returned Git SHA against the locally computed blob SHA. POST a complete tree at `/git/trees` (no `base_tree`; all exact paths/modes/blob SHAs), then require returned tree SHA equals the prepared tree. Full-tree construction must correctly handle literal file names and avoid prototype-key dictionaries; reject unrepresentable names before any POST.
4. POST `/git/commits` with the exact tree, single base parent, message, author, and committer. Require returned SHA equals prepared `headCommit`, then GET and verify tree/parent/message identities. Export raw prepared commit metadata and verify it can be represented by this API before spending. Reject unrepresentable extra headers/signatures/timezone/encoding instead of silently creating a different commit. If needed, pin UTC author/committer timestamp formatting only for preparation in the new opt-in contract; historical preparation stays unchanged. The exact serialization/API equivalence requires a real integration check before claiming production compatibility.
5. Compute an unguessable controller branch under the signed prefix, for example `harness/product/<publication-nonce>`; sign that exact ref. POST `/git/refs` with that ref and expected head SHA. Never PATCH, force-update, adopt a pre-existing ref at first publication, or DELETE. A 422 collision is not success. GET the exact ref and verify it points to the expected commit.
6. Immediately recheck repository/base/ref identity and all local freshness. POST `/pulls` with exact base, head, title, body, `draft:true`, and `maintainer_can_modify:false`. Body appends an exact publication marker bound to the descriptor/nonce; include its final bytes in the signed descriptor. The marker should reference a pre-marker binding digest to avoid a self-referential descriptor hash. Do not send reviewers, notifications outside normal PR creation, labels, or other side effects.
7. GET the returned PR and verify numeric ID/number, expected fixed URL structure, creator actor ID, same repository IDs on head/base, exact refs/head SHA/base SHA/title/body/marker, open state, draft status, and not merged. Re-read ref, commit tree/parent, and base after the PR GET before `COMPLETE`. A changed base/head produces a retained created-PR observation and a conflict/incomplete result; never automatically update, close, delete, or recreate it.

GitHub PR creation has no compare-and-swap parameter for the base/head commits in this design. Pre/post checks can prove what was observed, not prevent an unrelated actor moving a ref between them or afterwards. Report `observedAt` and the observed IDs/SHAs, not a permanent invariant. Branch prefix ownership must be operator-controlled; a high-entropy nonce plus absent-before/create-only/exact-after checks avoids accidental collision but is not cryptographic evidence of who created a ref. For a resumed uncertain ref, an exact matching nonce ref is sufficient to observe the authorized resource, without claiming an authenticated creator of that ref. PR actor identity is separately checked.

## Crash and uncertainty behavior

| Durable point / observation | Allowed recovery |
|---|---|
| Descriptor exists, no START/request intent | Revalidate; spend/start normally. |
| GET intent with lost result | Another bounded, separately charged GET; never infer absence from transport failure. |
| Blob/tree/commit POST intent, no result | GET expected content-addressed object and compare exact identity/content. If absent or ambiguous, `INCOMPLETE`; never repost that object request. |
| Ref POST intent, no result | GET exact ref. Exact expected head permits recording observed resource; absent, different, ambiguous, or unreachable stops. |
| PR POST intent, no result | Bounded complete GET search with `state=all`, exact owner/head/base; then GET candidates and compare marker, actor, repository, and all signed identities. Exactly one exact open draft match can settle; zero, multiple, truncated, modified, closed, or merged matches stop. Never POST a second PR. |
| Response retained, event append lost | Validate ack against original intent and append its observation idempotently; no repeat POST. |
| Observation committed, process dies before next request | Replay; revalidate and reserve the next previously unattempted request. |
| Local source/authority changes while request is in flight | Retain what the API returned; block further effects and readiness. Never pretend the side effect did not happen. |
| COMPLETE exists | Replay the historical observation without new effects; a new live verification uses bounded GET resources if still authorized. |

Search must account for pagination explicitly. Construct bounded page queries internally; never treat a full first page as exhaustive. Reconciliation read budgets survive restarts. Expired/removed authority cannot authorize fresh authenticated requests: replay retained observations locally, and obtain an exact read-only recovery authority if further remote discovery is needed. Do not reset the original mutation nonce or budget to make recovery possible.

## Result meaning and files to change

Return a typed `PRODUCT_PR_OBSERVED`/`PRODUCT_PUBLICATION_INCOMPLETE` projection with descriptor/evidence digests, repository/ref/head/tree/base IDs, PR ID/number/URL, observed timestamp, draft status, and the precise assurance. A successful HTTP response alone is insufficient. Keep production, merge, external authority acceptance, P0 readiness, and real model execution claims separate. `FIXTURE` product evidence never becomes real product readiness because its publication path was exercised with a fake HTTPS fixture. Operator-attested isolation remains operator-attested, not tested OS isolation. Local journal replay is not independent signed GitHub evidence.

Change/add only:

- `product-publication.schema.mjs`: closed profile/descriptor/budget/operation/payload/result schemas and domain constants.
- `product-publication.mjs`: private plan, signature checks, lifecycle, counters, custody, reconciliation, projections.
- `github-product.mjs`: fixed HTTPS named operations and response identity validation.
- `classify.mjs`: private constructor wiring and optional fifth product boundary argument.
- `product.mjs`: private binding/guard/export helper, three public handle-based methods, publication projection, mutual-exclusion guards; optional exact commit-serialization pin for the new contract only.
- `journal.mjs`: new explicit contract/event binding/reducer hook and custody guards; preserve prior contract schema/binding constants.
- `index.mjs`: optionally export the new schema/runtime-binding constants for signing, never transport/constructor capability.
- New publication tests; contract documentation and installation/pack inventory only if explicit inventories require new files. `installedBundleDigest()` discovers runtime `.mjs` files, so new modules become part of the bound installed runtime automatically.

No initial changes are needed to `authority.mjs`, `budget.mjs`, `execution.schema.mjs`, `execution.mjs`, or `github-actions.mjs`; their existing schemas and historical receipts should remain intact.

## Essential behavioral tests

Use the existing `node:test` pattern in `tests/execution-backend.test.mjs`, which mocks `https.request`; never add a production-configurable test transport. No real token/network is needed for these tests. Fixture reports must explicitly say they do not establish real GitHub authentication, acceptance, or containment.

1. Historical v1/v2 schema and journal-binding constants stay exact; historical product tests still stop at local handoff. Publication host without the new journal contract fails closed.
2. Public forged/cross-runtime handles, projected handoffs, edited descriptors/budgets, arbitrary URL/root/token/callback fields, unsupported auth/profile, missing signatures, wrong kind/role/scope/repository/run/objective, revoked or expired authority all produce zero POSTs.
3. Descriptor binds every source byte/path/mode, prepared head/tree/base, review and gate result, product state, config, and runtime. Mutation of any binding before publish or after an awaited preflight blocks before the next effect. Frozen/literal `__proto__` filenames and non-ASCII/binary blob bytes remain exact or are explicitly rejected before effects.
4. Wrong remote repository numeric ID/full name, authenticated actor, base ref, returned blob/tree/commit SHA, commit parent, existing branch, PR head/base repository/ref/SHA, marker, actor, state, or title/body prevents completion. No branch ref POST occurs after a commit mismatch.
5. Competing same-runtime calls, two runtimes, and two processes reserve exactly one publication start and one intent per mutation; only the creator of the new intent dispatches. Use a controlled held response to expose races between request intent, response, ack, and observation. Test resume called while the original POST remains pending.
6. Crash matrix above at every boundary for each mutation family. Count POSTs across reopening the same journal. Lost acknowledgement plus zero search matches stays uncertain forever within that authority; it must not retry. Positive reconciliation resumes only new subsequent requests.
7. Journal ack tampering, altered payload, duplicate operation key with different request, mismatched predecessor, forged COMPLETE, generic append/reconcile bypass, terminal-run replacement, and resource counter rollback fail. Recovery of a dead lock does not grant permission to redispatch.
8. Original product start/total exhaustion; immutable signed total mismatch; mutation/read request cap; response/request bytes; pagination cap; request deadline; expiration after preflight and before the next POST. Failed/uncertain attempts remain charged. Blob upload count is bounded by the signed plan.
9. Known product difference recorded while POST is in flight retains the side effect but blocks subsequent mutations/completion. Remote head/base drift similarly retains PR identity without claiming exact ready state. No PATCH/DELETE/merge or second PR is ever emitted.
10. Token only appears in the expected fixed-origin Authorization header. It is absent from descriptors, journal objects, public projections, errors, prompts, worker/verifier stdin/env, and Git argv/env. Redirects, path injection, oversized/malformed JSON, timeouts, and response URLs pointing elsewhere fail closed. This test demonstrates routing/non-disclosure behavior, not OS isolation.
11. Closed-state/merged PRs, matching marker under wrong actor, multiple matches, page truncation, lost Git ref, and moved prepared ref never trigger automatic recreation. A completed replay causes zero new POSTs.
12. Positive fixture: full local product flow -> separately signed publication -> exact blobs/tree/commit/ref/PR -> readback -> durable complete projection -> process restart replay, with explicit fixture provenance and unchanged production/merge/readiness claims.

After implementation, a separately authorized real GitHub canary is needed to establish raw commit API serialization, token identity/permissions, actual branch/PR creation, and actual credential separation. Offline fixtures cannot certify those facts.

## Material decisions and limits

- The mandate covers branch/PR creation. Draft PRs, a reserved nonce branch, no merge/deploy, no automatic update/delete, and fail-closed uncertain requests are conservative implementation choices within that mandate.
- The new signed compound-publication resource domain is an explicit policy contract, not permission to exceed any old total. If the accepted budget policy requires every resource category to appear in the old category schema, adopt a new full budget schema in the new journal contract instead; do not silently reclassify publication into mechanical/review spending.
- A previously prepared v1/v2 journal cannot simply be upgraded under its old signatures. Reusing that exact already-prepared objective requires an explicitly designed/signed migration or a publication sidecar authority anchored to its immutable old journal head. The minimal initial implementation instead requires the new opt-in contract from objective creation. This is a compatibility boundary, not an excuse to manufacture new authorization.
- No remote exactly-once guarantee exists when the durable local custody record can be lost/rolled back, when a different host publishes the same objective with a new journal, or when another writer can mutate the reserved branch. Preventing those cases requires an external durable coordinator/witness or stronger operator custody, beyond this minimal implementation. The proposed guarantee is at-most-one POST per recorded mutation intent with conservative GET reconciliation.
- Real credential isolation remains unavailable until the operator's attestation is backed by actual evidence. The code may report the attestation and verified remote identity; it must not promote that into tested containment or real product acceptance.
