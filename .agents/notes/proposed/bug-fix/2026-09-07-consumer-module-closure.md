# Include the complete pinned production runtime in consumer bundles

The owner's 2026-09-07 PR33–37 closure mandate authorizes this integration fix.
AGENTS.md, DECISIONS.md, bin/ARCHITECTURE.md and docs/quality-document.md remain
the governing documents. The current product/distribution integration failed
its real offline fresh-clone import because the historical hardcoded module
list omitted product.schema.mjs.

The builder and validator now share one exact top-level production module and
contract predicate, retain the original required minimum, and bind every entry
to its exact immutable Git source path. Tests, fixture modules and subdirectories
remain excluded. The unchanged33-case distribution suite passed after this fix
and received independent static approval. The failed integrated check and
pre-fix manager remain retained; this is not claimed as a new historical PR36
failure or as accepted live runtime authority.

Stable manager payload changes still require explicit migration. The correction
does not bypass drift, migration, ownership or plan-digest checks. The real
isolated consumer upgrade/rollback test must start from a baseline containing
this manager and preserve the consumer's later config and journal. The missing
original F26 RED variant remains historically unavailable.
