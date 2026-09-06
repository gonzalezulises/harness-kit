# Closed local effects preserve the verified boundary

Under AGENTS.md, docs/quality-document.md and MIGRATION-01 in DECISIONS.md, H05
extends the single existing runtime with canonical record writes and one finite
source/digest batch. Exact signed grants, private permits, persistent exclusive
leases, actual implementation/dependency hashing and complete pre/post manifests
make classification a provisional input to execution rather than permission.
The complete projected accepted document set is validated before writing: a
canonical-only change cannot silently invalidate an accepted dependent digest.

Runtime-created local-effect intent is durable and distinguished inside the
journal. Generic host target reconciliation cannot settle it, including after
reopening; the supervisor must recompute the actual complete postcondition and
persist its own receipt. This closes the integration route that accepted an
unrelated target response as completion. Both defects have preserved causal RED
source/test/log evidence. H04's two narrow availability fixes remain in this same
integration, with previous tests and evidence unchanged.

A generic command/plugin framework, new service and new dependencies were rejected
because the two concrete operations need none. The cost is deliberately narrow
schemas, runtime-exclusive cooperating writers, bounded complete workspace scans
and refusal of partial-effect automatic repair. No elapsed lease time grants
ownership. No OS containment is available here, so subprocess operations remain
BLOCKED_BY_REQUIRED_CAPABILITY / NOT_EXECUTED. Revisit this boundary only with a
real approved host containment backend and separately verified custody, not more
path checks or process-group cleanup. Details and limits live in the runtime's
contracts-capabilities-v1.md and the H05 implementation evidence directory.
