# The pack's JSON readers must honour depth, or the gate signs for what it never read

**Decided:** `sentry-check` prunes a response to the nesting level a reader
actually means before matching. `json_field` reads the object's own level,
`json_field_deep` reads any level and is used only where Sentry genuinely
nests (release health under `projects[].healthData`), and `json_count` counts
elements of a root array rather than keys at any depth. Scalar cleanup strips
trailing structure before the quotes, so `"ok"}` no longer yields `ok"`.

**Why:** the readers matched the first key at any depth. Sentry's monitor
response carries a per-environment `status` alongside the monitor's own, and
when the environment list serialises first, a **disabled** monitor read as
`ok` — `bin/sentry-check cron` printed a pass and exited 0 for a scheduled job
nobody was watching. That is the precise outage the cron check exists to
prevent, and the gate was issuing a receipt for it. Same class in
`/releases/{v}/commits/`: each commit carries `author.id`, so the count
reported twice the commits that exist. Verified against the live rizoma-di
org on 2026-08-30 — its 25 releases all carry zero associated commits and it
has no monitors, which is why the flat stubs never exposed the bug.

Five cases pinning the real nested shapes joined the matrix (55 → 60). Four
of them fail against the previous readers; the fifth pins the health contract
that already held, so a later prune cannot quietly break it.

**Given up:** `json_field_deep` still reads the first match, so it stays sound
only while one project is in play — a multi-project release response could
read the wrong project's crash-free rate. Left as is rather than guessed at:
the org has no release health data to verify the real shape against, and a
reader written against an imagined response is the mistake this note is about.
Depth-pruning also costs an `awk` pass per read, which is nothing next to the
HTTP call it follows.
