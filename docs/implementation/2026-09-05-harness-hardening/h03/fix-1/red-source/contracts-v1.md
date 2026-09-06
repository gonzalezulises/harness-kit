# Autonomy runtime contract v1 — H03

This is an installable runtime contract, separate from the immutable inactive
policy proposals in docs/reviews. Node >=22, yaml2.9.0 and zod4.5.4 are required.
The exported surface is index.mjs. Nothing here returns an execution permit.

## Trust and bootstrap

`openRuntime(hostBinding)` takes operator-established host configuration. This
constructor belongs to the host supervisor; never expose it as a request route
or read its settings from candidate-controlled files. The candidate may supply
serialized data and byte arrays through the listed methods, never executable
objects, getters, callbacks, imported modules or replacement runtime code.

Host fields are `repositoryId`, `authorityDigest`, `now`, `revocation`, `issuers`
and `files`. `now()` supplies current trusted integer time in a consistent unit
(the tests use milliseconds); all timestamps use that same unit. Revocation is
an operator-established current checkpoint `{epoch, asOf, expiresAt,
revokedReceiptIds}`. Missing, expired or unavailable time/revocation basis
blocks. The checkpoint is copied and stays fixed in this runtime instance;
create a new runtime for a newly authenticated checkpoint and reverify handles.
The host must keep checkpoint validity suitably short and ensure it is the
latest trusted state. This runtime cannot discover unreported remote revocations.

Each pinned issuer is `{issuer, keyId, role, kinds, publicKey}`. Keys must be
Ed25519 public keys; their custody and enrolled human approval channel are the
operator's responsibility. A signature proves that enrolled issuer's attestation,
not independently that a human clicked. Kinds are policy-adoption,
baseline-acceptance, bounded-grant, deployment-authorization and recovery. The
latter three can authenticate a wire approval but gain no execution/budget
semantics in H03. No candidate-selected role hierarchy or precedence exists.

Each registered file is `{path, schemaId, class}`. Paths are exact relative
paths; no glob, parent traversal or adapter selection. Classes are data, derived,
normative, architecture, security and shared. Configuration is copied. The
runtime/schema bundle and the host process itself must be approved outside the
candidate's control. Host replacement or another process mutating that trusted
bundle/state with the same UID is outside this guarantee.

## Identity

`runtime.identify(bytes, registeredSchemaId)` returns IDENTIFIED or UNKNOWN.
Only byte arrays and built-in schema IDs `record.v1` and `digest.v1` are supported.
A caller-supplied schema digest/object is an unsupported lookup claim. Schemas
are strict Zod contracts, with descriptive typed-domain JSON schemas in schemas/;
this is not a general schema engine or arbitrary JSON/YAML equivalence service.

record.v1 contains exactly title:string, status:active|paused, enabled:boolean
and threshold:number. digest.v1 contains exactly sourcePath:string and
sourceContentSha256:lowercase SHA256. Unknown fields or schemas stop. Numbers
are parsed into `{type:'number', lexeme:<exact source>}` before Zod validation.
No floating-point arithmetic or rounding decides equivalence. Signed zero,
exponent spelling, large integers and near-equal decimals remain distinct.
Hex/octal, infinities and unsupported numeric spellings stop. YAML1.2 core
mapping/scalar/sequence parsing rejects duplicate keys, aliases, anchors, tags,
merge keys, directives, comments, invalid UTF8 and documents larger than1MiB.
Comments are rejected because erasing human prose is not proof of equivalence.
Structural YAML whitespace/key order may differ; string content is preserved.

Identity contains repositoryId, schemaId, schemaSha256, normalizerId and the
complete validated typed value. contentSha256 hashes exact supplied bytes.
canonicalSha256 hashes a sorted canonical typed representation with its binding;
semanticSha256 hashes that same complete representation with the separate
harness.semantic.v1 domain. No scalar numeric equivalence is enabled in v1.
Identities are frozen data, not authority handles. `schemaBindings`,
`NORMALIZER_ID`, `canonical(data)` and `digestData(data)` are exported for trusted
producers; canonical/digestData are for JSON-domain values and do not validate a
schema or confer trust.

## Authority and accepted before state

Authority is canonical JSON bytes with exactly `{version:1, repositoryId,
policyId:'conservative.v1', role:'normative', runtimeBinding:RUNTIME_BINDING,
scope:{paths:[...]}}`. RUNTIME_BINDING is exported and binds protocol,
normalizer, registered schema descriptions and policy identity. Host approval of
the actual source/lock bundle is a separate prerequisite; a version/digest alone
does not protect a replaced runtime. The host pins digestData(authority).
Noncanonical authority JSON, duplicate/unknown fields and unsupported policies
stop. Paths in scope are unique.

`runtime.loadAuthority(authorityBytes, policyAdoptionReceipt)` verifies the exact
pinned authority, repository and scope, producing an opaque VerifiedAuthority.
The adoption receipt subjectDigest and authorityDigest both equal the pinned
authority digest; scopeDigest equals digestData(authority.scope).

An approval envelope contains exactly version:1, issuer, issuerRole, keyId, kind,
receiptId, repositoryId, subjectDigest, scopeDigest, authorityDigest, issuedAt,
expiresAt, revocationEpoch, decision:'approve', signature. `approvalSigningBytes`
validates the unsigned envelope and produces UTF8 bytes with domain prefix
`harness.approval.v1` plus NUL and canonical JSON of every security field.
Signature is canonical base64 Ed25519. Altering kind, issuer role, repo, subject,
scope, authority or freshness invalidates approval. Unknown keys/fields reject.

`runtime.verifyApproval(receipt, expectedBinding)` requires exact kind,
subjectDigest, scopeDigest and authorityDigest, and returns an opaque
VerifiedApproval or a structured stop. `runtime.inspectApproval(handle)`
rechecks freshness and returns evidence describing the actual verified binding.
H04 and later consumers must compare that binding to their own recomputed
obligation and operation; an approval is not itself an operation-replay permit.

`runtime.describeBaseline([{path,bytes},...])` recomputes a sorted complete
identity manifest and its domain-separated digest. It is an unsigned description,
useful to the host approval channel, not an accepted baseline.
`runtime.verifyContext({authority,documents,acceptance})` reidentifies every byte
and requires a baseline-acceptance receipt whose subjectDigest equals that exact
manifest digest and whose scope/authority match adoption. No substituted before
object or candidate same_* boolean is accepted. Partial documents mean only
those exact accepted documents are available for classification, never an
implicit whole-repository acceptance. Unknown/duplicate paths reject.

VerifiedAuthority, VerifiedApproval and VerifiedContext are empty frozen handles
retained in per-runtime WeakMaps. JSON copying, booleans or a handle from another
instance cannot create authority. inspectAuthority/inspectContext return frozen
evidence summaries and recheck receipt expiry/revocation; summaries cannot be
used as handles. Serialization requires full re-verification on reload. No
journal replay or external witness assurance is claimed by H03.

## Classification and proof limits

`runtime.classifyChange({changes:[{path,after},...]}, verifiedContext)` recomputes
before/after identities. Unknown keys, proofs, policies, adapters, unregistered
paths, missing before state, empty batches and duplicate paths return UNKNOWN.

Closed proofs are identical-bytes.v1, canonical-reorder.v1 and
derived-content-digest.v1. The last applies only to registered derived digest.v1
files. The accepted digest must refer to the accepted content hash of one
registered non-derived source. It preserves sourcePath and recomputes the exact
new content hash from accepted bytes or a separately eligible source change in
the same batch. Source substitution, recursive derivation, invented digest
values and human/unknown source transformations stop. Batch ordering does not
matter. Unsupported numeric equivalence, program/text equivalence, test greens,
documentation extensions, coverage, review and postcondition proofs never become
mechanical eligibility.

Known normative/architecture/security/shared byte changes require a human.
Other typed semantic changes are HUMAN_REQUIRED. Disposition aggregation is
UNKNOWN before HUMAN_REQUIRED before MECHANICAL_ELIGIBLE; invalid/stale trusted
context is UNKNOWN/BLOCKED. Every result has executionAuthorized:false,
assurance:recomputed and postconditions:NOT_EXECUTED. Even an eligible mixed
batch grants no partial authorization. Runtime inspection may report
host-authenticated inputs, but classification never implies external witnessing,
containment, a completed effect, or acceptance of a new baseline.

H04 should import this package and reuse approval/context/identity verification,
not deserialize handles or add a second signature implementation. New schema,
policy or proof kinds require a versioned built-in implementation and adversarial
tests; candidate callbacks or a boolean proof registry are not extension points.
