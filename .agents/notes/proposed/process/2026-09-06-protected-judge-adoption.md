# Adopt the reviewed judge through an additive policy proposal

The new hardening workflow requires a protected-base judge that current main
does not yet contain. Adding the exact reviewed snapshot under a separate path
lets the existing required checks validate an adoption proposal before the
hardening workflow starts using it. AGENTS.md, DECISIONS.md and
bin/ARCHITECTURE.md govern the authority transition.

The proposal preserves the active workflow, its verifier scripts, existing
feature claims and branch rules. The owner adopts the snapshot only by reviewing
and merging this separate PR through normal checks. A failed check is not an
adoption mechanism. The hardening PR remains subject to the new base checks and
its other outstanding review/acceptance gates.

Replacing the current judge immediately recreates the bootstrap dependency;
using the candidate judge would remove the intended separation. A copied,
source-hashed snapshot costs some duplicated bytes but introduces no second
implementation. Revisit its location only when a supported protected workflow
mechanism can provide the same authority without snapshots.

See [the adoption procedure](../../../../docs/protected-judge-adoption.md).
