# H05 fix round 1/5 — accepted output membership

Addresses the single confirmed High H05-R1 from independent review of frozen
index tree `8739edeed87e427a1f8260c02313c9f6df2fc887`, based on published H04
`772f47da8a96335346a126481fd11590126d75cb`. No unrelated fixes or expansion.

The bounded patch adds one membership check for each computed output before the
complete projected classification. Both members of the derived batch must occur
in the exact accepted binding. H04 already makes this the exact H03 context, and
H03 already restricts that context to adopted scope. A signed bounded grant cannot
replace acceptance or expand adopted scope. The capability contract now states
this requirement explicitly. No new authority API or dependency is introduced.

Four new focal cases cover: registered canonical output lacking accepted-before
identity; canonical output outside adopted scope; omitted derived target with an
accepted source; and derived source/target outside adopted context. Each first
confirms direct H03 classification of the omitted output is UNKNOWN. On the
reviewed defective source it then obtains a real exact fixture grant and valid
lease, performs the filesystem effect and observes EFFECT_VERIFIED where POLICY
is required. On fixed source, description/preparation return POLICY, workspace
bytes stay unchanged, spend stays0, pending stays empty and no intent/receipt is
created. The existing accepted source/digest positive workflow still executes.

`source-before-membership/` preserves the reviewed shipping implementation once,
with the final33-test file and pinned package/lockfile. `live-red.log` observes
four real assertion failures before the source fix. `reproduce-red.sh` recreates
that source in one temporary directory with the existing installed dependencies;
`causal-red.log` also observes4 failures / exit1. `red-receipt.json` binds this
reproduction command, exact current test bytes, preserved source and raw log.
Initial H05 evidence/snapshots/receipts remain untouched; all24 original evidence
manifest entries were checked unchanged. AC-H05 now points to this new receipt.

| Layer | Exact command | Result |
| --- | --- | --- |
| Static | `bash docs/implementation/2026-09-05-harness-hardening/h05/verify-static.sh` | exit0, five syntax checks |
| Runtime | `node --test --test-skip-pattern='e2e:' packs/autonomy/repo-template/scripts/quality-orchestrator/tests/capabilities.test.mjs` | exit0,30/30 |
| E2E | `node --test --test-name-pattern='^e2e:' packs/autonomy/repo-template/scripts/quality-orchestrator/tests/capabilities.test.mjs` | exit0,3/3 |

Current test SHA256: `95ed2f3d23416629e8226ffbdd15cb28139e83b7abbe588a6d52e7ff03db291b`.
Current capability source SHA256: `e14232dae9798664105f994353596fbf047201e2a2212ceee5e98dfd886f2d54`.
Source manifest SHA256: `00b9ae7e546e11e2e86a8ac1a51b0f2f6cc640898b8d088ca2dafce92e2b02a8`.
New RED receipt SHA256: `0b3418ef5922117bebf7e28e553b1c6953526a213bd3d070d7c52f9f27d75c49`.
Causal log SHA256: `64ec23a2ec03433d1e98bb2fef25dce141dde11cf0b6243c0efd4fbeb92e6a0b`.

No full repository suite, index/ref/commit change, agent, network, adoption,
external account action or deployment. Root retains independent review, source
index, feature/state/ledger and broad integration. Local cooperating-writer and
unavailable real containment limits are unchanged. No fixture certifies a real
host trust channel or malicious subprocess containment.

FROZEN for independent re-review; further changes require a concrete finding.
