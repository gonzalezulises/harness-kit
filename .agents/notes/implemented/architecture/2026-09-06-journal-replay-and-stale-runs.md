# Journal replay preserves authority across mechanical fresh runs

H04 extends the one autonomy runtime with a cohesive local journal module and
closed event, run and checkpoint contracts. Exclusive ownership, content-object
verification, sequence/hash chains and head CAS preserve ordered intent and
objective budget. HEAD is a repairable index; external current-state claims
require a newly fetched scoped signed checkpoint matching the full chain.
The existing H03 Ed25519 verifier is reused for checkpoint and recovery receipts.

Mechanical fresh runs re-read the actual final workspace through the operator
binding, re-prove its complete manifest against the original opaque accepted
context, and retain the original acceptance and lineage. Earlier terminal
verdicts and objective spending cannot be reset. This avoids unnecessary human
acceptance for representation-only changes without trusting candidate summaries.
H04 permits no PASS or executable capability. A crashed intent requires target-key
reconciliation, and a dead-owner lock additionally requires scoped signed recovery.

A service, database, generic verifier and second signature stack were rejected:
none is needed for this boundary. Synchronous host acquisition adapters and the
existing Node filesystem/crypto/Zod dependencies suffice. Local file modes and
hashes do not contain a same-UID replacement of the trusted runtime/local state.
Tests exercise simulated external witness transport and a real SIGKILL boundary;
they do not certify an external production witness or effect adapter.

Legacy bytes remain exact and unverified. A frozen projection maps old claims to
blocked plus LEGACY_UNVERIFIED with provenance, preserving read compatibility.
The source/full-template direct writer refuses an adopted-v2 marker before layer
effects. H09 owns marker installation and protected adoption; the marker itself
is not cryptographic authority. No baseline was accepted and no consumer adopted.

Revisit when a real external witness requires explicit intermediate checkpoint
synchronization or an authenticated effect adapter supplies terminal verification
receipts. Those extensions must preserve current closed contracts and objective
budgets. Governed sources: AGENTS.md, DECISIONS.md (MIGRATION-01),
bin/ARCHITECTURE.md and docs/quality-document.md. Runtime details live in
packs/autonomy/repo-template/scripts/quality-orchestrator/contracts-journal-v1.md.
