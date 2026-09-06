# Durable mechanical recovery without fabricated human authority

Governing documents: AGENTS.md and docs/quality-document.md.

Scope and normative authorization: docs/implementation/2026-09-06-human-interruption/plan.md.
Contract: packs/autonomy/repo-template/scripts/quality-orchestrator/contracts-human-interruption-v1.md.

The explicit product.v2 extension separates completed valid review judgments
from bounded tooling attempts, derives infrastructure IDs, persists normalized
review output before ingest and rereads it on resume. The original signed grant
contains the exact closed record/golden/corpus transformation; semantic changes
and expired authority cannot inherit it. OPEN is required both at description
and under custody in the remediation intent reducer.

The release driver consumes supplied existing authorizations and reconciles
original pending operation keys. Unknown authority is an operational diagnosis,
not automatic permission or an invented human decision. Fixture production
traces do not establish a real deployment. The credential-shaped-ID fixture
uses an explicit synthetic adapter rejection followed by a clean terminated
reviewer attempt and valid retry. No real credential detector is certified.

Historical tests/contracts/receipts stay intact. New tests are confined to
human-interruption.test.mjs; compact causal evidence binds its exact bytes.

An opt-in version preserves existing signed contracts and their replay meaning;
changing v1 in place would invalidate that history. The tradeoff is that existing
consumers must select v2 to receive this recovery behavior. Broader recovery
rules should be added only for a demonstrated failure with a bounded equivalence
proof and an actual consumer verification path.

The integrated gate exposed a possible retained-ack publication window. A
causal filesystem-lock fixture reproduced one effect and zero observations.
Both product versions now retry only bounded custody acquisition for that
retained evidence, revalidating authority/source under custody and publishing
once. Existing owner locks, journal schemas, signed budgets and effect keys
retain their meanings. The original global process interleaving is unknown.
