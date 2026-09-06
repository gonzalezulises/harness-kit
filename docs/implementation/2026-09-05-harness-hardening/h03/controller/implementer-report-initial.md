# Task 3 / H03 report

Status: DONE_WITH_CONCERNS

Implementation/test/document edits are complete and will be FROZEN immediately
after the final manifest/seal is written. No later edits are authorized without
controller reopening. Independent task review and the controller's full make
check/feature promotion remain pending, not implied by this report.

Review baseline: H02 commit29445190ae94fd85771d5b41223104f8e1d1c011,
exact tree53290b4a99f2d3d0aab25d1eb4510344dda26678. Early work ran while HEAD
wasfff527b2c7a64fb6d70d60d633a0261e68315169 and the reviewed H02 index was
uploading. The latter is the oracle's valid historical anchor, not a claim that
H03 source existed at that commit. Actual source/test bytes are preserved and
hashed. No index, refs, commit, owner keys, credentials or external deployment
were mutated. Parent-owned PROGRESS/feature/ledger changes were left alone.

## Delivered files

All shipping runtime files have one source beneath
`packs/autonomy/repo-template/scripts/quality-orchestrator/`:

- package.json, package-lock.json and .gitignore: dedicated optional package,
  Node>=22, yaml2.9.0 and zod4.5.4, exact SHA512 lock integrity, local node_modules
  excluded. No consumer root package.json or dependency merge is required.
- identity.mjs: YAML1.2 strict parse, full typed values, exact numeric lexemes,
  repository/schema/normalizer bindings and content/canonical/semantic SHA256.
- authority.mjs: domain-separated Ed25519 receipt verification against host-pinned
  keys/roles/kinds, runtime/schema binding, exact scope/authority and live
  time/revocation checks; private per-instance handles.
- classify.mjs: signed accepted-before contexts, closed canonical/digest proofs,
  conservative protected/unknown change handling and whole-batch disposition.
- index.mjs: the shared versioned entry point for H04 onward.
- schemas/record.v1.json and schemas/digest.v1.json: descriptive typed-domain wire
  schemas; strict Zod implementation remains authoritative.
- contracts-v1.md: exact APIs, envelopes, trust model, limitations and integration
  rules. tests/{identity,authority,classify}.test.mjs plus tests/helpers.mjs.

Pack entry/setup guide: packs/autonomy/index.md. Executable verifier:
packs/autonomy/verify-pack.sh (exit69 when dependencies/tooling are absent).
Oracle: .harness/oracles/AC-H03.yaml. Agent Note:
.agents/notes/implemented/architecture/2026-09-06-h03-typed-authority-runtime.md.
Current capability/health text: docs/harness-capabilities.md and
docs/quality-document.md. All evidence is under
docs/implementation/2026-09-05-harness-hardening/h03/.
No archived inactive audit proposal/evidence was changed. Proposed append-only
controller decision is h03/proposed-decision.md; the ledger itself was not edited.

## Actual verification and preserved RED/GREEN

Commands were run in the repository working tree unless a recorded temporary
consumer path is specified. Full raw stdout/stderr are retained; logs are not
summaries. The final source/test/report manifest hashes them all.

| Execution | Actual result | Immutable evidence |
| --- | --- | --- |
| Initial npm install --prefix <runtime> --ignore-scripts --no-audit --no-fund | exit0; exact lock created | dependency-setup.stdout/stderr.log |
| Initial requirements before module exists | exit1, missing-module errors; not semantic RED | capability-absence.stdout/stderr.log; requirements-first/ |
| First executable implementation | exit1 including canonical-authority fixture mismatch and strict signing-helper errors; not claimed as bypass RED | first-executable.stdout/stderr.log; first-executable-source/ |
| Functional closed derivation requirement | RED44 tests/43 pass/1 assertion; GREEN44/44 | derived-red*, derived-green* |
| Deterministic baseline ordering | RED50 tests/49 pass/1 assertion; fixed test passes in next runs | order-red*, order-red-source/ |
| Human comments must not be erased | RED51 tests/50 pass/1 assertion; GREEN51/51 | comments-red*, comments-green* |
| Explicit runtime/schema-bound authority contract | RED52 tests/41 pass/11 failures because new fixture contract is not yet supported; GREEN52/52 | runtime-binding-red*, runtime-binding-green* |
| Missing trusted clock | RED53 tests/52 pass/1 runtime exception; GREEN53/53; current assert.doesNotThrow variant produces assertion RED below | clock-red*, clock-green* |
| YAML mapping impersonates numeric token | RED54 tests/53 pass/1 assertion; GREEN54/54 | numeric-type-red*, numeric-type-green* |
| Exact current tests on reconstructed actual pre-fix module versions | exit1:54 tests,48 pass,6 assertion failures; no import/tooling errors | final-red.command.json, final-red.stdout/stderr.log, final-falsification-source/, red-receipt.json |
| Exact current tests on shipping source | exit0:54/54 | final-green.command.json, final-green.stdout/stderr.log |
| Fresh copied pack without installed deps | exit69 TOOL_FAILURE, as required | missing-dependencies.stdout/stderr.log |
| Copied consumer npm ci --offline --prefix <nested-runtime> --ignore-scripts --no-audit --no-fund | exit0 using exact lock and cached package tarballs | consumer-npm-ci.stdout/stderr.log; integration-commands.json |
| npm test --prefix <copied-consumer-runtime> | exit0:54/54; consumer root package bytes unchanged | consumer-tests.stdout/stderr.log; integration-commands.json |
| bash packs/autonomy/verify-pack.sh | exit0:54/54 | verify-pack.stdout/stderr.log |
| ShellCheck0.11.0, bash -n, node --check for all4 source and4 test/helper modules | all exit0 | static-check.commands.json, static-check.stdout/stderr.log |
| bash scripts/verify-oracles.sh | exit0; all3 current local receipts consistent | oracle-check.stdout/stderr.log |
| bash scripts/verify-agent-notes.sh | exit0;19 notes well-formed | notes-check.stdout/stderr.log |

The dependency stderr retains npm's ambient http-proxy deprecation warning.
No registry failure was counted as success. No credentials/auth retries were
used. The copied-consumer canary tests installability of this nested package;
H09's future --with autonomy installer flow is not claimed implemented.

The final falsification is explicitly an overlay of real captured module
versions: identity from comments-red-source, classify from derived-red-source,
authority from clock-red-source, and current entry point/lock/tests. It is not
represented as a historical commit snapshot. It reproduces missing derivation,
adverse derived-source handling, locale sorting, erased comments, numeric mapping
spoofing and unstructured trusted-clock failure. No unsafe baseline or constant
PASS/negative stub was manufactured. All earlier complete source/test pairs and
streams remain available. h03/evidence-guide.md describes reconstruction and
capture-final.py refuses to overwrite existing final streams. The oracle's
current-test receipt binds all4 current test/helper bytes, actual exit1/argv,
source snapshot and complete logs. This is local consistency evidence, not
independently authenticated review authority.

## Exported contract for H04

Import index.mjs. Public exports are openRuntime, digestData, canonical,
schemaBindings, NORMALIZER_ID, RUNTIME_BINDING and approvalSigningBytes.

openRuntime(hostBinding) returns the runtime or
BLOCKED_BY_MISSING_AUTHORITY_BINDING. Its methods are identify,
describeBaseline, loadAuthority, inspectAuthority, verifyApproval,
inspectApproval, verifyContext, inspectContext and classifyChange.

Host bootstrap must be inaccessible to candidate configuration: operator-pinned
repository/authority digest, enrolled issuer key/role/kinds, trusted current clock
and revocation checkpoint, approved runtime/schema bundle, registered exact file
paths/classes. Missing authenticity/freshness stops. Replacing this host/runtime
or its state is outside the guarantee. Test keys are generated only in the
fixture helper; production never creates keys or enrolls its own issuer.

Identity supports only built-in record.v1 and digest.v1. Unknown schema objects,
fields, tags, aliases, comments, directives, invalid UTF8 and unsupported numeric
forms return UNKNOWN. Exact numbers have parser-private construction before Zod
validation, so a candidate mapping cannot spoof an internal number. The complete
typed value and repository/schema/normalizer binding participate in canonical
and semantic hashes; content hash covers exact input bytes. 1 versus1.0,
large/near-equal decimals, exponents, signed zero and string whitespace remain
conservatively distinct. No numeric equivalence rules are enabled.

Authority canonical JSON binds the exported runtime/schema contract and the
single conservative policy. Domain-separated signatures bind all envelope
fields including kind, issuer role, repository, exact subject/scope/authority,
issued/expiry time, revocation epoch and decision. A valid signature is an
attestation from a host-enrolled channel, not proof by itself that a human acted.
The host establishes that provenance and checkpoint custody/freshness.

VerifiedAuthority/VerifiedApproval/VerifiedContext are frozen empty handles
retained in private per-instance WeakMaps. Copies, booleans, serialized evidence
summaries and foreign-instance handles cannot substitute for them. Inspection
rechecks freshness. Baseline acceptance requires a signature over the recomputed
full supplied document identity manifest; accepted documents are the sole before
bindings. Partial baseline inputs do not imply whole-repository acceptance.

The classifier recognizes identical-bytes.v1, canonical-reorder.v1 and closed,
nonrecursive derived-content-digest.v1. It validates both accepted and new source
hash relations; a changed source must itself be mechanically eligible. Protected
normative/architecture/security/shared changes require human authority. Unknown
proofs, arbitrary program/text equivalence, documentation extensions and test
greens cannot earn mechanical status. Mixed batches aggregate the most
restrictive result. Every assessment has executionAuthorized:false and
postconditions:NOT_EXECUTED. H03 cannot issue a permit, execute/replay an event,
check an external witness, spend a grant or certify review/deployment. H04 must
reuse the verifier and compare verified approval bindings to its own recomputed
obligation; a bare approval handle never authorizes operation replay.

## Concerns and evidence limits

No self-review High/Critical finding remains known after the witnessed fixes,
but independent specification/quality review is pending. The schema vocabulary
is deliberately narrow; new H04+ schemas/proofs require explicit versioned
built-in contracts, not runtime-loaded candidate schema engines/callbacks.
The pure local guarantee assumes an intact operator-established host; same-UID
runtime replacement, live external witness custody, real human channel
enrollment, OS containment, authenticated Codex review and production systems
are not exercised by these fixtures. The host must supply the latest revocation
checkpoint and suitably short validity; this package does not discover new
remote revocations. Unsupported effects/postconditions remain blocked.

The full make check, core/quick/load concurrency suites, feature state and
publication are controller responsibilities per the handoff; no unchanged suite
was rerun here and no full integration success is asserted. Root review baseline
is2944519. Earlier history anchors and logs are intentionally unchanged.
