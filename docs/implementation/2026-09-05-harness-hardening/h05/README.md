# H05 implementation evidence

Base: `772f47da8a96335346a126481fd11590126d75cb`. Worktree-only H05 change;
no index, commit, external account, adoption or deployment operations.

The closed canonical and source/digest batch capabilities now bind a scoped
signed grant, opaque permit, actual runtime/dependency bytes, exclusive fenced
lease, current run/head and complete before/expected-after workspace. They record
exact durable intent before reserving objective spend and publishing bytes. Only
an independently checked complete postmanifest can produce the local effect
receipt and its journal outcome. Pending or partial effects do not repeat.

Causal discovery and fixes:

- Complete projected-document validation was absent: canonical-only preparation
  could leave an accepted dependent digest stale. The canonical+derived batch
  remains supported; insufficient single-path changes now stop before effects.
- High: generic target reconciliation could settle a local capability with an
  unrelated target response, bypassing the actual supervisor postcondition path.
  Runtime-only persistent intent provenance now closes that route, including when
  the journal is reopened without configuring the capability API.
- Assigned H04 Medium fixes: internal outcome key capacity210 (candidate remains
  200 and reserved-prefix protected), and authenticated intermediate witness B is
  retained under ownership before publishing successor C against an earlier A.

`source-before-precondition/` is the one preserved relevant defective source
snapshot, with exact final test bytes. `reproduce-red.sh` reconstructs it in one
temporary directory using the existing pinned dependencies, runs the three causal
assertions, and removes that temporary copy. `causal-red.log` observes 3 assertion
failures / exit1. `red-receipt.json` binds that command, exact current tests,
snapshot and raw log. This is local content-consistent evidence, not independent
external authentication. `initial-red.log` is only missing-API development
 evidence; it does not certify a security falsification. Other development logs
are intermediate observations; the final layers below are authoritative here.

| Layer | Exact command | Observed result |
| --- | --- | --- |
| F19 static | `bash docs/implementation/2026-09-05-harness-hardening/h05/verify-static.sh` | exit0, five syntax checks |
| F19 runtime | `node --test --test-skip-pattern='e2e:' packs/autonomy/repo-template/scripts/quality-orchestrator/tests/capabilities.test.mjs` | 26/26, exit0 |
| F19 e2e | `node --test --test-name-pattern='^e2e:' packs/autonomy/repo-template/scripts/quality-orchestrator/tests/capabilities.test.mjs` | 3/3, exit0 |

The full focal file also ran29/29 (`full-focal-green.log`); the separate commands
exercise actual public workflow publication, persistent reopen reconciliation,
and refusal after partial unexpected frozen mutation. The restart case uses real
filesystem data and runtime reopening; failure injection wraps Node rename only
inside tests to stop precisely after a real publication. Host signing/witness
channels are fixtures. No test helper is exported as production authority.

No broad integration was repeated; root owns independent review, feature state,
full `make check`, ledger and publication. Earlier H03/H04 test bytes and receipts
remain unchanged; `prior-tests-unchanged.log` records the current/base comparison.
`source-manifest.json` binds final owned source/contracts/tests/docs; evidence
hashes bind the preserved snapshot and logs.

Actual malicious subprocess containment, inherited descriptors, secrets, network,
orphan escape, login/review session and deployment acceptance are NOT_EXECUTED.
The unsupported subprocess route is BLOCKED_BY_REQUIRED_CAPABILITY before any
spawn. Portable Node path checks and cooperating exclusive leases do not confine
a hostile same-UID process. No configured real containment backend was substituted,
no rejected/cancelled external operation retried, and no fixture was promoted to
real acceptance. Local partial effects and interrupted leases require operator
investigation; there is no automatic repair or multi-file atomicity claim.
