# Human interruption reduction — bounded independent increment

Owner requirement: HUMAN INTERRUPTION REDUCTION, 2026-09-06. This explicitly
supersedes automatic Product Owner escalation for mechanical/tooling exhaustion
inside this opt-in increment; it does not authorize merge, deployment, new
product meaning, signature renewal or a reset of signed resource limits.
Base is published P0 commit dd8a20c1465b3ccd7e9a4d86ed6a11860146e7f7 (#35).
PR33 is frozen; #34 is the unadopted protected-judge proposal; #36 is the separate
distribution increment. Casabat and Aurobalance are evidence only, never targets.
Baseline ./init.sh passed286/0. Historical F09 and F25 stay blocked with their
receipts intact; no consumer authority or real P0 acceptance is fabricated.

| REQUIREMENT | COVERED | PARTIAL | MISSING | CURRENT_EVIDENCE | NEXT_CHANGE |
|---|---|---|---|---|---|
| Four justified human-decision answers | | | yes | Scattered HUMAN_REQUIRED/POLICY statuses | Typed classification in the reached controller paths |
| Automatic mechanical classification | | yes | | classify/continuation recognize canonical equivalence | Operational causes, recovery and visible classification |
| Separate tooling and judgment budgets | | yes | | budget categories exist; FULL/FIX currently charged at INTENT | Durable bounded tooling attempts; count valid judgment separately |
| Deterministic infrastructure IDs/refs | | yes | | identity hashes exist; review schema expects model IDs | Resolve allowed evidence and derive IDs locally |
| Durable normalized output before ingest | | yes | | journal putObject/getObject use canonical hash + fsync | Persist, bind ledger, reread exact object, then ingest |
| Reuse bounded approved correction | | yes | | continuation handles canonical-record representation | Verifiable authorized delta and unchanged semantic bindings |
| Release objective continuity | | yes | | release obligations and reconciliation exist | Bounded driver of only already-authorized actions |
| Ten empirical regression fixtures | | | yes | Similar individual cases, no complete circuit | One fixture file for all ten and semantic negatives |

## Minimal contract and implementation

Use product.v2 selected explicitly by journal.contract and version2 inputs.
Preserve every product.v1/journal-v1 meaning, signature and historical test.
Extend existing product, review, journal, budget, continuation, execution,
release, classify and schema files only as necessary. No new service, provider,
framework or dependency. Keep normal use on existing product entrypoints;
classification must run in actual recovery paths, not only in an exported demo.

HUMAN_DECISION_REQUIRED needs an actual permitted category plus the exact missing
decision, why existing authority does not cover it, real alternatives and their
semantic/authorization/safety consequences. A category or four invented strings
is insufficient evidence. Unknown causes remain fail-closed operational diagnosis.
Canonical bytes, stale derived bindings, IDs, allowlisted evidence references,
transport/schema packaging, local plumbing and authorized bounded fixes are
AUTO_REMEDIABLE when checked invariants establish that classification.

Reserve resource costs before attempting effects. Count FULL/FIX judgments only
when a valid durable review is ingested once. Tooling repair/retry has bounded,
durable limits and a progress fingerprint. Never reset a signed budget, repeat
an uncertain POST, release another process's lock or rewrite journal history.
If authorized operational resources cannot make progress, return an explicit
OPERATIONAL_BLOCKED checkpoint; do not invent a Product Owner decision.
Journal repair preserves original bytes and links the recovery/fresh replay.

The reviewer supplies finding/severity/rationale/evidence selection/counterexample
meaning. Infrastructure identifiers, references and hashes come from the harness.
Canonical normalized payload bytes MUST NOT contain their own hash. Their hash
is stored in the outer ledger/receipt. Persist with putObject, bind the digest,
read again with getObject, and ingest those verified canonical bytes. Enforce:
sha256(persisted normalized bytes) == ledger digest == sha256(ingested bytes).
A missing/corrupt durable object cannot fall back to ephemeral session memory.
Repair uses retained authenticated output, or obtains another valid review.
Actual credential exposure remains a safety issue; an infrastructure identifier
that merely trips a shape check can be normalized without weakening that check.

Reuse approval only with current authority and a mechanically verified delta
already allowed by the original grant: same AC, scope, threat model and
semantics. Recompute approved golden/corpus outputs from that correction; a
boolean sameSemantics claim is never a proof. Do not rebind an expired/revoked
signature to a new subject or introduce product thresholds/classifiers.

runRelease drives existing obligations through production evidence only when
the objective and exact effects are already authorized. It must distinguish
an unavailable input/capability from a real external authorization decision.
No actual production operation is authorized by this implementation task.

## Verification and review

One new human-interruption.test.mjs holds all ten requested Aurobalance-style
fixtures (synthetic, small): canonical YAML/bytes, stale run, credential-shaped
output rejection, evidence_refs, durable_test_id, lost normalized output,
tooling-exhausted budget, unnecessary reapproval, stale approval after an
approved correction, and repeated mechanical blockers. Exercise the actual
controller, persistence/ingest and resume, not labels alone. Add specific
negative semantic, expired-authority, out-of-scope, invented-evidence and
uncertain-effect cases. The release driver uses local authorized fixtures.

Write tests before implementation; retain meaningful causal RED and GREEN,
current source/test hashes, minimal error and reversible defect patch. One
independent scoped review follows; fixes use only focused re-review. Historical
suites stay exact. Run affected tests first, then required make check once the
reviewed source is frozen; rerun only for a concrete failure or changed input.
Root owns feature promotion, final receipts and publication as a separate PR
based on #35. No unsupported real-model, containment or production claim.
