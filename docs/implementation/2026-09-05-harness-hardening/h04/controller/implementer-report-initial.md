# H04 implementer handoff — FROZEN

Status: **FROZEN**. Worktree edits only; no index/ref/commit, adoption, baseline
acceptance, external account or deployment operation. H03 base is
`96438e86b3d671027c8398b8c10edbb994e8ee59`. Root owns review, broad gates and F18 state.

## What changed

One cohesive `journal.mjs` extends operator-only `openRuntime(host.journal)`.
Closed event/run/witness contracts, exclusive objects and lock ownership,
sequence/hash chain, head CAS, deterministic replay and idempotent operations
preserve objective spending. Strong replay fetches and verifies latest scoped
signed checkpoint through the existing H03 Ed25519 boundary and retained witness
floor. External witness publication uses host CAS transport and verifies signed
response plus a fresh readback. No callback determines verification.

Fresh runs re-read complete final workspace bytes/commit, classify against the
original opaque accepted context and reverify every replayed run. Old verdicts
remain immutable and original baseline authority/budget survive. H04 supports
only OPEN/STALE/FAILED/INCOMPLETE, no PASS or executable permit. Pending intent
requires the same target idempotency key; UNKNOWN cannot repeat effects. Actual
SIGKILL testing retains budget/intent and lock, then scoped signed dead-PID
recovery repairs HEAD. Torn tails remain INCOMPLETE, never silently truncated.

Legacy import retains exact original bytes, projects `blocked` plus
`LEGACY_UNVERIFIED` with provenance, and remains compatible with existing ratio
reading. A small root/full-template `verify-feature.sh` guard rejects direct
writers before effects when `.harness/autonomy-v2.json` exists. H09 owns marker
installation/protected adoption. Unadopted legacy behavior remains unchanged.

Compatibility: H03 source adds only optional journal construction, one export
and closed journal-checkpoint receipt kind. No H03 tests or receipts changed;
no new dependency/package/lock. Existing H03 approvals/classification behavior
is not promoted to journal/effect authority.

## Verification and causal evidence

Final static exit 0; runtime29/29 exit 0; distinct public e2e6/6 exit 0, collectively
all35 H04 tests with current bytes. Root must run broad compatibility/full gates.
Two actual assertion REDs (old-run reservation and reserved-key collision) are
preserved once in h04/red-source and reproduced by h04/reproduce-red.sh; final
current test bytes produce two failures, exit1, without missing imports/APIs.
Earlier initial absent-API evidence is labeled separately.

Final test SHA256: `2b1727e3d4e299c78b843732fd1989e641d1366a4e36cce29f35bb3194389318`.
Final journal SHA256: `206975c30a859f35191d9b8195ca8d88fd884034f6a8d058c642b547756e4d63`.
Source/contract manifest SHA256: `fcdba6b3b77ba34489d28a327dca4621bff86d8fd1073a78d440387494687ba5`.
Evidence manifest SHA256: `8d3183aea815111a6bafa06646fc163b5567177e60b0c608c5395b72b61fc371`.
RED receipt SHA256: `b73230312bd488ae9f35182819c4b54fda349c6903932520a7e9b4274b1730e8`.

Full per-file mappings and raw commands/output/status are in
`docs/implementation/2026-09-05-harness-hardening/h04/`.

## Proposed F18 layer commands

Static (syntax for all changed runtime modules and both compatibility writers):

```bash
for source in packs/autonomy/repo-template/scripts/quality-orchestrator/{authority,classify,index,journal}.mjs; do node --check "$source" || exit; done; bash -n scripts/verify-feature.sh templates/full/scripts/verify-feature.sh
```

Runtime (29 focused chain, authority, idempotency, stale-run and negative cases):

```bash
node --test '--test-name-pattern=^(?:journal appends|idempotency|replay rejects|head index|exclusive existing|an existing|signed latest|checkpoint rejects|witness is fetched|fresh run rejects|incomplete intent|closed event|stale run|recovery requires|terminal verdict)' packs/autonomy/repo-template/scripts/quality-orchestrator/tests/journal.test.mjs
```

End-to-end (6 distinct public runtime/source/scaffold cases, including real processes):

```bash
node --test '--test-name-pattern=^(?:fresh mechanical|process crash|two real writers|legacy bytes|adopted v2|witness publication)' packs/autonomy/repo-template/scripts/quality-orchestrator/tests/journal.test.mjs
```

No High/Critical remains known after these fixes. No optional framework or service
was added. Remaining limitations are explicit contracts: real external witness
custody/latest authentication is host responsibility, interrupted recovery-owner
or torn-tail repair stays operator-controlled, missing witness intermediates
fail closed, and H05 supplies actual contained effects. Tests do not certify
same-UID containment, production witness availability or target adapters.
