# harness-wiring checks the integrations a repo depends on, as the right account

**Decision.** `bin/harness-wiring.sh` is a read-only checklist that asks the live systems
whether a repo is wired to what it needs:
- identity: profile, git email, which gh account sees the repo;
- GitHub: Dependabot alerts and security updates, a required check;
- quality: CI present, a lint that is not the removed `next lint`, SonarCloud declared;
- deploy: Vercel Git link and production SHA, or Cloud Build trigger and last build;
- Supabase: open signup over `USING true` policies, leaked-password protection;
- Sentry: DSN declared in production;
- cross-wiring: production declares the variables of each integration the code uses, and a
  smoke that marks a login wall as unverified, never green.

**Scope follows D10:**
- A missing required check fails only where the repo reaches production, detected as a linked
  Vercel project, a Cloud Build trigger or a workflow that deploys. Elsewhere it is a note.
- Archived repos report `ARCHIVED` and are not checked.

The first fleet run over 47 Mallol clones marked 38 repos for a missing required check,
experiments included. A check that fails everywhere gets skimmed, so it was scoped.

Every line names the object it asked about. It reports `WIRED`, `PARTIAL` or `NOT_WIRED`;
`--json` gives the same for agents, `--quick` re-uses the last full run for session start, and
`--fleet OWNER` gives one line per local clone.

Account profiles hold identifiers only, never secrets. They live in
`~/.config/harness-kit/profiles/<owner>.profile`, outside the kit, so the kit stays generic.
They do not use `.env` names, so they are not mistaken for secrets and do not trip a
`.env`-guard hook.

**Why.** On 2026-10-23 every failure that cost real time lived outside the repo, and no gate in
the harness could see it:
- Dependabot off in 235 repos;
- four sites that did not deploy themselves;
- open Supabase signup over `USING true` policies;
- a Vercel CLI user whose GitHub could not see the repo it was asked to connect.

**Alternatives rejected.**
- *A per-repo CI job.* It needs every platform token as a repo secret, which turns a read-only
  check into a credential-distribution problem.
- *Fixing as well as checking.* A check that also writes is a check nobody runs casually.
  Each failing line names the fix instead.
- *Profiles inside the kit.* Account ids are the owner's, not the kit's.

**Given up.**
- SonarCloud and Sentry are checked as declared, not as working. `packs/sentry` proves events
  arrive.
- Behind IAP or a login, the render is reported as unverified.

**Revisit when** a failure class repeats that a line here could have named, or when a check
here starts failing on repos that are in fact fine. A noisy check gets skimmed, and then it
protects nothing.
