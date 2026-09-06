# H05 implementer report — FROZEN

Base HEAD: `772f47da8a96335346a126481fd11590126d75cb` (published H04).
H05 worktree only. No index/ref/commit edits, subagents, broad suites, external
account operations, baseline/adoption acceptance or deployment.

Implemented one cohesive `capabilities.mjs` using existing Node/fs/crypto/Zod and
the existing runtime/journal. Two closed operations: canonical record write and
one canonical-source + registered-digest batch. Host-pinned actual implementation,
Node executable/dependencies and runtime config bind every exact plan. Opaque
contexts/grants/permits/leases, exact deny-winning paths, conservative alias/mode
checks, complete projected preconditions, exclusive durable fencing and exact
postmanifest checks separate preparation from completed actual effect evidence.
Intent precedes budget reservation and publication; supervised receipts precede
journal outcomes. Reopen and retry reconcile exact final bytes without repeating
writes. Unsupported subprocess capability returns BLOCKED_BY_REQUIRED_CAPABILITY
and NOT_EXECUTED before any spawn.

Two causal defects were reproduced and fixed:

1. Preparation classified only direct outputs, permitting a canonical-only write
   that would invalidate an accepted dependent digest. Complete projected final
   documents are now checked before preparation. The closed source/digest batch
   remains usable when both paths are exactly authorized.
2. High: H04 generic target reconciliation could settle H05 local intent using an
   unrelated target response. Runtime-created reservations now durably record
   private `effectKind:'local-capability.v1'`; candidate append rejects the field,
   and generic reconciliation refuses such intent even when reopened without the
   capability API. Only actual H05 postcondition reconciliation settles it.

Assigned H04 Medium fixes also implemented: outcome-only key bound210 while
candidate bound200/reserved-prefix rules remain; authenticated intermediate
witness B retained under ownership before successor C publication. H03/H04 tests
and prior sealed evidence were not changed.

One preserved relevant source snapshot, exact final test bytes and raw causal
log observe three assertion failures (precondition, same-runtime crossover,
reopened crossover), exit1. Initial absent-API RED is labeled development only.
All H05 test bytes remain exact after that final preserved-source falsification.

Actual layer commands and results:

- Static: `bash docs/implementation/2026-09-05-harness-hardening/h05/verify-static.sh`
  → exit0, five runtime/integration/test syntax checks.
- Runtime: `node --test --test-skip-pattern='e2e:' packs/autonomy/repo-template/scripts/quality-orchestrator/tests/capabilities.test.mjs`
  → exit0,26/26.
- E2E: `node --test --test-name-pattern='^e2e:' packs/autonomy/repo-template/scripts/quality-orchestrator/tests/capabilities.test.mjs`
  → exit0,3/3 actual public workflows: source/digest publication+reopen,
  partial unexpected frozen delta refusal, complete publication crash
  reconciliation with zero repeated workspace publication.
- One full focal file run also passed29/29. No full make check rerun; root owns
  broad integration once after independent review/freeze.

Evidence directory: `docs/implementation/2026-09-05-harness-hardening/h05/`.
Exact hashes:

| Artifact | SHA256 |
| --- | --- |
| final H05 test bytes | `4522ae0692f1fad6e5d197584286ef058b00a619abe1dc5e8ad3b34944ecdcc1` |
| source-manifest.json | `ff15b7f61e477b6aa991e75a1fb61b7c278612b7d66051fe241cf6f8e5de37a1` |
| evidence-manifest.json | `a331818b30bc8f92669f59abedcad6261fe14c9c13eab325ac7ecdb18d7bd8e8` |
| red-receipt.json | `2f8c80f5022a5ba2dda050e0862f480868eed7896b6ce9ed2f412b6294f7f4b3` |
| final-static.log | `475336c0d901ea82f37358ecdf7ed6598dd054ae86569a210f39cf139720ee06` |
| final-runtime.log | `224d6c2dfcc90ea1175bb0c0c729d937c169daa941909b53153dc261df882dff` |
| final-e2e.log | `376709b85e20f9f9fe269fd6bd0e0361ff8209f3890986f3c14805bb88fe7587` |
| causal-red.log | `30fde7ea486d7a78937b51a3e6747069ee7c3db6a81756de3976f1bf6796aabf` |

Owned changes: capabilities module and test, current runtime classify/index/journal
integration, capabilities contract, pack index, module quality row, AC-H05 oracle,
one governed Agent Note, H05 evidence and this report. Source manifest records
exact final relevant source/doc bytes; evidence manifest binds all evidence files.

Limits: trusted runtime-exclusive cooperating writers only. Portable filesystem
checks cannot contain a malicious same-UID concurrent process. Partial multi-file
effects or interrupted ownership can require operator investigation; no automatic
repair or atomic batch promise. Actual malicious subprocess/network/secrets/fd/
orphan containment and real external issuer custody are NOT_EXECUTED; fixtures
certify local contract handling only. No new dependency, command/plugin framework,
service, bypass flag or process-groups-as-sandbox fallback. No auth/telemetry retry.
Event/runtime bindings advance explicitly; old journal bindings are not silently
rewritten or retrospectively certified. Root owns remaining feature state,
independent review, full check, ledger, decisions and publication.

FROZEN. No further source/test/evidence edits unless root requests a concrete
review fix.


# H05 fix round 1/5 — FROZEN again

The complete original report above is preserved byte-for-byte as the prefix
(SHA256 bb16026328791c5b8504a814f2ac2be740c9ef9f0de927dce238f8fcb6af563d).
Independent review of tree8739edeed87e427a1f8260c02313c9f6df2fc887 found one
High H05-R1: registered writable outputs omitted from the accepted binding could
bypass H03 projected classification/adopted scope and receive EFFECT_VERIFIED.

One membership guard now requires every computed output, including both derived
batch members, to occur in the accepted binding before projected classification.
No broader API, dependency or scope change. The capability contract states that
a bounded grant cannot replace accepted-before proof or expand adopted scope.

Four new exact regression cases exercised actual granted, leased effects on the
reviewed source and each observed EFFECT_VERIFIED instead of POLICY. One current
defective-source snapshot and exact final33-test file are preserved under
`docs/implementation/2026-09-05-harness-hardening/h05/fix-1/`; its reproduction
observes4 assertion failures / exit1. Prior snapshots/receipts are unchanged, and
AC-H05 points to the new current-test receipt.

Fresh final commands:

- Static: `bash docs/implementation/2026-09-05-harness-hardening/h05/verify-static.sh` → exit0.
- Runtime: `node --test --test-skip-pattern='e2e:' packs/autonomy/repo-template/scripts/quality-orchestrator/tests/capabilities.test.mjs` → exit0,30/30.
- E2E: `node --test --test-name-pattern='^e2e:' packs/autonomy/repo-template/scripts/quality-orchestrator/tests/capabilities.test.mjs` → exit0,3/3.

Exact fix-1 hashes:

| Artifact | SHA256 |
| --- | --- |
| current test | `95ed2f3d23416629e8226ffbdd15cb28139e83b7abbe588a6d52e7ff03db291b` |
| current capabilities.mjs | `e14232dae9798664105f994353596fbf047201e2a2212ceee5e98dfd886f2d54` |
| report.md | `7d9ad28ad4f8bba61cd3418fd724b7110e3808e6b86f097c8c68c45a838d61af` |
| source-manifest.json | `00b9ae7e546e11e2e86a8ac1a51b0f2f6cc640898b8d088ca2dafce92e2b02a8` |
| evidence-manifest.json | `8b313117c93e1f4c6bcfbe2a6a33f3151e74db91301cb2b2593a210df4e1a839` |
| red-receipt.json | `0b3418ef5922117bebf7e28e553b1c6953526a213bd3d070d7c52f9f27d75c49` |
| causal-red.log | `64ec23a2ec03433d1e98bb2fef25dce141dde11cf0b6243c0efd4fbeb92e6a0b` |
| final-static.log | `475336c0d901ea82f37358ecdf7ed6598dd054ae86569a210f39cf139720ee06` |
| final-runtime.log | `9fd2ec8d898ee8ff15ec413efdc14f1487208a9af1dd21e1ff556a30777f17d1` |
| final-e2e.log | `5ff1c0d919efd997b6e2803d8b7a2b3d62b1e825569058a349aa54fdde080197` |

All12 current source-manifest entries and all fix evidence-manifest entries were
checked by exact SHA256. All24 original evidence-manifest entries remain unchanged.
No full repo suite, index/ref/commit, agent, network, adoption or deployment.
Subprocess containment remains BLOCKED_BY_REQUIRED_CAPABILITY / NOT_EXECUTED.
Root owns independent re-review, feature state, broad integration and publication.

FROZEN. No additional edits until a concrete review finding is assigned.
