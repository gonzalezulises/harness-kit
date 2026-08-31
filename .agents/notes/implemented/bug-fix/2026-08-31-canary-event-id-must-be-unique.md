# The canary worked exactly once per project, and lied every time after

**Decided:** `cmd_canary` builds its `event_id` with `canary_event_id()` — 16
bytes of `/dev/urandom`, falling back to `RANDOM` seeded from the PID and the
clock. Four regression cases pin the shape and, above all, that two calls never
agree.

**Why:** the id was `printf '%032d' 0 | tr '0' 'a'` — thirty-two literal `a`s,
identical on every run everywhere. Sentry deduplicates by `event_id`, so only
the first canary a project ever received was stored. Every later one was
accepted with HTTP 200, dropped silently, and the gate then printed
`event accepted by ingest`, waited out its timeout hunting a marker that would
never appear, and reported UNCONFIRMED against a perfectly healthy Sentry.

The command exists to say that **accepted is not stored**. It was committing
that error while sending the very probe meant to detect it, and the failure was
shaped to be undiscoverable: it passes the first time you try it, which is the
only time anyone tests a new gate.

Proven against the live `rizoma-di` project, not reasoned about. Two events with
the constant id produced one issue; the second never appeared, though ingest
returned 200 for both. Two events with generated ids produced two issues. The
canary events were resolved afterwards so the project was left as it was found.

**Given up:** `RANDOM` on the fallback path carries 15 bits per group rather
than 16, so the ids are not uniformly distributed. Accepted — this is a
deduplication key, not a secret, and it only has to differ from the last one.
Depending on `uuidgen` or `openssl` would have cost the kit its "bash and
nothing else" property for a probe that does not need cryptography.
