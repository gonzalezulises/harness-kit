# Secret scanner filters must anchor to the keyword, not any colon

**Decided:** no-secrets-committed keeps its broad match but pipes through two
keyword-anchored filters: drop values that are `$VAR` references, keep only
values containing a digit.

**Why:** propagating gates to Aurobalance flagged two healthy lines —
`apikey: $SUPABASE_SERVICE_ROLE_KEY` (env reference in a workflow) and
`const secret = requireWebhookSecret()` (a call; identifiers carry no digits,
credentials practically always do). A first filter draft matched the digit in
git grep's `file:line:` prefix — the filters therefore re-anchor to the
credential keyword. Regression cases for both shapes live in the suite; the
fixture credential stays caught (175/175).

**Given up:** a digitless real secret would slip this rule; accepted — the
alternative flagged every `secret = fn()` in every governed repo.
