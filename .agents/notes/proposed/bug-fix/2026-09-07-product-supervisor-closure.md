# Preserve product authority at Git and verifier boundaries

The owner's 2026-09-07 closure mandate authorizes necessary PR35 corrections.
AGENTS.md, DECISIONS.md, bin/ARCHITECTURE.md and docs/quality-document.md govern
this change. Original product.v1 signed scope, journal, step limits and local
handoff remain unchanged.

A linked worktree's per-worktree Git directory has no object store. Resolving the
absolute common directory preserves the exact source parent without changing
source index, references or frozen bytes. Fatal UTF-8 decode failure belongs
inside the verifier promise boundary so the controller records a typed stop and
keeps the original pending key, rather than throwing from the child callback.

Fresh current-byte causal RED on exact published dd8a20c failed both reviewed
Medium cases; the same two tests passed after these narrow changes. They check
actual parent/tree/bytes and an actual resume with no duplicate verifier call.
Evidence in docs/implementation/2026-09-07-closure/pr35-corrections is separate
from earlier product.v2 receipts. No history, signed budget or authority is reset.
Real pilot, remote publication and overall closure remain unaccepted.
