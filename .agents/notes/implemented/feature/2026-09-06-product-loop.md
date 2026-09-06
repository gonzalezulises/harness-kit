# Bounded product loop preserves historical authority semantics

Governed by AGENTS.md, DECISIONS.md and bin/ARCHITECTURE.md; the exact scope is
in docs/implementation/2026-09-06-product-loop/plan.md.

The approved P0 plan adds functional product work that H06 equivalence and the
v1 journal do not describe. Reusing ordinary reserve events for documentation,
patches and review counters would mislabel that work and alter historical
meaning. A new opt-in product journal decoder therefore adds one internal
product-step reference while retaining the v1 schemas/binding exactly.

The controller derives closed child steps from one signed product objective,
keeps code inventory separate from accepted normative documents, applies model
patches as data under journal custody and uses observed verifier cases plus
independent worker sessions. A pinned host verifier remains a trusted capability;
fixture workers do not establish authentication or OS containment. The final
local PR artifact does not publish or authorize merge.

New tests live only in product-loop.test.mjs. Historical tests/receipts remain
unchanged. Current static verification checks syntax, exact v1 binding and those
historical bytes; it does not require current source to equal an older candidate.
The diagnostic CLI JSON is installation observation only, including nonzero
unavailable/dependency failure, and never READY certification.
