# Runtime boundary preflight — 2026-09-05

Read-only review of the approved H03–H08 plan, review architecture, proposed policies/schemas, and recorded environment preflight. No unfinished H01 diff inspected, no repository edits, implementation, or tests performed. Environment observations below are supplied/recorded observations, not new probes.

**Recommendation:** proceed with a small trusted runtime and data-only candidate interface. H03 pure verification is implementable now. Keep effectful operations disabled until their actual host authority and containment prerequisites pass. A local pack can be portable without promising every capability on every host. Do not implement a daemon or invent a platform to bridge unavailable trust.

## 1. Explicit trust model

Separate three properties in every result:

1. **Recomputed:** an intact trusted verifier actually parsed inputs or recomputed an output.
2. **Host authenticated:** approval/execution provenance came from an approved host identity/channel outside candidate control.
3. **Externally witnessed through sequence N:** an external trusted checkpoint anchors journal history through N; later events do not inherit that guarantee automatically.

The candidate supplies bytes and object references only. It cannot select the trust root, verifier module, schema implementation, adapter implementation, approval identity, or assurance level. An absolute path outside the repository, file mode 0600, a Git commit, and a self-authored digest do not establish trust against a malicious process with the same UID. A trusted runtime launched by an operator can defend against candidate inputs; replacing that runtime and its entire local state remains outside this guarantee. An external witness detects history replacement relative to its anchor; it does not make a malicious runtime execute correctly.

No available host channel is established by ChatGPT auth metadata alone. Missing configured trusted identity returns `BLOCKED_BY_MISSING_AUTHORITY_BINDING`; no automatic creation of an owner key, self-signing, or conversion of the user's implementation mandate into artifact acceptance/deploy authority.

## 2. Minimal APIs

The following are contracts, not proposed public extension/plugin mechanisms. `Verified*`, `Permit`, and `Lease` are opaque handles created by the trusted runtime, retained in private state (for example private fields/WeakMaps), never accepted by deserializing JSON. Serialization produces evidence references only; reload always re-verifies. Branding prevents input forgery within an intact runtime, not runtime replacement.

| Boundary | Minimal contract | Required validation |
|---|---|---|
| Host bootstrap | `openRuntime(hostBinding) -> Runtime` | Operator-established root identifies repo, approved runtime/dependency bundle, schemas/normalizer, authority sources, issuer keys/channel and capability registry. Never resolve these from candidate-controlled configuration or dynamic imports. |
| Authority | `runtime.loadAuthority(authorityRef, approvalRef) -> VerifiedAuthority \| Stop` | Load exact bytes, verify receipt provenance and scope, repo/role/precedence, conflicts, expiration/revocation, schema/runtime bindings. A derived source cannot become normative. |
| Identity | `runtime.identify(bytes, registeredSchemaId) -> Identity` | Schema selected from trusted registry; complete typed tree and triple identity computed locally. Unknown schema/profile is UNKNOWN. Caller-supplied schema digest is merely a lookup claim. |
| Context | `runtime.verifyContext(requestRefs) -> VerifiedContext \| Stop` | Resolve all immutable inputs through authority and verified replay. Unknown/missing proof obligation blocks; no `proofs: {x:true}` or callback that returns a favorable boolean. |
| Classification | `runtime.classifyChange(request, context) -> Assessment` | Recompute evidence; aggregate most restrictive operation classes; output is an assessment, never execution permission. |
| Effects | `runtime.prepareCapability(id, typedArgs, context) -> Permit \| Stop`; `runtime.execute(permit, lease) -> Receipt \| Stop` | Prepare computes exact intended output/delta; permit binds repo/run/head/inputs/scope/grant/budget/runtime and capability digest. Execute checks freshness and containment, reserves budget, then validates effects before success. |
| Replay | `runtime.replay(journalRef, trustedCheckpoint) -> VerifiedReplay \| Stop` | Verify bytes, sequence, parent, operation uniqueness, actors/provenance, allowed transitions, external anchor and assurance boundary. |
| Review/release | `runtime.review(binding, targetRef)`; `runtime.certifyRelease(objectiveRef, replay)` | Both obtain evidence internally; raw model/deploy/smoke JSON never constitutes a verified receipt. |

Keep the proof schema as a **wire evidence description**, with a closed dispatch table per proof kind. Pure proofs recompute from authoritative input bytes; execution-dependent proofs resolve authenticated runtime events; human assertions require an authenticated scoped approval. Do not export a generic `makeProof(kind, true)` or a caller-supplied verifier function. Pending proof kinds remain unsupported and block rather than receiving placeholder implementations.

## 3. Host approval receipts

Minimum envelope: `{version, issuer, keyId, kind, receiptId, repositoryId, subjectDigest, scopeDigest, authorityDigest, issuedAt, expiresAt, revocationEpoch, decision, signature}`. Scope includes exact permitted capability/actions, paths, objective/grant/AC/threat/architecture bindings where relevant. Domain-separated canonical signing bytes include every security field. `kind` distinguishes baseline acceptance, policy adoption, bounded grant, deployment authorization and recovery; cross-kind reuse fails.

Use one host-configured signature verifier with a pinned public key (Node crypto is sufficient), or an existing authenticated host channel with the same verified envelope semantics. Signatures must be produced outside candidate control. A fixture issuer/key is usable only in test construction and cannot be selected by production CLI/config. Rejection cases: altered scope, wrong repo/subject/kind/key, unknown issuer, stale expiry/revocation, replay beyond allowed operations. A signature proves the issuer's attestation; it does not by itself prove a human acted, so issuer enrollment must state which approval channel it represents.

Revocation/time are not magically supplied by hashes: bind an authoritative revocation checkpoint and a host time/freshness policy. If their freshness cannot be established, block operations requiring them. Never silently interpret absent revocations as none.

## 4. Journal and external witness

`appendEvent(expectedHead, operationKey, requestDigest)` runs under exclusive ownership; duplicate key+same digest returns its original outcome, different digest is POLICY. Events record authenticated actor/capability, execution inputs/outputs, runtime binding and transition. Exclusive content-object creation plus a serialized head compare/update are both required; rename alone is not a compare-and-swap. Verify existing object bytes on a digest collision/path reuse. Preserve torn tails as INCOMPLETE; a repairable index is not authority.

Minimal optional witness interface: `readLatest(repositoryId, objectiveId)` and `compareAndAppend(expectedWitness, checkpoint)`. Checkpoint covers `{version, repositoryId, objectiveId, journalId, sequence, headDigest, previousWitnessDigest, authorityDigest, runtimeDigest, issuedAt}` with authentic issuer/channel evidence. It must live outside candidate write access. A manually imported externally authenticated checkpoint can certify a prefix without adding a service; it cannot prove that no newer checkpoint/revocation exists. Strong current-state claims need a fresh external head or an operator-established latest checkpoint. Reject rollback to an older genuine signed checkpoint; do not just verify its signature.

When no witness is configured, allow diagnostic local replay explicitly labeled local/unwitnessed. Do not satisfy a policy that requires a trusted checkpoint, certify immutable audit history, or promote that replay to authoritative state. A locally generated signature with a key available to the candidate provides no external witness.

Record operation intent and budget reservation before an external effect, then outcome. A crash between effect and receipt is uncertain; query the target by the same idempotency key. If the target cannot reconcile that key, return INCOMPLETE and require authorized recovery—never blindly repeat a deploy. Expired lease time alone cannot authorize takeover.

## 5. Closed capabilities and the current containment limitation

Begin with pure, built-in canonical serialization/digest/manifest computations and exact runtime-applied derived writes. No arbitrary `cmd`, JS callback/module, script path, shell text, package lifecycle hook, or project `npm test` can enter as a mechanical capability. Registry entries bind implementation and transitive executable dependencies; `shell:false` only prevents shell interpolation and is not a sandbox.

For writes, runtime checks exact paths, denylist precedence, ancestor symlinks, protected inode aliases, modes, pre/post manifests and lease before publication. Reject symlinks/hardlinks conservatively in the initial writable set. Portable Node path checks do not eliminate hostile concurrent filesystem races; scope the pure local mode to trusted runtime-exclusive writes. Strong defense against another same-UID writer requires an OS/host boundary, not more `realpath` calls. Stage outputs and publish only computed exact bytes; unexpected delta blocks and records evidence, never claims containment merely because a later manifest detected damage.

Execution requires an actual tested containment backend covering filesystem writes, process creation/cleanup, network, environment/secrets and inherited descriptors. Process groups/timeouts are useful supervision, not complete protection against daemonization/escape. The recorded bwrap/unshare failures mean untrusted subprocess capabilities are `BLOCKED_BY_REQUIRED_CAPABILITY` now. Do not fallback to uncontained execution, `--dangerously-bypass-*`, Node permissions as an equivalent OS sandbox, or a user-confirmation flag that silently upgrades guarantees.

## 6. Reviewer and release receipts

H07 preflight freezes binary/dependencies/protocol/model/effort/config/auth mode/schema and containment identity. Existing ChatGPT metadata supports neither a successful isolated login nor a successful review. Require a real authorized session under supported containment before adapter acceptance. A separate process and shadow Git improve separation but are not sufficient when egress/MCP/config/credentials remain unrestricted. If supported isolation cannot run here, adapter contract tests may pass while real-session acceptance remains NOT_EXECUTED. Counterexample replay is untrusted execution and obeys the same containment gate.

The host supervisor creates a review execution receipt binding exact target commit+manifest, input/prompt bytes, independent session ID, adapter digest, raw output digest, exit/termination, limits, primary pre/post manifests and journal operation. Validate strict local Zod output, independently resolve finding locations and reproduce executable counterexamples. A valid `PASS`, exit 0, or signed model output proves neither absence of defects nor product correctness; policy combines review evidence with required verification and unresolved findings. No raw JSON import directly earns `independent_review_verified`.

H08 deploy receipts originate from a fixed approved target adapter, authenticated target response/readback, and operation journal. Bind repo/objective, integrated commit, artifact digest, environment, deployment ID, approval and operation key. Smoke/observability are separate actual executions against that deployment and artifact, with freshness and target evidence. Preview/slice/merge receipts cannot satisfy production obligations. Test adapters must be marked simulation and excluded from real certification. No real target configured means deployment/certification blocked, not a fabricated local PRODUCTION_PASS.

## 7. Resolve before H03

1. **Proposal versus adopted policy:** existing YAML/schemas intentionally require `PROPOSED_NON_AUTHORITATIVE` and `activation:false`. Preserve them as history. Create separate versioned runtime contracts and explicit adoption receipts; changing these flags is not adoption. MIGRATION-01 authorizes implementation, not final baseline acceptance.
2. **Exact numeric semantics:** ordinary JS numbers erase `1` versus `1.0` and round large/decimal values. Preserve scalar source lexemes and exact integer/decimal representation in the identity AST; apply numeric equivalence only for registered field rules. Zod validates the typed domain representation without silently coercing/rounding it. Reject unsupported numeric forms instead of weakening the approved distinction. Add adversarial safe-integer-boundary, signed-zero and exponent cases.
3. **Preconditions versus postconditions:** policy lists include final manifest delta, fresh verification and independent review. These cannot all exist before the operation. Separate provisional prepared permits from completed proof/receipt sets; classification must not grant final PASS in advance. Document unsupported classes in H03 rather than claiming all proof names work.
4. **Human-text/documentation equivalence:** `DOCUMENTATION_ONLY` is insufficient evidence of unchanged human-facing meaning. With no approved structural rule plus required signoff, classify as UNKNOWN/HUMAN_REQUIRED. Similarly tests cannot decide arbitrary program equivalence, preserved coverage, or defect identity universally; implement closed checks and explicit grants.
5. **Capability-dependent milestone acceptance:** H05/H07/H08/H09 end-to-end acceptance cannot all be truthfully achieved here with absent containment/trust/target. Implement and test portable safe refusal now; retain actual blocked acceptance items. This is an environment limitation, not permission to relax acceptance or request a new platform.

Local implementation tests can cover parser/identity negatives, forged/altered receipts, proof injection, wrong authority, rollback checkpoints, crash/replay/idempotency, stale leases, scope/delta rejection, budget continuity, strict reviewer output and target-receipt mismatch using isolated fixtures. Real host-channel authenticity, external witness custody/freshness, OS containment, Codex login/review and production observations require their real configured systems. Report these separately; mocks prove contract handling only.
