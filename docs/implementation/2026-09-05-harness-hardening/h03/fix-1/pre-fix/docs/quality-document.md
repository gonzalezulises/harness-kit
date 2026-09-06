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
| Installation profiles and prerequisites | B | Versioned minimal/full/kit profiles; universal gates required; PyYAML6.0.3 isolated install and explicit core/full prerequisite checks | Consumers must explicitly migrate old installations and install parser/tool prerequisites |
| Oracle evidence and context routing | B | Strict standard YAML, current test-byte receipt bindings, committed/index/workspace/untracked routes; preserved H01 probes witnessed again | Local receipt consistency does not authenticate a malicious author or prove prose meaning |
| Staged hooks and test infrastructure | B | Index snapshots preserve partial staging/modes; symlinks and formatter failures block; concurrent core286/0 twice and load55/0 twice | No malicious-formatter process sandbox; two authenticated-gh omissions per load suite remain explicit |
| Delivery status and capability docs | B | Readiness requires observed bounded local check; rule contents inspected; API failure stays indeterminate; current module/prerequisite docs | Configuration inspection is not an adversarial merge canary or production acceptance |
| Optional verified autonomy runtime | C | H03 typed identity, scoped Ed25519 authority and pure classification:54 focused tests and copied-package canary | H04–H09 remain pending; no journal, effects or production acceptance; H03 independent review is pending |

H01 evidence is in the implementation ledger and its `h01/` folders. GREEN
fixtures establish their tested contracts; they do not certify authenticated
Codex sessions, malicious same-UID containment, external consumers, or production.
F09's historical two-attempt claim is blocked under the approved recovery rule;
its original contract and receipts remain intact.

Update this document when a module changes materially, before comparing
benchmarks, and after removing or simplifying a harness component. Grades must
follow observed behavior and explicit gaps, not the number of files or rules.
