# H06 review fixes C1 / M1 — round 1/5

Both assigned findings are fixed with a bounded five-line shipping change.
The shared envelope helper is now `verifyEnvelope`, so its cryptographic call
resolves to `node:crypto`'s `verify` instead of recursively returning a truthy stop
object. Current and recorded paths still use the same helper, signature format,
pinned issuer and existing freshness/event-time rules. Public
`evaluateContinuation` parses required `{gateDigest,path}` before shared validation;
missing/null inputs cannot use the internal observation-omitting path.

The eight-case `continuation-authority.test.mjs` is new. Original17-test bytes and
all23 original evidence-manifest entries are unchanged. Current-source RED ran
before either shipping change: exit1, seven assertion failures. Exact reviewed
source, new test/helper/package bytes and live log were preserved once, and the
snapshot reproduction again observed exit1 / seven failures. These include actual
current and recorded fabricated-signature acceptance, altered signed fields,
missing/null observed defects, public forged-grant registration, and journal replay
of a forged grant with content/operation hashes recomputed. No artificial mutation
or missing-API failure substitutes for this evidence.

The shared rejection cases exercise all six existing approval kinds; valid
signatures still succeed, while historically valid expired receipts stay distinct
from current authority. The independent review probe/log outside the checkout
remain untouched. The new critical AC-H06-authority oracle and governed Agent Note
record the defect and current-byte receipt; original AC-H06 remains unchanged.

Executed commands and observed outcomes:

- Static: `bash docs/implementation/2026-09-05-harness-hardening/h06/fix-1/verify-static.sh`
  → exit0; changed authority/continuation modules and new focal test syntax.
- Runtime: `node --test --test-skip-pattern='e2e:' packs/autonomy/repo-template/scripts/quality-orchestrator/tests/continuation-authority.test.mjs packs/autonomy/repo-template/scripts/quality-orchestrator/tests/continuation.test.mjs`
  → exit0,21/21. Includes all original15 runtime cases on the corrected verifier.
- E2E: `node --test --test-name-pattern='^e2e:' packs/autonomy/repo-template/scripts/quality-orchestrator/tests/continuation-authority.test.mjs packs/autonomy/repo-template/scripts/quality-orchestrator/tests/continuation.test.mjs`
  → exit0,4/4. Forged registration and recorded replay reject; original signed
  leased effects, fresh-run reuse and exhausted reconciliation remain verified.
- Causal RED: `bash docs/implementation/2026-09-05-harness-hardening/h06/fix-1/reproduce-red.sh`
  → observed exit1,7 failures / 1 pass on preserved reviewed source.

SHA256:

| Artifact | SHA256 |
| --- | --- |
| authority.mjs | `7facc38c306d2f469de8a67cc48aaaf14c58d93bbb10b744a111716f10e078ed` |
| continuation.mjs | `939c95db08dcb8235311ad3e621bc448618f1a50bd815b660e91c02d480eb8e2` |
| New focal test | `c92ab95f4f48c537fc7f7b9b0f73352248bf7931527920658505f128ed157973` |
| source-manifest.json | `dfa03a819560035b1962c88d0bec94331d701d5616b23c2f3d4f4003811ea20d` |
| red-receipt.json | `c120a51990b82b96c93c20eadda51d059f5550a4d1e5e1ba42efa8a5b0357a36` |
| causal-red.log | `ce0190790100593127be386975d9d8d99a3c76ab1263f7c24f30ebfc90a31d69` |
| final-static.log | `1b68f95789462e848ea77574b2f491c8645703f5e11c3532b5e85f95cd584539` |
| final-runtime.log | `415233a7091e7e0346f8aaa59ccff7ca2ca702896de0659adbab76847a5d027b` |
| final-e2e.log | `a2110746e74e6898eec3d3264a71d4538710c6e6fe48cec1262ab44493f0d153` |

No known remaining assigned finding. Root owns scoped independent re-review,
H03/H04/H05 aggregate verification, feature state and publication. This worker
performed no full/startup suite, index/ref/commit change, account/network action,
new capability, baseline acceptance or deployment. Real authority custody,
subprocess containment and product/release acceptance retain the prior explicit
limitations. Original passing receipts remain historical evidence, not authority
to skip the C1 correction and root's fresh aggregate verification.

FROZEN. No further edits until a concrete fix dispatch.
