### Spec Compliance

- ✅ **Spec compliant for the scoped C1/M1 correction.** Both assigned findings are ADDRESSED; no new blocking breakage appears in the fix diff.
- ⚠️ H03/H04/H05 aggregate verification and root-owned feature/history/publication gates remain controller-owned and outside this re-review. This approval does not assert those gates passed.

### Finding Verdicts

- **C1 — Critical — ADDRESSED.** `packs/autonomy/repo-template/scripts/quality-orchestrator/authority.mjs:45,53,62–63`: renaming the shared helper to `verifyEnvelope` makes the signature expression resolve to the imported `node:crypto` verifier again. Both current and recorded approval paths dispatch through that same corrected helper. No signature format, approval kind, pinned issuer or event-time behavior is expanded.
- **C1 evidence:** `tests/continuation-authority.test.mjs:15–37` covers fabricated signatures, genuine signatures, altered signed fields, all six approval kinds and historical/current freshness separation. Lines 57–71 exercise public forged-grant refusal before registration and recorded forged-grant refusal after journal content/request hashes have been recomputed. These tests reach the actual authority/runtime/journal paths and distinguish signature rejection from a hash mismatch.
- **M1 — Medium — ADDRESSED.** `packs/autonomy/repo-template/scripts/quality-orchestrator/continuation.mjs:60–64`: the public entry point now unconditionally parses the required strict observed-defect object before verification or journal append. Internal observation-free revalidation remains available only through its existing private flow. `tests/continuation-authority.test.mjs:51–56` checks both undefined and null rejection, unchanged replay state, and successful subsequent evaluation with a valid observation.

### Strengths and Evidence

- The five-line shipping correction directly fixes the two causes without introducing an additional verifier, capability or workflow abstraction (`authority.mjs:45,62–63`; `continuation.mjs:61–62`).
- Actual pre-fix causal evidence is retained: `docs/implementation/2026-09-05-harness-hardening/h06/fix-1/causal-red.log:1–16` reports 7 failures / 1 pass, and the detailed assertions show fabricated current/recorded signatures accepted, missing/null observations accepted, forged registration accepted and forged replay reported REPLAYED. `fix-1/red-receipt.json:7–13` binds exit 1, the exact new current test and the previously reviewed authority bytes. The retained authority SHA256 is the same `8051f25f8e03a75f7a74dad24983ce7b2b2c43a795fb1b5400784b33896d1989` identified in the initial review.
- Read supplied final evidence: `fix-1/final-static.log:1` reports syntax success; `fix-1/final-runtime.log:1–29` reports 21/21 passes, including the original 15 runtime cases; `fix-1/final-e2e.log:1–12` reports 4/4 passes, including original signed local writes/reuse/reconciliation. No warning noise is present. Tests were not rerun.
- Root reports verification of 17 current source hashes, 23 fix evidence hashes and all 23 prior evidence entries unchanged. This re-review inspected the supplied logs and receipt without duplicating that manifest verification.

### Issues

- **Critical:** none remaining from the assigned findings or introduced by the fix diff.
- **High:** none found in the fix diff.
- **Medium/Low:** no new findings within the correction scope.

### Assessment

**Task quality: Approved for the scoped correction.**

**Reasoning:** C1 now invokes real cryptographic verification on both paths, and M1 now rejects absent public observation before mutation. Focused causal RED and subsequent runtime/e2e evidence cover the failures and preserve the original H06 behaviors; the controller may proceed to its required aggregate/state/history gates.

- **Review scope:** previous tree `79b2a04f7950a5d9d4eaa461996476976efc1b86` → current tree `9291f6b60f1fdd0cf8e331ff9eb0089be197741f`; task-6 brief, fix-1 report, fix-only shipping diff and exact reported evidence. No source/index/ref changes, external actions, additional agents, probes or suite reruns.
- **Unresolved cross-task checks:** H03/H04/H05 full integration and controller publication/history verification only; no additional fix-specific unanswered risk remains.
