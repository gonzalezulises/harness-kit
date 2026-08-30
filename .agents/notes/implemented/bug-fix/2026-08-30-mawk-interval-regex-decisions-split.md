# Decision splitting must not use interval regex — mawk has none

**Decided:** `split_entries` in verify-decisions.sh matches horizontal rules
with `/^---+[[:space:]]*$/` instead of `/^-{3,}[[:space:]]*$/`.

**Why:** Ubuntu's default awk is mawk, which does not implement interval
expressions, so the `---` separator was never skipped on Linux: appending a new
decision glued a stray `---` to the previously-last entry and produced a false
DECISION_REWRITE_FORBIDDEN. Passed everywhere on macOS (BSD awk supports
intervals) and on any repo whose ledger was not appended to — a landmine every
governed repo carried. Surfaced by the kit's own claims gate on PR #4 once
layer output became visible; reproduced in a node:20 container (mawk) and
verified fixed there and on macOS.

**Given up:** nothing; `---+` is equivalent for 3+ dashes here. Deployed repos
need the fixed script copied over (harness-init never overwrites) — tracked in
sdlc-ai-nativo P20.
