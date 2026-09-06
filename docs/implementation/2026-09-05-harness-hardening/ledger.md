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

Task 2: active on top of the immutable reviewed H01 index tree b0ee52e.
H01 publication reads index blobs only; H02 edits the working tree only until
that checkpoint is imported. No overlapping implementers or index mutations.
- Ruling: start H02 after H01 local verification and clean independent review
while its exact reviewed index is being uploaded — index isolation preserves the
H01 publication bytes and avoids waiting for mechanical upload — cost if wrong:
publication must stop if the index differs; no H02 bytes may enter H01's commit.
- Ruling: use a pinned standard safe YAML parser for full-harness oracle parsing,
with an explicit prerequisite and an isolated installation path; minimal remains
Bash/Python-only and does not claim full mechanical readiness — strict parsing
is necessary to close R16 — cost if wrong: full consumers need the declared
parser setup; missing dependency blocks instead of silently weakening validation.

Task 1: published (9ee4eaa..fff527b), exact remote/local tree b0ee52e;
review clean, full check421/0. H02 working changes remained outside the index
and were preserved when the exact API-created commit was imported.

H01 remote CI observation: run34002096392/job101402668518 at exact fff527b
stopped at ShellCheck0.11.0 SC2034 unused variables. Remaining tests were skipped
by the workflow, not passed. H02 owns the bounded unused-assignment cleanup in
its touched script/test files and mirrors; no lint suppression or threshold
reduction. Source of evidence: GitHub Actions job logs saved in scratch.

Task 2: frozen initial implementation at review tree45d528d. Independent
specification and quality review started with read-only review_h02. Controller
validated207 source/evidence hashes and the report seal. Implementer reports
focal27/27, core286/0, live8/8 and pinned lint0; full integration is pending.
Two concurrent core286/0 and two load55/0 runs and the0.72s INCOMPLETE readiness
probe have exact unchanged-source records. Later bounded trust/import and rule
detail corrections have separate RED/reconstructible snapshots and final checks.

Task 2: initial review complete (0 Critical, 0 High, 3 Medium open).
Spec and quality need fixes. Fix round 1/5 begins for isolated parser setup,
owned status child cleanup and explicit missing delivery-document rejection.
The original frozen tree remains45d528d; review and three bounded probes are
retained in h02/review-1/. No next milestone or H02 publication yet.

Task 2: fix round 1/5 approved (3 addressed, 0 open). Independent spec
and quality reviews are clean for the combined H02 task and scoped corrections;
fix review tree e4534d3. Controller verified163 source/evidence hashes.
F16 promotion ran actual ordered lint, focal30/30 and shipped-CLI/scaffold
e2e286/0 layers, exit0; frozen source remained identical across the run.
Full make check is the remaining local integration gate. H02 decision is appended
without changing any prior decision bytes; baseline remains unaccepted.

Task 2: complete locally, independent reviews clean; F16 promoted by actual
three-layer execution. Full make check exit0: 8 quick gates and424 assertions
(core286 + Gherkin15 + load55 + Sentry68); two authenticated-gh load cases
explicitly omitted. Source hashes remained unchanged; stderr empty.
Controller evidence and independent re-review are preserved in h02/controller/.
Fourteen legacy contracts/receipts remain identical; only F09 state is blocked.
This is the atomic H02 publication checkpoint. H03/F17 is next.

- Ruling: retain the exact captured unified diff at
  h02/judge-import-red-05-snapshot/tracked.patch and exclude that single raw
  capture, like raw logs, from the publication whitespace check — its leading
  context spaces are patch syntax required for faithful source reconstruction —
  cost if wrong: artifact whitespace is validated by its hash/reconstruction,
  while every shipping source and current document remains whitespace-checked.

Task 3: active after H02 clean independent review, actual feature promotion
and full check424/0. H02 index tree53290b4 is frozen for exact API publication;
H03 source/state edits stay in the working tree until that commit is imported.
The same immutable-index publication ruling used for H01 applies.

Task 2: published fff527b..2944519, exact remote/local tree53290b4;
H03 working-tree changes stayed outside the index and survived import.
H02 review and full check424/0 are complete. Actual exact-head remote run
34004221994 reports failure; job detail is being inspected before classifying it.

H02 remote CI classified from actual job101408391783 logs: lint and Gherkin
passed; protected live-policy step stopped with ADOPTION_REQUIRED because
base88ea1e6 has no required judge contract. Repository pipeline, protected
claims and decision checks were skipped, not passed. Exact log and digest are
in h02/controller/remote-ci-2944519.*. No rule, authority or baseline changed.

Task 3: initial implementation frozen at review treef508b94, base2944519.
Controller validated154 manifest entries and the report seal. Independent
review_h03 examines specification and quality. Reported local evidence54/54
and copied-consumer54/54; full controller integration remains pending.

Task 3: initial review requests two bounded Medium fixes, no Critical/High.
Fix round 1/5 starts for explicit TAG directive rejection and stale constructor
stop propagation; original frozen treef508b94 remains reconstructible.
Review and three probe artifacts are retained in h03/review-1/.
- Ruling: keep changed protected-class source bytes behind a human gate; only
  ordinary registered data uses canonical-equivalence eligibility in this v1
  contract — authority source bindings are exact and this proof does not rebind
  them — cost if wrong: protected-source formatting incurs a conservative stop
  until a separately approved proof contract covers that authority boundary.

Task 3: fix round 1/5 approved (2 addressed, 0 open), treea358faa.
Independent specification and quality are approved; controller verified116
source/evidence/report manifest entries. F17 ordered static, identity/authority
runtime and public-classifier integration layers actually passed (exit0), with
source unchanged. Full make check is running. H03 decision is appended; original
decision bytes and all historical receipts remain preserved.

H03 full-check-01 did not complete: automatic approval review rejected an
HTTPS k6 usage-report connection because its payload was not established or
authorized. No exit/result receipt exists; preserved partial logs are not GREEN.
Read-only process inspection found no matching controller/k6 process remaining.
- Ruling: disable k6 usage telemetry with its documented K6_NO_USAGE_REPORT=true
  option for fixture/controller verification — this removes an unrelated
  outbound metadata effect and preserves every test expectation — cost if wrong:
  fixture usage is absent from vendor telemetry; product performance claims
  and thresholds are unchanged. No alternate route retries the denied report.
Task 3 integration fix round 2/5: add the opt-out to the fixture runner and
record the coupling; scoped review and a new full run follow before publication.

- Owner steering, 2026-09-06: asked how much remains and explicitly requested
  avoiding overengineering. H01/H02 are published, H03 is in final integration,
  and H04–H09 remain. Continue the authorized scope with the smallest concrete
  implementation that satisfies each contract. Reuse the existing runtime and
  pinned dependencies; add no speculative extension framework or service.
  Nonblocking Medium/Low findings may go to the original permitted backlog.
  Keep High/Critical fixes, causal evidence, independent review and required
  integration gates. Reuse evidence instead of duplicating snapshots or rerunning
  checks without a specific remaining risk. This changes execution priority,
  not authority, acceptance criteria or the meaning of PASS.

Task 3 integration fix round 2/5: independent specification and quality both
APPROVED, zero findings, staged tree965733a5. Controller verified16 manifest
entries; H03 source and tests retain their previously reviewed bytes. Actual
F17 three-layer re-verification passed62 tests, exit0, source unchanged. The new
full-check-02 runs with the documented fixture/controller telemetry opt-out;
the interrupted first attempt remains preserved and is not counted as GREEN.

Task 3: complete locally. Full-check-02 exit0, source unchanged, stderr empty:
8 quick PASS and486 assertions (core286 + autonomy62 + Gherkin15 + load55 +
Sentry68); two authenticated-gh load cases explicitly omitted. Independent
specification/quality and both bounded correction reviews are approved, with
no open finding. Actual F17 promotion receipts and complete raw verification
streams are in h03/controller/. The interrupted first attempt and exact remote
H02 ADOPTION_REQUIRED CI evidence remain separate. No baseline is accepted.
H04 is next after freezing this atomic publication index.

Task 4: active after H03 independent approval and full-check486/0. H03 index
tree69e1282c is frozen for exact publication; H04 working-tree changes remain
unpublished until their own review/gate. Owner priority: concrete minimal
journal/replay/recovery in the existing package, no speculative platform.

Task 3: published2944519..96438e8, exact local/remote tree69e1282c. H04
working-tree changes were preserved outside the publication index. PR33 remains
draft and now records H01–H03 complete, H04 active, H05–H09 pending.
Exact-head remote CI run34005465297 is in progress; no result claimed yet.

H03 exact-head CI run34005465297/job101411703549 completed with the same
protected-base ADOPTION_REQUIRED boundary: lint/Gherkin pass; repository full
pipeline, claims and decision checks skipped. Exact raw log SHA256
2b76a3e126fb16dfefde94433a28bfc9def6fc10bf9c65ed1fb3154cd925dd98.
PR33 records this result; no judge fallback, rule weakening or adoption occurred.

Task 4: frozen review treee3f83a2, base96438e8; controller verified13 source and35
evidence hashes. Independent specification and quality APPROVE, no High/Critical.
F18 actual ordered static/runtime29/e2e6 layers passed, source unchanged.
Full make check exit0: 8 quick PASS and521 assertions (core286 + autonomy97 +
Gherkin15 + load55 + Sentry68); two authenticated-gh load cases explicitly omitted.
Complete controller receipts and independent review are in h04/controller/.

Two nonblocking Medium findings are assigned to H05 operation/witness integration:
- H04-M1: a 191–200-character reservation key exceeds the outcome's 200-character
  bound after the internal reconciliation prefix. Permit210 for internal outcome
  keys while retaining the candidate200 limit and reserved-prefix rejection.
- H04-M2: publication verifies intervening checkpoint B against retained floor A,
  but fails to retain B before verifying successor C. Retain the already verified
  intermediate checkpoint under ownership; this needs no history-sync framework.
- Ruling: carry these concrete availability fixes into the immediately following
  H05 integration and its required test/review cycle, rather than opening another
  H04 cycle. The owner's original rule permits Medium/Low backlog, and the latest
  steering asks to avoid unnecessary work. Both findings fail closed and neither
  grants authority, resets budget or issues PASS. Cost until fixed: affected key
  lengths or witness interleavings may require an operational stop. They remain
  explicitly open and must not be described as fixed by the current GREEN suite.

Task 4 is complete locally with that explicit backlog. H05 is next after freezing
the atomic publication index. No baseline or product deployment was accepted.

Task 5: active after H04 independent approval/no High/Critical and full check521/0.
H04 indexfc084ebd is frozen for exact publication. H05 owns its capabilities plus
the two explicit Medium integration fixes; all edits stay outside the index.

Task 4: published96438e8..772f47d with exact local/remote treefc084ebd.
H05 worktree edits survived unchanged outside the index. PR33 records H01–H04
complete, H05 active, H06–H09 pending and the two Medium items still open.

H04 exact-head CI run34006151797/job101413595556: lint/Gherkin PASS;
protected-base live judge stops ADOPTION_REQUIRED, later full pipeline/claims/
decisions skipped. Exact raw log and SHA256 recorded in h04/controller/remote-ci-772f47d.*.
PR33 updated with the actual result. No rules, baseline or authority changed.

Task 5 initial frozen review tree8739edee, base772f47d: controller validated15
source and24 evidence hashes. Actual F19 static/runtime26/e2e3 layers passed29
tests with source unchanged, but independent review reproduced a High before
full integration. A registered writable output omitted from the accepted context
and adopted authority can be described, granted and written as EFFECT_VERIFIED;
only binding.documents were classified, so the extra output was never checked.
The scratch probe and exact output are preserved under h05/review-1/.
F19 remains active and its earlier test receipt is retained, not treated as
milestone completion. Full integration has not run on this initial version.
Fix round1/5: require every output in accepted context before projected proof;
capture current-test assertion RED before the bounded fix, then scoped re-review.

Task 5 fix1 frozen at tree9c6a49ac: one output-membership guard and4 new
regressions. Each recorded actual EFFECT_VERIFIED where POLICY was required
on the reviewed defective source before the fix; final static0/runtime30/e2e3
passed. Controller validated12 source+20 new evidence hashes. Old receipts
remain unchanged. Scoped independent re-review and final F19 layers are running;
first full integration follows after that High is independently closed.

Task 5 fix1 independent specification and quality APPROVED; H05-R1 addressed,
no remaining finding or fix-created blocker. Final F19 actual static/runtime30/
e2e3 layers passed33 tests, source unchanged. The H04-M1/M2 fixes were also
independently reviewed as correct. First H05 full integration is running on
the reviewed source; no full-suite result is claimed until completion.

Task 5 complete locally: full-check-01 exit0, source unchanged, stderr empty,
8 quick PASS and554 assertions (core286 + autonomy130 + Gherkin15 + load55 +
Sentry68), with two authenticated-gh load cases explicitly omitted. F19 final
ordered layers ran33 focal cases. Independent specification and quality approved;
H05-R1 High and the two carried H04 Medium findings are resolved. No open finding.
Actual subprocess containment remains BLOCKED_BY_REQUIRED_CAPABILITY/NOT_EXECUTED,
and local runtime-exclusive effects do not certify malicious same-UID isolation
or product release. All exact receipts/reviews are in h05/controller/.
H06 is next after freezing this atomic publication index.

Task 6: active after clean H05 independent re-review and full554/0. H05 publication uses frozen index cdc5681307062bd22d74bd928e200729217111f7; H06 edits are worktree-only. F20 is the sole active feature. Reuse existing capabilities, journal and verifier for approved continuation; no per-operation human signature or speculative framework.
Task 5: published772f47d..589a4e3 with exact frozen treecdc5681307062bd22d74bd928e200729217111f7; H06 worktree preserved. Remote CI run34007233246 was in progress at publication.
Ruling: H06 introduces no invented default budget — the approved grant must carry strict per-kind and total limits, fixed objective-wide and consistent with the journal total — the spec requires approved maxima; if wrong, a legitimate grant must be explicitly reissued rather than silently enlarged.
H05 exact-head CI589a4e3: run34007233246/job101416583302; lint and Gherkin succeeded, protected-live-policy failed ADOPTION_REQUIRED against base88ea1e6, later verification/claims/decisions skipped. Raw47,679-byte log SHA256efaf9721af34b1576a12db62ff4aa842d6a81c4427066842e4e3c6c5d57726eb archived under h05/controller; this is not a full CI pass.
Task 6: implementer FROZEN; static passed, runtime15/15, e2e2/2, causal RED2 failures before coverage/retry corrections. Root checked14 source and23 evidence manifest entries. Source manifest SHA2561dba863f2ebc0efad675b88ef9c2e0f20635cab65c232890cd2b19d3d63202b8; evidence manifest SHA2563fb9e1aeccf3b3d94a99f3c50dcb4be6058c1a40e8b3adf300bef2d94864d8c9. Independent review /root/review_h06 sees tree79b2a04f7950a5d9d4eaa461996476976efc1b86 against base589a4e3. F20 actual layers running; full gate waits for review.
H06 controller verify-feature-01 completed exit0 in16.401s,17 cases, source unchanged; original receipt retained. Independent reviewer then reproduced a Critical in changed authority.mjs: helper name shadows node:crypto verify, so a truthy stop object accepts invalid signatures in current and recorded approval paths. F20 reopened active; H07 and full/publication blocked until causal RED-backed fix and scoped re-review. Reviewer also identified Medium omitted/null observedDefect acceptance; complete report pending.
Task 6: independent spec ❌ and quality Needs fixes; C1 Critical verified signature bypass and M1 Medium missing public observation. Fix round1/5 dispatched to original implementer with both findings and exact exit1 probe. Focused probe SHA256b20a6bb274e0ee457094f90a10f186bb34cb4af2cdbb0d9dda172d5fa4b2e6ba; raw log SHA2563255097b3edc1fbe678f0f641e8465dd203fafbdcc674124fc6d10c6bd30f4f6; frozen authority SHA2568051f25f8e03a75f7a74dad24983ce7b2b2c43a795fb1b5400784b33896d1989. Exact artifacts archived h06/review-1. No broad rerun on defective source. Root will verify legacy claims, append-only decisions and shared signature suites through final actual gate.
Task 6: fix round1 FROZEN; five-line shipping correction for C1/M1, new8-case test file; original17-test/evidence bytes preserved. Actual RED7 failures/1 pass before fix, static pass, runtime21/21, e2e4/4. Root verified17 current source,23 fix evidence and23 prior evidence entries. Fix source-manifest SHA256dfa03a819560035b1962c88d0bec94331d701d5616b23c2f3d4f4003811ea20d. Scoped re-review sees79b2a04f..9291f6b6; actual final F20 layers running, full gate pending approval.
H06 final controller verify-feature-02 completed exit0 in17.686s with25 cases and unchanged reviewed source. F20 passing was written by the actual harness command; original17-case receipt retained. Scoped re-review and full aggregate remain required before H07/publication.
Task 6: fix round1/5 independent re-review C1 ADDRESSED, M1 ADDRESSED; spec compliant and quality Approved, no new blocking findings. Report archived h06/controller/independent-re-review-1.md. Full aggregate begins on reviewed corrected source; H07 waits for completion.
Task 6: complete locally; both independent verdicts approved after fix1, no open findings. Actual final25-test F20 static/runtime/e2e receipt and full-check-01 exit0 in90.188s with8 quick PASS and579 assertions (286core+155autonomy+15Gherkin+55load+68Sentry); two authenticated-gh load omissions explicit. Reviewed source unchanged, stderr empty. Full aggregate includes H03/H04/H05 shared signature rejection. Root checked14 original claims/receipts against audit9ee4eaa with only F09 blocked, exact DECISIONS prefix and shipping whitespace; reviewer cross-task questions resolved by these actual checks. H07 next; no external review/containment/production acceptance claimed.
Task 7: active F21 after H06 clean review and full579/0. H06 publication uses frozen index2bd8f826d14152f336abbe2443366336333c6f33; H07 edits worktree-only. Existing Codex0.153.4 protocol and truthful unsupported containment/account acceptance boundaries are in the task brief; no retry of cancelled authenticated preflight.
Task 6: published589a4e3..19851a2, exact frozen tree2bd8f826d14152f336abbe2443366336333c6f33. H07 worktree edits preserved; CI observation pending.
Ruling: H07 may use fixed pinned trusted Git object plumbing to construct an exact isolated shadow, with clean environment/config and no hooks/filters/credentials/lazy fetching or replacement-object influence — this is a closed host helper, not candidate program execution; if wrong, object acquisition must stop rather than widen command access. Untrusted reviewer/counterexample execution still requires real supported containment.
H06 exact-head CI19851a2: run34008025046/job101418707321; lint/Gherkin pass, protected policy ADOPTION_REQUIRED against88ea1e6, later verification/claims/decisions skipped. Exact raw log and SHA metadata archived h06/controller/remote-ci-19851a2; PR metadata updated. No CI full-pass claim or bypass.
Ruling: H07 missing-capability preflight stops before review-budget spending — known unavailable containment means no review attempt has begun; debit only immediately before supported execution, reusing H06 spendBudget — if wrong, preflight requests are not counted as billable review rounds, but remain explicit diagnostics. Do not add a hypothetical backend merely to exercise reservation. This build produces no authenticated independent-review evidence or successful-review handle.
Task 7: portable preparation/refusal FROZEN;3 modules, no live launch/receipt-minting backend. Reported runtime28 includes3 e2e; no inflated31-case count. Actual High primary __proto__ manifest omission witnessed RED before fix using exact current test; earlier deliberate mutation experiments remain explicitly separate. Root verified9 source,21 top evidence,17 causal source and current test/log bindings. Source manifest SHA256116ee8602c2394f10dbf5b27ca499e933dfdb84bfb0767aecc7a77f95eabb7ad; evidence manifest SHA25667c1010073ba49cc1c2f1e9e252f672d4f16c7b5052b2266682216afb462bbbf. Reviewer /root/review_h07 sees tree3998ad0a against19851a2. Actual distinct F21 layers25runtime+3e2e running; full gate after independent review.
H07 controller verify-feature-01 exit0 in34.271s, exact distinct25runtime+3e2e, reviewed source unchanged and stderr empty; F21 passing written by actual command. Reviewer noted worker static-final.log is empty despite a current script PASS line. Preserve that historical discrepancy; current controller stdout lines3–10 execute the exact static command and include PASS, SHA256ef41457825dd45a2e7f9e1f3a1676f496da0d477c9847dd9f852d2e6a4d81c27. Present static verification is supported by this actual receipt, with no rerun or alteration of earlier logs.
Task 7: independent spec and quality approved for portable preparation/refusal, no blocking findings. Low historical static-log discrepancy retained; current controller receipt closes present verification uncertainty. Real adapter/backend acceptance remains NOT_EXECUTED; H08 can consume no authenticated review output. Full integrated gate starts; H08 waits for actual completion.
H07 publication packaging: removed2,126 generated dependency files and the earlier external dependency symlink from the index only; original worktree bytes and every source/evidence manifest entry preserved. Local h07 ignore prevents accidental vendoring. README records pinned npm-ci setup, exact actual-RED command and historical static-log discrepancy/current receipt. This is publication hygiene, no shipping source/test change or re-run. Shipping whitespace now passes; failed first check reflected upstream dependency whitespace, not a source defect.
Task 7: portable preparation/refusal complete locally; independent approved with Low historical-log note clarified in README/current receipt. Full-check-01 exit0 in88.490s, reviewed source unchanged, stderr empty,8 quick PASS and607 assertions (286core+183autonomy+15Gherkin+55load+68Sentry); two authenticated-gh omissions explicit. Original real-session H07 acceptance is still NOT_EXECUTED and launch/receipt backend unimplemented. H08 obligation to consume zero diagnostic review outputs is carried explicitly in its brief; future real-backend checks remain explicit delivery limitations. Root historical-state/decision-prefix/whitespace checks passed after excluding generated dependencies.
