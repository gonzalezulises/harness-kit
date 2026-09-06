# Verifiers fail before effects when their contract or authority is invalid

**Decided:** the four portable legacy verifiers validate their complete input
before executing a declared command or emitting a successful verdict. Feature
verification requires one uniquely identified active feature, WIP=1, valid
layers and budgets, and no recorded failed attempt unless a future trusted
runtime supplies recovery authority. Claim verification executes each
declared layer in order without reusing a prior command result. Decision checks
require an explicit baseline and preserve it as an exact byte prefix.
Architecture rules reject ambiguous JSON and NUL-bearing commands; typed
`match_argv` rules declare their legitimate match/no-match exits explicitly.

**Why:** the hardening review reproduced false greens and unintended effects:
an empty command shifted repair prose into the execution column, blocked work
could run again and erase its receipt, malformed JSON became an empty success,
declared but unreadable authority disappeared, cached success survived an input
mutation, indentation changed executable policy, and failed architecture rules
lost their exit status. These faults share one cause: validation or authority
was inferred after lossy parsing and after execution had already become
possible.

**Recovery boundary:** local state, budget maxima, and ledger receipts are all
mutable, so they cannot authorize their own retry. Until the verified runtime
and external authority/witness arrive, a budgeted feature with any recorded
failed attempt exits `RECOVERY_AUTHORITY_REQUIRED`, remains blocked, and keeps
its configured maxima and receipts. A fresh first attempt remains valid. This
conservative boundary cannot detect total local history erasure or replacement;
that stronger anti-tamper guarantee belongs to the externally witnessed
runtime rather than this portable verifier.

**Given up:** identical claim commands are no longer deduplicated. Command text
alone cannot prove that filesystem, environment, or earlier-layer inputs stayed
unchanged, so the speedup was an unverifiable cache. Whitespace-only edits to an
old decision are also rejected because Markdown contains code, tables, and prose
whose meaning can depend on whitespace; there is no document parser in this
portable layer that can prove equivalence.

Legacy architecture-rule strings still execute with their existing Bash
semantics, but any nonzero status is a check error. Rules that use a matcher's
exit 1 for a legitimate no-match must use the structured `match_argv` form;
the shipped root and full-template rules use that form and ordered regex
filters instead of shell pipelines ending in `|| true`.

Revisit caching or mechanical decision formatting only after a versioned input
manifest or document parser can establish equivalence. R11 installer wiring and
R12 repair-only re-earning remain separate milestones and are not covered by
this decision.
