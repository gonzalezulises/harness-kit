# Quality Document — harness-kit

Current module health, based on the hardening review and executed verification.
Last updated: 2026-09-06. Grades: **A** solid, **B** adequate, **C** needs work,
**D** a known false-success path remains. Historical audit evidence stays in
`docs/reviews/2026-09-05-harness-hardening/`; current work and limits are in
`docs/implementation/2026-09-05-harness-hardening/ledger.md`.

| Module | Grade | Verified behavior | Remaining gap |
|---|---|---|---|
| Legacy contract, claims, state and decision verifiers | B | 31 focal tests; independent H01 review approved after three fix rounds | Mutable local history is not strong authority; recorded budgeted failures require verified recovery, unavailable in v1 |
| Architecture checks | B | Whole-document validation and typed matcher exit/filter contracts fail before effects | Legacy shell commands remain legacy; no process confinement claim |
| Live gate registry and required CI | B | H02 real-scaffold/live-policy and separate-base judge fixtures pass; quick gates are part of integrated check | Proposed CI requires protected-policy adoption; remote required execution is not yet certified |
| Installation profiles and prerequisites | B | Versioned profiles, required universal gates and isolated pinned parser; H09 explicit optional install preserves existing runtime/root package and adds four boundary tests | Consumers must explicitly migrate old installations, install prerequisites and adopt authority separately |
| Oracle evidence and context routing | B | Strict standard YAML, current test-byte receipt bindings, committed/index/workspace/untracked routes; preserved H01 probes witnessed again | Local receipt consistency does not authenticate a malicious author or prove prose meaning |
| Staged hooks and test infrastructure | B | Index snapshots preserve partial staging/modes; symlinks and formatter failures block; concurrent core286/0 twice and load55/0 twice | No malicious-formatter process sandbox; two authenticated-gh omissions per load suite remain explicit |
| Delivery status and capability docs | B | Readiness requires observed bounded local check; rule contents inspected; API failure stays indeterminate; current module/prerequisite docs | Configuration inspection is not an adversarial merge canary or production acceptance |
| Optional verified autonomy runtime | C | 239 runtime/local-contract tests plus H09 installation4/canary1 and one protected-workflow regression; full integration669/0, startup286/0, selected69-source manifest unchanged; F24 backend and CI independently approved after four causal fixes | Current F24 layers pass24 runtime/4 e2e plus the protected workflow case, and F19/F23 original35/5 cases are revalidated. Broad final review remains INCOMPLETE; actual containment/consumer target integration and live acceptance remain outstanding; the new selected-asset candidate is unsigned and unaccepted |

H01 evidence is in the implementation ledger and its `h01/` folders. GREEN
fixtures establish their tested contracts; they do not certify authenticated
Codex sessions, malicious same-UID containment, external consumers, or production.
F09's historical two-attempt claim is blocked under the approved recovery rule;
its original contract and receipts remain intact.

Final review's one confirmed High (FR-01) is corrected and independently closed
within that corrective scope. The automatic interruption of the whole-branch
review is preserved in the H09 controller handoff; no broad approval is claimed.
The workflow now installs the existing locked optional dependencies, but real
CI remains subject to protected-policy adoption before those steps execute.

Update this document when a module changes materially, before comparing
benchmarks, and after removing or simplifying a harness component. Grades must
follow observed behavior and explicit gaps, not the number of files or rules.
