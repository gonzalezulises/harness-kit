# H03 fix round 1 — scoped independent re-review

**Specification verdict: APPROVED. Code-quality verdict: APPROVED.**

R1: **ADDRESSED**. R2: **ADDRESSED**. No new blocking breakage found. Remaining findings within this re-review scope: **0 Critical, 0 High, 0 Medium, 0 Low**.

Reviewed the change from `f508b942704143a5d58c45b7eb4fdbd0180f096a` to frozen tree `a358faaae3f6c346297ef0ce713cbab7bd5b8688`, using `.superpowers/sdd/migration-plan/h03-fix-1-review.diff`, the appended “H03 fix round 1” implementer report, current source/tests and fix evidence. The shipping pack had no working-tree diff against the new frozen tree when checked. This review covers the two prior findings and breakage introduced by their fixes; it is not a fresh full H03 or branch review.

## Finding disposition

| Finding | Status | Source and evidence |
| --- | --- | --- |
| R1 — Explicit default-handle TAG directive accepted as canonical reorder | ADDRESSED | `packs/autonomy/repo-template/scripts/quality-orchestrator/identity.mjs:52–56` now iterates actual yaml Parser tokens and rejects every directive token before composition. This distinguishes an explicit `%TAG !!` declaration from the implicit default tag mapping. The new identity test covers LF, CRLF, and a custom tag handle, while preserving quoted directive text as a string. The public classifier regression rejects the reported directive addition and preserves ordinary key-reorder eligibility. |
| R2 — Constructors return intermediate approval handles when freshness reinspection fails | ADDRESSED | `authority.mjs:64–68` and `classify.mjs:35–38` first preserve a stop from `verifyApproval`, then return the failed reinspection result itself. Authority/context handles are created only after successful reinspection. Tests cover expiry and unavailable-clock boundaries in both constructors and exact status/reason propagation. Two additional controls preserve original signature-verification stops. |

The R1 implementation uses the same pinned YAML parser already in the package. It does not introduce a separate text-pattern filter, normalize unsupported directives, or reject ordinary quoted directive text. Existing fatal UTF-8, size, composed-document and typed-schema checks remain in place. The recorded structural probe confirms why token inspection is necessary: plain and explicitly declared default-tag documents have identical composed tag maps, but only the explicit declaration contains a directive token.

The R2 fix correctly handles both branches of the return union. Its initial `.status` check is applied to a value produced by the trusted verifier: an explicit stop or an empty, frozen, null-prototype handle. It is not accepting candidate-provided status claims as verification. Reinspection still occurs on successful approvals; the fix neither skips freshness checks nor treats an approval handle as an authority/context handle. Existing successful constructor tests remain GREEN.

No fix-created permission, trust-root, schema, proof-kind or protected-class expansion appears in the diff. Package/lock, verifier and public API kinds are unchanged. Contract text explains the repaired behavior without weakening the original v1 rejection or freshness requirements. Current capability/quality text distinguishes the new 62-case focused run from the earlier 54-case consumer canary.

## Evidence assessment

The preserved `h03/fix-1/` evidence supports the claimed causal progression:

| Capture | Recorded result | Interpretation |
| --- | --- | --- |
| `red-01` | Exit 1; 62 tests, 56 pass, six ERR_ASSERTION failures | The exact reviewed pre-fix production source fails both directive regressions and all four constructor expiry/unavailability regressions. The two signature-stop controls already pass, as expected. |
| `r1-fixed-01` | Exit 1; 62 tests, 58 pass, four ERR_ASSERTION failures | Both directive failures are resolved; exactly the four R2 cases remain failing. |
| `green-01` | Exit 0; 62 tests, 62 pass, zero failures | Both fixes and all prior focused cases pass. |
| `directive-probe-02` | Successful captured plain/directive/quoted token controls | Confirms the structural parser distinction used by R1. |

I inspected the failure names/counts and GREEN totals in the captured logs, the current regression assertions, corrected directive probe source/output, current RED receipt and final seal. The pre-fix production hashes in `red-receipt-v2.json` match the module hashes recorded in the original independent review probes. This is actual pre-fix source with the new current tests, not the earlier multi-version final-falsification overlay. The Git history anchor in the oracle is not being treated as a commit containing those H03 modules; the named reviewed tree and preserved source hashes identify the defect-bearing implementation.

The initial directive probe's import failure is explicitly retained as a tooling error and excluded from causal RED. The report preserves the original 54-case history and distinguishes it from this round. The controller verified all 116 manifest entries and the report seal; I rely on that supplied verification rather than repeating the hash sweep. The recorded eight syntax checks, oracle/note checks and scoped diff check are exit 0.

No suites or additional probes were rerun in this re-review: the small source diff, meaningful regression assertions and preserved execution evidence resolve both findings and the relevant fix risks. The copied-consumer, broad core/load and full integration suites were not rerun by the implementer, and this report does not imply otherwise.

## Limits and next step

The scoped fixes are approved for the controller's integration checks and normal feature-promotion process. This is not a full `make check` result, branch-wide review, policy/baseline acceptance or publication authorization. The original H03 host-trust and H04+ limits remain unchanged: fixture receipts do not establish real human enrollment, external revocation/witness freshness, containment, authenticated Codex acceptance or production execution. No source, index or refs were changed during this review.
