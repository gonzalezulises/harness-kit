# The pack was auditing everyone else's observability and nobody had audited it

**Decided:** three fixes in `packs/sentry/repo-template`, each closing a hole
the pack itself opened in every repository it was installed into.

`sentry-scrub.ts` redacts secrets carried in URLs, wired into all three
`Sentry.init` calls through `beforeSend` and `beforeSendTransaction`. Workflow
inputs move from `${{ }}` inside `run:` scripts to `env:`. `sentry-to-issues`
sanitises issue titles and caps how many it can open in one run.

**Why:** a security review on the first real installation found all three. Each
was verified against the code, not taken on the reviewer's word.

`sendDefaultPii: false` does not filter the URL. Sentry sends the request URL,
the transaction name, the Referer and every navigation breadcrumb verbatim. The
target repo puts capability tokens in the path — `/mi-perfil/<token>`,
`/encuesta/<token>`, `/encuesta-evaluacion/<token>`; the review spotted one, the
code has three — so the first error on a client's page would hand that client's
live token to a third party, and anyone with read access to the Sentry project
could use it. The token is not PII, it is a credential. This is a wellbeing app.

GitHub substitutes `${{ inputs.release }}` before bash ever reads the line, so
the surrounding quotes bound nothing. Anyone able to dispatch the workflow could
inject commands into a job that exports `SENTRY_AUTH_TOKEN`.

The client DSN is public by design — it ships in the browser bundle — so anyone
can create a Sentry issue whose title they control, and the backlog command
copied that title into a private tracker where `@mentions` notify people.

**The uncomfortable part:** this pack's entire argument is that a gate must be
proven rather than assumed, and its failure matrix had 68 cases. None of them
could have caught these, because every one measured whether the gate detects
failure — never what the gate exposes by being installed. A tool that verifies
others earns no exemption from being verified. Eight cases now cover the
surface, including the exact `${{ }}`-inside-`run:` shape.

**Given up:** the scrubber is a heuristic — a path segment of 16+ characters
mixing letters and digits — plus an optional route list. It cannot recognise a
short token, and it will redact a legitimate identifier of that shape. Accepted
in that direction on purpose: a redacted analytics dimension is recoverable, a
leaked capability token is not. Title sanitisation likewise does not
authenticate origin, which is impossible with a public DSN; it removes the edge
rather than the vector.
