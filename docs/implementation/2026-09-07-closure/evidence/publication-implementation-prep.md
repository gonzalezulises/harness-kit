# Product Publication Implementation Preparation

**Goal:** Add an explicitly opted-in, separately authorized GitHub draft-PR publication capability after the existing product-v2 local handoff, without changing historical product/journal/budget meaning.

**Architecture:** A private publication reducer owns an exact immutable upload plan and a compound signed resource envelope. A closed GitHub transport exposes only named repository, Git-object, ref, and pull-request operations. `product.mjs` remains the sole owner of product handles and supplies a fresh private binding/guard to the publication boundary.

**Spec:** `/workspace/scratch/0be017df5260/closure-review/publication-design.md` (`sha256:282a9a52ecaefeb12bcd36296debec926a2917f4f074517647744f42a5329a35`)

## Current-source fit

The design fits the current integrated source and should proceed only after the controller releases the source freeze.

- `journal.mjs` already has the GR01 creator split: private `appendClaimOwned(...)` returns `{created,receipt}`, and `claimExecution(...)` dispatches only when `created` is true. Publication must receive an equally narrow `claimProductPublicationRequest(...)`; ordinary `append`, its idempotent receipt, and `productCustody` do not establish dispatch ownership.
- Event versions 1/2/3 and `JOURNAL_RUNTIME_BINDING`, `PRODUCT_JOURNAL_RUNTIME_BINDING`, and `PRODUCT_V2_JOURNAL_RUNTIME_BINDING` remain parents. `product.v2.publication.v1` adds event version 4 and a new binding whose parent is the exact current product-v2 binding.
- The current F27 schema adds `SETTLED_REVIEW_FAILURE` and `REVIEW_CHECKPOINT_RECOVERY` to `productPayloadV2Schema`. Event v4 must continue to decode the unchanged `productEventOperationSchema`; `productVersion` remains 2, so the current F27 reducer executes byte-for-byte under the new contract.
- `state.product.stage` remains `HANDOFF_PREPARED`, with its existing `prCreated:false`, `publication:'NOT_EXECUTED'`, `NOT_P0_READY`, and fixture limitations. Publication adds `state.productPublication` and a separate `remotePublication` projection.
- Product steps currently charge `state.product.counters.starts` and `state.budget.spent` without relabeling them as an old category. Publication `START` follows that exact total-budget rule once, while all HTTP request/byte/time accounting lives in the independently signed publication budget and publication state.
- `installedBundleDigest()` already includes every runtime `.mjs`; adding the three new modules automatically creates a new installed-bundle binding. Existing objectives cannot be reused after that byte change, which is consistent with the new-journal-only rule.

Current files inspected during the freeze:

| File | SHA-256 |
|---|---|
| `journal.mjs` | `b736a6ae3163c85387cbc7c32648c1e33449218b9d54e8ef8567758d64f4e26a` |
| `classify.mjs` | `497fb60b930dc8a3ac00062d297d865ccbfa6f713f31ed1ad050ff315fe90e49` |
| `product.mjs` | `acc0e4c8402dde24e9c7d88cf168be7744c0b9a4ccc435ef1282bb087ac0b51a` |
| `product.schema.mjs` | `89ae1728629ef5f24a60ff553180d63fdc45a47951aabc9fe5d1d5a8557eebe2` |
| `execution.mjs` | `2c11cde8830a16dfdd056e5c4f755bf9de944f1459e8fc21b7af3bcf03ecefdc` |
| `github-actions.mjs` | `db760d896e42f14e88f06165021c11ac146b3c4ad84fc929a486fc5245003bb1` |
| `authority.mjs` | `c835ae848b7a6ad4dfc024b5eb2495fa6c6dc68f6cafa89dd7c3a0b12f8cfe26` |

## Necessary design refinements

1. **Snapshot planned bytes during description.** `describeProductPublication` must read the private prepared repository once, validate its raw commit/tree/blob graph, and retain each blob as an immutable journal object. The signed descriptor contains a sorted array of `{path,mode,gitSha,sha256,size,bytesObjectDigest}`. Later network work reads those content-addressed objects rather than the mutable worktree or session repository. `__proto__` and all other literal names remain array entries; no normal-prototype filename dictionary is introduced.
2. **Pin representable commit metadata only for the new contract.** Under `journal.publicationContract`, `preparePR` must use one trusted integer timestamp for author and committer, UTC, the existing fixed ASCII name/email, UTF-8 message, one parent, and no extra headers. Its handoff records the raw commit digest and parsed exact metadata. Historical v1/v2 preparation is untouched. The transport still requires the returned GitHub commit SHA to equal `headCommit`; offline fixtures do not prove GitHub serialization, so the later real canary remains mandatory.
3. **Use a publication-specific creator claim.** Add `journal.claimProductPublicationRequest(...)`, implemented with the existing private `appendClaimOwned` pattern and restricted to a version-4 `REQUEST_INTENT`. Only `created:true` permits the sole POST. An existing intent always enters GET-only reconciliation, including when the original POST may still be in flight.
4. **Make every authenticated GET durable and charged.** Initial preflight, existence checks, pagination, reconciliation, and final readback each receive their own `REQUEST_INTENT` and `REQUEST_OBSERVATION`. A retry is a new read request with a new request ID and predecessor binding. Mutation request IDs are never reused or retried.

## Module and reducer worklist

### 1. Closed schemas

**Create:** `product-publication.schema.mjs`

- Export domain constants, `productPublicationProfileSchema`, `productPublicationHostSchema`, `productPublicationDescriptorSchema`, `productPublicationBudgetSchema`, `productPublicationEventOperationSchema`, `productPublicationPayloadSchema`, and public result schemas.
- Keep `token` and containment approval only in the host schema. The profile and `profileDigest` include repository identity, base branch, branch prefix, actor ID, containment status/digest, and no credential or approval bytes.
- Use sorted arrays for file/request plans. Bound 200 files, 1 MiB per blob, 200 MiB raw aggregate, 204 mutation requests, 512 read requests, 300 MiB request bytes, 512 MiB reserved response bytes, 30 minutes reserved elapsed time, 2 MiB per response, and 15 seconds per request. The signed values may be lower but never higher.
- Budget scope is exactly `{objectiveId,journalId,runId,operationKey,objectiveDigest,descriptorDigest}`. Require `publicationStarts:1` and `objectiveTotal === journal budgetLimit`; zero remaining counters are finite exhaustion, never unlimited.
- Descriptor binds repository/authority/baseline/journal/run/objective IDs; prepared product-state, product-config and installed-bundle digests; source inventory/manifest; raw prepared commit digest and exact metadata; base/head/tree; review/full-review/current-green/coverage digests; immutable blob object references and totals; exact branch/ref; and exact draft-PR request.
- Descriptor also binds the digest of the required containment subject: `{domain:'harness.product-publication-containment.v1',profileDigest,productConfigDigest,runtimeDigest,gitDigest,nodeDigest,verifierDigest,workerDigest,protocolDigest,containmentDigest,isolationStatement}`. The statement is a fixed schema literal that the candidate/worker cannot read the token, uploader memory, or journal. The host approval itself stays outside the profile and public projection.
- Construct the PR marker from a non-self-referential digest over the profile, objective, product state, nonce, base/head/tree, operation key, and exact handoff body. Include both the marker binding digest and final marked body in the descriptor.

### 2. Journal version 4 and publication reducer hook

**Modify:** `journal.mjs`

- Extend only the host contract enum with `product.v2.publication.v1`. Set `product=true`, `productV2=true`, `publicationContract=true`, event version 4, and runtime binding `PRODUCT_PUBLICATION_JOURNAL_RUNTIME_BINDING = digestData({protocol:'harness.journal.product.v2.publication.v1',parent:PRODUCT_V2_JOURNAL_RUNTIME_BINDING,event:...})`.
- Event v4 unions the unchanged version-3 operation set with `productPublicationEventOperationSchema`. Call `internal.productTransition` for existing `product-step` events and `internal.publicationTransition` only for `product-publication-step` events.
- Initialize `state.productPublication=null`; do not add publication requests to the legacy `intents`/`pending` reservation model.
- Expose private `publicationContract`, `publicationCustody(fn)`, and `claimProductPublicationRequest(expectedHead,op,ctx,validateNew)`. The claim wrapper must reject every operation except a publication `REQUEST_INTENT` and return `{created,receipt}`.
- Block generic reserve, budget-spend, replace-run, close-run, legacy reconcile, and public candidate append while publication has unsettled custody. Keep `reportProductDifference` possible through the product reducer so an in-flight remote result can be retained and later effects blocked.
- Preserve `appendEvent`, `reconcile`, lock recovery, acknowledgement storage, old schemas, and old runtime-binding constants exactly.

### 3. Fixed GitHub product transport

**Create:** `github-product.mjs`

- Export only `githubProduct(profile,token)`. Return named methods: `getRepository`, `getUser`, `getRef`, `getCommit`, `getTree`, `getBlob`, `listPulls`, `getPull`, `createBlob`, `createTree`, `createCommit`, `createRef`, and `createPull`.
- Build every URL from fixed `https://api.github.com` route templates and separately encoded validated segments. Never accept a URL, method, callback, redirect target, `Link` target, or route fragment from a caller.
- Use direct `node:https`, explicit 200/201/404 handling per operation, fatal UTF-8 JSON decoding, exact response schemas, per-request deadlines/bounds, and no retry or redirect. Treat 422 mutation collisions as conflicts, never observations of success.
- Send the token only as `Authorization: Bearer ...`. Sanitize errors to route kind/status; exclude request headers, token, bodies containing approval data, and response-provided URLs. Verify any returned web/API URL by reconstructing the expected fixed form instead of following it.

### 4. Publication planner, reducer, and lifecycle

**Create:** `product-publication.mjs`

Interface:

```js
productPublicationBoundary(host,runtime,auth,journal) => {
  describe(binding,{operationKey,limits},ctx),
  publish(wire,binding,ctx,guard),
  resume(operationKey,binding,ctx,guard),
  records(ctx)
}
```

- Parse/freeze the host at construction, split `{token,containment.approval,...profile}`, construct the private transport, and bind the profile digest. Keep an in-memory `Map<descriptorDigest,Promise>` only for same-runtime coalescing; durable claims remain authoritative.
- `describe` accepts only the private product binding. It verifies the prepared bare repository with the pinned Git binary/minimal environment, parses the raw commit, recursively reads the complete tree with NUL-safe output, snapshots verified blob bytes into journal objects, generates 32 random bytes as lowercase hex, constructs the exact branch/ref and marked PR body, stores the descriptor object, and returns `{status:'PRODUCT_PUBLICATION_DESCRIBED',descriptor,budget}`.
- `publish` deep-clones/freezes `{descriptor,budget,approval}`, recomputes the description/bindings without generating a new nonce, verifies the `execution-budget` envelope and the execution-supervisor containment observation, then appends `BOUND` and `START` under custody. `START` increments product starts and journal total spent exactly once and initializes publication counters.
- Reducer state contains descriptor/budget/approval digests, publication lineage digest, stage, counters, sorted request records, one uncertain mutation ID at most, and final observation. Payload behavior:

| Payload | Reducer requirement and effect |
|---|---|
| `BOUND` | No prior publication; exact descriptor/object plan; current `HANDOFF_PREPARED`; recorded budget approval valid. No spend or network. |
| `START` | Bound once; current open product run; no product pending/remediation/difference/blocking finding; one original product start and total unit remain. Charge them once. |
| `REQUEST_INTENT` | Exact next closed route/body/predecessor; recorded approval valid at event time; reserve method-specific request count, body bytes, maximum response bytes, and deadline with no refund. |
| `REQUEST_OBSERVATION` | Existing request intent and exact retained acknowledgement/result digest; update typed remote identity. No live freshness is required to retain a response already received. |
| `COMPLETE` | All required final GET observations exact; no uncertain mutation, drift, difference, or stale guard; append final repository/ref/commit/tree/base/PR identity and observed time. |

- Before each new request, synchronously re-run `guard()` inside publication custody and recheck current publication-budget and containment approval handles. After any await, retain a bounded response first, append its observation, then require the guard again before another effect.
- Dispatch POST only from `claimProductPublicationRequest(...).created === true`. Existing mutation intents perform bounded GET reconciliation only. Zero/ambiguous/moved/closed/merged results remain incomplete and never authorize a second POST.
- Each GET retry has a new durable intent. Pagination is internal, fixed at 100 items/page, bounded by signed read count, and complete only when a short page or an exact bounded total proves exhaustion.
- Execute the fixed protocol in this order: repository/user/base-ref/base-commit/head-absence/pr-absence reads; blob existence reads and at most one create per missing blob; tree existence/create/readback; commit existence/create/readback; final base/head checks; create-only ref plus readback; final pre-PR checks; one draft-PR create; PR/ref/commit/tree/base final readbacks. A pending blob/tree/commit/ref/PR mutation replaces its next normal step with the corresponding exact GET reconciliation path.
- Same-runtime `publish`/`resume` calls share one promise. Cross-runtime/process callers converge through creator claims and immutable acknowledgements. Clear the local promise map in `finally`.
- Use stages `BOUND`, `UPLOADING`, `REF_OBSERVED`, `PR_OBSERVED`, `COMPLETE`, `INCOMPLETE`, and `CONFLICT`; stage names never substitute for the exact observations. Project only `PRODUCT_PR_OBSERVED` or `PRODUCT_PUBLICATION_INCOMPLETE`, with `assurance` equal to `FIXTURE` whenever the product execution assurance is fixture-derived. Preserve production, merge, owner acceptance, and readiness as not executed/not ready.

### 5. Product-handle integration and wiring

**Modify:** `product.mjs`, `classify.mjs`, `index.mjs`

- In `classify.mjs`, construct the private publication boundary only when both `host.productPublication` and `journal.publicationContract` exist, then pass it as the fifth argument to `productBoundary`. Do not add it to the public runtime or pass a generic transport.
- In `product.mjs`, keep the existing `WeakMap`. Add a private binding builder containing the exact objective/state/handoff/config/runtime/evidence data and the private prepared-repository path. Add a synchronous guard that re-resolves the same handle, checks current context/grants/source/run/handoff/evidence, and rejects active ordinary source mutation/remediation/rebinding.
- Add only `describeProductPublication(handle,input)`, `publishProduct(handle,wire)`, and `resumeProductPublication(handle,operationKey)` to the public runtime when publication is configured. Deep-clone/freeze all supplied wire data before any await.
- Allow `reportProductDifference` during an in-flight request; reject subsequent source/product effects and publication requests. Make `executeProductStep`, `applyProductRemediation`, automatic rebind, control-cycle, and promotion paths respect active publication custody.
- Under the new contract only, pin UTC author/committer metadata in `preparePR` and retain the exact raw commit metadata needed by the planner. Leave old handoff bytes and assertions untouched.
- Extend product projection with `remotePublication` from the private boundary without replacing the local handoff fields or readiness claims.
- From `index.mjs`, export only signable schemas/domain/runtime-binding constants. Do not export `productPublicationBoundary` or `githubProduct`.

### 6. Offline fixture and TDD matrix

**Create:**

- `tests/product-publication-fixture.mjs` — product-v2 flow, ephemeral owner/execution-supervisor signatures, exact bare-repository inspection, and a deterministic `https.request` fixture using production transport code.
- `tests/product-publication.test.mjs` — schemas, authority, immutable plan, reducer, budgets, races, crash/recovery, and full positive flow.
- `tests/product-publication-process-worker.mjs` — reopen the same journal in separate processes for creator-claim and restart tests.
- `tests/github-product.test.mjs` — fixed routes, token placement/non-disclosure, response validation, bounds, malformed UTF-8/JSON, redirect refusal, and unsupported status behavior.

Write and witness focused RED tests before production changes in this order:

1. Historical v1/v2 contracts and handoff projections remain exact; publication without the new contract fails with zero requests.
2. Descriptor binds all paths/modes/bytes and exact commit/tree/base/review/gate/coverage state; `__proto__`, non-ASCII, and binary bytes survive or fail before network.
3. Forged/cross-runtime handles, modified descriptor/budget, wrong signature/kind/role/scope/repository/run/objective, revoked/expired authority, arbitrary URL/token/callback fields, and stale product state produce zero POSTs.
4. Route-level wrong repository/actor/base/blob/tree/commit/ref/PR identities stop at the exact boundary; commit mismatch produces no ref POST.
5. Same-runtime, two-runtime, and two-process contenders create one start and one mutation intent/POST. A resume during a held POST performs GET-only reconciliation and never dispatches POST.
6. Crash after every mutation intent, response, acknowledgement, and observation preserves counts. Lost ack plus zero/ambiguous search never retries; exact reconciliation permits only the next unattempted mutation.
7. Ack/payload/predecessor/counter tampering, forged completion, generic append/reconcile, lock recovery, terminal run, total/start/request/byte/time exhaustion, and paginated truncation fail closed without counter rollback.
8. A product difference or remote base/head drift during a held request retains its observation and blocks the next mutation/completion. No PATCH, DELETE, merge, branch update, automatic close, or second PR appears.
9. Full fixture flow creates exact blobs/tree/commit/ref/draft PR, performs final readbacks, reopens the journal, and replays with zero POSTs while keeping fixture provenance and `NOT_P0_READY`/merge/production limitations.

Focused commands after implementation:

```sh
node --test tests/product-publication.test.mjs tests/github-product.test.mjs
node --test tests/product-loop.test.mjs tests/human-interruption.test.mjs tests/f27-corrections.test.mjs tests/f27-late-malformed-review.test.mjs tests/f27-late-review-failure.test.mjs
node --test tests/execution-backend.test.mjs tests/journal.test.mjs tests/literal-filename.test.mjs
```

The controller owns the later full `make check`, review, commit, remote canary, and actual pilot. The fixture must state that mocked HTTPS, ephemeral signatures, and fixture containment do not prove real GitHub authentication, raw-commit compatibility, credential isolation, independent acceptance, merge authority, or production readiness.

## Files intentionally unchanged

No initial implementation change is needed in `authority.mjs`, `budget.mjs`, `execution.schema.mjs`, `execution.mjs`, `github-actions.mjs`, `capabilities.mjs`, or `product.schema.mjs`. Historical receipts/tests and old runtime-binding constants remain exact. CI judge policy, protected adoption, the real pilot, and external isolation blockers are outside this worklist.

## Preparation status

READY_FOR_BASELINE_RELEASE. This preparation performed read-only source inspection and wrote only this document. It did not execute a candidate, access network/credentials, edit repository files, add modules/tests, stage, or commit.
