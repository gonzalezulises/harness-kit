# Codex review boundary — H07

This optional extension uses the existing runtime, Ed25519 approval verifier and
objective journal. It adds no provider registry, service, credential reader or
generic command runner. Its current executable behavior is trusted local Git
shadow construction, diagnostic preflight/output validation and safe refusal.
Real Codex execution and independent-review acceptance are **NOT_EXECUTED**.

| Runtime method | Contract |
| --- | --- |
| `describeReviewPolicy(input)` | Computes the closed subject and exact scope for existing external `bounded-grant` approval. No authority is granted. |
| `preflightReview({policy,approval})` | Verifies the signature and all pins; resolves an approved model/effort pair against the complete diagnostic catalog; returns an opaque frozen binding. |
| `inspectReviewBinding(binding)` | Rechecks approval freshness and actual pinned files, returns diagnostic identity with `acceptance: NOT_EXECUTED`. |
| `createReviewShadow(binding)` | Builds one exact Git target from verified commit/tree/blob identities; returns an opaque shadow belonging to this binding. |
| `inspectReviewShadow(shadow)` | Recomputes primary and shadow manifests and exposes the shadow location and target digest. |
| `describeReviewRound(binding,shadow)` | Returns fixed thread/turn parameters as data, repeating model, effort, cwd and approval constraints. This is not a launch permit. |
| `reviewRun(binding,shadow)` | Rechecks binding and manifests, then returns `BLOCKED_BY_REQUIRED_CAPABILITY`, `execution: NOT_EXECUTED`, `acceptance: NOT_EXECUTED` and null output, execution receipt and budget receipt. |
| `validateReview({output,receipt},binding)` | Parses strict local output, resolves finding locations against the exact shadow, checks supplied receipt bindings and refuses unauthenticated provenance. It never returns an independent-review handle. |

The input contains objective ID, operation key, product/harness review category,
target SHA-1 commit, exact prompt, auth mode, ordered model/effort pairs and
bounded output/time limits. The signed subject also covers repository, exact
scope and pins for the runtime/dependency bundle, artifact registry, configuration,
schema and unavailable containment identity. The actual adapter source and its
existing YAML/Zod/Node dependencies are covered by `installedBundleDigest`.
The operator supplies a complete immutable registry of absolute resolved Codex
executable, transitive executable dependencies and protocol artifact paths with
their byte hashes; the runtime re-reads each before every operation. Registry
completeness and trusted host custody remain operator prerequisites.

Host observations are a closed normalized catalog (`model`, supported `efforts`,
complete flag), auth mode and remote schema capability. The only presently
supported provenance is explicitly `FIXTURE`; `NOT_EXECUTED`, incomplete catalogs,
duplicate model identifiers, wrong auth mode and no approved compatible pair
block. This package performs no account/catalog request and creates no real
capability-discovery claim. The operator's signed order supplies preference;
catalog order and lexicographic names supply none. There is no implicit model,
effort or authentication downgrade. Absent remote JSON Schema changes only the
transport plan: local validation always uses the same pinned strict Zod schema.

Local Codex 0.153.4 generated protocol schemas informed the transport shape:
`ModelListResponse` has `data` and optional `nextCursor`; models expose supported
reasoning efforts but no approved ranking. `ThreadStartParams` exposes model,
provider, cwd, sandbox, approval policy, ephemeral mode and config;
`TurnStartParams` can override model/effort/cwd/approval policy and output schema.
The round description repeats the frozen choices and has no override input.
It is deliberately incomplete as a production launch system: CLI flags alone
cannot enforce bounded MCP, egress, secret custody or process cleanup.

Shadow construction uses the host-pinned absolute Git executable for only `init`,
`cat-file` and `rev-parse`. The child environment is an explicit allowlist with
an empty isolated home, global/system config disabled, no credential or proxy
variables, no inherited descriptors beyond controlled stdio, no lazy fetch,
no replace-object influence and no allowed network protocol. Source repository
configuration is never opened as Git configuration: only its verified plain
object directory is exposed to the fresh Git repository. No clone, checkout,
filter, hook or candidate program is run. Raw object headers/content are hashed
locally and written into the shadow; the original commit identity is preserved
with a shallow boundary. Ordinary and executable files retain exact bytes/modes.
Symlinks, hardlinks, submodules, alternates, unsafe/ambiguous tree names, unsupported
object formats and bounded-size violations stop. The actual primary file manifest
must match the exact target, and complete primary/shadow manifests are rechecked.
The shadow has no inherited index or history beyond its target; no clean-index
or history-analysis guarantee is made. Git trust checks remain enabled.

Output is untrusted UTF-8 JSON text. JSON syntax and duplicate keys are checked
before strict Zod validation; extra fields, invalid severity/location, duplicate
finding IDs, contradictory verdicts and oversized output block. Counterexample
text is retained as data, never executed. `REVIEW_OUTPUT_VALIDATED` means only
recomputed parsing/location checks, with `independentReviewVerified: false`,
`acceptance: NOT_EXECUTED`, explicit unresolved High/Critical count and
`counterexamples: NOT_EXECUTED`. It proves no arbitrary product equivalence.

The receipt wire binds repository/objective/operation, exact target and manifest,
prompt/output bytes, independent session ID, adapter/binding/model/effort/auth/schema,
limits, primary before/after and exit/termination. Mismatches or cancellation
block. Even an otherwise exact receipt, simulation flag or signed raw JSON lacks
authenticated host-supervisor provenance here and returns
`BLOCKED_BY_MISSING_AUTHORITY_BINDING`. There is no supported authenticated receipt
import or receipt minting path. H08 therefore may consume **none** of these outputs
as authenticated independent-review evidence; unavailable review cannot certify
release or discharge required review obligations.

Known missing containment/authenticated execution is checked before spending.
Repeated unavailable requests do not consume signed review units. A future
supported host implementation must call the existing
`spendBudget(kind,objectiveId,operationKey)` immediately before actual reviewer
launch, retain its replay-derived reservation even on cancellation/failure, and
create a separate authenticated execution receipt. This package adds no simulated
backend merely to exercise that call. Neither a budget event nor a scoped review
policy accepts artifact bytes. Existing H06 continuation remains limited to its
registered identity regression contract.

This local mode assumes intact trusted runtime and exclusive cooperating writers.
Hashes, modes and path checks do not contain malicious concurrent same-UID writers.
Missing tested OS containment, authenticated session and counterexample execution
remain explicit limitations. Do not add an escape flag, copy global credentials,
skip Git trust, retry the cancelled authenticated preflight or silently switch
adapters inside a frozen run. Rollback keeps the run/binding evidence and disables
the new adapter. A future supported host must actually run this reviewed adapter
under authorized containment before real acceptance can change.
