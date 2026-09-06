# Required CI selects one versioned protected judge

The required workflow resolves its judge contract, parser, quick gates, feature
contracts and decision ledger from `.harness/protected-judge/v1` in the exact
base checkout. This keeps one reviewed policy root and prevents a candidate
marker or verifier from satisfying the protected check. AGENTS.md, DECISIONS.md
and bin/ARCHITECTURE.md govern this authority boundary.

Keeping the judge at the base repository root was simpler, but it made an
additive adoption proposal impossible to validate with the prior workflow.
Candidate fallback and automatic owner acceptance were rejected because either
would let proposed bytes judge themselves. The cost is a versioned snapshot
whose source manifest must be reviewed and adopted separately. Revisit the path
only through another explicit protected-policy adoption.
