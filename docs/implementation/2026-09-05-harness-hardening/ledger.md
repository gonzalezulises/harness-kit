# Implementation ledger — plan: docs/implementation/2026-09-05-harness-hardening/plan.md

Base: `9ee4eaaf6b19ded4b5e32349d77ba8fdaf6af79e`, branch `review/harness-hardening-autonomy`, PR #33.
Authorization: owner’s explicit “Implementa todas las mejoras” resolves MIGRATION-01.
Baseline: `./init.sh` exit 0, 273 passed, zero failed.

## Preflight contract scan

| Tasks | Producer / consumer or self-consistency | Resolution |
|---|---|---|
| H01 | Legacy strict parsing, state and authority guards / existing valid CLIs | Preserve command bytes and CLI; invalid inputs now block. |
| H02 | Gates, profiles and scoped remediation / installed consumers | Kit-only gates require an explicit profile; universal gates remain required. |
| H03 | Identity, classifier, authority / typed inputs | No LLM/boolean authority; proposed policies become runtime contracts only through explicit adoption. |
| H04 | Append/replay/migration / state source | Historical receipts imported as unverified; no old PASS synthesized. |
| H05 | Lease/manifests/capabilities / effects | Denylist wins; no generic shell capability; fail closed without containment. |
| H06 | Grant and budget / continuation | Authoritative limits required, no reset on run replacement. |
| H07 | Frozen adapter / independent review | Real CLI/auth certification required; unavailable capability is not PASS. |
| H08 | Replay obligations / release | Deploy needs scope-specific authorization; simulation never production certification. |
| H09 | Installed consumer canary / complete flow | Isolated local canary allowed; baseline acceptance remains owner-only. |
| H01, H02 | shared verify-claims, tests and mirrors | Sequence edits; repair prose exception belongs H02, strict command identity remains. |
| H02, H09 | installer profiles / optional pack adoption | Existing files preserved; no force migration. |
| H03, H04 | typed hashes / event inputs | Identity includes schema/normalizer/repository binding. |
| H03, H05 | classification / closed capability | Eligibility is not execution permission. |
| H03, H06 | trusted authority / grants | Host supplies trusted anchors; candidate grants cannot approve themselves. |
| H04, H05 | operation keys / lease | Exact operation idempotency with fencing and verified head. |
| H04, H06 | journal / budget counters | Replay is source; revocations and all runs share objective budgets. |
| H04, H08 | replay / next obligation | Fresh integrated commit and deployment identity required. |
| H05, H07 | shadow workspace / reviewer process | No inherited untrusted hooks or unrestricted network/MCP. |
| H06, H07 | review budgets / retries | Transport retries consume mechanical budget, never silently change model. |
| H06, H08 | grants / next authorized slice | Continuation cannot enlarge objective or production access. |
| H07, H09 | live adapter certification / end-to-end canary | Finish all implementable work; report missing external capability precisely. |
| H08, H09 | local release canary / production semantics | Local fixture deployment verifies plumbing only; production acceptance is separate. |

## Rulings

- Ruling: preserve the original review and its manifests at their recorded commit; write current implementation state here — otherwise updating PROGRESS would appear to rewrite historical evidence — cost if wrong: consumers need the documented commit when checking the historical manifest.
- Ruling: the existing named review branch is the isolated implementation workspace — no main mutation or additional worktree is needed — cost if wrong: branch scope grows to include fixes, reviewed in the same draft PR.

## Execution

Task 1: active. H01 is the only active feature; no product baseline accepted.


## Runtime boundary decisions for H03–H09

Independent preflight: [runtime-boundary-review.md](runtime-boundary-review.md).

- Ruling: runtime policy/adoption contracts are separate from archived inactive proposals — implementation authorization is not baseline acceptance — cost if wrong: operator adoption remains required before effects.
- Ruling: identity preserves exact numeric source forms by default; registered schema rules alone may declare exact numeric equivalence — cost if wrong: conservative extra semantic stops, never floating-point equivalence bypass.
- Ruling: classification prepares eligibility; postconditions (fresh verification, final manifests, independent review) can only be earned after execution — cost if wrong: caller workflows must distinguish prepared permits from completed receipts.
- Ruling: no generic documentation/program equivalence by extension or green tests; unsupported proofs fail closed — cost if wrong: fewer automatically eligible operations until registered structural proofs exist.
- Ruling: effects require host-configured trusted authority, witness where required and tested confinement for untrusted commands; no self-issued owner keys or uncontained fallback — cost if wrong: effects remain unavailable on hosts that cannot meet the contract.
- Ruling: complete implementation and local contract/canary testing even when real Codex/production acceptance is unavailable; report capability-dependent acceptance separately — cost if wrong: feature acceptance stays blocked despite code/tests delivered, instead of inventing product certification.

Public dependency versions observed: yaml 2.9.0, zod 4.5.4, Codex CLI 0.153.4. Codex protocol schemas generated locally. Native namespace probes and Landlock ABI unsupported in this host. An authenticated account/catalog preflight was not executed: tool network approval was cancelled before a decision. No alternative channel will bypass that cancellation.

Task 1 verification before independent review: focal 12/12, core 281/0, quick gates 8/0, full `make check` exit 0 (419 passing assertions; two authenticated-gh load cases skipped). `make verify-feature F=F15` recorded actual static/runtime receipts. F15 reopened to active, with receipts retained, because independent review identified additional candidate bypasses awaiting focused reproduction. No H01 commit or H02 activation yet.

Task 1: fix round 1/5 started (0 addressed, 6 open — mutable recovery/maxima; partial-ledger accounting; NUL command framing; decision slug collisions; grep-substring false success; duplicate JSON keys). Independent review: `h01/round-1/independent-review.md`; seven isolated probes preserved in `independent-probes.json`. The original implementer owns the entire fix wave. Minor failure-log suppression will be addressed in the same touched test runner. No H02 work begins with these High findings open.

- Ruling: H01 rejects execution after any recorded budgeted failed attempt when verified recovery authority is unavailable, including edited/removed maxima or changed state; preserve configured limits and receipts and diagnose missing recovery authority rather than exhaustion — the approved H01 contract already requires a verifiable grant, and v1 has none — cost if wrong: ordinary legacy budgeted retries stop after the first recorded failure until operators adopt the verified H04/H06 continuation path. This does not detect wholesale replacement of local history; strong anti-tamper assurance still needs external trusted state/witness. No local hash, mutable Git state or boolean becomes a grant.

Task 1: fix round 1/5 reviewed (5 original findings addressed, 3 High open — inconsistent blocker history; filter compilation after effects; decision suffix without a real line boundary; frozen trees 0ca1ec1..f1fa81c). Focal 25/25, core 283/0 and quick gates 8/0 were read by the independent reviewer; three isolated probes still produced undesired success. Minor regression-output suppression addressed. Fix round 2/5 dispatched to the original implementer with only the three open findings.

Current legacy claim status: F09 is blocked because its recorded two-attempt verification is superseded by the approved conservative recovery boundary. Its meaning and original receipts are unchanged; an exact full feature-list snapshot from9ee is preserved as `h01/legacy-feature-list-9ee.json` (SHA256 54ce91287a316e64cb4a2f4552af55a46f8d79d737d734a965753cdc6acd658f). The other thirteen historical feature records remain identical. F15 tests the replacement contract. This prevents new test greens from falsely recertifying the old F09 behavior; it does not erase historical evidence or grant v1 recovery.


Task 1: fix round 2/5 reviewed (2 addressed, 1 High open — append separator
extends an unterminated protected line; frozen trees f1fa81c..c54d3ab).
Final split-test evidence: 31 tests, six RED assertions, zero errors; 31 GREEN.
Earlier interim captures were read before the implementer froze the test split;
no commit or published completion relied on them. Final exact captures and the
amended independent review resolve the mismatch in `h01/fix-2/`.

Task 1: fix round 3/5 reviewed (1 addressed, 0 open; frozen trees
c54d3ab..e89712f). Spec compliance and code quality approved. The permanent
append cases reject heading, dash, space and tab concatenation before a real LF
or CRLF boundary. Focal RED: 31 tests, three assertions, zero errors; GREEN:
31/31. The reviewer inspected unique complete logs and matching source hashes.
All pre-fix source/test pairs are retained in `h01/snapshots/` so independent
reproduction does not depend on unpublished intermediate Git objects.

Task 1 full verification: `make check` exit 0, 421 passing assertions
(283 core + 15 Gherkin + 55 load + 68 Sentry); two load cases requiring an
authenticated gh were explicitly omitted. No implementation bytes changed after
the approved frozen tree. F15's declared layers now distinguish focal runtime
from the existing shipped-CLI/scaffold end-to-end suite; promotion is re-earned
with all three ordered layers rather than hand-assigned. Current module health
is recorded in `docs/quality-document.md`.

H02 handoff: protected CI currently copies base scripts into the head checkout;
that can make candidate feature commands exercise old source under a head label.
The physical judge/target separation, live policy and migration compatibility
belong to H02. H01's local verification is not an assertion that this old CI
boundary or authenticated external acceptance has been repaired.

Task 1: complete locally, review clean; F15 promotion command exits 0 for all
three layers, quick gates 8/0. Atomic publication checkpoint is this commit.
The next milestone is H02/F16. Baseline acceptance and product deployment remain
ungranted; no stronger runtime guarantee is claimed.

Evidence packaging: raw subprocess logs retain their original trailing spaces.
The code/document diff whitespace check excludes only captured `.log` artifacts;
their exact bytes remain covered by SHA-256 manifests. No runtime gate, test or
proof expectation is relaxed. The reviewer probe exports inputs and results,
not its disposable fixture Git database.
