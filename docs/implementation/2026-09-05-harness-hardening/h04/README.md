# H04 evidence — frozen implementation handoff

Base history: `96438e86b3d671027c8398b8c10edbb994e8ee59` (reviewed/published H03).
The owner authorized H04 implementation, not baseline acceptance, adoption or
production effects. Root owns independent review and the broad repository gate.

Final source passes static syntax checks, 29 focused runtime cases and 6 distinct
public integration cases, all exit 0. Commands and raw output/status are stored
as `static-*`, `runtime-*` and `e2e-*`. The public integration cases exercise
mechanical fresh-run authority/budget continuity, signed witness CAS transport,
actual SIGKILL after durable log append, two actual competing writer processes,
lossless legacy import with the existing ratio reader, and both source/scaffold
legacy writer refusal before effects. No H03 test or receipt was changed.

`initial-missing.log` is the initial absent-API baseline, not an implemented
security falsification. `development.log`, `recovery-red.log`, `reader-red.log`,
`key-red.log` and `focused-green.log` are earlier development observations; only
the final static/runtime/e2e results cover the frozen current source/test set.

Two concrete adverse assertions are causally RED against the one preserved
`red-source/` snapshot and the exact final current test bytes:

1. Old run could reserve after the host workspace's commit/content binding changed.
2. Candidate could occupy the runtime-reserved reconciliation operation-key prefix.

Run `bash docs/implementation/2026-09-05-harness-hardening/h04/reproduce-red.sh`.
It copies the single preserved source/test snapshot into a temporary directory,
links the already installed pinned dependencies, runs those two test names, and
returns observed exit 1 with two assertion failures. It does not edit the working
tree, refs or index. `causal-red.log`, `causal-red.status` and `red-receipt.json`
bind the preserved defective source and exact current test bytes. Both fixes are
included in the final 29-case runtime GREEN. Local receipts establish content
consistency, not independent authentication.

`source-manifest.json` records final H04-owned source, tests and contract/docs
hashes. `evidence-manifest.json` records preserved evidence hashes. The implementation
handoff report is `.superpowers/sdd/migration-plan/task-4-report.md`.

Limits are explicit in `contracts-journal-v1.md`: trusted local runtime/state and
host acquisition adapters, no same-UID containment claim, simulated external
witness custody, synchronous local filesystem, no actual effect or PASS receipt,
and no automatic repair of torn log tails or interrupted recovery ownership.
H09 owns adopted-marker installation and protected custody. Missing intermediate
external witness links stop rather than silently accepting a newer head. These
are bounded supported behavior, not invented remote-service acceptance.
