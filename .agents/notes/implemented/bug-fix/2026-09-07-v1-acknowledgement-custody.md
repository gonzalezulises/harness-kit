# Retain v1 verifier results through transient custody contention

- Date: 2026-09-07
- Owner: harness-kit maintainers under the authorized PR33–37 closure
- Context: `AGENTS.md`; `packs/autonomy/repo-template/scripts/quality-orchestrator/contracts-product-v1.md`+
The integrated PR35 check observed one verifier invocation and no observation.
Its child results were not retained, so that exact interleaving is unknown.
The new oracle was written before the fix; exact published PR35 source produced
two causal failures and a persistent-custody control PASS. Preserve both records.

Backport only F27's bounded acknowledgement publication to product.v1. Re-read
the original pending nonce and acknowledgement under journal custody and check
authority/source again before publication. Retry only custody conflict, at most
three attempts, with250ms/1000ms waits. Persistent foreign ownership and expired
authority remain closed. No new verifier effect, charge, signature or budget is
created. Original receipt schemas and historical tests remain unchanged.

This adds bounded latency under contention. It does not turn an uncertain effect
into a retryable effect or recover another owner's lock. Focused regressions5/5
passed; full integrated checks and independent review are recorded separately.
