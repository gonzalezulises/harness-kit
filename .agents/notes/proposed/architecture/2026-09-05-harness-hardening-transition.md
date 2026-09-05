# Preserve legacy consumers while introducing verified replay

The hardening proposal keeps the portable installer and v1 behavior while
placing a future local runtime in an optional pack. Adoption makes
`feature_list.json` a replay projection only in an opted-in consumer. Historical
receipts remain intact and are imported as `LEGACY_UNVERIFIED`; a fresh real
verification earns a new receipt. This is MIGRATION-01, a proposal awaiting the
owner's architecture decision, not an accepted entry in `DECISIONS.md`.

The current kit has useful verification and evidence discipline, but no M01–M04
runtime or verified journal replay. Calling mutable JSON a journal would claim
a guarantee it does not have. Replacing that authority globally would break
existing consumers. The optional pack gives up uniform enforcement across all
installations in return for an explicit migration and a viable rollback.

The audit follows `AGENTS.md`, the existing `DECISIONS.md` ledger and the user's
execution condition: material contradictions require HARNESS_REVIEW_BLOCKED
after completing the audit and plan. Proposed policies stay inactive; no
baseline or historical evidence is approved by this change. Known bypasses
have executable RED probes and remain unresolved until remediation.

Revisit this proposal when the owner resolves MIGRATION-01 or provides the
working Aurobalance runtime for an extraction assessment. Then execute the
approved milestones without additional housekeeping approvals, retaining
semantic gates and independent review. The complete contracts, tradeoffs and
verification limits are in the
[review](../../../../docs/reviews/2026-09-05-harness-hardening/README.md).
