# H08 evidence — portable release obligations

Review base: c8988acc87a18441e310e8f78e9015b3107d9341 (tree d0db2152be4e82526a7e58f5fc9d28f7d9f0c52a).
Shipping contracts are in packs/autonomy/repo-template/scripts/quality-orchestrator/contracts-release-v1.md.

Current verification: static exit 0 (five syntax checks and tracked-diff whitespace);
focused runtime 26/26, exit 0; local e2e 2/2, exit 0. Full check, independent review
and publication are root-owned. No production acceptance claim follows.

The experiment recorded by `mutation-receipt.json` is classified here and in
AC-H08 as a **MUTATION_EXPERIMENT**: after initial
implementation, only an isolated snapshot's exact receipt-binding guard was
removed. The exact current test bytes produced seven assertion failures, with
19 passes and exit 1. This proves test strength, not causal pre-fix RED for a
discovered prior High/Critical defect. Shipping code was never mutated.

`feature-red.*` is the initial absent-API feature test, not a safety witness.
`initial.*` records the earlier 24-test version. `focused-pre-falsification.*`
records the final 26-test version before the isolated mutation. The first
`mutation-setup-failure.*` attempt could not start tests because a dependency
symlink correctly violated the existing bundle guard; it proves no release
safety criterion. The subsequent mutation run used a local temporary dependency
copy and produced actual assertion failures. Those generated dependencies were
removed and are not evidence source or files to stage.

Reconstruct the sole preserved mutation package with Node >=22 using its pinned
package-lock.json (`npm ci --prefix docs/implementation/2026-09-05-harness-hardening/h08/mutation-source --ignore-scripts --no-audit --no-fund`; use `--offline` only with a populated cache).
Then from the repository root run:

```
node --test docs/implementation/2026-09-05-harness-hardening/h08/mutation-source/tests/release.test.mjs
```

Expected: exit 1; seven binding assertion failures. Do not stage generated
node_modules. Both Node/runtime and dependency custody remain host assumptions.
The receipt and manifests establish local content consistency, not authenticated
execution, independent review or protected history. Node used: v24.19.0.

The same evaluator serves explicit simulation and runtime decisions. Runtime
has no authenticated release receipts and always refuses production completion.
Known unavailable deploy/rollback/reconciliation performs no external operation
or budget reservation. Positive production scheduling, real target adapter,
authenticated receipt import/issuance and live rollback invalidation are
**unimplemented**. Real production acceptance/deploy/smoke/observability/rollback
are **NOT_EXECUTED**, and H07 supplies zero authenticated review evidence.

Independent review approved the portable scope with no blocking findings.
Its Low wording note is clarified here: the preserved JSON receipt contains
command, exit and hashes; the mutation-versus-causal-RED classification is in
this README and AC-H08, not a field in that JSON. The original implementer
report and receipt bytes remain unchanged.
