# Independent H05 review 1

Reviewed base `772f47da8a96335346a126481fd11590126d75cb` through frozen tree `8739edeed87e427a1f8260c02313c9f6df2fc887`, including the shipping diff, complete task brief, runtime-boundary preflight, capability contract, H03 context/classification and H04 journal integration. The reviewed runtime/test files match the frozen tree. The exact initial implementer report SHA256 is `bb16026328791c5b8504a814f2ac2be740c9ef9f0de927dce238f8fcb6af563d`.

**Spec verdict: CHANGES REQUIRED — one High accepted-context/authority-scope bypass.**

**Code-quality verdict: CHANGES REQUIRED — the same missing output-membership check.** The closed implementation and existing primitives are proportionate to H05; no framework, service, new grant architecture or containment expansion is requested.

## H05-R1 — High: an output absent from the accepted context bypasses classification and adopted path scope

**Location:** `packs/autonomy/repo-template/scripts/quality-orchestrator/capabilities.mjs`, lines 60–62, especially the classification constructed exclusively from `binding.documents` at line 62. The relevant missing guard also affects the output assembly at lines 57–59.

`permitted()` checks the operator's writable paths, deny paths and registry class, but does not require an accepted-before identity. The projected classification iterates only the accepted binding documents. Consequently an output that is registered and writable but absent from that binding never enters the H03 classifier. A context can cover only `policy.yaml`, while a requested `record.yaml` output is silently omitted from the proof. This also allows the write when adopted authority scope contains only `policy.yaml`: the existing H03 context checks enforce adopted scope only for context documents.

**Observed impact:** a signed exact bounded grant can lead to an actual write and `EFFECT_VERIFIED` receipt outside the adopted authority scope, with no accepted-before proof for the output. A bounded grant must not replace baseline acceptance or expand the adopted scope. This is a supported data-only/public-API route using an intact runtime, actual filesystem writes, authentic fixture signatures and a valid lease; it requires no runtime/state tampering, hostile concurrent writer or uncontained subprocess.

**Focused reproduction, preserved exactly:**

- Probe: `/workspace/scratch/adce1c53b293/h05-unaccepted-output-probe.mjs`
- Output: `/workspace/scratch/adce1c53b293/h05-unaccepted-output-probe.log`
- Command: `node /workspace/scratch/adce1c53b293/h05-unaccepted-output-probe.mjs`
- Probe SHA256: `b9cb80086064ed26fb2faacdd425e042540ad6b76080bea4bbbf55cfe13984a7`
- Output SHA256: `adb54e4ac717526af4c4aa73da921d0096cba13eadcbec433606ba4a185a3bc6`

The probe configures adopted and accepted paths as `['policy.yaml']`, leaves `record.yaml` registered and writable, then requests `canonical-write.v1` for `record.yaml`. Direct H03 classification for the requested output returns `UNKNOWN`. Capability description nevertheless returns `CAPABILITY_DESCRIBED`; preparation with the fixture's exact signed grant and execution with a valid lease returns `EFFECT_VERIFIED`, `execution:'EXECUTED'`, `postconditions:'VERIFIED'`, changes `record.yaml` bytes and spends one unit. The probe exits 0 because it records the observed behavior rather than running an assertion suite.

**Smallest fix:** before projected classification or returning a description, require every computed output path to occur in `binding.documents`. Keep the complete projected-document classification already present. H04 validates that binding against exactly the accepted context; H03 already ensures that accepted context is within adopted authority scope. Thus this one membership guard restores both invariants without a new authority API. Cover omitted canonical output and omitted source/target of the derived batch with a focused regression; refusal must precede permit creation, reservation and workspace mutation. Preserve the now-discovered High source and exact regression bytes as causal evidence.

## Other reviewed boundaries

No additional blocking defect was established in this concrete review scope.

- The existing projected-document fix correctly prevents a canonical-only transformation from invalidating an accepted dependent digest when the source and digest are both in the accepted context. The missing-output case above is distinct.
- The two H04 fixes are correctly targeted: only internal outcome keys grow to 210, candidate keys remain capped at 200 with the reserved prefix refused, and verified witness B is durably retained under ownership before publishing/validating C. Corresponding focused cases are present.
- Generic reconciliation closure is substantive: only the private journal append path creates `effectKind:'local-capability.v1'`, the field persists in validated reservation events, candidate parsing rejects it, and generic reconciliation checks it before returning or obtaining a target outcome. Reopening without capability configuration does not remove the check. Actual supervisor completion verifies the complete manifest and records its receipt before the outcome.
- The capability registry is closed to canonical and source/digest transformations. Exact plan grants, private WeakMap permits/leases, current run/head and context checks, actual Node/module/dependency/config binding, deny precedence, conservative aliases/modes, whole-workspace manifests, intent-before-reservation-before-effect ordering and exact receipt-before-outcome ordering are present.
- Reconciliation does not republish. Partial publication, journal uncertainty and interrupted ownership fail closed without automatic rollback or takeover. The local-only cooperating-writer and partial-batch limitations are stated accurately; no malicious same-UID protection or atomicity is claimed.
- `subprocess.v1` refuses before spawn with `BLOCKED_BY_REQUIRED_CAPABILITY` / `NOT_EXECUTED`. Missing host containment is not represented as a successful sandbox test.

## Evidence assessment and limits

Read the final static, runtime and e2e evidence and the causal RED receipt/log/reproduction script. Recorded results are five syntax checks, 26 runtime tests and 3 actual public workflow tests passing. The preserved-source causal log contains three real assertion failures: `CAPABILITY_DESCRIBED` instead of `POLICY`, and two generic reconciliations returning `APPENDED` instead of `POLICY` (same runtime and reopened). Current test bytes are bound in the receipt and match the preserved test snapshot; initial missing-API development output is explicitly separate. The controller's source/evidence hash validation is acknowledged; these local artifacts do not authenticate real external issuer custody or containment.

Only the focused probe above was executed during this review. No broad suite, source/index/ref edits, worker requests, new agents or external operations were performed. Root retains F19/full-check, evidence integration and publication ownership. Stop for the narrow H05-R1 fix and its causal regression; H06 semantic continuation remains outside this review.
