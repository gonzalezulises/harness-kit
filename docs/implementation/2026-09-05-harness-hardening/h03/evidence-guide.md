# H03 evidence map and reconstruction

The source base is the working tree after H02's reviewed index tree53290b4a99f2d3d0aab25d1eb4510344dda26678.
Git HEADfff527b2c7a64fb6d70d60d633a0261e68315169 was a history anchor during H02
publication, not an attribution of new source to that commit. No H03 index/refs
or commits were created. The final SHA256 manifest identifies actual bytes.

requirements-first/ retains the initial oracle and all requirements tests before
runtime source. capability-absence logs are missing-module errors, not causal
semantic RED. first-executable-source/ is the first complete executable source;
first-executable logs include a fixture mismatch (ordinary JSON where authority
requires canonical JSON) and attempts to sign invalid envelopes through a strict
production helper. Fixtures were corrected to canonical bytes and independently
signed raw envelopes before derived-red. These errors are not semantic bypass
RED. The helper's only generated keys are ephemeral test fixtures.

Each named `*-red-source/` retains all package source/lock/tests as they existed
for that observed run, excluding node_modules. All stdout/stderr logs are exact,
including original whitespace and empty stderr streams. Commands for each early
unit stream were `node --test --test-reporter=tap <runtime>/tests/*.test.mjs`,
except capability-absence and first-executable which used the default reporter.
The runtime path is packs/autonomy/repo-template/scripts/quality-orchestrator.
Early shell wrappers reported the actual test exit before continuing; none of
their own successful wrapper exits are claimed as a successful failing test.

- derived-red:44 tests,43 pass,1 assertion failure; derived-green:44/44.
- order-red:50 tests,49 pass,1 assertion failure. The next comments-red run shows
  the fixed ordering test passing; its own new comment assertion fails.
- comments-red:51 tests,50 pass,1 assertion failure; comments-green:51/51.
- runtime-binding-red adds the explicit runtime/schema binding to authority
  fixtures before implementation. Existing valid-authority assertions fail
  because that new field is not supported yet. This is capability development,
  not an observed forged-signature bypass. runtime-binding-green:52/52.
- clock-red:53 tests,52 pass,1 thrown runtime error from the trusted-clock failure.
  clock-green:53/53. The final test uses assert.doesNotThrow so the exact current
  regression appears as an assertion failure in final-red.
- numeric-type-red:54 tests,53 pass,1 assertion failure (YAML mapping impersonates
  numeric domain object); numeric-type-green:54/54.

final-falsification-source/ is an explicit reconstruction of preserved actual
pre-fix module versions, not a commit snapshot: identity.mjs comes from
comments-red-source, classify.mjs from derived-red-source, authority.mjs from
clock-red-source, and index/lock/tests from the final current package. Each module
origin is preserved separately and hash-checkable. This reconstructs the real
missing derivation, locale order, comment erasure, numeric type confusion and
clock-failure regressions together without a synthetic favorable or negative
stub. final-red runs the exact final current tests against those module bytes:
54 tests,48 pass,6 assertion failures. The sixth is the adverse derived-source
case that also detects the incomplete original derivation. Final GREEN is54/54.

red-receipt.json binds the exact current four test/helper files, every byte of
the reconstructed source/lock/tests, actual argv, exit1 and both complete final
RED streams. final-red.command.json and final-green.command.json record actual
argv/exit/log hashes. A private temporary node_modules symlink supplied the one
installed pinned package during reconstruction and was removed afterward. No
node_modules or synthetic runtime code is preserved as evidence. To reproduce,
copy a source snapshot into a new temporary directory, run `npm ci --ignore-scripts
--no-audit --no-fund` there (or `--offline` with populated cache), then run
`node --test --test-reporter=tap tests/*.test.mjs`. Preserve new output under a new
label; never overwrite these captured streams. capture-final.py refuses to
replace existing final evidence.

integration-commands.json records a fresh copied package with no node_modules:
verifier exit69 before setup, npm ci --offline exit0 using the integrity lock,
consumer tests54/54, the exact unchanged consumer root package hash, and shipped
verify-pack exit0. The canary's temporary paths are intentionally transient; the
copy relationship and commands are recorded. Dependency installation succeeded;
its ambient npm http-proxy deprecation warning remains in stderr and is not
silenced. Missing dependency failure is expected TOOL_FAILURE, not a test PASS.

static-check.commands.json records ShellCheck0.11.0, Bash syntax and node syntax
exit0 for every shipping module/test. oracle-check and notes-check record actual
local gate execution exit0. Local receipts establish byte consistency, not
independent authority. Parent controller owns independent review, feature state,
full make check, publication and external acceptance. None is inferred here.
