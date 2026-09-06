# H07 evidence and reproduction

The actual security RED is prototype-red.log and red-receipt.json: the
unchanged current test witnessed a primary __proto__ file omission on the
preserved source before its null-prototype map correction. Deliberate mutation
experiments and missing-API failures are labeled separately in the implementer
report and do not supply that security receipt.

Installed dependencies are generated setup, excluded from Git. Each snapshot
retains the same pinned package.json/package-lock.json. To reproduce the actual
RED from a fresh checkout with Node>=22 and an available registry/cache:

```bash
npm ci --prefix docs/implementation/2026-09-05-harness-hardening/h07/prototype-red-source --ignore-scripts --no-audit --no-fund
node --test --test-name-pattern=prototype-shaped docs/implementation/2026-09-05-harness-hardening/h07/prototype-red-source/tests/review.test.mjs
```

The recorded result is exit1 with one assertion failure and one pass. Preserve
the snapshot and test bytes; inability to install dependencies is an environment
failure, not RED. No lifecycle scripts or Codex/account operations are needed.

The worker static-final.log is historically empty despite its report naming the
current script, which prints a PASS line. The current controller verification
in controller/verify-feature-01.stdout.log lines3–10 records actual syntax/lint
execution and that PASS; its result JSON records exit0 and source freshness.
The discrepancy and original bytes remain visible.

There is no live reviewer, containment or authenticated review receipt backend.
Fixture/local contract success never satisfies real independent review.
